function Y = fl_ext_direction(X, theta, margin, filterRows)
%FL_EXT_DIRECTION Filter along theta (degrees, clockwise in image coordinates).
% filterRows accepts one 2-D channel and filters along its horizontal rows.
if nargin < 3 || isempty(margin), margin = 0; end
validateattributes(X, {'numeric'}, {'nonempty','finite','real'});
validateattributes(theta, {'numeric'}, {'scalar','finite','real'});
validateattributes(margin, {'numeric'}, {'scalar','nonnegative','finite'});
X = double(X); [h,w,nc] = size(X);
% A reflected square includes both rotated footprint and filter transients.
side = ceil(hypot(h,w)) + 2*ceil(margin) + 4;
py = ceil((side-h)/2); px = ceil((side-w)/2);
iy = reflect_index((1-py):(h+py), h);
ix = reflect_index((1-px):(w+px), w);
% sl_rot's interpolation fallback rotates clockwise; imrotate is opposite.
angle = -theta;
if exist('imrotate','file') == 2, angle = theta; end
Y = zeros(size(X));
for c = 1:nc
    canvas = X(iy,ix,c);
    if mod(theta,180) == 0
        filtered = filterRows(canvas);
    else
        rotated = sl_rot(canvas,angle);
        filtered = sl_rot(filterRows(rotated),-angle);
    end
    Y(:,:,c) = filtered(py+(1:h),px+(1:w));
end
end

function idx = reflect_index(k,n)
if n == 1, idx = ones(size(k)); return; end
t = mod(k-1,2*(n-1)); idx = 1+min(t,2*(n-1)-t);
end
