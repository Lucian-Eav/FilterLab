function M = fl_ext_document(img, meta, opts)
%FL_EXT_DOCUMENT Column-only periodic-line rejection and shading correction.
% opts.LinePeriod: pixels; opts.Order: even FIR section order; Cutoff: Nyquist.
if nargin < 2 || isempty(meta), meta=struct; end
if nargin < 3 || isempty(opts), opts=struct; end
img=double(img); validateattributes(img,{'numeric'},{'nonempty','finite','real'});
[nr,nc,nch]=size(img); gray=mean(img,3);
[detPeriod,profileSpectrum,spectrumFrequency]=detect_period(gray);
period=option(opts,'LinePeriod',detPeriod);
validateattributes(period,{'numeric'},{'scalar','finite','>',2});
order=option(opts,'Order',48); cutoff=option(opts,'Cutoff',.03);
validateattributes(cutoff,{'numeric'},{'scalar','finite','>=',.02,'<=',.04});
frequencies=2/period;
if 4/period<.90, frequencies=[frequencies 4/period]; end
[b,notch]=fl_ext_notch(frequencies,order);
% Only vertical columns are filtered: horizontal transfer function is unity.
pad=3*(numel(b)-1); iy=reflect((1-pad):(nr+pad),nr);
causal=zeros(size(img)); causalIIR=causal; zero=causal; background=causal; normalized=causal;
[bl,al]=sl_butter(2,cutoff);
for c=1:nch
    x=img(iy,:,c);
    yc=filter(b,1,x,[],1); yz=sl_filtfilt(b,1,x);
    causal(:,:,c)=yc(pad+(1:nr),:); zero(:,:,c)=yz(pad+(1:nr),:);
    yi=x;
    for f=frequencies
        bk=[1 -2*cos(pi*f) 1]; ak=[1 -2*.88*cos(pi*f) .88^2];
        bk=bk*(sum(ak)/sum(bk));
        yi=filter(bk,ak,yi,[],1);
    end
    causalIIR(:,:,c)=yi(pad+(1:nr),:);
    % Suppress ink influence on the slow illumination envelope with a
    % first lowpass upper envelope, then estimate that envelope by lowpass.
    coarse=fl_filter2(zero(:,:,c),bl,al,'Edge','symmetric','ZeroPhase',true);
    envelopeInput=max(zero(:,:,c),coarse);
    background(:,:,c)=fl_filter2(envelopeInput,bl,al,'Edge','symmetric','ZeroPhase',true);
    % A notch also removes stroke frequencies. Preserve dark ink relative
    % to the estimated paper illumination, blending smoothly at its edges.
    paper=max(background(:,:,c),.05);
    inkWeight=min(1,max(0,(.96-img(:,:,c)./paper)/(.96-.65)));
    corrected=zero(:,:,c)-inkWeight.*max(0,zero(:,:,c)-img(:,:,c));
    normalized(:,:,c)=min(1,max(0,.94*corrected./paper));
end
bg=mask(meta,'BgMask',size(gray)); fg=mask(meta,'FgMask',size(gray));
if isempty(bg) || isempty(fg)
    coarse=mean(background,3);
    contrast=gray./max(coarse,.05);
    if isempty(bg), bg=contrast>.96; end
    if isempty(fg), fg=contrast<.65; end
end
if any(bg(:)) && any(fg(:))
    before=fl_ext_metrics('background_uniformity',img,bg,fg);
    after=fl_ext_metrics('background_uniformity',normalized,bg,fg,img);
else
    before=struct('Std',NaN,'Contrast',NaN,'Reduction',NaN,'Improvement',NaN); after=before;
end
contrast=gray./max(mean(background,3),.05);
% Pick a dark interior pixel for a real document when no reference ROI exists.
search=contrast; border=max(1,floor(min(nr,nc)/8));
search([1:border nr-border+1:nr],:)=Inf; search(:,[1:border nc-border+1:nc])=Inf;
[~,at]=min(search(:)); [probeRow,probeCol]=ind2sub(size(gray),at);
center=option(meta,'ProfileCenter',[probeRow probeCol]);
validateattributes(center,{'numeric'},{'numel',2,'finite','real'});
center=max([1 1],min([nr nc],round(center(:).')));
delay=(numel(b)-1)/2;
radius=min([option(meta,'ProfileRadius',18),center(1)-1,nr-center(1)]);
rows=center(1)+(-radius:radius);
profiles=[gray(rows,center(2)) mean(causalIIR(rows,center(2),:),3) ...
    mean(zero(rows,center(2),:),3) mean(normalized(rows,center(2),:),3)];
symC=fl_ext_metrics('profile_symmetry',profiles(:,2));
symZ=fl_ext_metrics('profile_symmetry',profiles(:,3));
names={'自动检测横线周期';'采用横线周期';'背景标准差（前）';'背景标准差（后）'; ...
    '背景标准差下降率';'文字对比度（前）';'文字对比度（后）';'文字对比度提升'; ...
    '因果笔画对称度';'零相位笔画对称度';'因果 FIR 群延迟';'基频横线衰减';'二次谐波横线衰减'};
lineBefore=line_amplitudes(gray,frequencies); lineAfter=line_amplitudes(mean(zero,3),frequencies);
lineAttenuation=20*log10(max(lineBefore,eps)./max(lineAfter,eps));
if numel(lineAttenuation)<2, harmonicAttenuation=NaN; else, harmonicAttenuation=lineAttenuation(2); end
values=[detPeriod;period;before.Std;after.Std;after.Reduction;before.Contrast; ...
    after.Contrast;after.Improvement;symC.Score;symZ.Score;delay;lineAttenuation(1);harmonicAttenuation];
units={'px';'px';'';'';'%';'';'';'倍';'';'';'px';'dB';'dB'};
hasClean=isfield(meta,'Clean') && isequal(size(meta.Clean),size(img));
if hasClean
    names=[names;{'处理前 PSNR';'处理后 PSNR';'处理后 SSIM'}];
    values=[values;fl_ext_metrics('psnr',meta.Clean,img); ...
        fl_ext_metrics('psnr',meta.Clean,normalized);fl_ext_metrics('ssim',meta.Clean,normalized)];
    units=[units;{'dB';'dB';''}];
end
M.Title='文档去横线与光照归一化';
M.Metrics=table(names,values,units,'VariableNames',{'Metric','Value','Unit'});
M.Views=struct('Title',{'非对称行列滤波','背景归一化与笔画剖面'},'Panels', ...
    {{panel('image','输入文档',img),panel('image','列方向因果 IIR 陷波（非对称拖尾）',causalIIR), ...
    panel('image','列方向零相位陷波',zero), ...
    linepanel('基频及二次谐波陷波响应',[notch.Response notch.ZeroPhaseResponse],notch.Frequency,{'单向 |H|','双向 |H|^2'})}, ...
    {panel('image','超低通背景包络',background),panel('image','光照归一化',normalized), ...
    linepanel('笔画上下边缘剖面',profiles,(-radius:radius).',{'原图','因果 IIR','零相位 Remez','归一化'}), ...
    linepanel('行 75% 分位周期频谱',profileSpectrum,spectrumFrequency,{'功率'})}});
M.Views(1).Panels{4}.XLabel='归一化频率 / Nyquist'; M.Views(1).Panels{4}.YLabel='幅频增益';
M.Views(2).Panels{3}.XLabel='相对笔画中心行偏移 / px'; M.Views(2).Panels{3}.YLabel='归一化灰度';
M.Views(2).Panels{4}.XLabel='归一化频率 / Nyquist'; M.Views(2).Panels{4}.YLabel='功率';
M.Conclusion=sprintf(['横线周期自动检测 %.2f px，采用 %.2f px；仅沿列方向对基频及可用二次谐波陷波。' ...
    '因果非线性相位 IIR 笔画对称度为 %.4f，零相位 Remez 为 %.4f；因果 FIR 分支有 %.0f px 线性群延迟，剖面固定在参考笔画坐标。' ...
    '以二阶 Butterworth（%.3f Nyquist）双向低通估计光照，按相对纸面亮度保留深色笔画后归一化。' ...
    '背景标准差从 %.4f 变为 %.4f，文字对比度提升 %.3f 倍。'], ...
    detPeriod,period,symC.Score,symZ.Score,delay,cutoff,before.Std,after.Std,after.Improvement);
M.Input=img; M.Causal=causal; M.ZeroPhase=zero; M.Background=background;
M.CausalIIR=causalIIR;
M.Normalized=normalized; M.DetectedPeriod=detPeriod; M.LinePeriod=period;
M.Notch=notch; M.Coefficients=b; M.Cutoff=cutoff;
M.LineAmplitudeBefore=lineBefore; M.LineAmplitudeAfter=lineAfter; M.LineAttenuationDB=lineAttenuation;
M.BackgroundBefore=before; M.BackgroundAfter=after; M.BgMask=bg; M.FgMask=fg;
M.Profile=struct('Center',center,'Rows',rows,'Data',profiles,'CausalSymmetry',symC, ...
    'ZeroPhaseSymmetry',symZ,'CausalGroupDelay',delay,'CausalFIRDelay',delay);
end

function amplitudes=line_amplitudes(gray,frequencies)
n=size(gray,1); t=(0:n-1).'; trace=mean(gray,2); D=[ones(n,1) t/n (t/n).^2];
for f=frequencies, D=[D cos(pi*f*t) sin(pi*f*t)]; end %#ok<AGROW>
fit=D\trace; amplitudes=hypot(fit(4:2:end),fit(5:2:end));
end

function [period,power,f]=detect_period(gray)
n=size(gray,1); sorted=sort(gray,2); trace=sorted(:,max(1,round(.75*size(gray,2)))); t=linspace(-1,1,n).'; D=[ones(n,1) t t.^2];
trace=trace-D*(D\trace); win=.5-.5*cos(2*pi*(0:n-1)'/max(1,n-1));
power=abs(fft(trace.*win)).^2; f=(0:n-1)'/n;
valid=find(f>=max(3/n,.04) & f<=.40);
[~,k]=max(power(valid)); k=valid(k); f0=f(k);
% A non-sinusoidal rule can have a stronger second harmonic.
half=round((k-1)/2)+1;
if half>=2 && abs(f(half)*2-f0)<2/n && power(half)>.35*power(k), k=half; end
d=0;
if k>1 && k<n
    v=log(power(k-1:k+1)+eps); d=.5*(v(1)-v(3))/(v(1)-2*v(2)+v(3));
    if ~isfinite(d), d=0; end; d=max(-.5,min(.5,d));
end
period=1/((k-1+d)/n); keep=1:(floor(n/2)+1); power=power(keep); f=2*f(keep);
end
function idx=reflect(k,n)
if n==1, idx=ones(size(k)); else, t=mod(k-1,2*(n-1)); idx=1+min(t,2*(n-1)-t); end
end
function m=mask(meta,name,sz)
m=[]; if isfield(meta,name) && isequal(size(meta.(name)),sz), m=logical(meta.(name)); end
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
