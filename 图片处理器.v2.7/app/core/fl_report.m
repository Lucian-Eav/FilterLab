function R = fl_report(X, F, S, varargin)
%FL_REPORT  生成分析图与判别数字，是软件的主要输出模块。
%
%   R = FL_REPORT(X, F, S) 对图像 X、滤波器组 F（见 FL_DESIGN）和规格 S
%   执行完整分析：画出幅频/相频、群延迟、阶跃响应、滤波结果、对称性破坏与
%   去噪对比，并在命令窗口打印全部判别数字。
%
%   名值对参数：
%       'Noisy'   有噪声的图像 Xn，默认由 S 的种子自动生成
%       'FigDir'  图片保存目录，设为空字符串则不保存
%       'Visible' 图窗是否可见，默认 'off'（便于批处理），交互使用时设 'on'
%       'Prefix'  图片文件名前缀，默认为空
%
%   返回 R 结构体：Filtered（1×3 元胞，各滤波器的输出）、Metrics（1×3 结构体
%   数组，见 FL_EVAL）、Noisy（使用的噪声图）、NoisyMetrics、ZeroPhase（零相位
%   对照结果）、Symmetric（主对角对称性检验数字）。
%
%   全部数字都是即时算出来的，没有任何硬编码的结论字符串。
%
%   见 also FL_EVAL, FL_FILTER2, FL_MAIN.

opt = struct('Noisy', [], 'FigDir', '', 'Visible', 'off', 'Prefix', '');
if mod(numel(varargin), 2) ~= 0
    error('fl_report:badArgs', '名值对参数必须是偶数个输入。');
end
for k = 1:2:numel(varargin)
    nm = char(varargin{k});
    if ~isfield(opt, nm)
        error('fl_report:unknownField', '未知参数名：%s', nm);
    end
    opt.(nm) = varargin{k+1};
end

X = double(X);
[m, n] = size(X);
if isempty(opt.Noisy)
    Xn = local_addnoise(X, S);
else
    Xn = double(opt.Noisy);
    if ~isequal(size(Xn), size(X))
        error('fl_report:noisySize', '噪声图与原图尺寸必须一致。');
    end
end

% 本次评估的裁边量：按"最长滤波器的阶数"与"图像有多小"两头取小。
% 32×32 上是 4（与历史结果一致），1024×1024 上自动放到 12，把瞬态盖掉。
S.CropOrder = max([F.Order]);
S.Crop      = fl_crop(S, size(X), S.CropOrder);
fprintf('\n 评估裁边 : %d 像素（滤波器最高 %d 阶，图像 %d×%d）\n', ...
        S.Crop, S.CropOrder, size(X,1), size(X,2));

vis = opt.Visible;
if strcmpi(vis, 'off')
    figvis = 'off';
else
    figvis = 'on';
end

names = {F.Name};
nF = numel(F);
R = struct();

% ========================= 图 1：幅频与相频 =========================
fig = local_newfig(figvis, '幅频与相频特性');
w = linspace(0, pi, 2048);
cl = lines(nF);
for k = 1:nF
    H = sl_freqz(F(k).B, F(k).A, w);
    subplot(2,1,1);
    plot(w/pi, 20*log10(max(abs(H), 1e-8)), 'Color', cl(k,:), 'LineWidth', 1.4); hold on;
    subplot(2,1,2);
    plot(w/pi, unwrap(angle(H)), 'Color', cl(k,:), 'LineWidth', 1.4); hold on;
end
subplot(2,1,1);
grid on; xlabel('归一化频率 \omega/\pi'); ylabel('|H| (dB)');
title('幅频特性（三个滤波器截止频率相同，差别只在阶数与结构）');
legend(names, 'Location', 'southwest');
subplot(2,1,2);
grid on; xlabel('归一化频率 \omega/\pi'); ylabel('相位 (rad)');
title('相频特性（曲线是否为过原点的直线，对应是否线性相位）');
legend(names, 'Location', 'southwest');
local_savefig(fig, opt, 'fig1_amp_phase.png');

% ========================= 图 2：群延迟 =========================
wp = linspace(0, pi*S.PassW, 1024);
fig = local_newfig(figvis, '群延迟');
for k = 1:nF
    g = sl_grpdelay(F(k).B, F(k).A, wp);
    plot(wp/pi, g, 'Color', cl(k,:), 'LineWidth', 1.4); hold on;
end
grid on; xlabel('归一化频率 \omega/\pi'); ylabel('群延迟 (样本)');
title(sprintf('通带内群延迟：标准差为 0 即线性相位（按 S.PassW=%.2f 统计）', S.PassW));
legend(names, 'Location', 'best');
local_savefig(fig, opt, 'fig2_group_delay.png');

% ========================= 图 3：阶跃响应 =========================
fig = local_newfig(figvis, '阶跃响应与超调');
L = 128;
st = ones(1, L);
fprintf('\n【第 3 问】阶跃响应超调（稳态归一化为 1）\n');
os = zeros(1, nF);
for k = 1:nF
    y = filter(F(k).B, F(k).A, st);
    y = y / y(end);
    os(k) = (max(y) - y(end)) * 100;
    fprintf('  %-4s 超调 %6.2f%%\n', names{k}, os(k));
    subplot(1,2,1);
    plot(0:L-1, y, 'Color', cl(k,:), 'LineWidth', 1.3); hold on;
    subplot(1,2,2);
    stem(0:min(L,numel(F(k).B))-1, F(k).Braw(1:min(L,numel(F(k).B))), ...
         'filled', 'Color', cl(k,:)); hold on;
end
subplot(1,2,1);
grid on; xlabel('样本'); ylabel('归一化输出');
title('阶跃响应（过冲越大，图像边缘越容易出现亮暗条）');
legend(arrayfun(@(k) sprintf('%s  超调 %.2f%%', names{k}, os(k)), 1:nF, ...
    'UniformOutput', false), 'Location', 'southeast');
subplot(1,2,2);
grid on; xlabel('抽头序号'); ylabel('系数');
title('冲激响应系数（全为正 ⇒ 阶跃响应单调 ⇒ 超调必为 0）');
legend(names, 'Location', 'best');
local_savefig(fig, opt, 'fig3_step.png');

% ========================= 滤波 =========================
R.Filtered = cell(1, nF);
R.Metrics  = [];
fprintf('\n【第 4/5 问】二维可分离滤波结果\n');
fprintf('  %-4s %-3s %-7s %-4s %-8s %-10s %s\n', ...
        '滤波', '阶', '增益', '线性', '过零', '越界', '动态范围');
for k = 1:nF
    R.Filtered{k} = fl_filter2(X, F(k).B, F(k).A, 'Edge', S.Edge);
    mk = fl_eval(X, R.Filtered{k}, S);
    if k == 1
        R.Metrics = repmat(mk, 1, nF);
    end
    R.Metrics(k) = mk;
    fprintf('  %-5s %-4d %-8.4f %-5s %-9.4f %-11.4f [%.2f, %.2f]\n', ...
        names{k}, F(k).Order, F(k).DCGain, local_yn(F(k).Linear), ...
        mk.ZeroCross, mk.OutEnergy, ...
        mk.DynRange(1), mk.DynRange(2));
end
fprintf('  （原图自身的边界过零数 %.2f/行，仅作尺度参照；上表已按像素归一）\n', local_zc(X));

fig = local_newfig(figvis, '滤波结果');
allY = X;
for k = 1:nF, allY = [allY, R.Filtered{k}]; end
him = imagesc(allY); axis image off; colormap(gray);
clim = [min(allY(:)), max(allY(:))];
set(gca, 'CLim', clim);
title(sprintf('原图与 %d 个滤波器的输出（统一色标 [%.3f, %.3f]，避免各自缩放造成错觉）', ...
      nF, clim(1), clim(2)));
colorbar;
local_savefig(fig, opt, 'fig4_filtered.png');

% ==================== 图 5：对称性与失真 ====================
fig = local_newfig(figvis, '对称性与形状失真');
% 面板数 = 1（原图）+ nF（交换误差图）+ 1（冲激响应）+ 1（剖面），按此自适应网格，
% 这样 1 个、3 个、8 个滤波器都不会撞车（原来写死 2×3，超过 3 个就重叠）。
nPan = nF + 3;
nCol = max(3, min(4, nPan));
nRow = ceil(nPan / nCol);

% 交换误差先算一次，图和正文共用同一个数。
% 之前这里用未配准的 max|Yf-fliplr(Y)| 直接当标题，正文却打印配准后的值，
% 出现"图上 1.18、正文 0.46"的自相矛盾（审计 H3 指出的问题）。
R.MirrorCommute = zeros(1, nF);
for k = 1:nF
    Yz = fl_filter2(fliplr(X), F(k).B, F(k).A, 'Edge', S.Edge);
    Yw = fliplr(R.Filtered{k});
    [dr, dc] = fl_shift(Yz, Yw);
    Yz = circshift(Yz, -[dr dc]);
    D  = Yz - Yw;
    L  = max(numel(F(k).B), numel(F(k).A));
    if 2*L < min(size(D))
        D = D(L+1:end-L, L+1:end-L);
    end
    R.MirrorCommute(k) = max(max(abs(D)));
    subplot(nRow, nCol, 1 + k);
    imagesc(D); axis image off; colorbar;
    title(sprintf('%s: 交换误差 %.3e', names{k}, R.MirrorCommute(k)));
end

subplot(nRow, nCol, 1);
imagesc(X); axis image off; colormap(gray); title('原图 x');

subplot(nRow, nCol, 1 + nF + 1);
for k = 1:nF
    plot(F(k).Braw / max(abs(F(k).Braw)), 'o-', 'Color', cl(k,:)); hold on;
end
grid on; xlabel('抽头'); ylabel('归一化系数');
title('冲激响应：偶对称 ⇒ 线性相位');
legend(names, 'Location', 'best');

subplot(nRow, nCol, 1 + nF + 2);
for k = 1:nF
    Y = R.Filtered{k};
    row = round(m/2);
    plot(1:n, Y(row,:), 'Color', cl(k,:)); hold on;
end
plot(1:n, X(round(m/2),:), 'k--', 'LineWidth', 1);
grid on; xlabel('列索引'); ylabel('灰度');
title('中间行剖面（看左右振铃是否对称）');
legend([names, {'原图'}], 'Location', 'best');
local_savefig(fig, opt, 'fig5_symmetry.png');

R.Symmetric.X = max(abs(X(:) - reshape(X.', [], 1)));
% R.MirrorCommute 已在图 5 之前算好（图里印的就是它），这里只打印，不要再置零。
fprintf('\n【第 5 问】对称性检验\n');
fprintf('  原图与自身转置之差 ‖X-Xᵀ‖_max = %.3g\n', R.Symmetric.X);
fprintf('  行、列用同一算子时 Y = A·X·Aᵀ，只要 X = Xᵀ 就恒有 Y = Yᵀ（与是否线性相位无关）：\n');
for k = 1:nF
    fprintf('    %s: ‖Y-Yᵀ‖_max = %.3g\n', names{k}, R.Metrics(k).SymT);
end
fprintf('  线性相位 ⟺ 冲激响应偶对称 ⟺ 滤波与左右镜像可交换。用交换误差判别：\n');
fprintf('    max | filter(fliplr(X)) - fliplr(filter(X)) |（只统计内部，避开零延拓边界）\n');
for k = 1:nF
    fprintf('    %s: %.3e\n', names{k}, R.MirrorCommute(k));
end
fprintf('  这个判据对平移不敏感（两边位移相同），不会被群延迟污染，比直接拿\n');
fprintf('  "输出与其镜像之差"当指标可靠得多。\n');

% ==================== 图 6：去噪 ====================
fig = local_newfig(figvis, '去噪对比');
% 面板 = 1（含噪图）+ nF，按面板数自适应，滤波器个数不再被写死在 3
nPan6 = 1 + nF;
nC6 = ceil(sqrt(nPan6)); nR6 = ceil(nPan6 / nC6);
subplot(nR6, nC6, 1); imagesc(Xn); axis image off; colormap(gray);
title(sprintf('含噪声图像 xn（σ≈%.2f）', S.NoiseSigma));
fprintf('\n【第 6 问】去噪效果（必须先配准再算误差）\n');
fprintf('  %-6s %-10s %-10s %-12s %-12s %s\n', ...
        '滤波器', '平移量', 'PSNR/未配准', 'PSNR/配准后', '平坦区RMS', '边缘MAE');
R.Noisy = Xn;
e0 = Xn - X;
fprintf('  %-6s %-10s %-10.2f %-12s %-12.4f %s\n', '未滤波', '-', ...
        local_psnr_crop(X, Xn, S.Crop), '-', sqrt(mean(e0(R.Metrics(1).FlatMask).^2)), '-');
R.NoisyMetrics = [];
for k = 1:nF
    Yn = fl_filter2(Xn, F(k).B, F(k).A, 'Edge', S.Edge);
    mn = fl_eval(X, Yn, S);
    if k == 1
        R.NoisyMetrics = repmat(mn, 1, nF);
    end
    R.NoisyMetrics(k) = mn;
    subplot(nR6, nC6, 1+k);
    imagesc(Yn); axis image off; colormap(gray);
    mets = R.NoisyMetrics(k);
    title(sprintf('%s：平移(%d,%d)  配准后 %.2f dB', ...
          names{k}, mets.Shift(1), mets.Shift(2), mets.PSNR));
    fprintf('  %-6s (%+d,%+d)   %-10.2f %-12.2f %-12.4f %.4f\n', names{k}, ...
        mets.Shift(1), mets.Shift(2), mets.PSNRraw, mets.PSNR, ...
        mets.FlatRMS, mets.EdgeMAE);
end
local_savefig(fig, opt, 'fig6_denoise.png');

% ==================== 图 7：零相位对照 ====================
fig = local_newfig(figvis, '零相位对照实验');
p0z = local_psnr_crop(X, Xn, S.Crop);
fprintf('\n【零相位对照】前后向滤波把相位归零，但等效幅频变成 |H|^2（带宽缩窄一次）：\n');
fprintf('  %-6s %-10s %-10s %-10s\n', 'f', '平移', 'PSNR', '不滤波');
zp = zeros(1, nF); zs = zeros(nF, 2);
nPan7 = nF + 1;                                   % +1 是右下角那段说明文字
nC7 = ceil(sqrt(nPan7)); nR7 = ceil(nPan7 / nC7);
for k = 1:nF
    Yz = fl_filter2(Xn, F(k).B, F(k).A, 'Edge', S.Edge, 'ZeroPhase', true);
    [dr, dc] = fl_shift(Yz, Xn);
    zs(k,:) = [dr dc];
    Yzal = circshift(Yz, -[dr dc]);
    zp(k) = local_psnr_crop(X, Yzal, S.Crop);
    fprintf('  %-6s [%d %d]%-6s %-10.3f %-10.3f\n', names{k}, dr, dc, '', zp(k), p0z);
    subplot(nR7, nC7, k);
    imagesc(Yz); axis image off; colormap(gray);
    title(sprintf('%s 零相位：平移(%d,%d)', names{k}, dr, dc));
end
subplot(nR7, nC7, nF + 1);
text(0.05, 0.6, {'零相位（前后向）滤波的等效幅频是 |H|^2，', ...
                 '相位虽然归零，带宽却被缩窄了一次。', ...
                 '所以它不是"只去掉相位"的对照组，', ...
                 '拿它比较时必须同时说明幅频已经变了。'}, ...
     'FontSize', 10, 'VerticalAlignment', 'top');
axis off;
local_savefig(fig, opt, 'fig7_zerophase.png');

R.ZeroPhase = struct('Shift', zs, 'PSNR', zp, 'PSNRnoisy', p0z, ...
    'Note', '前后向滤波的等效幅频为 |H|^2');

if strcmpi(vis, 'off'), close all; end
end

% ========================= 局部函数 =========================
function fig = local_newfig(vis, nm)
fig = figure('Visible', vis, 'Color', 'w', 'Name', nm, 'NumberTitle', 'off', ...
             'Position', [80 80 1100 620]);
end

function local_savefig(fig, opt, fname)
if isempty(opt.FigDir), return; end
if ~exist(opt.FigDir, 'dir'), mkdir(opt.FigDir); end
fn = fullfile(opt.FigDir, [opt.Prefix fname]);
try
    print(fig, fn, '-dpng', '-r110');
catch err
    warning('fl_report:saveFail', '保存 %s 失败：%s', fn, err.message);
end
end

function Xn = local_addnoise(X, S)
% 用固定种子加高斯白噪声，保证每次运行结果一致。
old = rng;
rng(S.Seed);
Xn = X + S.NoiseSigma * randn(size(X));
rng(old);
end

function s = local_yn(tf)
if tf, s = '是'; else, s = '否'; end
end

function v = local_psnr_crop(X, Y, c)
[m, n] = size(X);
v = 10*log10(1 / mean(mean((X(c+1:m-c, c+1:n-c) - Y(c+1:m-c, c+1:n-c)).^2)));
end

function v = local_zc(X)
[m, n] = size(X);
zc = 0;
for i = 1:m
    s = X(i,:) - 0.5;
    zc = zc + sum(sign(s(1:end-1)) .* sign(s(2:end)) < 0);
end
v = zc / m;
end
