function out = FL_innov(S, varargin)
%FL_INNOV 三个创新模块的驱动：相位隔离、滤波决策、故障注入
%
%   OUT = FL_INNOV() 或 FL_INNOV(S, 'Save', true, 'Visible', 'off')
%
%   依次运行：
%     A  FL_PHASETEST  同幅频不同相位的滤波器族 + 位移解析预测
%     B  FL_DECIDE     带弃权的滤波决策器（解析风险模型）
%     C  FL_MUTATE     故障注入自检（变异测试）
%
%   并画一张四联图：幅频对比、相位对比、阶跃响应、预测与实测 PSNR 对照。
%
%   见 also FL_PHASETEST, FL_DECIDE, FL_MUTATE.

if nargin < 1 || isempty(S)
    S = fl_spec();
end
opt = struct('Save', true, 'Visible', 'off', 'FigDir', '');
for k = 1:2:numel(varargin)
    opt.(varargin{k}) = varargin{k+1};
end
if isempty(opt.FigDir)
    here = fileparts(mfilename('fullpath'));
    opt.FigDir = fullfile(here, 'output');
end
if ~exist(opt.FigDir, 'dir')
    mkdir(opt.FigDir);
end

X = local_sample();
rng(S.Seed);
Xn = X + S.NoiseSigma * randn(size(X));

fprintf('\n');
fprintf('################################################################\n');
fprintf('#  三个创新模块：相位隔离 / 带弃权决策 / 故障注入自检\n');
fprintf('#  图像 %dx%d，噪声 sigma = %.2f\n', size(X, 1), size(X, 2), S.NoiseSigma);
fprintf('################################################################\n');

% -------------------------------- A
T = fl_phasetest(S);

% -------------------------------- B
D = fl_decide(Xn, S, 'Truth', X);

% -------------------------------- C
M = fl_mutate(X, S);

% -------------------------------- 汇总
nOK = sum([M.OK]);
fprintf('\n========== 汇总 ==========\n');
fprintf('A 相位隔离：幅频最大偏差 %.2e，位移判据差 %.2e\n', ...
    max([T.MagMax]), max(abs([T.DShift])));
fprintf('B 决策器  ：%s\n', D.Reason);
fprintf('C 故障注入：%d/%d 个变异判定正确\n', nOK, numel(M));

% -------------------------------- 图
fig = figure('Visible', opt.Visible, 'Color', 'w', 'Position', [80 80 1100 780]);
w = linspace(0, pi, 512).';

subplot(2, 2, 1);
hold on; grid on; box on;
for i = 1:numel(T)
    H = exp(-1i * w * (0:numel(T(i).B)-1)) * T(i).B(:);
    plot(w / pi, abs(H), 'LineWidth', 1.2);
end
xlabel('\omega / \pi'); ylabel('|H(e^{j\omega})|');
title(sprintf('幅频：%d 条曲线完全重合（看不出差别）', numel(T)));
legend({T.Name}, 'Location', 'northeast');

subplot(2, 2, 2);
hold on; grid on; box on;
for i = 1:numel(T)
    H = exp(-1i * w * (0:numel(T(i).B)-1)) * T(i).B(:);
    plot(w / pi, unwrap(angle(H)), 'LineWidth', 1.2);
end
xlabel('\omega / \pi'); ylabel('\angle H  (rad)');
title('相位：这才是唯一的差别'); legend({T.Name}, 'Location', 'southwest');

subplot(2, 2, 3);
hold on; grid on; box on;
s = [zeros(1, 40) ones(1, 56)];
for i = 1:numel(T)
    y = filter(T(i).B, 1, s);
    plot(0:numel(y)-1, y, 'LineWidth', 1.2);
end
xline(40 + T(1).Tau, 'k--');
xlabel('n'); ylabel('阶跃响应');
title(sprintf('阶跃：实测穿越点 vs 解析群延迟 %.2f', T(1).Tau));
legend({T.Name}, 'Location', 'southeast');

subplot(2, 2, 4);
names = {D.Candidates.Name};
pred = [D.Candidates.PSNRpred];
tru  = [D.Candidates.PSNRtrue];
bar([pred(:) tru(:)]);
grid on; box on;
set(gca, 'XTick', 1:numel(names), 'XTickLabel', names, 'XTickLabelRotation', 15);
ylabel('PSNR (dB)');
legend({'解析预测', '实测'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
title(sprintf('决策器：%s', pick(D.Recommend, '建议滤波', '建议弃权')));
ylim([0, max([pred(:); tru(:)]) + 4]);

if opt.Save
    f = fullfile(opt.FigDir, 'fig9_innovation.png');
    exportgraphics(fig, f, 'Resolution', 150);
    fprintf('\n图已保存：%s\n', f);
end
if strcmpi(opt.Visible, 'off')
    close(fig);
end

out = struct('Phase', T, 'Decision', D, 'Mutation', M);
end

% ======================= 局部函数 =======================
function X = local_sample()
here = fileparts(mfilename('fullpath'));
f = fullfile(here, 'samples', 'plus.mat');
if exist(f, 'file')
    M = load(f);
    if isfield(M, 'x')
        X = double(M.x);
        return;
    end
    fn = fieldnames(M);
    X = double(M.(fn{1}));
    return;
end
X = zeros(32);
X(6:25, 14:16) = 1;
X(14:16, 6:25) = 1;
end

function s = pick(c, a, b)
if c
    s = a;
else
    s = b;
end
end
