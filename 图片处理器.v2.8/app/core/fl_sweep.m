function T = fl_sweep(S, field, values, varargin)
%FL_SWEEP  参数扫描：看关键指标随某一规格参数如何变化。
%
%   T = FL_SWEEP(S, FIELD, VALUES)
%   T = FL_SWEEP(..., 'Image', X, 'Noisy', Xn, 'Quiet', true)
%
%   FIELD  是 FL_SPEC 里的字段名，例如 'Wc'、'N2'、'N3'、'TransWidth'。
%   VALUES 是候选值向量。
%
%   返回结构体数组 T，每个元素对应一个取值，字段：
%       Param   该行的参数取值
%       GDMean  1×3 通带群延迟均值（b1 b2 b3）
%       GDStd   1×3 通带群延迟标准差（线性相位时应为 0）
%       OS      1×3 阶跃超调百分比
%       PSNR    1×3 降噪后与干净图的峰值信噪比（无噪声图时为 NaN）
%       ZC      1×3 振铃密度（残差符号变化次数，按像素归一）
%
%   题目报告要求"分析关键参数在不同取值条件下对结果的影响"，手工改一次参数、
%   跑一遍脚本很费时；本模块把这件事变成一次调用，并且保证每个取值都走同一
%   条处理链，避免"换了参数却忘了换别的设置"。
%
%   示例：
%       S = fl_spec();
%       T = fl_sweep(S, 'Wc', 0.20:0.05:0.50);
%
%   见 also FL_SPEC, FL_DESIGN, FL_FILTER2, FL_EVAL.

opt = struct('Image', [], 'Noisy', [], 'Quiet', false);
for k = 1:2:numel(varargin)-1
    if isfield(opt, varargin{k})
        opt.(varargin{k}) = varargin{k+1};
    end
end

X = opt.Image;
if isempty(X)
    here = fileparts(mfilename('fullpath'));
    src = fullfile(here, '..', 'samples', 'plus.mat');
    X = fl_load_image(src);
    if isempty(opt.Noisy)
        try
            tmp = load(src, 'xn');
            if isfield(tmp, 'xn') && isequal(size(tmp.xn), size(X))
                opt.Noisy = double(tmp.xn);
            end
        catch
            % 没有 xn 就只算不依赖噪声的指标
        end
    end
end
Xn = opt.Noisy;

values = values(:).';
T = repmat(struct('Param', 0, 'GDMean', [0 0 0], 'GDStd', [0 0 0], ...
                  'OS', [0 0 0], 'PSNR', [NaN NaN NaN], 'ZC', [0 0 0]), ...
           numel(values), 1);

for i = 1:numel(values)
    Sv = S;
    Sv.(field) = values(i);

    F = fl_design(Sv);
    T(i).Param = values(i);

    for k = 1:3
        T(i).GDMean(k) = F(k).GDMean;
        T(i).GDStd(k)  = F(k).GDStd;

        % 阶跃响应的超调：稳态已被归一化到 1
        y = filter(F(k).B, F(k).A, ones(1, 200));
        T(i).OS(k) = max([max(y) - 1, 0]) * 100;

        Y = fl_filter2(X, F(k).B, F(k).A, 'Edge', S.Edge);
        R = fl_eval(X, Y, Sv);
        T(i).ZC(k) = R.ZeroCross;

        if ~isempty(Xn)
            Yn = fl_filter2(Xn, F(k).B, F(k).A, 'Edge', S.Edge);
            Rn = fl_eval(X, Yn, Sv);
            T(i).PSNR(k) = Rn.PSNR;
        end
    end
end

if ~opt.Quiet
    local_print(T, field);
end
end

% ------------------------------------------------------------------------
function local_print(T, field)
names = {'b1','b2','b3'};
fprintf('\n参数扫描：%s\n', field);
fprintf('%-8s %-4s %9s %9s %8s %9s %9s\n', ...
        field, '滤波', '群延迟', '标准差', '超调%', 'PSNR dB', '振铃密度');
fprintf('%s\n', repmat('-', 1, 70));
for i = 1:numel(T)
    for k = 1:3
        fprintf('%-8.3f %-4s %9.3f %9.3f %8.2f %9.2f %9.4f\n', ...
            T(i).Param, names{k}, T(i).GDMean(k), T(i).GDStd(k), ...
            T(i).OS(k), T(i).PSNR(k), T(i).ZC(k));
    end
end
fprintf('\n读法：标准差为 0 说明该滤波器在整个通带内群延迟恒定，即线性相位；\n');
fprintf('      超调只取决于时域形状，与截止频率没有必然联系；\n');
fprintf('      PSNR 只在有噪声图时有意义，比较前务必先配准（本工具已做）。\n');
end
