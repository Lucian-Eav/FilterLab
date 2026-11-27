function q = sl_polypow(p, k)
%SL_POLYPOW 多项式幂次：q = p^k
%   用于双线性变换中把 (2-2z^-1)^(n-j)、(1+z^-1)^j 之类的因子展开成系数向量。
    if k < 0 || fix(k) ~= k
        error('sl_polypow:幂次必须是非负整数');
    end
    q = 1;
    for ii = 1:k
        q = conv(q, p);
    end
end
