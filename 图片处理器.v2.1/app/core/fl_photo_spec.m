function S = fl_photo_spec(varargin)
%FL_PHOTO_SPEC  自然照片参数：默认值、结构体或名值对。
% S=fl_photo_spec(); S=fl_photo_spec(S); S=fl_photo_spec('Exposure',0.3);
% 去噪/Detail:0..1；锐化强度:0..2，半径:.3..5，阈值:0...1。
% Temperature/Tint:-100..100；Exposure:-3..3 EV。
% Contrast/Highlights/Shadows/Vibrance/Saturation:-1..1；WB:三通道 .1..10。
% 所有模块关闭时保留原图；AutoWB 默认关闭，WB 默认 [1 1 1]。
S=struct('DenoiseEnable',true,'LumaDenoise',.25,'ColorDenoise',.35,'Detail',.65, ...
    'SharpenEnable',true,'SharpenAmount',.35,'SharpenRadius',1,'SharpenThreshold',.012, ...
    'ColorEnable',true,'AutoWB',false,'Temperature',0,'Tint',0,'Exposure',0, ...
    'AutoNoise',false,'FineDetail',0,'Clarity',0,'LocalContrast',0,'HaloSuppression',.75, ...
    'Contrast',0,'Highlights',0,'Shadows',0,'Vibrance',0,'Saturation',0,'WB',[1 1 1]);
if nargin==1 && isstruct(varargin{1}) && isscalar(varargin{1})
    source=varargin{1}; names=fieldnames(source); values=struct2cell(source);
else
    if mod(nargin,2), error('fl_photo_spec:args','参数须为结构体或成对的名称和值。'); end
    names=varargin(1:2:end); values=varargin(2:2:end);
end
for k=1:numel(names)
    key=names{k};
    if ~(ischar(key) && isrow(key)) && ~(isstring(key) && isscalar(key))
        error('fl_photo_spec:name','参数名称必须为文本。');
    end
    key=char(key);
    if ~isfield(S,key), error('fl_photo_spec:unknown','未知照片参数：%s',key); end
    S.(key)=values{k};
end
flags={'DenoiseEnable','SharpenEnable','ColorEnable','AutoWB','AutoNoise'};
for k=1:numel(flags)
    v=S.(flags{k});
    if ~((islogical(v)||isnumeric(v)) && isreal(v) && isscalar(v) && isfinite(v) && (v==0||v==1))
        error('fl_photo_spec:flag','%s 必须为 true/false。',flags{k});
    end
    S.(flags{k})=logical(v);
end
ranges={'LumaDenoise',0,1;'ColorDenoise',0,1;'Detail',0,1; ...
    'SharpenAmount',0,2;'SharpenRadius',.3,5;'SharpenThreshold',0,.1; ...
    'FineDetail',-1,1;'Clarity',-1,1;'LocalContrast',-1,1;'HaloSuppression',0,1; ...
    'Temperature',-100,100;'Tint',-100,100;'Exposure',-3,3; ...
    'Contrast',-1,1;'Highlights',-1,1;'Shadows',-1,1;'Vibrance',-1,1;'Saturation',-1,1};
for k=1:size(ranges,1)
    key=ranges{k,1}; v=S.(key);
    if ~(isnumeric(v)&&isreal(v)&&isscalar(v)&&isfinite(v)&&v>=ranges{k,2}&&v<=ranges{k,3})
        error('fl_photo_spec:range','%s 必须在 %g 至 %g 之间。',key,ranges{k,2},ranges{k,3});
    end
    S.(key)=double(v);
end
if ~(isnumeric(S.WB)&&isreal(S.WB)&&numel(S.WB)==3&&all(isfinite(S.WB(:)))&&all(S.WB(:)>=.1 & S.WB(:)<=10))
    error('fl_photo_spec:wb','WB 必须为 .1 至 10 范围内的三个增益。');
end
S.WB=reshape(double(S.WB),1,3);
end
