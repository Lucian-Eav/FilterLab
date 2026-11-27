function FL_lab_gui(varargin)
%FL_GUI  图形界面：参数设置、运行分析、结果浏览与导出。
%
%   FL_GUI                     打开界面
%   FL_GUI('Visible','off')    只建界面不显示（用于自检与环境探测）
%
%   界面分左右两栏。左栏设置规格参数并触发分析，右栏显示原图、含噪图、
%   三个滤波器的输出图像，以及"越界能量 / 振铃密度"的归一化对比柱状图。
%
%   界面本身不实现任何算法：所有计算都转发给 FL_MAIN，保证界面运行结果与
%   命令行运行结果完全一致，便于结果复现和问题定位。
%
%   见 also FL_MAIN, FL_SPEC, FL_DESIGN, FL_REPORT, FL_EVAL.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'core'));
addpath(here);

vis = 'on';
for k = 1:2:numel(varargin)-1
    if strcmpi(varargin{k}, 'Visible')
        vis = varargin{k+1};
    end
end

S0     = fl_spec();
outDir = fullfile(here, 'output');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

state = struct('Source', fullfile(here, 'samples', 'plus.mat'), ...
               'IsDemo', true, 'Out', [], 'LastLog', '', 'Extra', {{}});

% ======================= 图窗与布局 =======================
fig = uifigure('Name', '图像可分离滤波与相位失真分析软件 V1.0', ...
               'Position', [60 50 1300 800], 'Visible', vis);

GL = uigridlayout(fig, [1 2]);
GL.ColumnWidth   = {390, '1x'};
GL.RowHeight     = {'1x'};
GL.Padding       = [8 8 8 8];
GL.ColumnSpacing = 8;

LP = uipanel(GL, 'Title', '参数与操作');
LG = uigridlayout(LP, [13 2]);
LG.ColumnWidth  = {130, '1x'};
LG.RowHeight    = {26,26,26,26,26,26,28,28,28,28,24,24,'1x'};
LG.Padding      = [8 8 8 8];
LG.RowSpacing   = 6;

RP = uipanel(GL, 'Title', '结果');
RG = uigridlayout(RP, [2 3]);
RG.RowHeight   = {'1x','1x'};
RG.ColumnWidth = {'1x','1x','1x'};

axX   = uiaxes(RG);
axN   = uiaxes(RG);
axA   = cell(1,3);
for k = 1:3
    axA{k} = uiaxes(RG);
end
axBar = uiaxes(RG);

% ---- 左栏控件（每个都带大白话提示，悬停即可看到）----
uilabel(LG, 'Text', '截止频率 Wc', 'Tooltip', ...
    '保留多少细节。调大 = 更清楚但噪声也留下；调小 = 更干净但边缘会糊。建议 0.40。');
edWc = uieditfield(LG, 'numeric', 'Value', S0.Wc, 'Limits', [0.05 0.95], 'Tooltip', ...
    '0.30 偏干净，0.50 偏清楚。它只决定"留多细"，不是越大越好。');

uilabel(LG, 'Text', '过渡带宽', 'Tooltip', ...
    '从"保留"过渡到"丢弃"的坡度。以 Wc 为中心向两边各扩一半，所以调大反而更糊、但振铃更小。只对 N2/N3 有效。');
edTw = uieditfield(LG, 'numeric', 'Value', S0.TransWidth, 'Limits', [0.01 0.40], 'Tooltip', ...
    '0.08 是起点。白边黑边刺眼就加到 0.12–0.15。对第一个（Butterworth）完全无效。');

uilabel(LG, 'Text', 'Butterworth 阶数', 'Tooltip', ...
    '第一个滤波器有多陡。阶数越高越狠，但整张图被挪得越多、边缘也越糊。建议 10。');
edN1 = uieditfield(LG, 'numeric', 'Value', S0.N1, 'Limits', [2 20], ...
                  'RoundFractionalValues', 'on', 'Tooltip', ...
                  '想要柔和模糊就用 2–4；超过 10 阶基本只有坏处。');

uilabel(LG, 'Text', 'FIR 阶数 N2', 'Tooltip', ...
    '第二个 FIR 的阶数（系数个数 = 阶数+1）。位移恒为 阶数/2 像素。建议 4 或 12–16，别停在 8（8 阶在此配置下明显更差）。');
edN2 = uieditfield(LG, 'numeric', 'Value', S0.N2, 'Limits', [2 40], ...
                  'RoundFractionalValues', 'on', 'Tooltip', ...
                  '5 个系数（阶数 4）时阻带只能到 -8.5 dB，别指望它压噪声。必须偶数。');

uilabel(LG, 'Text', 'FIR 阶数 N3', 'Tooltip', ...
    '第三个 FIR 的阶数，过渡带最陡，但位移最大（20 阶会挪 10 个像素）。建议 12。');
edN3 = uieditfield(LG, 'numeric', 'Value', S0.N3, 'Limits', [2 40], ...
                  'RoundFractionalValues', 'on', 'Tooltip', ...
                  '12 阶 = 13 个系数。必须偶数（本实现只做第一类线性相位）。');

uilabel(LG, 'Text', '噪声标准差 σ', 'Tooltip', ...
    '给原图加多少随机噪声，只影响含噪图，不改变滤波器设计。噪声小于 0.17 时滤波反而更糟。');
edNs = uieditfield(LG, 'numeric', 'Value', S0.NoiseSigma, 'Limits', [0 0.8], 'Tooltip', ...
    '0 = 看滤镜怎么糟蹋干净图；0.2 = 常规；0.4 = 看噪声大起来后谁更扛。');

btnDemo   = uibutton(LG, 'Text', '样例数据', 'ButtonPushedFcn', @(~,~) doDemo());
btnLoad   = uibutton(LG, 'Text', '载入图像…', 'ButtonPushedFcn', @(~,~) doLoad());
btnRun    = uibutton(LG, 'Text', '运行分析', 'FontWeight', 'bold', ...
                     'ButtonPushedFcn', @(~,~) doRun());
btnExport = uibutton(LG, 'Text', '导出报告', 'ButtonPushedFcn', @(~,~) doExport());
btnShow   = uibutton(LG, 'Text', '🎬 成果演示', 'FontWeight', 'bold', ...
                     'FontColor', [0.10 0.35 0.65], ...
                     'ButtonPushedFcn', @(~,~) doPresent());
btnFilt   = uibutton(LG, 'Text', '＋ 载入滤波器…', ...
                     'ButtonPushedFcn', @(~,~) doLoadFilter());

btnDemo.Layout.Row = 7;  btnDemo.Layout.Column = 1;
btnLoad.Layout.Row = 7;  btnLoad.Layout.Column = 2;
btnRun.Layout.Row  = 8;  btnRun.Layout.Column  = 1;
btnExport.Layout.Row = 8; btnExport.Layout.Column = 2;
btnFilt.Layout.Row = 9;  btnFilt.Layout.Column = [1 2];
btnShow.Layout.Row = 10; btnShow.Layout.Column = [1 2];

lblSource = uilabel(LG, 'Text', '数据源');
txtSource = uilabel(LG, 'Text', 'plus.mat（样例）', 'Interpreter', 'none');
lblSource.Layout.Row = 11; lblSource.Layout.Column = 1;
txtSource.Layout.Row = 11; txtSource.Layout.Column = 2;

lblStatus = uilabel(LG, 'Text', '状态');
statusLbl = uilabel(LG, 'Text', '就绪', 'FontColor', [0.25 0.45 0.25]);
lblStatus.Layout.Row = 12; lblStatus.Layout.Column = 1;
statusLbl.Layout.Row = 12; statusLbl.Layout.Column = 2;

log = uitextarea(LG, 'Editable', 'off', 'FontName', 'Consolas', 'FontSize', 10);
log.Layout.Row    = 13;
log.Layout.Column = [1 2];
log.Value = {'点击"样例数据"或"载入图像"后开始分析。', ...
             '可点"＋ 载入滤波器"把自己的系数加进比较列表。', ...
             '不懂参数？鼠标悬停在左侧每一项上，会显示大白话说明。', ...
             '完整说明见 docs\调参指南.md'};

% ======================= 回调 =======================
    function doDemo()
        state.Source = fullfile(here, 'samples', 'plus.mat');
        state.IsDemo = true;
        txtSource.Text = 'plus.mat（样例）';
        doRun();
    end

    function doLoad()
        [f, p] = uigetfile({'*.mat;*.png;*.jpg;*.jpeg;*.bmp;*.tif', ...
                            '图像文件 (*.mat, *.png, *.jpg, *.bmp, *.tif)'}, ...
                           '选择待分析的图像');
        if isequal(f, 0)
            return;
        end
        state.Source = fullfile(p, f);
        state.IsDemo = false;
        txtSource.Text = f;
        doRun();
    end

    function doLoadFilter()
        [f, p] = uigetfile({'*.mat;*.csv;*.txt;*.dat', ...
                            '系数文件 (*.mat, *.csv, *.txt, *.dat)'}, ...
                           '选择滤波器系数文件');
        if isequal(f, 0)
            return;
        end
        try
            sp = fl_filter_load(fullfile(p, f));
            sp.Name = regexprep(f, '\.[^.]+$', '');
            state.Extra{end+1} = sp;
            btnFilt.Text = sprintf('＋ 载入滤波器（已加 %d 个）', numel(state.Extra));
            statusLbl.Text = sprintf('已载入 %s（%d 个系数）', sp.Name, numel(sp.B));
            doRun();
        catch err
            uialert(fig, err.message, '载入失败');
        end
    end

    function doRun()
        btnRun.Enable = 'off';
        statusLbl.Text = '正在计算…';
        drawnow;
        try
            S = buildSpec();
            P = state.Source;
            if state.IsDemo
                [txt, out] = evalc('FL_main(S, ''Visible'', ''off'', ''Save'', false)');
            else
                [txt, out] = evalc(['FL_main(S, ''Visible'', ''off'', ''Save'', false, ' ...
                                    '''ImageFile'', P)']);
            end
            state.Out     = out;
            state.LastLog = txt;
            log.Value     = splitlines(txt);
            refreshPlot();
            statusLbl.Text = sprintf('%d 个滤波器，完成 %s', numel(out.Filter), ...
                                     char(datetime('now', 'Format', 'HH:mm:ss')));
        catch err
            log.Value = [{'运行失败：'}; {err.message}];
            statusLbl.Text = '失败';
        end
        btnRun.Enable = 'on';
    end

    function S = buildSpec()
        S = fl_spec('Wc', edWc.Value, 'TransWidth', edTw.Value, ...
                    'N1', round(edN1.Value), 'N2', round(edN2.Value), ...
                    'N3', round(edN3.Value), 'NoiseSigma', edNs.Value);
        if ~isempty(state.Extra)
            S.Filters = [S.Filters, state.Extra{:}];
        end
    end

    function refreshPlot()
        if isempty(state.Out)
            return;
        end
        O = state.Out;
        showImg(axX, O.Image, '原图 x');
        if ~isempty(O.Noisy)
            showImg(axN, O.Noisy, '含噪图 xn');
        else
            cla(axN); axis(axN, 'off'); title(axN, '无噪声图');
        end
        nF = numel(O.Filter);
        nS = min(3, nF);
        for k = 1:3
            if k <= nS
                showImg(axA{k}, O.Result.Filtered{k}, ...
                        sprintf('%s 输出（%s，%d 阶）', O.Filter(k).Name, ...
                                O.Filter(k).Type, O.Filter(k).Order));
            else
                cla(axA{k}); axis(axA{k}, 'off'); title(axA{k}, '');
            end
        end
        if nF > nS
            title(axA{3}, sprintf('%s 输出（%s，%d 阶）\n另有 %d 个未显示', ...
                  O.Filter(3).Name, O.Filter(3).Type, O.Filter(3).Order, nF - nS));
        end

        eo = zeros(1, nF); zc = zeros(1, nF);
        for k = 1:nF
            eo(k) = O.Result.Metrics(k).OutEnergy;
            zc(k) = O.Result.Metrics(k).ZeroCross;
        end
        eo = eo / max([eo, eps]);
        zc = zc / max([zc, eps]);
        bar(axBar, [eo(:), zc(:)]);
        axBar.XTick = 1:nF;
        axBar.XTickLabel = {O.Filter.Name};
        if nF > 4
            axBar.XTickLabelRotation = 30;
        end
        legend(axBar, {'越界能量（归一）', '振铃密度（归一）'}, ...
               'Location', 'northoutside');
        title(axBar, '振荡强度对比');
        grid(axBar, 'on');
    end

    function doExport()
        if isempty(state.Out)
            log.Value = {'还没有可导出的结果，请先运行分析。'};
            return;
        end
        stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
        fid = fopen(fullfile(outDir, ['分析报告_' stamp '.txt']), 'w', 'n', 'UTF-8');
        if fid > 0
            fprintf(fid, '%s', strjoin(cellstr(splitlines(state.LastLog)), newline));
            fclose(fid);
        end
        axs = [axX, axN, axA{1}, axA{2}, axA{3}, axBar];
        nms = {'原图','含噪图','b1','b2','b3','指标对比'};
        for k = 1:numel(axs)
            try
                exportgraphics(axs(k), ...
                    fullfile(outDir, sprintf('界面_%s_%s.png', nms{k}, stamp)), ...
                    'Resolution', 150);
            catch
                % 单张导出失败不影响其余
            end
        end
        log.Value = ['已导出到 output\：' stamp];
        statusLbl.Text = '已导出';
    end

    function doPresent()
        % 打开成果演示窗口（读 output/ 下已生成的图，翻页瞬时完成）
        try
            FL_demo();
            statusLbl.Text = '演示窗口已打开';
        catch err
            statusLbl.Text = ['演示启动失败：' err.message];
        end
    end

    function showImg(ax, X, ttxt)
        imagesc(ax, X);
        axis(ax, 'image');
        axis(ax, 'off');
        colormap(ax, 'gray');
        title(ax, ttxt, 'Interpreter', 'none');
    end

% ======================= 首次显示 =======================
if strcmpi(vis, 'on')
    drawnow;
    doDemo();
end

end
