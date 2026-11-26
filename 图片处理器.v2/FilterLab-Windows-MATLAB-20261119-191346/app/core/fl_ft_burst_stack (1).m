function R = fl_ft_burst_stack(frames,opts)
%FL_FT_BURST_STACK Register a translation-only burst to one reference frame.
% Shifts(k,:) is the observed [dy dx]. CropRect is [x y width height].
if nargin<2, opts=struct(); end
p=inputParser; p.addParameter('Mode','median'); p.addParameter('RefIndex',1);
p.addParameter('AutoCrop',true); p.addParameter('Clean',[]); p.addParameter('TrueShifts',[]);
p.parse(opts); o=p.Results; mode=validatestring(o.Mode,{'median','mean','trimmed'});
if ~iscell(frames) || isempty(frames), error('fl_ft_burst_stack:frames','请选择一组连拍。'); end
n=numel(frames); ref=o.RefIndex;
validateattributes(ref,{'numeric'},{'integer','scalar','>=',1,'<=',n});
validateattributes(o.AutoCrop,{'logical','numeric'},{'scalar','binary'});
reference=double(frames{ref}); [h,w,ch]=size(reference);
if ch~=3 || min(h,w)<8, error('fl_ft_burst_stack:size','需要至少 8 × 8 的 RGB 连拍。'); end
[x,y]=meshgrid(1:w,1:h);
wy=.5-.5*cos(2*pi*(0:h-1)'/(h-1)); wx=.5-.5*cos(2*pi*(0:w-1)/(w-1));
window=wy*wx;
fy=ifftshift((-floor(h/2):ceil(h/2)-1)'/h); fx=ifftshift((-floor(w/2):ceil(w/2)-1)/w);
radius=2*hypot(fy,fx); weight=exp(-.5*(radius/.38).^2);
Fref=spectrum(reference,window);
shifts=zeros(n,2); psr=inf(n,1); aligned=nan(h,w,3,n);
for k=1:n
    img=double(frames{k});
    if ~isequal(size(img),size(reference)) || ~isreal(img) || any(~isfinite(img(:)) | img(:)<0 | img(:)>1)
        error('fl_ft_burst_stack:frames','连拍需要相同尺寸的有限 [0,1] RGB 图像。');
    end
    if k==ref, aligned(:,:,:,k)=img; continue; end
    cross=spectrum(img,window).*conj(Fref);
    corr=real(ifft2(weight.*cross./(abs(cross)+eps)));
    [peak,idx]=max(corr(:)); [row,col]=ind2sub([h,w],idx);
    rr=mod(row-1+[-1 0 1],h)+1; cc=mod(col-1+[-1 0 1],w)+1;
    dy=mod(row-1+floor(h/2),h)-floor(h/2)+vertex(corr(rr,col));
    dx=mod(col-1+floor(w/2),w)-floor(w/2)+vertex(corr(row,cc));
    shifts(k,:)=[dy dx];
    side=corr; side(mod(row-1+(-3:3),h)+1,mod(col-1+(-3:3),w)+1)=NaN;
    side=side(isfinite(side)); psr(k)=(peak-mean(side))/max(std(side),eps);
    for c=1:3
        aligned(:,:,c,k)=interp2(img(:,:,c),x+dx,y+dy,'linear',NaN);
    end
end
valid=squeeze(all(isfinite(aligned(:,:,1,:)),4));
rows=find(any(valid,2)); cols=find(any(valid,1));
if isempty(rows), error('fl_ft_burst_stack:overlap','连拍没有公共有效区域。'); end
switch mode
    case 'median', stacked=median(aligned,4,'omitnan');
    case 'mean', stacked=mean(aligned,4,'omitnan');
    case 'trimmed'
        count=sum(isfinite(aligned),4);
        total=sum(aligned,4,'omitnan');
        trimmed=(total-min(aligned,[],4,'omitnan')-max(aligned,[],4,'omitnan'))./max(count-2,1);
        stacked=total./count;
        mask=count>2; stacked(mask)=trimmed(mask);
end
% Compare the same reference-grid pixels before and after registration.
refPatch=reference(rows,cols,:); before=zeros(n,1); after=zeros(n,1);
for k=1:n
    a=frames{k}(rows,cols,:)-refPatch; b=aligned(rows,cols,:,k)-refPatch;
    before(k)=mean(abs(a(:))); after(k)=mean(abs(b(:)));
end
others=setdiff(1:n,ref); if isempty(others), others=ref; end
m=struct('FrameCount',n,'MaxShift',max(hypot(shifts(:,1),shifts(:,2))), ...
    'ResidualBefore',mean(before(others)),'ResidualAfter',mean(after(others)));
m.ResidualReduction=(m.ResidualBefore-m.ResidualAfter)/max(m.ResidualBefore,eps);
stackPatch=stacked(rows,cols,:);
if ~isempty(o.Clean)
    if ~isequal(size(o.Clean),size(reference)), error('fl_ft_burst_stack:truth','Clean 尺寸应与连拍一致。'); end
    offset=[0 0];
    if ~isempty(o.TrueShifts)
        validateattributes(o.TrueShifts,{'numeric'},{'size',[n 2],'finite','real'});
        offset=o.TrueShifts(ref,:);
    end
    % Restrict metrics to available truth, even when AutoCrop is disabled.
    yr=rows(rows-offset(1)>=1 & rows-offset(1)<=h);
    xc=cols(cols-offset(2)>=1 & cols-offset(2)<=w);
    truth=zeros(numel(yr),numel(xc),3);
    for c=1:3
        truth(:,:,c)=interp2(double(o.Clean(:,:,c)),xc(:).'-offset(2),yr(:)-offset(1),'linear');
    end
    singleFrame=reference(yr,xc,:); stackFrame=stacked(yr,xc,:);
    m.SinglePSNR=fl_ext_metrics('psnr',truth,singleFrame); m.StackPSNR=fl_ext_metrics('psnr',truth,stackFrame);
    m.SingleSSIM=fl_ext_metrics('ssim',truth,singleFrame); m.StackSSIM=fl_ext_metrics('ssim',truth,stackFrame);
    m.NoiseStdBefore=std(singleFrame(:)-truth(:)); m.NoiseStdAfter=std(stackFrame(:)-truth(:));
    m.NoiseMethod='对干净真值的 RGB 残差标准差';
else
    m.NoiseStdBefore=noise_estimate(refPatch); m.NoiseStdAfter=noise_estimate(stackPatch);
    m.NoiseMethod='亮度对角差分 MAD 估计';
end
m.NoiseReduction=(m.NoiseStdBefore-m.NoiseStdAfter)/max(m.NoiseStdBefore,eps);
if ~o.AutoCrop, rows=1:h; cols=1:w; end
R=struct('Aligned',aligned(rows,cols,:,:),'Stacked',stacked(rows,cols,:), ...
    'Reference',reference(rows,cols,:),'Shifts',shifts,'PSR',psr,'ValidMask',valid(rows,cols), ...
    'CropRect',[cols(1) rows(1) numel(cols) numel(rows)],'Metrics',m);
end

function F=spectrum(img,window)
L=fl_ft_luma(img); F=fft2((L-mean(L(:))).*window);
end
function v=vertex(a)
curvature=a(1)-2*a(2)+a(3); v=0;
if curvature < -eps, v=.5*(a(1)-a(3))/curvature; end
end
function sigma=noise_estimate(img)
d=conv2(fl_ft_luma(img),[1 -1;-1 1]/2,'valid');
sigma=median(abs(d(:)-median(d(:))))/.67449;
end
