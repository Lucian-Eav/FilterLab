function result = fl_ext_metrics(action, varargin)
%FL_EXT_METRICS Toolbox-free metrics. Images use a fixed unit dynamic range.
% SSIM follows Wang's 11-by-11, sigma=1.5 local luminance/contrast model.
% Calls and return fields
%   ('psnr',ref,test) returns dB; ('ssim',ref,test) returns local mean SSIM.
%   ('rgb_edge_shift',ref,test) returns Shift [row,col] per channel in pixels,
%       Max/RMS R-G and B-G displacement and normalized Correlation peaks.
%   ('background_uniformity',img,bgMask,fgMask[,before]) returns Std,
%       Contrast (background/foreground mean), Reduction (%) and Improvement.
%   ('profile_symmetry',profile) returns Score [0,1] and normalized L1/L2.
%   ('step_overshoot',b,a) returns Response, DC, Absolute and Percent.
%   ('gradient_sharpness',img) returns Sobel RMS and Mean magnitude.
%   ('ringing_index',ref,test[,edgeMask]) returns RMS high-frequency residual,
%       OvershootEnergy outside [0,1] and ResidualRMS in a nine-pixel edge band.
switch lower(char(action))
    case 'psnr'
        [x,y] = pair(varargin{:});
        mse = mean((x(:)-y(:)).^2);
        if mse == 0, result = Inf; else, result = -10*log10(mse); end
    case 'ssim'
        [x,y] = pair(varargin{:});
        width = min([11,size(x,1),size(x,2)]);
        if mod(width,2)==0, width=width-1; end
        t = -(width-1)/2:(width-1)/2;
        g = exp(-t.^2/(2*1.5^2)); g = g/sum(g);
        scores=zeros(1,size(x,3));
        for c=1:size(x,3)
            a=x(:,:,c); b=y(:,:,c);
            ux=smooth(a,g); uy=smooth(b,g);
            vx=max(0,smooth(a.^2,g)-ux.^2);
            vy=max(0,smooth(b.^2,g)-uy.^2);
            covxy=smooth(a.*b,g)-ux.*uy;
            s=((2*ux.*uy+.01^2).*(2*covxy+.03^2))./ ...
                ((ux.^2+uy.^2+.01^2).*(vx+vy+.03^2));
            scores(c)=mean(s(:));
        end
        result=mean(scores);
    case 'rgb_edge_shift'
        [x,y]=pair(varargin{:});
        shifts=zeros(size(x,3),2); peaks=zeros(size(x,3),1);
        for c=1:size(x,3)
            a=edge_gradient(x(:,:,c)); b=edge_gradient(y(:,:,c));
            [dr,dc,peaks(c)]=fl_shift(b,a);
            a=a-mean(a(:)); b=b-mean(b(:));
            corr=real(ifft2(fft2(b).*conj(fft2(a))));
            row=mod(dr,size(a,1))+1; col=mod(dc,size(a,2))+1;
            dy=parabola(corr(mod(row-2,size(a,1))+1,col),corr(row,col),corr(mod(row,size(a,1))+1,col));
            dx=parabola(corr(row,mod(col-2,size(a,2))+1),corr(row,col),corr(row,mod(col,size(a,2))+1));
            shifts(c,:)=[dr+dy,dc+dx];
        end
        if size(shifts,1)==3
            offsets=shifts([1 3],:)-shifts(2,:);
        else
            offsets=zeros(1,2);
        end
        distances=sqrt(sum(offsets.^2,2));
        result=struct('Shift',shifts,'Max',max(distances),'RMS',sqrt(mean(distances.^2)), ...
            'Offsets',offsets,'Correlation',peaks);
    case 'background_uniformity'
        gray=gray_image(varargin{1}); bg=logical(varargin{2}); fg=logical(varargin{3});
        if ~isequal(size(gray),size(bg),size(fg)) || ~any(bg(:)) || ~any(fg(:))
            error('fl_ext_metrics:mask','Background and foreground masks must be nonempty and match the image.');
        end
        result=struct('Std',std(gray(bg),1),'Contrast',mean(gray(bg))/max(mean(gray(fg)),eps), ...
            'Reduction',NaN,'Improvement',NaN);
        if numel(varargin)>3
            before=gray_image(varargin{4});
            result.Reduction=100*(1-result.Std/max(std(before(bg),1),eps));
            initialContrast=mean(before(bg))/max(mean(before(fg)),eps);
            result.Improvement=result.Contrast/initialContrast;
        end
    case 'profile_symmetry'
        p=double(varargin{1}(:));
        if isempty(p) || any(~isfinite(p)), error('fl_ext_metrics:profile','Expected a finite profile.'); end
        residual=p-flipud(p);
        scale=max(p)-min(p);
        l1=mean(abs(residual))/max(scale,eps);
        l2=sqrt(mean(residual.^2))/max(scale,eps);
        result=struct('Score',max(0,min(1,1-l1)),'L1',l1,'L2',l2);
    case 'step_overshoot'
        b=varargin{1}; a=varargin{2}; dc=sum(b)/sum(a);
        response=filter(b,a,ones(320,1));
        absolute=max(0,max(sign(dc)*response)-abs(dc));
        result=struct('Response',response,'DC',dc,'Absolute',absolute, ...
            'Percent',100*absolute/max(abs(dc),eps));
    case 'gradient_sharpness'
        [gx,gy]=sobel(gray_image(varargin{1})); magnitude=hypot(gx,gy);
        result=struct('RMS',sqrt(mean(magnitude(:).^2)),'Mean',mean(magnitude(:)));
    case 'ringing_index'
        [x,y]=pair(varargin{1:2});
        if numel(varargin)>2 && ~isempty(varargin{3})
            mask=logical(varargin{3});
        else
            grad=edge_gradient(gray_image(x)); mask=grad>max(grad(:))*.25;
        end
        band=conv2(double(mask),ones(9),'same')>0;
        residual=gray_image(y)-gray_image(x);
        if ~any(band(:)), band(:)=true; end
        high=residual-conv2(residual,ones(3)/9,'same');
        over=max(0,-y).^2+max(0,y-1).^2;
        over=mean(over,3);
        result=struct('RMS',sqrt(mean(high(band).^2)), ...
            'OvershootEnergy',mean(over(band)),'ResidualRMS',sqrt(mean(residual(band).^2)));
    otherwise
        error('fl_ext_metrics:action','Unknown metric %s.',char(action));
end
end

function [x,y]=pair(x,y)
if ~isequal(size(x),size(y)) || isempty(x) || ~isreal(x) || ~isreal(y)
    error('fl_ext_metrics:images','Metrics require equally sized real images.');
end
x=double(x); y=double(y);
if any(~isfinite(x(:))) || any(~isfinite(y(:)))
    error('fl_ext_metrics:finite','Images must be finite.');
end
end

function y=smooth(x,g)
y=conv2(conv2(x,g,'valid'),g','valid');
end

function g=gray_image(x)
x=double(x);
if size(x,3)==3, g=.2126*x(:,:,1)+.7152*x(:,:,2)+.0722*x(:,:,3); else, g=x; end
end

function [gx,gy]=sobel(x)
k=[1 0 -1;2 0 -2;1 0 -1]/8;
% Replicated boundary samples avoid artificial image-frame gradients.
x=x([1 1:end end],[1 1:end end]);
gx=conv2(x,k,'valid'); gy=conv2(x,k','valid');
end

function g=edge_gradient(x)
[gx,gy]=sobel(x); g=hypot(gx,gy);
end

function d=parabola(a,b,c)
den=a-2*b+c;
if abs(den)<=eps*max(1,abs(b)), d=0; else, d=max(-.5,min(.5,.5*(a-c)/den)); end
end
