function P=fl_app_paths()
%FL_APP_PATHS Read-only application assets and writable user output locations.
P.Root=fileparts(fileparts(mfilename('fullpath')));
P.Standalone=isdeployed;
P.Packaged=P.Standalone||strcmp(getenv('FILTERLAB_PACKAGED'),'1');
P.Sample=fullfile(P.Root,'samples','plus.mat');
if ~P.Packaged
    original=fullfile(fileparts(P.Root),'工程设计题5. 基于一维滤波器的图像处理','plus.mat');
    if exist(original,'file')==2, P.Sample=original; end
end
if P.Packaged
    base=getenv('FILTERLAB_USER_DATA');
    if isempty(base)
        base=getenv('LOCALAPPDATA');
        if isempty(base), base=prefdir; end
        base=fullfile(base,'FilterLab');
    end
    P.Output=fullfile(base,'output');
else
    P.Output=fullfile(P.Root,'output');
end
end
