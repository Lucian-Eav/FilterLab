function sp = fl_filter_load(src, varargin)
%FL_FILTER_LOAD  从一个来源读出滤波器系数，生成可直接放进 S.Filters 的规格。
%
%   SP = FL_FILTER_LOAD(SRC) 支持四类来源：
%
%       数值向量            [1 2 1]        → FIR，a = 1
%       元胞                {b, a}          → 直接给定
%       结构体              含 B/A 或 b/a   → 直接给定
%                           含 SOS / sos   → 级联二阶节展开成一阶多项式
%       文件路径
%             .mat   自动查找 b/a、B/A、num/den、Num/Den、sos/SOS
%             .csv / .txt / .dat
%                    一列 = 分子系数（FIR），两列 = 第一列 b、第二列 a
%
%   SP = FL_FILTER_LOAD(..., 'Name', '我的滤波器') 指定显示名。
%
%   返回 SP 是单元素规格结构体（Kind = 'coeff'），拼到默认列表后面即可：
%
%       S = fl_spec();
%       S.Filters = [S.Filters, fl_filter_load('mine.mat', 'Name', '我的')];
%       FL_main(S, 'Visible', 'off');
%
%   这样自带的 b1/b2/b3 变成了"可替换的默认项"，而不是写死的三件套。
%
%   见 also FL_SPEC, FL_DESIGN, FL_FILTER2.

opt = struct('Name', '', 'Var', '');
for k = 1:2:numel(varargin)
    nm = varargin{k};
    if ~isfield(opt, nm)
        error('fl_filter_load:badName', '未知参数：%s', nm);
    end
    opt.(nm) = varargin{k+1};
end

desc = '';
if isnumeric(src)
    b = src(:).';
    a = 1;
    desc = '来自数值向量';

elseif iscell(src)
    if numel(src) ~= 2
        error('fl_filter_load:cell', '元胞输入必须是 {b, a} 两个元素。');
    end
    b = src{1}(:).';
    a = src{2}(:).';
    desc = '来自元胞 {b, a}';

elseif isstruct(src)
    [b, a] = local_from_struct(src);
    desc = '来自结构体';

elseif ischar(src) || isstring(src)
    src = char(src);
    if ~exist(src, 'file')
        error('fl_filter_load:noFile', '文件不存在：%s', src);
    end
    [~, base, ext] = fileparts(src);
    switch lower(ext)
        case '.mat'
            b = []; a = [];
            [b, a] = local_from_mat(src, opt.Var);
            desc = ['来自 ' base '.mat'];
            if isempty(opt.Name)
                opt.Name = base;
            end
        case {'.csv', '.txt', '.dat'}
            [b, a] = local_from_text(src);
            desc = ['来自 ' base ext];
            if isempty(opt.Name)
                opt.Name = base;
            end
        otherwise
            error('fl_filter_load:ext', ...
                '不支持的文件类型：%s（支持 .mat / .csv / .txt / .dat）', ext);
    end
else
    error('fl_filter_load:src', '无法识别的输入类型。');
end

% ---- 统一校验 ----
b = double(b(:).');
a = double(a(:).');
if isempty(b) || isempty(a)
    error('fl_filter_load:empty', '分子或分母系数为空。');
end
if any(~isfinite([b, a]))
    error('fl_filter_load:nan', '系数含 NaN 或 Inf。');
end
if any(imag([b, a]) ~= 0)
    error('fl_filter_load:complex', '系数含虚部；本软件只处理实系数滤波器。');
end
if a(1) == 0
    error('fl_filter_load:zeroA', '分母首项 a(1) 为 0，不是合法的传递函数。');
end
if all(b == 0)
    error('fl_filter_load:zeroB', '分子系数全为 0。');
end
a = a / a(1);

nm = opt.Name;
if isempty(nm)
    nm = sprintf('自定义%d', randi(99));
end

sp = struct('Kind', 'coeff', 'Name', nm, ...
            'Order', max(numel(b), numel(a)) - 1, ...
            'OrderSrc', '', ...
            'Wc', NaN, 'TransWidth', NaN, ...
            'B', b, 'A', a, 'Source', desc);
end

% -------------------------------------------------------------------------
function [b, a] = local_from_struct(st)
sos = local_pick_sos(st);
if ~isempty(sos)
    [b, a] = local_sos2tf(sos);
    return;
end
[bn, an] = local_pick_bapair(st);
b = bn; a = an;
end

% -------------------------------------------------------------------------
function s = local_pick_sos(st)
s = [];
names = fieldnames(st);
for i = 1:numel(names)
    v = st.(names{i});
    if isnumeric(v) && size(v, 2) == 6 && size(v, 1) >= 1
        s = v;
        return;
    end
end
end

% -------------------------------------------------------------------------
function [b, a] = local_pick_bapair(st)
[b, a] = local_search_pair(st);
if isempty(b)
    error('fl_filter_load:noCoeff', ...
        ['结构体里没找到系数。请提供 B/A（或 b/a）字段，' ...
         '或一个 6 列的 SOS 矩阵。']);
end
end

% -------------------------------------------------------------------------
function [b, a] = local_search_pair(st)
b = []; a = [];
bpairs = {{'b','a'}, {'B','A'}, {'num','den'}, {'Num','Den'}, ...
          {'Numerator','Denominator'}, {'numerator','denominator'}};
names = fieldnames(st);
for i = 1:size(bpairs, 1)
    n1 = bpairs{i}{1}; n2 = bpairs{i}{2};
    if any(strcmp(names, n1)) && any(strcmp(names, n2))
        v1 = st.(n1); v2 = st.(n2);
        if isnumeric(v1) && isnumeric(v2) && isvector(v1) && isvector(v2)
            b = v1(:).'; a = v2(:).';
            return;
        end
    end
end
% 退一步：找第一个数值向量当 b，第二个当 a
vecs = {};
for i = 1:numel(names)
    v = st.(names{i});
    if isnumeric(v) && isvector(v) && numel(v) >= 1 && ~isscalar(v)
        vecs{end+1} = v(:).';                    %#ok<AGROW>
    end
end
if numel(vecs) >= 1
    b = vecs{1};
end
if numel(vecs) >= 2
    a = vecs{2};
else
    a = 1;
end
end

% -------------------------------------------------------------------------
function [b, a] = local_from_mat(f, wantVar)
M = load(f);
if ~isempty(wantVar)
    if ~isfield(M, wantVar)
        error('fl_filter_load:var', 'MAT 文件里没有变量 %s。', wantVar);
    end
    v = M.(wantVar);
    if isnumeric(v) && size(v, 2) == 6
        [b, a] = local_sos2tf(double(v));
    else
        b = double(v(:).'); a = 1;
    end
    return;
end
sos = local_pick_sos(M);
if ~isempty(sos)
    [b, a] = local_sos2tf(sos);
    return;
end
[b, a] = local_search_pair(M);
if isempty(b)
    error('fl_filter_load:noCoeff', ...
        ['%s 里没找到系数。支持的变量名：b/a、B/A、num/den、sos（6 列）。'], f);
end
end

% -------------------------------------------------------------------------
function [b, a] = local_from_text(f)
M = readmatrix(f);
M = M(~all(isnan(M), 2), :);
if isempty(M)
    error('fl_filter_load:emptyText', '%s 里没有数值。', f);
end
if size(M, 2) == 1
    b = M(:, 1).'; a = 1;
elseif size(M, 2) == 2
    b = M(:, 1).';
    a = M(:, 2).';
else
    error('fl_filter_load:textShape', ...
        '%s 应为 1 列（FIR）或 2 列（b 和 a），实际 %d 列。', f, size(M, 2));
end
end

% -------------------------------------------------------------------------
function [b, a] = local_sos2tf(sos)
K = size(sos, 1);
b = 1; a = 1;
for i = 1:K
    gi = sos(i, 1);            % 增益
    if gi == 0
        gi = 1;
    end
    b = conv(b, gi * sos(i, 2:3));
    a = conv(a, sos(i, 5:6));
end
end
