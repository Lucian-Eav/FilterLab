function g = sl_grpdelay(b, a, w)
%SL_GRPDELAY 群延迟 tau(w) = -d(angle H)/dw（单位：样本）
%
%   有 Signal Processing Toolbox 时调用 grpdelay；
%   否则用解析式直接求，避免数值求导在通带边缘产生的符号/噪声问题：
%
%       tau(w) = Re{ (sum_n n*b_n e^{-jwn}) / B(e^{-jw}) }
%              - Re{ (sum_n n*a_n e^{-jwn}) / A(e^{-jw}) }
%
%   线性相位滤波器的群延迟是常数，因此可直接用它判定「是否线性相位」。

    if exist('grpdelay', 'file') == 2
        g = grpdelay(b, a, w);
        return;
    end

    w = w(:).';
    b = b(:).';
    a = a(:).';
    z = exp(-1i * w);               % 注意：这里 z 已经含 e^{-jw}

    B = polyval(b, z);
    A = polyval(a, z);

    Sb = zeros(size(z));
    for k = 1:numel(b)-1
        Sb = Sb + k * b(k+1) .* z.^k;
    end
    Sa = zeros(size(z));
    for k = 1:numel(a)-1
        Sa = Sa + k * a(k+1) .* z.^k;
    end

    g = real(Sb ./ B) - real(Sa ./ A);
    g = g(:);
end
