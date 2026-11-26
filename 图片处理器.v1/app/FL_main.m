function out = FL_main(mode, varargin)
%FL_MAIN  FilterLab 入口：默认打开自然照片处理器，显式 demo/file 保留实验。
%
%   自然照片：FL_main / FL_gui / FL_photo；批处理使用 FL_process。
%   以下 demo/file/spec 数据结构入口属于旧版滤波实验，仍输出实验报告。
%
%   用法：
%       FL_main                       打开自然照片处理器
%       FL_main('demo')               用 plus.mat 跑旧版滤波实验
%       FL_main('lab')                打开旧版实验界面
%       FL_main('file','my.png')      分析自己的图像
%       FL_main('spec','Wc',0.3)      覆盖任意规格参数（见 FL_SPEC）
%       FL_main('gui')                打开图形界面
%       FL_main('test')               运行自检
%       R = FL_main(...)              返回结果结构体（不再画图时用 'Visible','off'）
%
%   可选名值对：
%       'FigDir'   图片输出目录，默认 <软件根目录>/output
%       'Visible'  'on' 显示图窗（默认），'off' 只在命令窗口出数字
%       'Save'     是否保存图片，默认 true
%
%   返回值 out 字段：Spec（规格）、Filter（滤波器组）、Result（分析结果）、
%   Image（使用的原图）、Noisy（含噪图）。
%
%   软件目录约定：
%       core/     核心算法（滤波器设计、二维滤波、相位分析、质量评估）
%       samples/  样例数据
%       docs/     用户手册
%       tests/    自检脚本
%
%   见 also FL_DESIGN, FL_REPORT, FL_GUI, FL_SELFTEST.

if nargin < 1 || isempty(mode)
    out = FL_gui();
    return;
end
givenSpec = false;
if isstruct(mode)
    givenSpec = true;
    Sinput = mode;
    mode = 'demo';
else
    mode = lower(char(mode));
end

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'core'));

% ---- 解析通用名值对 ----
opt = struct('FigDir', fullfile(here, 'output'), 'Visible', 'on', ...
             'Save', true, 'ImageFile', '');
userArgs = varargin;
switch mode
    case 'file'
        if isempty(userArgs) || ~ischar(userArgs{1})
            error('FL_main:noFile', 'file 模式需要给出图像路径。');
        end
        imgPath = userArgs{1};
        userArgs = userArgs(2:end);
    case 'demo'
        imgPath = fullfile(here, 'samples', 'plus.mat');
    case {'gui','photo'}
        out = FL_gui(userArgs{:});
        return;
    case 'assignment'
        out = FL_assignment_gui(userArgs{:});
        return;
    case 'assignment-run'
        out = FL_assignment(userArgs{:});
        return;
    case 'lab'
        FL_lab_gui();
        out = [];
        return;
    case 'test'
        out = fl_selftest();
        return;
    otherwise
        error('FL_main:badMode', '未知模式：%s', mode);
end

specArgs = {};
rest = {};
k = 1;
while k <= numel(userArgs)
    if ~ischar(userArgs{k})
        error('FL_main:badArgs', '参数名必须是字符串。');
    end
    if isfield(opt, userArgs{k})
        opt.(userArgs{k}) = userArgs{k+1};
        k = k + 2;
    else
        specArgs{end+1} = userArgs{k};      %#ok<AGROW>
        specArgs{end+1} = userArgs{k+1};    %#ok<AGROW>
        k = k + 2;
    end
end

% ImageFile 对两种入口都生效（字符串入口也允许换图，否则 'demo' 永远读样例）
if ~isempty(opt.ImageFile)
    imgPath = opt.ImageFile;
end

if givenSpec
    S = local_validate_struct(Sinput);
else
    S = fl_spec(specArgs{:});
end

fprintf('============================================================\n');
fprintf(' 图像可分离滤波与相位失真分析软件 V1.0\n');
fprintf('============================================================\n');
fprintf(' 输入      : %s\n', imgPath);
fprintf(' 截止频率  : Wc = %.3f\n', S.Wc);
fprintf(' 滤波器    : %d 个\n', numel(S.Filters));
fprintf(' 过渡带    : [%.3f, %.3f]\n', S.Wc-S.TransWidth/2, S.Wc+S.TransWidth/2);
fprintf('------------------------------------------------------------\n');

[X, meta] = fl_load_image(imgPath);
fprintf(' 读入      : %d × %d，数值范围 [%.4f, %.4f]\n', ...
        size(X,1), size(X,2), meta.RawRange(1), meta.RawRange(2));

% ---- 如果 MAT 里同时带噪声版本，直接用它，保证与原始题目数据一致 ----
Xn = [];
if strcmpi(mode, 'demo')
    try
        tmp = load(imgPath, 'xn');
        if isfield(tmp, 'xn') && isequal(size(tmp.xn), size(X))
            Xn = double(tmp.xn);
            fprintf(' 噪声图    : 使用 plus.mat 中的 xn 变量\n');
        end
    catch
        % 没有 xn 就按规格自动生成
    end
end

F = fl_design(S);
fprintf(' 待比较    : %s\n', strjoin({F.Name}, ' / '));

fprintf('\n【第 1 问】设计结果\n');
fprintf('  %-4s %-4s %-3s %-3s %-7s %-5s %-14s %s\n', ...
        '名称', '类型', '阶', '长', '增益', '线性', '通带', '群延迟');
for k = 1:numel(F)
    fprintf('  %-5s %-5s %-4d %-4d %-8.4f %-5s %.3f~%.3f   %.3f±%.3f\n', ...
        F(k).Name, F(k).Type, F(k).Order, F(k).Len, F(k).DCGain, ...
        local_yn(F(k).Linear), F(k).PassMin, F(k).PassMax, ...
        F(k).GDMean, F(k).GDStd);
end
fprintf('  说明：remez 的 n 是阶数，系数长度 n+1。\n');
fprintf('        "通带"是 [0, Wc-过渡带/2] 内的最小与最大增益；理想低通应接近 1.000~1.000。\n');
bad = find(arrayfun(@(f) f.PassMin < 0.9 || f.PassMax > 1.1, F));
if ~isempty(bad)
    fprintf('        注意：'); 
    for k = bad
        fprintf('%s 通带偏离 1 超过 10%%', F(k).Name);
        if k ~= bad(end), fprintf('；'); end
    end
    fprintf('。\n        照片上这会表现为整体发灰（<1）或边缘光晕（>1），必要时换更大的阶数。\n');
end

fprintf('\n【第 2 问】相位类型\n');
for k = 1:numel(F)
    sym = max(abs(F(k).Braw - fliplr(F(k).Braw)));
    isFIR = (numel(F(k).A) == 1) && (F(k).A(1) == 1);
    if F(k).Linear
        fprintf('  %s：系数偶对称误差 %.1e，通带群延迟 %.3f（标准差 %.1e）⇒ 严格线性相位\n', ...
            F(k).Name, sym, F(k).GDMean, F(k).GDStd);
    elseif isFIR
        fprintf('  %s：系数不对称（误差 %.3e），群延迟 %.3f ± %.3f ⇒ 非线性相位\n', ...
            F(k).Name, sym, F(k).GDMean, F(k).GDStd);
    else
        fprintf('  %s：这是 IIR，分子系数的对称性没有判别意义（此处误差 %.1e，\n', F(k).Name, sym);
        fprintf('       偶数阶 Butterworth 的分子恰好是回文多项式）。真正让相位非线性的\n');
        fprintf('       是分母的极点，群延迟 %.3f ± %.3f ⇒ 非线性相位。\n', F(k).GDMean, F(k).GDStd);
    end
end

figDir = '';
if opt.Save
    figDir = opt.FigDir;
    if ~exist(figDir, 'dir')
        mkdir(figDir);
    end
end

R = fl_report(X, F, S, 'Noisy', Xn, 'FigDir', figDir, 'Visible', opt.Visible);

fprintf('\n------------------------------------------------------------\n');
fprintf(' 分析完成。图片输出目录：%s\n', figDir);
fprintf('============================================================\n');

out = struct('Spec', S, 'Filter', F, 'Result', R, 'Image', X, 'Noisy', R.Noisy);
end

% ------------------------------------------------------------------------
function S = local_validate_struct(Sin)
% 把结构体摊成名值对再走一遍 fl_spec，保证校验与归一化只有一条路径
if ~isstruct(Sin)
    error('FL_main:badSpec', '第一个参数若是结构体，必须是 FL_SPEC 返回的规格。');
end
flds = fieldnames(Sin);
args = cell(1, 2 * numel(flds));
for i = 1:numel(flds)
    args{2*i - 1} = flds{i};
    args{2*i}     = Sin.(flds{i});
end
try
    S = fl_spec(args{:});
catch err
    error('FL_main:badSpec', '规格校验失败：%s', err.message);
end
end

% ------------------------------------------------------------------------
function s = local_yn(tf)
if tf, s = '是'; else, s = '否'; end
end
