function [b, a] = sl_butter(n, Wn)
%SL_BUTTER 低通 Butterworth 数字滤波器系数（与 MATLAB butter(n,Wn) 数值一致）
%
%   有 Signal Processing Toolbox 时直接调用 butter；
%   没有时用解析法自行设计：
%     1) 由数字截止频率反推模拟截止频率（双线性变换预畸变）
%     2) 用 Butterworth 极点公式构造模拟原型分母多项式
%     3) 双线性变换 s = 2(1-z^-1)/(1+z^-1) 代入，得到数字域系数
%     4) 归一化到直流增益 1
%
%   输入：n 阶数；Wn 归一化截止频率（1 对应 Nyquist）
%   输出：b 分子系数、a 分母系数（行向量，a(1)=1）

    if exist('butter', 'file') == 2
        [b, a] = butter(n, Wn);
        return;
    end

    if nargin < 2
        error('sl_butter:需要阶数 n 与归一化截止频率 Wn');
    end
    if numel(Wn) ~= 1
        error('sl_butter:自实现版本仅支持单个截止频率');
    end
    if Wn <= 0 || Wn >= 1
        error('sl_butter:Wn 应严格位于 (0,1) 之间');
    end
    if n < 1 || fix(n) ~= n
        error('sl_butter:阶数 n 必须是正整数');
    end

    wc = pi * Wn;                       % 数字截止角频率
    Wc = 2 * tan(wc / 2);               % 预畸变后的模拟截止频率（双线性变换 T=2）

    kk = (0:n-1).';
    p  = Wc * exp(1i * pi * (2*kk + 1 + n) / (2*n));   % 左半平面共轭极点对

    Ka = Wc^n;                          % 模拟增益，保证 |H_a(0)| = 1
    d  = real(poly(p));                 % s 的降幂系数，d(1) = 1（共轭极点对，虚部应为 0）

    % 双线性变换代入
    snum = [2, -2];                     % 2 - 2 z^-1
    sden = [1,  1];                     % 1 +   z^-1
    num = Ka * sl_polypow(sden, n);     % 分子：(1+z^-1)^n 乘以模拟增益
    den = zeros(1, n + 1);
    for j = 0:n
        term = conv(sl_polypow(snum, n - j), sl_polypow(sden, j));
        den  = sl_polyadd(den, d(j+1) * term);
    end

    % 按分母首项（= D(2) = prod(2-p_k)）归一化，使 a(1)=1 且直流增益为 1
    sc = real(den(1));
    b  = real(num) / sc;
    a  = real(den) / sc;
end
