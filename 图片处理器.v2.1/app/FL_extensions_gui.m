function fig=FL_extensions_gui(varargin)
%FL_EXTENSIONS_GUI Standalone or embedded engineering experiment workspace.
root=fileparts(mfilename('fullpath')); if ~isdeployed, addpath(fullfile(root,'core')); end
p=inputParser; p.addParameter('Parent',[]); p.addParameter('Visible','on');
p.addParameter('OutputDir',''); p.parse(varargin{:});
visible=validatestring(p.Results.Visible,{'on','off'});
embedded=~isempty(p.Results.Parent);
if embedded
    fig=uipanel(p.Results.Parent,'BorderType','none','Tag','ExtensionsWorkspace');
    host=ancestor(fig,'figure');
else
    fig=uifigure('Name','FilterLab · 信号与系统扩展应用','Position',[80 60 1320 840], ...
        'Visible','off','Tag','ExtensionsFigure');
    host=fig; fig.CloseRequestFcn=@(~,~)closeWindow();
end
keys={'MountainImage','MoireImage','DocumentImage','NaishuImage'};
optsKeys={'MoireOpts','DocumentOpts','MotionOpts','AllpassOpts'};
images=cell(1,4); results=cell(1,4); busy=false; report=''; output=char(p.Results.OutputDir);
names={'1 · 摩尔纹与抗混叠','2 · 文档去横线去阴影','3 · 动态追焦与去模糊','4 · 全通相位置乱加密','5 · 统一指标总览'};
viewNames={{'四倍抽样与 RGB 边缘','频谱定位与定向陷波'},{'横线滤波与对照','光照归一化与剖面'}, ...
    {'多方向运动模糊','方向增强与振铃'},{'全通系统响应','加密、解密与敏感度'}};
% Field, label, initial value, limits. Zero selects automatic line detection.
defs={{'Order','抗混叠阶数',6,[1 10]}; ...
    {'LinePeriod','行距 / px（0 自动）',0,[0 256];'Cutoff','背景截止频率 / Nyquist',.03,[.02 .04]}; ...
    {'Angle','去模糊方向 / °',30,[-180 180]}; ...
    {'Seed','密钥随机种子',3,[0 2^32-1];'NumPairs','每轴共轭极点对',14,[1 24]}};
main=uigridlayout(fig,[3 1],'RowHeight',{38,'1x',30},'Padding',[12 10 12 8]);
bar=uigridlayout(main,[1 5],'ColumnWidth',{175,145,125,120,115},'Padding',[0 0 0 0]);
btnAll=uibutton(bar,'Text','运行全部四模块并导出','Tag','ExtensionsRunAll','ButtonPushedFcn',@(~,~)safe(@runAll));
btnOne=uibutton(bar,'Text','运行当前模块','Tag','ExtensionsRunModule','ButtonPushedFcn',@(~,~)safe(@runModule));
btnImage=uibutton(bar,'Text','选择输入图…','ButtonPushedFcn',@(~,~)safe(@chooseImage));
btnFolder=uibutton(bar,'Text','导出位置…','ButtonPushedFcn',@(~,~)safe(@chooseOutput));
btnReport=uibutton(bar,'Text','打开报告','ButtonPushedFcn',@(~,~)safe(@openReport));
tabs=uitabgroup(main,'Tag','ExtensionsTabs');
pages=gobjects(1,5); selectors=gobjects(1,4); drawings=gobjects(1,4);
notes=gobjects(1,4); sources=gobjects(1,4); params=cell(1,4);
for idx=1:4
    pages(idx)=uitab(tabs,'Title',names{idx});
    g=uigridlayout(pages(idx),[1 2],'ColumnWidth',{275,'1x'});
    controls=uigridlayout(g,[8 1],'RowHeight',{30,46,26,56,56,30,'1x',1},'Padding',[6 6 6 6]);
    if idx==1
        imageRole=uidropdown(controls,'Items',{'正演输入 · 山脉','逆向输入 · 拍屏'},'ItemsData',[1 2], ...
            'ValueChangedFcn',@(~,~)updateSources());
    else
        uilabel(controls,'Text','实验输入','FontWeight','bold');
    end
    sources(idx)=uilabel(controls,'Text','','WordWrap','on');
    uilabel(controls,'Text','实验参数','FontWeight','bold');
    def=defs{idx}; fields=gobjects(1,size(def,1));
    for j=1:size(def,1)
        fieldBox=uigridlayout(controls,[2 1],'RowHeight',{18,25},'Padding',[0 0 0 0],'RowSpacing',1);
        fieldBox.Layout.Row=j+3;
        uilabel(fieldBox,'Text',def{j,2});
        fields(j)=uieditfield(fieldBox,'numeric','Value',def{j,3},'Limits',def{j,4}, ...
            'Tag',['Extensions' def{j,1}],'ValueChangedFcn',@(~,~)invalidate(idx));
        if ismember(def{j,1},{'Order','NumPairs','Seed'}), fields(j).RoundFractionalValues='on'; end
    end
    params{idx}=fields;
    selectors(idx)=uidropdown(controls,'Items',viewNames{idx},'ItemsData',1:2, ...
        'ValueChangedFcn',@(~,~)showModule(idx)); selectors(idx).Layout.Row=6;
    notes(idx)=uitextarea(controls,'Editable','off','Value',{'运行模块后显示实测指标。'}); notes(idx).Layout.Row=7;
    drawings(idx)=uigridlayout(g,[1 1],'Padding',[2 2 2 2]);
end
pages(5)=uitab(tabs,'Title',names{5}); overview=uigridlayout(pages(5),[2 1],'RowHeight',{175,'1x'});
guide=fl_ext_catalog(1:4);
uitable(overview,'Data',table2cell(guide),'ColumnName',{'模块','核心对比维度','关键定量评价指标','课程核心知识点'}, ...
    'ColumnWidth',{50,'auto','auto','auto'},'Tag','ExtensionsOverview');
metrics=uitable(overview,'ColumnName',{'模块','实测指标','数值','单位'},'ColumnWidth',{55,230,120,100},'Tag','ExtensionsMetrics');
status=uilabel(main,'Text','选择模块后可单独运行；运行全部将同时导出报告。','Tag','ExtensionsStatus');
tabs.SelectionChangedFcn=@(~,~)refresh();
actions=struct('RunAll',@runAll,'RunModule',@runModule,'SetImage',@setImage, ...
    'SetModule',@setModule,'SetView',@setView,'SetOutputDir',@setOutput,'OpenReport',@openReport);
setappdata(fig,'ExtensionsActions',actions);
if embedded, setappdata(host,'ExtensionsActions',actions); end
updateSources(); refresh();
if ~embedded, fig.Visible=visible; end

    function out=runAll(folder)
        if nargin<1, folder=output; end
        out=execute(1:4,true,folder);
    end
    function out=runModule(id)
        if nargin<1, id=current(); end
        checkModule(id); out=execute(id,false,'');
    end
    function out=execute(ids,export,folder)
        checkIdle(); busy=true;
        guard=onCleanup(@finish); %#ok<NASGU>
        status.Text='正在计算实验…'; refresh(); drawnow;
        args={'Modules',ids,'Export',export,'OutputDir',folder};
        for n=1:4
            opts=struct; spec=defs{n}; handles=params{n};
            for a=1:numel(handles)
                key=spec{a,1}; value=handles(a).Value;
                if strcmp(key,'LinePeriod') && value==0, continue; end
                opts.(key)=value;
            end
            args=[args,{keys{n},images{n},optsKeys{n},opts}]; %#ok<AGROW>
        end
        out=FL_extensions(args{:});
        results(ids)=out.Results(ids);
        for n=ids, showModule(n); end
        updateMetrics();
        if export
            report=fullfile(out.OutputDir,'report.html');
            status.Text=['已导出 · ' out.OutputDir];
        else
            status.Text=['已完成 · ' names{ids}];
        end
    end
    function finish()
        if isvalid(fig), busy=false; refresh(); end
    end
    function showModule(id)
        area=drawings(id); delete(area.Children); m=results{id};
        if isempty(m), notes(id).Value={'运行模块后显示实测指标。'}; return; end
        view=m.Views(selectors(id).Value); count=numel(view.Panels);
        cols=min(3,ceil(sqrt(count))); rows=ceil(count/cols);
        area.RowHeight=repmat({'1x'},1,rows); area.ColumnWidth=repmat({'1x'},1,cols);
        for q=1:count
            ax=uiaxes(area); ax.Layout.Row=ceil(q/cols); ax.Layout.Column=1+mod(q-1,cols);
            fl_ext_draw_panel(ax,view.Panels{q});
        end
        t=m.Metrics; lines=cell(height(t)+2,1); lines(1:2)={char(m.Conclusion);''};
        for q=1:height(t), lines{q+2}=sprintf('%s  %.6g %s',t.Metric{q},t.Value(q),t.Unit{q}); end
        notes(id).Value=lines;
    end
    function updateMetrics()
        rows=cell(0,4);
        for n=1:4
            if ~isempty(results{n})
                t=results{n}.Metrics;
                rows=[rows;num2cell(repmat(n,height(t),1)),table2cell(t)]; %#ok<AGROW>
            end
        end
        metrics.Data=rows;
    end
    function invalidate(ids)
        checkIdle(); report=''; results(ids)=repmat({[]},1,numel(ids));
        for n=ids, showModule(n); end
        updateMetrics(); status.Text='输入或参数已更改，运行模块可更新指标。'; refresh();
    end
    function setImage(key,value)
        checkIdle();
        n=find(strcmpi(key,keys),1);
        if isempty(n), error('FL_extensions_gui:image','请选择 MountainImage、MoireImage、DocumentImage 或 NaishuImage。'); end
        images{n}=value; affected={[1 3],1,2,4};
        updateSources(); invalidate(affected{n});
    end
    function updateSources()
        roles=[imageRole.Value 3 1 4];
        for n=1:4
            value=images{roles(n)};
            if isempty(value), label='自动发现照片或使用内置基准';
            elseif ischar(value)||isstring(value), label=char(value);
            else, label=sprintf('数值输入 · %d × %d',size(value,2),size(value,1)); end
            sources(n).Text=label; sources(n).Tooltip=label;
        end
    end
    function chooseImage()
        roles=[imageRole.Value 3 1 4]; id=current(); checkModule(id);
        [name,path]=uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff;*.mat','照片或 MAT 图像'},'选择实验输入图');
        if ~isequal(name,0), setImage(keys{roles(id)},fullfile(path,name)); end
    end
    function chooseOutput()
        path=uigetdir(pwd,'选择空的报告导出目录');
        if ~isequal(path,0), setOutput(path); end
    end
    function setOutput(path)
        checkIdle(); output=char(path); status.Text=['下次导出 · ' output]; refresh();
    end
    function openReport()
        if isfile(report), web(report,'-browser'); end
    end
    function id=current()
        id=find(pages==tabs.SelectedTab,1);
    end
    function setModule(id)
        validateattributes(id,{'numeric'},{'scalar','integer','>=',1,'<=',5});
        tabs.SelectedTab=pages(id); refresh();
    end
    function setView(id,v)
        checkModule(id); validateattributes(v,{'numeric'},{'scalar','integer','>=',1,'<=',2});
        selectors(id).Value=v; showModule(id);
    end
    function refresh()
        set([btnAll btnFolder],'Enable',onoff(~busy));
        set([btnOne btnImage],'Enable',onoff(~busy && current()<=4));
        btnReport.Enable=onoff(~busy && ~isempty(report) && isfile(report));
        for n=1:4, set(params{n},'Enable',onoff(~busy)); end
        st=struct('Busy',busy,'SelectedModule',current(),'Results',{results},'Images',{images},'OutputDir',output,'Report',report);
        setappdata(fig,'ExtensionsState',st);
        if embedded, setappdata(host,'ExtensionsState',st); end
    end
    function safe(fn)
        try, fn(); catch ex
            status.Text=ex.message;
            if strcmp(host.Visible,'on'), uialert(host,ex.message,'扩展应用实验'); end
        end
    end
    function checkIdle()
        if busy, error('FL_extensions_gui:busy','实验正在运行。'); end
    end
    function closeWindow()
        if ~busy, delete(fig); end
    end
end
function checkModule(id)
validateattributes(id,{'numeric'},{'scalar','integer','>=',1,'<=',4});
end
function s=onoff(tf)
if tf, s='on'; else, s='off'; end
end
