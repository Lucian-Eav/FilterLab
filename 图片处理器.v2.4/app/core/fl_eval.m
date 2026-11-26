function R = fl_eval(X, Y, S)
%FL_EVAL  对一次二维滤波结果做多判据质量评估。
%
%   R = FL_EVAL(X, Y, S) 以原图 X、输出 Y 和规格 S 计算一组互不替代的判据。
%   这些判据刻意分成"降噪"和"模糊"两类，因为任何单一指标都会掩盖取舍。
%
%   返回 R 的字段：
%       Shift      [dr dc] Y 相对 X 的平移量；用 circshift(Y,-Shift) 对齐
%       Corr       归一化互相关峰值，接近 1 表示估计可靠
%       PSNRraw    未配准的 PSNR（dB），用来说明"为什么必须先配准"
%       PSNR       配准后、去掉边界 Crop 像素的 PSNR（dB）
%       FlatMask   平坦区逻辑掩膜（窗口内原图恒定）
%       FlatRMS    平坦区残余噪声 RMS，衡量降噪效果
%       EdgeMAE    边缘/过渡区平均绝对误差，衡量细结构被抹掉的程度
%       OutEnergy  越界能量 mean(([y-1]+)^2 + ([-y]+)^2)，衡量过冲与下冲
%       ZeroCross  每行扫描线平均过零次数，衡量振荡的密度
%       DynRange   [min max] 输出动态范围
%       SymT       与自身转置的最大绝对差，检验主对角对称性
%       SymLR      与左右镜像的最大绝对差
%       SymUD      与上下镜像的最大绝对差
%
%   关于"必须先配准"：因果滤波器的输出相对输入必然有延迟。若直接逐像素比
%   较，位移会把误差吃满，PSNR 会掉到 4 dB 量级，此时任何结论都不成立。
%
%   见 also FL_FILTER2, FL_SHIFT, FL_REPORT.

X = double(X);
Y = double(Y);
if ~isequal(size(X), size(Y))
    error('fl_eval:sizeMismatch', '原图与输出尺寸必须一致。');
end
[m, n] = size(X);

R = struct();
[dr, dc, cp] = fl_shift(Y, X);
R.Shift = [dr, dc];
R.Corr  = cp;
% fl_shift 返回的是"Y 相对 X 被平移了多少"；要还原就得反向移回来。
Yal = circshift(Y, -R.Shift);

if isfield(S, 'CropOrder')
    amax = S.CropOrder;
else
    amax = 12;
end
crop = fl_crop(S, [m n], amax);
rows = (crop+1):(m-crop);
cols = (crop+1):(n-crop);

R.PSNRraw = local_psnr(X(rows,cols), Y(rows,cols));
R.PSNR    = local_psnr(X(rows,cols), Yal(rows,cols));
R.Crop    = crop;

% ---- 平坦区与边缘区划分：局部标准差小到可忽略即为平坦 ----
% 老写法判的是 "窗口均值 ≈ 0 或 ≈ 1"，那只对 0/1 二值测试图成立；
% 换成真实照片（灰度连续）时几乎没有像素满足，平坦区会变成空集，
% FlatRMS 直接 NaN。改成看局部方差，与图像内容、尺寸都无关。
p  = (S.FlatWin - 1) / 2;
Xp = [repmat(X(1,:), p, 1); X; repmat(X(end,:), p, 1)];
Xp = [repmat(Xp(:,1), 1, p), Xp, repmat(Xp(:,end), 1, p)];
w  = ones(S.FlatWin) / S.FlatWin^2;
mu = conv2(Xp, w, 'valid');
sq = conv2(Xp.^2, w, 'valid');
vs = max(sq - mu.^2, 0);                 % 局部方差
rg = max(X(:)) - min(X(:));
tau = max(1e-12, 0.02 * max(rg, eps));   % 取动态范围的 2% 作门限
R.FlatMask = sqrt(vs) < tau;
edgeMask   = ~R.FlatMask;
R.FlatTau  = tau;

E = Yal - X;
if any(R.FlatMask(:))
    R.FlatRMS = sqrt(mean(E(R.FlatMask).^2));
else
    R.FlatRMS = NaN;                     % 整幅图都在变化，没有平坦区
end
if any(edgeMask(:))
    R.EdgeMAE = mean(abs(E(edgeMask)));
else
    R.EdgeMAE = NaN;
end

R.OutEnergy = mean( max(Y(:)-1,0).^2 + max(-Y(:),0).^2 );

% 振荡密度：沿行统计"输出与原图之差"的符号变化次数。
% 用固定阈值去数输出的过零是不行的——那会把边缘位置和整体亮度差也算进去；
% 残差的符号变化才真正对应振铃的疏密。
zc = 0;
for i = rows
    d = Y(i,:) - X(i,:);
    d(abs(d) < 1e-9) = 0;
    zc = zc + sum(sign(d(1:end-1)) .* sign(d(2:end)) < 0);
end
R.ZeroCross = zc / (numel(rows) * numel(cols));

R.DynRange = [min(Y(:)), max(Y(:))];

R.SymT  = max(abs(Y(:) - reshape(Y.', [], 1)));
R.SymLR = max(max(abs(Y - fliplr(Y))));
R.SymUD = max(max(abs(Y - flipud(Y))));
end

% ------------------------------------------------------------------------
function v = local_psnr(A, B)
% 假定数据范围 [0,1]，峰值取 1。
mse = mean((A(:) - B(:)).^2);
if mse <= 0
    v = Inf;
else
    v = 10 * log10(1 / mse);
end
end
