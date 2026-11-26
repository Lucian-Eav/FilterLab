function R = FL_extensions(varargin)
%FL_EXTENSIONS Compute independent engineering experiments and export evidence.
% R=FL_extensions('Modules',[1 3],'Export',false,'MotionOpts',struct('Angle',45));
% An image option accepts a path, RGB/gray array, or 'synthetic'.
root=fileparts(mfilename('fullpath'));
if ~isdeployed, addpath(fullfile(root,'core')); end
p=inputParser; p.PartialMatching=false;
addParameter(p,'Modules',1:4);
addParameter(p,'OutputDir','',@(x)ischar(x)||(isstring(x)&&isscalar(x)));
addParameter(p,'Export',true,@(x)islogical(x)&&isscalar(x));
addParameter(p,'Visible','off');
imageKeys={'MountainImage','MoireImage','DocumentImage','NaishuImage'};
optionKeys={'MoireOpts','DocumentOpts','MotionOpts','AllpassOpts'};
for j=1:4
    addParameter(p,imageKeys{j},[]);
    addParameter(p,optionKeys{j},struct(),@(x)isstruct(x)&&isscalar(x));
end
parse(p,varargin{:}); opt=p.Results;
visible=validatestring(opt.Visible,{'on','off'});
validateattributes(opt.Modules,{'numeric'},{'vector','real','integer','nonempty','>=',1,'<=',4});
ids=unique(double(opt.Modules(:).'),'stable');
kinds={'mountain','screen_moire','notebook','naishu'};
needed=[any(ismember(ids,[1 3])),ismember(1,ids),ismember(2,ids),ismember(4,ids)];
inputs=struct(); settings=cell(1,4);
for j=1:4
    if needed(j)
        [img,meta]=fl_ext_samples(kinds{j},opt.(imageKeys{j}));
        inputs.(kinds{j})=struct('Image',img,'Meta',meta);
    end
    settings{j}=opt.(optionKeys{j});
end
R=fl_ext_compute(ids,inputs,settings);
if opt.Export
    folder=char(opt.OutputDir);
    if isempty(folder)
        paths=fl_app_paths(); [~,suffix]=fileparts(tempname);
        folder=fullfile(paths.Output,['extensions-' datestr(now,'yyyymmdd-HHMMSS') '-' suffix]);
    end
    R=fl_ext_export(R,folder);
    if strcmp(visible,'on'), web(fullfile(R.OutputDir,'report.html'),'-browser'); end
elseif strcmp(visible,'on')
    for j=ids
        for v=1:2, fl_ext_figure(R.Results{j}.Views(v),'on'); end
    end
end
end
