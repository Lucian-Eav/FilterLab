function T=fl_frequency_mask(imageSize,C)
%FL_FREQUENCY_MASK Real centrosymmetric FFT mask; frequencies are cycles/pixel.
h=imageSize(1); w=imageSize(2); T=ones(h,w,'single');
for k=1:numel(C.FrequencyStrokes)
    s=C.FrequencyStrokes{k}; points=double(s.Points);
    if size(points,1)>1
        dense=points(1,:);
        for j=2:size(points,1)
            n=max(1,ceil(norm(points(j,:)-points(j-1,:))/max(s.Radius*.25,1/max(h,w))));
            dense=[dense;points(j-1,:)+(points(j,:)-points(j-1,:)).*((1:n)'/n)]; %#ok<AGROW>
        end
        points=dense;
    end
    coverage=zeros(h,w,'single');
    for j=1:size(points,1)
        % Include periodic copies so a brush crossing Nyquist has no seam.
        for dx=-1:1
            for dy=-1:1
                px=(points(j,1)+dx)*w+floor(w/2)+1; py=(points(j,2)+dy)*h+floor(h/2)+1;
                xr=max(1,floor(px-s.Radius*w)):min(w,ceil(px+s.Radius*w));
                yr=max(1,floor(py-s.Radius*h)):min(h,ceil(py+s.Radius*h));
                if isempty(xr)||isempty(yr), continue; end
                [xx,yy]=meshgrid(single((xr-px)/w),single((yr-py)/h)); d=sqrt(xx.^2+yy.^2)/s.Radius;
                v=min(1,max(0,(1-d)/.65)); v=v.^2.*(3-2*v);
                coverage(yr,xr)=max(coverage(yr,xr),v);
            end
        end
    end
    unshift=ifftshift(coverage); iy=mod(-(0:h-1),h)+1; ix=mod(-(0:w-1),w)+1;
    coverage=fftshift(max(unshift,unshift(iy,ix)))*single(s.Opacity);
    if strcmp(s.Mode,'erase'), T=T+(1-T).*coverage; else, T=T.*(1-coverage); end
end
if C.FrequencyKeepDC, T(floor(h/2)+1,floor(w/2)+1)=1; end
end
