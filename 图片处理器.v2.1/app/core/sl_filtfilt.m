function y = sl_filtfilt(b, a, x)
%SL_FILTFILT 零相位（前后向）滤波
%   正向滤一遍再反向滤一遍，相位相互抵消，等效幅频为 |H|^2。
%   注意：这不是「纯去相位」——幅频被平方，通带会变窄。做对照实验时必须说明这一点。
%   为减弱端部瞬态，序列两端做镜像延拓后再滤，最后裁掉延拓部分。
%
%   行向量、列向量、矩阵（沿第一维逐列）都支持。v1.1 修正：原实现用
%   size(x,1) 取序列长度，行向量时得到 1，导致 np<1 直接原样返回——
%   零相位模式在所有逐行调用里都退化成了恒等映射。

    if exist('filtfilt', 'file') == 2
        y = filtfilt(b, a, x);
        return;
    end

    x = double(x);
    sz = size(x);
    isVec = isvector(x);
    if isVec
        x = x(:);
    end

    nz = max(numel(b), numel(a)) - 1;
    nx = size(x, 1);
    np = min(3 * nz, nx - 1);

    if np < 1
        y = x;
    else
        xp = [flipud(x(2:np+1, :)); x; flipud(x(end-np:end-1, :))];
        y1 = filter(b, a, xp, [], 1);
        y2 = flipud(filter(b, a, flipud(y1), [], 1));
        y  = y2(np+1 : np+nx, :);
    end

    if isVec
        y = reshape(y, sz);
    end
end
