function paths = fl_barrier_export(R, folder)
%FL_BARRIER_EXPORT Publish a full-resolution base and zero-offset RGBA overlay.
if ~isstruct(R) || ~isscalar(R) || ~all(isfield(R,{'Base','Size','Width'}))
    error('fl_barrier_export:result','请先生成栅栏底图。');
end
base = R.Base;
[h,width,channels] = size(base);
if ~isa(base,'uint8') || isempty(base) || ndims(base)~=3 || channels~=3 || ...
        ~isequal(R.Size,[h width])
    error('fl_barrier_export:base','底图的尺寸或像素格式无效。');
end
blocked = fl_barrier_columns(width,R.Width,0);
if ~((ischar(folder) && isrow(folder)) || (isstring(folder) && isscalar(folder) && ~ismissing(folder))) || strlength(folder)==0
    error('fl_barrier_export:folder','请选择有效的导出目录。');
end
folder = char(folder);
if ~isfolder(folder)
    [ok,msg] = mkdir(folder);
    if ~ok, error('fl_barrier_export:mkdir','%s',msg); end
end
[ok,attr] = fileattrib(folder);
if ~ok, error('fl_barrier_export:folder','无法读取导出目录。'); end
folder = attr.Name;
[~,token] = fileparts(tempname(folder));
output = fullfile(folder,['barrier_' token]);
stage = fullfile(folder,['.barrier-writing_' token]);
[ok,msg,id] = mkdir(stage);
if ~ok || ~isempty(id), error('fl_barrier_export:stage','无法创建独立的暂存目录。%s',msg); end
guard = onCleanup(@() removeStage(stage)); %#ok<NASGU>
imwrite(base,fullfile(stage,'base.png'),'png');
alpha = repmat(uint8(blocked).*uint8(255),h,1);
imwrite(zeros(h,width,3,'uint8'),fullfile(stage,'grating.png'),'png','Alpha',alpha);
% Both files are closed before publishing the directory. Omitting
% REPLACE_EXISTING preserves previous packages even on a name collision.
java.nio.file.Files.move(java.io.File(stage).toPath(),java.io.File(output).toPath(), ...
    javaArray('java.nio.file.CopyOption',0));
paths = struct('Base',fullfile(output,'base.png'),'Grating',fullfile(output,'grating.png'));
end

function removeStage(stage)
if isfolder(stage), rmdir(stage,'s'); end
end
