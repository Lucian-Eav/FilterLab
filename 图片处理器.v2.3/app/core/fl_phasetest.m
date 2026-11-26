function T = fl_phasetest(S)
%FL_PHASETEST 相位隔离实验：幅频完全相同、只有相位不同的滤波器族
%
%   现有 b1/b2/b3 的幅频互不相同，所以"输出歪了"到底是幅频还是相位造成的，
%   从这三个滤波器上根本分不出来。本函数把这件事拆开。
%
%   取 b3（线性相位 FIR）的零点，把 r 换成 1/conj(r)。在单位圆上有
%       |e^{jw} - 1/conj(r)| = |e^{jw} - r| / |r|
%   幅频只被乘上一个与频率无关的常数，归一化之后整条幅频曲线在数值精度内
%   完全重合——幅频被钉死了，剩下的差别只可能来自相位。
%
%   两个实现要点：
%     · 实系数多项式里复零点成共轭对出现，必须整对反射，否则重建出来是
%       复系数，取实部就破坏了幅频（这个坑很容易踩）。
%     · |r| = 1 的零点反射后还是自己，是无效操作，单独标出来。
%
%   对每个成员给三个位移量：
%       Tau   一阶矩 sum(n.*h)/sum(h)（解析重心）
%       Cross 阶跃响应 50% 穿越位置（实测，线性插值）
%       Shift Cross + 0.5
%   对对称冲激响应可证 y[n] + y[2T-1-n] = 1，穿越点恰在 T-0.5，
%   所以 Shift 应当等于 Tau。对非对称成员这个等式不成立——这正是
%   "非线性相位下位移没有唯一值"的量化证据。
%
%   T = FL_PHASETEST(S) 返回结构体数组：
%       Name / B / Tau / Cross / Shift / DShift / MagMax / Sym / Overshoot
%
%   见 also FL_DESIGN, FL_FILTER2, FL_DECIDE.

if nargin < 1 || isempty(S)
    S = fl_spec();
end
F  = fl_design(S);
h0 = F(3).B(:).';
r0 = roots(h0);

[grp, outside] = zero_groups(r0);          % outside(k) = 第 k 组在单位圆外
onCircle = false(numel(grp), 1);
for k = 1:numel(grp)
    onCircle(k) = all(abs(abs(r0(grp{k})) - 1) < 1e-6);
end
mov = find(~onCircle);

names  = {};
coeffs = {};
names{end+1}  = '线性相位（基准）';  coeffs{end+1} = h0;
selMin = mov( outside(mov));
if ~isempty(selMin)
    names{end+1} = '最小相位';       coeffs{end+1} = rebuild(r0, grp, selMin);
end
selMax = mov(~outside(mov));
if ~isempty(selMax)
    names{end+1} = '最大相位';       coeffs{end+1} = rebuild(r0, grp, selMax);
end
if numel(selMin) >= 2
    names{end+1} = '混合相位';       coeffs{end+1} = rebuild(r0, grp, selMin(1:2:end));
end

w  = linspace(0, pi, 8192).';
H0 = abs(magresp(h0, w));

T = struct('Name', {}, 'B', {}, 'Tau', {}, 'Cross', {}, 'Shift', {}, ...
           'DShift', {}, 'MagMax', {}, 'Sym', {}, 'Overshoot', {});
for i = 1:numel(names)
    h    = coeffs{i};
    n    = (0:numel(h)-1).';
    tau  = sum(n .* h(:)) / sum(h);
    [crs, os] = stepdelay(h);
    T(i).Name      = names{i};
    T(i).B         = h;
    T(i).Tau       = tau;
    T(i).Cross     = crs;
    T(i).Shift     = crs + 0.5;
    T(i).DShift    = T(i).Shift - tau;
    T(i).MagMax    = max(abs(abs(magresp(h, w)) - H0));
    T(i).Sym       = max(abs(h(:) - flipud(h(:))));
    T(i).Overshoot = os;
end

tauV = [T.Tau];
dshV = [T.DShift];
magV = [T.MagMax];
symV = [T.Sym];
isLin = symV < 1e-12;

fprintf('\n========== 模块 A：相位隔离实验 ==========\n');
fprintf('基准 b3：%d 抽头、%d 个零点；其中 %d 组在单位圆上（反射后不变）、%d 组可移动\n', ...
    numel(h0), numel(r0), sum(onCircle), numel(mov));
fprintf('%-18s %-10s %-10s %-10s %-10s %-11s %-9s\n', ...
    '成员', '一阶矩τ', '阶跃穿越', '穿越+0.5', '与τ之差', '幅频偏差', '超调');
for i = 1:numel(T)
    fprintf('%-18s %-10.4f %-10.4f %-10.4f %-10.2e %-11.2e %-9.2f%%\n', ...
        T(i).Name, T(i).Tau, T(i).Cross, T(i).Shift, T(i).DShift, ...
        T(i).MagMax, 100 * T(i).Overshoot);
end

okMag = max(magV) < 1e-9;
okLin = all(abs(dshV(isLin)) < 1e-6);
fprintf('\n判据与结论：\n');
fprintf('  1) 全族幅频重合（偏差 < 1e-9）：%s（最大 %.2e）\n', ...
    pick(okMag, '通过', '未通过'), max(magV));
fprintf('  2) 对称成员上"穿越+0.5 = 一阶矩"成立：%s\n', pick(okLin, '通过', '未通过'));
if any(~isLin)
    okDif = all(abs(dshV(~isLin)) > 1e-2);
    fprintf('  3) 非对称成员上两者分裂（> 0.01 像素）：%s\n', pick(okDif, '通过', '未通过'));
    fprintf('     => 非线性相位下"位移"不是唯一值，任何单一位移指标都只是一种约定。\n');
end
fprintf('  参考：一阶矩 线性 %.2f / 最小 %.2f / 最大 %.2f\n', ...
    tauV(1), min(tauV), max(tauV));
end

% ======================= 局部函数 =======================
function [grp, outside] = zero_groups(r)
% 把根按共轭对分组（实根单独成组）；outside(k) 标记该组是否在单位圆外
r = r(:);
n = numel(r);
grp = {};
used = false(n, 1);
for i = 1:n
    if used(i)
        continue;
    end
    if abs(imag(r(i))) < 1e-9
        grp{end+1} = i;
        used(i) = true;
    else
        j = find(~used & abs(r - conj(r(i))) < 1e-6, 1);
        if isempty(j)
            grp{end+1} = i;
            used(i) = true;
        else
            grp{end+1} = [i; j];
            used(i)    = true;
            used(j)    = true;
        end
    end
end
outside = false(numel(grp), 1);
for k = 1:numel(grp)
    outside(k) = abs(r(grp{k}(1))) > 1;
end
end

function h = rebuild(r, grp, selGrp)
% 把 selGrp 指出的零点组整组反射到 1/conj(r)，重建实系数冲激响应
r = r(:);
for k = 1:numel(selGrp)
    idx = grp{selGrp(k)};
    if any(abs(r(idx)) < 1e-9)
        warning('fl_phasetest:zeroRoot', ...
            '零点恰好为 0，反射会得到 Inf，跳过该组。');
        continue;
    end
    r(idx) = 1 ./ conj(r(idx));
end
h = real(poly(r)).';
s = sum(h);
if abs(s) < 1e-12
    warning('fl_phasetest:zeroDC', '重建后直流增益为 0，无法归一化，返回未归一化系数。');
else
    h = h / s;
end
end

function H = magresp(h, w)
n = 0:numel(h)-1;
H = exp(-1i * w * n) * h(:);
end

function [cross, os] = stepdelay(h)
% 阶跃响应的 50% 穿越位置（相对阶跃起点，0 基，线性插值）+ 超调
n0 = 40;
s  = [zeros(1, n0) ones(1, 200)];
y  = filter(h(:).', 1, s);
seg = y(n0+1:end);
k   = find(seg >= 0.5, 1);
if isempty(k) || k < 2
    cross = NaN;
else
    a0   = seg(k-1);
    a1   = seg(k);
    frac = (0.5 - a0) / (a1 - a0);
    cross = (k - 2) + frac;      % seg(k) 对应 n = k-1
end
os = max(y) - 1;
end

function s = pick(c, a, b)
if c
    s = a;
else
    s = b;
end
end
