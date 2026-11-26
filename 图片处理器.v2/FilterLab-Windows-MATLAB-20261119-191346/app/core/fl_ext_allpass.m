function M = fl_ext_allpass(img, opts)
%FL_EXT_ALLPASS 二阶节周期稳态全通相位置乱及时间反转解密。
% 密文保持 double，EncVis 仅用于显示。实验展示相位作用与密钥敏感度。
if nargin < 2, opts = struct; end
defaults = struct('Seed',3,'NumPairs',14,'RadiusRange',[.82 .94],'DeltaRadius',.01,'DeltaAngle',.01);
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(opts,names{k}), opts.(names{k}) = defaults.(names{k}); end
end
validateattributes(opts.Seed,{'numeric'},{'scalar','integer','nonnegative','finite'});
validateattributes(opts.NumPairs,{'numeric'},{'scalar','integer','>=',1,'<=',24});
validateattributes(opts.RadiusRange,{'numeric'},{'vector','numel',2,'positive','<',1,'finite'});
if opts.RadiusRange(1)>opts.RadiusRange(2), error('fl_ext_allpass:radius','半径范围必须递增。'); end
validateattributes(opts.DeltaRadius,{'numeric'},{'scalar','nonnegative','finite'});
validateattributes(opts.DeltaAngle,{'numeric'},{'scalar','real','finite'});
img = double(img);
old = rng; cleanup = onCleanup(@() rng(old)); %#ok<NASGU>
rng(opts.Seed,'twister');
row = make_key(opts); col = make_key(opts);
enc = apply_dimension(img,row,2);
enc = apply_dimension(enc,col,1);
dec = decrypt(enc,row,col);
deltas = [.001 .005 .01 .02 .05];
wrongPSNR = zeros(5,1); wrongSSIM = wrongPSNR;
for k = 1:numel(deltas)
    wr = perturb(row,deltas(k),0); wc = perturb(col,deltas(k),0);
    wrong = decrypt(enc,wr,wc);
    wrongPSNR(k) = fl_ext_metrics('psnr',img,wrong);
    wrongSSIM(k) = fl_ext_metrics('ssim',img,wrong);
end
wrong = decrypt(enc,perturb(row,opts.DeltaRadius,0),perturb(col,opts.DeltaRadius,0));
angleWrong = decrypt(enc,perturb(row,0,opts.DeltaAngle),perturb(col,0,opts.DeltaAngle));
w = linspace(0,pi,1025)';
[hr,gr] = response(row,w); [hc,gc] = response(col,w);
% 同时保留组合多项式及既有核心分析输出，实际运算始终采用稳定二阶节。
polynomialHr = sl_freqz(row.B,row.A,w); polynomialHc = sl_freqz(col.B,col.A,w);
legacyDelay = [sl_grpdelay(row.B,row.A,w),sl_grpdelay(col.B,col.A,w)];
energyError = abs(norm(enc(:))-norm(img(:)))/max(norm(img(:)),eps);
spectrumError = 0; powerError = 0;
for c = 1:size(img,3)
    a = abs(fft2(img(:,:,c))); b = abs(fft2(enc(:,:,c)));
    spectrumError = max(spectrumError,max(abs(a(:)-b(:))));
    powerError = max(powerError,max(abs(a(:).^2-b(:).^2))/max(max(a(:).^2),eps));
end
maxError = max(abs(img(:)-dec(:)));
encSSIM = fl_ext_metrics('ssim',img,enc);
decPSNR = fl_ext_metrics('psnr',img,dec); decSSIM = fl_ext_metrics('ssim',img,dec);
wrongP = fl_ext_metrics('psnr',img,wrong); wrongS = fl_ext_metrics('ssim',img,wrong);
magnitudeError = max(abs(abs([hr;hc])-1));
encVis = display_map(enc);
M = struct('Title','模块四 · 全通相位置乱与无损解密','Options',opts, ...
    'Original',img,'RowKey',row,'ColumnKey',col,'Encrypted',enc,'EncVis',encVis, ...
    'Decrypted',dec,'WrongKey',wrong,'WrongAngle',angleWrong,'Frequency',w, ...
    'Response',[hr hc],'GroupDelay',[gr gc],'PolynomialResponse',[polynomialHr polynomialHc], ...
    'CoreGroupDelay',legacyDelay,'MagnitudeError',magnitudeError,'EnergyError',energyError, ...
    'SpectrumError',spectrumError,'RelativePowerError',powerError,'MaxError',maxError, ...
    'EncryptedSSIM',encSSIM,'DecryptedPSNR',decPSNR,'DecryptedSSIM',decSSIM, ...
    'WrongKeyPSNR',wrongP,'WrongKeySSIM',wrongS);
M.Sensitivity = table(deltas',wrongPSNR,wrongSSIM,'VariableNames',{'DeltaRadius','PSNR','SSIM'});
M.AngleSensitivity = struct('DeltaAngle',opts.DeltaAngle,'PSNR',fl_ext_metrics('psnr',img,angleWrong), ...
    'SSIM',fl_ext_metrics('ssim',img,angleWrong));
M.Metrics = table({'全通幅度最大误差';'相对能量误差';'二维幅度谱最大绝对误差';'二维功率谱相对误差'; ...
    '加密 SSIM';'正确密钥 PSNR';'正确密钥 SSIM';'重建最大绝对误差';'半径扰动 PSNR';'半径扰动 SSIM';'角度扰动 PSNR'}, ...
    [magnitudeError;energyError;spectrumError;powerError;encSSIM;decPSNR;decSSIM;maxError;wrongP;wrongS;M.AngleSensitivity.PSNR], ...
    {'1';'1';'1';'1';'1';'dB';'1';'1';'dB';'1';'dB'},'VariableNames',{'Metric','Value','Unit'});
for k = 1:numel(deltas)
    names = {sprintf('半径扰动 %.3g PSNR',deltas(k));sprintf('半径扰动 %.3g SSIM',deltas(k))};
    M.Metrics = [M.Metrics;table(names,[wrongPSNR(k);wrongSSIM(k)],{'dB';'1'}, ...
        'VariableNames',{'Metric','Value','Unit'})]; %#ok<AGROW>
end
M.Metrics = [M.Metrics;table({'角度扰动 SSIM'},M.AngleSensitivity.SSIM,{'1'}, ...
    'VariableNames',{'Metric','Value','Unit'})];
panels = {panel('line','全通幅频响应',abs([hr hc]),w/pi,{'行全通','列全通'}), ...
    panel('line','非线性群时延 / 样本',[gr gc],w/pi,{'行全通','列全通'}), ...
    panel('line','相频响应 / rad',unwrap(angle([hr hc])),w/pi,{'行全通','列全通'}), ...
    panel('pz','行全通极点与倒数共轭零点',[row.Poles,row.Zeros],[],{})};
M.Views(1) = struct('Title','全通系统幅频、相频与群时延','Panels',{panels});
for k = 1:3, M.Views(1).Panels{k}.XLabel = '归一化角频率 / pi'; end
M.Views(1).Panels{1}.YLabel = '幅度'; M.Views(1).Panels{2}.YLabel = '群时延 / 样本';
M.Views(1).Panels{3}.YLabel = '相位 / rad';
panels = {panel('image','原始图像',img,[],{}),panel('image','相位置乱（显示映射）',encVis,[],{}), ...
    panel('image',sprintf('正确解密 %.1f dB',decPSNR),dec,[],{}), ...
    panel('image',sprintf('半径扰动 %.3g / %.1f dB',opts.DeltaRadius,wrongP),wrong,[],{}), ...
    panel('line','密钥半径敏感度 PSNR',wrongPSNR,deltas',{'PSNR / dB'})};
M.Views(2) = struct('Title','相位置乱、时间反转解密与密钥敏感度','Panels',{panels});
M.Views(2).Panels{5}.XLabel = '极点半径扰动'; M.Views(2).Panels{5}.YLabel = 'PSNR / dB';
M.Conclusion = sprintf(['每节采用 r^2、-2r cos(phi)、1 的分子及其反序分母。' ...
    '逐节周期延拓长度 ceil(-14 log(10)/log(rmax))，保留原长度稳态样本。' ...
    '解密逆序通过相同全通节，实测最大重建误差 %.3g。半径扰动 %.3g 的 PSNR 为 %.2f dB，' ...
    '敏感度依赖输入频谱和密钥。'],maxError,opts.DeltaRadius,wrongP);
end

function key = make_key(opts)
r = opts.RadiusRange(1)+diff(opts.RadiusRange)*rand(1,opts.NumPairs);
phi = pi*(.12+.76*rand(1,opts.NumPairs));
key = assemble(r,phi);
end

function key = assemble(r,phi)
n = numel(r); sections = zeros(n,6); B = 1; A = 1;
for k = 1:n
    b = [r(k)^2,-2*r(k)*cos(phi(k)),1]; a = fliplr(b);
    sections(k,:) = [b a]; B = conv(B,b); A = conv(A,a);
end
p = r.*exp(1i*phi); p = [p;conj(p)]; p = p(:);
key = struct('Radii',r,'Angles',phi,'Sections',sections,'B',B,'A',A, ...
    'Poles',p,'Zeros',1./conj(p),'WrapLength',ceil(-14*log(10)/log(max(r))));
end

function key = perturb(key,dr,dp)
% 稳定性边界内的连续扰动，保留原密钥各节对应关系。
key = assemble(min(.985,key.Radii+dr),key.Angles+dp);
end

function y = apply_dimension(x,key,dim)
order = [dim setdiff(1:ndims(x),dim,'stable')];
y = permute(x,order); sz = size(y); n = sz(1); y = reshape(y,n,[]);
idx = mod((-key.WrapLength:n-1),n)+1;
% 每个二阶节都从自己的周期输入开始，避免高阶级联瞬态的多项式尾增长。
for k = 1:size(key.Sections,1)
    z = filter(key.Sections(k,1:3),key.Sections(k,4:6),y(idx,:),[],1);
    y = z(end-n+1:end,:);
end
y = ipermute(reshape(y,sz),order);
end

function y = decrypt(x,row,col)
y = flip(apply_dimension(flip(x,1),col,1),1);
y = flip(apply_dimension(flip(y,2),row,2),2);
end

function [h,g] = response(key,w)
h = ones(size(w)); g = zeros(size(w)); z = exp(-1i*w);
for k = 1:size(key.Sections,1)
    b = key.Sections(k,1:3); a = key.Sections(k,4:6);
    bn = b(1)+b(2)*z+b(3)*z.^2; an = a(1)+a(2)*z+a(3)*z.^2;
    h = h.*(bn./an);
    g = g+real((b(2)*z+2*b(3)*z.^2)./bn-(a(2)*z+2*a(3)*z.^2)./an);
end
end

function y = display_map(x)
lo = min(x(:)); hi = max(x(:));
y = (x-lo)/max(hi-lo,eps);
end

function p = panel(kind,title,data,x,labels)
p = struct('Kind',kind,'Title',title,'Data',data,'X',x,'Labels',{labels},'XLabel','','YLabel','');
end
