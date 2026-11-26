function fl_photo_save(path, X, meta, varargin)
%FL_PHOTO_SAVE  保存照片像素，不导出坐标区，不覆盖输入或已有文件。
% fl_photo_save(PATH,X,META,'Quality',95,'BitDepth',8)
% PNG/TIFF 支持 8/16 位；JPEG 支持 8 位和 Quality=1..100。
% 输出为 sRGB 数值，不复制原 EXIF/ICC，避免重复旋转与错误配置。
opt = struct('Quality',95,'BitDepth',8);
if mod(numel(varargin),2), error('fl_photo_save:args','选项必须成对。'); end
for k=1:2:numel(varargin)
    nm=char(varargin{k});
    if ~isfield(opt,nm), error('fl_photo_save:option','未知导出选项：%s',nm); end
    opt.(nm)=varargin{k+1};
end
validateattributes(opt.Quality,{'numeric'},{'scalar','real','finite','>=',1,'<=',100});
if ~isscalar(opt.BitDepth) || ~ismember(opt.BitDepth,[8 16])
    error('fl_photo_save:depth','导出位深必须为 8 或 16。');
end
if ~(ischar(path) || (isstring(path)&&isscalar(path)))
    error('fl_photo_save:path','请提供导出文件路径。');
end
path=char(path);
if isempty(X) || ndims(X)~=3 || size(X,3)~=3 || ~isreal(X) || ~isnumeric(X) || ...
        any(~isfinite(X(:))) || any(X(:)<0 | X(:)>1)
    error('fl_photo_save:pixels','导出数据必须为 [0,1] 的有限 RGB 图像。');
end
if nargin>=3 && isstruct(meta) && isfield(meta,'Width') && isfield(meta,'Height')
    if size(X,2)~=meta.Width || size(X,1)~=meta.Height
        error('fl_photo_save:size','导出尺寸与预期完整分辨率不一致，请先运行全分辨率处理。');
    end
end
[folder,~,ext]=fileparts(path);
if isempty(folder), folder=pwd; path=fullfile(folder,path); end
if exist(folder,'dir')~=7, error('fl_photo_save:folder','导出文件夹不存在。'); end
if nargin>=3 && isstruct(meta) && isfield(meta,'Source') && ~isempty(meta.Source)
    if strcmpi(canonical(path),canonical(meta.Source))
        error('fl_photo_save:original','请另存为新文件，原照片不会被覆盖。');
    end
end
if exist(path,'file')~=0
    error('fl_photo_save:exists','此文件已存在，请选择新的文件名：%s',path);
end
ext=lower(ext);
if ~any(strcmp(ext,{'.png','.jpg','.jpeg','.tif','.tiff'}))
    error('fl_photo_save:format','导出格式请选择 PNG、JPEG 或 TIFF。');
end
if any(strcmp(ext,{'.jpg','.jpeg'})) && opt.BitDepth~=8
    error('fl_photo_save:jpegDepth','JPEG 只支持 8 位；16 位请使用 PNG 或 TIFF。');
end
if opt.BitDepth==16
    pixels=uint16(round(single(X)*65535));
else
    pixels=uint8(round(single(X)*255));
end
tmp=[tempname(folder) ext];
cleaner=onCleanup(@() remove_temp(tmp)); %#ok<NASGU>
switch ext
    case {'.jpg','.jpeg'}, imwrite(pixels,tmp,'jpg','Quality',opt.Quality);
    case '.png', imwrite(pixels,tmp,'png');
    otherwise, imwrite(pixels,tmp,'tif','Compression','lzw');
end
[ok,msg]=movefile(tmp,path);
if ~ok, error('fl_photo_save:write','无法保存照片：%s',msg); end
end

function p=canonical(p)
try
    p=char(java.io.File(p).getCanonicalPath());
catch
    [ok,a]=fileattrib(p);
    if ok, p=a.Name; end
end
p=strrep(p,'\','/');
end

function remove_temp(p)
if exist(p,'file')==2, delete(p); end
end
