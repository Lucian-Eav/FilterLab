function count=check_photo_v21(oldApp,newApp)
%CHECK_PHOTO_V21 Compare photo/creative results against the original v2 app.
% count=check_photo_v21(absolutePathToV2App,absolutePathToV21App)
oldCore=fullfile(oldApp,'core'); newCore=fullfile(newApp,'core');
assert(isfolder(oldCore)&&isfolder(newCore)&&~strcmpi(oldCore,newCore),'Supply the two distinct app folders.');
originalPath=path; originalDir=pwd; originalRng=rng;
cleanup=onCleanup(@()restore(originalDir,originalPath,originalRng));
rng(2137,'twister'); image=rand(73,101,3,'single'); large=rand(353,389,3,'single');
reference=capture(oldCore,image,large);
candidate=capture(newCore,image,large);
keys=fieldnames(reference); assert(isequal(keys,fieldnames(candidate)),'Photo result cases differ.');
count=1; % Case-name comparison above.
for k=1:numel(keys)
    name=keys{k}; count=count+check(reference.(name),candidate.(name),name);
end
fprintf('Photo/creative comparison passed: %d exact output assertions across %d cases.\n',count,numel(keys));
end

function R=capture(core,I,L)
cd(core); addpath(core,'-begin'); clearPhotoFunctions();
assert(strcmpi(which('fl_photo_process'),fullfile(core,'fl_photo_process.m')),'Unexpected photo module on path.');
R=struct();
R.noise_single=fl_photo_noise(L); R.noise_double=fl_photo_noise(double(L)+eps*(L>0&L<1));
R.noise_tiny=fl_photo_noise(I(1,:,:)); R.noise_flat=fl_photo_noise(zeros(99,101,3,'single'));
R.noise_one_tile=fl_photo_noise(I(1:8,1:8,:));
settings={struct(),struct('ColorEnable',false,'DenoiseEnable',false,'SharpenEnable',false), ...
    struct('SharpenAmount',0,'FineDetail',.41),struct('SharpenAmount',0,'Clarity',-.38), ...
    struct('DenoiseEnable',false,'SharpenAmount',0,'LocalContrast',.24), ...
    struct('AutoWB',true,'AutoNoise',true,'Exposure',-.27,'Contrast',.28,'Vibrance',.23, ...
    'FineDetail',-.13,'Clarity',.24,'LocalContrast',.37),struct('Saturation',-.17,'Shadows',.4)};
for k=1:numel(settings)
    [y,info,st]=fl_photo_process(I,settings{k});
    R.(sprintf('photo%d',k))={y,rmfield(info,'ElapsedSeconds'),st};
end
R.degenerate_photo=fl_photo_process(I(1,:,:),settings{3});
fpaint=struct('Points',[.49 .47;.5 .5;-.48 .48],'Radius',.072,'Opacity',.81,'Mode','paint');
ferase=struct('Points',[-.5 0;-.34 .12],'Radius',.05,'Opacity',.43,'Mode','erase');
F=fl_creative_spec(struct('FrequencyEnable',true,'FrequencyStrokes',{{fpaint,ferase}}));
for h=[64 65]
    for w=[72 73]
        R.(sprintf('freq%d_%d',h,w))=fl_frequency_mask([h w],F);
    end
end
F.FrequencyKeepDC=false;
F.FrequencyStrokes{end+1}=struct('Points',[0 0],'Radius',.1,'Opacity',.91,'Mode','paint');
R.frequency_dc=fl_frequency_mask([65 67],F);
geo=struct('OriginalSize',[139 175 3],'Geometry',{{struct('Type','crop','Value',[13 17 101 73]), ...
    struct('Type','rotate','Value',1),struct('Type','flip-h')}});
brush=struct('Points',[.01 .32;.2 .41;.63 .12;.63 .12],'Radius',.044,'Opacity',.73,'Mode','paint');
eraser=struct('Points',[.45 .32;.53 .08],'Radius',.09,'Opacity',.41,'Mode','erase');
outside=struct('Points',[1 1],'Radius',.014,'Opacity',1,'Mode','paint');
M=fl_creative_spec(struct('MaskEnable',true,'MaskBase',.13,'MaskStrokes',{{brush,eraser,outside}}));
R.mask_soft=fl_photo_mask([67 49],M,geo);
M.MaskInvert=true; M.MaskSoftness=0; R.mask_hard=fl_photo_mask([67 49],M,geo);
for type={'directional','zoom','spin'}
    C=struct('MotionEnable',true,'MotionType',type{1},'MotionAngle',-26.3, ...
        'MotionLength',21.7,'MotionCenter',[.237 .781],'MotionZoom',.11,'MotionSpin',14.2,'MotionAmount',.68);
    R.(type{1})=fl_creative_process(I,C); R.([type{1} '_strips'])=fl_creative_process(L,C);
    R.([type{1} '_row'])=fl_creative_process(I(1,:,:),C);
    R.([type{1} '_column'])=fl_creative_process(I(:,1,:),C);
end
R.tilt=fl_creative_process(I,struct('TiltEnable',true,'TiltBlur',4.8,'TiltAngle',11.3,'TiltCenter',[.23 .86]));
R.classic=fl_creative_process(I,struct('ClassicType','fir4','ClassicAmount',.43));
R.pipeline_idle=fl_photo_pipeline(I,settings{1});
R.pipeline_mask_idle=fl_photo_pipeline(I,settings{1},M,geo);
M.MaskTarget='all'; R.pipeline_all=fl_photo_pipeline(I,settings{1},M,geo);
M.FrequencyEnable=true; M.FrequencyStrokes=F.FrequencyStrokes; M.TiltEnable=true; M.TiltAngle=27;
[y,info,st]=fl_photo_pipeline(I,settings{6},M,geo); R.pipeline_mixed={y,rmfield(info,'ElapsedSeconds'),st};
end

function count=check(a,b,name)
assert(strcmp(class(a),class(b))&&isequal(size(a),size(b)),'Type or shape differs in %s.',name);
if isstruct(a)
    keys=fieldnames(a); assert(isequal(keys,fieldnames(b)),'Field names differ in %s.',name);
    count=2;
    for k=1:numel(keys)
        key=keys{k}; count=count+check(a.(key),b.(key),[name '.' key]);
    end
elseif iscell(a)
    count=1;
    for k=1:numel(a), count=count+check(a{k},b{k},sprintf('%s{%d}',name,k)); end
else
    if ~isequaln(a,b) && isnumeric(a)
        delta=abs(double(a(:))-double(b(:))); error('check_photo_v21:delta','%s max absolute difference %.12g.',name,max(delta));
    end
    assert(isequaln(a,b),'Value differs in %s.',name); count=2;
end
end

function restore(folder,savedPath,savedRng)
cd(folder); path(savedPath); clearPhotoFunctions(); rng(savedRng);
end
function clearPhotoFunctions()
clear fl_photo_process fl_photo_noise fl_photo_pipeline fl_photo_mask fl_photo_spec
clear fl_creative_process fl_creative_spec fl_frequency_mask fl_mask_transform fl_assignment_design
end
