function [Y,details]=fl_creative_process(X,C,context)
%FL_CREATIVE_PROCESS Luminance frequency/classic filters, tilt-shift, motion.
% X: finite single/double RGB [0,1]. Spatial radii are full-resolution pixels.
persistent classicMemo tiltMemo motionMemo
if nargin<2, C=fl_creative_spec(); else, C=fl_creative_spec(C); end
if nargin<3, context=struct('OriginalSize',size(X),'Geometry',{{}}); end
validateattributes(X,{'single','double'},{'real','finite','nonempty','>=',0,'<=',1});
if ndims(X)~=3||size(X,3)~=3, error('fl_creative_process:rgb','需要 RGB 图像。'); end
Y=single(X); h=size(X,1); w=size(X,2); details=struct();
[~,fullSize]=fl_mask_transform(context.OriginalSize,context.Geometry); scale=min(h/fullSize(1),w/fullSize(2));
% Limit retained intermediates. The exact incoming pixels are part of every
% key, so changes in upstream stages always invalidate downstream responses.
keep=h*w<=2*1024^2;
if ~keep, classicMemo=[]; tiltMemo=[]; motionMemo=[]; end
if ~strcmp(C.ClassicType,'off')&&C.ClassicAmount>0
    if matches(classicMemo,Y,C.ClassicType)
        delta=classicMemo.value;
    else
        delta=classic_response(Y,C.ClassicType);
        if keep, classicMemo=struct('source',Y,'key',C.ClassicType,'value',delta); end
    end
    Y=min(1,max(0,Y+delta*single(C.ClassicAmount)));
end
if C.FrequencyEnable&&~isempty(C.FrequencyStrokes)
    L=luma(Y); T=fl_frequency_mask([h w],C); z=ifft2(fft2(L).*ifftshift(T));
    details.ImaginaryResidual=max(abs(imag(z(:))));
    Y=min(1,max(0,Y+real(z)-L));
end
if C.TiltEnable&&C.TiltBlur>0
    xx=single((1:w)-(.5+C.TiltCenter(1)*w)); yy=single((1:h)'-(.5+C.TiltCenter(2)*h));
    d=abs(-sind(C.TiltAngle)*xx+cosd(C.TiltAngle)*yy)/min(h,w);
    alpha=min(1,max(0,(d-C.TiltWidth/2)/C.TiltFeather)); alpha=alpha.^2.*(3-2*alpha);
    sigma=max(.01,C.TiltBlur*scale);
    if matches(tiltMemo,Y,sigma)
        blurred=tiltMemo.value;
    else
        blurred=gaussian(Y,sigma);
        if keep, tiltMemo=struct('source',Y,'key',sigma,'value',blurred); end
    end
    Y=Y+(blurred-Y).*alpha;
end
if C.MotionEnable&&C.MotionAmount>0
    key={C.MotionType,C.MotionLength,C.MotionAngle,C.MotionCenter,C.MotionZoom,C.MotionSpin,scale};
    if matches(motionMemo,Y,key)
        blurred=motionMemo.value;
    else
        blurred=motion(Y,C,scale);
        if keep, motionMemo=struct('source',Y,'key',{key},'value',blurred); end
    end
    Y=Y+(blurred-Y)*single(C.MotionAmount);
end
Y=min(1,max(0,Y));
end
function tf=matches(memo,source,key)
tf=~isempty(memo) && isequal(memo.key,key) && isequal(memo.source,source);
end
function delta=classic_response(Y,kind)
persistent filters
h=size(Y,1); w=size(Y,2);
if isempty(filters), filters=fl_assignment_design(); end
kinds={'butter10','fir4','fir12'}; f=filters(strcmp(kind,kinds)); b=f.B; a=f.A;
b=b/(sum(b)/sum(a)); L=luma(Y); pad=96;
yi=min(h,max(1,(1-pad):(h+pad))); xi=min(w,max(1,(1-pad):(w+pad))); z=double(L(yi,xi));
z=filter(b,a,filter(b,a,z,[],2),[],1); z=flip(flip(z,1),2);
z=filter(b,a,filter(b,a,z,[],2),[],1); z=flip(flip(z,1),2);
delta=single(z(pad+(1:h),pad+(1:w)))-L;
end
function L=luma(X)
L=.2126*X(:,:,1)+.7152*X(:,:,2)+.0722*X(:,:,3);
end
function Y=gaussian(X,sigma)
r=max(1,ceil(3*sigma)); t=single(-r:r); k=exp(-t.^2/(2*sigma^2)); k=k/sum(k);
h=size(X,1); w=size(X,2); Y=zeros(size(X),'single');
yi=min(h,max(1,(1-r):(h+r))); xi=min(w,max(1,(1-r):(w+r)));
for c=1:3, Y(:,:,c)=conv2(k',k,X(yi,xi,c),'valid'); end
end
function Y=motion(X,C,scale)
h=size(X,1); w=size(X,2);
if strcmp(C.MotionType,'directional')
    travel=C.MotionLength*scale;
elseif strcmp(C.MotionType,'zoom')
    travel=C.MotionZoom*max(h,w);
else
    travel=C.MotionSpin*pi/180*max(h,w)/2;
end
if travel<=eps, Y=X; return; end
% Bounded quadrature cost. Smooth motions over long distances are sampled.
n=min(41,max(3,2*ceil(travel/3)+1)); ts=linspace(-.5,.5,n);
cx=.5+C.MotionCenter(1)*w; cy=.5+C.MotionCenter(2)*h;
isSpin=strcmp(C.MotionType,'spin'); isZoom=strcmp(C.MotionType,'zoom');
if isSpin
    cs=cosd(ts*C.MotionSpin); sn=sind(ts*C.MotionSpin);
elseif ~isZoom
    shiftX=ts*travel*cosd(C.MotionAngle); shiftY=ts*travel*sind(C.MotionAngle);
end
% Directional and zoom queries are separable. Preserve the original single
% linear-index rounding on very large images and for the nonseparable spin.
useLinear=isSpin || h*w>double(flintmax('single'));
if useLinear, planes={X(:,:,1),X(:,:,2),X(:,:,3)}; end
% Accumulate all samples in a cache-sized column strip before moving on.
colsPerStrip=max(1,floor(131072/h)); yy=single((1:h)'); Y=zeros(size(X),'single');
for first=1:colsPerStrip:w
    cols=first:min(w,first+colsPerStrip-1); xx=single(cols);
    band=zeros(h,numel(cols),3,'single');
    for j=1:n
        if isSpin
            qx=cx+(xx-cx)*cs(j)-(yy-cy)*sn(j);
            qy=cy+(xx-cx)*sn(j)+(yy-cy)*cs(j);
        elseif isZoom
            factor=1+ts(j)*C.MotionZoom; qx=cx+(xx-cx)*factor; qy=cy+(yy-cy)*factor;
        else
            qx=xx+shiftX(j); qy=yy+shiftY(j);
        end
        qx=min(w,max(1,qx)); qy=min(h,max(1,qy)); x0=floor(qx); y0=floor(qy);
        x1=min(w,x0+1); y1=min(h,y0+1); dx=qx-x0; dy=qy-y0;
        wx=1-dx; wy=1-dy;
        if useLinear
            i00=y0+(x0-1)*h; i10=y0+(x1-1)*h; i01=y1+(x0-1)*h; i11=y1+(x1-1)*h;
        end
        for c=1:3
            if useLinear
                v=planes{c}; sampled=wy.*(wx.*v(i00)+dx.*v(i10))+dy.*(wx.*v(i01)+dx.*v(i11));
            elseif ~isZoom && shiftY(j)==0
                % Exactly horizontal: vertical weights are identically 1 and 0.
                sampled=wx.*X(:,x0,c)+dx.*X(:,x1,c);
            elseif ~isZoom && shiftX(j)==0
                sampled=wy.*X(y0,cols,c)+dy.*X(y1,cols,c);
            else
                sampled=wy.*(wx.*X(y0,x0,c)+dx.*X(y0,x1,c))+dy.*(wx.*X(y1,x0,c)+dx.*X(y1,x1,c));
            end
            band(:,:,c)=band(:,:,c)+sampled/single(n);
        end
    end
    Y(:,cols,:)=band;
end
end
