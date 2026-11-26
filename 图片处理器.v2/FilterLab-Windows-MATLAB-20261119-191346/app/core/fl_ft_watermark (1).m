function R=fl_ft_watermark(action,img,opts)
%FL_FT_WATERMARK Embed in conjugate magnitude bins or independently inspect them.
if nargin<3, opts=struct(); end
action=validatestring(action,{'embed','inspect'});
p=inputParser; p.addParameter('Mode','text'); p.addParameter('Text','FILTERLAB');
p.addParameter('Icon','heart'); p.addParameter('PatternImage',[]);
p.addParameter('Strength',.22); p.addParameter('RunAttackTest',true); p.parse(opts); o=p.Results;
validateattributes(o.Strength,{'numeric'},{'scalar','finite','>=',.05,'<=',.60});
validateattributes(o.RunAttackTest,{'logical','numeric'},{'binary','scalar'});
img=fl_ft_samples('normalize',img,flintmax);
if iscell(img)
    if numel(img)~=1, error('fl_ft_watermark:image','请选择一张照片。'); end
    img=img{1};
end
[h,w,~]=size(img); cy=floor(h/2)+1; cx=floor(w/2)+1;
if min(h,w)<24, error('fl_ft_watermark:size','水印需要至少 24 × 24 像素。'); end
pattern=make_pattern(o);
% Fit the complete template above DC, inside both conjugate half planes.
scale=min([min(.24*(cy-1)/size(pattern,1),.82*(w-2)/size(pattern,2)),2]);
sz=max(1,round(size(pattern)*scale));
pattern=pattern(round(linspace(1,size(pattern,1),sz(1))),round(linspace(1,size(pattern,2),sz(2))));
if all(pattern(:)==pattern(1)), error('fl_ft_watermark:pattern','模板需要可区分的前景与背景，请调整模板或图像大小。'); end
r=cy-round(.36*(cy-1))-floor(sz(1)/2)+(0:sz(1)-1);
c=cx-floor(sz(2)/2)+(0:sz(2)-1);
X=img; imagResidual=NaN;
if strcmp(action,'embed')
    Y=fl_ft_luma(img); F=fftshift(fft2(Y)); mag=abs(F);
    % Parseval caps the spatial RMS. Local magnitude sets the contrast needed
    % in the target band. A small floor covers smooth or constant images.
    targetRMS=o.Strength*.036;
    energyLimit=numel(Y)*targetRMS/sqrt(2*sum(pattern(:).^2));
    band=mag(r,c);
    amplitude=min(energyLimit,max(.55*energyLimit,median(band(:))*22*o.Strength));
    patch=amplitude*pattern;
    mag(r,c)=mag(r,c)+patch;
    % Both index vectors descend, so indexing supplies the 180-degree turn.
    mr=2*cy-r; mc=2*cx-c;
    mag(mr,mc)=mag(mr,mc)+patch;
    restored=ifft2(ifftshift(mag.*exp(1i*angle(F))));
    imagResidual=max(abs(imag(restored(:))));
    X=min(1,max(0,img+(real(restored)-Y)));
end
R=inspect_image(X,pattern,r,c);
R.Output=X; R.Original=img; R.Pattern=pattern; R.Region=[r(1) c(1) sz];
R.ImagResidual=imagResidual; R.Attack=struct();
if strcmp(action,'embed')
    R.PSNR=fl_ext_metrics('psnr',img,X); R.SSIM=fl_ext_metrics('ssim',img,X);
    if o.RunAttackTest
        % A private stream leaves the caller's random sequence intact.
        stream=RandStream('mt19937ar','Seed',771);
        noisy=min(1,max(0,X+.015*randn(stream,size(X))));
        R.Attack.Noise=inspect_image(noisy,pattern,r,c);
        R.Attack.Tone=inspect_image(.95*X+.04,pattern,r,c);
    end
end
end

function R=inspect_image(img,pattern,r,c)
S=log10(1+abs(fftshift(fft2(fl_ft_luma(img)))));
patch=S(r,c); p=pattern-mean(pattern(:)); q=patch-mean(patch(:));
R.Spectrum=S; R.WatermarkSpectrum=patch;
R.DetectCorr=sum(p(:).*q(:))/max(norm(p(:))*norm(q(:)),eps);
signal=mean(patch(pattern>.5)); background=patch(pattern<=.5);
R.DetectSNR_dB=20*log10(max(abs(signal-mean(background)),eps)/max(std(background),eps));
end

function pat=make_pattern(o)
switch validatestring(o.Mode,{'text','icon','image'})
    case 'image'
        if isempty(o.PatternImage), error('fl_ft_watermark:pattern','请选择自定义图标。'); end
        icon=fl_ft_samples('normalize',o.PatternImage,160);
        if iscell(icon), icon=icon{1}; end
        a=fl_ft_luma(icon); pat=a>(min(a(:))+max(a(:)))/2;
    case 'icon'
        maps=struct('heart',[0 1 0 1 0;1 1 1 1 1;1 1 1 1 1;0 1 1 1 0;0 0 1 0 0], ...
            'star',[0 0 0 1 0 0 0;0 0 1 1 1 0 0;1 1 1 1 1 1 1;0 1 1 1 1 1 0;0 0 1 1 1 0 0;0 1 1 0 1 1 0;0 1 0 0 0 1 0], ...
            'smile',[0 1 1 1 1 1 0;1 0 0 0 0 0 1;1 0 1 0 1 0 1;1 0 0 0 0 0 1;1 1 0 0 0 1 1;1 0 1 1 1 0 1;0 1 1 1 1 1 0], ...
            'plus',[0 0 1 0 0;0 0 1 0 0;1 1 1 1 1;0 0 1 0 0;0 0 1 0 0]);
        key=validatestring(o.Icon,fieldnames(maps)); pat=kron(maps.(key),ones(2));
    case 'text'
        pat=text_pattern(upper(char(o.Text)));
end
pat=double(pat);
end

function p=text_pattern(s)
keys={'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','0','1','2','3','4','5','6','7','8','9','-','_','.','!',' '};
rows={'01110 10001 10001 11111 10001 10001 10001','11110 10001 10001 11110 10001 10001 11110','01111 10000 10000 10000 10000 10000 01111','11110 10001 10001 10001 10001 10001 11110','11111 10000 10000 11110 10000 10000 11111','11111 10000 10000 11110 10000 10000 10000','01111 10000 10000 10111 10001 10001 01111','10001 10001 10001 11111 10001 10001 10001','11111 00100 00100 00100 00100 00100 11111','00111 00010 00010 00010 10010 10010 01100','10001 10010 10100 11000 10100 10010 10001','10000 10000 10000 10000 10000 10000 11111','10001 11011 10101 10101 10001 10001 10001','10001 11001 10101 10011 10001 10001 10001','01110 10001 10001 10001 10001 10001 01110','11110 10001 10001 11110 10000 10000 10000','01110 10001 10001 10001 10101 10010 01101','11110 10001 10001 11110 10100 10010 10001','01111 10000 10000 01110 00001 00001 11110','11111 00100 00100 00100 00100 00100 00100','10001 10001 10001 10001 10001 10001 01110','10001 10001 10001 10001 10001 01010 00100','10001 10001 10001 10101 10101 10101 01010','10001 10001 01010 00100 01010 10001 10001','10001 10001 01010 00100 00100 00100 00100','11111 00001 00010 00100 01000 10000 11111','01110 10001 10011 10101 11001 10001 01110','00100 01100 00100 00100 00100 00100 01110','01110 10001 00001 00010 00100 01000 11111','11110 00001 00001 01110 00001 00001 11110','00010 00110 01010 10010 11111 00010 00010','11111 10000 10000 11110 00001 00001 11110','01110 10001 10000 11110 10001 10001 01110','11111 00001 00010 00100 01000 01000 01000','01110 10001 10001 01110 10001 10001 01110','01110 10001 10001 01111 00001 00001 01110','00000 00000 11111 00000 00000 00000 00000','00000 00000 00000 00000 00000 00000 11111','00000 00000 00000 00000 00000 00000 00100','00100 00100 00100 00100 00100 00000 00100','00000 00000 00000 00000 00000 00000 00000'};
if isempty(strtrim(s)), error('fl_ft_watermark:text','请输入署名。'); end
p=zeros(7,6*numel(s)-1);
for k=1:numel(s)
    index=find(strcmp(keys,s(k)),1);
    if isempty(index), error('fl_ft_watermark:text','不支持字符 %s。',s(k)); end
    bits=rows{index}; bits=bits(bits~=' ');
    p(:,6*(k-1)+(1:5))=reshape(bits=='1',5,7).';
end
end
