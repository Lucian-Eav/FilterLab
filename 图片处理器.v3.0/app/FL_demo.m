function out = FL_demo(varargin)
%FL_DEMO  成果演示界面：一页一张图 + 讲解要点，适合投影演示。
%
%   FL_DEMO()                     打开演示窗口
%   FL_DEMO('Visible','off')      无头构造（冒烟测试用）
%   FL_DEMO('Regenerate',true)    打开前先重跑一遍分析、刷新图片
%
%   页面内容全部来自 output/ 下已生成的 PNG（fig1…fig7、fig9_innovation），
%   演示时不再做计算，翻页是瞬时的。图由 FL_MAIN('demo') 生成。
%
%   键盘：← 上一页 / → 下一页 / 空格 自动播放开关 / Esc 关闭
%
%   见 also FL_GUI, FL_MAIN, FL_INNOV.

here = fileparts(mfilename('fullpath'));
opt = struct('Visible', 'on', 'Regenerate', false, 'FigDir', fullfile(here, 'output'));
for k = 1:2:numel(varargin)
    opt.(varargin{k}) = varargin{k+1};
end
if ~exist(opt.FigDir, 'dir'), mkdir(opt.FigDir); end

if opt.Regenerate
    fprintf('重新生成分析图…\n');
    evalc("FL_main('demo','Visible','off')");
end

P = local_pages();
cur = 1;
tm = [];

fig = uifigure('Name', '成果演示 · 图像可分离滤波与相位失真分析软件 V1.0', ...
    'Position', [60 60 1400 860], 'Color', [1 1 1], ...
    'Visible', opt.Visible);

GL = uigridlayout(fig, [1 2]);
GL.ColumnWidth = {300, '1x'};
GL.Padding = [10 10 10 10];
GL.ColumnSpacing = 10;

LB = uilistbox(GL, 'Items', {P.title}, 'Value', P(1).title, ...
    'FontSize', 12, 'ValueChangedFcn', @(~, ~) goList());

RG = uigridlayout(GL, [3 1]);
RG.RowHeight = {'1x', 158, 40};
RG.RowSpacing = 8;

ax = uiaxes(RG);
ax.XTick = []; ax.YTick = [];
ax.Toolbar.Visible = 'off';
ax.Box = 'on';
ax.Color = [1 1 1];

tx = uitextarea(RG, 'Editable', 'off', 'FontSize', 13, ...
    'FontName', 'Microsoft YaHei', 'Value', {''});

BG = uigridlayout(RG, [1 6]);
BG.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1.4x'};
bPrev = uibutton(BG, 'Text', '◀ 上一页', 'ButtonPushedFcn', @(~, ~) step(-1));
bNext = uibutton(BG, 'Text', '下一页 ▶', 'ButtonPushedFcn', @(~, ~) step(1));
bAuto = uibutton(BG, 'Text', '自动播放', 'ButtonPushedFcn', @(~, ~) toggleAuto());
bSave = uibutton(BG, 'Text', '导出当前页', 'ButtonPushedFcn', @(~, ~) savePage());
bGen  = uibutton(BG, 'Text', '重新生成', 'ButtonPushedFcn', @(~, ~) regen());
bInfo = uibutton(BG, 'Text', '共 0 页', 'Enable', 'off');

fig.KeyPressFcn = @(~, e) onKey(e);
fig.CloseRequestFcn = @(~, ~) onClose();

show(1);
bInfo.Text = sprintf('第 %d / %d 页   ← → 翻页', cur, numel(P));

if nargout > 0
    out = struct('Figure', fig, 'Pages', P);
end
if strcmpi(opt.Visible, 'off')
    pause(0.2);
    onClose();
    out = struct('Figure', [], 'Pages', P, 'Headless', true);
end

% ======================= 回调 =======================
    function goList()
        idx = find(strcmp({P.title}, LB.Value), 1);
        if ~isempty(idx), show(idx); end
    end

    function step(d)
        show(mod(cur - 1 + d, numel(P)) + 1);
    end

    function show(idx)
        cur = idx;
        tx.Value = P(idx).text;
        LB.Value = P(idx).title;
        bInfo.Text = sprintf('第 %d / %d 页   ← → 翻页', cur, numel(P));
        drawnow limitrate;

        if isempty(P(idx).img)                  % 封面页：不读图，直接写字
            cla(ax);
            ax.XLim = [0 1]; ax.YLim = [0 1];
            text(ax, 0.5, 0.66, '图像可分离滤波与相位失真分析软件 V1.0', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 20, 'FontWeight', 'bold', 'Interpreter', 'none');
            text(ax, 0.5, 0.55, '成果演示', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 16, 'Interpreter', 'none');
            text(ax, 0.5, 0.44, '设计 → 相位 → 超调 → 二维结果 → 对称性 → 去噪 → 零相位 → 创新模块', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 12, 'Color', [0.35 0.35 0.35], 'Interpreter', 'none');
            text(ax, 0.5, 0.36, '按 → 翻页，空格自动播放', ...
                'Units', 'normalized', 'HorizontalAlignment', 'center', ...
                'FontSize', 11, 'Color', [0.5 0.5 0.5], 'Interpreter', 'none');
            axis(ax, 'off'); ax.Box = 'on';
            ax.Title.String = P(idx).title;
            ax.Title.FontSize = 14;
            return
        end

        f = fullfile(opt.FigDir, P(idx).img);
        if ~exist(f, 'file')
            cla(ax);
            ax.Title.String = sprintf('缺少 %s，请点「重新生成」', P(idx).img);
            return
        end
        [im, cm] = imread(f);
        if ~isempty(cm)
            im = local_rgb(im, cm);
        end
        cla(ax);
        image(ax, im);
        axis(ax, 'image'); axis(ax, 'off');
        ax.Title.String = P(idx).title;
        ax.Title.FontSize = 14;
    end

    function toggleAuto()
        if isempty(tm) || ~isvalid(tm)
            tm = timer('ExecutionMode', 'fixedRate', 'Period', 6, ...
                'TimerFcn', @(~, ~) autoStep(), 'BusyMode', 'drop');
            start(tm);
            bAuto.Text = '停止播放';
        else
            stop(tm); delete(tm); tm = [];
            bAuto.Text = '自动播放';
        end
    end

    function autoStep()
        try
            if isvalid(fig), step(1); end
        catch
        end
    end

    function regen()
        bInfo.Text = '正在重新生成，请稍候…';
        drawnow;
        try
            evalc("FL_main('demo','Visible','off')");
            show(cur);
            bInfo.Text = sprintf('已刷新 · 第 %d / %d 页', cur, numel(P));
        catch err
            bInfo.Text = ['生成失败：' err.message];
        end
    end

    function savePage()
        f = fullfile(opt.FigDir, P(cur).img);
        if ~exist(f, 'file'), return; end
        [n, p] = uiputfile({'*.png', 'PNG 图片'}, '导出当前页', ...
            fullfile(opt.FigDir, P(cur).img));
        if isequal(n, 0), return; end
        copyfile(f, fullfile(p, n));
        bInfo.Text = ['已导出：' n];
    end

    function onKey(e)
        switch e.Key
            case 'leftarrow',  step(-1);
            case 'rightarrow', step(1);
            case 'space',      toggleAuto();
            case 'escape',     onClose();
        end
    end

    function onClose()
        try
            if ~isempty(tm) && isvalid(tm), stop(tm); delete(tm); end
        catch
        end
        try
            if isvalid(fig), delete(fig); end
        catch
        end
    end
end

% ======================= 页面定义 =======================
function P = local_pages()

P = struct('title', {}, 'img', {}, 'text', {});

P(1).title = '00  封面';
P(1).img   = '';
P(1).text  = {
    '图像可分离滤波与相位失真分析软件 V1.0'
    ''
    '把「一维滤波器参数」到「二维图像效果」的因果链量化出来：'
    '不只是出图，而是回答"糊了/振了/偏了，是哪一段幅频、哪一段相位造成的，各占多少"。'
    ''
    '规模：24 个源文件、2524 行；零工具箱依赖（自带 butter / remez / filtfilt 实现）'
    '自检：6 项全部通过（系数、等纹波、线性相位、直流归一化、平移估计、可分离一致性）'
    '演示顺序：设计 → 相位 → 超调 → 二维结果 → 对称性 → 去噪 → 零相位 → 三个创新模块'};

P(2).title = '01  三个滤波器的幅频与相位';
P(2).img   = 'fig1_amp_phase.png';
P(2).text  = {
    'b1 = butter(10, 0.4)：IIR，11 个系数'
    'b2 = remez(4, …)：FIR，5 抽头，直流增益 1.3721'
    'b3 = remez(12, …)：FIR，13 抽头，直流增益 0.8497'
    ''
    '易错点：remez 的 n 是阶数，系数长度是 n+1，弄错后面全错。'
    'b2 只有 5 抽头 + 0.08π 过渡带，阻带只能到 −8.5 dB（δ=0.374），这是参数决定的硬约束。'};

P(3).title = '02  群延迟：谁才是线性相位';
P(3).img   = 'fig2_group_delay.png';
P(3).text  = {
    'b2 群延迟恒为 2.000（标准差 3.3e−16）→ 线性相位'
    'b3 群延迟恒为 6.000（标准差 1.5e−15）→ 线性相位'
    'b1 群延迟 5.204 ± 1.746（随频率变）→ 非线性相位'
    ''
    '坑：b1 的分子系数恰好是回文多项式，若只查系数对称性会误判成线性相位。'
    'IIR 的相位由分母极点决定，分子的对称性没有判别意义。'};

P(4).title = '03  阶跃超调：最大平坦 ≠ 无超调';
P(4).img   = 'fig3_step.png';
P(4).text  = {
    'b1  21.66%   >   b3  15.02%   >   b2  0.00%'
    ''
    '巴特沃斯是"最大平坦"——那是幅频性质，和阶跃超调是两回事。'
    'b2 超调为 0 可以事先推出来：系数全正 ⇒ 阶跃响应单调 ⇒ 不可能过冲。'};

P(5).title = '04  二维可分离滤波的结果';
P(5).img   = 'fig4_filtered.png';
P(5).text  = {
    '行、列各滤一次：Y = A · X · Aᵀ'
    '动态范围  b1 [−0.808, 1.126]   b2 [0.000, 0.988]   b3 [−0.571, 1.294]'
    ''
    '比较时务必统一色标（clim 固定）并标出动态范围——'
    '滤波后取值不再是 {0,1}，各图自动缩放会让比较彻底失真。'
    '注意 b2 的直流增益是 1.3721，不归一化就比幅度是在比两把不同的尺子。'};

P(6).title = '05  失真与对称性';
P(6).img   = 'fig5_symmetry.png';
P(6).text  = {
    '原图 ‖X − Xᵀ‖ = 0（沿主对角对称）'
    'Y = A·X·Aᵀ ⇒ Y 恒对称，与是否线性相位无关（实测 1e−15 量级）'
    ''
    '真正被破坏的是左右镜像。用交换子衡量（对平移不敏感）：'
    'max | filter(fliplr(X)) − fliplr(filter(X)) |'
    '    b1  4.578e−01      b2  0.000      b3  1.110e−16'
    ''
    '"非线性相位破坏对称性"必须限定为镜像意义，主对角对称性严格保持。'};

P(7).title = '06  加噪去噪：必须先配准';
P(7).img   = 'fig6_denoise.png';
P(7).text  = {
    '平移量  b1 +5 / b2 +2 / b3 +6 像素（等于各自群延迟）'
    '不配准直接算 PSNR 只有 5.42 / 7.79 / 5.45 dB；配准后 13.00 / 13.97 / 13.96'
    '不滤波 14.16 dB —— 三者整体都不如不滤波（图上只有 3 像素细线，低通糊边的代价更大）'
    ''
    '平坦区残留 RMS   b1 0.1140   b2 0.0461   b3 0.1129'
    '边缘 MAE         b1 0.2098   b2 0.2225   b3 0.1844'
    '⇒ b2 降噪最强但边缘最糊，b3 边缘最好但降噪最弱。单一 PSNR 说不清这件事。'};

P(8).title = '07  零相位对照：不一定更好';
P(8).img   = 'fig7_zerophase.png';
P(8).text  = {
    'filtfilt 把相位归零，但等效幅频变成 |H|²，带宽被再削一次'
    ''
    'b1 零相位  15.189  ← 唯一超过不滤波（14.162）'
    'b2 零相位  12.992'
    'b3 零相位  11.123'
    ''
    '所以"零相位一定更好"是错的：只看相位不看幅频，结论会反过来。'};

P(9).title = '08  三个创新模块';
P(9).img   = 'fig9_innovation.png';
P(9).text  = {
    'A 相位隔离：对同一幅频做零点反射，造出"幅频完全一样、只有相位不同"的族'
    '    幅频最大偏差 3.44e−15；位移可由脉冲响应一阶矩解析预测，误差 < 0.2 像素'
    'B 带弃权的决策器：把误差拆成 ‖(L−I)x‖² + σ²‖L‖²_F，先判"该不该滤"'
    '    模型对实测 0.21 dB；σ 盲估 0.2066（真值 0.20）；σ 交叉点 0.17'
    'C 故障注入自检：9 个变异，6 个有效全检出、3 个代数等价零误报（等价变异不计分母）'
    ''
    '三条都不是"多做个界面"，而是让结论可被证伪。'};
end

% ======================= 工具 =======================
function rgb = local_rgb(idx, cmap)
% 不依赖工具箱的 ind2rgb
idx = double(idx) + 1;
[h, w] = size(idx);
rgb = uint8(reshape(cmap(idx(:), :), [h, w 3]) * 255);
end
