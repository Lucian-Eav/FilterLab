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
    p=densify(p,max(.5,radius*.22));
    % A single stroke only changes its clipped bounding rectangle.
    x0=max(1,floor(min(p(:,1))-radius)); x1=min(w,ceil(max(p(:,1))+radius));
    y0=max(1,floor(min(p(:,2))-radius)); y1=min(h,ceil(max(p(:,2))+radius));
    if x1<x0 || y1<y0, continue; end
    coverage=zeros(y1-y0+1,x1-x0+1,'single');
    for j=1:size(p,1)
        xr=max(1,floor(p(j,1)-radius)):min(w,ceil(p(j,1)+radius));
        yr=max(1,floor(p(j,2)-radius)):min(h,ceil(p(j,2)+radius));
        if isempty(xr)||isempty(yr), continue; end
        xx=single(xr-p(j,1)); yy=single(yr'-p(j,2)); d=sqrt(xx.^2+yy.^2)/radius;
        if C.MaskSoftness<=0, alpha=single(d<=1);
        else, t=min(1,max(0,(1-d)/C.MaskSoftness)); alpha=t.^2.*(3-2*t); end
        rr=yr-y0+1; cc=xr-x0+1; coverage(rr,cc)=max(coverage(rr,cc),alpha);
    end
    alpha=coverage*single(s.Opacity);
    region=M(y0:y1,x0:x1);
    if strcmp(s.Mode,'erase'), region=region.*(1-alpha); else, region=region+(1-region).*alpha; end
    M(y0:y1,x0:x1)=region;
end
if C.MaskInvert, M=1-M; end
M=min(1,max(0,M));
end
function p=densify(p,spacing)
if size(p,1)<2, return; end
parts=cell(size(p,1),1); parts{1}=p(1,:);
for k=2:size(p,1)
    n=max(1,ceil(norm(p(k,:)-p(k-1,:))/spacing)); t=(1:n)'/n;
    parts{k}=p(k-1,:)+(p(k,:)-p(k-1,:)).*t;
end
p=vertcat(parts{:});
end
