function S = fl_phase_split(X, rounds)
%FL_PHASE_SPLIT Partition a grayscale or RGB image into disjoint sample phases.
% S.Tiles{r,c}(i,j,:) is X(r+(i-1)*S.Step,c+(j-1)*S.Step,:).
% Rounds 1 and 2 give steps 2 and 4. Edge samples keep their own phase.
if ~isnumeric(X) || ~isreal(X) || issparse(X) || ndims(X) > 3 || ...
        ~ismember(size(X,3), [1 3])
    error('fl_phase_split:image', '原图必须是实数数值灰度矩阵或三通道 RGB 数组。');
end
if ~isnumeric(rounds) || ~isreal(rounds) || ~isscalar(rounds) || ...
        ~ismember(rounds, [1 2])
    error('fl_phase_split:rounds', '请选择 1 轮或 2 轮分解。');
end
S.Rounds = double(rounds);
S.Step = 2^S.Rounds;
S.SourceSize = size(X);
if any(S.SourceSize(1:2) < S.Step)
    error('fl_phase_split:size', '进行 %d 轮分解时，原图的高和宽均须至少为 %d 像素。', S.Rounds, S.Step);
end
S.Tiles = cell(S.Step, S.Step);
for r = 1:S.Step
    for c = 1:S.Step
        S.Tiles{r,c} = X(r:S.Step:end, c:S.Step:end, :);
    end
end
end
