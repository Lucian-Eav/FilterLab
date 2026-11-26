function fig = FL_photo(varargin)
%FL_PHOTO  自然照片工作区，MATLAB R2020b+，无需附加工具箱。
% FL_photo; FL_photo('File','photo.jpg'); FL_photo('Visible','off');
% 使用原图/处理后/分割对比；100% 模式可拖动、滚轮或方向按钮平移。
% 预览最长边 1200；100% 和导出从原尺寸重新处理，参数不叠加到旧结果。
% 自动化接口：getappdata(fig,'PhotoActions')；状态：getappdata(fig,'PhotoState')。
startupClock=tic;
root=fileparts(mfilename('fullpath')); if ~isdeployed, addpath(fullfile(root,'core')); end
opt=struct('Visible','on','File','');
if mod(nargin,2), error('FL_photo:args','请使用名称和值成对的选项。'); end
for k=1:2:nargin
    key=char(varargin{k});
    if ~isfield(opt,key), error('FL_photo:option','未知选项：%s',key); end
    opt.(key)=varargin{k+1};
end
C=struct('bg',[.12 .13 .14],'panel',[.18 .19 .20],'text',[.91 .92 .93], ...
    'muted',[.65 .69 .73],'blue',[.37 .62 .79],'input',[.23 .25 .27]);
ST=struct('Original',[],'Working',[],'Preview',[],'PreviewResult',[],'FullResult',[], ...
    'Result',[],'Spec',fl_photo_spec(),'Source','','Meta',struct(),'OutputMeta',struct(), ...
    'ViewMode','split','Zoom','fit','Split',.5,'Center',[1 1],'FullValid',false,'Busy',false, ...
    'Geometry',{{}},'CropActive',false,'CropRect',[],'CropRatio',0, ...
    'HistoryLabels',{{}},'HistoryIndex',0,'CanUndo',false,'CanRedo',false, ...
    'PreviewStages',struct(),'FullStages',struct(),'Info',struct(), ...
    'Creative',fl_creative_spec(),'Tool','none','ShowMask',false,'Spectrum',[]);
controls=struct(); dragStart=[]; dragCenter=[]; history={}; historyIndex=0;
cropDrag=struct(); cropReturn=struct(); strokePoints=[]; strokeActive=false; assignmentPanel=[];
spectrumBase=[]; % Unmarked spectrum thumbnail depends only on the working geometry.
fig=uifigure('Name','FilterLab · 照片与滤波工作室','Position',[90 70 1320 860], ...
    'Color',C.bg,'Visible','off','Tag','PhotoFigure');
fig.AutoResizeChildren='off';
lessonFigure=[];
fig.CloseRequestFcn=@(~,~)closeApp();
fig.DeleteFcn=@(~,~)closeLesson();
shell=uigridlayout(fig,[1 1],'Padding',[0 0 0 0]);
workspaceTabs=uitabgroup(shell,'Tag','FilterLabWorkspaces');
photoPage=uitab(workspaceTabs,'Title','照片与创意编辑','Tag','PhotoWorkspace','BackgroundColor',C.bg);
assignmentPage=uitab(workspaceTabs,'Title','题目滤波实验','Tag','AssignmentPage');
extensionsPage=uitab(workspaceTabs,'Title','扩展应用实验','Tag','ExtensionsPage');
extensionsPanel=[];
freqToolsPage=uitab(workspaceTabs,'Title','频域实用工坊','Tag','FreqToolsPage');
freqToolsPanel=[];
workspaceTabs.SelectionChangedFcn=@(~,~)workspaceChanged();
layout=uigridlayout(photoPage,[3 1],'RowHeight',{66,'1x',42},'Padding',[16 12 16 10], ...
    'RowSpacing',10,'BackgroundColor',C.bg);
header=uigridlayout(layout,[1 8],'ColumnWidth',{154,90,82,'1x',90,90,104,110}, ...
    'Padding',[0 0 0 0],'ColumnSpacing',8,'BackgroundColor',C.bg);
label(header,{'FilterLab','照片与滤波工作室'},C.text,18,'PhotoTitle');
openBtn=button(header,'打开照片','PhotoOpen',@(~,~)uiRun(@openDialog));
resetBtn=button(header,'重置全部','PhotoReset',@(~,~)uiRun(@reset));
sourceLabel=label(header,'导入照片，保留自然的细节与颜色',C.muted,12,'PhotoSource');
sourceLabel.WordWrap='on';
savePresetBtn=button(header,'保存参数','PhotoPresetSave',@(~,~)uiRun(@savePresetDialog));
loadPresetBtn=button(header,'载入参数','PhotoPresetLoad',@(~,~)uiRun(@loadPresetDialog));
exportBtn=button(header,'导出照片…','PhotoExport',@(~,~)uiRun(@exportDialog));
exportBtn.BackgroundColor=C.blue; exportBtn.FontColor=[.06 .10 .13]; exportBtn.FontWeight='bold';
assignmentBtn=button(header,'题目实验 →','PhotoAssignment',@(~,~)uiRun(@openAssignment));
% Variables shared by the on-demand editor and its sibling callbacks.
editorReady=false; landing=[]; enterBtn=[]; firstOpen=[];
undoBtn=[]; redoBtn=[]; cropQuickBtn=[]; historyLabel=[]; restoreBtn=[];
lessonViewButton=[]; splitLabel=[];
viewDrop=[]; zoomDrop=[]; splitSlider=[]; splitText=[]; ax=[]; img=[]; divider=[];
cropShades=[]; cropFrame=[]; cropHandles=[]; maskOverlay=[]; focusGuide=[];
brushTrail=[]; brushRing=[]; welcome=[]; leftBtn=[]; rightBtn=[]; upBtn=[]; downBtn=[];
viewHint=[]; sizeLabel=[]; toolDrop=[]; tabs=[]; colorTab=[]; denoiseTab=[]; sharpTab=[]; editTab=[];
callbacks=struct('Change',@(key,value)uiRun(@()creativeChange(key,value)), ...
    'Tool',@(tool)uiRun(@()setTool(tool)),'Mask',@(op)uiRun(@()maskOperation(op)), ...
    'FrequencyClear',@()uiRun(@clearFrequency),'SpectrumLesson',@()uiRun(@openLesson));
creativeUI=struct('Controls',struct(),'Buttons',gobjects(0),'Tabs',gobjects(0));
loadedTools={}; cropRatios=[0 -1 1 4/3 3/2 16/9 3/4 2/3 9/16];
noiseLabel=gobjects(0); ratioDrop=gobjects(0); cropFields=gobjects(0); cropSizeLabel=gobjects(0);
cropBtn=gobjects(0); rotateLeftBtn=gobjects(0); rotateRightBtn=gobjects(0);
flipHBtn=gobjects(0); flipVBtn=gobjects(0); applyCropBtn=gobjects(0); cancelCropBtn=gobjects(0);
perf=struct('ShellSeconds',NaN,'EditorReady',false,'EditorBuildSeconds',NaN, ...
    'LastOpenSeconds',NaN,'LastDecodeSeconds',NaN,'LastPreviewSeconds',NaN);
if isempty(opt.File)
    landing=uigridlayout(layout,[5 1],'RowHeight',{'1x',52,34,42,'1x'}, ...
        'Padding',[32 20 32 20],'RowSpacing',8,'BackgroundColor',C.panel,'Tag','PhotoStart');
    landing.Layout.Row=2;
    hint=label(landing,'打开照片开始编辑',C.text,26,'PhotoStartTitle');
    hint.Layout.Row=2; hint.HorizontalAlignment='center';
    hint=label(landing,'可直接打开照片，也可先进入编辑器浏览工具。',C.muted,13,'PhotoStartHint');
    hint.Layout.Row=3; hint.HorizontalAlignment='center';
    startBar=uigridlayout(landing,[1 4],'ColumnWidth',{'1x',132,132,'1x'}, ...
        'Padding',[0 0 0 0],'ColumnSpacing',10,'BackgroundColor',C.panel);
    startBar.Layout.Row=4;
    firstOpen=button(startBar,'选择照片…','PhotoStartOpen',@(~,~)uiRun(@openDialog));
    firstOpen.Layout.Column=2; firstOpen.BackgroundColor=C.blue; firstOpen.FontColor=[.06 .10 .13];
    enterBtn=button(startBar,'进入编辑器','PhotoEnterEditor',@(~,~)uiRun(@enterEditor));
    enterBtn.Layout.Column=3;
end
status=label(layout,'准备就绪 · 打开 JPEG、PNG、TIFF 或 BMP',C.muted,12,'PhotoStatus');
fig.SizeChangedFcn=@(~,~)refreshViewport();
status.Layout.Row=3;
fig.WindowKeyPressFcn=@(~,e)uiRun(@()keyPress(e));
actions=struct('Open',@loadFile,'SetSpec',@setSpec,'SetView',@setView,'SetZoom',@setZoom, ...
    'SetSplit',@setSplit,'Pan',@panPixels,'Reset',@reset,'Export',@exportTo, ...
    'SavePreset',@savePreset,'LoadPreset',@loadPreset,'Undo',@undo,'Redo',@redo, ...
    'Rotate',@rotatePhoto,'Flip',@flipPhoto,'Crop',@cropPhoto,'RestoreGeometry',@restoreGeometry, ...
    'BeginCrop',@beginCrop,'SetCropRect',@setCropRect,'SetCropRatio',@setCropRatio, ...
    'ApplyCrop',@applyCrop,'CancelCrop',@cancelCrop,'OpenAssignment',@openAssignment, ...
    'OpenExtensions',@openExtensions,'OpenFreqTools',@openFreqTools, ...
    'SetCreative',@setCreative,'SetTool',@setTool,'MaskOperation',@maskOperation, ...
    'PaintMask',@paintMask,'PaintFrequency',@paintFrequency,'SetFocus',@setFocus,'EnterEditor',@enterEditor,'OpenSpectrumLesson',@openLesson);
setappdata(fig,'PhotoActions',actions); publish(); updateEnabled();
directFileOpen=~isempty(opt.File);
if ~directFileOpen, fig.Visible=opt.Visible; end
perf.ShellSeconds=toc(startupClock); setappdata(fig,'PhotoPerformance',perf);
if ~isempty(opt.File)
    % Assemble the populated window before its first visible paint.
    try
        loadFile(char(opt.File));
        directFileOpen=false;
        fig.Visible=opt.Visible;
    catch ex
        delete(fig); rethrow(ex);
    end
end

    function child=openLesson()
        if ~isempty(lessonFigure) && isgraphics(lessonFigure,'figure') && isequal(getappdata(lessonFigure,'FilterLabPreview'),ST.Preview)
            figure(lessonFigure); child=lessonFigure; return;
        end
        % Open a read-only snapshot of the current composition, or use stripes.
        child=FL_spectrum_lesson(ST.Preview);
        closeLesson(); lessonFigure=child;
        setappdata(child,'FilterLabPreview',ST.Preview);
    end
    function closeLesson()
        if ~isempty(lessonFigure) && isgraphics(lessonFigure,'figure'), delete(lessonFigure); end
        lessonFigure=[];
    end
    function enterEditor()
        if editorReady, return; end
        beginBusy('正在创建照片编辑器…'); done=onCleanup(@finishBusy); %#ok<NASGU>
        ensureEditor(); status.Text='编辑器已就绪 · 打开照片开始编辑';
    end
    function ensureEditor()
        if editorReady, return; end
        buildClock=tic; body=[];
        try
            body=uigridlayout(layout,[1 2],'ColumnWidth',{'1x',324},'ColumnSpacing',14, ...
                'Padding',[0 0 0 0],'BackgroundColor',C.bg,'Visible','off');
            body.Layout.Row=2; body.Layout.Column=1;
            view=uigridlayout(body,[4 1],'RowHeight',{38,42,'1x',38},'Padding',[0 0 0 0], ...
                'RowSpacing',6,'BackgroundColor',C.bg);
            editBar=uigridlayout(view,[1 5],'ColumnWidth',{82,82,90,'1x',126}, ...
                'Padding',[0 0 0 0],'ColumnSpacing',6,'BackgroundColor',C.bg);
            undoBtn=button(editBar,'↶ 撤销','PhotoUndo',@(~,~)uiRun(@undo)); undoBtn.Tooltip='Ctrl+Z';
            redoBtn=button(editBar,'↷ 重做','PhotoRedo',@(~,~)uiRun(@redo)); redoBtn.Tooltip='Ctrl+Y / Ctrl+Shift+Z';
            cropQuickBtn=button(editBar,'裁剪…','PhotoCropQuick',@(~,~)uiRun(@beginCrop));
            historyLabel=label(editBar,'打开照片开始编辑',C.muted,11,'PhotoHistory');
            restoreBtn=button(editBar,'恢复完整构图','PhotoRestoreGeometry',@(~,~)uiRun(@restoreGeometry));
            viewBar=uigridlayout(view,[1 5],'ColumnWidth',{142,126,65,'1x',50}, ...
                'Padding',[0 0 0 0],'BackgroundColor',C.bg);
            viewDrop=uidropdown(viewBar,'Items',{'分割对比','处理后','处理前','去噪残差','细节增量','原图频谱'}, ...
                'ItemsData',{'split','result','original','removed','enhanced','spectrum'}, ...
                'Value','split','Tag','PhotoView','ValueChangedFcn',@(s,~)uiRun(@()setView(s.Value)), ...
                'BackgroundColor',C.input,'FontColor',C.text);
            zoomDrop=uidropdown(viewBar,'Items',{'适应窗口','100% 细节'},'ItemsData',{'fit','100'}, ...
                'Value','fit','Tag','PhotoZoom','ValueChangedFcn',@(s,~)uiRun(@()setZoom(s.Value)), ...
                'BackgroundColor',C.input,'FontColor',C.text);
            splitLabel=label(viewBar,'分界位置',C.muted,11,'PhotoSplitLabel');
            splitSlider=uislider(viewBar,'Limits',[0 1],'Value',.5,'MajorTicks',[],'MinorTicks',[], ...
                'Tag','PhotoSplit','ValueChangedFcn',@(s,~)setSplit(s.Value));
            splitText=label(viewBar,'50%',C.muted,11,'PhotoSplitValue');
            lessonViewButton=button(viewBar,'交互教程：从照片到频谱','PhotoViewSpectrumLesson',@(~,~)uiRun(@openLesson));
            lessonViewButton.Layout.Row=1; lessonViewButton.Layout.Column=[3 5]; lessonViewButton.Visible='off';
            canvas=uipanel(view,'BackgroundColor',[.08 .09 .10],'BorderType','none','Tag','PhotoCanvas');
            canvasGrid=uigridlayout(canvas,[1 1],'Padding',[0 0 0 0],'BackgroundColor',[.08 .09 .10]);
            ax=uiaxes(canvasGrid,'Tag','PhotoAxes','Color',[.08 .09 .10],'XTick',[],'YTick',[], ...
                'Box','off','XColor',[.08 .09 .10],'YColor',[.08 .09 .10]);
            ax.Toolbar.Visible='off'; ax.Interactions=[]; ax.YDir='reverse';
            ax.DataAspectRatio=[1 1 1]; ax.PlotBoxAspectRatioMode='auto';
            ax.PositionConstraint='innerposition'; ax.LooseInset=[0 0 0 0];
            img=image(ax,'CData',zeros(2,2,3,'single'),'Tag','PhotoImage','Visible','off');
            img.ButtonDownFcn=@(~,~)startDrag();
            hold(ax,'on'); divider=line(ax,[1 1],[1 2],'Color',[.93 .94 .95],'LineWidth',1,'Visible','off','HitTest','off');
            cropShades=gobjects(1,4);
            for k=1:4
                cropShades(k)=patch(ax,'XData',nan(1,4),'YData',nan(1,4),'FaceColor','k', ...
                    'FaceAlpha',.5,'EdgeColor','none','HitTest','off','Visible','off');
            end
            cropFrame=rectangle(ax,'Position',[1 1 1 1],'EdgeColor',C.blue,'LineWidth',1.5, ...
                'Visible','off','HitTest','off','Tag','PhotoCropFrame');
            cropHandles=plot(ax,nan(1,4),nan(1,4),'s','MarkerSize',8,'MarkerFaceColor',C.blue, ...
                'MarkerEdgeColor','w','LineStyle','none','Visible','off','HitTest','off');
            set([divider cropShades cropFrame cropHandles],'PickableParts','none');
            maskOverlay=image(ax,'CData',zeros(2,2,3,'single'),'AlphaData',0,'Visible','off','HitTest','off','PickableParts','none','Tag','PhotoMaskOverlay');
            focusGuide=plot(ax,nan,nan,'-','Color',C.blue,'LineWidth',1.5,'HitTest','off','PickableParts','none','Tag','PhotoFocusGuide');
            brushTrail=plot(ax,nan,nan,'-','Color',[1 .35 .3],'LineWidth',2,'HitTest','off','PickableParts','none','Tag','PhotoBrushTrail');
            brushRing=plot(ax,nan,nan,'-','Color',[1 .8 .7],'LineWidth',1,'HitTest','off','PickableParts','none','Tag','PhotoBrushRing');
            welcome=text(ax,1,1,{'打开一张照片','去噪 · 锐化 · 色彩 · 构图'},'Color',C.muted, ...
                'HorizontalAlignment','center','FontSize',17,'Tag','PhotoWelcome','HitTest','off');
            ax.XLim=[0 2]; ax.YLim=[0 2];
            nav=uigridlayout(view,[1 6],'ColumnWidth',{38,38,38,38,'1x',120}, ...
                'Padding',[0 0 0 0],'BackgroundColor',C.bg);
            leftBtn=button(nav,'←','PhotoPanLeft',@(~,~)panPixels(-160,0));
            rightBtn=button(nav,'→','PhotoPanRight',@(~,~)panPixels(160,0));
            upBtn=button(nav,'↑','PhotoPanUp',@(~,~)panPixels(0,-160));
            downBtn=button(nav,'↓','PhotoPanDown',@(~,~)panPixels(0,160));
            viewHint=label(nav,'左：原图    右：处理后',C.muted,11,'PhotoViewHint');
            sizeLabel=label(nav,'',C.muted,11,'PhotoSize'); sizeLabel.HorizontalAlignment='right';
            side=uigridlayout(body,[3 1],'RowHeight',{48,'1x',78},'Padding',[12 12 12 12], ...
                'RowSpacing',10,'BackgroundColor',C.panel);
            toolDrop=uidropdown(side,'Items',{'色彩校正','去噪','锐化与细节','构图','频域画笔','微缩景观','运动轨迹','局部蒙版','照片滤波器'}, ...
                'ItemsData',{'PhotoTabColor','PhotoTabDenoise','PhotoTabSharpen','PhotoTabEdit','PhotoTabFrequency','PhotoTabTilt','PhotoTabMotion','PhotoTabMask','PhotoTabClassic'}, ...
                'Value','PhotoTabColor','Tag','PhotoToolSelect','BackgroundColor',C.input,'FontColor',C.text, ...
                'ValueChangedFcn',@(s,~)selectToolTab(s.Value));
            tabs=uitabgroup(side,'Tag','PhotoTabs');
            colorTab=uitab(tabs,'Title','色彩','BackgroundColor',C.panel,'Tag','PhotoTabColor');
            denoiseTab=uitab(tabs,'Title','去噪','BackgroundColor',C.panel,'Tag','PhotoTabDenoise');
            sharpTab=uitab(tabs,'Title','锐化','BackgroundColor',C.panel,'Tag','PhotoTabSharpen');
            editTab=uitab(tabs,'Title','构图','BackgroundColor',C.panel,'Tag','PhotoTabEdit');
            creativeTags={'PhotoTabFrequency','PhotoTabTilt','PhotoTabMotion','PhotoTabMask','PhotoTabClassic'};
            creativeTitles={'频域','微缩','运动','蒙版','滤波'};
            for k=1:numel(creativeTags)
                uitab(tabs,'Title',creativeTitles{k},'BackgroundColor',C.panel,'Tag',creativeTags{k});
            end
            buildToolTab('PhotoTabColor');
            tabs.SelectionChangedFcn=@(~,~)toolTabChanged();
            footer=label(side,{'工作空间：sRGB · 原文件保持不变','导出尺寸跟随裁剪与旋转结果。','P3 / Adobe RGB 请先转换为 sRGB。'},C.muted,11,'PhotoProfile');
            footer.WordWrap='on';
            fig.WindowButtonMotionFcn=@(~,~)dragPhoto(); fig.WindowButtonUpFcn=@(~,~)uiRun(@finishStroke);
            fig.WindowScrollWheelFcn=@(~,e)panPixels(0,60*e.VerticalScrollCount);
        catch ex
            if ~isempty(body)&&isgraphics(body), delete(body); end
            loadedTools={}; controls=struct();
            rethrow(ex);
        end
        editorReady=true;
        if ~isempty(landing)&&isgraphics(landing), delete(landing); end
        landing=[]; enterBtn=[]; firstOpen=[];
        layout.RowHeight={66,'1x',42}; body.Visible='on';
        perf.EditorReady=true; perf.EditorBuildSeconds=toc(buildClock);
        setappdata(fig,'PhotoPerformance',perf);
    end

    function h=label(parent,txt,color,sz,tag)
        h=uilabel(parent,'Text',txt,'FontColor',color,'FontSize',sz,'Tag',tag,'FontName','Microsoft YaHei UI');
    end
    function h=button(parent,txt,tag,cb)
        h=uibutton(parent,'Text',txt,'Tag',tag,'ButtonPushedFcn',cb, ...
            'BackgroundColor',C.input,'FontColor',C.text,'FontSize',12,'FontName','Microsoft YaHei UI');
    end
    function g=controlGrid(parent,n)
        g=uigridlayout(parent,[n 1],'RowHeight',repmat({25},1,n), ...
            'Padding',[14 14 14 14],'RowSpacing',5,'BackgroundColor',C.panel,'Scrollable','on');
    end
    function addFlag(g,key,txt,row)
        h=uicheckbox(g,'Text',txt,'Value',ST.Spec.(key),'FontColor',C.text,'FontSize',12, ...
            'Tag',['Photo_' key],'ValueChangedFcn',@(s,~)uiRun(@()change(key,s.Value)));
        h.Layout.Row=row; controls.(key)=h;
    end
    function addSlider(g,key,txt,lo,hi,row,fmt)
        lineGrid=uigridlayout(g,[1 2],'ColumnWidth',{'1x',64},'Padding',[0 0 0 0],'BackgroundColor',C.panel);
        lineGrid.Layout.Row=row;
        label(lineGrid,txt,C.text,12,['PhotoLabel_' key]);
        val=label(lineGrid,sprintf(fmt,ST.Spec.(key)),C.muted,12,['PhotoValue_' key]); val.HorizontalAlignment='right';
        h=uislider(g,'Limits',[lo hi],'Value',ST.Spec.(key),'MajorTicks',[], ...
            'MinorTicks',[],'Tag',['Photo_' key],'ValueChangedFcn',@(s,~)uiRun(@()change(key,s.Value)), ...
            'ValueChangingFcn',@(~,e)set(val,'Text',sprintf(fmt,e.Value)));
        h.Layout.Row=row+1; controls.(key)=h; controls.([key 'Text'])=val;
        setappdata(h,'Format',fmt);
    end
    function built=buildToolTab(tag)
        built=~any(strcmp(loadedTools,tag));
        if ~built, return; end
        switch char(tag)
            case 'PhotoTabColor'
                cg=controlGrid(colorTab,21); addFlag(cg,'ColorEnable','启用色彩校正',1);
                addFlag(cg,'AutoWB','自动白平衡（谨慎使用）',2);
                addSlider(cg,'Temperature','冷暖',-100,100,3,'%+.0f');
                addSlider(cg,'Tint','色调 · 绿 / 洋红',-100,100,5,'%+.0f');
                addSlider(cg,'Exposure','曝光 / EV',-3,3,7,'%+.2f');
                addSlider(cg,'Contrast','对比度',-1,1,9,'%+.2f');
                addSlider(cg,'Highlights','高光',-1,1,11,'%+.2f');
                addSlider(cg,'Shadows','阴影',-1,1,13,'%+.2f');
                addSlider(cg,'Vibrance','自然饱和度',-1,1,15,'%+.2f');
                addSlider(cg,'Saturation','饱和度',-1,1,17,'%+.2f');
                wbNote=label(cg,'自动白平衡找不到中性色时保持原色。',C.muted,11,'PhotoWBNote');
                wbNote.Layout.Row=[19 20]; wbNote.WordWrap='on';
            case 'PhotoTabDenoise'
                dg=controlGrid(denoiseTab,15); addFlag(dg,'DenoiseEnable','启用保边去噪',1);
                addFlag(dg,'AutoNoise','自动估噪并联动锐化阈值',2);
                addSlider(dg,'LumaDenoise','亮度去噪（手动）',0,1,3,'%.2f');
                addSlider(dg,'ColorDenoise','色彩去噪（手动）',0,1,5,'%.2f');
                addSlider(dg,'Detail','细节保留',0,1,7,'%.2f');
                noiseLabel=label(dg,'打开照片后显示噪声估计',C.text,11,'PhotoNoiseEstimate');
                noiseLabel.Layout.Row=[9 11]; noiseLabel.WordWrap='on';
                note=label(dg,{'自动模式以原尺寸计算，可能稍慢。','估计来自低纹理区域，密集纹理可能误判。','去噪残差中若有清晰纹理，请改用手动。'},C.muted,11,'PhotoDenoiseNote');
                note.Layout.Row=[12 15]; note.WordWrap='on';
            case 'PhotoTabSharpen'
                sg=controlGrid(sharpTab,22); addFlag(sg,'SharpenEnable','启用亮度锐化与细节',1);
                addSlider(sg,'SharpenAmount','锐化强度',0,2,2,'%.2f');
                addSlider(sg,'SharpenRadius','半径 / 原图像素',.3,5,4,'%.2f');
                addSlider(sg,'SharpenThreshold','噪声阈值下限',0,.1,6,'%.3f');
                addSlider(sg,'FineDetail','细小纹理',-1,1,8,'%+.2f');
                addSlider(sg,'Clarity','结构清晰度',-1,1,10,'%+.2f');
                addSlider(sg,'LocalContrast','局部对比度',-1,1,12,'%+.2f');
                addSlider(sg,'HaloSuppression','光晕抑制',0,1,14,'%.2f');
                note=label(sg,{'负值柔化，正值增强；先从小幅度调整。','光晕抑制越高，边缘过冲越少。','细节增量：中灰为零变化，亮为增加，暗为减少。','请以 100% 视图判断最终细节。'},C.muted,11,'PhotoSharpenNote');
                note.Layout.Row=[16 22]; note.WordWrap='on';
            case 'PhotoTabEdit'
                eg=controlGrid(editTab,20);
                rotGrid=uigridlayout(eg,[1 2],'Padding',[0 0 0 0],'BackgroundColor',C.panel); rotGrid.Layout.Row=1;
                rotateLeftBtn=button(rotGrid,'左转 90°','PhotoRotateLeft',@(~,~)uiRun(@()rotatePhoto(1)));
                rotateRightBtn=button(rotGrid,'右转 90°','PhotoRotateRight',@(~,~)uiRun(@()rotatePhoto(-1)));
                flipGrid=uigridlayout(eg,[1 2],'Padding',[0 0 0 0],'BackgroundColor',C.panel); flipGrid.Layout.Row=3;
                flipHBtn=button(flipGrid,'水平翻转','PhotoFlipH',@(~,~)uiRun(@()flipPhoto('horizontal')));
                flipVBtn=button(flipGrid,'垂直翻转','PhotoFlipV',@(~,~)uiRun(@()flipPhoto('vertical')));
                h=label(eg,'裁剪比例',C.text,12,'PhotoCropRatioLabel'); h.Layout.Row=5;
                ratioDrop=uidropdown(eg,'Items',{'自由','当前比例','1 : 1','4 : 3','3 : 2','16 : 9','3 : 4','2 : 3','9 : 16'}, ...
                    'ItemsData',cropRatios,'Value',ST.CropRatio,'Tag','PhotoCropRatio', ...
                    'BackgroundColor',C.input,'FontColor',C.text,'ValueChangedFcn',@(s,~)uiRun(@()setCropRatio(s.Value)));
                ratioDrop.Layout.Row=6;
                cropBtn=button(eg,'开始裁剪','PhotoCropBegin',@(~,~)uiRun(@beginCrop)); cropBtn.Layout.Row=8;
                fieldsGrid=uigridlayout(eg,[2 4],'ColumnWidth',{24,'1x',24,'1x'},'Padding',[0 0 0 0], ...
                    'BackgroundColor',C.panel); fieldsGrid.Layout.Row=[10 11];
                cropFields=gobjects(1,4); names={'X','Y','宽','高'};
                for k=1:4
                    rr=ceil(k/2); cc=1+2*mod(k-1,2);
                    h=label(fieldsGrid,names{k},C.muted,11,['PhotoCropLabel' num2str(k)]); h.Layout.Row=rr; h.Layout.Column=cc;
                    cropFields(k)=uieditfield(fieldsGrid,'numeric','Value',1,'Limits',[1 Inf], ...
                        'RoundFractionalValues','on','ValueDisplayFormat','%.0f','Tag',['PhotoCropField' num2str(k)], ...
                        'BackgroundColor',C.input,'FontColor',C.text,'ValueChangedFcn',@(~,~)uiRun(@()cropFieldChanged(k)));
                    cropFields(k).Layout.Row=rr; cropFields(k).Layout.Column=cc+1;
                end
                cropSizeLabel=label(eg,'选区坐标以当前原尺寸照片为准',C.muted,11,'PhotoCropSize'); cropSizeLabel.Layout.Row=12;
                applyGrid=uigridlayout(eg,[1 2],'Padding',[0 0 0 0],'BackgroundColor',C.panel); applyGrid.Layout.Row=14;
                applyCropBtn=button(applyGrid,'应用裁剪','PhotoCropApply',@(~,~)uiRun(@applyCrop));
                applyCropBtn.BackgroundColor=C.blue; applyCropBtn.FontColor=[.06 .10 .13];
                cancelCropBtn=button(applyGrid,'取消','PhotoCropCancel',@(~,~)uiRun(@cancelCrop));
                note=label(eg,{'拖动框内移动，拖动角点缩放。','在框外拖出新选区，也可输入精确尺寸。','Enter 应用 · Esc 取消','裁剪后仍可撤销，或恢复完整构图。'},C.muted,11,'PhotoCropNote');
                note.Layout.Row=[16 20]; note.WordWrap='on';
            otherwise
                creativeUI=fl_creative_controls(tabs,ST.Creative,callbacks,tag,creativeUI);
        end
        loadedTools{end+1}=char(tag);
    end
    function uiRun(f)
        try, f(); catch ex
            if isvalid(fig)
                status.Text=['操作未完成：' ex.message]; syncControls();
                if strcmp(fig.Visible,'on'), uialert(fig,ex.message,'无法完成操作'); end
            end
        end
    end
    function beginBusy(msg)
        if ST.Busy, error('FL_photo:busy','正在处理，请稍候。'); end
        ST.Busy=true; status.Text=msg; updateEnabled(); publish();
        if ~directFileOpen, drawnow; end
    end
    function finishBusy()
        if ~isvalid(fig), return; end
        ST.Busy=false; updateEnabled(); publish();
        if ~directFileOpen, drawnow limitrate; end
    end
    function loadFile(path)
        openClock=tic;
        beginBusy('正在读取与预览照片…'); done=onCleanup(@finishBusy); %#ok<NASGU>
        decodeClock=tic; [X,meta]=fl_photo_load(path); decodeSeconds=toc(decodeClock);
        ensureEditor(); previewClock=tic; spec=fl_photo_spec();
        creative=fl_creative_spec();
        [P,Q,full,ps,fs,info]=calculate(X,spec,false,creative,{},size(X));
        previewSeconds=toc(previewClock);
        ST.Original=X; ST.Working=X; ST.Preview=P; ST.PreviewResult=Q; ST.FullResult=full;
        ST.PreviewStages=ps; ST.FullStages=fs; ST.Info=info;
        ST.FullValid=~isempty(full); ST.Spec=spec; ST.Source=meta.Source; ST.Meta=meta; ST.OutputMeta=meta;
        ST.Creative=creative; ST.Tool='none'; ST.ShowMask=false; ST.Spectrum=[]; spectrumBase=[];
        ST.ViewMode='split'; viewDrop.Value='split';
        ST.Geometry={}; ST.CropActive=false; ST.CropRect=[]; ST.CropRatio=0;
        if ~isempty(ratioDrop), ratioDrop.Value=0; end
        cropDrag=struct(); cropReturn=struct(); stopDrag();
        history={snapshot('打开照片')}; historyIndex=1;
        ST.Zoom='fit'; ST.Center=[(size(X,2)+1)/2 (size(X,1)+1)/2];
        [~,name,ext]=fileparts(path); sourceLabel.Text=[name ext]; sourceLabel.Tooltip=meta.Source;
        zoomDrop.Value='fit'; syncControls(); render();
        status.Text=sprintf('已载入 %d × %d · 预览 %d × %d · %s',meta.Width,meta.Height,size(P,2),size(P,1),meta.ProfileNote);
        clear done; % Release Busy and restore enabled controls before timing the open.
        if ~isgraphics(fig), return; end
        if strcmp(fig.Visible,'on'), drawnow nocallbacks; end
        perf.LastOpenSeconds=toc(openClock); perf.LastDecodeSeconds=decodeSeconds;
        perf.LastPreviewSeconds=previewSeconds; setappdata(fig,'PhotoPerformance',perf);
    end
    function change(key,value)
        next=ST.Spec; next.(key)=value; setSpec(next);
    end
    function setSpec(next)
        if ST.CropActive, error('FL_photo:cropActive','请先应用或取消裁剪。'); end
        applyState(fl_photo_spec(next),ST.Geometry,'调整照片参数',true);
    end
    function changed=applyState(next,geometry,name,record,creative)
        if nargin<5, creative=ST.Creative; end
        changed=~(isequal(next,ST.Spec)&&isequal(geometry,ST.Geometry)&&isequal(creative,ST.Creative));
        if ~changed, return; end
        beginBusy('正在应用编辑…'); done=onCleanup(@finishBusy); %#ok<NASGU>
        changedGeometry=~isequal(geometry,ST.Geometry);
        changedSpectrum=changedGeometry||creative.FrequencyKeepDC~=ST.Creative.FrequencyKeepDC|| ...
            ~isequal(creative.FrequencyStrokes,ST.Creative.FrequencyStrokes);
        if ~isempty(ST.Original)
            if changedGeometry
                working=fl_photo_geometry(ST.Original,geometry); preview=[];
            else, working=ST.Working; preview=ST.Preview; end
            [preview,processed,full,ps,fs,info]=calculate(working,next,strcmp(ST.Zoom,'100')&&~changedGeometry,creative,geometry,size(ST.Original),preview);
            ST.Working=working; ST.Preview=preview; ST.PreviewResult=processed;
            ST.PreviewStages=ps; ST.FullStages=fs; ST.Info=info;
            ST.FullResult=full; ST.FullValid=~isempty(full);
            ST.OutputMeta=ST.Meta; ST.OutputMeta.Width=size(working,2); ST.OutputMeta.Height=size(working,1);
            if changedGeometry
                ST.Zoom='fit'; zoomDrop.Value='fit';
                ST.Center=[(size(working,2)+1)/2 (size(working,1)+1)/2];
            end
        end
        if changedGeometry, spectrumBase=[]; end
        if changedSpectrum, ST.Spectrum=[]; end
        ST.Spec=next; ST.Geometry=geometry; ST.Creative=creative; ST.CropActive=false; stopDrag();
        if record&&~isempty(ST.Original)
            history=history(1:historyIndex); history{end+1}=snapshot(name);
            if numel(history)>51, history=history(end-50:end); end
            historyIndex=numel(history);
        end
        syncControls(); render(); status.Text=[name ' · Ctrl+Z 撤销 · 导出使用编辑后的完整分辨率'];
    end
    function state=snapshot(name)
        state=struct('Spec',ST.Spec,'Geometry',{ST.Geometry},'Creative',ST.Creative,'Label',name);
    end
    function undo()
        if ST.Busy||ST.CropActive||historyIndex<=1, return; end
        target=historyIndex-1; state=history{target};
        applyState(state.Spec,state.Geometry,['撤销至：' state.Label],false,state.Creative);
        historyIndex=target; updateEnabled(); publish();
    end
    function redo()
        if ST.Busy||ST.CropActive||historyIndex>=numel(history), return; end
        target=historyIndex+1; state=history{target};
        applyState(state.Spec,state.Geometry,['重做：' state.Label],false,state.Creative);
        historyIndex=target; updateEnabled(); publish();
    end
    function reset()
        if ST.CropActive, cancelCrop(); end
        ST.Tool='none'; ST.ShowMask=false; stopDrag();
        if strcmp(ST.ViewMode,'spectrum'), ST.ViewMode='result'; viewDrop.Value='result'; end
        if ~applyState(fl_photo_spec(),{},'重置全部编辑',true,fl_creative_spec()), render(); end
    end
    function requirePhoto()
        if isempty(ST.Original), error('FL_photo:empty','请先打开照片。'); end
        if ST.Busy, error('FL_photo:busy','正在处理，请稍候。'); end
    end
    function geometryOperation(op,name)
        requirePhoto();
        if ST.CropActive, error('FL_photo:cropActive','请先应用或取消裁剪。'); end
        applyState(ST.Spec,[ST.Geometry {op}],name,true);
    end
    function rotatePhoto(turns)
        validateattributes(turns,{'numeric'},{'real','finite','scalar','integer'});
        requirePhoto(); if mod(turns,4)==0, return; end
        geometryOperation(struct('Type','rotate','Value',turns),'旋转照片');
    end
    function flipPhoto(direction)
        switch char(direction)
            case 'horizontal', kind='flip-h'; name='水平翻转';
            case 'vertical', kind='flip-v'; name='垂直翻转';
            otherwise, error('FL_photo:flip','翻转方向请选择 horizontal 或 vertical。');
        end
        geometryOperation(struct('Type',kind),name);
    end
    function cropPhoto(rect)
        requirePhoto(); validateCrop(rect);
        if isequal(double(rect(:)'),[1 1 size(ST.Working,2) size(ST.Working,1)])
            if ST.CropActive, cancelCrop(); end
            return;
        end
        applyState(ST.Spec,[ST.Geometry {struct('Type','crop','Value',double(rect(:)'))}],'裁剪照片',true);
    end
    function restoreGeometry()
        if ST.CropActive, cancelCrop(); end
        applyState(ST.Spec,{},'恢复完整构图',true);
    end
    function [p,q,full,ps,fs,info]=calculate(x,spec,needFull,creative,geometry,originalSize,p)
        context=struct('OriginalSize',originalSize,'Geometry',{geometry});
        if nargin<7||isempty(p), p=fl_photo_resize(x,1200); end
        full=[]; fs=struct();
        if needFull||spec.AutoNoise||creative.FrequencyEnable||~strcmp(creative.ClassicType,'off')
            [full,info,fs]=fl_photo_pipeline(x,spec,creative,context); q=fl_photo_resize(full,1200);
            if isequal(size(p),size(x)), ps=fs; else
                % Both signed residuals use the same linear antialiasing transform.
                % Pack them into two channels and do one resize for the pair.
                denoiseCode=.5+.5*fs.DenoiseResidual;
                small=fl_photo_resize(cat(3,denoiseCode,.5+.5*fs.DetailResidual,denoiseCode),1200);
                ps=struct('DenoiseResidual',2*small(:,:,1)-1,'DetailResidual',2*small(:,:,2)-1);
            end
        else
            [q,info,ps]=fl_photo_pipeline(p,spec,creative,context);
            if isequal(size(p),size(x)), full=q; fs=ps; end
        end
    end
    function ensureFull()
        if ~ST.FullValid
            status.Text='正在计算完整分辨率照片…'; drawnow;
            [ST.FullResult,ST.Info,ST.FullStages]=fl_photo_pipeline(ST.Working,ST.Spec,ST.Creative,maskContext()); ST.FullValid=true;
        end
    end
    function child=openAssignment()
        if isempty(assignmentPanel)||~isvalid(assignmentPanel), assignmentPanel=mountWorkspace(@FL_assignment_gui,assignmentPage); end
        workspaceTabs.SelectedTab=assignmentPage; child=assignmentPanel;
    end
    function child=openExtensions()
        if isempty(extensionsPanel)||~isvalid(extensionsPanel)
            extensionsPanel=mountWorkspace(@FL_extensions_gui,extensionsPage);
        end
        workspaceTabs.SelectedTab=extensionsPage; child=extensionsPanel;
    end
    function child=openFreqTools()
        if isempty(freqToolsPanel)||~isvalid(freqToolsPanel)
            freqToolsPanel=mountWorkspace(@FL_freqtools_gui,freqToolsPage);
        end
        workspaceTabs.SelectedTab=freqToolsPage; child=freqToolsPanel;
    end
    function panel=mountWorkspace(builder,page)
        host=uigridlayout(page,[1 1],'Padding',[0 0 0 0]);
        try, panel=builder('Parent',host); catch ex, delete(host); rethrow(ex); end
    end
    function workspaceChanged()
        if workspaceTabs.SelectedTab==assignmentPage
            openAssignment();
        elseif workspaceTabs.SelectedTab==extensionsPage
            openExtensions();
        elseif workspaceTabs.SelectedTab==freqToolsPage
            openFreqTools();
        else
            refreshViewport();
        end
    end
    function context=maskContext()
        context=struct('OriginalSize',size(ST.Original),'Geometry',{ST.Geometry});
    end
    function selectToolTab(tag)
        h=findobj(tabs,'Tag',tag); if ~isempty(h), tabs.SelectedTab=h; toolTabChanged(); end
    end
    function toolTabChanged()
        if buildToolTab(tabs.SelectedTab.Tag), syncCreativeControls(); updateEnabled(); publish(); end
        toolDrop.Value=tabs.SelectedTab.Tag;
        expected=struct('mask','PhotoTabMask','frequency','PhotoTabFrequency','tilt','PhotoTabTilt','motion','PhotoTabMotion');
        if ~strcmp(ST.Tool,'none')&&~strcmp(tabs.SelectedTab.Tag,expected.(ST.Tool))
            setTool('none');
        end
    end
    function creativeChange(key,value)
        next=ST.Creative; next.(key)=value; setCreative(next);
    end
    function setCreative(next)
        if ST.CropActive, error('FL_photo:cropActive','请先应用或取消裁剪。'); end
        applyState(ST.Spec,ST.Geometry,'调整创意效果',true,fl_creative_spec(next));
    end
    function setTool(tool)
        requirePhoto(); tool=validatestring(tool,{'none','mask','frequency','tilt','motion'});
        if ST.CropActive, error('FL_photo:cropActive','请先应用或取消裁剪。'); end
        ST.Tool=tool; ST.ShowMask=strcmp(tool,'mask');
        switch tool
            case 'frequency', selectToolTab('PhotoTabFrequency'); mode='spectrum';
            case 'mask', selectToolTab('PhotoTabMask'); mode='result';
            case 'tilt', selectToolTab('PhotoTabTilt'); mode='result';
            case 'motion', selectToolTab('PhotoTabMotion'); mode='result';
            otherwise
                mode=ST.ViewMode; if strcmp(mode,'spectrum'), mode='result'; end
        end
        setView(mode);
        if strcmp(tool,'none'), status.Text='已结束绘制 · Ctrl+Z 撤销上一笔';
        else, status.Text='拖动绘制或定位，松开应用 · Esc 结束工具 · Ctrl+Z 撤销'; end
    end
    function maskOperation(op)
        requirePhoto();
        if ST.CropActive, error('FL_photo:cropActive','请先应用或取消裁剪。'); end
        if strcmp(op,'show'), ST.ShowMask=~ST.ShowMask; render(); return; end
        next=ST.Creative; next.MaskEnable=true; next.MaskInvert=false; next.MaskStrokes={};
        switch op
            case 'clear', next.MaskBase=0;
            case 'fill', next.MaskBase=1;
            otherwise, error('FL_photo:mask','未知蒙版操作。');
        end
        applyState(ST.Spec,ST.Geometry,'修改局部蒙版',true,next);
    end
    function paintMask(points,radius,opacity,mode)
        requirePhoto(); validateattributes(points,{'numeric'},{'real','finite','2d','nonempty','ncols',2,'>=',0,'<=',1});
        [transform,sz]=fl_mask_transform(size(ST.Original),ST.Geometry);
        p=.5+double(points).*[sz(2) sz(1)]; p=[p ones(size(p,1),1)]/transform';
        p=(p(:,1:2)-.5)./[size(ST.Original,2) size(ST.Original,1)]; p=min(1,max(0,p));
        stroke=struct('Points',p,'Radius',radius*min(sz)/min(size(ST.Original,1),size(ST.Original,2)), ...
            'Opacity',opacity,'Mode',mode);
        next=ST.Creative; next.MaskEnable=true; next.MaskStrokes{end+1}=stroke;
        if ST.CropActive, error('FL_photo:cropActive','请先应用或取消裁剪。'); end
        applyState(ST.Spec,ST.Geometry,'局部蒙版笔触',true,fl_creative_spec(next));
    end
    function paintFrequency(points,radius,opacity,mode)
        requirePhoto(); stroke=struct('Points',points,'Radius',radius,'Opacity',opacity,'Mode',mode);
        next=ST.Creative; next.FrequencyEnable=true; next.FrequencyStrokes{end+1}=stroke;
        if ST.CropActive, error('FL_photo:cropActive','请先应用或取消裁剪。'); end
        applyState(ST.Spec,ST.Geometry,'频域画笔笔触',true,fl_creative_spec(next));
    end
    function clearFrequency()
        next=ST.Creative; next.FrequencyStrokes={}; setCreative(next);
    end
    function setFocus(tool,point)
        requirePhoto(); validateattributes(point,{'numeric'},{'real','finite','numel',2,'>=',0,'<=',1});
        next=ST.Creative;
        if strcmp(tool,'tilt'), next.TiltCenter=reshape(point,1,2); next.TiltEnable=true;
        elseif strcmp(tool,'motion'), next.MotionCenter=reshape(point,1,2); next.MotionEnable=true;
        else, error('FL_photo:focus','定位请选择 tilt 或 motion。'); end
        setCreative(next);
    end
    function point=toolPoint()
        q=ax.CurrentPoint; sz=size(img.CData);
        point=min(1,max(0,(q(1,1:2)-.5)./[sz(2) sz(1)]));
        if strcmp(ST.Tool,'frequency'), point=point-.5; end
    end
    function showBrushTrail()
        if isempty(strokePoints)||~any(strcmp(ST.Tool,{'mask','frequency'})), return; end
        h=size(img.CData,1); w=size(img.CData,2); points=strokePoints;
        if strcmp(ST.Tool,'frequency'), points=points+.5; radii=creativeUI.FrequencyRadius.Value*[w h];
        else, radii=creativeUI.MaskRadius.Value*min(h,w)*[1 1]; end
        xy=.5+points.*[w h]; brushTrail.XData=xy(:,1); brushTrail.YData=xy(:,2); brushTrail.Visible='on';
        angle=linspace(0,2*pi,60); brushRing.XData=xy(end,1)+radii(1)*cos(angle); brushRing.YData=xy(end,2)+radii(2)*sin(angle); brushRing.Visible='on';
    end
    function finishStroke()
        if ~strokeActive, stopDrag(); return; end
        points=strokePoints; tool=ST.Tool; stopDrag();
        switch tool
            case 'mask', paintMask(points,creativeUI.MaskRadius.Value,creativeUI.MaskOpacity.Value,creativeUI.MaskMode.Value);
            case 'frequency', paintFrequency(points,creativeUI.FrequencyRadius.Value,creativeUI.FrequencyOpacity.Value,creativeUI.FrequencyMode.Value);
            case {'tilt','motion'}, setFocus(tool,points(end,:));
        end
    end
    function refreshCreativeOverlay(imageSize)
        maskOverlay.Visible='off'; focusGuide.Visible='off';
        if ST.CropActive||strcmp(ST.ViewMode,'spectrum'), return; end
        h=imageSize(1); w=imageSize(2);
        if ST.ShowMask
            config=ST.Creative; config.MaskEnable=true; M=fl_photo_mask(imageSize,config,maskContext());
            red=zeros(h,w,3,'single'); red(:,:,1)=1;
            maskOverlay.CData=red; maskOverlay.AlphaData=.35*M; maskOverlay.XData=[1 w]; maskOverlay.YData=[1 h]; maskOverlay.Visible='on';
        end
        if strcmp(ST.Tool,'tilt'), showFocusPoint(ST.Creative.TiltCenter);
        elseif strcmp(ST.Tool,'motion'), showFocusPoint(ST.Creative.MotionCenter); end
    end
    function showFocusPoint(point)
        h=size(img.CData,1); w=size(img.CData,2); center=.5+point.*[w h];
        if strcmp(ST.Tool,'tilt')
            direction=[cosd(ST.Creative.TiltAngle) sind(ST.Creative.TiltAngle)]*max(h,w);
            normal=[-sind(ST.Creative.TiltAngle) cosd(ST.Creative.TiltAngle)]*ST.Creative.TiltWidth*min(h,w)/2;
            xs=[-direction(1) direction(1) nan]; ys=[-direction(2) direction(2) nan];
            focusGuide.XData=center(1)+[xs-normal(1) xs xs+normal(1)];
            focusGuide.YData=center(2)+[ys-normal(2) ys ys+normal(2)];
        else
            r=.03*min(h,w); focusGuide.XData=center(1)+[-r r nan 0 0]; focusGuide.YData=center(2)+[0 0 nan -r r];
        end
        focusGuide.Visible='on';
    end
    function validateCrop(rect)
        validateattributes(rect,{'numeric'},{'real','finite','vector','numel',4,'integer','positive'});
        if rect(1)+rect(3)-1>size(ST.Working,2)||rect(2)+rect(4)-1>size(ST.Working,1)
            error('FL_photo:cropBounds','选区超出当前照片，请减小尺寸或调整位置。');
        end
    end
    function ratio=cropRatio()
        ratio=ST.CropRatio;
        if ratio==-1, ratio=size(ST.Working,2)/size(ST.Working,1); end
    end
    function beginCrop()
        requirePhoto(); if ST.CropActive, return; end
        ST.Tool='none'; ST.ShowMask=false; stopDrag();
        if strcmp(ST.ViewMode,'spectrum'), ST.ViewMode='result'; viewDrop.Value='result'; end
        cropReturn=struct('Zoom',ST.Zoom,'Center',ST.Center);
        ST.Zoom='fit'; zoomDrop.Value='fit'; ST.CropActive=true;
        selectToolTab('PhotoTabEdit'); resetCropBox(); updateEnabled(); render();
        fig.Pointer='crosshair'; status.Text='裁剪：拖动框内移动、角点缩放；Enter 应用，Esc 取消';
    end
    function resetCropBox()
        w=size(ST.Working,2); h=size(ST.Working,1);
        ratio=cropRatio(); cw=max(1,round(w*.8)); ch=max(1,round(h*.8));
        if ratio>0
            if cw/ch>ratio, cw=max(1,round(ch*ratio)); else, ch=max(1,round(cw/ratio)); end
        end
        ST.CropRect=[floor((w-cw)/2)+1 floor((h-ch)/2)+1 cw ch];
    end
    function setCropRatio(value)
        validateattributes(value,{'numeric'},{'real','finite','scalar'});
        if ~any(value==cropRatios), error('FL_photo:ratio','请选择列表中的裁剪比例。'); end
        ST.CropRatio=value;
        if ~isempty(ratioDrop), ratioDrop.Value=value; end
        if ST.CropActive, resetCropBox(); refreshCropOverlay(); end
        publish();
    end
    function setCropRect(rect)
        requirePhoto();
        if ~ST.CropActive, error('FL_photo:cropInactive','请先开始裁剪。'); end
        validateCrop(rect); r=cropRatio();
        if r>0&&abs(rect(3)-rect(4)*r)>max(1,r)
            error('FL_photo:cropRatio','选区尺寸不符合所选比例；任意尺寸请选择自由裁剪。');
        end
        ST.CropRect=double(rect(:)'); refreshCropOverlay(); publish();
    end
    function cropFieldChanged(index)
        if ~ST.CropActive, return; end
        rect=ST.CropRect; rect(index)=cropFields(index).Value;
        w=size(ST.Working,2); h=size(ST.Working,1); r=cropRatio();
        if index<=2
            rect(1)=max(1,min(w-rect(3)+1,rect(1))); rect(2)=max(1,min(h-rect(4)+1,rect(2)));
        else
            if r>0
                if index==3, rect(4)=max(1,round(rect(3)/r)); else, rect(3)=max(1,round(rect(4)*r)); end
                scale=min([1 w/rect(3) h/rect(4)]); rect(3:4)=max(1,round(rect(3:4)*scale));
            else
                rect(3)=min(w,rect(3)); rect(4)=min(h,rect(4));
            end
            rect(1)=min(rect(1),w-rect(3)+1); rect(2)=min(rect(2),h-rect(4)+1);
        end
        setCropRect(rect);
    end
    function applyCrop()
        if ~ST.CropActive, return; end
        cropPhoto(ST.CropRect);
    end
    function cancelCrop()
        if ~ST.CropActive||ST.Busy, return; end
        ST.CropActive=false; cropDrag=struct(); stopDrag();
        if ~isempty(fieldnames(cropReturn))
            ST.Zoom=cropReturn.Zoom; ST.Center=cropReturn.Center; zoomDrop.Value=ST.Zoom;
        end
        render(); updateEnabled(); publish(); status.Text='已取消裁剪 · 照片未改变';
    end
    function refreshCropOverlay()
        enabled=ST.CropActive&&~isempty(ST.Working);
        set(cropShades,'Visible',onoff(enabled)); cropFrame.Visible=onoff(enabled); cropHandles.Visible=onoff(enabled);
        if ~enabled, return; end
        rect=ST.CropRect; pw=size(ST.Preview,2); ph=size(ST.Preview,1);
        scale=[pw/size(ST.Working,2) ph/size(ST.Working,1)];
        edge=.5+(rect(1:2)-1).*scale; extent=rect(3:4).*scale;
        x=edge(1); y=edge(2); right=x+extent(1); bottom=y+extent(2);
        cropFrame.Position=[edge extent]; cropHandles.XData=[x right right x]; cropHandles.YData=[y y bottom bottom];
        boxes=[.5 .5 pw y-.5; .5 bottom pw ph+.5-bottom; .5 y x-.5 extent(2); right y pw+.5-right extent(2)];
        for j=1:4
            b=boxes(j,:); cropShades(j).XData=[b(1) b(1)+b(3) b(1)+b(3) b(1)];
            cropShades(j).YData=[b(2) b(2) b(2)+b(4) b(2)+b(4)];
            cropFields(j).Value=rect(j);
        end
        cropSizeLabel.Text=sprintf('输出 %d × %d 像素',rect(3),rect(4));
    end
    function point=cropPoint()
        q=ax.CurrentPoint; pw=size(ST.Preview,2); ph=size(ST.Preview,1);
        point=floor((q(1,1:2)-.5).*[size(ST.Working,2)/pw size(ST.Working,1)/ph])+1;
        point=min([size(ST.Working,2) size(ST.Working,1)],max([1 1],point));
    end
    function startCropDrag()
        p=cropPoint(); r=ST.CropRect;
        corners=[r(1) r(2);r(1)+r(3)-1 r(2);r(1)+r(3)-1 r(2)+r(4)-1;r(1) r(2)+r(4)-1];
        pos=ax.InnerPosition; tolerance=10*max(size(ST.Working,2)/max(1,pos(3)),size(ST.Working,1)/max(1,pos(4)));
        [distance,index]=min(sum((corners-p).^2,2));
        if distance<=tolerance^2
            cropDrag=struct('Mode','resize','Anchor',corners(mod(index+1,4)+1,:));
        elseif p(1)>=r(1)&&p(1)<r(1)+r(3)&&p(2)>=r(2)&&p(2)<r(2)+r(4)
            cropDrag=struct('Mode','move','Anchor',p,'Rect',r);
        else
            cropDrag=struct('Mode','resize','Anchor',p);
        end
    end
    function moveCropDrag()
        if ~isfield(cropDrag,'Mode'), return; end
        p=cropPoint(); w=size(ST.Working,2); h=size(ST.Working,1);
        if strcmp(cropDrag.Mode,'move')
            r=cropDrag.Rect; r(1:2)=r(1:2)+p-cropDrag.Anchor;
            r(1)=min(w-r(3)+1,max(1,r(1))); r(2)=min(h-r(4)+1,max(1,r(2)));
        else
            r=fl_photo_crop_rect([h w],cropDrag.Anchor,p,cropRatio());
        end
        ST.CropRect=r; refreshCropOverlay(); publish();
    end
    function keyPress(e)
        if ST.Busy||workspaceTabs.SelectedTab~=photoPage, return; end
        if strcmp(e.Key,'escape')&&~strcmp(ST.Tool,'none'), setTool('none'); return; end
        if ST.CropActive
            if strcmp(e.Key,'escape'), cancelCrop(); elseif strcmp(e.Key,'return'), applyCrop(); end
            return;
        end
        if any(strcmp(e.Modifier,'control'))||any(strcmp(e.Modifier,'command'))
            if strcmp(e.Key,'z')&&any(strcmp(e.Modifier,'shift')), redo();
            elseif strcmp(e.Key,'z'), undo();
            elseif strcmp(e.Key,'y'), redo(); end
        end
    end
    function setZoom(mode)
        mode=char(mode); if ~any(strcmp(mode,{'fit','100'})), error('FL_photo:zoom','未知缩放模式。'); end
        if isempty(ST.Original)||ST.CropActive||strcmp(ST.ViewMode,'spectrum'), return; end
        beginBusy('正在切换查看模式…'); done=onCleanup(@finishBusy); %#ok<NASGU>
        if strcmp(mode,'100'), ensureFull(); end
        ST.Zoom=mode; zoomDrop.Value=mode; render();
        if strcmp(mode,'100')
            status.Text='100% 原图像素 · 拖动照片、滚轮或方向按钮可查看其他区域';
        else
            status.Text='适应窗口 · 缩略预览；细节效果请切换 100% 检查';
        end
    end
    function setView(mode)
        mode=char(mode); if ~any(strcmp(mode,{'original','result','split','removed','enhanced','spectrum'})), error('FL_photo:view','未知对比方式。'); end
        if ST.Busy||ST.CropActive, return; end
        if any(strcmp(mode,{'removed','enhanced'}))&&~isempty(ST.Original)
            beginBusy('正在准备细节检查…'); done=onCleanup(@finishBusy); %#ok<NASGU>
            ensureFull(); ST.Zoom='100'; zoomDrop.Value='100'; ST.Tool='none'; ST.ShowMask=false;
        end
        if ~editorReady, enterEditor(); end
        if strcmp(mode,'spectrum'), ST.Zoom='fit'; zoomDrop.Value='fit'; end
        if strcmp(ST.Tool,'frequency')&&~strcmp(mode,'spectrum'), ST.Tool='none'; end
        if strcmp(mode,'spectrum')&&~strcmp(ST.Tool,'frequency'), ST.Tool='none'; ST.ShowMask=false; end
        stopDrag(); ST.ViewMode=mode; viewDrop.Value=mode; updateEnabled(); render();
    end
    function setSplit(value)
        validateattributes(value,{'numeric'},{'scalar','finite','>=',0,'<=',1});
        if ST.Busy||ST.CropActive, return; end
        if ~editorReady, enterEditor(); end
        ST.Split=value; splitSlider.Value=value; splitText.Text=sprintf('%.0f%%',value*100); render();
    end
    function render()
        if isempty(ST.Original), publish(); return; end
        if strcmp(ST.Zoom,'100'), A=ST.Working; B=ST.FullResult; else, A=ST.Preview; B=ST.PreviewResult; end
        if strcmp(ST.ViewMode,'spectrum')&&~ST.CropActive
            if isempty(ST.Spectrum), [ST.Spectrum,~,spectrumBase]=fl_frequency_view(ST.Working,ST.Creative,spectrumBase); end
            img.CData=ST.Spectrum; img.XData=[1 size(ST.Spectrum,2)]; img.YData=[1 size(ST.Spectrum,1)]; img.Visible='on';
            ST.Result=B; welcome.Visible='off'; divider.Visible='off'; maskOverlay.Visible='off'; focusGuide.Visible='off';
            viewHint.Text='原图亮度频谱 · 中心为 DC · 红色为抑制频率 · 切回处理后查看效果';
            refreshCropOverlay(); refreshViewport(); publish(); return;
        end
        if ST.CropActive
            shown=B; viewHint.Text='拖动选框或角点 · Enter 应用 · Esc 取消';
        else
            switch ST.ViewMode
                case 'original', shown=A; viewHint.Text='处理前';
                case 'result', shown=B; viewHint.Text='处理后';
                case {'removed','enhanced'}
                    if strcmp(ST.Zoom,'100'), d=ST.FullStages; else, d=ST.PreviewStages; end
                    if strcmp(ST.ViewMode,'removed')
                        residual=d.DenoiseResidual; viewHint.Text='去噪前 − 去噪后 · 亮度差 ×4，中灰为零';
                    else
                        residual=d.DetailResidual; viewHint.Text='细节处理后 − 去噪后 · 亮度差 ×4，中灰为零';
                    end
                    shown=repmat(min(1,max(0,.5+4*residual)),1,1,3);
                otherwise
                    shown=B; cut=round(size(A,2)*ST.Split); shown(:,1:cut,:)=A(:,1:cut,:);
                    viewHint.Text='左：处理前    右：处理后';
            end
            if ~isempty(ST.Geometry), viewHint.Text=[viewHint.Text ' · 相同构图']; end
        end
        ST.Result=B; img.CData=shown; img.XData=[1 size(A,2)]; img.YData=[1 size(A,1)]; img.Visible='on';
        welcome.Visible='off';
        if strcmp(ST.ViewMode,'split')&&~ST.CropActive
            divider.XData=[1 1]*(.5+round(size(A,2)*ST.Split)); divider.YData=[.5 size(A,1)+.5]; divider.Visible='on';
        else, divider.Visible='off'; end
        sizeLabel.Text=sprintf('%d × %d',ST.OutputMeta.Width,ST.OutputMeta.Height);
        refreshCropOverlay(); refreshCreativeOverlay(size(A)); refreshViewport(); publish();
    end
    function refreshViewport()
        if ~isvalid(fig)||isempty(ST.Original), return; end
        if strcmp(ST.ViewMode,'spectrum')
            ax.XLim=[.5 size(img.CData,2)+.5]; ax.YLim=[.5 size(img.CData,1)+.5]; return;
        end
        if strcmp(ST.Zoom,'fit')
            ax.XLim=[.5 size(ST.Preview,2)+.5]; ax.YLim=[.5 size(ST.Preview,1)+.5];
        else
            drawnow limitrate;
            pos=ax.InnerPosition; vw=max(1,pos(3)); vh=max(1,pos(4));
            w=ST.OutputMeta.Width; h=ST.OutputMeta.Height;
            if w<=vw, ST.Center(1)=(w+1)/2; else, ST.Center(1)=min(w+.5-vw/2,max(.5+vw/2,ST.Center(1))); end
            if h<=vh, ST.Center(2)=(h+1)/2; else, ST.Center(2)=min(h+.5-vh/2,max(.5+vh/2,ST.Center(2))); end
            ax.XLim=ST.Center(1)+[-vw vw]/2; ax.YLim=ST.Center(2)+[-vh vh]/2;
        end
    end
    function panPixels(dx,dy)
        if ST.Busy||ST.CropActive||~strcmp(ST.Tool,'none')||~strcmp(ST.Zoom,'100')||isempty(ST.Original), return; end
        ST.Center=ST.Center+[dx dy]; refreshViewport(); publish();
    end
    function startDrag()
        if ST.Busy, return; end
        if ST.CropActive, startCropDrag(); return; end
        if ~strcmp(ST.Tool,'none')
            strokeActive=true; strokePoints=toolPoint(); fig.Pointer='crosshair'; showBrushTrail(); return;
        end
        if ~strcmp(ST.Zoom,'100'), return; end
        dragStart=fig.CurrentPoint; dragCenter=ST.Center; fig.Pointer='fleur';
    end
    function dragPhoto()
        if ST.Busy, return; end
        if ST.CropActive, moveCropDrag(); return; end
        if strokeActive
            q=toolPoint();
            if norm(q-strokePoints(end,:))>.001, strokePoints(end+1,:)=q; end
            if any(strcmp(ST.Tool,{'tilt','motion'})), showFocusPoint(q); else, showBrushTrail(); end
            return;
        end
        if isempty(dragStart), return; end
        movement=fig.CurrentPoint-dragStart;
        ST.Center=dragCenter+[-movement(1) movement(2)]; refreshViewport(); publish();
    end
    function stopDrag()
        dragStart=[]; cropDrag=struct(); strokePoints=[]; strokeActive=false;
        if editorReady, brushTrail.Visible='off'; brushRing.Visible='off'; end
        if isvalid(fig)
            if ST.CropActive||~strcmp(ST.Tool,'none'), fig.Pointer='crosshair'; else, fig.Pointer='arrow'; end
        end
    end
    function exportTo(path)
        if isempty(ST.Original), error('FL_photo:empty','请先打开照片。'); end
        if ST.CropActive, error('FL_photo:cropActive','请先应用或取消裁剪再导出。'); end
        beginBusy('正在准备完整分辨率导出…'); done=onCleanup(@finishBusy); %#ok<NASGU>
        ensureFull(); fl_photo_save(path,ST.FullResult,ST.OutputMeta,'Quality',95,'BitDepth',8);
        status.Text=sprintf('已导出 %d × %d 像素：%s',ST.OutputMeta.Width,ST.OutputMeta.Height,path);
    end
    function openDialog()
        [name,folder]=uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp','照片文件'},'打开照片');
        if isequal(name,0), return; end
        loadFile(fullfile(folder,name));
    end
    function exportDialog()
        [~,name]=fileparts(ST.Source);
        [file,folder]=uiputfile({'*.png','PNG 无损照片';'*.jpg','JPEG 照片';'*.tif','TIFF 照片'}, ...
            '另存为新照片',fullfile(fileparts(ST.Source),[name '_edited.png']));
        if isequal(file,0), return; end
        exportTo(fullfile(folder,file));
    end
    function savePreset(path)
        Spec=ST.Spec; Creative=ST.Creative; Creative.MaskStrokes={}; Creative.MaskEnable=false; Creative.MaskInvert=false; Creative.MaskBase=0;
        Format='FilterLabPhoto-v1'; %#ok<NASGU>
        save(path,'Spec','Creative','Format'); status.Text=['已保存参数：' path];
    end
    function loadPreset(path)
        data=load(path);
        if ~isfield(data,'Spec')||~isfield(data,'Format')||~strcmp(data.Format,'FilterLabPhoto-v1')
            error('FL_photo:preset','请选择 FilterLab 照片版保存的参数文件。');
        end
        if ST.CropActive, error('FL_photo:cropActive','请先应用或取消裁剪。'); end
        creative=fl_creative_spec();
        if isfield(data,'Creative'), creative=fl_creative_spec(data.Creative); end
        % Parameter presets do not replace this photo's spatial mask.
        for key={'MaskStrokes','MaskEnable','MaskBase','MaskInvert','MaskSoftness','MaskTarget'}, creative.(key{1})=ST.Creative.(key{1}); end
        applyState(fl_photo_spec(data.Spec),ST.Geometry,'载入参数预设',true,creative);
    end
    function savePresetDialog()
        [file,folder]=uiputfile('*.mat','保存照片参数','photo-preset.mat');
        if ~isequal(file,0), savePreset(fullfile(folder,file)); end
    end
    function loadPresetDialog()
        [file,folder]=uigetfile('*.mat','载入照片参数');
        if ~isequal(file,0), loadPreset(fullfile(folder,file)); end
    end
    function syncControls()
        keys=fieldnames(ST.Spec);
        for i=1:numel(keys)
            key=keys{i}; if ~isfield(controls,key), continue; end
            controls.(key).Value=ST.Spec.(key);
            if isfield(controls,[key 'Text'])
                controls.([key 'Text']).Text=sprintf(getappdata(controls.(key),'Format'),ST.Spec.(key));
            end
        end
        syncCreativeControls();
    end
    function syncCreativeControls()
        keys=fieldnames(creativeUI.Controls);
        for j=1:numel(keys)
            key=keys{j}; h=creativeUI.Controls.(key); h.Value=ST.Creative.(key);
            if isappdata(h,'CreativeLabel'), set(getappdata(h,'CreativeLabel'),'Text',sprintf('%s  %.3g',getappdata(h,'CreativeTitle'),h.Value)); end
        end
    end
    function updateEnabled()
        available=~ST.Busy; hasPhoto=~isempty(ST.Original); editing=available&&~ST.CropActive;
        openBtn.Enable=onoff(editing); loadPresetBtn.Enable=onoff(editing); savePresetBtn.Enable=onoff(editing);
        resetBtn.Enable=onoff(editing); exportBtn.Enable=onoff(editing&&hasPhoto);
        assignmentBtn.Enable=onoff(available);
        if ~editorReady
            if ~isempty(enterBtn), enterBtn.Enable=onoff(editing); firstOpen.Enable=onoff(editing); end
            return;
        end
        viewDrop.Enable=onoff(editing&&hasPhoto); zoomDrop.Enable=onoff(editing&&hasPhoto);
        spectrumView=strcmp(ST.ViewMode,'spectrum');
        set([splitLabel splitText],'Visible',onoff(~spectrumView));
        splitSlider.Visible=onoff(~spectrumView);
        lessonViewButton.Visible=onoff(spectrumView); lessonViewButton.Enable=onoff(available);
        if isfield(creativeUI,'LessonButton'), creativeUI.LessonButton.Enable=onoff(available); end
        splitSlider.Enable=onoff(editing&&hasPhoto&&strcmp(ST.ViewMode,'split'));
        undoBtn.Enable=onoff(editing&&historyIndex>1); redoBtn.Enable=onoff(editing&&historyIndex<numel(history));
        restoreBtn.Enable=onoff(editing&&hasPhoto&&~isempty(ST.Geometry));
        set([cropQuickBtn cropBtn rotateLeftBtn rotateRightBtn flipHBtn flipVBtn],'Enable',onoff(editing&&hasPhoto));
        if ~isempty(ratioDrop), ratioDrop.Enable=onoff(available&&hasPhoto); end
        set([applyCropBtn cancelCropBtn],'Enable',onoff(available&&ST.CropActive));
        set(cropFields,'Enable',onoff(available&&ST.CropActive));
        keys=fieldnames(controls);
        for i=1:numel(keys)
            h=controls.(keys{i}); if isprop(h,'Enable'), h.Enable=onoff(editing); end
        end
        toolDrop.Enable=onoff(available);
        keys=fieldnames(creativeUI.Controls);
        for j=1:numel(keys), creativeUI.Controls.(keys{j}).Enable=onoff(editing); end
        set(creativeUI.Buttons,'Enable',onoff(editing&&hasPhoto));
        zoomDrop.Enable=onoff(editing&&hasPhoto&&~strcmp(ST.ViewMode,'spectrum'));
        if isfield(controls,'LumaDenoise')
            controls.LumaDenoise.Enable=onoff(editing&&~ST.Spec.AutoNoise);
            controls.ColorDenoise.Enable=onoff(editing&&~ST.Spec.AutoNoise);
        end
        enablePan=onoff(editing&&hasPhoto&&strcmp(ST.Zoom,'100'));
        leftBtn.Enable=enablePan; rightBtn.Enable=enablePan; upBtn.Enable=enablePan; downBtn.Enable=enablePan;
        if historyIndex>0
            historyLabel.Text=sprintf('%s · %d 步可撤销',history{historyIndex}.Label,historyIndex-1);
        else, historyLabel.Text='打开照片开始编辑'; end
    end
    function v=onoff(flag)
        if flag, v='on'; else, v='off'; end
    end
    function publish()
        ST.HistoryIndex=historyIndex; ST.HistoryLabels=cellfun(@(s)s.Label,history,'UniformOutput',false);
        ST.CanUndo=historyIndex>1; ST.CanRedo=historyIndex<numel(history);
        if ~isempty(noiseLabel)&&isfield(ST.Info,'Noise')
            n=ST.Info.Noise;
            noiseLabel.Text=sprintf('亮度噪声估计 ≈ %.2f / 255（可信度：%s）\n有效亮度 / 色彩去噪：%.2f / %.2f\n有效锐化阈值：%.3f', ...
                n.SigmaLuma*255,n.Confidence,ST.Info.EffectiveLumaDenoise,ST.Info.EffectiveColorDenoise,ST.Info.EffectiveThreshold);
        end
        if isvalid(fig), setappdata(fig,'PhotoState',ST); end
    end
    function closeApp()
        if ST.Busy, status.Text='正在处理，请等待完成后关闭窗口。'; return; end
        if ~isempty(assignmentPanel)&&isvalid(assignmentPanel)
            other=getappdata(assignmentPanel,'AssignmentState'); if other.Busy, return; end
        end
        if ~isempty(extensionsPanel)&&isvalid(extensionsPanel)
            other=getappdata(extensionsPanel,'ExtensionsState'); if other.Busy, return; end
        end
        if ~isempty(freqToolsPanel)&&isvalid(freqToolsPanel)
            other=getappdata(freqToolsPanel,'FreqToolsState'); if other.Busy, return; end
        end
        delete(fig);
    end
end
