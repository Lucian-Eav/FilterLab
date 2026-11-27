function view = FL_sampling_stripes(parent)
%FL_SAMPLING_STRIPES Embedded stripe experiment for an empty sampling tab.
% api = getappdata(parent,'StripesActions'); api.SetStep(2);
% api.SetFrequencies([24 40]); data = api.GetState();
if ~isdeployed, addpath(fullfile(fileparts(mfilename('fullpath')),'core')); end
s = fl_stripe_samples();
theme = fl_ui_theme(); paper = theme.Paper; white = theme.White; ink = theme.Ink;
% Series also differ by stroke and marker so coincident peaks stay legible.
colors = [theme.Accent; theme.Ink]; font = 'Microsoft YaHei UI';
view = uigridlayout(parent,[1 1],'Padding',[0 0 0 0],'BackgroundColor',paper,'Tag','StripesView');
frame = uipanel(view,'BorderType','none','BackgroundColor',paper,'AutoResizeChildren','off');
root = uigridlayout(frame,[4 1],'Scrollable','on','ColumnWidth',{'1x'}, ...
    'Padding',[12 8 12 6],'RowSpacing',6,'BackgroundColor',paper);
controls = uigridlayout(root,[1 7],'ColumnWidth',{72,68,48,50,48,50,'1x'}, ...
    'RowHeight',{'1x'},'ColumnSpacing',5,'Padding',[0 0 0 0],'BackgroundColor',paper);
makeLabel(controls,'采样步长',ink);
stepBox = uidropdown(controls,'Items',arrayfun(@(d)sprintf('%d px',d),s.Steps,'UniformOutput',false), ...
    'ItemsData',s.Steps,'Value',s.Step,'Tag','StripesStep','FontName',font,'ValueChangedFcn',@changed);
frequencyBox = gobjects(1,2);
for k = 1:2
    makeLabel(controls,['频率 ' char(64+k)],colors(k,:));
    frequencyBox(k) = uieditfield(controls,'numeric','Limits',[0 128],'RoundFractionalValues','on', ...
        'Value',s.Frequencies(k),'Tag',['StripesFrequency' char(64+k)],'FontName',font, ...
        'Tooltip','周期 / 原图宽','ValueChangedFcn',@changed);
end
makeLabel(controls,'周期 / 原图宽',ink);
rasters = uigridlayout(root,[3 3],'Tag','StripesRasters','RowHeight',{23,'1x','1x'}, ...
    'ColumnWidth',{58,'1x','1x'},'Padding',[8 5 8 6],'RowSpacing',4,'ColumnSpacing',8,'BackgroundColor',white);
originalLabel = makeLabel(rasters,'原图（256 列）',ink); place(originalLabel,1,2);
resultLabel = makeLabel(rasters,'',ink); place(resultLabel,1,3);
rowLabels = gobjects(1,2); rasterImage = gobjects(2,2);
% Four stripe images share one normalized canvas; each retains its actual
% 2-by-N sample matrix and spans the same width regardless of sample count.
canvas = uiaxes(rasters,'Visible','off','XTick',[],'YTick',[],'YDir','reverse', ...
    'XLim',[0 2.04],'YLim',[0 2.08],'CLim',[0 1]); place(canvas,[2 3],[2 3]);
canvas.Toolbar.Visible = 'off'; disableDefaultInteractivity(canvas);
canvas.PositionConstraint = 'innerposition'; canvas.LooseInset = [0 0 0 0];
colormap(canvas,gray(256));
for k = 1:2
    rowLabels(k) = makeLabel(rasters,'',colors(k,:)); place(rowLabels(k),k+1,1);
    rowLabels(k).FontWeight = 'bold';
    for j = 1:2
        rasterImage(k,j) = image('Parent',canvas,'CData',zeros(2,2),'CDataMapping','scaled', ...
            'YData',(k-1)*1.08+[.25 .75],'Tag',sprintf('StripesRaster%d%d',k,j),'HitTest','off');
    end
end
chartGrid = uigridlayout(root,[1 2],'Padding',[0 0 0 0],'ColumnSpacing',8, ...
    'RowSpacing',6,'BackgroundColor',paper);
profile = chart(chartGrid,'StripesProfile','原图剖面与采样点','原图横坐标（px）','亮度');
spectrum = chart(chartGrid,'StripesSpectrum','采样后的单边频谱（扣除 0.5 灰底）','空间频率（周期 / 原图宽）','幅度');
profile.YLim = [-.07 1.07]; profile.YTick = [0 .5 1];
spectrum.YLim = [-.03 .57]; spectrum.YTick = [0 .25 .5];
curves = gobjects(1,2); marks = gobjects(1,2); spectra = gobjects(1,2); peakMarks = gobjects(1,2);
styles = {'-','--'}; symbols = {'o','x'}; names = {'A','B'};
for k = 1:2
    curves(k) = line(profile,NaN,NaN,'Color',colors(k,:),'LineStyle',styles{k}, ...
        'LineWidth',1.35,'Tag',['StripesCurve' names{k}]);
    marks(k) = line(profile,NaN,NaN,'Color',colors(k,:),'LineStyle','none', ...
        'Marker',symbols{k},'MarkerSize',8,'LineWidth',1.4,'Tag',['StripesSamples' names{k}]);
    % The wide solid trace remains visible behind a coincident dashed one.
    spectra(k) = line(spectrum,NaN,NaN,'Color',colors(k,:),'LineStyle',styles{k}, ...
        'LineWidth',3.8-1.25*k,'Tag',['StripesFFT' names{k}]);
    peakMarks(k) = line(spectrum,NaN,NaN,'Color',colors(k,:),'LineStyle','none', ...
        'Marker',symbols{k},'MarkerSize',9,'LineWidth',1.5,'Tag',['StripesPeak' names{k}]);
end
status = makeLabel(root,'',ink); status.Tag = 'StripesStatus'; status.WordWrap = 'on';
status.Tooltip = '剖面显示原图左段，频谱使用整幅的全部样本。单边幅度以亮度 0.5 为基准，保留折叠到零频的分量。';
lastStacked = []; lastHeights = []; lastFrequencies = [NaN NaN];
api = struct('SetStep',@setStep,'SetFrequencies',@setFrequencies,'GetState',@getState);
render(); fitView(); frame.SizeChangedFcn = @(~,~)fitView();
setappdata(parent,'StripesActions',api); setappdata(view,'StripesActions',api);

    function label = makeLabel(container,str,color)
        label = uilabel(container,'Text',str,'FontName',font,'FontColor',color,'FontSize',13);
    end
    function ax = chart(container,tag,caption,xname,yname)
        ax = uiaxes(container,'FontName',font,'FontSize',11,'Color',paper,'Tag',tag);
        ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
        ax.XColor = theme.Muted; ax.YColor = theme.Muted; ax.GridColor = theme.Rule;
        ax.XGrid = 'on'; ax.YGrid = 'on'; ax.Box = 'on';
        title(ax,caption,'FontSize',14,'FontName',font,'Color',ink);
        xlabel(ax,xname,'FontName',font); ylabel(ax,yname,'FontName',font);
    end
    function fitView()
        sz = frame.Position(3:4);
        % A numeric minimum gives the scrollable grid usable content at
        % short window heights. Narrow windows stack the two plots.
        rasterHeight = max(116,min(240,round(.27*sz(2))));
        stacked = sz(1) < 730;
        if ~isequal(stacked,lastStacked)
            if stacked
                chartGrid.RowHeight = {'1x','1x'};
                place(spectrum,2,1); chartGrid.ColumnWidth = {'1x'};
            else
                chartGrid.ColumnWidth = {'1x','1x'};
                place(spectrum,1,2); chartGrid.RowHeight = {'1x'};
            end
            lastStacked = stacked;
        end
        if stacked, minCharts = 350; else, minCharts = 190; end
        heights = [32,rasterHeight,max(minCharts,sz(2)-rasterHeight-110),42];
        if ~isequal(heights,lastHeights)
            root.RowHeight = num2cell(heights); lastHeights = heights;
        end
    end
    function changed(~,~)
        s = fl_stripe_samples(stepBox.Value,[frequencyBox(1).Value frequencyBox(2).Value]);
        render();
    end
    function setStep(value)
        s = fl_stripe_samples(value,s.Frequencies); stepBox.Value = s.Step; render();
    end
    function setFrequencies(value)
        s = fl_stripe_samples(s.Step,value);
        frequencyBox(1).Value = s.Frequencies(1); frequencyBox(2).Value = s.Frequencies(2); render();
    end
    function data = getState()
        data = s;
    end
    function render()
        resultLabel.Text = sprintf('抽取后（%d 列，按原宽显示）',s.Count);
        for i = 1:2
            if s.Frequencies(i)~=lastFrequencies(i)
                rowLabels(i).Text = ['条纹 ' names{i}];
                row = s.Original(i,:); dx = .5/numel(row);
                set(rasterImage(i,1),'CData',[row;row],'XData',[dx 1-dx]);
                set(curves(i),'XData',s.X,'YData',row);
            end
            row = s.Samples(i,:); dx = .5/numel(row);
            set(rasterImage(i,2),'CData',[row;row],'XData',1.04+[dx 1-dx]);
            set(marks(i),'XData',s.SampleX,'YData',s.Samples(i,:));
            set(spectra(i),'XData',s.Bins,'YData',s.Amplitude(i,:));
            p = s.Peaks(i); set(peakMarks(i),'XData',p,'YData',s.Amplitude(i,p+1));
        end
        profile.XLim = [0 min(s.Width-1,max(32,4*s.Step))];
        spectrum.XLim = [-.025*s.Nyquist 1.025*s.Nyquist];
        spectrum.XTick = unique([0:2^max(0,round(log2(s.Nyquist/4))):s.Nyquist s.Nyquist]);
        if s.MaxDifference < 1e-12, relation = '两组采样点重合'; else, relation = '两组采样点不同'; end
        status.Text = sprintf('%s。单边 FFT 峰值：A ○ %d，B × %d；奈奎斯特频率 %g 周期/原图宽。', ...
            relation,s.Peaks(1),s.Peaks(2),s.Nyquist);
        lastFrequencies = s.Frequencies;
    end
end

function place(control,row,column)
control.Layout.Row = row; control.Layout.Column = column;
end
