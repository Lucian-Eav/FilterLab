function report = check_spectrum_explore()
%CHECK_SPECTRUM_EXPLORE Analytic checks for the spectrum lesson (base MATLAB).
oldPath = path;
restore = onCleanup(@()path(oldPath)); %#ok<NASGU>
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'app','core'),'-begin');
report = struct('StripeCases',0, 'WorstRoundTripError',0, 'WorstPhaseErrorRad',0);
N = 256;
center = N/2+1;
axisBins = (-N/2:N/2-1)/N;
expectedAxis = {'vertical','horizontal'};
for direction = 1:numel(expectedAxis)
    for k = [1 13 32]
        base = fl_spectrum_explore(expectedAxis{direction}, k, 0, 'all', 0);
        expected = repmat(.5 + .5*sin(2*pi*k*(0:N-1)/N), N, 1);
        plus = [center,center+k]; minus = [center,center-k];
        if direction == 2
            expected = expected.';
            plus = fliplr(plus); minus = fliplr(minus);
        end
        near(base.Input, expected, 2e-14, 'stripe pixels');
        near(base.Output, expected, 2e-14, 'full inversion');
        near(base.Fx,axisBins,0,'horizontal frequency coordinates');
        near(base.Fy,axisBins.',0,'vertical frequency coordinates');
        assert(islogical(base.Mask) && isequal(base.Mask,true(N)));
        near(base.RetainedEnergy,1,1e-14,'all-pass energy');
        report.WorstRoundTripError = max(report.WorstRoundTripError,base.MaxError);

        % The real sine contributes N^2/4 at each conjugate peak; the offset
        % contributes N^2/2 at DC. Other bins should contain roundoff only.
        pos = sub2ind([N N],plus(1),plus(2));
        neg = sub2ind([N N],minus(1),minus(2));
        lines = zeros(N); lines(center,center) = N^2/2; lines([pos neg]) = N^2/4;
        near(base.Spectrum,log1p(lines),2e-9,'DC and conjugate peaks');
        near(phase_diff(base.Phase(pos),-pi/2),0,1e-12,'positive sine phase');
        near(phase_diff(base.Phase(neg),pi/2),0,1e-12,'negative sine phase');

        for shift = [-5 11]
            moved = fl_spectrum_explore(expectedAxis{direction}, k, shift, 'all', .5);
            near(moved.Input,circshift(expected,shift,3-direction),2e-14,'shift direction');
            near(moved.Spectrum,base.Spectrum,2e-9,'translation preserves magnitude');
            delta = 2*pi*k*shift/N;
            phaseErrors = [phase_diff(moved.Phase(pos),base.Phase(pos)-delta), ...
                           phase_diff(moved.Phase(neg),base.Phase(neg)+delta)];
            near(phaseErrors,[0 0],1e-12,'translation phase at both peaks');
            report.WorstPhaseErrorRad = max([report.WorstPhaseErrorRad,abs(phaseErrors)]);
        end

        low = fl_spectrum_explore(expectedAxis{direction},k,0,'low',(k-.5)/N);
        high = fl_spectrum_explore(expectedAxis{direction},k,0,'high',(k-.5)/N);
        near(low.Output,.5*ones(N),2e-14,'below stripe frequency retains DC');
        near(high.Output,expected-.5,2e-14,'high-pass retains signed sine');
        near(low.RetainedEnergy,2/3,1e-14,'DC energy fraction');
        near(high.RetainedEnergy,1/3,1e-14,'AC energy fraction');
        near(high.MaxError,.5,2e-14,'reported input-output error');
        assert(isequal(low.Mask,~high.Mask) && ~low.Mask(pos) && ~low.Mask(neg));
        atEdge = fl_spectrum_explore(expectedAxis{direction},k,0,'low',k/N);
        outsideEdge = fl_spectrum_explore(expectedAxis{direction},k,0,'high',k/N);
        assert(atEdge.Mask(pos) && atEdge.Mask(neg) && ~outsideEdge.Mask(pos) && ~outsideEdge.Mask(neg));
        near(atEdge.Output,expected,2e-14,'inclusive low-pass edge');
        near(outsideEdge.Output,zeros(N),2e-14,'complementary high-pass edge');
        report.StripeCases = report.StripeCases + 1;
    end
end

% A diagonal sinusoid has both components below .25 but radius above .25.
% The second sinusoid is horizontal in frequency and survives this cutoff.
[x,y] = meshgrid(0:14,0:8);
slow = .5 + .1*cos(2*pi*x/15);
diagonal = .2*cos(2*pi*(3*x/15+2*y/9));
photo = slow + diagonal;
lo = fl_spectrum_explore('photo',1,0,'low',.25,photo);
hi = fl_spectrum_explore('photo',1,0,'high',.25,photo);
near(lo.Fx,(-7:7)/15,0,'odd width coordinates');
near(lo.Fy,(-4:4).'/9,0,'odd height coordinates');
near(lo.Output,slow,2e-14,'radial low-pass on rectangular photo');
near(hi.Output,diagonal,2e-14,'radial high-pass on rectangular photo');
near(lo.RetainedEnergy,sum(slow(:).^2)/sum(photo(:).^2),1e-14,'spatial energy fraction');
assert(isequal(lo.Mask,~hi.Mask));
% Verify grayscale conversion with independently varying channels.
rgb = cat(3,uint8(10*x),uint8(30*y),uint8(5*x+7*y));
luma = (.2126*double(rgb(:,:,1)) + .7152*double(rgb(:,:,2)) + .0722*double(rgb(:,:,3)))/255;
r = fl_spectrum_explore('photo',1,3,'all',0,rgb);
near(r.Input,circshift(luma,[0 3]),2e-14,'RGB luma and horizontal photo shift');
near(r.Output,r.Input,2e-14,'odd RGB inversion');
report.WorstRoundTripError = max(report.WorstRoundTripError,r.MaxError);
dc = fl_spectrum_explore('photo',1,0,'low',0,photo);
assert(nnz(dc.Mask)==1 && dc.Mask(5,8));
near(dc.Output,mean(photo(:))*ones(size(photo)),2e-14,'cutoff zero gives the mean');
for mode = {'all','low','high'}
    black = fl_spectrum_explore('photo',1,0,mode{1},.5,false(7,11));
    near(black.Output,zeros(7,11),0,'zero image output');
    near(black.RetainedEnergy,0,0,'zero image energy convention');
end

% 2-pixel checkerboard period along rows cancels exactly under 2:1 reduction.
pattern = repmat(uint16(mod((0:511).',2)*65535),1,128);
small = fl_spectrum_explore('photo',1,0,'all',.5,pattern);
near(small.Input,.5*ones(256,64),1e-14,'area-average preview');
% A fractional reduction must preserve the field of view, mean and aspect.
wide = repmat(linspace(0,1,513),123,1);
small = fl_spectrum_explore('photo',1,0,'all',.5,wide);
assert(isequal(size(small.Input),[61 256]));
near(mean(small.Input(:)),.5,1e-13,'fractional preview mean');
assert(small.Input(1,1)<.01 && small.Input(end,end)>.99);
for dims = {[1 21],[17 1],[1 1]}
    oneD = reshape(linspace(.1,.9,prod(dims{1})),dims{1});
    r = fl_spectrum_explore('photo',1,-3,'all',0,oneD);
    near(r.Output,circshift(oneD,-3,2),2e-14,'single-row/column photo');
end
fprintf('Spectrum exploration passed: %d stripe cases, shifted phases, filters and photo fixtures.\n',report.StripeCases);
fprintf('Worst full inversion %.3g, worst peak phase error %.3g rad.\n', ...
    report.WorstRoundTripError, report.WorstPhaseErrorRad);
end

function delta = phase_diff(actual, expected)
delta = angle(exp(1i*(actual-expected)));
end

function near(actual, expected, tolerance, label)
assert(isequal(size(actual),size(expected)),'Shape mismatch: %s',label);
err = max(abs(actual(:)-expected(:)));
assert(isfinite(err) && err<=tolerance,'%s: error %.3g exceeds %.3g',label,err,tolerance);
end
