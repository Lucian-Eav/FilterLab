function report=check_brush_v26(appDir,numericOnly)
%CHECK_BRUSH_V26 Drive an actual axes drag, paint/erase/undo, fit, 100%, export.
% Run on a MATLAB desktop-capable host: check_brush_v26(absoluteAppDirectory).
if nargin==0, appDir=fullfile(fileparts(fileparts(mfilename('fullpath'))),'app'); end
savedDir=pwd; savedPath=path; temp=tempname; mkdir(temp);
cleanup=onCleanup(@()restore(savedPath,savedDir,temp)); %#ok<NASGU>
cd(appDir); addpath(appDir,fullfile(appDir,'core'),'-begin');
clear FL_photo fl_photo_process fl_photo_pipeline fl_creative_process fl_frequency_view fl_frequency_mask fl_frequency_brush_view
assert(strcmpi(which('FL_photo'),fullfile(appDir,'FL_photo.m')));
% Check cache append, changes to protection, undo and branching independently
% of the display. Use all four odd/even parity combinations, the DC bin,
% partially transparent paint/erase and the periodic Nyquist boundaries.
checks=0;
for h=[63 64]
    for w=[71 72]
        input=single(repmat(reshape(mod(1:h*w,117)/117,h,w),1,1,3));
        C=fl_creative_spec(); [~,cache]=fl_frequency_brush_view(input,C,[]);
        C.FrequencyStrokes={stroke([0 0;.47 .48;.5 .5],.07,.87,'paint')};
        [c1,cache]=fl_frequency_brush_view(input,C,cache);
        assert(isequal(c1,fl_frequency_view(input,C)));
        C.FrequencyKeepDC=false; [unprotected,cache]=fl_frequency_brush_view(input,C,cache);
        assert(isequal(unprotected,fl_frequency_view(input,C)) && ~isequal(unprotected,c1));
        C.FrequencyStrokes{2}=stroke([-.5 -.5;-.48 .02],.05,.76,'erase');
        [erased,cache]=fl_frequency_brush_view(input,C,cache);
        assert(isequal(erased,fl_frequency_view(input,C)) && ~isequal(erased,unprotected));
        C.FrequencyStrokes(2)=[]; [back,cache]=fl_frequency_brush_view(input,C,cache);
        assert(isequal(back,unprotected));
        C.FrequencyStrokes={stroke([.19 .17],.04,1,'paint')};
        branch=fl_frequency_brush_view(input,C,cache); assert(isequal(branch,fl_frequency_view(input,C)));
        checks=checks+5;
    end
end
if nargin>=2 && numericOnly
    report=struct('MaskComparisons',checks); fprintf('PASS brush v2.6: %d numeric comparisons.\n',checks); return;
end
[x,y]=meshgrid(1:1332,1:669);
pic=uint8(cat(3,126+98*cos(2*pi*(x/13+y/21)),mod(2*x+y,256),mod(x+3*y,256)));
source=fullfile(temp,'photo.png'); target=fullfile(temp,'export.png'); imwrite(pic,source);
fig=FL_photo('File',source,'Visible','on'); cleanupFig=onCleanup(@()delete(fig)); %#ok<NASGU>
drawnow; api=getappdata(fig,'PhotoActions'); choose(widget(fig,'PhotoToolSelect'),'PhotoTabFrequency');
press(widget(fig,'PhotoFrequencyPaint')); first=state(fig); assert(strcmp(first.Tool,'frequency'));
axesHandle=widget(fig,'PhotoAxes'); pixels=widget(fig,'PhotoImage'); tc=matlab.uitest.TestCase.forInteractiveUse;
wh=[size(first.Spectrum,2) size(first.Spectrum,1)]; center=floor(wh/2)+1;
p0=[.09 .02]; p1=[.21 .15]; tc.drag(axesHandle,center+p0.*wh,center+p1.*wh); drawnow;
painted=state(fig); assert(numel(painted.Creative.FrequencyStrokes)==1,'Real drag did not commit exactly one stroke.');
pathPoints=painted.Creative.FrequencyStrokes{1}.Points;
assert(size(pathPoints,1)>=2 && norm(pathPoints(1,:)-p0)<.025 && norm(pathPoints(end,:)-p1)<.025,'Stroke endpoints do not follow the axes gesture.');
assert(~isequal(painted.Spectrum,first.Spectrum) && isequal(painted.Spectrum,pixels.CData));
assert(~painted.FullValid && isempty(painted.FullResult) && isempty(painted.PreviewResult));
mode=widget(fig,'PhotoFrequencyMode'); mode.Value='erase';
tc.drag(axesHandle,center+p0.*wh,center+p1.*wh); drawnow; erased=state(fig);
assert(numel(erased.Creative.FrequencyStrokes)==2 && strcmp(erased.Creative.FrequencyStrokes{2}.Mode,'erase'));
assert(~isequal(erased.Spectrum,painted.Spectrum) && isequal(erased.Spectrum,pixels.CData));
api.Undo(); actual=state(fig); assert(isequal(actual.Spectrum,painted.Spectrum));
api.Redo(); actual=state(fig); assert(isequal(actual.Spectrum,erased.Spectrum));
% Use a strong notch on the synthetic sinusoid so an outdated export is visible.
api.PaintFrequency([1/13 1/21],.027,.95,'paint'); pending=state(fig);
ref=fl_photo_pipeline(pending.Working,pending.Spec,pending.Creative,struct('OriginalSize',size(pending.Original),'Geometry',{pending.Geometry}));
api.Export(target); assert(isequal(imread(target),uint8(round(ref*255))),'Export differs from evaluated full-size brush pipeline.');
press(widget(fig,'PhotoFrequencyPhoto')); fit=state(fig); expected=fl_photo_resize(ref,1200);
assert(isequal(fit.Result,expected) && isequal(pixels.CData,expected));
api.SetZoom('100'); full=state(fig); assert(isequal(full.Result,ref) && isequal(pixels.CData,ref));
% Repeat the switch without a preceding export (cold materialization).
api.SetTool('frequency'); api.PaintFrequency([.2 .2;.21 .23],.045,.67,'paint');
api.SetView('result'); cold=state(fig); expected=fl_photo_pipeline(cold.Working,cold.Spec,cold.Creative);
assert(isequal(cold.FullResult,expected) && isequal(pixels.CData,fl_photo_resize(expected,1200)));
api.SetTool('frequency'); press(widget(fig,'PhotoFrequencyClear')); cleared=state(fig);
assert(isempty(cleared.Creative.FrequencyStrokes) && isequal(cleared.Spectrum,first.Spectrum));
% Reopen a different image of identical dimensions to test base-cache invalidation.
imwrite(uint8(ones(size(pic))*67),fullfile(temp,'other.png')); api.Open(fullfile(temp,'other.png'));
api.SetTool('frequency'); other=state(fig); assert(~isequal(other.Spectrum,first.Spectrum));
report=struct('MaskComparisons',checks,'GesturePoints',size(pathPoints,1),'OriginalSize',size(ref),'PreviewSize',size(fit.PreviewResult));
fprintf('PASS brush v2.6: %d mask parity/cache comparisons, drag %d points, paint/erase/undo/redo/clear, exact fit/100%%/export, fresh source.\n',checks,size(pathPoints,1));
end
function s=stroke(p,r,o,m)
s=struct('Points',p,'Radius',r,'Opacity',o,'Mode',m);
end
function s=state(fig)
s=getappdata(fig,'PhotoState');
end
function h=widget(fig,tag)
h=findall(fig,'Tag',tag); assert(isscalar(h),'Missing or duplicate control: %s',tag);
end
function press(h)
assert(strcmp(h.Enable,'on')); feval(h.ButtonPushedFcn,h,[]); drawnow;
end
function choose(h,v)
h.Value=v; feval(h.ValueChangedFcn,h,[]); drawnow;
end
function restore(savedPath,savedDir,temp)
cd(savedDir); path(savedPath); if isfolder(temp), rmdir(temp,'s'); end
end
