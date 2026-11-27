function C=fl_creative_spec(value)
%FL_CREATIVE_SPEC Validated creative settings, normalized vector brush strokes.
C=struct('FrequencyEnable',false,'FrequencyStrokes',{{}},'FrequencyKeepDC',true, ...
    'TiltEnable',false,'TiltCenter',[.5 .5],'TiltAngle',0,'TiltWidth',.22,'TiltFeather',.18,'TiltBlur',14, ...
    'MotionEnable',false,'MotionType','directional','MotionLength',24,'MotionAngle',0, ...
    'MotionCenter',[.5 .5],'MotionZoom',.12,'MotionSpin',12,'MotionAmount',1, ...
    'ClassicType','off','ClassicAmount',1,'MaskEnable',false,'MaskBase',0, ...
    'MaskStrokes',{{}},'MaskSoftness',.65,'MaskInvert',false,'MaskTarget','creative');
if nargin
    if ~isstruct(value)||~isscalar(value), error('fl_creative_spec:input','创意参数必须为标量结构体。'); end
    keys=fieldnames(value);
    for k=1:numel(keys)
        if ~isfield(C,keys{k}), error('fl_creative_spec:field','未知创意参数：%s',keys{k}); end
        C.(keys{k})=value.(keys{k});
    end
end
flags={'FrequencyEnable','FrequencyKeepDC','TiltEnable','MotionEnable','MaskEnable','MaskInvert'};
for k=1:numel(flags)
    v=C.(flags{k}); validateattributes(v,{'logical','numeric'},{'real','finite','scalar'});
    if v~=0&&v~=1, error('fl_creative_spec:flag','开关必须为 true/false。'); end
    C.(flags{k})=logical(v);
end
ranges={'TiltAngle',-180,180;'TiltWidth',.01,2;'TiltFeather',.001,1;'TiltBlur',0,60; ...
    'MotionLength',0,120;'MotionAngle',-180,180;'MotionZoom',0,.7;'MotionSpin',0,90; ...
    'MotionAmount',0,1;'ClassicAmount',0,1;'MaskBase',0,1;'MaskSoftness',0,1};
for k=1:size(ranges,1)
    validateattributes(C.(ranges{k,1}),{'numeric'},{'real','finite','scalar','>=',ranges{k,2},'<=',ranges{k,3}});
    C.(ranges{k,1})=double(C.(ranges{k,1}));
end
for key={'TiltCenter','MotionCenter'}
    validateattributes(C.(key{1}),{'numeric'},{'real','finite','numel',2,'>=',0,'<=',1});
    C.(key{1})=reshape(double(C.(key{1})),1,2);
end
C.MotionType=validatestring(C.MotionType,{'directional','zoom','spin'});
C.ClassicType=validatestring(C.ClassicType,{'off','butter10','fir4','fir12'});
C.MaskTarget=validatestring(C.MaskTarget,{'creative','all'});
for field={'MaskStrokes','FrequencyStrokes'}
    strokes=C.(field{1});
    if ~iscell(strokes)||numel(strokes)>1000, error('fl_creative_spec:strokes','笔触必须为至多 1000 项的元胞数组。'); end
    for k=1:numel(strokes)
        s=strokes{k};
        if ~isstruct(s)||~isscalar(s)||~all(isfield(s,{'Points','Radius','Opacity','Mode'})), error('fl_creative_spec:stroke','笔触格式不正确。'); end
        validateattributes(s.Points,{'numeric'},{'real','finite','2d','nonempty','ncols',2});
        if size(s.Points,1)>10000, error('fl_creative_spec:points','单笔点数过多。'); end
        if strcmp(field{1},'FrequencyStrokes'), bound=.5; else, bound=1; end
        if any(abs(s.Points(:))>bound)|| (bound==1&&any(s.Points(:)<0)), error('fl_creative_spec:points','笔触超出归一化坐标范围。'); end
        validateattributes(s.Radius,{'numeric'},{'real','finite','scalar','>',0,'<=',1});
        validateattributes(s.Opacity,{'numeric'},{'real','finite','scalar','>=',0,'<=',1});
        validatestring(s.Mode,{'paint','erase'});
    end
end
end
