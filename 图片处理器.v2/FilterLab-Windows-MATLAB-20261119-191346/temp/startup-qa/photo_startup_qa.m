function photo_startup_qa
qa=fileparts(mfilename('fullpath'));
pkg=fileparts(fileparts(qa));
startStamp=str2double(getenv('FILTERLAB_QA_START'))/1000;
clockNow=@()posixtime(datetime('now','TimeZone','UTC'));
fprintf('ENGINE_SECONDS %.3f\n',clockNow()-startStamp);
addpath(fullfile(pkg,'app'),fullfile(pkg,'app','core'));
tic;
f=FL_photo('Visible','off');
guard=onCleanup(@()cleanup(f));
build=toc;
creationObjects=numel(findall(f));
f.Visible='on'; drawnow;
elapsed=toc;
fprintf('HIDDEN_BUILD %.3f DRAW_TOTAL %.3f TOTAL %.3f OBJECTS %d\n',build,elapsed,clockNow()-startStamp,creationObjects);
f.Visible='off';
api=getappdata(f,'PhotoActions');
lookup=@(tag)findall(f,'Tag',tag);
tabs=lookup('PhotoTabs'); chooser=lookup('PhotoToolSelect');
tags=chooser.ItemsData; assert(numel(tags)==9);
assert(~isempty(lookup('Photo_Exposure')));
sampleTags={'Photo_Exposure','Photo_LumaDenoise','Photo_Clarity','PhotoCropField1','PhotoFrequencyMode','PhotoCreative_TiltBlur','PhotoMotionPlace','PhotoMaskRadius','PhotoCreative_ClassicType'};
for i=2:numel(tags)
    assert(isempty(lookup(sampleTags{i})));
    assert(isscalar(lookup(tags{i})));
end
file=fullfile(qa,'sample.png');
rng(21); imwrite(rand(60,80,3),file);
api.Open(file); 
api.SetCropRatio(1); s=getappdata(f,'PhotoState'); assert(s.CropRatio==1);
assert(isempty(lookup('PhotoCropField1')));
api.SetSpec(struct('Clarity',.31,'AutoNoise',true));
api.SetCreative(struct('TiltBlur',4,'MotionType','zoom','MaskTarget','all'));
for i=1:numel(tags)
    if mod(i,2)==0
        chooser.Value=tags{i}; chooser.ValueChangedFcn(chooser,[]);
    else
        tabs.SelectedTab=lookup(tags{i}); tabs.SelectionChangedFcn(tabs,[]);
    end
    h=lookup(sampleTags{i}); assert(isscalar(h));
    assert(strcmp(chooser.Value,tags{i}));
    switch i
        case 2
            assert(strcmp(h.Enable,'off'));
            assert(~isempty(strfind(lookup('PhotoNoiseEstimate').Text,'255')));
        case 3
            assert(abs(h.Value-.31)<1e-7);
        case 4
            assert(lookup('PhotoCropRatio').Value==1);
        case 6
            assert(h.Value==4);
        case 7
            assert(strcmp(lookup('PhotoCreative_MotionType').Value,'zoom'));
        case 8
            assert(strcmp(lookup('PhotoCreative_MaskTarget').Value,'all'));
    end
    childCount=numel(findall(lookup(tags{i})));
    tabs.SelectionChangedFcn(tabs,[]);
    assert(numel(findall(lookup(tags{i})))==childCount);
    fprintf('TAB %s PASS\n',tags{i});
end
api.BeginCrop(); api.SetCropRect([4 6 20 20]); api.ApplyCrop();
s=getappdata(f,'PhotoState'); assert(isequal(size(s.Working),[20 20 3]) && ~s.CropActive);
api.Undo(); api.Redo(); api.Undo();
for mode={'frequency','mask','tilt','motion'}
    api.SetTool(mode{1}); s=getappdata(f,'PhotoState'); assert(strcmp(s.Tool,mode{1})); api.SetTool('none');
end
api.PaintMask([.4 .6],.1,.8,'paint');
api.PaintFrequency([.1 .2],.05,.6,'paint');
api.SetFocus('tilt',[.4 .5]); api.SetFocus('motion',[.5 .6]);
api.SetZoom('100');
out=[tempname(qa) '.png']; api.Export(out); assert(isequal(size(imread(out)),[60 80 3]));
preset=[tempname(qa) '.mat']; api.SavePreset(preset); api.Reset(); api.LoadPreset(preset);
s=getappdata(f,'PhotoState'); assert(abs(s.Spec.Clarity-.31)<1e-7);
assert(isgraphics(api.OpenAssignment()) && isgraphics(api.OpenExtensions()) && isgraphics(api.OpenFreqTools()));
close(f); assert(~isgraphics(f));
fprintf('NINE_TABS_AND_ACTIONS_PASS\n');
assert(fl_ft_selftest(true)); fprintf('SELFTEST_ALL_PASS\n')
end
function cleanup(f)
if isgraphics(f), delete(f); end
end
