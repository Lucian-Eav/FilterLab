function M = fl_mutate(X, S)
%FL_MUTATE 故障注入自检（变异测试）
%
%   一组"全部通过"的自检并不能证明自检有效——它也可能什么都抓不住。
%   本函数对滤波内核故意注入已知故障，再跑同一套自检，看它能不能抓到。
%
%   同时区分两类变异：
%     · 有效变异：改变了行为，自检应当报错
%     · 等价变异：改了代码但行为不变（对称 FIR 的系数倒序、行列顺序交换），
%                 自检不报错是正确行为，不能算漏检 —— 这类不计入分母
%   否则"检出力 = 检出数 / 全部变异"会被等价变异稀释，数字永远好看。
%
%   四项自检（对正确的内核必须全过）：
%     T1 常数图内部保持 1（抓漏归一化、反馈系数错）
%     T2 阶跃稳态回到 1（抓直流增益错）
%     T3 实测整体平移 = 一阶矩预测（仅对对称 FIR 有意义）
%     T4 与 Toeplitz 矩阵乘一致（抓次序、边界、量化、平移）
%
%   M = FL_MUTATE(X) 或 FL_MUTATE(X, S)
%   返回结构体数组：Name / Expected / Detected / Tests / OK / Err
%
%   见 also FL_SELFTEST, FL_FILTER2.

if nargin < 1 || isempty(X)
    X = load_sample();
end
if nargin < 2 || isempty(S)
    S = fl_spec();
end
F  = fl_design(S);
b3 = F(3).B(:).';   a3 = F(3).A;
b1 = F(1).B(:).';   a1 = F(1).A;

ref3 = @(Z) fl_filter2(Z, b3, a3, 'Orient', 'rc', 'Edge', 'zero');
ref1 = @(Z) fl_filter2(Z, b1, a1, 'Orient', 'rc', 'Edge', 'zero');

mut = {};
mut{end+1} = mk('（对称 FIR）系数倒序', 'equivalent', b3, a3, ...
    @(Z) fl_filter2(Z, fliplr(b3), a3, 'Orient', 'rc', 'Edge', 'zero'));
hA = [1 3 5 3 2] / 14;      % 非对称 FIR，倒序会真的改变行为
mut{end+1} = mk('（非对称 FIR）系数倒序', 'detect', hA, 1, ...
    @(Z) fl_filter2(Z, fliplr(hA), 1, 'Orient', 'rc', 'Edge', 'zero'));
mut{end+1} = mk('IIR 反馈系数符号取反', 'detect', b1, a1, ...
    @(Z) fl_filter2(Z, b1, [a1(1), -a1(2:end)], 'Orient', 'rc', 'Edge', 'zero'));
mut{end+1} = mk('漏掉归一化（用未归一化系数）', 'detect', b3, a3, ...
    @(Z) fl_filter2(Z, F(3).Braw, a3, 'Orient', 'rc', 'Edge', 'zero'));
mut{end+1} = mk('输出量化到 0.01', 'detect', b3, a3, ...
    @(Z) round(ref3(Z) * 100) / 100);
mut{end+1} = mk('边界 zero 改成 replicate', 'detect', b3, a3, ...
    @(Z) fl_filter2(Z, b3, a3, 'Orient', 'rc', 'Edge', 'replicate'));
mut{end+1} = mk('整体平移 1 像素', 'detect', b3, a3, ...
    @(Z) circshift(ref3(Z), 1, 1));
mut{end+1} = mk('行列顺序交换（等价）', 'equivalent', b3, a3, ...
    @(Z) fl_filter2(Z, b3, a3, 'Orient', 'cr', 'Edge', 'zero'));
mut{end+1} = mk('先转置再滤再转回（等价）', 'equivalent', b3, a3, ...
    @(Z) fl_filter2(Z.', b3, a3, 'Orient', 'rc', 'Edge', 'zero').');

% 基线校验：未变异的实现必须先通过全部检测器。
% 否则"变异被测出"可能只是检测器本身有毛病，而不是变异起作用了。
tb = run_tests(ref3, X, b3, a3);
if ~all(tb)
    error('fl_mutate:baseline', ...
        '基线（未变异）实现未通过自检 T%s，先修基线再谈变异检测。', ...
        mat2str(find(~tb)));
end

M = struct('Name', {}, 'Expected', {}, 'Detected', {}, 'Tests', {}, ...
           'OK', {}, 'Err', {});
for i = 1:numel(mut)
    err = '';
    try
        t   = run_tests(mut{i}.Apply, X, mut{i}.B, mut{i}.A);
        det = ~all(t);
    catch errObj
        % 异常不等于"检出"：实现崩了说明框架本身有问题，单列出来，
        % 不能算进检出力，否则指标会被自己的 bug 喂高。
        t   = false(1, 5);
        det = NaN;
        err = errObj.message;
    end
    M(i).Name     = mut{i}.Name;
    M(i).Expected = mut{i}.Expected;
    M(i).Detected = det;
    M(i).Tests    = t;
    M(i).Err      = err;
    if isnan(det)
        M(i).OK = false;
    elseif strcmp(mut{i}.Expected, 'detect')
        M(i).OK = det;
    else
        M(i).OK = ~det;
    end
end

nDet = sum(strcmp({M.Expected}, 'detect') & ~isnan([M.Detected]));
nCaught = sum(strcmp({M.Expected}, 'detect') & [M.Detected] == 1);
nErr = sum(isnan([M.Detected]));
fprintf('\n========== 模块 C：故障注入自检 ==========\n');
fprintf('基线（未变异）先过全部检测器：通过\n');
fprintf('%-30s %-11s %-7s %-18s %-6s\n', '注入的故障', '预期', '被抓到', 'T1T2T3T4T5', '判定');
for i = 1:numel(M)
    if isnan(M(i).Detected)
        tag = '异常';
    else
        tag = pick(M(i).Detected, '是', '否');
    end
    fprintf('%-30s %-11s %-7s %-18s %-6s\n', M(i).Name, M(i).Expected, ...
        tag, mat2str(double(M(i).Tests)), ...
        pick(M(i).OK, 'OK', '失守'));
end
fprintf('检出力 = %d/%d（只统计有效变异；等价变异 %d 个不计入分母）\n', ...
    nCaught, nDet, numel(M) - nDet);
if nCaught == nDet
    fprintf('结论：全部有效变异被检出，自检不是装饰性的。\n');
else
    fprintf('结论：有 %d 个有效变异漏检，自检需要补强。\n', nDet - nCaught);
end
bad = find(~cellfun(@isempty, {M.Err}));
for k = bad
    fprintf('  [异常] %s -> %s\n', M(k).Name, M(k).Err);
end
end

% ======================= 局部函数 =======================
function t = run_tests(f, X, Bk, Ak)
% 五项自检
t = false(1, 5);
L = max(numel(Bk), numel(Ak));
pad = 15;

% T1 常数图内部保持 1
Xc = ones(64, 64);
Yc = f(Xc);
t(1) = abs(mean(Yc(pad+1:end-pad, pad+1:end-pad), 'all') - 1) < 1e-9;

% T2 阶跃稳态回到 1
Xs = ones(64, 64);
Xs(:, 1:32) = 0;
Ys = f(Xs);
t(2) = abs(mean(Ys(45:55, 52:58), 'all') - 1) < 5e-3;

% T5 阶跃的动态行为（过冲在合理区间）。
% T1/T2 查的都是直流：常数图稳态、阶跃稳态，两个判据高度重叠。
% T5 换成看过冲，才能抓住"直流对但动态已经坏了"这类变异。
prof = mean(Ys(:, 40:60), 2);
osv  = max(prof) - 1;
t(5) = (osv > -0.05) && (osv < 0.80);

% T3 实测整体平移 = 一阶矩预测（只对对称 FIR 有意义）
symOk = isscalar(Ak) && Ak == 1 && ...
        max(abs(Bk(:) - flipud(Bk(:)))) < 1e-12 && numel(Bk) >= 3;
if symOk
    tau = sum((0:numel(Bk)-1).' .* Bk(:)) / sum(Bk);
    [dr, dc] = fl_shift(f(X), X);
    t(3) = abs(dr - tau) <= 0.5 && abs(dc - tau) <= 0.5;
else
    t(3) = true;      % 非对称/IIR：单一位移指标没有意义，跳过
end

% T4 与 Toeplitz 矩阵乘（独立实现）一致。故意把图整体抬高 0.5，
% 让边界不再是零——否则"复制边界"和"零延拓"在这种四周留白的图上
% 完全等价，边界错误就永远抓不到。
%
% 注意：矩阵是**由系数直接拼出来的**（Tb/Ta 两个下三角 Toeplitz，
% 再解 Ta*A = Tb），不是拿 filter 打单位基向量凑的。后者看着像独立
% 实现，其实调的是同一个 filter，filter 本身的错（延迟约定、系数
% 顺序）永远抓不到。
Xb  = X + 0.5;
Ar  = op_matrix(Bk, Ak, size(Xb, 1));
Ac  = op_matrix(Bk, Ak, size(Xb, 2));
t(4) = max(max(abs(f(Xb) - Ar * Xb * Ac.'))) < 1e-9;
end

function A = op_matrix(Bk, Ak, n)
% 由系数直接构造 n×n 因果线性算子，零初值；不调用 filter
Bk = Bk(:).';
Ak = Ak(:).';
Tb = zeros(n);
Ta = zeros(n);
for k = 1:numel(Bk)
    Tb = Tb + Bk(k) * shift_diag(n, k - 1);
end
for k = 1:numel(Ak)
    Ta = Ta + Ak(k) * shift_diag(n, k - 1);
end
A = Ta \ Tb;
end

function S = shift_diag(n, d)
% 第 d 条次对角线上的单位阵：(i, i-d) = 1，即延迟 d 个样本
S = zeros(n);
if d < 0 || d >= n
    return;
end
for i = d+1:n
    S(i, i - d) = 1;
end
end

function s = mk(name, expd, Bk, Ak, fn)
s = struct('Name', name, 'Expected', expd, 'B', Bk, 'A', Ak, 'Apply', fn);
end

function X = load_sample()
here = fileparts(mfilename('fullpath'));
f = fullfile(here, '..', 'samples', 'plus.mat');
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
