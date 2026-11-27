function R = fl_barrier_build(A, B, w)
%FL_BARRIER_BUILD Interlace two images in vertical strips on A's native canvas.
% Odd strips come from A. B fills the canvas with a centered, uniform scale.
% The last strip is kept even if it contains fewer than w pixels.
[h, width, ~] = size(A);
bColumns = fl_barrier_columns(width, w, 0);
base = rgb8(A);
source = rgb8(B);
[bh, bw, ~] = size(source);
if bh == h && bw == width
    base(:,bColumns,:) = source(:,bColumns,:);
elseif any(bColumns)
    % Inverse-map output pixel centers. Only B's visible strips need sampling.
    scale = max(h/bh, width/bw);
    cols = find(bColumns);
    x = (cols - (width+1)/2) / scale + (bw+1)/2;
    y = ((1:h)' - (h+1)/2) / scale + (bh+1)/2;
    x = min(bw,max(1,x));  y = min(bh,max(1,y));
    x0 = floor(x);  x1 = min(x0+1,bw);  dx = single(x-x0);
    y0 = floor(y);  y1 = min(y0+1,bh);  dy = single(y-y0);
    % Limit interpolation scratch space for large photographs. Clamped indices
    % also handle one-row, one-column and one-pixel inputs.
    blockHeight = max(1,floor(2^18/numel(cols)));
    for first = 1:blockHeight:h
        rows = first:min(first+blockHeight-1,h);
        for c = 1:3
            upper = single(source(y0(rows),x0,c)).*(1-dx) + single(source(y0(rows),x1,c)).*dx;
            lower = single(source(y1(rows),x0,c)).*(1-dx) + single(source(y1(rows),x1,c)).*dx;
            base(rows,cols,c) = uint8(upper.*(1-dy(rows)) + lower.*dy(rows));
        end
    end
end
R = struct('Base',base,'Width',double(w),'Size',[h width]);
end

function rgb = rgb8(pixels)
if isempty(pixels) || issparse(pixels) || ~isreal(pixels) || ...
        ndims(pixels)>3 || ~ismember(size(pixels,3),[1 3])
    error('fl_barrier_build:image','请输入非空的灰度或 RGB 图像。');
end
switch class(pixels)
    case 'uint8'
        rgb = pixels;
    case 'uint16'
        rgb = uint8(single(pixels)./257);
    case 'logical'
        rgb = uint8(pixels).*uint8(255);
    case {'single','double'}
        if any(~isfinite(pixels(:))) || any(pixels(:)<0) || any(pixels(:)>1)
            error('fl_barrier_build:range','浮点图像必须为 [0,1] 内的有限数值。');
        end
        rgb = uint8(pixels.*255);
    otherwise
        error('fl_barrier_build:type','支持 uint8、uint16、logical 和 [0,1] 浮点图像。');
end
if size(rgb,3)==1, rgb = repmat(rgb,1,1,3); end
end
