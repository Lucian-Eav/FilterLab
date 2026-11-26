function rect = fl_photo_crop_rect(imageSize, anchor, point, ratio)
%FL_PHOTO_CROP_RECT  从原尺寸像素坐标求有界的自由/固定比例裁剪框。
% imageSize=[height width]，anchor/point=[x y]，ratio=width/height，0 为自由。
% 返回 1 起始 [x y width height]；固定比例允许整数像素舍入误差。
validateattributes(imageSize,{'numeric'},{'real','finite','vector','numel',2,'integer','positive'});
validateattributes(anchor,{'numeric'},{'real','finite','vector','numel',2});
validateattributes(point,{'numeric'},{'real','finite','vector','numel',2});
validateattributes(ratio,{'numeric'},{'real','finite','scalar','nonnegative'});
h=double(imageSize(1)); w=double(imageSize(2));
a=min([w h],max([1 1],round(double(anchor(:)'))));
p=min([w h],max([1 1],round(double(point(:)'))));
direction=sign(p-a); direction(direction==0)=1;
maxW=w-a(1)+1; if direction(1)<0, maxW=a(1); end
maxH=h-a(2)+1; if direction(2)<0, maxH=a(2); end
cw=abs(p(1)-a(1))+1; ch=abs(p(2)-a(2))+1;
if ratio>0
    if cw/ch>ratio, ch=cw/ratio; else, cw=ch*ratio; end
    scale=min([1 maxW/cw maxH/ch]); cw=cw*scale; ch=ch*scale;
end
cw=min(maxW,max(1,round(cw))); ch=min(maxH,max(1,round(ch)));
x=a(1); if direction(1)<0, x=x-cw+1; end
y=a(2); if direction(2)<0, y=y-ch+1; end
rect=[x y cw ch];
end
