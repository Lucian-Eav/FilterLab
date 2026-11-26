function [Y, info, stages] = fl_photo_process(X, S)
%FL_PHOTO_PROCESS Nonaccumulating sRGB color, guided denoise and multiscale detail.
% Optional stages are signed luma differences: before/after denoise, detail gain.
% Noise estimates are heuristics on native tiles, not calibrated sensor noise.
timer=tic;
if nargin<2, S=fl_photo_spec(); else, S=fl_photo_spec(S); end
if ~((isa(X,'single')||isa(X,'double'))&&isreal(X)&&~isempty(X)&&ndims(X)==3&&size(X,3)==3) ...
        || any(~isfinite(X(:))) || any(X(:)<0|X(:)>1)
    error('fl_photo_process:input','输入必须为 [0,1] 的有限 single/double RGB 图像。');
end
Y=single(X); gains=single([1 1 1]); colorClip=0; stages=struct();
if S.ColorEnable
    gains=single(S.WB).*single([exp(S.Temperature*.003+S.Tint*.001), ...
        exp(-S.Tint*.002),exp(-S.Temperature*.003+S.Tint*.001)]);
    if S.AutoWB, gains=gains.*auto_white(Y); end
    if any(abs(gains-1)>1e-7)||S.Exposure~=0
        L=decode_srgb(Y); L=L.*reshape(gains,1,1,3)*single(2^S.Exposure);
        colorClip=nnz(any(L<0|L>1,3))/(size(L,1)*size(L,2));
        Y=encode_srgb(min(1,max(0,L))); clear L;
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
noise=fl_photo_noise(Y); effective=S;
if S.AutoNoise
    effective.LumaDenoise=noise.LumaStrength;
    effective.ColorDenoise=noise.ColorStrength;
    effective.SharpenThreshold=max(S.SharpenThreshold,noise.Threshold);
end
denoise=S.DenoiseEnable && (effective.LumaDenoise>0||effective.ColorDenoise>0);
if nargout>2 || denoise, lum=luma(Y); end
if nargout>2, before=lum; end
if denoise
    cr=Y(:,:,1)-lum; cb=Y(:,:,3)-lum;
    r=2+round(4*max(effective.LumaDenoise,effective.ColorDenoise));
    mu=box_mean(lum,r); variance=max(0,box_mean(lum.*lum,r)-mu.*mu);
    if effective.LumaDenoise>0
        ep=single((.008+.07*effective.LumaDenoise)^2*(1-.6*S.Detail));
        a=variance./(variance+ep); b=mu-a.*mu;
        smooth=box_mean(a,r).*lum+box_mean(b,r);
        outLum=lum+single(effective.LumaDenoise)*(smooth-lum);
    else
        outLum=lum;
    end
    if effective.ColorDenoise>0
        ep=single((.025+.12*effective.ColorDenoise)^2);
        cr=guided_chroma(cr,lum,mu,variance,r,ep,effective.ColorDenoise);
        cb=guided_chroma(cb,lum,mu,variance,r,ep,effective.ColorDenoise);
    end
    delta=cat(3,cr,-(single(.2126)*cr+single(.0722)*cb)/single(.7152),cb);
    Y=compose(outLum,delta);
end
if nargout>2
    if denoise, denoised=luma(Y); else, denoised=before; end
    stages.DenoiseResidual=before-denoised; clear before;
end
if S.SharpenEnable && any([S.SharpenAmount S.FineDetail S.Clarity S.LocalContrast]~=0)
    if nargout>2, lum=denoised; else, lum=luma(Y); end
    target=lum;
    if S.SharpenAmount~=0
        detail=soft(lum-gaussian_blur(lum,S.SharpenRadius),effective.SharpenThreshold);
        target=lum+single(S.SharpenAmount)*detail;
    end
    % Adjacent bands share their edge-aware base. Build only the bases used.
    if S.FineDetail~=0 || S.Clarity~=0, b1=edge_base(lum,2,.0004); end
    if S.FineDetail~=0
        target=target+single(S.FineDetail)*soft(lum-b1,effective.SharpenThreshold);
    end
    if S.Clarity~=0 || S.LocalContrast~=0, b2=edge_base(lum,6,.0016); end
    if S.Clarity~=0
        target=target+single(S.Clarity)*soft(b1-b2,effective.SharpenThreshold*.5);
    end
    if S.LocalContrast~=0
        b3=edge_base(lum,18,.004);
        target=target+single(S.LocalContrast)*soft(b2-b3,effective.SharpenThreshold*.25);
    end
    [lo,hi]=local_envelope(lum);
    % Scale allowed overshoot by edge contrast, available headroom and noise.
    contrast=hi-lo; headroom=min(lum,1-lum);
    allowance=(single(.003)+single(.08)*contrast).*min(1,headroom/single(.08));
    allowance=allowance*single(1-.9*S.HaloSuppression)/single(1+8*noise.SigmaLuma);
    target=min(hi+allowance,max(lo-allowance,target));
    Y=compose(min(1,max(0,target)),Y-lum);
end
Y=min(1,max(0,Y));
if nargout>2, stages.DetailResidual=luma(Y)-denoised; end
info=struct('ElapsedSeconds',toc(timer),'ClippedFraction',colorClip, ...
    'WhiteBalanceGains',double(gains),'ColorSpace','sRGB','Noise',noise, ...
    'EffectiveLumaDenoise',effective.LumaDenoise,'EffectiveColorDenoise',effective.ColorDenoise, ...
    'EffectiveThreshold',effective.SharpenThreshold, ...
    'Method','guided denoise / edge-aware multiscale / adaptive halo limiter');
end
function y=soft(x,t)
y=sign(x).*max(0,abs(x)-single(t));
end
function y=luma(x)
y=single(.2126)*x(:,:,1)+single(.7152)*x(:,:,2)+single(.0722)*x(:,:,3);
end
function y=compose(lum,delta)
pos=max(delta,[],3); neg=max(-delta,[],3);
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
