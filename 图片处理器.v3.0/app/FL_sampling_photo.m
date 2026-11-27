function panel = FL_sampling_photo(parent)
%FL_SAMPLING_PHOTO Interactive ROI sampling comparison in an empty uitab.
% api = getappdata(panel,'SamplingPhotoActions'); api.Load(path);
% api.SetROI([x y width height]); api.SetStep(d); r = api.GetResult();
if ~isdeployed, addpath(fullfile(fileparts(mfilename('fullpath')),'core')); end
theme = fl_ui_theme();
paper = theme.Paper; ink = theme.Ink; muted = theme.Muted; font = 'Microsoft YaHei UI';
fig = ancestor(parent,'figure'); source = []; step = 4; result = []; drag = [];
zooms = [1 2 4 8 16]; viewport = []; lastLayout = [];
moveFcn = @moveDrag; upFcn = @endDrag;
panel = uigridlayout(parent,[1 1],'Padding',[0 0 0 0],'Tag','SamplingPhotoPanel');
panel.DeleteFcn = @(~,~)releaseDrag();
try
    shell = uipanel(panel,'BorderType','none','BackgroundColor',paper,'AutoResizeChildren','off');
    root = uigridlayout(shell,[4 1],'Scrollable','on','ColumnWidth',{'1x'}, ...
        'Padding',[14 10 14 10],'RowSpacing',8,'BackgroundColor',paper);
    header = grid(root,1,3,paper); header.ColumnWidth = {'1x',94,84};
    titleText = label(header,'照片采样对照',19,ink,''); titleText.FontWeight = 'bold';
    open = button(header,'打开照片…','SamplingPhotoLoad',@chooseFile);
    open.BackgroundColor = theme.Accent; open.FontColor = theme.White;
    button(header,'内置织样','SamplingPhotoDemo',@demo);

    tools = grid(root,1,2,paper); tools.ColumnWidth = {290,'1x'};
    sampling = grid(tools,1,4,paper); sampling.ColumnWidth = {68,56,46,100};
    label(sampling,'步长（px）',13,ink,'');
    stepBox = uispinner(sampling,'Limits',[1 16],'Step',1,'RoundFractionalValues','on', ...
        'Value',step,'Tag','SamplingPhotoStep','FontName',font, ...
        'Tooltip','行、列每隔 1–16 个原图像素取一点。输入整数后按 Enter。', ...
        'ValueChangedFcn',@(s,~)guard(@()setStep(s.Value)));
    label(sampling,'倍率',13,ink,'');
    zoomBox = uidropdown(sampling,'Items',{'1× 全区','2×','4×','8×','16×'}, ...
        'ItemsData',zooms,'Value',1,'Tag','SamplingPhotoZoom','FontName',font, ...
        'Tooltip','两幅结果相对完整选区同步放大。用方向键选择倍率。', ...
        'ValueChangedFcn',@zoomChanged);
    centers = grid(tools,1,5,paper); centers.ColumnWidth = {44,64,44,64,'1x'};
    label(centers,'中心列',12,muted,''); xBox = centerBox(centers,'SamplingPhotoCenterX');
    label(centers,'中心行',12,muted,''); yBox = centerBox(centers,'SamplingPhotoCenterY');
    hint = label(centers,'点击结果可定位到同一采样点。',12,muted,'SamplingPhotoViewHint');

    % One plate sets the title baseline and gives both canvases the same footprint.
    views = grid(root,3,2,paper); views.ColumnWidth = {'1x','1x'}; views.ColumnSpacing = 8;
    leftTitle = label(views,'直接抽样',17,ink,'SamplingPhotoDirectTitle');
    rightTitle = label(views,'先低通，再抽样',17,ink,'SamplingPhotoLowpassTitle');
    leftTitle.FontWeight = 'bold'; rightTitle.FontWeight = 'bold';
    leftTitle.Layout.Row = 1; leftTitle.Layout.Column = 1;
    rightTitle.Layout.Row = 1; rightTitle.Layout.Column = 2;
    [rawAx,rawImg] = canvas(views,'Direct',2,1);
    [lpAx,lpImg] = canvas(views,'Lowpass',2,2);
    for im = [rawImg lpImg]
        im.HitTest = 'on'; im.PickableParts = 'all'; im.ButtonDownFcn = @locate;
    end
    meta = grid(views,1,2,paper); meta.Layout.Row = 3; meta.Layout.Column = [1 2];
    status = label(meta,'',12,ink,'SamplingPhotoStatus');
    note = label(meta,'',12,muted,'SamplingPhotoMethod');

    overview = grid(root,1,3,theme.Panel); overview.Padding = [8 6 8 6];
    [nav,navImg] = thumbnail(overview,'原图定位（拖框）','Navigator');
    [origAx,origImg] = thumbnail(overview,'选区原图','Original');
    navImg.HitTest = 'on'; navImg.PickableParts = 'all'; navImg.ButtonDownFcn = @startDrag;
    frameHalo = rectangle('Parent',nav,'Position',[.5 .5 1 1],'EdgeColor',theme.Canvas, ...
        'LineWidth',4,'HitTest','off','PickableParts','none');
    frame = rectangle('Parent',nav,'Position',[.5 .5 1 1],'EdgeColor',theme.AccentLight, ...
        'LineWidth',1.6,'HitTest','off','PickableParts','none','Tag','SamplingPhotoFrame');
    focusFrame = rectangle('Parent',origAx,'Position',[.5 .5 1 1],'EdgeColor',theme.White, ...
        'LineWidth',1.5,'LineStyle','--','HitTest','off','PickableParts','none','Tag','SamplingPhotoViewFrame');
    info = grid(overview,3,1,theme.Panel); info.RowHeight = {'1x',19,28}; info.RowSpacing = 3;
    sourceName = label(info,'',15,ink,'SamplingPhotoName'); sourceName.FontWeight = 'bold';
    label(info,'选区：起始列、起始行、宽、高（px）',12,muted,'');
    roiRow = grid(info,1,2,theme.Panel); roiRow.ColumnWidth = {'1x',78};
    roiBox = uieditfield(roiRow,'text','FontName',font,'Tag','SamplingPhotoROI', ...
        'Tooltip','拖动原图框选，或输入起始列、起始行、宽度、高度，按 Enter。坐标从 1 开始。', ...
        'ValueChangedFcn',@(s,~)guard(@()applyROIText(s.Value)));
    button(roiRow,'选取全图','SamplingPhotoReset',@resetROI);
    setappdata(panel,'SamplingPhotoActions',struct('Load',@loadFile,'Demo',@demo, ...
        'SetROI',@setROI,'SetStep',@setStep,'ResetROI',@resetROI,'GetResult',@getResult, ...
        'SetView',@setView,'GetView',@getView));
    fitLayout(); shell.SizeChangedFcn = @(~,~)fitLayout(); demo();
catch err
    delete(panel); rethrow(err);
end
    function g = grid(host,nRows,nCols,bg)
        g = uigridlayout(host,[nRows nCols],'Padding',[0 0 0 0], ...
            'ColumnSpacing',6,'RowSpacing',4,'BackgroundColor',bg);
    end
    function textLabel = label(host,text,sz,color,tag)
        textLabel = uilabel(host,'Text',text,'FontName',font,'FontSize',sz,'FontColor',color,'Tag',tag);
    end
    function control = button(host,text,tag,action)
        control = uibutton(host,'Text',text,'FontName',font,'FontColor',ink,'Tag',tag, ...
            'ButtonPushedFcn',@(~,~)guard(action));
    end
    function control = centerBox(host,tag)
        control = uispinner(host,'Limits',[1 Inf],'Step',1,'RoundFractionalValues','on', ...
            'Value',1,'Tag',tag,'FontName',font,'Tooltip','选区内的采样点编号，从 1 开始。输入后按 Enter。', ...
            'ValueChangedFcn',@centerChanged);
    end
    function zoomChanged(s,~)
        guard(@()setView(s.Value,viewport.Center));
    end
    function centerChanged(~,~)
        guard(@()setView(viewport.Zoom,[xBox.Value yBox.Value]));
    end
    function [ax,img] = thumbnail(host,text,key)
        g = grid(host,2,1,theme.Panel); g.RowHeight = {20,'1x'};
        heading = label(g,text,12,muted,''); heading.FontWeight = 'bold';
        [ax,img] = canvas(g,key,2,1);
    end
    function [ax,img] = canvas(host,key,row,col)
        mat = grid(host,1,1,theme.Canvas); mat.Layout.Row = row; mat.Layout.Column = col;
        ax = uiaxes(mat,'Tag',['SamplingPhoto' key 'Axes'],'Color',theme.Canvas);
        ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
        ax.Visible = 'off'; ax.YDir = 'reverse'; ax.DataAspectRatio = [1 1 1];
        ax.PositionConstraint = 'innerposition'; ax.LooseInset = [0 0 0 0];
        img = image('Parent',ax,'CData',zeros(2,2,3,'single'),'HitTest','off', ...
            'PickableParts','none','Tag',['SamplingPhoto' key]);
        if isprop(img,'Interpolation'), img.Interpolation = 'nearest'; end
    end
    function fitLayout()
        sz = round(shell.Position(3:4));
        if isequal(sz,lastLayout), return; end
        lastLayout = sz;
        if sz(1) < 680
            tools.RowHeight = {28,28}; centers.Layout.Row = 2; centers.Layout.Column = 1;
            tools.ColumnWidth = {'1x'}; toolH = 60;
            meta.RowHeight = {18,18}; note.Layout.Row = 2; note.Layout.Column = 1;
            meta.ColumnWidth = {'1x'}; note.HorizontalAlignment = 'left'; metaH = 40;
            overview.RowHeight = {85,78}; info.Layout.Row = 2; info.Layout.Column = [1 2];
            overview.ColumnWidth = {'1x','1x'}; overviewH = 179;
        else
            tools.ColumnWidth = {290,'1x'}; centers.Layout.Row = 1; centers.Layout.Column = 2;
            tools.RowHeight = {'1x'}; toolH = 30;
            meta.ColumnWidth = {'1x',180}; note.Layout.Row = 1; note.Layout.Column = 2;
            meta.RowHeight = {'1x'}; note.HorizontalAlignment = 'right'; metaH = 22;
            thumb = max(116,min(194,round(.18*sz(1))));
            overview.ColumnWidth = {thumb,thumb,'1x'}; info.Layout.Row = 1; info.Layout.Column = 3;
            overview.RowHeight = {'1x'}; overviewH = max(110,min(142,round(.19*sz(2))));
        end
        hint.Visible = matlab.lang.OnOffSwitchState(sz(1)>=760);
        views.RowHeight = {28,'1x',metaH};
        % Keep both canvases comparable even in a short window. Allow scrolling below this size.
        root.ColumnWidth = {max(350,sz(1)-32)};
        plateH = max(170+metaH,sz(2)-44-34-toolH-overviewH);
        root.RowHeight = {34,toolH,plateH,overviewH};
    end
    function guard(action)
        try
            action();
        catch err
            releaseDrag();
            stepBox.Value = step; status.Text = err.message; status.Tooltip = err.message;
            if ~isempty(result)
                roiBox.Value = sprintf('%d  %d  %d  %d',result.ROI); drawFrame(result.ROI);
            end
        end
    end
    function chooseFile()
        [file,folder] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp','照片（JPEG / PNG / TIFF / BMP）'},'选择照片');
        if ~isequal(file,0), loadFile(fullfile(folder,file)); end
    end
    function loadFile(path)
        [img,meta] = fl_photo_load(path); [~,name,ext] = fileparts(meta.Source);
        install(img,[name ext],meta.Source);
    end
    function demo()
        install(wovenSample(),'内置织样','宽色带、细斜纹和人字织纹');
    end
    function install(img,name,tip)
        releaseDrag(); [h,w,~] = size(img);
        cw = min(288,w); ch = min(180,h); roi = [1+floor((w-cw)/2) 1+floor((h-ch)/2) cw ch];
        next = fl_photo_samples(img,roi,step);
        source = img;
        showImage(nav,navImg,displayPixels(img),w,h);
        sourceName.Text = sprintf('%s   %d × %d px',name,w,h); sourceName.Tooltip = tip;
        render(next,1,[]);
    end
    function output = getResult()
        output = result;
    end
    function output = getView()
        output = viewport;
    end
    function resetROI()
        setROI([1 1 size(source,2) size(source,1)]);
    end
    function applyROIText(text)
        fields = regexp(strtrim(text),'[,，;；\s]+','split');
        if numel(fields) ~= 4 || any(cellfun(@isempty,regexp(fields,'^\d+$','once')))
            error('FL_sampling_photo:roiText','请按「起始列 起始行 宽 高」输入四个正整数。');
        end
        setROI(str2double(fields));
    end
    function setROI(roi)
        releaseDrag(); render(fl_photo_samples(source,roi,step),1,[]);
    end
    function setStep(d)
        releaseDrag(); next = fl_photo_samples(source,result.ROI,d);
        % Preserve the source location under inspection when the lattice changes.
        anchor = 1 + round((viewport.Center-1)*step/next.Step);
        render(next,viewport.Zoom,anchor);
    end
    function render(next,z,anchor)
        result = next; step = result.Step; stepBox.Value = step; roi = result.ROI;
        showImage(origAx,origImg,displayPixels(result.Original),roi(3),roi(4));
        roiBox.Value = sprintf('%d  %d  %d  %d',roi); drawFrame(roi);
        if step==1
            note.Text = '低通旁路，两幅结果相同';
        else
            note.Text = sprintf('高斯低通   σ = %.1f px',result.Sigma);
        end
        note.Tooltip = '核权重和为 1。跨选区边缘取真实邻像素，仅在照片边缘复制最近像素。';
        setView(z,anchor);
    end
    function setView(z,anchor)
        validateattributes(z,{'numeric'},{'scalar','real','finite'});
        if ~ismember(z,zooms), error('FL_sampling_photo:zoom','请选择 1、2、4、8 或 16 倍。'); end
        counts = [numel(result.SampleX) numel(result.SampleY)];
        if nargin<2 || isempty(anchor), anchor = 1+floor(counts/2); end
        validateattributes(anchor,{'numeric'},{'real','finite','numel',2});
        anchor = round(double(reshape(anchor,1,2)));
        extent = ceil(counts/double(z));
        first = max(1,min(counts-extent+1,anchor-floor(extent/2))); last = first+extent-1;
        cols = first(1):last(1); rows = first(2):last(2);
        % Crop native samples first. Zooming into a large image must reveal
        % actual samples, not magnify the area-averaged whole-view thumbnail.
        showImage(rawAx,rawImg,displayPixels(result.Direct(rows,cols,:)),extent(1),extent(2),first);
        showImage(lpAx,lpImg,displayPixels(result.Lowpass(rows,cols,:)),extent(1),extent(2),first);
        actual = first+floor(extent/2);
        viewport = struct('Zoom',double(z),'Center',actual,'Cols',[first(1) last(1)], ...
            'Rows',[first(2) last(2)],'SourceCols',result.SampleX([first(1) last(1)]), ...
            'SourceRows',result.SampleY([first(2) last(2)]));
        zoomBox.Value = z; xBox.Value = actual(1); yBox.Value = actual(2);
        xBox.Enable = matlab.lang.OnOffSwitchState(extent(1)<counts(1));
        yBox.Enable = matlab.lang.OnOffSwitchState(extent(2)<counts(2));
        startPx = (first-1)*step+.5;
        endPx = min(last*step,result.ROI(3:4))+.5;
        focusFrame.Position = [startPx endPx-startPx];
        focusFrame.Visible = matlab.lang.OnOffSwitchState(z>1);
        status.Text = sprintf('结果尺寸   %d × %d 点',counts(1),counts(2));
        if z > 1
            status.Text = sprintf('%s     列 %d–%d，行 %d–%d',status.Text,first(1),last(1),first(2),last(2));
        end
        status.Tooltip = sprintf('%s。两路对应原图第 %d–%d 列、第 %d–%d 行上的采样点。', ...
            status.Text,viewport.SourceCols,viewport.SourceRows);
    end
    function locate(im,event)
        if ~strcmp(fig.SelectionType,'normal'), return; end
        guard(@()setView(max(2,viewport.Zoom),pointer(event,im.Parent)));
    end
    function drawFrame(roi)
        pos = [roi(1:2)-.5 roi(3:4)]; frame.Position = pos; frameHalo.Position = pos;
    end
    function point = pointer(event,ax)
        if nargin < 2, ax = nav; end
        % A graphics hit event provides axes coordinates on mouse-down.
        % Figure motion/release events use the source axes' current point.
        if (isstruct(event) && isfield(event,'IntersectionPoint')) || ...
                (isobject(event) && isprop(event,'IntersectionPoint'))
            xyz = event.IntersectionPoint;
        else
            xyz = ax.CurrentPoint(1,:);
        end
        point = xyz(1:2);
    end
    function startDrag(~,event)
        if ~strcmp(fig.SelectionType,'normal'), return; end
        releaseDrag();
        drag = struct('Anchor',pointer(event),'OldMotion',{fig.WindowButtonMotionFcn}, ...
            'OldUp',{fig.WindowButtonUpFcn});
        fig.WindowButtonMotionFcn = moveFcn; fig.WindowButtonUpFcn = upFcn;
        drawFrame(dragRect(drag.Anchor));
    end
    function rect = dragRect(point)
        rect = fl_photo_crop_rect([size(source,1) size(source,2)],drag.Anchor,point,0);
    end
    function moveDrag(~,event)
        if isempty(drag), return; end
        drawFrame(dragRect(pointer(event)));
    end
    function endDrag(~,event)
        if isempty(drag), return; end
        guard(@()commitDrag(event));
    end
    function commitDrag(event)
        roi = dragRect(pointer(event)); releaseDrag(); setROI(roi);
    end
    function releaseDrag()
        if isempty(drag), return; end
        old = drag; drag = [];
        if ~isgraphics(fig), return; end
        if isequal(fig.WindowButtonMotionFcn,moveFcn), fig.WindowButtonMotionFcn = old.OldMotion; end
        if isequal(fig.WindowButtonUpFcn,upFcn), fig.WindowButtonUpFcn = old.OldUp; end
    end
end

function showImage(ax,img,data,w,h,first)
% first is the 1-based grid coordinate of the top left visible texel.
if nargin < 6, first = [1 1]; end
origin = first-.5;
[n,m,~] = size(data); dx = w/m; dy = h/n;
% MATLAB treats a singleton image dimension as one unit wide. Duplicate
% that texel for display so even a 1-row panorama fills its physical extent.
if m==1, data = data(:,[1 1],:); dx = w/2; end
if n==1, data = data([1 1],:,:); dy = h/2; end
img.CData = data; img.XData = origin(1)+[dx/2 w-dx/2]; img.YData = origin(2)+[dy/2 h-dy/2];
ax.XLim = origin(1)+[0 w]; ax.YLim = origin(2)+[0 h];
end

function out = displayPixels(img)
% Native texels for local comparisons. For a large view, average original
% pixels in disjoint bins. Both sampled panels always use identical bins.
[h,w,~] = size(img); scale = min(1,1024/max(h,w));
if scale==1, out=img; return; end
ny=max(1,round(h*scale)); nx=max(1,round(w*scale));
ye=round(linspace(0,h,ny+1)); xe=round(linspace(0,w,nx+1));
out=zeros(ny,nx,3,'single'); dx=diff(xe);
for ch=1:3
    for y=1:ny
        col=sum(img(ye(y)+1:ye(y+1),:,ch),1,'double');
        edge=[0 cumsum(col)]; out(y,:,ch)=diff(edge(xe+1))./(dx*(ye(y+1)-ye(y)));
    end
end
end

function img = wovenSample()
% Original woven swatch with bands much wider than the yarn spacing.
[x,y] = meshgrid(0:575,0:335);
fold = 4*sin(y/37)+2*cos((x+y)/49);
stripe = .5+.5*tanh(2.2*cos(2*pi*(x+.18*y+fold)/90));
weft = .09*cos(2*pi*(x/4.35+y/21+fold/7));
warp = .08*cos(2*pi*(y/5.1-x/32));
% Alternating orientation in the lower part produces a herringbone weave.
zig = abs(mod(x,80)-40); skirt = y>170+14*sin(x/82);
weft(skirt) = .16*cos(2*pi*(zig(skirt)/4.45+y(skirt)/8.4));
light = .04*cos((x-2*y)/124)+weft+warp;
img=single(cat(3,.30+.44*stripe+light,.47+.03*stripe+light,.51-.24*stripe+light));
img=max(0,min(1,img));
end
