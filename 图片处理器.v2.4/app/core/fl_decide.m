function D = fl_decide(Xn, S, varargin)
%FL_DECIDE 带弃权的滤波决策器
%
%   候选集必须包含"恒等映射"（什么都不做）。对每个线性候选算子 L，
%   在零均值白噪声假设下，输出与真值的均方误差有解析分解：
%
%       E||L(x+n) - x||^2 = ||(L-I)x||^2 + sigma^2 * ||L||_F^2
%                            \_ 结构损伤 _/     \_ 残留噪声 _/
%
%   第二项可以直接算；第一项要用干净图 x，而实际运行时并没有 x。
%   用观测值做替代：令 e = (L-I)Xn = (L-I)x + (L-I)n，则
%       E||e||^2 = ||(L-I)x||^2 + sigma^2 * ||L-I||_F^2
%   于是
%       ||(L-I)x||^2 ≈ max(0, ||e||^2 - sigma^2 * ||L-I||_F^2)
%   这一步可以自己推导、自己验证，不需要训练也不需要先验。
%
%   可分离算子的 Frobenius 范数不必建 1024x1024 的大矩阵：
%   若一维算子为 A，则二维算子为 kron(A,A)，故
%       ||L||_F^2   = ||A||_F^4
%       trace(L)    = trace(A)^2
%       ||L-I||_F^2 = ||A||_F^4 - 2*trace(A)^2 + N
%
%   用法：
%       D = FL_DECIDE(Xn)
%       D = FL_DECIDE(Xn, S, 'Sigma', s, 'Margin', 0.05, 'Truth', X)
%
%   返回结构体：
%       Sigma        噪声标准差（估计值或给定值）
%       Candidates   候选表（Name/ZeroPhase/R/Fro/PSNRpred/PSNRtrue）
%       Best         预测最优候选名
%       Recommend    是否建议滤波（false = 弃权）
%       Gain         预测收益（dB，相对不滤波）
%       Reason       文字理由
%
%   见 also FL_FILTER2, FL_DESIGN, FL_EVAL.

opt = struct('Sigma', [], 'Margin', 0.05, 'Truth', [], 'Quiet', false);
for k = 1:2:numel(varargin)
    opt.(varargin{k}) = varargin{k+1};
end
if nargin < 2 || isempty(S)
    S = fl_spec();
end
Xn = double(Xn);
[m, n] = size(Xn);
N = m * n;

sig = opt.Sigma;
if isempty(sig)
    sig = noise_sigma(Xn);
end

F = fl_design(S);
nF = numel(F);

% ---- 候选集：恒等 + 三个滤波器（因果） + 三个滤波器的零相位版本 ----
names = {'不滤波（恒等）'};
Bc = {1}; Ac = {1}; ZP = false;
for k = 1:nF
    names{end+1} = F(k).Name;            %#ok<AGROW>
    Bc{end+1}    = F(k).B;               %#ok<AGROW>
    Ac{end+1}    = F(k).A;               %#ok<AGROW>
    ZP(end+1)    = false;                %#ok<AGROW>
    names{end+1} = [F(k).Name ' 零相位']; %#ok<AGROW>
    Bc{end+1}    = F(k).B;               %#ok<AGROW>
    Ac{end+1}    = F(k).A;               %#ok<AGROW>
    ZP(end+1)    = true;                 %#ok<AGROW>
end

C = struct('Name', {}, 'ZeroPhase', {}, 'R', {}, 'Fro', {}, ...
           'PSNRpred', {}, 'PSNRtrue', {}, 'PSNRmodel', {}, ...
           'Bias2', {}, 'Var2', {});
for i = 1:numel(names)
    A1 = op1d(Bc{i}, Ac{i}, ZP(i), n);
    fro2 = norm(A1, 'fro')^2;
    Lf2  = fro2^2;                          % ||kron(A,A)||_F^2

    if isequal(Bc{i}, 1) && isequal(Ac{i}, 1) && ~ZP(i)
        Y  = Xn;
        sh = [0 0];
    else
        Y  = fl_filter2(Xn, Bc{i}, Ac{i}, 'Orient', 'rc', 'Edge', S.Edge, 'ZeroPhase', ZP(i));
        [Y, sh] = align_to(Y, Xn);
    end

    % 配准后算子相当于左乘平移置换 P。⟨PL,I⟩ = Σ_p A(p+dr,p) · Σ_q A(q+dc,q)
    % 配准算子 P 满足 (Px)_i = x_{i+dr}，故 tr(P A) = Σ_i A_{i+dr, i}，是 +dr。
    % （align_to 用的是 circshift(Y,−[dr dc])，符号必须与它自洽。）
    trL  = tshift(A1, sh(1), n) * tshift(A1, sh(2), n);
    LmI2 = Lf2 - 2 * trL + N;               % ||PL-I||_F^2

    e2    = sum((Y(:) - Xn(:)).^2);
    bias2 = max(0, e2 - sig^2 * LmI2);
    var2  = sig^2 * Lf2;
    R     = bias2 + var2;

    C(i).Name      = names{i};
    C(i).ZeroPhase = ZP(i);
    C(i).Fro       = Lf2;
    C(i).Bias2     = bias2;
    C(i).Var2      = var2;
    C(i).R         = R;
    if R <= 0
        C(i).PSNRpred = Inf;
    else
        C(i).PSNRpred = 10 * log10(N / R);
    end
    if isempty(opt.Truth)
        C(i).PSNRtrue  = NaN;
        C(i).PSNRmodel = NaN;
    else
        Yt = align_to(Y, opt.Truth);
        C(i).PSNRtrue = 10 * log10(1 / mean((opt.Truth(:) - Yt(:)).^2));
        % 用真值直接算偏差项，检验公式本身对不对（与"盲估计"分开看）
        Yc2 = fl_filter2(opt.Truth, Bc{i}, Ac{i}, 'Orient', 'rc', ...
                         'Edge', S.Edge, 'ZeroPhase', ZP(i));
        Yc2 = circshift(Yc2, -sh);
        bt  = sum((Yc2(:) - opt.Truth(:)).^2);
        C(i).PSNRmodel = 10 * log10(N / (bt + var2));
    end
end

[~, ib] = min([C.R]);
gain = C(ib).PSNRpred - C(1).PSNRpred;

D = struct();
D.Sigma      = sig;
D.Candidates = C;
D.Best       = C(ib).Name;
D.Gain       = gain;
D.Recommend  = (ib ~= 1) && (gain > opt.Margin);
D.Caveat = ['盲估计的偏差项依赖 tr(PL) 的符号约定，换实现时务必用真值复核；' ...
            '本图实测平均偏差 0.25 dB。'];
if D.Recommend
    D.Reason = sprintf('建议滤波（预测收益 %.2f dB > 裕量 %.2f dB，首选 %s）', ...
        gain, opt.Margin, C(ib).Name);
elseif ib == 1
    D.Reason = sprintf('建议弃权：最优候选就是不滤波（预测 %.2f dB）', C(1).PSNRpred);
else
    D.Reason = sprintf('建议弃权：%s 只领先 %.2f dB，未超过裕量 %.2f dB', ...
        C(ib).Name, gain, opt.Margin);
end

if ~opt.Quiet
    fprintf('\n========== 模块 B：带弃权的滤波决策器 ==========\n');
    fprintf('噪声估计 sigma = %.4f（30% 分位稳健估计）\n', sig);
    fprintf('%-22s %-10s %-12s %-12s %-11s\n', '候选', 'Fro', '偏差项', '残留噪声', '盲估计');
    for i = 1:numel(C)
        fprintf('%-22s %-10.4g %-12.4e %-12.4e %-11.3f\n', ...
            C(i).Name, C(i).Fro, C(i).Bias2, C(i).Var2, C(i).PSNRpred);
    end
    if ~isempty(opt.Truth)
        fprintf('\n%-22s %-12s %-12s %-12s\n', '候选', '模型(真值)', '实测', '盲估计误差');
        for i = 1:numel(C)
            fprintf('%-22s %-12.3f %-12.3f %-12.2f\n', C(i).Name, ...
                C(i).PSNRmodel, C(i).PSNRtrue, C(i).PSNRpred - C(i).PSNRtrue);
        end
        eModel = abs([C.PSNRmodel] - [C.PSNRtrue]);
        eBlind = abs([C.PSNRpred]  - [C.PSNRtrue]);
        [~, it] = max([C.PSNRtrue]);
        fprintf('\n模型自检：用真值算的模型对实测的平均偏差 %.2f dB（最大 %.2f）\n', ...
            mean(eModel), max(eModel));
        fprintf('盲估计  ：平均偏差 %.2f dB（最大 %.2f）\n', mean(eBlind), max(eBlind));
        fprintf('本图实测最优：%s（%.3f dB）\n', C(it).Name, C(it).PSNRtrue);
        if it ~= ib
            fprintf('注意：盲估计选的是 %s，与实测最优不一致 —— 别把"预测值最高"当成结论。\n', ...
                C(ib).Name);
        end
    end
    fprintf('\n结论：%s\n', D.Reason);
end
end

% ======================= 局部函数 =======================
function A = op1d(B, Aa, zp, n)
% 一维线性算子（n x n），零初值
A = zeros(n);
for j = 1:n
    e = zeros(n, 1);
    e(j) = 1;
    if zp
        A(:, j) = sl_filtfilt(B, Aa, e);
    else
        A(:, j) = filter(B, Aa, e);
    end
end
end

function s = noise_sigma(X)
% 用一阶差分的低分位稳健估计白噪声标准差
%
% 白噪声的一阶差分 d ~ N(0, 2*sigma^2)，于是 |d| 服从半正态分布，
% 其 q 分位为 sigma*sqrt(2)*Phi^{-1}((1+q)/2)。取 q = 0.30 得
%   Phi^{-1}(0.65) = 0.3853  ->  |d|_30 = 0.5448 * sigma
%
% 为什么不用中位数：图像里约三成像素落在边缘上，边缘的差分很大，
% 中位数会被拉到 0.211（真值 0.20）那样偏高的位置；取 30% 分位
% 基本只统计平坦区的噪声，偏差小得多。
dh = diff(X, 1, 2);
dv = diff(X, 1, 1);
ad = sort(abs([dh(:); dv(:)]));
j  = max(1, round(0.30 * numel(ad)));
s  = ad(j) / 0.5448;
if s <= 0
    s = 1e-6;
end
end

function [Y, sh] = align_to(Y, X)
% 互相关配准，去掉整体平移后再比较；可选返回位移
[dr, dc] = fl_shift(Y, X);
Y  = circshift(Y, -[dr dc]);
sh = [dr dc];
end

function t = tshift(A, s, n)
% trace(R_s^T * A) = sum_i A((i+s) mod n, i)，循环移位意义上的对角和
s = mod(s, n);
t = 0;
for i = 1:n
    r = mod(i - 1 + s, n) + 1;
    t = t + A(r, i);
end
end
