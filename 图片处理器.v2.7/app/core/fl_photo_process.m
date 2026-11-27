function [Y, info, stages] = fl_photo_process(X, S)
%FL_PHOTO_PROCESS Nonaccumulating sRGB color, guided denoise and multiscale detail.
% Optional stages are signed luma differences: before/after denoise, detail gain.
% Noise estimates are heuristics on native tiles, not calibrated sensor noise.
% Retain just the last preview or small full frame. Full pixel/class checks
% handle same-sized replacements, interactive callers and preview/full switches.
persistent last
clock=tic;
if nargin<2, S=fl_photo_spec(); else, S=fl_photo_spec(S); end
if ~((isa(X,'single')||isa(X,'double'))&&isreal(X)&&~isempty(X)&&ndims(X)==3&&size(X,3)==3)
    error('fl_photo_process:input','输入必须为 [0,1] 的有限 single/double RGB 图像。');
end
keep=size(X,1)*size(X,2)<=2*1024^2;
same=keep && ~isempty(last) && strcmp(class(X),class(last.source)) && isequal(X,last.source);
wantStages=nargout>2;
if same
    memo=last;
    if isequal(memo.spec,S) && (~wantStages || isfield(memo.stages,'DetailResidual'))
        Y=memo.result; info=memo.info; stages=memo.stages; info.ElapsedSeconds=toc(clock); return
    end
else
    if any(~isfinite(X(:))) || any(X(:)<0|X(:)>1)
        error('fl_photo_process:input','输入必须为 [0,1] 的有限 single/double RGB 图像。');
    end
    last=[]; memo=struct('source',X,'linear',[],'spec',[],'prefix',[],'residual',[], ...
        'codeChecked',false,'codes',[]);
end
prefix=rmfield(S,{'SharpenEnable','SharpenAmount','SharpenRadius','SharpenThreshold', ...
    'FineDetail','Clarity','LocalContrast','HaloSuppression'});
if ~isequal(prefix,memo.prefix) || (wantStages && isempty(memo.residual))
    [colored,memo,gains,colorClip]=color_stage(single(X),S,memo,keep);
    noise=fl_photo_noise(colored);
    lumaStrength=S.LumaDenoise; colorStrength=S.ColorDenoise;
    if S.AutoNoise
        lumaStrength=noise.LumaStrength; colorStrength=noise.ColorStrength;
    end
    [memo.base,memo.residual,memo.luma]=denoise_stage(colored,S,lumaStrength,colorStrength,wantStages);
    clear colored
    memo.prefix=prefix; memo.noise=noise; memo.gains=gains; memo.clip=colorClip;
    memo.lumaStrength=lumaStrength; memo.colorStrength=colorStrength;
end
threshold=S.SharpenThreshold;
if S.AutoNoise, threshold=max(threshold,memo.noise.Threshold); end
Y=memo.base; stages=struct();
if wantStages, stages.DenoiseResidual=memo.residual; end
if S.SharpenEnable && any([S.SharpenAmount S.FineDetail S.Clarity S.LocalContrast]~=0)
    if isempty(memo.luma), memo.luma=luma(Y); end
    Y=sharpen_stage(Y,memo.luma,S,threshold,memo.noise.SigmaLuma);
end
Y=min(1,max(0,Y));
if wantStages, stages.DetailResidual=luma(Y)-memo.luma; end
info=struct('ElapsedSeconds',toc(clock),'ClippedFraction',memo.clip, ...
    'WhiteBalanceGains',double(memo.gains),'ColorSpace','sRGB','Noise',memo.noise, ...
    'EffectiveLumaDenoise',memo.lumaStrength,'EffectiveColorDenoise',memo.colorStrength, ...
    'EffectiveThreshold',threshold, ...
    'Method','guided denoise / edge-aware multiscale / adaptive halo limiter');
if keep
    memo.spec=S; memo.result=Y; memo.info=info; memo.stages=stages; last=memo;
end
end

function [Y,memo,gains,colorClip]=color_stage(Y,S,memo,keep)
gains=single([1 1 1]); colorClip=0;
if S.ColorEnable
    gains=single(S.WB).*single([exp(S.Temperature*.003+S.Tint*.001), ...
        exp(-S.Tint*.002),exp(-S.Temperature*.003+S.Tint*.001)]);
    if S.AutoWB, gains=gains.*auto_white(Y); end
    if any(abs(gains-1)>1e-7)||S.Exposure~=0
        if ~memo.codeChecked
            % JPEG/8-bit PNG code values permit an exact 256-entry transform.
            % A quick rejection helps float previews. Acceptance tests every value.
            sample=Y(1:max(1,floor(numel(Y)/128)):end);
            if isequal(single(uint8(sample*255))/255,sample)
                codes=uint8(Y*255);
                if isequal(single(codes)/255,Y), memo.codes=codes; end
            end
            memo.codeChecked=true;
        end
        if ~isempty(memo.codes)
            levels=decode_srgb(single((0:255)')/255); clipped=false(size(Y,1),size(Y,2));
            for c=1:3
                L=levels.*gains(c)*single(2^S.Exposure);
                curve=encode_srgb(min(1,max(0,L))); outside=L<0|L>1;
                idx=uint16(memo.codes(:,:,c))+uint16(1);
                Y(:,:,c)=reshape(curve(idx),size(idx)); clipped=clipped|reshape(outside(idx),size(idx));
            end
            colorClip=nnz(clipped)/numel(clipped);
        else
            if isempty(memo.linear), L=decode_srgb(Y); else, L=memo.linear; end
            if keep, memo.linear=L; end
            L=L.*reshape(gains,1,1,3)*single(2^S.Exposure);
            colorClip=nnz(any(L<0|L>1,3))/(size(L,1)*size(L,2));
            Y=encode_srgb(min(1,max(0,L))); clear L;
        end
    end
    if any([S.Contrast S.Highlights S.Shadows S.Vibrance S.Saturation]~=0)
        lum=luma(Y); delta=Y-lum;
        target=lum+single(.6*S.Shadows)*lum.*(1-lum).^2 ...
            +single(.6*S.Highlights)*lum.^2.*(1-lum);
        target=target+single(3.2*S.Contrast)*(target-.5).*target.*(1-target);
        target=min(1,max(0,target)); delta=delta.*(target./max(lum,single(1e-5)));
        factor=single(1+S.Saturation);
        if S.Vibrance~=0
            peak=max(Y,[],3); sat=(peak-min(Y,[],3))./max(peak,single(1e-5));
            factor=factor*(1+single(S.Vibrance)*(1-sat));
        end
        Y=compose(target,delta.*factor);
    end
end
end

function [Y,residual,denoised]=denoise_stage(Y,S,lumaStrength,colorStrength,wantStages)
residual=[]; denoised=[];
denoise=S.DenoiseEnable && (lumaStrength>0||colorStrength>0);
if wantStages || denoise, lum=luma(Y); end
if denoise
    cr=Y(:,:,1)-lum; cb=Y(:,:,3)-lum;
    r=2+round(4*max(lumaStrength,colorStrength));
    mu=box_mean(lum,r); variance=max(0,box_mean(lum.*lum,r)-mu.*mu);
    if lumaStrength>0
        ep=single((.008+.07*lumaStrength)^2*(1-.6*S.Detail));
        a=variance./(variance+ep); b=mu-a.*mu;
        smooth=box_mean(a,r).*lum+box_mean(b,r);
        outLum=lum+single(lumaStrength)*(smooth-lum);
    else
        outLum=lum;
    end
    if colorStrength>0
        ep=single((.025+.12*colorStrength)^2);
        cr=guided_chroma(cr,lum,mu,variance,r,ep,colorStrength);
        cb=guided_chroma(cb,lum,mu,variance,r,ep,colorStrength);
    end
    delta=cat(3,cr,-(single(.2126)*cr+single(.0722)*cb)/single(.7152),cb);
    Y=compose(outLum,delta);
end
if wantStages
    if denoise, denoised=luma(Y); else, denoised=lum; end
    residual=lum-denoised;
end
end

function Y=sharpen_stage(Y,lum,S,threshold,sigmaLuma)
target=lum;
if S.SharpenAmount~=0
    detail=soft(lum-gaussian_blur(lum,S.SharpenRadius),threshold);
    target=lum+single(S.SharpenAmount)*detail;
end
% Adjacent bands share their edge-aware base. Build only the bases used.
if S.FineDetail~=0 || S.Clarity~=0, b1=edge_base(lum,2,.0004); end
if S.FineDetail~=0
    target=target+single(S.FineDetail)*soft(lum-b1,threshold);
end
if S.Clarity~=0 || S.LocalContrast~=0, b2=edge_base(lum,6,.0016); end
if S.Clarity~=0
    target=target+single(S.Clarity)*soft(b1-b2,threshold*.5);
end
if S.LocalContrast~=0
    b3=edge_base(lum,18,.004);
    target=target+single(S.LocalContrast)*soft(b2-b3,threshold*.25);
end
[lo,hi]=local_envelope(lum);
% Scale allowed overshoot by edge contrast, available headroom and noise.
contrast=hi-lo; headroom=min(lum,1-lum);
allowance=(single(.003)+single(.08)*contrast).*min(1,headroom/single(.08));
allowance=allowance*single(1-.9*S.HaloSuppression)/single(1+8*sigmaLuma);
target=min(hi+allowance,max(lo-allowance,target));
Y=compose(min(1,max(0,target)),Y-lum);
end
function y=soft(x,t)
y=sign(x).*max(0,abs(x)-single(t));
end
function y=luma(x)
y=single(.2126)*x(:,:,1)+single(.7152)*x(:,:,2)+single(.0722)*x(:,:,3);
end
function y=compose(lum,delta)
pos=max(delta,[],3); neg=-min(delta,[],3);
scale=min(1,min((1-lum)./max(pos,single(1e-7)),lum./max(neg,single(1e-7))));
y=lum+delta.*max(0,scale);
end
function q=guided_chroma(p,I,mu,varI,r,ep,strength)
mp=box_mean(p,r); cov=box_mean(I.*p,r)-mu.*mp;
a=cov./(varI+ep); b=mp-a.*mu;
q=p+single(strength)*(box_mean(a,r).*I+box_mean(b,r)-p);
end
function y=edge_base(x,r,ep)
mu=box_mean(x,r); variance=max(0,box_mean(x.*x,r)-mu.*mu);
a=variance./(variance+single(ep)); y=box_mean(a,r).*x+box_mean(mu-a.*mu,r);
end
function y=box_mean(x,r)
k=ones(1,2*r+1,'single')/single(2*r+1); y=separable(x,k);
end
function y=gaussian_blur(x,sigma)
r=max(1,ceil(3*sigma)); k=single(exp(-(-r:r).^2/(2*sigma^2))); k=k/sum(k); y=separable(x,k);
end
function y=separable(x,k)
r=(numel(k)-1)/2; h=size(x,1); w=size(x,2);
rows=[ones(1,r),1:h,h*ones(1,r)]; cols=[ones(1,r),1:w,w*ones(1,r)];
y=conv2(x(:,cols),k,'valid'); y=conv2(y(rows,:),k','valid');
end
function [lo,hi]=local_envelope(x)
% A 3x3 extremum is the 1x3 extremum of the three row extrema.
h=size(x,1); w=size(x,2);
left=x(:,[1 1:w-1]); right=x(:,[2:w w]);
lo=min(x,min(left,right)); hi=max(x,max(left,right));
up=[1 1:h-1]; down=[2:h h];
lo=min(lo,min(lo(up,:),lo(down,:))); hi=max(hi,max(hi(up,:),hi(down,:)));
end
function L=decode_srgb(x)
L=x/single(12.92); mask=x>single(.04045); L(mask)=((x(mask)+single(.055))/single(1.055)).^single(2.4);
end
function x=encode_srgb(L)
x=single(12.92)*L; mask=L>single(.0031308); x(mask)=single(1.055)*L(mask).^single(1/2.4)-single(.055);
end
function gains=auto_white(x)
stride=max(1,ceil(sqrt(size(x,1)*size(x,2)/160000)));
p=x(1:stride:end,1:stride:end,:); lum=luma(p);
peak=max(p,[],3); chroma=(peak-min(p,[],3))./max(peak,single(1e-5));
mask=lum>.08 & lum<.9 & chroma<.22; gains=single([1 1 1]);
if nnz(mask)<max(16,numel(mask)*.005), return; end
p=decode_srgb(p); means=zeros(1,3,'single');
for c=1:3, channel=p(:,:,c); means(c)=mean(channel(mask)); end
if min(means)<1e-6, return; end
gains=min(single(1.35),max(single(.75),mean(means)./means));
end
