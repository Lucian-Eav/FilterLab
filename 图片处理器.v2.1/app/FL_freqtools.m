function R = FL_freqtools(tool,varargin)
%FL_FREQTOOLS Four toolbox-free photographic frequency tools.
% R = FL_freqtools('burst', frames, 'Mode','median', 'SaveTo','stack.png')
% R = FL_freqtools('sharpness', folderOrFiles)
% R = FL_freqtools('watermark', image, 'Action','inspect', 'Text','FILTERLAB')
% R = FL_freqtools('optics', image, struct('Aperture','pent5'))
% Omit the input to use a deterministic sample. Options accept structs or
% name/value pairs. MaxEdge (default 512) limits processing and export size.
root=fileparts(mfilename('fullpath'));
if ~isdeployed, addpath(fullfile(root,'core')); end
if nargin<1, tool='burst'; end
tool=validatestring(tool,{'burst','sharpness','watermark','optics'});
p=inputParser;
p.addParameter('Input',[]); p.addParameter('Sample','');
p.addParameter('MaxEdge',512); p.addParameter('SaveTo','');
switch tool
    case 'burst'
        defaults=struct('Mode','median','RefIndex',1,'AutoCrop',true,'Clean',[],'TrueShifts',[]);
        sample='burst_crowd';
    case 'sharpness'
        defaults=struct('Names',{{}}); sample='burst_sharpness';
    case 'watermark'
        defaults=struct('Action','embed','Mode','text','Text','FILTERLAB','Icon','heart', ...
            'PatternImage',[],'Strength',.22,'RunAttackTest',true);
        sample='watermark_photo';
    case 'optics'
        defaults=struct('Effect','starburst','Aperture','','Threshold',.78,'Intensity',.85, ...
            'Size',[],'RotationDeg',15,'Dispersion',true,'CustomAperture',[]);
        sample='night_lights';
end
fields=fieldnames(defaults);
for k=1:numel(fields), p.addParameter(fields{k},defaults.(fields{k})); end
source=[];
if ~isempty(varargin) && ~isstruct(varargin{1})
    first=varargin{1}; isKey=(ischar(first)||(isstring(first)&&isscalar(first))) && ...
        any(strcmpi(char(first),p.Parameters));
    if ~isKey, source=first; varargin=varargin(2:end); end
end
% Expand option structs alongside name/value pairs, including after an input.
args={};
for k=1:numel(varargin)
    value=varargin{k};
    if isstruct(value) && isscalar(value)
        names=fieldnames(value);
        for j=1:numel(names), args=[args,{names{j},value.(names{j})}]; end %#ok<AGROW>
    else
        args{end+1}=value; %#ok<AGROW>
    end
end
p.parse(args{:}); o=p.Results;
if ~isempty(o.Input)
    if ~isempty(source), error('FL_freqtools:input','请只指定一次输入。'); end
    source=o.Input;
end
if ~isempty(o.Sample), sample=char(o.Sample); end
[data,meta]=fl_ft_samples(sample,source,o.MaxEdge);
opts=struct();
for k=1:numel(fields), opts.(fields{k})=o.(fields{k}); end
switch tool
    case 'burst'
        if ~iscell(data), data={data}; end
        if isempty(opts.Clean) && isfield(meta,'Clean'), opts.Clean=meta.Clean; end
        if isempty(opts.TrueShifts) && isfield(meta,'TrueShifts'), opts.TrueShifts=meta.TrueShifts; end
        R=fl_ft_burst_stack(data,opts); output=R.Stacked;
    case 'sharpness'
        if ~iscell(data), data={data}; end
        names=opts.Names;
        if isempty(names) && isfield(meta,'Names'), names=meta.Names; end
        R=fl_ft_sharpness_rank(data,names,struct('MaxEdge',min(384,o.MaxEdge)));
        output=R.BestImage;
    otherwise
        if iscell(data)
            if numel(data)~=1, error('FL_freqtools:single','此工具需要一张图像。'); end
            data=data{1};
        end
        if strcmp(tool,'watermark')
            action=opts.Action; opts=rmfield(opts,'Action');
            R=fl_ft_watermark(action,data,opts);
        else
            R=fl_ft_optics(data,opts);
        end
        output=R.Output;
end
R.Tool=tool; R.InputMeta=meta; R.InputImages=data; R.SavedTo='';
if ~isempty(o.SaveTo)
    saveMeta=struct('Width',size(output,2),'Height',size(output,1));
    if isfield(meta,'Paths'), saveMeta.Source=meta.Paths{1}; end
    fl_photo_save(o.SaveTo,output,saveMeta);
    R.SavedTo=char(o.SaveTo);
end
end
