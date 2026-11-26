function c = fl_crop(S, sz, Amax)
%FL_CROP  本次评估实际要裁掉的边界像素数。
%
%   C = FL_CROP(S, SZ, AMAX)
%
%   SZ   图像尺寸 [m n]
%   AMAX 本次参与比较的滤波器中最大的阶数（零初值瞬态的长度量级）
%
%   为什么不能写死一个常数：
%
%     裁边太小的后果是"零初值瞬态"混进误差——一条 12 阶 FIR 的响应
%     还没进入稳态的前 12 个样本会被当成巨大误差，PSNR 直接失真。
%     裁得太大的后果是图像本来就小，一裁就没了。
%
%   所以规则是"两头取小"：
%
%       c = min( AMAX, floor(min(m,n)/8) )
%
%     32×32 的小图 → min(12, 4)  = 4    （与历史结果一致）
%     64×64        → min(12, 8)  = 8
%     256×256 以上 → min(12, 32) = 12   （刚好覆盖最长滤波器的瞬态）
%
%   这样小图不会被裁空，大图也不会把瞬态留在里面。
%
%   如果 S.Crop 给了非 NaN 的具体值，就按用户的来，不再自动推算。
%
%   见 also FL_EVAL, FL_SPEC.

if nargin < 3 || isempty(Amax) || ~isfinite(Amax)
    Amax = 12;
end
sz = double(sz(:).');
m = sz(1); n = sz(end);
short = min(m, n);

if isfield(S, 'Crop') && ~isempty(S.Crop) && ~isnan(S.Crop)
    c = double(S.Crop);
else
    c = min(double(Amax), floor(short / 8));
end

% 兜底：无论怎么算，都必须给内部区域留下至少 2 个像素
c = max(0, min(c, floor((short - 2) / 2)));
end
