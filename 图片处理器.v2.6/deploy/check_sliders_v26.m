function check_sliders_v26(artifactDir,physicalKeys)
%CHECK_SLIDERS_V26 Actual app widgets, preview, commit, reset and keyboard focus.
% check_sliders_v26(tempdir,true) also sends real OS key events. It needs an
% unlocked local desktop and exclusive keyboard focus for the duration.
if nargin<1 || isempty(artifactDir), artifactDir=tempdir; end
if nargin<2, physicalKeys=false; end
if ~isfolder(artifactDir), mkdir(artifactDir); end
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'app'),fullfile(root,'app','core'));
path=[tempname(artifactDir) '.png']; imwrite(uint8(repmat(0:95,64,1)),path);
cleanFile=onCleanup(@()delete(path)); %#ok<NASGU>
fig=FL_photo('Visible','on','File',path); closeFig=onCleanup(@()delete(fig)); %#ok<NASGU>
api=getappdata(fig,'PhotoActions'); exposure=widget(fig,'Photo_Exposure'); amount=number(exposure);
ui=matlab.uitest.TestCase.forInteractiveUse;
ui.type(amount,.37); drawnow;
assert(abs(exposure.Value-.37)<1e-10 && abs(state(fig).Spec.Exposure-.37)<1e-10);
api.Undo(); checkPair(exposure,0); api.Redo(); checkPair(exposure,.37);
feval(exposure.ValueChangingFcn,exposure,struct('Value',.483));
assert(abs(amount.Value-.48)<1e-10 && abs(state(fig).Spec.Exposure-.37)<1e-10);
ui.drag(exposure,exposure.Value,exposure.Limits(2)); drawnow;
assert(exposure.Value>2.8,'Drag did not reach the upper end of the track.');
checkPair(exposure,exposure.Value); assert(abs(state(fig).Spec.Exposure-exposure.Value)<1e-10);
ui.type(amount,3); checkPair(exposure,3); assert(state(fig).Spec.Exposure==3);
ui.type(amount,.48); checkPair(exposure,.48); assert(abs(state(fig).Spec.Exposure-.48)<1e-10);
if physicalKeys
    % Keep focus across the expensive editor callback and its busy/idle cycle.
    keyCheck(exposure,.01);
    lastExposure=exposure.Value; contrast=widget(fig,'Photo_Contrast'); keyCheck(contrast,.01);
    checkPair(exposure,lastExposure);
end
split=widget(fig,'PhotoSplit'); change(number(split),75); assert(abs(split.Value-.75)<eps && state(fig).Split==.75);
api.SetSplit(.25); assert(number(split).Value==25);
tools=widget(fig,'PhotoToolSelect');
for tag={'PhotoTabDenoise','PhotoTabSharpen','PhotoTabFrequency','PhotoTabTilt','PhotoTabMotion','PhotoTabMask','PhotoTabClassic'}
    change(tools,tag{1});
end
change(tools,'PhotoTabTilt'); tilt=widget(fig,'PhotoCreative_TiltWidth');
change(number(tilt),1.42); checkPair(tilt,1.42); assert(abs(state(fig).Creative.TiltWidth-1.42)<1e-10);
api.Undo(); checkPair(tilt,.22); api.Redo(); checkPair(tilt,1.42);
change(tools,'PhotoTabDenoise'); auto=widget(fig,'Photo_AutoNoise'); change(auto,true);
noise=widget(fig,'Photo_LumaDenoise'); assert(strcmp(noise.Enable,'off') && strcmp(number(noise).Enable,'off'));
change(tools,'PhotoTabFrequency'); brush=widget(fig,'PhotoFrequencyRadius'); change(number(brush),.097); checkPair(brush,.097);
api.Reset(); checkPair(exposure,0); checkPair(tilt,.22); checkPair(brush,.035); assert(number(split).Value==50);
assert(strcmp(noise.Enable,'on') && strcmp(number(noise).Enable,'on'));
api.SetView('spectrum'); assert(strcmp(split.Visible,'off') && strcmp(number(split).Visible,'off'));
api.SetView('result'); assert(strcmp(split.Enable,'off') && strcmp(number(split).Enable,'off'));
barrier=api.OpenBarrier(); offset=widget(barrier,'BarrierOffset'); width=widget(barrier,'BarrierWidth');
change(width,3); assert(isequal(offset.Limits,[0 6]) && isequal(number(offset).Limits,[0 6]));
change(number(offset),5); checkPair(offset,5); assert(contains(widget(barrier,'BarrierPhaseLabel').Text,'5 px'));
showB=widget(barrier,'BarrierShowB'); feval(showB.ButtonPushedFcn,showB,[]); checkPair(offset,3);
change(widget(barrier,'BarrierMode'),'base'); assert(strcmp(number(offset).Enable,'off'));
freq=api.OpenFreqTools(); fapi=getappdata(freq,'FreqToolsActions'); fapi.SetModule(3);
watermark=widget(freq,'FreqWatermarkStrength'); fapi.SetOptions(3,struct('Strength',.31)); checkPair(watermark,.31);
change(number(watermark),.57); checkPair(watermark,.57);
sliders=findall(fig,'Type','uislider'); assert(numel(sliders)>=36,'Some parameter panels were not built.');
for k=1:numel(sliders)
    h=sliders(k); f=number(h); assert(isa(f,'matlab.ui.control.NumericEditField'));
    scale=1; if strcmp(h.Tag,'PhotoSplit'), scale=100; end
    assert(isequal(f.Limits,h.Limits*scale) && abs(f.Value-h.Value*scale)<1e-10,'Unpaired %s.',h.Tag);
    assert(isscalar(getappdata(h,'FineStep')) && getappdata(h,'FineStep')>0,'Missing fine step on %s.',h.Tag);
end
fprintf('PASS: %d slider/number pairs, UI numeric entry, drag preview, commit, history, reset, dynamic range and disabled states.\n',numel(sliders));
if physicalKeys
    legacy=uifigure('Position',[120 200 400 170]); closeLegacy=onCleanup(@()delete(legacy)); %#ok<NASGU>
    setappdata(legacy,'FlTestLegacySlider',true); grid=uigridlayout(legacy,[2 1]);
    s=uislider(grid,'Limits',[0 1],'Value',.5,'Tag','LegacyThumb'); fl_slider_pair(grid,s,'TestLegacyNumber',.01,'%.2f'); drawnow;
    keyCheck(s,.01);
    ui.drag(s,s.Value,1); pause(.25); drawnow; assert(s.Value>.95); checkPair(s,s.Value);
    fprintf('PASS: physical left/right, consecutive key events, inactive edit-field focus, native Step and compatibility routes.\n');
end
end
function keyCheck(s,step)
fig=ancestor(s,'figure'); figure(fig); drawnow; pause(.2);
r=java.awt.Robot; focus(s); pause(.4); v=s.Value;
previous=fig.WindowKeyPressFcn; keyCount=0; fig.WindowKeyPressFcn=@observeKey;
restore=onCleanup(@()restoreKeys(fig,previous));

for key=[39 39 37]
    if key==39, v=v+step; else, v=v-step; end
    before=keyCount; r.keyPress(key); r.keyRelease(key);
    t=tic; while toc(t)<4 && (abs(s.Value-v)>1e-8 || keyCount==before), drawnow; pause(.04); end
    drawnow;
    assert(keyCount>before,'check_sliders_v26:foreground','No key reached %s. Check that the MATLAB desktop has input focus.',s.Tag);
    assert(abs(s.Value-v)<1e-8,'Keyboard %d on %s expected %g, got %g.',key,s.Tag,v,s.Value);
end
field=number(s); focus(field); pause(.3); before=keyCount; r.keyPress(37); r.keyRelease(37); pause(.25); drawnow;
assert(keyCount>before && abs(s.Value-v)<1e-8,'The caret key must reach the figure and preserve the slider value.');
clear restore;
    function observeKey(src,e)
        keyCount=keyCount+1;
        if ~isempty(previous), feval(previous,src,e); end
    end
end
function restoreKeys(fig,old)
if isgraphics(fig) && strcmp(fig.BeingDeleted,'off'), fig.WindowKeyPressFcn=old; end
end
function s=state(fig)
s=getappdata(fig,'PhotoState');
end
function f=number(h)
f=getappdata(h,'NumberField'); assert(isscalar(f) && isgraphics(f),'No input beside %s.',h.Tag);
end
function checkPair(h,v)
assert(abs(h.Value-v)<1e-10 && abs(number(h).Value-v)<1e-10,'Pair %s did not restore %g.',h.Tag,v);
end
function h=widget(root,tag)
h=findall(root,'Tag',tag); assert(isscalar(h),'Missing or duplicate %s.',tag);
end
function change(h,v)
h.Value=v; feval(h.ValueChangedFcn,h,struct('Value',v)); drawnow;
end
