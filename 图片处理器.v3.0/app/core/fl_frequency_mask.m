function T=fl_frequency_mask(imageSize,C,T)
%FL_FREQUENCY_MASK Real centrosymmetric FFT mask; frequencies are cycles/pixel.
% An optional initial mask lets a display cache apply only appended strokes.
h=imageSize(1); w=imageSize(2);
if nargin<3, T=ones(h,w,'single'); end
% Conjugate-bin partners directly in fftshift coordinates (odd/even sizes).
iy=mod(2*floor(h/2)-(0:h-1),h)+1; ix=mod(2*floor(w/2)-(0:w-1),w)+1;
for k=1:numel(C.FrequencyStrokes)
    s=C.FrequencyStrokes{k}; points=double(s.Points);
    if size(points,1)>1
        parts=cell(size(points,1),1); parts{1}=points(1,:);
        for j=2:size(points,1)
            n=max(1,ceil(norm(points(j,:)-points(j-1,:))/max(s.Radius*.25,1/max(h,w))));
            parts{j}=points(j-1,:)+(points(j,:)-points(j-1,:)).*((1:n)'/n);
        end
        points=vertcat(parts{:});
    end
    coverage=zeros(h,w,'single');
    for j=1:size(points,1)
        % Include periodic copies so a brush crossing Nyquist has no seam.
        for dx=-1:1
            px=(points(j,1)+dx)*w+floor(w/2)+1;
            xr=max(1,floor(px-s.Radius*w)):min(w,ceil(px+s.Radius*w));
            if isempty(xr), continue; end
            xx=single((xr-px)/w);
            for dy=-1:1
                py=(points(j,2)+dy)*h+floor(h/2)+1;
                yr=max(1,floor(py-s.Radius*h)):min(h,ceil(py+s.Radius*h));
                if isempty(yr), continue; end
                yy=single((yr'-py)/h); d=sqrt(xx.^2+yy.^2)/s.Radius;
                v=min(1,max(0,(1-d)/.65)); v=v.^2.*(3-2*v);
                coverage(yr,xr)=max(coverage(yr,xr),v);
            end
        end
    end
    coverage=max(coverage,coverage(iy,ix))*single(s.Opacity);
    if strcmp(s.Mode,'erase'), T=T+(1-T).*coverage; else, T=T.*(1-coverage); end
end
if C.FrequencyKeepDC, T(floor(h/2)+1,floor(w/2)+1)=1; end
end
