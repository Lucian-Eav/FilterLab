function [X, meta] = fl_photo_load(path)
%FL_PHOTO_LOAD  读取 sRGB 照片，保留颜色、纠正 EXIF 方向。
% [X,META] = fl_photo_load(PATH) 返回 single RGB [0,1]。
% 支持 JPEG/PNG/TIFF/BMP；灰度扩展为 RGB，透明区域合成到白色。
% 本版不执行 ICC 色彩转换。非 sRGB 图片请先在原软件转换到 sRGB。
if ~(ischar(path) || (isstring(path) && isscalar(path)))
    error('fl_photo_load:path', '请提供一个图像文件路径。');
end
path = char(path);
if exist(path, 'file') ~= 2
    error('fl_photo_load:notFound', '照片不存在：%s', path);
end
[~,~,ext] = fileparts(path);
if ~any(strcmpi(ext, {'.jpg','.jpeg','.png','.tif','.tiff','.bmp'}))
    error('fl_photo_load:format', '请使用 JPEG、PNG、TIFF 或 BMP 照片。');
end
allInfo = imfinfo(path); info = allInfo(1);
alpha = [];
if strcmpi(ext, '.png')
    [A, map, alpha] = imread(path);
else
    [A, map] = imread(path);
end
sourceClass = class(A);
if ~isempty(map)
    idx = double(A);
    if isinteger(A) || islogical(A), idx = idx + 1; end
    if any(idx(:)<1 | idx(:)>size(map,1) | idx(:)~=fix(idx(:)))
        error('fl_photo_load:indexed', '索引色图片包含无效颜色索引。');
    end
    X = reshape(single(map(idx(:),1:3)), [size(A,1),size(A,2),3]);
else
    X = unit_pixels(A);
    if ismatrix(X)
        X = repmat(X,1,1,3);
    elseif size(X,3) ~= 3
        error('fl_photo_load:channels', '此图像不是 RGB 或灰度图。请先将 CMYK/多通道图转换为 sRGB。');
    end
end
hasAlpha = ~isempty(alpha);
if hasAlpha
    a = unit_pixels(alpha);
    if ~isequal(size(a), [size(X,1),size(X,2)])
        error('fl_photo_load:alpha', '图片透明通道尺寸无效。');
    end
    X = X .* a + (1-a);
end
orientation = 1;
if isfield(info,'Orientation') && isnumeric(info.Orientation) && isscalar(info.Orientation)
    orientation = double(info.Orientation);
end
switch orientation
    case 2, X = X(:,end:-1:1,:);
    case 3, X = X(end:-1:1,end:-1:1,:);
    case 4, X = X(end:-1:1,:,:);
    case 5, X = permute(X,[2 1 3]);
    case 6, X = rot90(X,-1);
    case 7, X = permute(X(end:-1:1,end:-1:1,:),[2 1 3]);
    case 8, X = rot90(X,1);
end
[ok, attr] = fileattrib(path);
if ok, path = attr.Name; end
meta = struct('Source',path,'Width',size(X,2),'Height',size(X,1), ...
    'SourceClass',sourceClass,'Orientation',orientation, ...
    'OrientationApplied',ismember(orientation,2:8),'HadAlpha',hasAlpha, ...
    'ProfileNote','按 sRGB 解释；本版不执行 ICC 配置转换', ...
    'ColorSpace','sRGB','BitDepth',info.BitDepth);
if numel(allInfo) > 1
    meta.ProfileNote = [meta.ProfileNote '；多页图像仅读取第一页'];
end
end

function X = unit_pixels(A)
if isa(A,'uint8')
    X = single(A)/255;
elseif isa(A,'uint16')
    X = single(A)/65535;
elseif islogical(A)
    X = single(A);
elseif isa(A,'single') || isa(A,'double')
    X = single(A);
else
    error('fl_photo_load:pixelType','不支持此像素类型，请转换为 8/16 位 RGB 图像。');
end
if any(~isfinite(X(:))) || any(X(:)<0 | X(:)>1)
    error('fl_photo_load:range','浮点图像必须是有限的 [0,1] 数值。');
end
end
