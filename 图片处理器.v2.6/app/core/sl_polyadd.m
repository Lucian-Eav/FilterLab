function q = sl_polyadd(p1, p2)
%SL_POLYADD 多项式相加，自动对齐到相同长度
    p1 = p1(:).';  p2 = p2(:).';
    n = max(numel(p1), numel(p2));
    q = [zeros(1, n - numel(p1)), p1] + [zeros(1, n - numel(p2)), p2];
end
