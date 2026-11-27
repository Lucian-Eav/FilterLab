function X = fl_phase_join(S)
%FL_PHASE_JOIN Interleave the phases at their original integer coordinates.
if ~isstruct(S) || ~isscalar(S) || ~all(isfield(S, {'Rounds','Step','SourceSize','Tiles'}))
    error('fl_phase_join:metadata', '缺少分解参数或相位图。');
end
if ~isnumeric(S.Rounds) || ~isreal(S.Rounds) || ~isscalar(S.Rounds) || ...
        ~ismember(S.Rounds,[1 2]) || ~isequal(S.Step, 2^double(S.Rounds))
    error('fl_phase_join:metadata', '分解轮数与采样步长不符。');
end
step = double(S.Step);
sz = S.SourceSize;
if ~isnumeric(sz) || ~isreal(sz) || ~isrow(sz) || ~ismember(numel(sz), [2 3]) || ...
        any(~isfinite(sz)) || any(sz ~= fix(sz)) || any(sz(1:2) < step) || ...
        (numel(sz) == 3 && ~ismember(sz(3), [1 3])) || ...
        ~iscell(S.Tiles) || ~isequal(size(S.Tiles), [step step])
    error('fl_phase_join:metadata', '原图尺寸或相位图数量不正确。');
end
sz = double(sz);
channels = prod(sz(3:end));  % prod([]) = 1 for a grayscale matrix.
prototype = S.Tiles{1,1};
for r = 1:step
    for c = 1:step
        tile = S.Tiles{r,c};
        if ~isnumeric(tile) || ~isreal(tile) || issparse(tile) || ...
                ~strcmp(class(tile),class(prototype)) || ndims(tile) > 3 || ...
                size(tile,1) ~= floor((sz(1)-r)/step)+1 || ...
                size(tile,2) ~= floor((sz(2)-c)/step)+1 || size(tile,3) ~= channels
            error('fl_phase_join:tile', '第 %d 行、第 %d 列的相位图类型或尺寸不正确。', r, c);
        end
    end
end
X = zeros(sz, 'like', prototype);
for r = 1:step
    for c = 1:step
        X(r:step:end, c:step:end, :) = S.Tiles{r,c};
    end
end
end
