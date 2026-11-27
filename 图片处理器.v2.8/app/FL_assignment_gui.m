function fig=FL_assignment_gui(varargin)
%FL_ASSIGNMENT_GUI Exact original assignment workspace and one-click report.
root=fileparts(mfilename('fullpath')); if ~isdeployed, addpath(fullfile(root,'core')); end
paths=fl_app_paths();
theme=fl_ui_theme();
p=inputParser; p.addParameter('Visible','on'); p.addParameter('DataFile',''); p.addParameter('Parent',[]); p.parse(varargin{:});
source=char(p.Results.DataFile);
if isempty(source), source=paths.Sample; end
R=[]; busy=false; output='';
embedded=~isempty(p.Results.Parent);
if embedded
    fig=uipanel(p.Results.Parent,'BorderType','none','Tag','AssignmentWorkspace'); host=ancestor(fig,'figure');
else
    fig=uifigure('Name','FilterLab · 题目实验（六问）','Position',[80 60 1380 900], ...
        'Color',theme.Paper,'Visible','off','Tag','AssignmentFigure');
    host=fig; fig.CloseRequestFcn=@(~,~)closeWindow();
end
g=uigridlayout(fig,[4 1],'BackgroundColor',theme.Paper,'RowHeight',{55,40,'1x',32},'Padding',[16 12 16 12]);
title=uilabel(g,'Text',{'基于一维滤波器的图像处理','原题参数 · 原始系数 · 因果行列滤波 · 六问报告'},'FontSize',17,'FontColor',theme.Ink);
bar=uigridlayout(g,[1 5],'BackgroundColor',theme.Paper,'ColumnWidth',{130,100,'1x',110,110},'Padding',[0 0 0 0]);
runBtn=uibutton(bar,'Text','运行六问并导出','Tag','AssignmentRun','BackgroundColor',theme.Accent,'FontColor',theme.White,'ButtonPushedFcn',@(~,~)uiRun(@()runExperiment('')));
loadBtn=uibutton(bar,'Text','选择题目数据','ButtonPushedFcn',@(~,~)selectSource());
sourceLabel=uilabel(bar,'Text',source,'Tooltip',source); sourceLabel.WordWrap='on';
folderBtn=uibutton(bar,'Text','导出位置…','ButtonPushedFcn',@(~,~)chooseFolder());
reportBtn=uibutton(bar,'Text','打开报告','Enable','off','Tag','AssignmentReport','ButtonPushedFcn',@(~,~)openReport());
tabs=uitabgroup(g); questionTab=uitab(tabs,'Title','逐题结果'); metricTab=uitab(tabs,'Title','指标与口径'); coeffTab=uitab(tabs,'Title','系数与复现');
qg=uigridlayout(questionTab,[1 2],'BackgroundColor',theme.Paper,'ColumnWidth',{310,'1x'},'Padding',[10 10 10 10]);
left=uigridlayout(qg,[3 1],'BackgroundColor',theme.Paper,'RowHeight',{38,'1x',100},'Padding',[0 0 0 0]);
question=uidropdown(left,'Items',{'1 · 数据与滤波器','2 · 幅度、相位、群延迟','3 · 阶跃响应与超调','4 · 原图行列滤波','5 · 轮廓与对称性','6 · 含噪滤波与比较'}, ...
    'ItemsData',1:6,'Value',1,'Tag','AssignmentQuestion','ValueChangedFcn',@(~,~)showQuestion());
answer=uitextarea(left,'Editable','off','Value',{'点击“运行六问并导出”。所有数值和结论由当前数据实际计算。'},'FontSize',14,'Tag','AssignmentAnswer');
uilabel(left,'Text',{'Wc=0.4；阶数 10 / 4 / 12','FIR 频带 [0 .36 .44 1]','不对 FIR 直流归一化，不对 xn 裁切。','备用设计会明确标注，不冒充原生函数。'},'WordWrap','on');
ax=uiaxes(qg,'XTick',[],'YTick',[],'Tag','AssignmentAxes'); ax.Toolbar.Visible='off'; ax.Interactions=[];
mg=uigridlayout(metricTab,[2 1],'BackgroundColor',theme.Paper,'RowHeight',{'1x',150});
metrics=uitable(mg,'Tag','AssignmentMetrics','ColumnName',{'滤波器','DC','绝对超调','相对超调','行位移','列位移','全图MSE','同域补偿MSE','增益校正MSE','对称误差'});
metricNote=uitextarea(mg,'Editable','off','Value',{'计算后显示指标定义。'},'FontSize',13);
cg=uigridlayout(coeffTab,[1 1],'BackgroundColor',theme.Paper); coeff=uitextarea(cg,'Editable','off','FontName','Consolas','FontSize',13,'Value',{'计算后显示原始系数与来源。'});
status=uilabel(g,'Text','准备就绪 · 导出包含 HTML、六张图、MAT 原始结果和独立复现脚本','Tag','AssignmentStatus');
actions=struct('Run',@runExperiment,'SetDataFile',@setDataFile,'SetQuestion',@setQuestion,'OpenReport',@openReport);
setappdata(fig,'AssignmentActions',actions); publish(); if ~embedded, fig.Visible=p.Results.Visible; end
    function out=runExperiment(folder)
        if nargin<1, folder=''; end
        if busy, error('FL_assignment_gui:busy','正在计算。'); end
        busy=true; set([runBtn loadBtn folderBtn reportBtn],'Enable','off'); status.Text='正在计算原题六问并导出证据…'; publish(); drawnow;
        done=onCleanup(@finish);
        if isempty(folder), folder=output; end
        next=FL_assignment('DataFile',source,'OutputDir',folder);
        R=next; out=R; showQuestion();
        data=cell(3,10); lines={};
        for j=1:3
            f=R.Filters(j); data(j,:)={f.Name,f.DCGain,f.Overshoot,f.RelativeOvershoot,f.Shift(1),f.Shift(2),f.RawMSE,f.AlignedMSE,f.GainCorrectedMSE,f.SymmetryError};
            lines=[lines;{f.Name;f.Source;['b = ' mat2str(f.B,17)];['a = ' mat2str(f.A,17)];''}]; %#ok<AGROW>
        end
        metrics.Data=data; coeff.Value=lines;
        metricNote.Value={sprintf('共同参考区域：行 1～%d、列 1～%d。补偿使用索引截取，不循环移位。',R.CommonRows(end),R.CommonCols(end)); ...
            '原坐标 MSE 包含位移、幅度误差、噪声；同域 MSE 仅补偿延迟；增益校正是额外诊断。'; ...
            '相对超调=绝对超调/DC；对称误差使用补偿后、校正增益后的有效镜像像素对。'; ...
            '仅适用于此数据与指定滤波器，不是自然照片的画质评分。'};
        status.Text=['已完成六问：' R.OutputDir]; publish();
    end
    function finish()
        if ~isvalid(fig), return; end
        busy=false; set([runBtn loadBtn folderBtn],'Enable','on');
        if ~isempty(R), reportBtn.Enable='on'; end
        publish();
    end
    function showQuestion()
        if isempty(R), return; end
        k=question.Value; answer.Value={R.Answers{k}};
        image(ax,imread(fullfile(R.OutputDir,R.Figures{k}))); axis(ax,'image'); ax.XTick=[]; ax.YTick=[];
    end
    function setQuestion(k)
        validateattributes(k,{'numeric'},{'scalar','integer','>=',1,'<=',6}); question.Value=k; showQuestion();
    end
    function setDataFile(path)
        if busy, error('FL_assignment_gui:busy','正在计算。'); end
        if exist(path,'file')~=2, error('FL_assignment_gui:data','找不到题目 MAT 数据。'); end
        source=char(path); sourceLabel.Text=source; sourceLabel.Tooltip=source;
        R=[]; reportBtn.Enable='off'; metrics.Data={}; coeff.Value={''}; cla(ax);
        answer.Value={'数据已更换，请重新运行六问。'}; status.Text='数据已更换 · 等待运行'; publish();
    end
    function selectSource()
        [name,path]=uigetfile('*.mat','选择包含 x 与 xn 的题目数据');
        if ~isequal(name,0), uiRun(@()setDataFile(fullfile(path,name))); end
    end
    function chooseFolder()
        start=paths.Output; if exist(start,'dir')~=7, start=prefdir; end
        path=uigetdir(start,'选择空的实验导出文件夹（已有结果不会覆盖）');
        if ~isequal(path,0), output=path; status.Text=['下次导出：' output]; end
    end
    function openReport()
        if ~isempty(R), web(fullfile(R.OutputDir,'report.html'),'-browser'); end
    end
    function uiRun(f)
        try, f(); catch ex
            status.Text=['未完成：' ex.message];
            if strcmp(host.Visible,'on'), uialert(host,ex.message,'题目实验'); end
        end
    end
    function publish()
        setappdata(fig,'AssignmentState',struct('Result',R,'Source',source,'Busy',busy,'OutputDir',output));
    end
    function closeWindow()
        if ~busy, delete(fig); end
    end
end
