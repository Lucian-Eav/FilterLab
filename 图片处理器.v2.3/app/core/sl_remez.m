function b = sl_remez(n, f, a, w)
%SL_REMEZ 等纹波（最小最大）FIR 低通/多带滤波器设计
%
%   b = sl_remez(n, f, a)     与 MATLAB 的 remez(n,f,a) 等价
%   b = sl_remez(n, f, a, w)  指定各频带权重
%
%   有 Signal Processing Toolbox 时直接调用 remez；
%   没有时用 **Lawson 迭代加权最小二乘**逼近最小最大解。
%
%   为什么不用手写交换算法：交换算法对上位极值点的选择极其敏感，
%   实现稍有偏差就会收敛到"看起来像"但不是等纹波的解，而且很难自证。
%   Lawson 算法（1970s）是求解 Chebyshev 逼近的经典方法，单调收敛、
%   代码短、且可以直接用「通带纹波 == 阻带峰值」自检。
%
%   原理：
%     1) 在通带/阻带上布稠密网格
%     2) 反复求解加权最小二乘  min Σ u_i (P(w_i) - D_i)^2 ，P 为 cos 多项式
%     3) 按 u_i <- u_i * |E_i| 更新权重（E 为加权误差），再归一化
%     4) 收敛后 u 的分布把误差"摊平"，极限即最小最大解
%
%   自检：权重全为 1 时，通带内 max|1-|H|| 与阻带内 max|H| 必然相等。

    if exist('remez', 'file') == 2
        if nargin < 4 || isempty(w)
            b = remez(n, f, a);
        else
            b = remez(n, f, a, w);
        end
        return;
    end

    if mod(n, 2) ~= 0
        error('sl_remez:自实现版本仅支持偶数阶（第一类线性相位）');
    end

    f = f(:).';  a = a(:).';
    if mod(numel(f), 2) ~= 0
        error('sl_remez:频带边界 f 的个数必须为偶数');
    end
    nb = numel(f) / 2;
    if nargin < 4 || isempty(w)
        w = ones(1, nb);
    end
    w = w(:).';
    if numel(w) ~= nb
        error('sl_remez:权重个数应与频带数一致');
    end

    M = n / 2;                 % cos 多项式次数

    % ---------- 1) 频带网格 ----------
    NG = 1024;
    wg = [];  Dg = [];  Wg = [];
    for kb = 1:nb
        lo = f(2*kb-1);  hi = f(2*kb);
        if hi <= lo
            continue;
        end
        a1 = a(2*kb-1);  a2 = a(2*kb);
        if abs(a1 - a2) > 1e-12
            error('sl_remez:自实现版本要求同一频带内期望幅度恒定');
        end
        x  = linspace(lo, hi, NG).';
        wg = [wg; x];
        Dg = [Dg; repmat(a1, NG, 1)];
        Wg = [Wg; repmat(w(kb), NG, 1)];
    end
    wg = pi * wg;
    Dg = Dg(:);  Wg = Wg(:);
    ng = numel(wg);
    if ng < 3
        error('sl_remez:有效频带太少，无法设计');
    end

    % ---------- 2) cos 基矩阵 ----------
    A = ones(ng, M + 1);
    for kk = 1:M
        A(:, kk+1) = cos(kk * wg);
    end

    % ---------- 3) Lawson 迭代 ----------
    u = ones(ng, 1);                    % 最小二乘权重
    for it = 1:80
        c = (A.' * (u .* A)) \ (A.' * (u .* Dg));
        E = Wg .* (A * c - Dg);
        u = u .* (abs(E) + 1e-10);
        u = u / sum(u) * ng;            % 归一化，防止尺度漂移
    end

    % ---------- 4) 由 cos 系数还原偶对称冲激响应 ----------
    h = zeros(1, n + 1);
    h(M+1) = c(1);
    for kk = 1:M
        h(M+1-kk) = c(kk+1) / 2;
        h(M+1+kk) = c(kk+1) / 2;
    end
    b = h;
end
