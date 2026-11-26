function M=fl_photo_mask(outputSize,C,context)
%FL_PHOTO_MASK Rasterize original-anchored vector strokes after geometry.
h=outputSize(1); w=outputSize(2);
if ~C.MaskEnable, M=ones(h,w,'single'); return; end
[T,fullSize]=fl_mask_transform(context.OriginalSize,context.Geometry);
scale=[w/fullSize(2) h/fullSize(1)]; M=ones(h,w,'single')*single(C.MaskBase);
for k=1:numel(C.MaskStrokes)
    s=C.MaskStrokes{k}; p=.5+double(s.Points).*[context.OriginalSize(2) context.OriginalSize(1)];
    p=[p ones(size(p,1),1)]*T'; p=.5+(p(:,1:2)-.5).*scale;
    radius=s.Radius*min(context.OriginalSize(1:2))*min(scale); radius=max(.5,radius);
    p=densify(p,max(.5,radius*.22)); coverage=zeros(h,w,'single');
    for j=1:size(p,1)
        xr=max(1,floor(p(j,1)-radius)):min(w,ceil(p(j,1)+radius));
        yr=max(1,floor(p(j,2)-radius)):min(h,ceil(p(j,2)+radius));
        if isempty(xr)||isempty(yr), continue; end
        [xx,yy]=meshgrid(single(xr-p(j,1)),single(yr-p(j,2))); d=sqrt(xx.^2+yy.^2)/radius;
        if C.MaskSoftness<=0, alpha=single(d<=1);
        else, t=min(1,max(0,(1-d)/C.MaskSoftness)); alpha=t.^2.*(3-2*t); end
        coverage(yr,xr)=max(coverage(yr,xr),alpha);
    end
    alpha=coverage*single(s.Opacity);
    if strcmp(s.Mode,'erase'), M=M.*(1-alpha); else, M=M+(1-M).*alpha; end
end
if C.MaskInvert, M=1-M; end
M=min(1,max(0,M));
end
function p=densify(p,spacing)
if size(p,1)<2, return; end
out=p(1,:);
for k=2:size(p,1)
    n=max(1,ceil(norm(p(k,:)-p(k-1,:))/spacing)); t=(1:n)'/n;
    out=[out;p(k-1,:)+(p(k,:)-p(k-1,:)).*t]; %#ok<AGROW>
end
p=out;
end
