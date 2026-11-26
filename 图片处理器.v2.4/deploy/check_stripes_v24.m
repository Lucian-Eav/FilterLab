function check_stripes_v24(outputDir)
%CHECK_STRIPES_V24 Check stripe aliasing and the controls that display it.
% check_stripes_v24() runs invisibly. Pass a directory to save both GUI states.
if nargin < 1, outputDir = ''; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'app'),fullfile(root,'app','core'));

% Reference samples use the physical pixel coordinates and known cosines.
frequencies = [24 40];
x = 0:255;
original = .5 + .5*cos((2*pi/256)*(frequencies(:)*x));
tolerance = 1e-12;
assert(max(abs(original(1,:)-original(2,:))) > .5);
for step = [4 2 1]
    s = fl_stripe_samples(step,frequencies);
    indices = 1:step:256;
    expected = original(:,indices);
    assert(isequal(s.X,x) && isequal(s.SampleX,x(indices)) && s.Count == numel(indices));
    assert(isequal(size(s.Original),size(original)) && max(abs(s.Original(:)-original(:))) < tolerance);
    assert(isequal(size(s.Samples),size(expected)) && max(abs(s.Samples(:)-expected(:))) < tolerance);
    if step == 4
        peaks = [24 24];
        assert(max(abs(s.Samples(1,:)-s.Samples(2,:))) < tolerance,'40 cycles must fold onto 24.');
    else
        peaks = frequencies;
        assert(max(abs(s.Samples(1,:)-s.Samples(2,:))) > .5,'Step %d must distinguish A and B.',step);
    end
    if step == 1
        assert(isequal(s.Original,s.Samples),'Unit-step sampling must preserve every pixel.');
    end
    assert(s.Nyquist == 128/step && isequal(s.Bins,0:128/step) && isequal(s.Peaks,peaks));
    expectedAmplitude = zeros(2,numel(s.Bins));
    expectedAmplitude(1,peaks(1)+1) = .5;
    expectedAmplitude(2,peaks(2)+1) = .5;
    assert(isequal(size(s.Amplitude),size(expectedAmplitude)) && ...
        max(abs(s.Amplitude(:)-expectedAmplitude(:))) < tolerance,'Unexpected one-sided FFT at step %d.',step);
end

visible = 'off';
if ~isempty(outputDir)
    if ~isfolder(outputDir), mkdir(outputDir); end
    visible = 'on';
end
host = uifigure('Name','条纹与混叠','Position',[100 80 1150 760],'Visible',visible);
cleanup = onCleanup(@()delete(host)); %#ok<NASGU>
outer = uigridlayout(host,[1 1],'Padding',[0 0 0 0]);
group = uitabgroup(outer);
page = uitab(group,'Title','条纹与混叠');
view = FL_sampling_stripes(page);
api = getappdata(page,'StripesActions');
dropdown = widget(view,'StripesStep');
freqA = widget(view,'StripesFrequencyA');
freqB = widget(view,'StripesFrequencyB');
verifyView(view,api.GetState(),4,frequencies,[24 24],true);
if ~isempty(outputDir)
    drawnow; exportapp(host,fullfile(outputDir,'条纹-步长4-重合.png'));
end
changeValue(dropdown,2);
verifyView(view,api.GetState(),2,frequencies,[24 40],false);
if ~isempty(outputDir)
    drawnow; exportapp(host,fullfile(outputDir,'条纹-步长2-分离.png'));
end
changeValue(freqA,16);
verifyView(view,api.GetState(),2,[16 40],[16 40],false);
changeValue(freqB,48);
verifyView(view,api.GetState(),2,[16 48],[16 48],false);
changeValue(dropdown,4);
verifyView(view,api.GetState(),4,[16 48],[16 16],true);
fprintf('PASS stripe sampling: 24/40 alias at step 4, separate at step 2, step-1 identity, dropdown and both frequency callbacks.\n');
end

function verifyView(view,s,step,frequencies,peaks,coincident)
assert(s.Step == step && isequal(s.Frequencies,frequencies) && isequal(s.Peaks,peaks));
for k = 1:2
    name = char(64+k);
    curve = widget(view,['StripesCurve' name]);
    dots = widget(view,['StripesSamples' name]);
    trace = widget(view,['StripesFFT' name]);
    peak = widget(view,['StripesPeak' name]);
    before = widget(view,sprintf('StripesRaster%d1',k));
    after = widget(view,sprintf('StripesRaster%d2',k));
    assert(isequal(curve.XData,s.X) && isequal(curve.YData,s.Original(k,:)));
    assert(isequal(dots.XData,s.SampleX) && isequal(dots.YData,s.Samples(k,:)));
    assert(isequal(trace.XData,s.Bins) && isequal(trace.YData,s.Amplitude(k,:)));
    assert(peak.XData == peaks(k) && abs(peak.YData-.5) < 1e-12);
    assert(isequal(before.CData,repmat(s.Original(k,:),2,1)));
    assert(isequal(after.CData,repmat(s.Samples(k,:),2,1)));
end
status = widget(view,'StripesStatus');
if coincident
    assert(s.MaxDifference < 1e-12 && contains(status.Text,'采样点重合'));
else
    assert(s.MaxDifference > .1 && contains(status.Text,'采样点不同'));
end
end

function changeValue(control,value)
previous = control.Value;
control.Value = value;
feval(control.ValueChangedFcn,control,struct('PreviousValue',previous,'Value',value));
drawnow;
end

function h = widget(parent,tag)
h = findall(parent,'Tag',tag);
assert(isscalar(h),'Missing or duplicate control %s.',tag);
end
