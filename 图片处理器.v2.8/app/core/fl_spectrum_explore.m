function R = fl_spectrum_explore(source, cycles, shiftPx, filterMode, cutoff, photo)
%FL_SPECTRUM_EXPLORE Explore a grayscale image and its centered 2-D DFT.
% Frequencies use cycles per preview pixel. Positive shifts move samples to
% the right (vertical stripes/photo) or down (horizontal stripes). A sample
% on the cutoff circle belongs to the low-pass mask. The output is signed.
% Phase is in radians and is meaningful only at bins with nonzero magnitude.
source = validatestring(source, {'vertical','horizontal','photo'}, mfilename, 'source');
filterMode = validatestring(filterMode, {'all','low','high'}, mfilename, 'filterMode');
validateattributes(cycles, {'numeric'}, {'real','scalar','finite','integer','>=',1,'<=',32});
validateattributes(shiftPx, {'numeric'}, {'real','scalar','finite','integer'});
validateattributes(cutoff, {'numeric'}, {'real','scalar','finite','>=',0,'<=',0.5});
maxEdge = 256;
shiftDim = 2;
if strcmp(source, 'photo')
    if nargin < 6 || isempty(photo)
        error('fl_spectrum_explore:photo', '请选择一张灰度或 RGB 照片。');
    end
    input = photo_preview(photo, maxEdge);
else
    wave = 0.5 + 0.5*sin((2*pi*double(cycles)/maxEdge)*(0:maxEdge-1));
    input = repmat(wave, maxEdge, 1);
    if strcmp(source, 'horizontal')
        input = input.';
        shiftDim = 1;
    end
end
input = circshift(input, double(shiftPx), shiftDim);
[height,width] = size(input);
fx = (-floor(width/2):ceil(width/2)-1)/width;
fy = (-floor(height/2):ceil(height/2)-1).'/height;
F = fftshift(fft2(input));
switch filterMode
    case 'all'
        mask = true(height,width);
    case 'low'
        mask = hypot(fy,fx) <= double(cutoff);
    case 'high'
        mask = hypot(fy,fx) > double(cutoff);
end
output = real(ifft2(ifftshift(F.*mask)));
magnitude = abs(F);
peak = max(magnitude(:));
retained = 0;  % Convention for an all-black image (zero total energy).
if peak > 0
    power = (magnitude/peak).^2;
    retained = min(1, sum(power(mask))/sum(power(:)));
end
R = struct('Input',input, 'Output',output, 'Spectrum',log1p(magnitude), ...
    'Phase',angle(F), 'Mask',mask, 'Fx',fx, 'Fy',fy, ...
    'MaxError',max(abs(input(:)-output(:))), 'RetainedEnergy',retained);
end

function preview = photo_preview(photo, maxEdge)
% Average pixel areas when reducing to integrate detail before decimation.
% Read strips so big photos need no full double copy.
if ~(isfloat(photo) || isa(photo,'uint8') || isa(photo,'uint16') || islogical(photo)) ...
        || ~isreal(photo) || issparse(photo) || ndims(photo) > 3 || ~ismember(size(photo,3),[1 3])
    error('fl_spectrum_explore:photo', '需要灰度或 RGB 照片，类型为 uint8、uint16、logical 或 [0,1] 浮点数。');
end
[h,w,channels] = size(photo);
scale = min(1, maxEdge/max(h,w));
nh = max(1,round(h*scale));
nw = max(1,round(w*scale));
if isinteger(photo)
    divisor = double(intmax(class(photo)));
else
    divisor = 1;
end
if channels == 1
    weights = 1;
else
    weights = [.2126 .7152 .0722];  % Rec. 709 luma matches the photo tools.
end
wy = area_weights(h,nh);
wx = area_weights(w,nw).';
preview = zeros(nh,nw);
blockHeight = max(1, floor(2^19/w));
for first = 1:blockHeight:h
    rows = first:min(h,first+blockHeight-1);
    gray = zeros(numel(rows),w);
    for c = 1:channels
        plane = double(photo(rows,:,c));
        if isfloat(photo) && any(~isfinite(plane(:)) | plane(:)<0 | plane(:)>1)
            error('fl_spectrum_explore:range', '浮点照片像素必须是 [0,1] 内的有限值。');
        end
        gray = gray + weights(c)*plane;
    end
    preview = preview + wy(:,rows)*(gray*wx);
end
preview = preview/divisor;
end

function weights = area_weights(src, dst)
% Each source cell overlaps at most two target cells because dst <= src.
if src == dst
    weights = speye(src);
    return
end
x = 0:src-1;
bin = floor(x*dst/src) + 1;
firstPart = min(1, (bin*src-x*dst)/dst);
split = firstPart < 1 & bin < dst;
weights = sparse([bin, bin(split)+1], [x+1, x(split)+1], ...
    [firstPart, 1-firstPart(split)]*(dst/src), dst, src);
end
