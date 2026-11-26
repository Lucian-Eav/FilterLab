function out = FL_process(source, destination, varargin)
%FL_PROCESS  无界面的自然照片处理入口。
% R=FL_process('photo.jpg','photo_edited.png')
% R=FL_process('photo.jpg','photo_edited.jpg','Exposure',0.3,'LumaDenoise',0.4)
% R=FL_process('photo.jpg','',S) 只处理并返回，不保存。
% 参数参见 fl_photo_spec；原照片与已存在文件不会被覆盖。
here=fileparts(mfilename('fullpath')); addpath(fullfile(here,'core'));
if nargin<2, destination=''; end
S=fl_photo_spec(varargin{:});
[X,meta]=fl_photo_load(source);
[Y,info]=fl_photo_process(X,S);
if ~isempty(destination), fl_photo_save(destination,Y,meta); end
out=struct('Image',Y,'Spec',S,'Meta',meta,'Info',info,'Destination',destination);
end
