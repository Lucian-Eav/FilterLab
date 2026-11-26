function M = fl_ext_moire(mountain, screen, screenMeta, opts)
%FL_EXT_MOIRE Fourfold anti-aliasing and directional RGB moire removal.
% opts.Order: base IIR order; opts.Frequency: Nyquist normalized; Angle: degrees.
if nargin < 3 || isempty(screenMeta), screenMeta = struct; end
if nargin < 4 || isempty(opts), opts = struct; end
mountain = double(mountain); screen = double(screen);
validateattributes(mountain,{'numeric'},{'nonempty','finite','real'});
validateattributes(screen,{'numeric'},{'nonempty','finite','real'});
order = option(opts,'Order',6);
validateattributes(order,{'numeric'},{'scalar','integer','>=',1,'<=',10});
cutoff = option(opts,'Cutoff',.25);
validateattributes(cutoff,{'numeric'},{'scalar','>',0,'<',1});
causal = zeros(size(mountain)); zero = causal;
orders = repmat(order,1,size(mountain,3));
[b,a] = sl_butter(order,cutoff);
for c = 1:size(mountain,3)
    causal(:,:,c) = fl_filter2(mountain(:,:,c),b,a,'Edge','symmetric');
    zero(:,:,c) = fl_filter2(mountain(:,:,c),b,a,'Edge','symmetric','ZeroPhase',true);
end
direct = mountain(1:4:end,1:4:end,:);
causal = causal(1:4:end,1:4:end,:); zero = zero(1:4:end,1:4:end,:);
reference = independent_reference(mountain);
evaluation = fl_eval(mean(reference,3),mean(zero,3),struct('FlatWin',5,'CropOrder',4));
shiftC = fl_ext_metrics('rgb_edge_shift',reference,causal);
shiftZ = fl_ext_metrics('rgb_edge_shift',reference,zero);
% Separate full-resolution phase experiment: identical crisp edges in RGB,
% so unequal channel delays cannot be mistaken for pre-existing color edges.
phaseReference = phase_benchmark(); phaseCausal=zeros(size(phaseReference)); phaseZero=phaseCausal;
phaseOrders=[8 4 6];
for c=1:3
    [bp,ap]=sl_butter(phaseOrders(c),cutoff);
    phaseCausal(:,:,c)=fl_filter2(phaseReference(:,:,c),bp,ap,'Edge','symmetric');
    phaseZero(:,:,c)=fl_filter2(phaseReference(:,:,c),bp,ap,'Edge','symmetric','ZeroPhase',true);
end
phaseShiftC=fl_ext_metrics('rgb_edge_shift',phaseReference,phaseCausal);
phaseShiftZ=fl_ext_metrics('rgb_edge_shift',phaseReference,phaseZero);
[detF,detAngle,spectrum] = detect_peak(screen);
frequency = option(opts,'Frequency',detF); angle = option(opts,'Angle',detAngle);
validateattributes(frequency,{'numeric'},{'scalar','positive','finite','<',1});
validateattributes(angle,{'numeric'},{'scalar','finite','real'});
[bn,notch] = fl_ext_notch(frequency,96);
removed = fl_ext_direction(screen,angle,3*(numel(bn)-1), ...
    @(x) sl_filtfilt(bn,1,x.').');
hasClean = isfield(screenMeta,'Clean') && isequal(size(screenMeta.Clean),size(screen));
signalBefore = screen; signalAfter = removed;
if hasClean
    signalBefore = screen-double(screenMeta.Clean);
    signalAfter = removed-double(screenMeta.Clean);
end
[amplitudeBefore,amplitudeAfter] = tone_amplitudes(signalBefore,signalAfter,frequency/2,angle);
attenuation = 20*log10(max(amplitudeBefore,eps)/max(amplitudeAfter,eps));
names = {'直接抽样 PSNR';'因果抗混叠 PSNR';'零相位抗混叠 PSNR'; ...
    '直接抽样 SSIM';'因果抗混叠 SSIM';'零相位抗混叠 SSIM'; ...
    '因果 RGB 最大偏移';'零相位 RGB 最大偏移';'FFT 检测频率'; ...
    'FFT 检测角度';'采用频率';'采用角度';'干扰衰减';'零相位边缘 MAE'};
values = [fl_ext_metrics('psnr',reference,direct); fl_ext_metrics('psnr',reference,causal); ...
    fl_ext_metrics('psnr',reference,zero);fl_ext_metrics('ssim',reference,direct); ...
    fl_ext_metrics('ssim',reference,causal);fl_ext_metrics('ssim',reference,zero); ...
    shiftC.Max;shiftZ.Max;detF;detAngle;frequency;angle;attenuation;evaluation.EdgeMAE];
units = {'dB';'dB';'dB';'';'';'';'px';'px';'Nyquist';'deg';'Nyquist';'deg';'dB';''};
names=[names;{'全分辨率因果 PSNR';'全分辨率零相位 PSNR';'全分辨率因果 SSIM'; ...
    '全分辨率零相位 SSIM';'全分辨率因果 RGB 最大错位';'全分辨率零相位 RGB 最大错位'}];
values=[values;fl_ext_metrics('psnr',phaseReference,phaseCausal); ...
    fl_ext_metrics('psnr',phaseReference,phaseZero);fl_ext_metrics('ssim',phaseReference,phaseCausal); ...
    fl_ext_metrics('ssim',phaseReference,phaseZero);phaseShiftC.Max;phaseShiftZ.Max];
units=[units;{'dB';'dB';'';'';'px';'px'}];
for c=1:3
    names=[names;{sprintf('RGB%d 因果行位移',c);sprintf('RGB%d 因果列位移',c); ...
        sprintf('RGB%d 零相位行位移',c);sprintf('RGB%d 零相位列位移',c)}]; %#ok<AGROW>
    values=[values;phaseShiftC.Shift(c,:).';phaseShiftZ.Shift(c,:).']; %#ok<AGROW>
    units=[units;{'px';'px';'px';'px'}]; %#ok<AGROW>
end
if isfield(screenMeta,'Frequency') && isfield(screenMeta,'Angle')
    names=[names;{'基准真实频率';'基准真实角度'}];
    values=[values;screenMeta.Frequency;screenMeta.Angle]; units=[units;{'Nyquist';'deg'}];
end
if hasClean
    names = [names;{'去摩尔纹前 PSNR';'去摩尔纹后 PSNR';'去摩尔纹前 SSIM';'去摩尔纹后 SSIM'}];
    values = [values;fl_ext_metrics('psnr',screenMeta.Clean,screen); ...
        fl_ext_metrics('psnr',screenMeta.Clean,removed);fl_ext_metrics('ssim',screenMeta.Clean,screen); ...
        fl_ext_metrics('ssim',screenMeta.Clean,removed)];
    units = [units;{'dB';'dB';'';''}];
end
M.Title = '拍屏摩尔纹与降采样抗混叠';
M.Metrics = table(names,values,units,'VariableNames',{'Metric','Value','Unit'});
M.Views = struct('Title',{'四倍降采样','定向去摩尔纹'},'Panels', ...
    {{panel('image','独立长窗 sinc 参考',reference),panel('image','直接抽样',direct), ...
    panel('image','RGB 同阶因果预滤波',causal),panel('image','RGB 同阶零相位预滤波',zero), ...
    panel('image','全分辨率锐利文字参考',phaseReference),panel('image','不等阶因果 RGB 错位',phaseCausal), ...
    panel('image','不等阶零相位 RGB 对齐',phaseZero)}, ...
    {panel('image','拍屏输入',screen),panel('image','二维对数功率谱',spectrum/max(max(spectrum(:)),eps)), ...
    panel('image','定向零相位陷波',removed), ...
    linepanel('陷波幅频响应',[notch.Response notch.ZeroPhaseResponse],notch.Frequency,{'单向 |H|','双向 |H|^2'})}});
M.Views(2).Panels{4}.XLabel='归一化频率 / Nyquist';
M.Views(2).Panels{4}.YLabel='幅频增益';
M.Conclusion = sprintf(['四倍抽样采用独立长窗 sinc 参考；RGB 因果滤波阶数为 %s。' ...
    '独立全分辨率文字靶采用 [8 4 6] 阶对照。' ...
    'FFT 检测 %.4f Nyquist、%.1f°，采用 %.4f Nyquist、%.1f°；干扰衰减 %.2f dB。' ...
    '双向滤波幅频响应为 |H|²。'],mat2str(orders),detF,detAngle,frequency,angle,attenuation);
M.Sampling = struct('Factor',4,'Reference',reference,'Direct',direct,'Causal',causal, ...
    'ZeroPhase',zero,'Orders',orders,'Cutoff',cutoff,'CausalShift',shiftC,'ZeroPhaseShift',shiftZ, ...
    'Evaluation',evaluation);
M.Moire = struct('Input',screen,'Output',removed,'DetectedFrequency',detF, ...
    'DetectedAngle',detAngle,'Frequency',frequency,'Angle',angle,'Spectrum',spectrum, ...
    'Coefficients',bn,'Notch',notch,'AmplitudeBefore',amplitudeBefore, ...
    'AmplitudeAfter',amplitudeAfter,'AttenuationDB',attenuation,'HasCleanReference',hasClean);
M.Phase=struct('Reference',phaseReference,'Causal',phaseCausal,'ZeroPhase',phaseZero, ...
    'Orders',phaseOrders,'CausalShift',phaseShiftC,'ZeroPhaseShift',phaseShiftZ);
end

function X=phase_benchmark()
[x,y]=meshgrid(0:255,0:191); ink=false(size(x));
for row=[35 83 131]
    for col=20:34:220
        dx=x-col; dy=y-row;
        ink=ink | (dx>=0 & dx<=3 & abs(dy)<=12) | ...
            (abs(dy+11)<=2 & dx>=0 & dx<=20) | ...
            (abs(dy)<=2 & dx>=0 & dx<=17) | ...
            (abs(dx-.65*dy-16)<=2 & abs(dy)<=12);
    end
end
X=repmat(.94-.82*double(ink),1,1,3);
end

function ref = independent_reference(X)
% Base MATLAB only: 257-tap windowed ideal lowpass, unrelated to Butterworth.
t = -128:128; f = .125; h = zeros(size(t)); h(t==0) = 2*f;
k = t~=0; h(k) = sin(2*pi*f*t(k))./(pi*t(k));
win = .42+.5*cos(pi*t/128)+.08*cos(2*pi*t/128);
h = h.*win; h = h/sum(h);
[nr,nc,nch] = size(X); iy = reflect((1-128):(nr+128),nr); ix = reflect((1-128):(nc+128),nc);
ref = zeros(numel(1:4:nr),numel(1:4:nc),nch);
for c = 1:nch
    z = conv2(h(:),h(:).',X(iy,ix,c),'valid');
    ref(:,:,c) = z(1:4:end,1:4:end);
end
end
function idx = reflect(k,n)
if n==1, idx=ones(size(k)); else, t=mod(k-1,2*(n-1)); idx=1+min(t,2*(n-1)-t); end
end
function [freq,angle,spectrum] = detect_peak(X)
[nr,nc,nch] = size(X); [xx,yy] = meshgrid(linspace(-1,1,nc),linspace(-1,1,nr));
design = [ones(nr*nc,1) xx(:) yy(:)]; power = zeros(nr,nc);
wy = .5-.5*cos(2*pi*(0:nr-1)'/max(1,nr-1)); wx = .5-.5*cos(2*pi*(0:nc-1)/max(1,nc-1));
% Fit all channel trends with one least-squares factorization.
fit = design \ reshape(X,nr*nc,nch);
window = wy*wx;
for c=1:nch
    z=X(:,:,c)-reshape(design*fit(:,c),nr,nc);
    power=power+abs(fftshift(fft2(z.*window))).^2;
end
fx = ((0:nc-1)-floor(nc/2))/nc; fy = ((0:nr-1)-floor(nr/2))/nr;
[FX,FY] = meshgrid(fx,fy); radius = hypot(FX,FY);
valid = radius>.025 & radius<.45 & (FX>0 | (FX==0 & FY>=0));
masked=power; masked(~valid)=-Inf; [~,at]=max(masked(:)); [r,c]=ind2sub(size(power),at);
dx=0; dy=0;
if c>1 && c<nc, dx=peak_offset(log(power(r,c-1:c+1)+eps)); end
if r>1 && r<nr, dy=peak_offset(log(power(r-1:r+1,c)+eps)); end
vx=fx(c)+dx/nc; vy=fy(r)+dy/nr; freq=2*hypot(vx,vy); angle=atan2d(vy,vx);
spectrum=log10(1+power);
end
function d=peak_offset(v)
d=.5*(v(1)-v(3))/(v(1)-2*v(2)+v(3)); if ~isfinite(d), d=0; end; d=max(-.5,min(.5,d));
end
function [before,after]=tone_amplitudes(X,Y,f,angle)
[nr,nc,nch]=size(X); [xx,yy]=meshgrid(0:nc-1,0:nr-1);
phase=2*pi*f*(xx*cosd(angle)+yy*sind(angle));
design=[ones(nr*nc,1) xx(:)/nc yy(:)/nr cos(phase(:)) sin(phase(:))];
% The basis is shared across channels and across the before/after pair.
fit=design\[reshape(X,[],nch), reshape(Y,[],nch)];
v=hypot(fit(4,:),fit(5,:));
before=sqrt(mean(v(1:nch).^2)); after=sqrt(mean(v(nch+1:end).^2));
end
function v=option(s,n,d)
v=d; if isfield(s,n) && ~isempty(s.(n)), v=s.(n); end
end
function p=panel(k,t,d)
p=struct('Kind',k,'Title',t,'Data',d,'X',[],'Labels',{{}});
end
function p=linepanel(t,d,x,l)
p=struct('Kind','line','Title',t,'Data',d,'X',x,'Labels',{l});
end
