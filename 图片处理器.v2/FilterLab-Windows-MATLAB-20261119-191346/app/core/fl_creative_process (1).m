function [Y,details]=fl_creative_process(X,C,context)
%FL_CREATIVE_PROCESS Luminance frequency/classic filters, tilt-shift, motion.
% X: finite single/double RGB [0,1]. Spatial radii are full-resolution pixels.
if nargin<2, C=fl_creative_spec(); else, C=fl_creative_spec(C); end
if nargin<3, context=struct('OriginalSize',size(X),'Geometry',{{}}); end
validateattributes(X,{'single','double'},{'real','finite','nonempty','>=',0,'<=',1});
if ndims(X)~=3||size(X,3)~=3, error('fl_creative_process:rgb','需要 RGB 图像。'); end
Y=single(X); h=size(X,1); w=size(X,2); details=struct();
[~,fullSize]=fl_mask_transform(context.OriginalSize,context.Geometry); scale=min(h/fullSize(1),w/fullSize(2));
if ~strcmp(C.ClassicType,'off')&&C.ClassicAmount>0
    persistent filters
    if isempty(filters), filters=fl_assignment_design(); end
    kinds={'butter10','fir4','fir12'}; f=filters(strcmp(C.ClassicType,kinds)); b=f.B; a=f.A;
    b=b/(sum(b)/sum(a)); L=luma(Y); pad=96;
    yi=min(h,max(1,(1-pad):(h+pad))); xi=min(w,max(1,(1-pad):(w+pad))); z=double(L(yi,xi));
    z=filter(b,a,filter(b,a,z,[],2),[],1); z=flip(flip(z,1),2);
    z=filter(b,a,filter(b,a,z,[],2),[],1); z=flip(flip(z,1),2);
    z=single(z(pad+(1:h),pad+(1:w))); Y=min(1,max(0,Y+(z-L)*single(C.ClassicAmount)));
end
if C.FrequencyEnable&&~isempty(C.FrequencyStrokes)
    L=luma(Y); T=fl_frequency_mask([h w],C); z=ifft2(fft2(L).*ifftshift(T));
    details.ImaginaryResidual=max(abs(imag(z(:))));
    Y=min(1,max(0,Y+real(z)-L));
end
if C.TiltEnable&&C.TiltBlur>0
    [xx,yy]=meshgrid(single((1:w)-(.5+C.TiltCenter(1)*w)),single((1:h)-(.5+C.TiltCenter(2)*h)));
    d=abs(-sind(C.TiltAngle)*xx+cosd(C.TiltAngle)*yy)/min(h,w);
    alpha=min(1,max(0,(d-C.TiltWidth/2)/C.TiltFeather)); alpha=alpha.^2.*(3-2*alpha);
    blurred=gaussian(Y,max(.01,C.TiltBlur*scale)); Y=Y+(blurred-Y).*alpha;
end
if C.MotionEnable&&C.MotionAmount>0
    blurred=motion(Y,C,scale); Y=Y+(blurred-Y)*single(C.MotionAmount);
end
Y=min(1,max(0,Y));
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
elseif strcmp(C.MotionType,'zoom'), travel=C.MotionZoom*max(h,w);
else, travel=C.MotionSpin*pi/180*max(h,w)/2; end
if travel<=eps, Y=X; return; end
% Bounded quadrature cost. Smooth motions over long distances are sampled.
n=min(41,max(3,2*ceil(travel/3)+1)); ts=linspace(-.5,.5,n);
[xx,yy]=meshgrid(single(1:w),single(1:h)); cx=.5+C.MotionCenter(1)*w; cy=.5+C.MotionCenter(2)*h;
Y=zeros(size(X),'single');
for t=ts
    switch C.MotionType
        case 'directional', qx=xx+t*travel*cosd(C.MotionAngle); qy=yy+t*travel*sind(C.MotionAngle);
        case 'zoom', factor=1+t*C.MotionZoom; qx=cx+(xx-cx)*factor; qy=cy+(yy-cy)*factor;
        case 'spin', angle=t*C.MotionSpin; qx=cx+(xx-cx)*cosd(angle)-(yy-cy)*sind(angle); qy=cy+(xx-cx)*sind(angle)+(yy-cy)*cosd(angle);
    end
    qx=min(w,max(1,qx)); qy=min(h,max(1,qy)); x0=floor(qx); y0=floor(qy);
    x1=min(w,x0+1); y1=min(h,y0+1); dx=qx-x0; dy=qy-y0;
    i00=y0+(x0-1)*h; i10=y0+(x1-1)*h; i01=y1+(x0-1)*h; i11=y1+(x1-1)*h;
    for c=1:3
        v=X(:,:,c); sampled=(1-dy).*((1-dx).*v(i00)+dx.*v(i10))+dy.*((1-dx).*v(i01)+dx.*v(i11));
        Y(:,:,c)=Y(:,:,c)+sampled/single(n);
    end
end
end
