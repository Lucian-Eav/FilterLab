function Y = fl_photo_resize(X, maxEdge)
%FL_PHOTO_RESIZE  无工具箱抗混叠缩略图，最长边不超过 maxEdge，不放大。
validateattributes(maxEdge,{'numeric'},{'scalar','real','finite','integer','positive'});
if isempty(X) || ~isnumeric(X) || ~isreal(X) || ndims(X)~=3 || size(X,3)~=3
    error('fl_photo_resize:image','输入必须为 RGB 照片。');
end
X=single(X); [h,w,~]=size(X);
s=min(1,double(maxEdge)/double(max(h,w)));
if s==1, Y=X; return; end
nh=max(1,round(h*s)); nw=max(1,round(w*s));
% 缩小前低通，抑制细纹在缩略预览中混叠。边界复制而不填黑。
sigma=max(.5,.5/s); r=ceil(3*sigma);
x=single(-r:r); g=exp(-(x.^2)/(2*sigma^2)); g=g/sum(g);
i=min(h,max(1,(1-r):(h+r))); j=min(w,max(1,(1-r):(w+r)));
Y=zeros(nh,nw,3,'single');
xq=linspace(1,w,nw); yq=linspace(1,h,nh);
for c=1:3
    a=conv2(conv2(X(i,j,c),g,'valid'),g','valid');
    if h==1
        if w==1, Y(:,:,c)=a;
        else, Y(:,:,c)=interp1(1:w,a,xq,'linear'); end
    elseif w==1
        Y(:,:,c)=interp1((1:h)',a,yq','linear');
    else
        Y(:,:,c)=interp2(a,xq,yq','linear');
    end
end
Y=min(1,max(0,Y));
end
