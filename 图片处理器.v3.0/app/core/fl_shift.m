function [dr, dc, corrPeak] = fl_shift(Y, X)
%FL_SHIFT  用二维互相关估计 Y 相对 X 的整数平移量。
%
%   [DR,DC] = FL_SHIFT(Y,X) 返回整数平移量，使得
%       circshift(Y, -[DR DC]) 与 X 最接近。
%   也就是说：DR > 0 表示 Y 的内容相对 X 下移了 DR 个像素，即滤波引入的延迟；
%   要用它对齐，必须**反向**移回：circshift(Y, -[DR DC])。
%   （符号写反会让 PSNR 从 13 dB 塌到 5 dB，这是本项目踩过的坑。）
%
%   [DR,DC,PEAK] = FL_SHIFT(...) 额外返回归一化互相关峰值，可用于判断估计
%   是否可靠（峰值接近 1 说明两图高度相关，估计可信）。
%
%   实现说明：直接对全图做 FFT 互相关，比逐像素搜索快，且不受图像尺寸限制。
%   峰值位置按循环卷积解读，因此结果天然落在 [-floor(m/2), ceil(m/2)-1] 内，
%   正好是我们需要的"相对平移"，不会因为内容移到边界外而失效。
%
%   为什么这件事重要：因果滤波器的输出相对输入一定有延迟，线性相位 FIR 的
%   延迟恰好是 (N-1)/2 个样本。若不做配准就直接逐像素比较滤波前后的图像，
%   位移会把误差吃满，PSNR 会掉到 4 dB 量级，任何"去噪好还是不好"的结论都
%   失去意义。
%
%   见 also FL_FILTER2, FL_EVAL.

Y = double(Y);
X = double(X);
if ~isequal(size(X), size(Y))
    error('fl_shift:sizeMismatch', '两张图尺寸必须一致。');
end

Xc = X - mean(X(:));
Yc = Y - mean(Y(:));

FX = fft2(Xc);
FY = fft2(Yc);
R  = real(ifft2(FY .* conj(FX)));

[~, idx] = max(R(:));
[ri, ci] = ind2sub(size(R), idx);

[m, n] = size(R);
dr = ri - 1;
dc = ci - 1;
if dr > floor(m/2), dr = dr - m; end
if dc > floor(n/2), dc = dc - n; end

denom = sqrt(sum(Xc(:).^2) * sum(Yc(:).^2));
if denom <= 0
    corrPeak = NaN;
else
    corrPeak = R(ri, ci) / denom;
end
end
