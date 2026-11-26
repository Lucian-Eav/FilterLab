function fig = FL_spectrum_lesson(photo)
%FL_SPECTRUM_LESSON Interactive 2-D Fourier lesson for MATLAB R2020b+.
% fig = FL_spectrum_lesson() uses synthetic stripes. Pass a normalized 2-D
% or RGB preview to offer a read-only grayscale snapshot as a third source.
if nargin < 1, photo = []; end
if ~isdeployed, addpath(fullfile(fileparts(mfilename('fullpath')),'core')); end
paper = [.965 .973 .976]; ink = [.10 .17 .22]; quiet = [.25 .33 .38];
accent = [.03 .38 .45]; fontName = 'Microsoft YaHei UI';
names = {'1　找到直流与峰对','2　量出条纹频率','3　平移与相位','4　选择低通或高通','5　用复频谱还原'};
questions = {'为什么一张竖条纹图会在水平方向出现一对亮点？', ...
    '把周期数翻倍，两侧的峰会向哪里移动？','条纹平移了，为什么幅度谱还能保持原样？', ...
    '只让中心附近的频率通过，条纹还会留下吗？','保留全部复系数，逆变换能还原到什么精度？'};
directions = {'先找到中心的直流，再把「图像」改为横条纹。对照灰度变化的方向与两峰的连线。', ...
    '把「周期数」从 8 改成 16。比较明暗条纹间距和两峰到中心的距离，用下方读数核对。', ...
    '在「平移」中比较 0 和 8 像素。切换「中图」的相位与幅度，记录正频率峰的相位和位置。', ...
    '先预测截止频率 0.04 与 0.08 的结果，再依次试低通和高通。把「中图」切到通带掩膜，白区表示通过。', ...
    '先选「全通」查看最大误差，再试低通或高通。回到照片编辑器，可用「频域画笔」→「在频谱上绘制」→「查看照片 / 停止绘制」。'};
formulas = {'F = fftshift(fft2(I));    S = log1p(abs(F));    DC = sum(I(:));', ...
    'f = k/256;    T = 1/f;    F = fftshift(fft2(I));', ...
    'A = abs(F);    phi = angle(F);    Fshift = F .* exp(-2i*pi*fx*dx);', ...
    '[fx,fy] = meshgrid(Fx,Fy);    H = hypot(fx,fy) <= fc;    G = F .* H;', ...
    'F = fftshift(fft2(I));    G = F .* H;    J = real(ifft2(ifftshift(G)));'};
notes = {'把图像分别与各方向、各频率的正弦和余弦逐点相乘再求和，得到复系数。fftshift 把直流移到中心，直流等于像素之和。实值图像的幅度峰关于中心成对出现。', ...
    'k 表示 256 像素里的周期数。8 个周期对应 0.03125 cycles/pixel，间距 32 像素。频率坐标沿图像向右、向下为正。', ...
    '循环平移只改变相位。幅度表示成分强弱，相位决定它在空间中的位置。相位图隐藏幅度低于峰值约一亿分之一的频点。', ...
    '低通保留圆内与边界，高通保留圆外。理想硬截止可能让照片边缘出现振铃。高通图固定色阶 [−1, 1]，黑为负、灰为零、白为正。', ...
    '逆变换使用保留幅度和相位的复系数。log1p(abs(F)) 仅供观察。全通时差值只含数值舍入误差，滤波后差值也包含滤去的图像成分。'};
screen = get(groot,'ScreenSize');
w = min(1240,max(640,screen(3)-56)); h = min(816,max(460,screen(4)-108));
fig = uifigure('Name','二维傅里叶频谱课堂','Tag','SpectrumLesson','Color',paper, ...
    'Position',[screen(1)+max(8,(screen(3)-w)/2),screen(2)+max(32,(screen(4)-h)/2),w,h], ...
    'Visible','off','AutoResizeChildren','off');
try
    root = uigridlayout(fig,[7 1],'BackgroundColor',paper,'RowHeight',{36,68,'1x',66,58,72,25}, ...
        'Padding',[18 14 18 12],'RowSpacing',8,'Scrollable','on');
    nav = makeGrid(root,{'1x',76,220,76,126},{'1x'},paper);
    heading = makeLabel(nav,'二维频谱课堂',22,ink,'LessonTitle'); heading.FontWeight = 'bold';
    step = uidropdown(nav,'Items',names,'ItemsData',1:5,'Value',1,'FontName',fontName, ...
        'FontSize',14,'Tag','LessonStep','ValueChangedFcn',@stepChanged); step.Layout.Column = 3;
    previous = uibutton(nav,'Text','上一步','Tag','LessonPrevious','FontName',fontName, ...
        'ButtonPushedFcn',@(~,~)applyStep(step.Value-1)); previous.Layout.Column = 2;
    next = uibutton(nav,'Text','下一步','Tag','LessonNext','FontName',fontName, ...
        'ButtonPushedFcn',@(~,~)applyStep(step.Value+1)); next.Layout.Column = 4;
    restore = uibutton(nav,'Text','恢复本步演示','Tag','LessonRestore','FontName',fontName, ...
        'ButtonPushedFcn',@stepChanged); restore.Layout.Column = 5;
    guide = makeGrid(root,{'1x'},{29,'1x'},paper);
    question = makeLabel(guide,'',19,ink,'LessonQuestion'); question.FontWeight = 'bold';
    direction = makeLabel(guide,'',14,quiet,'LessonDirection'); direction.WordWrap = 'on';
    gallery = makeGrid(root,{'1x','1x','1x'},{'1x'},[1 1 1]); gallery.Padding = [6 5 6 3];
    [axInput,imgInput] = makePlot(gallery,'输入图像','LessonInput','x (像素)','y (像素)');
    [axSpec,imgSpec] = makePlot(gallery,'中心化频谱','LessonSpectrum','f_x (cycles/pixel)','f_y (cycles/pixel)');
    [axOutput,imgOutput] = makePlot(gallery,'逆变换结果','LessonOutput','x (像素)','y (像素)');
    peaks = line(axSpec,NaN,NaN,'LineStyle','none','Marker','o','MarkerSize',8, ...
        'Color',[.20 .76 .83],'LineWidth',1.1,'HitTest','off','Tag','LessonPeakMarkers');
    controls = makeGrid(root,{'1.2x','1x','1x','1x','1.2x','1.2x'},{22,32},paper);
    labels = {'图像','周期数 / 256 像素','平移 / 像素','滤波方式','截止 / cycles·pixel⁻¹','中图'};
    for col = 1:numel(labels)
        label = makeLabel(controls,labels{col},13,quiet,''); label.Layout.Row = 1; label.Layout.Column = col;
    end
    sources = {'竖条纹','横条纹'}; sourceValues = {'vertical','horizontal'};
    if ~isempty(photo), sources{end+1} = '当前照片（灰度）'; sourceValues{end+1} = 'photo'; end
    source = makeDrop(1,sources,sourceValues,'LessonSource');
    cycles = makeSpinner(2,[1 32],1,8,'LessonCycles');
    shift = makeSpinner(3,[-128 128],1,0,'LessonShift');
    filter = makeDrop(4,{'全通','低通','高通'},{'all','low','high'},'LessonFilter');
    cutoff = makeSpinner(5,[0 .5],.01,.04,'LessonCutoff');
    view = makeDrop(6,{'对数幅度','相位（弧度）','通带掩膜'},{'magnitude','phase','mask'},'LessonView');
    readout = makeGrid(root,{'1x'},{26,25},paper);
    observed = makeLabel(readout,'',14,accent,'LessonObserved'); observed.FontWeight = 'bold';
    metrics = makeLabel(readout,'',13,ink,'LessonMetrics');
    eqBox = makeGrid(root,{'1x'},{25,38},[1 1 1]); eqBox.Padding = [10 2 10 0];
    equation = makeLabel(eqBox,'',14,ink,'LessonFormula'); equation.FontName = 'Consolas';
    note = makeLabel(eqBox,'',13,quiet,'LessonNote'); note.WordWrap = 'on';
    if isempty(photo)
        footer = '本次使用内置条纹。打开照片后从编辑器进入，本课即可读取照片的灰度快照。';
    else
        footer = '当前照片为进入本课时的只读灰度快照，预览最长边 256 像素。课堂参数只影响此窗口。';
    end
    makeLabel(root,footer,12,quiet,'LessonSnapshotNote');
    fig.SizeChangedFcn = @(~,~)fitLayout();
    fitLayout(); applyStep(1); fig.Visible = 'on';
catch err
    delete(fig); rethrow(err);
end

    function stepChanged(~,~)
        applyStep(step.Value);
    end

    function fitLayout()
        % Fixed lower bounds keep the diagrams and text legible on small screens.
        root.ColumnWidth = {max(850,fig.Position(3)-44)};
        root.RowHeight{3} = max(230,fig.Position(4)-407);
    end

    function grid = makeGrid(parent,widths,heights,bg)
        grid = uigridlayout(parent,[numel(heights) numel(widths)],'Padding',[0 0 0 0], ...
            'ColumnWidth',widths,'RowHeight',heights,'ColumnSpacing',8,'RowSpacing',2,'BackgroundColor',bg);
    end

    function out = makeLabel(parent,text,sz,color,tag)
        out = uilabel(parent,'Text',text,'FontSize',sz,'FontName',fontName,'FontColor',color,'Tag',tag);
    end

    function out = makeDrop(column,items,values,tag)
        out = uidropdown(controls,'Items',items,'ItemsData',values,'Value',values{1}, ...
            'FontName',fontName,'FontSize',13,'Tag',tag,'ValueChangedFcn',@(~,~)refresh());
        out.Layout.Row = 2; out.Layout.Column = column;
    end

    function out = makeSpinner(column,limits,increment,value,tag)
        out = uispinner(controls,'Limits',limits,'Step',increment,'Value',value, ...
            'FontName',fontName,'FontSize',13,'Tag',tag,'ValueChangedFcn',@(~,~)refresh());
        out.Layout.Row = 2; out.Layout.Column = column;
    end

    function [ax,img] = makePlot(parent,caption,tag,xname,yname)
        ax = uiaxes(parent,'Tag',[tag 'Axes'],'FontName',fontName,'FontSize',11);
        ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
        img = image('Parent',ax,'CData',zeros(2),'CDataMapping','scaled','Tag',[tag 'Image'],'HitTest','off');
        ax.YDir = 'reverse'; ax.DataAspectRatio = [1 1 1]; ax.Box = 'on'; ax.CLim = [0 1];
        colormap(ax,gray(256)); title(ax,caption,'FontSize',15,'FontWeight','bold','Color',ink);
        xlabel(ax,xname); ylabel(ax,yname);
    end

    function applyStep(n)
        step.Value = n; source.Value = 'vertical'; cycles.Value = 8; shift.Value = 0;
        cutoff.Value = .04; filter.Value = 'all'; view.Value = 'magnitude';
        switch n
            case 3
                shift.Value = 8; view.Value = 'phase';
            case 4
                cycles.Value = 16; filter.Value = 'low';
            case 5
                if ~isempty(photo), source.Value = 'photo'; end
        end
        previous.Enable = onOff(n>1); next.Enable = onOff(n<numel(names));
        question.Text = questions{n}; direction.Text = directions{n};
        refresh();
    end

    function refresh()
        cycles.Value = round(cycles.Value); shift.Value = round(shift.Value);
        isPhoto = strcmp(source.Value,'photo'); isHigh = strcmp(filter.Value,'high');
        cycles.Enable = onOff(~isPhoto); cutoff.Enable = onOff(~strcmp(filter.Value,'all'));
        R = fl_spectrum_explore(source.Value,cycles.Value,shift.Value,filter.Value,cutoff.Value,photo);
        [nr,nc] = size(R.Input);
        showSpace(axInput,imgInput,R.Input,[0 1]);
        if isHigh
            outputScale = [-1 1]; axOutput.Title.String = '逆变换结果（灰色为零）';
        else
            outputScale = [0 1]; axOutput.Title.String = '逆变换结果（灰度 0–1）';
        end
        showSpace(axOutput,imgOutput,R.Output,outputScale);
        imgSpec.XData = [R.Fx(1) R.Fx(end)]; imgSpec.YData = [R.Fy(1) R.Fy(end)];
        imgSpec.AlphaData = 1; axSpec.Color = [1 1 1]; colormap(axSpec,gray(256));
        switch view.Value
            case 'magnitude'
                imgSpec.CData = R.Spectrum .* R.Mask;
                axSpec.CLim = [0 log1p(nr*nc)]; % |F| <= pixel count for 0..1 inputs.
                axSpec.Title.String = '通过的对数幅度';
            case 'phase'
                imgSpec.CData = R.Phase;
                minLog = log1p(1e-8*expm1(max(R.Spectrum(:))));
                imgSpec.AlphaData = double(R.Mask & R.Spectrum > minLog);
                axSpec.Color = [.88 .89 .90]; axSpec.CLim = [-pi pi]; colormap(axSpec,hsv(256));
                axSpec.Title.String = '通过的相位（灰底无读数）';
            case 'mask'
                imgSpec.CData = double(R.Mask); axSpec.CLim = [0 1];
                axSpec.Title.String = '掩膜（白色通过）';
        end
        zoomPeaks = ~isPhoto && ~strcmp(view.Value,'mask');
        if zoomPeaks
            bounds = [-.15 .15]; ticks = [-.1 0 .1];
        else
            bounds = [-.5 .5]; ticks = [-.5 -.25 0 .25 .5];
        end
        axSpec.XLim = bounds; axSpec.YLim = bounds; axSpec.XTick = ticks; axSpec.YTick = ticks;
        peaks.XData = NaN; peaks.YData = NaN;
        if isPhoto
            observed.Text = sprintf('照片输入为 %d × %d 像素（高 × 宽）　|　中心直流除以像素数 = 平均灰度 %.4f', ...
                nr,nc,mean(R.Input(:)));
        else
            [~,ix] = min(abs(R.Fx)); [~,iy] = min(abs(R.Fy));
            k = cycles.Value;
            if strcmp(source.Value,'vertical'), ix = ix+k; else, iy = iy+k; end
            fx = R.Fx(ix); fy = R.Fy(iy);
            if R.Mask(iy,ix) && zoomPeaks, peaks.XData = [-fx fx]; peaks.YData = [-fy fy]; end
            if step.Value == 3
                phaseRad = R.Phase(iy,ix);
                phaseDelta = atan2(sin(phaseRad+pi/2),cos(phaseRad+pi/2));
                observed.Text = sprintf(['输入正峰 (%.4f, %.4f) 的相位 %.3f rad' ...
                    '　|　相对未移条纹的相位变化 %+.3f rad（折回 ±π）'],fx,fy,phaseRad,phaseDelta);
            else
                if R.Mask(iy,ix), passText = '通过'; else, passText = '被截去'; end
                observed.Text = sprintf(['输入两峰位于 ±(%.4f, %.4f) cycles/pixel' ...
                    '　|　空间周期 %.2f 像素　|　当前这对峰%s'],fx,fy,256/k,passText);
            end
        end
        metrics.Text = sprintf('平均灰度 %.4f → %.4f　|　保留频谱能量 %.2f%%　|　最大像素差 max|J−I| = %.3g', ...
            mean(R.Input(:)),mean(R.Output(:)),100*R.RetainedEnergy,R.MaxError);
        equation.Text = formulas{step.Value}; note.Text = notes{step.Value};
        if step.Value == 3 && strcmp(source.Value,'horizontal')
            equation.Text = 'A = abs(F);    phi = angle(F);    Fshift = F .* exp(-2i*pi*fy*dy);';
        elseif step.Value == 4 && isHigh
            equation.Text = '[fx,fy] = meshgrid(Fx,Fy);    H = hypot(fx,fy) > fc;    G = F .* H;';
        elseif step.Value == 4 && strcmp(filter.Value,'all')
            equation.Text = 'H = true(size(F));    G = F .* H;';
        end
        setappdata(fig,'LessonResult',R);
    end
end

function showSpace(ax,img,data,limits)
% Keep physical output values, using CLim to clip only the display.
[rows,cols] = size(data);
img.XData = [1 cols]; img.YData = [1 rows]; img.CData = data;
ax.XLim = [.5 cols+.5]; ax.YLim = [.5 rows+.5]; ax.CLim = limits;
end

function value = onOff(test)
if test, value = 'on'; else, value = 'off'; end
end
