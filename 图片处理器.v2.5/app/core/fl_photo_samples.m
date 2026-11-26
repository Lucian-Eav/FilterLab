function result = fl_photo_samples(source,roi,step)
%FL_PHOTO_SAMPLES Sample a photo on one ROI-anchored lattice, with/without low-pass.
% SOURCE is sRGB, single/double RGB in [0,1], as returned by fl_photo_load.
% ROI = [x y width height], in 1-based original pixel coordinates (inclusive).
% Both paths start at (x,y) and advance STEP original pixels along each axis.
% Use actual neighbours across ROI boundaries. Replicate at physical image edges.
if ~(isa(source,'single') || isa(source,'double')) || ~isreal(source) || ...
        ndims(source) ~= 3 || size(source,3) ~= 3 || isempty(source)
    error('fl_photo_samples:image','请输入 [0,1] 范围内的浮点 RGB 照片。');
end
validateattributes(step,{'numeric'},{'scalar','real','finite','integer','>=',1,'<=',16});
validateattributes(roi,{'numeric'},{'real','finite','integer','positive','vector','numel',4});
step = double(step); roi = reshape(double(roi),1,4);
[h,w,~] = size(source);
x = roi(1); y = roi(2); right = x+roi(3)-1; bottom = y+roi(4)-1;
if right>w || bottom>h
    error('fl_photo_samples:bounds','选区超出照片范围。');
end
if isequal(roi,[1 1 w h])
    original = single(source);
else
    original = single(source(y:bottom,x:right,:));
end
sx = x:step:right; sy = y:step:bottom;
if step == 1
    direct = original; lowpass = original; sigma = 0; kernel = 1;
else
    direct = single(source(sy,sx,:));
    sigma = 0.6*step;
    radius = ceil(3*sigma);
    offsets = -radius:radius;
    kernel = exp(-0.5*(offsets/sigma).^2);
    kernel = kernel/sum(kernel); % unit DC gain
    weights = single(kernel);
    lowpass = zeros(size(direct),'single');
    % Tile source rows. Compute horizontal sums only at retained columns,
    % then vertical sums only at retained rows, keeping intermediates small.
    tileRows = max(1,min(numel(sy),floor(5e5/(step*numel(sx)))));
    for first = 1:tileRows:numel(sy)
        dest = first:min(first+tileRows-1,numel(sy));
        rows = max(1,min(h,(sy(dest(1))-radius):(sy(dest(end))+radius)));
        centers = sy(dest)-sy(dest(1))+radius+1;
        for channel = 1:3
            horiz = zeros(numel(rows),numel(sx),'single');
            for tap = 1:numel(offsets)
                cols = max(1,min(w,sx+offsets(tap)));
                horiz = horiz + weights(tap).*single(source(rows,cols,channel));
            end
            band = zeros(numel(dest),numel(sx),'single');
            for tap = 1:numel(offsets)
                band = band + weights(tap).*horiz(centers+offsets(tap),:);
            end
            lowpass(dest,:,channel) = band;
        end
    end
    lowpass = max(0,min(1,lowpass));
end
result = struct('ROI',roi,'Step',step,'Original',original,'Direct',direct, ...
    'Lowpass',lowpass,'SampleX',sx,'SampleY',sy,'Sigma',sigma,'Kernel',kernel, ...
    'Boundary','replicate at photo edge');
end
