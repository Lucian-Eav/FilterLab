function S = fl_spec(varargin)
%FL_SPEC  实验规格：待比较的滤波器列表与评估参数。
%
%   S = FL_SPEC() 返回默认规格。默认的滤波器列表 Filters 是三个标准项：
%       10 阶 Butterworth（IIR）
%        4 阶 Parks-McClellan（FIR，5 个系数）
%       12 阶 Parks-McClellan（FIR，13 个系数）
%   过渡带总宽度 0.08、截止频率 0.4。
%
%   S = FL_SPEC('Name',Value,...) 用名值对覆盖任意字段，例如
%       S = fl_spec('Wc', 0.3, 'N2', 6, 'TransWidth', 0.05);
%
%   换成任意滤波器：直接改 Filters，个数不限。
%       S = fl_spec();
%       S.Filters = [S.Filters, fl_filter_load('mine.mat', 'Name', '我的')];
%       S.Filters(1) = [];                       % 去掉第一个
%       FL_main(S, 'Visible', 'off');
%
%   字段含义：
%       Filters       1×N 规格结构体，每个元素描述一个滤波器（见下）
%       Wc            全局截止频率，0 < Wc < 1（1 对应奈奎斯特频率）
%       TransWidth    全局过渡带总宽度，通带边 = Wc-TransWidth/2
%       N1/N2/N3      默认三项的阶数，供 Filters 里 OrderSrc 引用
%       PassW         统计群延迟时使用的通带上限，默认 0.9*Wc
%       AlignMode     计算保真度前的对齐方式，'shift' 或 'none'
%       Crop          计算整体误差时裁掉的边界像素数，避开零初值瞬态
%       FlatWin       平坦区判定的窗口边长
%       Seed          人工噪声的随机种子，保证结果可复现
%       NoiseSigma    人工噪声标准差
%
%   Filters 里每个元素可带字段：
%       Kind        'butter' | 'remez' | 'coeff' | 'identity'
%       Name        显示名，空则自动 f1/f2/…
%       Order       阶数；NaN 表示由 OrderSrc 指向的字段决定
%       OrderSrc    'N1'/'N2'/'N3'，配合默认三项使用
%       Wc          本项自己的截止频率；NaN 表示用全局 S.Wc
%       TransWidth  本项自己的过渡带；NaN 表示用全局 S.TransWidth
%       B, A        仅 Kind='coeff' 使用，直接给出的系数
%       Source      来源说明，用于报告里标注
%
%   本函数只做参数校验，不做任何计算，便于上层反复试参数而无需重跑设计。
%
%   见 also FL_DESIGN, FL_FILTER_LOAD, FL_FILTER2, FL_EVAL.

S = struct('Wc', 0.4, 'N1', 10, 'N2', 4, 'N3', 12, ...
           'TransWidth', 0.08, 'PassW', 0.36, ...
           'AlignMode', 'shift', 'Crop', NaN, 'CropOrder', 12, 'FlatWin', 5, ...
           'Edge', 'replicate', ...
           'Seed', 20260101, 'NoiseSigma', 0.2, ...
           'Filters', local_legacy());

if mod(numel(varargin), 2) ~= 0
    error('fl_spec:badArgs', '名值对参数必须是偶数个输入。');
end
for k = 1:2:numel(varargin)
    nm = varargin{k};
    if ~ischar(nm) && ~isstring(nm)
        error('fl_spec:badName', '第 %d 个参数应为字段名字符串。', k);
    end
    nm = char(nm);
    if ~isfield(S, nm)
        error('fl_spec:unknownField', '未知参数名：%s', nm);
    end
    S.(nm) = varargin{k+1};
end

% ---- 参数合法性检查：把错误挡在设计之前，而不是让它们变成离谱的曲线 ----
if ~(isscalar(S.Wc) && S.Wc > 0 && S.Wc < 1)
    error('fl_spec:badWc', 'Wc 必须是 (0,1) 内的标量。');
end
if ~(isscalar(S.TransWidth) && S.TransWidth > 0 && S.TransWidth < 2*S.Wc)
    error('fl_spec:badTW', 'TransWidth 必须为正，且小于 2*Wc。');
end
if S.Wc - S.TransWidth/2 <= 0 || S.Wc + S.TransWidth/2 >= 1
    error('fl_spec:band', '过渡带越出 (0,1)，请调整 Wc 或 TransWidth。');
end
for f = {'N1','N2','N3'}
    v = S.(f{1});
    if ~(isscalar(v) && v > 0 && mod(v,1) == 0)
        error('fl_spec:badOrder', '%s 必须是正整数。', f{1});
    end
end
if mod(S.N2, 2) ~= 0 || mod(S.N3, 2) ~= 0
    error('fl_spec:oddOrder', ...
        ['本软件的 Parks-McClellan 实现只支持偶数阶（第一类线性相位）。' ...
         '奇数阶会引入 Nyquist 频率处的零点约束，需要另一套基函数。']);
end
if ~any(strcmpi(S.AlignMode, {'shift','none'}))
    error('fl_spec:badAlign', 'AlignMode 只能是 ''shift'' 或 ''none''。');
end
if ~any(strcmpi(S.Edge, {'zero','symmetric','replicate'}))
    error('fl_spec:badEdge', 'Edge 只能是 zero / symmetric / replicate。');
end
if ~isempty(S.Crop) && ~isnan(S.Crop)
    if ~(isscalar(S.Crop) && S.Crop >= 0 && mod(S.Crop,1) == 0)
        error('fl_spec:badCrop', 'Crop 必须是非负整数（NaN 表示按图像尺寸与滤波器阶数自动推算）。');
    end
end
if mod(S.FlatWin, 2) ~= 1 || S.FlatWin < 3
    error('fl_spec:badWin', 'FlatWin 必须是 ≥3 的奇数。');
end

S.Filters = local_norm_filters(S.Filters, S);
end

% -------------------------------------------------------------------------
function F = local_legacy()
% 默认三项：NaN 的 Wc/TransWidth 表示"用全局值"，Order 由 OrderSrc 决定。
% 这样改 S.Wc / S.N2 时它们会自动跟着变，不需要重建列表。
F = struct('Kind',   {'butter', 'remez',  'remez'}, ...
           'Name',   {'b1',     'b2',     'b3'}, ...
           'Order',  {NaN,      NaN,      NaN}, ...
           'OrderSrc', {'N1',   'N2',     'N3'}, ...
           'Wc',     {NaN, NaN, NaN}, ...
           'TransWidth', {NaN, NaN, NaN}, ...
           'B',      {[], [], []}, ...
           'A',      {[], [], []}, ...
           'Source', {'默认', '默认', '默认'});
end

% -------------------------------------------------------------------------
function F = local_norm_filters(F, S)
if isempty(F)
    F = local_legacy();
end
if ~isstruct(F)
    error('fl_spec:filters', 'Filters 必须是结构体数组（可用 fl_filter_load 生成）。');
end

def = struct('Kind', 'coeff', 'Name', '', 'Order', NaN, 'OrderSrc', '', ...
             'Wc', NaN, 'TransWidth', NaN, 'B', [], 'A', [], 'Source', '');

for k = 1:numel(F)
    flds = fieldnames(def);
    for i = 1:numel(flds)
        if ~isfield(F(k), flds{i})
            F(k).(flds{i}) = def.(flds{i});
        end
    end
    if isempty(F(k).Name)
        F(k).Name = sprintf('f%d', k);
    end
    F(k).Kind = lower(char(F(k).Kind));
    switch F(k).Kind
        case 'butter'
            ord = local_order(F(k), S);
            if mod(ord, 2) ~= 0
                error('fl_spec:oddButter', ...
                    '第 %d 个滤波器（%s）：本实现的 Butterworth 只支持偶数阶。', ...
                    k, F(k).Name);
            end
        case 'remez'
            ord = local_order(F(k), S);
            if mod(ord, 2) ~= 0
                error('fl_spec:oddOrder', ...
                    ['第 %d 个滤波器（%s）：Parks-McClellan 只支持偶数阶' ...
                     '（第一类线性相位）。'], k, F(k).Name);
            end
        case 'coeff'
            if isempty(F(k).B) || isempty(F(k).A)
                error('fl_spec:coeffMissing', ...
                    '第 %d 个滤波器（%s）：Kind=''coeff'' 需要同时给出 B 和 A。', ...
                    k, F(k).Name);
            end
        case 'identity'
            % 什么都不用给
        otherwise
            error('fl_spec:kind', ...
                '第 %d 个滤波器（%s）：未知 Kind ''%s''（可选 butter/remez/coeff/identity）。', ...
                k, F(k).Name, F(k).Kind);
    end
end
end

% -------------------------------------------------------------------------
function ord = local_order(f, S)
ord = f.Order;
if (isnan(ord) || isempty(ord)) && ~isempty(f.OrderSrc)
    if ~isfield(S, f.OrderSrc)
        error('fl_spec:orderSrc', '未知的 OrderSrc：%s', f.OrderSrc);
    end
    ord = S.(f.OrderSrc);
end
if isnan(ord) || isempty(ord)
    error('fl_spec:noOrder', '滤波器（%s）没有给出 Order，也没有 OrderSrc。', f.Name);
end
if ~(isscalar(ord) && ord > 0 && mod(ord,1) == 0)
    error('fl_spec:badOrder', '滤波器（%s）的 Order 必须是正整数。', f.Name);
end
end
