function Y = sl_rot(X, theta, varargin)
%SL_ROT 以图像中心旋转 theta 度并裁剪回原尺寸
%   有 Image Processing Toolbox 时调用 imrotate；
%   否则用「逆映射 + 双线性插值」自实现，多出的参数（如 'bicubic','crop'）忽略。

    if exist('imrotate', 'file') == 2
        Y = imrotate(X, theta, 'bilinear', 'crop');
        return;
    end

    X = double(X);
    [M, N] = size(X);
    th = theta * pi / 180;
    c  = cos(th);
    s  = sin(th);
    cx = (N + 1) / 2;
    cy = (M + 1) / 2;

    [U, V] = meshgrid(1:N, 1:M);
    % 目标像素坐标 -> 源像素坐标（逆旋转）
    xs =  c * (U - cx) + s * (V - cy) + cx;
    ys = -s * (U - cx) + c * (V - cy) + cy;
    Y  = interp2(X, xs, ys, 'linear', 0);
end
