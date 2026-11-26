function R=fl_ft_optics(img,opts)
%FL_FT_OPTICS Fraunhofer diffraction and geometric defocus, in linear light.
if nargin<1 || isempty(img), img=fl_ft_samples('night_lights'); end
if nargin<2, opts=struct(); end
p=inputParser;
p.addParameter('Effect','starburst'); p.addParameter('Aperture','');
p.addParameter('Threshold',.78); p.addParameter('Intensity',.85);
p.addParameter('Size',[]); p.addParameter('RotationDeg',15);
p.addParameter('Dispersion',true); p.addParameter('CustomAperture',[]);
p.parse(opts); o=p.Results;
img=fl_ft_samples('normalize',img,flintmax);
if iscell(img)
    if numel(img)~=1, error('fl_ft_optics:image','请选择一张夜景照。'); end
    img=img{1};
end
o.Effect=validatestring(o.Effect,{'starburst','bokeh'});
starburst=strcmp(o.Effect,'starburst');
if starburst
    shapes={'hex6','oct8','pent5','cross4'}; defaultSize=45;
else
    shapes={'heart','star','hexagon','ring','custom'}; defaultSize=15;
end
if isempty(o.Aperture), o.Aperture=shapes{1}; end
if isempty(o.Size), o.Size=defaultSize; end
o.Aperture=validatestring(o.Aperture,shapes);
validateattributes(o.Size,{'numeric'},{'scalar','integer','>=',3,'<=',161});
validateattributes(o.Threshold,{'numeric'},{'scalar','real','>=',.4,'<=',.98});
validateattributes(o.Intensity,{'numeric'},{'scalar','real','>=',0,'<=',2.5});
validateattributes(o.RotationDeg,{'numeric'},{'scalar','real','finite'});
validateattributes(o.Dispersion,{'numeric','logical'},{'scalar','binary'});
if starburst
    % Sample straight pupil edges on a finer grid than the output PSF.
    P=aperture_mask(o,241);
    pad=512;
    diffraction=abs(fftshift(fft2(P,pad,pad))).^2;
    radius=floor(o.Size/2);
    idx=floor(pad/2)+1+(-radius:radius);
    [x,y]=meshgrid(-radius:radius);
    r=hypot(x,y);
    % Suppress the central lobe smoothly and compress the diffraction wings.
    K=diffraction(idx,idx).^.76 .* (1-exp(-(r/3).^4));
else
    P=aperture_mask(o,2*o.Size+1);
    K=P;
end
if ~any(K(:)), error('fl_ft_optics:aperture','孔径没有透光像素。'); end
K=K/sum(K(:)); kernels=repmat(K,1,1,3);
if starburst && o.Dispersion
    scales=[1.06 1 .94];
    for c=[1 3]
        channel=interp2(x,y,K,x/scales(c),y/scales(c),'linear',0);
        kernels(:,:,c)=channel/sum(channel(:));
    end
end
linear=img.^2.2; L=fl_ft_luma(linear);
gate=(max(0,L-o.Threshold)/(1-o.Threshold)).^1.6;
highlights=linear.*gate; glow=zeros(size(img));
for c=1:3
    glow(:,:,c)=linear_convolve(highlights(:,:,c),kernels(:,:,c));
end
% A shoulder on the added light preserves the input tone at zero exposure.
room=1-linear; extra=-room.*expm1(-o.Intensity*glow./max(room,eps));
output=min(1,(linear+extra).^(1/2.2));
if o.Intensity==0, output=img; end
dark=L<.02; delta=fl_ft_luma(output-img);
if any(dark(:)), darkError=mean(abs(delta(dark))); else, darkError=NaN; end
m=struct('HighlightFraction',mean(gate(:)>0),'GlowEnergy',sum(glow(:)), ...
    'EnergyIncrease',mean(extra(:)),'DarkBackgroundError',darkError, ...
    'PSFSize',size(K,1),'Effect',o.Effect,'Aperture',o.Aperture);
preview=log1p(200*kernels/max(kernels(:)))/log(201);
R=struct('Output',output,'Aperture',P,'PSF',preview,'PSFKernel',K, ...
    'ChannelKernels',kernels,'Highlights',highlights,'Glow',glow,'Metrics',m,'Options',o);
end

function P=aperture_mask(o,n)
t=linspace(-1,1,n); [x,y]=meshgrid(t);
u=x*cosd(o.RotationDeg)+y*sind(o.RotationDeg);
v=y*cosd(o.RotationDeg)-x*sind(o.RotationDeg);
switch o.Aperture
    case {'hex6','hexagon','oct8','pent5','cross4'}
        switch o.Aperture
            case 'oct8', sides=8;
            case 'pent5', sides=5;
            case 'cross4', sides=4;
            otherwise, sides=6;
        end
        % Zero rotation puts the outward normal to one blade on +x.
        angle=mod(atan2d(v,u)+180/sides,360/sides)-180/sides;
        P=hypot(u,v).*cosd(angle)<=.92*cosd(180/sides);
    case 'heart'
        a=u/.78; b=-v/.78;
        P=(a.^2+b.^2-1).^3<=a.^2.*b.^3;
    case 'star'
        angles=-90+(0:9)*36; radii=repmat([.94 .4],1,5);
        P=inpolygon(u,v,radii.*cosd(angles),radii.*sind(angles));
    case 'ring'
        r=hypot(u,v); P=r>=.48 & r<=.9;
    case 'custom'
        if isempty(o.CustomAperture), error('fl_ft_optics:custom','请选择黑白光圈图。'); end
        a=fl_ft_samples('normalize',o.CustomAperture,512);
        if iscell(a), a=a{1}; end
        a=fl_ft_luma(a); [h,w]=size(a);
        if min(h,w)<2, error('fl_ft_optics:custom','光圈图至少需要两行两列。'); end
        scale=max(h-1,w-1)/2;
        P=interp2(a,(w+1)/2+scale*u,(h+1)/2+scale*v,'linear',0)>.5;
end
P=double(P);
end

function out=linear_convolve(a,k)
[h,w]=size(a); [kh,kw]=size(k);
fftSize=2.^nextpow2([h+kh-1,w+kw-1]);
F=fft2(a,fftSize(1),fftSize(2)).*fft2(k,fftSize(1),fftSize(2));
full=real(ifft2(F));
out=max(0,full(floor(kh/2)+(1:h),floor(kw/2)+(1:w)));
end
