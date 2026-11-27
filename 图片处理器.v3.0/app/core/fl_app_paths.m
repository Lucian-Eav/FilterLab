function P = fl_app_paths()
%FL_APP_PATHS All read-only resources travel with the app; only user data is writable.
sourceRoot = fileparts(fileparts(mfilename('fullpath')));
roots = {sourceRoot};
if isdeployed
    roots = [roots, {ctfroot,fullfile(ctfroot,'app'), ...
        fullfile(ctfroot,'FilterLab'),fullfile(ctfroot,'FilterLab','app')}];
end
P = struct();
for k = 1:numel(roots)
    sample = fullfile(roots{k},'samples','plus.mat');
    assets = fullfile(roots{k},'assets');
    if isfile(sample) && isfile(fullfile(assets,'ridge-overview.jpg'))
        P.Root = roots{k}; P.Sample = sample; P.Assets = assets;
        break
    end
end
if ~isfield(P,'Root')
    error('FilterLab:MissingResources','找不到随包的实验数据或首页图片，请重新安装完整应用。');
end
P.Standalone = isdeployed;
P.Packaged = isdeployed;
base = getenv('FILTERLAB_USER_DATA');
if isempty(base)
    local = getenv('LOCALAPPDATA');
    if isempty(local), local = prefdir; end
    base = fullfile(local,'FilterLab');
end
P.Output = fullfile(base,'output');
end
