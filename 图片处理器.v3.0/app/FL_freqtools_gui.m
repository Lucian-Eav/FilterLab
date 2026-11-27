function fig = FL_freqtools_gui(varargin)
%FL_FREQTOOLS_GUI Standalone or embedded photographic frequency workshop.
% Actions and State are published on both the workspace and its host figure.
% Actions: RunModule(id), RunAll(), SetInput(id,source), UseSample(id,kind),
% SetOptions(id,struct), SetModule(id), Inspect(), SelectRank(rank), Export(id,path).
root=fileparts(mfilename('fullpath'));
if ~isdeployed, addpath(fullfile(root,'core')); end
theme=fl_ui_theme();
p=inputParser; p.addParameter('Parent',[]); p.addParameter('Visible','on');
p.addParameter('MaxEdge',512); p.parse(varargin{:});
visible=validatestring(p.Results.Visible,{'on','off'});
maxEdge=p.Results.MaxEdge;
validateattributes(maxEdge,{'numeric'},{'scalar','integer','>=',24});
embedded=~isempty(p.Results.Parent);
if embedded
    fig=uipanel(p.Results.Parent,'BorderType','none','Tag','FreqToolsWorkspace');
    host=ancestor(fig,'figure');
else
    screen=get(groot,'ScreenSize');
    windowSize=min([1380 860],screen(3:4)-[40 60]);
    position=[screen(1:2)+(screen(3:4)-windowSize)/2,windowSize];
    fig=uifigure('Name','FilterLab · 频域实用工坊','Position',position, ...
        'Visible','off','Tag','FreqToolsFigure');
    host=fig; fig.CloseRequestFcn=@(~,~)closeWindow();
end
tools={'burst','sharpness','watermark','optics'};
titles={'连拍对齐与堆栈','连拍清晰度体检','频域隐形水印','光学星芒与散景'};
samples={'burst_crowd','burst_sharpness','watermark_photo','night_lights'};
inputs=cell(1,4); results=cell(1,4); busy=false; selectedRank=1;
options={struct('Mode','median','RefIndex',1,'AutoCrop',true),struct(), ...
    struct('Mode','text','Text','FILTERLAB','Icon','heart', ...
    'PatternImage',[],'Strength',.22,'RunAttackTest',true), ...
    struct('Effect','starburst','Aperture','hex6','Threshold',.78,'Intensity',.85, ...
    'Size',45,'RotationDeg',15,'Dispersion',true,'CustomAperture',[])};
widgets=cell(1,4); controls=gobjects(1,4); notes=gobjects(1,4);
sources=gobjects(1,4); axesList=cell(1,4); tables=gobjects(1,2);
shell=uigridlayout(fig,[2 1],'BackgroundColor',theme.Paper,'RowHeight',{'1x',28},'Padding',[8 8 8 6]);
tabs=uitabgroup(shell,'Tag','FreqToolsTabs'); pages=gobjects(1,4);
for pageIndex=1:4
    pages(pageIndex)=uitab(tabs,'Title',titles{pageIndex});
end
areas=gobjects(1,4); imageList=cell(1,4); renderedResult=false(1,4);
lockable=cell(1,4); lastBusy=false;
status=uilabel(shell,'Text','选择工具后可直接运行内置样例。','Tag','FreqToolsStatus');
tabs.SelectionChangedFcn=@(~,~)selectTool();
actions=struct('RunModule',@runModule,'RunAll',@runAll,'SetInput',@setInput, ...
    'UseSample',@useSample,'SetOptions',@setOptions,'SetModule',@setModule, ...
    'Inspect',@inspect,'SelectRank',@selectRank,'Export',@exportResult);
selectTool();
setappdata(fig,'FreqToolsActions',actions);
if embedded, setappdata(host,'FreqToolsActions',actions); end
if ~embedded, fig.Visible=visible; end

    function selectTool()
        id=current(); mount(id);
        if ~isempty(results{id}) && ~renderedResult(id), showResult(id); end
        publish();
    end
    function mount(id)
        if isgraphics(controls(id)), return; end
    layout=uigridlayout(pages(id),[1 2],'BackgroundColor',theme.Paper,'ColumnWidth',{285,'1x'},'Padding',[6 6 6 6]);
    panel=uipanel(layout,'BorderType','none','Scrollable','on');
    lastControl=[9 7 12 13]; lastRow=lastControl(id);
    controls(id)=uigridlayout(panel,[lastRow+2 1],'BackgroundColor',theme.Paper,'RowHeight', ...
        [repmat({30},1,lastRow),{150,'1x'}],'Padding',[3 3 6 3],'RowSpacing',5);
    sources(id)=uilabel(controls(id),'Text',['内置样例 · ' samples{id}],'WordWrap','on');
    sources(id).Layout.Row=1; widgets{id}=struct();
    switch id
        case 1
            button(id,2,'加载多张连拍…',@()chooseFiles(1,true));
            button(id,3,'使用去路人样例',@()useSample(1,'burst_crowd'));
            button(id,4,'使用夜景降噪样例',@()useSample(1,'burst_night'));
            widgets{1}.Mode=dropdown(1,5,{'去路人中位数','夜景均值','截尾均值'}, ...
                {'median','mean','trimmed'},'median');
            widgets{1}.RefIndex=number(1,6,'参考帧索引',1,[1 10000],true);
            widgets{1}.AutoCrop=checkbox(1,7,'裁剪公共有效区域',true);
            button(1,8,'运行堆栈',@()runModule(1));
            button(1,9,'导出结果照片…',@()chooseExport(1));
        case 2
            button(2,2,'选择多张照片…',@()chooseFiles(2,true));
            button(2,3,'选择照片文件夹…',@chooseFolder);
            button(2,4,'使用连拍样例',@()useSample(2));
            button(2,5,'开始体检排序',@()runModule(2));
            button(2,6,'导出最清晰照片…',@()chooseExport(2));
            uilabel(controls(2),'Text','点击排名表可联动照片与频谱。');
        case 3
            button(3,2,'打开照片…',@()chooseFiles(3,false));
            button(3,3,'使用样例图',@()useSample(3));
            widgets{3}.Mode=dropdown(3,4,{'文字署名','内置图标','自定义图标'}, ...
                {'text','icon','image'},'text');
            widgets{3}.Text=uieditfield(controls(3),'text','Value','FILTERLAB', ...
                'Tooltip','A-Z、0-9、空格和 - _ . !','ValueChangedFcn',@(~,~)invalidate(3));
            widgets{3}.Text.Layout.Row=5;
            widgets{3}.Icon=dropdown(3,6,{'心形','五角星','笑脸','加号'}, ...
                {'heart','star','smile','plus'},'heart');
            button(3,7,'选择自定义水印图…',@choosePattern);
            strengthBox=uigridlayout(controls(3),[2 2],'BackgroundColor',theme.Paper,'RowHeight',{26,40},'ColumnWidth',{'1x',70}, ...
                'Padding',[0 0 0 0],'RowSpacing',5);
            strengthBox.Layout.Row=8; uilabel(strengthBox,'Text','水印强度');
            widgets{3}.Strength=uislider(strengthBox,'Limits',[.05 .60],'Value',.22, ...
                'MajorTicks',[.05 .22 .4 .6],'Tag','FreqWatermarkStrength','ValueChangedFcn',@(~,~)invalidate(3));
            widgets{3}.Strength.Layout.Row=2; widgets{3}.Strength.Layout.Column=[1 2];
            strengthValue=fl_slider_pair(strengthBox,widgets{3}.Strength,'FreqWatermarkStrengthValue',.01,'%.2f');
            strengthValue.Layout.Row=1; strengthValue.Layout.Column=2;
            controls(3).RowHeight{8}=80;
            widgets{3}.RunAttackTest=checkbox(3,9,'验证加噪与亮度对比度扰动',true);
            button(3,10,'写入隐形水印',@()runModule(3));
            button(3,11,'仅查验当前图频谱',@inspect);
            button(3,12,'导出水印照片…',@()chooseExport(3));
        case 4
            button(4,2,'打开夜景照…',@()chooseFiles(4,false));
            button(4,3,'使用夜景样例',@()useSample(4));
            widgets{4}.Effect=dropdown(4,4,{'衍射星芒','自定义散景'}, ...
                {'starburst','bokeh'},'starburst');
            widgets{4}.Effect.ValueChangedFcn=@(~,~)changeEffect();
            widgets{4}.Aperture=dropdown(4,5,{'6角星芒','8角星芒','10角星芒（5叶片）','4角星芒'}, ...
                {'hex6','oct8','pent5','cross4'},'hex6');
            widgets{4}.Threshold=number(4,6,'高光阈值',.78,[.4 .98],false);
            widgets{4}.Intensity=number(4,7,'光效强度',.85,[0 2.5],false);
            widgets{4}.Size=number(4,8,'星芒核尺寸 / 散景半径 px',45,[3 161],true);
            widgets{4}.RotationDeg=number(4,9,'旋转角度 / °',15,[-360 360],false);
            widgets{4}.Dispersion=checkbox(4,10,'RGB 波长色散',true);
            button(4,11,'选择自定义光圈图…',@chooseAperture);
            button(4,12,'生成效果',@()runModule(4));
            button(4,13,'导出效果照片…',@()chooseExport(4));
    end
    notes(id)=uitextarea(controls(id),'Editable','off','Value', ...
        {sprintf('处理最长边上限 %d px。导出尺寸跟随处理结果。',maxEdge)});
    notes(id).Layout.Row=lastRow+1;
    view=uigridlayout(layout,[2 1],'BackgroundColor',theme.Paper,'RowHeight',{'1x',150},'Padding',[2 2 2 2]);
    areas(id)=uigridlayout(view,[2 2],'BackgroundColor',theme.Paper,'Padding',[0 0 0 0]);
    axesList{id}=gobjects(1,4); imageList{id}=gobjects(1,4);
    if id<=2
        tables(id)=uitable(view,'Tag',sprintf('FreqToolsTable%d',id),'RowName',{});
        if id==2, tables(id).CellSelectionCallback=@(~,event)safe(@()selectCell(event)); end
    else
        view.RowHeight={'1x',0};
    end
    lockable{id}=findall(controls(id),'-property','Enable');
    if busy, set(lockable{id},'Enable','off'); end
    end

    function button(id,row,label,fn)
        b=uibutton(controls(id),'Text',label,'ButtonPushedFcn',@(~,~)safe(fn));
        b.Layout.Row=row;
        if any(strcmp(label,{'运行堆栈','开始体检排序','写入隐形水印','生成效果'}))
            b.BackgroundColor=theme.Accent; b.FontColor=theme.White;
        end
    end
    function h=dropdown(id,row,items,data,value)
        h=uidropdown(controls(id),'Items',items,'ItemsData',data,'Value',value, ...
            'ValueChangedFcn',@(~,~)invalidate(id)); h.Layout.Row=row;
    end
    function h=number(id,row,label,value,limits,integer)
        box=uigridlayout(controls(id),[1 2],'BackgroundColor',theme.Paper,'ColumnWidth',{'1x',92},'Padding',[0 0 0 0]);
        box.Layout.Row=row; uilabel(box,'Text',label);
        h=uieditfield(box,'numeric','Value',value,'Limits',limits, ...
            'ValueChangedFcn',@(~,~)invalidate(id));
        if integer, h.RoundFractionalValues='on'; end
    end
    function h=checkbox(id,row,label,value)
        h=uicheckbox(controls(id),'Text',label,'Value',value, ...
            'ValueChangedFcn',@(~,~)invalidate(id)); h.Layout.Row=row;
    end
    function o=readOptions(id)
        o=options{id}; names=fieldnames(widgets{id});
        for k=1:numel(names), o.(names{k})=widgets{id}.(names{k}).Value; end
    end
    function R=runModule(id)
        if nargin<1, id=current(); end
        checkId(id); checkIdle(); mount(id); busy=true;
        guard=onCleanup(@finish);
        publish();
        status.Text=['正在运行 · ' titles{id}]; drawnow;
        o=readOptions(id);
        if id==3, o.Action='embed'; end
        R=calculate(id,o); results{id}=R;
        if id==2, selectedRank=1; end
        renderedResult(id)=false;
        if id==current(), showResult(id); end
        status.Text=['已完成 · ' titles{id}];
    end
    function all=runAll()
        checkIdle(); all=cell(1,4);
        for k=1:4, all{k}=runModule(k); end
    end
    function R=calculate(id,o)
        args={'MaxEdge',maxEdge,'Sample',samples{id}};
        if ~isempty(inputs{id}), args=[args,{'Input',inputs{id}}]; end
        R=FL_freqtools(tools{id},args{:},o);
    end
    function R=inspect()
        checkIdle(); mount(3); busy=true; guard=onCleanup(@finish);
        publish();
        status.Text='正在查验当前输入图频谱…'; drawnow;
        o=readOptions(3); o.Action='inspect';
        R=calculate(3,o); results{3}=R; renderedResult(3)=false;
        if current()==3, showResult(3); end
        status.Text='频谱查验完成';
    end
    function finish()
        if isvalid(fig), busy=false; publish(); end
    end
    function setInput(id,source)
        checkId(id); checkIdle();
        [data,meta]=fl_ft_samples('normalize',source,maxEdge);
        if id>=3 && iscell(data) && numel(data)~=1
            error('FL_freqtools_gui:single','此工具需要一张图像。');
        end
        mount(id); inputs{id}=source; invalidate(id); preview(id,data);
        if isfield(meta,'Names'), label=strjoin(meta.Names,', ');
        else, label='数值图像输入'; end
        sources(id).Text=label; sources(id).Tooltip=label; publish();
    end
    function useSample(id,kind)
        checkId(id); checkIdle();
        if nargin<2, defaults={'burst_crowd','burst_sharpness','watermark_photo','night_lights'}; kind=defaults{id}; end
        allowed={{'burst_crowd','burst_night'},{'burst_sharpness'},{'watermark_photo'},{'night_lights'}};
        kind=validatestring(kind,allowed{id});
        data=fl_ft_samples(kind,[],maxEdge);
        mount(id); inputs{id}=[]; samples{id}=kind;
        if id==1
            widgets{1}.RefIndex.Value=1;
            if strcmp(kind,'burst_night'), widgets{1}.Mode.Value='mean';
            else, widgets{1}.Mode.Value='median'; end
        end
        invalidate(id); preview(id,data); sources(id).Text=['内置样例 · ' kind]; publish();
    end
    function setOptions(id,o)
        checkId(id); checkIdle();
        if ~isstruct(o)||~isscalar(o), error('FL_freqtools_gui:options','选项应为标量结构体。'); end
        names=fieldnames(o);
        if ~all(ismember(names,fieldnames(options{id})))
            error('FL_freqtools_gui:options','包含此工具不支持的选项。');
        end
        mount(id); invalidate(id);
        if id==4 && isfield(o,'Effect')
            if ~strcmp(widgets{4}.Effect.Value,o.Effect)
                widgets{4}.Effect.Value=o.Effect; changeEffect();
            end
        end
        for k=1:numel(names)
            key=names{k};
            if isfield(widgets{id},key)
                widget=widgets{id}.(key); widget.Value=o.(key);
                if isappdata(widget,'NumberField'), set(getappdata(widget,'NumberField'),'Value',widget.Value); end
            end
            options{id}.(key)=o.(key);
        end
        publish();
    end
    function changeEffect()
        checkIdle(); bokeh=strcmp(widgets{4}.Effect.Value,'bokeh');
        h=widgets{4}.Aperture;
        if bokeh
            h.Items={'心形','五角星','六边形','甜甜圈','自定义光圈'};
            h.ItemsData={'heart','star','hexagon','ring','custom'}; h.Value='heart';
            widgets{4}.Size.Value=15;
        else
            h.Items={'6角星芒','8角星芒','10角星芒（5叶片）','4角星芒'};
            h.ItemsData={'hex6','oct8','pent5','cross4'}; h.Value='hex6';
            widgets{4}.Size.Value=45;
        end
        widgets{4}.Dispersion.Enable=onoff(~bokeh); invalidate(4);
    end
    function invalidate(id)
        checkIdle(); results{id}=[];
        renderedResult(id)=false; im=imageList{id};
        for h=im(isgraphics(im))
            set(h,'Visible','off','CData',[]); h.Parent.Title.String='';
        end
        if id<=2, tables(id).Data=cell(0,0); end
        notes(id).Value={'输入或参数已更改，请重新运行。'};
        status.Text='输入或参数已更新'; publish();
    end
    function preview(id,data)
        if iscell(data), data=data{1}; end
        drawImage(id,1,data,'当前输入');
    end
    function showResult(id)
        r=results{id}; lines={};
        switch id
            case 1
                drawImage(1,1,r.Reference,'参考帧');
                drawImage(1,2,r.Stacked,'对齐堆栈结果');
                d=min(1,5*abs(fl_ft_luma(r.Stacked)-fl_ft_luma(r.Reference)));
                drawImage(1,3,cat(3,min(1,2*d),d.^2,zeros(size(d))),'亮度差异热图 ×5');
                drawImage(1,4,r.Aligned(:,:,:,end),'末帧对齐结果');
                tables(1).ColumnName={'帧','dy / px','dx / px','PSR'};
                tables(1).Data=[(1:size(r.Shifts,1))',r.Shifts,r.PSR];
                m=r.Metrics;
                lines={sprintf('帧数 %d，最大位移 %.3f px',m.FrameCount,m.MaxShift), ...
                    sprintf('帧间残差下降 %.2f%%',100*m.ResidualReduction), ...
                    sprintf('噪声标准差下降 %.2f%%',100*m.NoiseReduction),m.NoiseMethod};
                if isfield(m,'StackPSNR')
                    lines=[lines,{sprintf('PSNR %.3f → %.3f dB',m.SinglePSNR,m.StackPSNR), ...
                        sprintf('SSIM %.5f → %.5f',m.SingleSSIM,m.StackSSIM)}];
                end
            case 2
                tables(2).ColumnName={'排名','帧','名称','得分','绝对分','中高频比','二阶矩','各向异性','手抖角 / °','诊断'};
                tables(2).Data=table2cell(r.Table); tables(2).ColumnWidth={45,40,100,65,75,75,75,75,80,220};
                showRank(true); lines={sprintf('推荐第 %d 帧。点击表格可对比各帧。',r.BestIndex), ...
                    '角度使用图像坐标，水平向右为 0°，顺时针，周期为 180°。'};
            case 3
                drawImage(3,1,r.Original,'当前输入照片');
                if isfield(r,'PSNR')
                    drawImage(3,2,r.Output,'写入水印后');
                else
                    drawImage(3,2,r.Pattern,'查验模板');
                end
                drawImage(3,3,spectrumView(r.Spectrum),'二维对数幅度谱');
                if isfield(r.Attack,'Noise')
                    drawImage(3,4,spectrumView(r.Attack.Noise.WatermarkSpectrum),'加噪后水印区域');
                else
                    drawImage(3,4,spectrumView(r.WatermarkSpectrum),'水印区域放大');
                end
                lines={sprintf('检出相关性 %.4f，检出 SNR %.2f dB',r.DetectCorr,r.DetectSNR_dB)};
                if isfield(r,'PSNR')
                    lines=[lines,{sprintf('PSNR %.3f dB，SSIM %.5f',r.PSNR,r.SSIM), ...
                        sprintf('逆变换虚部残差 %.3g',r.ImagResidual)}];
                end
                if isfield(r.Attack,'Noise')
                    lines=[lines,{sprintf('加噪相关性 %.4f',r.Attack.Noise.DetectCorr), ...
                        sprintf('亮度对比度扰动相关性 %.4f',r.Attack.Tone.DetectCorr)}];
                end
            case 4
                drawImage(4,1,r.Aperture,'光圈孔径'); drawImage(4,2,r.PSF,'物理 PSF（对数显示）');
                drawImage(4,3,r.InputImages,'输入夜景'); drawImage(4,4,r.Output,'光学效果');
                m=r.Metrics;
                lines={sprintf('高光像素 %.3f%%',100*m.HighlightFraction), ...
                    sprintf('线性光平均能量增量 %.6g',m.EnergyIncrease), ...
                    sprintf('暗区平均误差 %.6g',m.DarkBackgroundError), ...
                    sprintf('核尺寸 %d px',m.PSFSize)};
        end
        notes(id).Value=lines; renderedResult(id)=true;
    end
    function selectRank(rank)
        checkIdle(); r=results{2};
        if isempty(r), error('FL_freqtools_gui:rank','请先运行清晰度体检。'); end
        validateattributes(rank,{'numeric'},{'scalar','integer','>=',1,'<=',height(r.Table)});
        if selectedRank~=rank
            selectedRank=rank;
            if current()==2, showRank(false); else, renderedResult(2)=false; end
            publish();
        end
    end
    function showRank(refreshBest)
        r=results{2}; idx=r.Table.FrameIndex(selectedRank);
        drawImage(2,1,r.InputImages{idx},sprintf('第 %d 名 · %s',selectedRank,r.Table.Name{selectedRank}));
        selectedSpectrum=spectrumView(r.Spectra{idx});
        drawImage(2,2,selectedSpectrum,'选中帧二维对数功率谱');
        if refreshBest
            drawImage(2,3,r.BestImage,'最清晰推荐帧');
            if idx==r.BestIndex, bestSpectrum=selectedSpectrum;
            else, bestSpectrum=spectrumView(r.Spectra{r.BestIndex}); end
            drawImage(2,4,bestSpectrum,'推荐帧二维对数功率谱');
        end
    end
    function selectCell(event)
        if ~isempty(event.Indices), selectRank(event.Indices(1,1)); end
    end
    function drawImage(id,index,data,label)
        ax=axesList{id}(index);
        if ~isgraphics(ax)
            ax=uiaxes(areas(id)); ax.Layout.Row=ceil(index/2); ax.Layout.Column=1+mod(index-1,2);
            axesList{id}(index)=ax;
            fl_ext_draw_panel(ax,struct('Kind','image','Data',data,'Title',label));
            im=findobj(ax,'Type','image'); imageList{id}(index)=im;
            % Each output cell can switch between RGB and normalized grayscale.
            colormap(ax,gray(256)); ax.CLim=[0 1]; im.CDataMapping='scaled';
        else
            im=imageList{id}(index);
            if ~ismatrix(data), data=min(1,max(0,data)); end
            [h,w,~]=size(data);
            set(im,'CData',data,'XData',[1 w],'YData',[1 h],'Visible','on');
            ax.XLim=[.5 w+.5]; ax.YLim=[.5 h+.5]; ax.Title.String=label;
        end
    end
    function path=exportResult(id,path)
        checkId(id); checkIdle(); r=results{id};
        if isempty(r), error('FL_freqtools_gui:export','请先运行工具。'); end
        if id==1, image=r.Stacked; elseif id==2, image=r.BestImage; else, image=r.Output; end
        meta=struct('Width',size(image,2),'Height',size(image,1));
        if isfield(r.InputMeta,'Paths'), meta.Source=r.InputMeta.Paths{1}; end
        fl_photo_save(path,image,meta); status.Text=['已导出 · ' char(path)];
    end
    function chooseFiles(id,multiple)
        mode='off'; if multiple, mode='on'; end
        [names,folder]=uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff','照片'}, ...
            '选择输入照片','MultiSelect',mode);
        if isequal(names,0), return; end
        if ischar(names), names={names}; end
        setInput(id,cellfun(@(n)fullfile(folder,n),names,'UniformOutput',false));
    end
    function chooseFolder()
        folder=uigetdir(pwd,'选择照片文件夹');
        if ~isequal(folder,0), setInput(2,folder); end
    end
    function choosePattern()
        [name,folder]=uigetfile({'*.png;*.jpg;*.bmp;*.tif','水印图标'},'选择水印图标');
        if ~isequal(name,0), setOptions(3,struct('Mode','image','PatternImage',fullfile(folder,name))); end
    end
    function chooseAperture()
        [name,folder]=uigetfile({'*.png;*.jpg;*.bmp;*.tif','黑白光圈图'},'选择光圈图');
        if ~isequal(name,0)
            setOptions(4,struct('Effect','bokeh','Aperture','custom','CustomAperture',fullfile(folder,name)));
        end
    end
    function chooseExport(id)
        [name,folder]=uiputfile({'*.png','PNG';'*.jpg','JPEG';'*.tif','TIFF'},'导出处理照片');
        if ~isequal(name,0), exportResult(id,fullfile(folder,name)); end
    end
    function setModule(id)
        checkId(id); tabs.SelectedTab=pages(id); selectTool();
    end
    function id=current()
        id=find(pages==tabs.SelectedTab,1);
    end
    function publish()
        if ~isvalid(fig), return; end
        if ~isequal(lastBusy,busy)
            for tool=find(isgraphics(controls)), set(lockable{tool},'Enable',onoff(~busy)); end
            if ~busy && isgraphics(controls(4)), widgets{4}.Dispersion.Enable=onoff(strcmp(widgets{4}.Effect.Value,'starburst')); end
            lastBusy=busy;
        end
        st=struct('Busy',busy,'SelectedModule',current(),'Results',{results}, ...
            'Inputs',{inputs},'Samples',{samples},'SelectedRank',selectedRank,'MaxEdge',maxEdge);
        setappdata(fig,'FreqToolsState',st);
        if embedded, setappdata(host,'FreqToolsState',st); end
    end
    function checkIdle()
        if busy, error('FL_freqtools_gui:busy','工坊正在处理，请等待完成。'); end
    end
    function safe(fn)
        try, fn(); catch ex
            status.Text=ex.message;
            if strcmp(host.Visible,'on'), uialert(host,ex.message,'频域实用工坊'); end
        end
    end
    function closeWindow()
        if ~busy, delete(fig); end
    end
end

function checkId(id)
validateattributes(id,{'numeric'},{'scalar','integer','>=',1,'<=',4});
end
function value=onoff(tf)
if tf, value='on'; else, value='off'; end
end
function image=spectrumView(spectrum)
% Clip sparse spectral peaks for a readable display of the surrounding band.
values=spectrum(:); count=numel(values);
lo=max(mink(values,max(1,round(.01*count))));
hi=min(maxk(values,count-max(1,round(.99*count))+1));
image=min(1,max(0,(spectrum-lo)/max(hi-lo,eps)));
end
