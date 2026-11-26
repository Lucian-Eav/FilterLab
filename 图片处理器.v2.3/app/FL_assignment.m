function R=FL_assignment(varargin)
%FL_ASSIGNMENT Run and export all six original assignment questions.
% R=FL_assignment('OutputDir','new-empty-folder','DataFile','plus.mat');
% R=FL_assignment('Export',false) computes without writing files.
root=fileparts(mfilename('fullpath')); if ~isdeployed, addpath(fullfile(root,'core')); end
paths=fl_app_paths();
p=inputParser; p.addParameter('DataFile',''); p.addParameter('OutputDir','');
p.addParameter('Visible','off'); p.addParameter('Export',true,@(v)islogical(v)&&isscalar(v)); p.parse(varargin{:});
opt=p.Results; R=fl_assignment_compute(opt.DataFile);
if opt.Export
    folder=char(opt.OutputDir);
    if isempty(folder), [~,id]=fileparts(tempname); folder=fullfile(paths.Output,['assignment-' datestr(now,'yyyymmdd-HHMMSS') '-' id(end-5:end)]); end
    R=fl_assignment_export(R,folder);
    if strcmp(opt.Visible,'on'), web(fullfile(folder,'report.html'),'-browser'); end
end
end
