function H = sl_freqz(b, a, w)
%SL_FREQZ 数字滤波器的频率响应 H(e^{jw})
%   有 Signal Processing Toolbox 时调用 freqz，否则直接按定义计算：
%   H(e^{jw}) = B(e^{-jw}) / A(e^{-jw})

    if exist('freqz', 'file') == 2 && numel(w) > 1
        H = freqz(b, a, w);
        return;
    end
    w = w(:);
    z = exp(-1i * w);
    H = polyval(b, z) ./ polyval(a, z);
end
