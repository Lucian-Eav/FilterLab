function panel = FL_barrier_gui(varargin)
%FL_BARRIER_GUI Embedded two-frame barrier illusion workspace (MATLAB R2020b+).
% actions = getappdata(panel,'BarrierActions');
% actions.LoadA(path); actions.LoadB(path); paths = actions.Export(folder);
p = inputParser; p.addParameter('Parent',[]); p.addParameter('OpenSampling',[]); p.parse(varargin{:});
openSampling = p.Results.OpenSampling;
if isempty(p.Results.Parent), error('FL_barrier_gui:parent','请提供承载工作区的 Parent 布局。'); end
if ~isdeployed, addpath(fullfile(fileparts(mfilename('fullpath')),'core')); end
paper = [.96 .97 .98]; white = [1 1 1]; ink = [.10 .17 .22];
muted = [.26 .34 .39]; teal = [.03 .36 .42]; font = 'Microsoft YaHei UI';
panel = uipanel(p.Results.Parent,'BorderType','none','BackgroundColor',paper,'Tag','BarrierPanel');
try
    [sourceA,sourceB] = dayAndNight();
    frameWidth = 6; position = 0;
    result = fl_barrier_build(sourceA,sourceB,frameWidth);
    cache = buildCache(result.Base,frameWidth);
    root = uigridlayout(panel,[3 1],'RowHeight',{40,'1x',22},'ColumnWidth',{'1x'}, ...
        'RowSpacing',8,'Padding',[14 10 14 8],'BackgroundColor',paper);
    headerCols = {'1x',120,142};
    if ~isempty(openSampling), headerCols = {'1x',124,120,142}; end
    header = grid(root,headerCols,{'1x'},paper);
    heading = label(header,'栅栏图像错觉',20,ink,''); heading.FontWeight = 'bold';
    if ~isempty(openSampling)
        button(header,'观察采样点','BarrierOpenSampling',@(~,~)guard(openSampling));
    end
    mode = uidropdown(header,'Items',{'栅栏叠放','交错底图'},'ItemsData',{'overlay','base'}, ...
        'Value','overlay','Tag','BarrierMode','FontName',font,'ValueChangedFcn',@(~,~)selectMode());
    exportButton = button(header,'导出两张 PNG…','BarrierExport',@(~,~)guard(@chooseFolder));
    exportButton.BackgroundColor = teal; exportButton.FontColor = white;
    body = grid(root,{208,'1x'},{'1x'},paper); body.ColumnSpacing = 10;
    sidebar = grid(body,{'1x'},{24,32,22,32,22,42,26,32,'1x'},white);
    sidebar.RowSpacing = 4; sidebar.Padding = [12 8 12 8]; sidebar.Scrollable = 'on';
    section = label(sidebar,'图像来源',15,ink,''); section.FontWeight = 'bold';
    button(sidebar,'载入图像 A…','BarrierLoadA',@(~,~)guard(@()chooseSource('A')));
    nameA = label(sidebar,'日照山海（内置）',12,muted,'BarrierNameA');
    button(sidebar,'载入图像 B…','BarrierLoadB',@(~,~)guard(@()chooseSource('B')));
    nameB = label(sidebar,'海上生月（内置）',12,muted,'BarrierNameB');
    note = label(sidebar,'以 A 为画布，B 等比缩放后居中裁切。',12,muted,''); note.WordWrap = 'on';
    label(sidebar,'条宽（原图像素）',13,ink,'');
    widthBox = uieditfield(sidebar,'numeric','Limits',[1 Inf],'RoundFractionalValues','on', ...
        'Value',frameWidth,'FontName',font,'Tag','BarrierWidth','ValueChangedFcn',@(~,~)guard(@changeWidth));
    stage = grid(body,{'1x'},{'1x',30,36},white);
    stage.Padding = [8 6 8 4]; stage.RowSpacing = 2;
    ax = uiaxes(stage,'Tag','BarrierAxes','Color',white);
    previewImage = image('Parent',ax,'CData',cache.Base,'HitTest','off','Tag','BarrierPreview');
    ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
    ax.Visible = 'off'; ax.DataAspectRatio = [1 1 1]; ax.YDir = 'reverse';
    tools = grid(stage,{'1x',68,68},{'1x'},white);
    phaseLabel = label(tools,'',13,ink,'BarrierPhaseLabel'); phaseLabel.FontWeight = 'bold';
    button(tools,'显示 A','BarrierShowA',@(~,~)alignTo(0));
button(tools,'显示 B','BarrierShowB',@showB);
    sliderGrid = grid(stage,{'1x'},{'1x'},white); sliderGrid.Padding = [9 0 9 0];
    slider = uislider(sliderGrid,'Limits',[0 2*frameWidth],'Value',0,'MinorTicks',[], ...
        'Tag','BarrierOffset','FontName',font,'FontSize',11, ...
        'ValueChangingFcn',@(~,event)moveTo(event.Value,false), ...
        'ValueChangedFcn',@(control,~)moveTo(control.Value,true));
    status = label(root,'',12,muted,'BarrierStatus');
    actions = struct('LoadA',@(path)loadSource('A',path),'LoadB',@(path)loadSource('B',path),'Export',@exportPair);
    setappdata(panel,'BarrierActions',actions);
    updateControls(); showSize(); selectMode();
catch err
    if isvalid(panel), delete(panel); end
    rethrow(err);
end

    function g = grid(parent,widths,heights,bg)
        g = uigridlayout(parent,[numel(heights),numel(widths)],'ColumnWidth',widths, ...
            'RowHeight',heights,'BackgroundColor',bg,'Padding',[0 0 0 0],'ColumnSpacing',6,'RowSpacing',0);
    end
    function l = label(parent,text,sz,color,tag)
        l = uilabel(parent,'Text',text,'FontName',font,'FontSize',sz,'FontColor',color,'Tag',tag);
    end
    function b = button(parent,text,tag,callback)
        b = uibutton(parent,'Text',text,'FontName',font,'FontSize',13,'Tag',tag,'ButtonPushedFcn',callback);
    end
    function guard(action)
        try
            action();
        catch err
            widthBox.Value = frameWidth; status.Text = err.message; status.Tooltip = err.message;
        end
    end
    function chooseSource(which)
        [file,folder] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.bmp','照片（JPEG / PNG / TIFF / BMP）'}, ...
            ['载入图像 ' which]);
        if ~isequal(file,0), loadSource(which,fullfile(folder,file)); end
    end
    function loadSource(which,path)
        [pixels,meta] = fl_photo_load(path);
        pixels = uint8(255 .* pixels);
        [~,stem,ext] = fileparts(meta.Source);
        if which == 'A'
            if size(pixels,2) < 2
                error('FL_barrier_gui:narrow','图像 A 至少需要两列像素才能交错显示两帧。');
            end
            install(pixels,sourceB,frameWidth); nameA.Text = [stem ext]; nameA.Tooltip = meta.Source;
        else
            install(sourceA,pixels,frameWidth); nameB.Text = [stem ext]; nameB.Tooltip = meta.Source;
        end
    end
    function changeWidth()
        install(sourceA,sourceB,widthBox.Value);
    end
    function install(a,b,w)
        w = min(max(1,round(w)),size(a,2)-1);
        % Build first, so a failed load preserves both current inputs and the preview.
        nextResult = fl_barrier_build(a,b,w); nextCache = buildCache(nextResult.Base,w);
        sourceA = a; sourceB = b; result = nextResult; cache = nextCache;
        position = min(2*w,round(position*w/frameWidth)); frameWidth = w;
        updateControls(); showSize(); selectMode();
    end
    function updateControls()
        widthBox.Value = frameWidth;
        slider.Value = 0; slider.Limits = [0 2*frameWidth];
        slider.MajorTicks = [0 frameWidth 2*frameWidth]; slider.MajorTickLabels = {'A','B','A'};
        slider.Value = position;
        [h,w,~] = size(cache.Base); dx = result.Size(2)/w; dy = result.Size(1)/h;
        previewImage.XData = [dx/2 result.Size(2)-dx/2]; previewImage.YData = [dy/2 result.Size(1)-dy/2];
        ax.XLim = [0 result.Size(2)]; ax.YLim = [0 result.Size(1)];
    end
    function showSize()
        status.Text = sprintf('画布 %d × %d 像素　｜　导出交错底图与零位移透明栅栏。',result.Size(2),result.Size(1));
        status.Tooltip = status.Text;
    end
    function chooseFolder()
        folder = uigetdir(pwd,'选择文件夹，以原图尺寸导出底图和透明栅栏');
        if ~isequal(folder,0), exportPair(folder); end
    end
    function paths = exportPair(folder)
        paths = fl_barrier_export(result,folder);
        status.Text = ['两张 PNG 已导出至 ' char(fileparts(paths.Base))];
        status.Tooltip = sprintf('%s\n%s',paths.Base,paths.Grating);
    end
    function showB(~,~)
        alignTo(frameWidth);
    end
    function alignTo(target)
        mode.Value = 'overlay'; slider.Enable = 'on'; moveTo(target,true);
    end
    function selectMode()
        if strcmp(mode.Value,'base')
            slider.Enable = 'off'; previewImage.CData = cache.Base;
            phaseLabel.Text = '交错底图（未叠放栅栏）';
        else
            slider.Enable = 'on'; moveTo(position,true);
        end
    end
    function moveTo(value,commit)
        previous = position; position = min(2*frameWidth,max(0,round(value)));
        if commit, slider.Value = position; end
        if strcmp(mode.Value,'base') || (~commit && position == previous), return; end
        previewImage.CData = renderOffset(cache,frameWidth,position);
        if mod(position,2*frameWidth) == 0
            alignment = '对齐 A';
        elseif position == frameWidth
            alignment = '对齐 B';
        else
            alignment = '两帧过渡';
        end
        phaseLabel.Text = sprintf('栅栏位移  %d px　·　%s',position,alignment);
    end
end

function c = buildCache(base,w)
% Each thumbnail column is a bin of ORIGINAL columns. Sort each bin by
% grating phase, so one open interval can be box-averaged with two lookups.
[h,n,~] = size(base); scale = min([1,920/n,560/h]);
nx = max(1,round(n*scale)); ny = max(1,round(h*scale));
ny = min(ny,max(1,floor(2.4e6/n))); % cap working cache size
xedge = round(linspace(0,n,nx+1)); yedge = round(linspace(0,h,ny+1));
c = struct('Base',[],'Sum',[],'Left',xedge(1:end-1),'Right',xedge(2:end));
if ny == h
    rows = base;
else
    rows = zeros(ny,n,3,'single');
    for k = 1:ny
        rows(k,:,:) = mean(base(yedge(k)+1:yedge(k+1),:,:),1,'double');
    end
end
if nx == n
    c.Base = uint8(rows); return;
end
col = 0:n-1; bin = repelem(0:nx-1,diff(xedge));
[~,order] = sort(bin*(2*w)+mod(col,2*w));
c.Sum = zeros(ny,n+1,3); % double preserves small differences near the right edge
for ch = 1:3
    c.Sum(:,2:end,ch) = cumsum(double(rows(:,order,ch)),2);
end
c.Base = uint8((c.Sum(:,c.Right+1,:)-c.Sum(:,c.Left+1,:))./(c.Right-c.Left));
end

function imageData = renderOffset(c,w,offset)
if isempty(c.Sum)
    imageData = fl_barrier_view(c.Base,w,offset); return;
end
period = 2*w; start = mod(offset,period); stop = mod(start+w,period);
lo = c.Left + countBelow(c.Left,c.Right,period,start);
hi = c.Left + countBelow(c.Left,c.Right,period,stop);
visible = c.Sum(:,hi+1,:) - c.Sum(:,lo+1,:);
if stop < start
    visible = visible + c.Sum(:,c.Right+1,:) - c.Sum(:,c.Left+1,:);
end
imageData = uint8(visible./(c.Right-c.Left));
end

function count = countBelow(left,right,period,threshold)
% Count columns whose phase is < threshold in each half-open source bin.
count = (floor(right/period)-floor(left/period))*threshold ...
    + min(mod(right,period),threshold)-min(mod(left,period),threshold);
end

function [a,b] = dayAndNight()
% Two original flat-colour coastal prints in a common coordinate system.
h = 360; n = 600; [x,y] = meshgrid(((1:n)-.5)/h, ((1:h)-.5)/h);
a = repmat(reshape(uint8([167 225 232]),1,1,3),h,n);
b = repmat(reshape(uint8([54 78 139]),1,1,3),h,n);
dx = x-.56; dy = y-.36; radius = hypot(dx,dy); angle = atan2(dy,dx);
rays = radius > .196 & radius < .265 & cos(12*angle)>.67;
a = paint(a,rays,[255 198 65]); a = paint(a,radius<=.167,[255 193 37]);
moon = hypot(x-1.08,y-.35)<.20 & hypot(x-1.16,y-.275)>.167;
b = paint(b,moon,[255 237 171]);
stars = [.18 .25 .032; .36 .40 .018; .59 .16 .025; .77 .38 .021; 1.38 .18 .038; 1.52 .48 .021];
for k = 1:size(stars,1)
    sparkle = abs(x-stars(k,1))+.56*abs(y-stars(k,2)) < stars(k,3);
    b = paint(b,sparkle,[214 236 247]);
end
ridge = interp1([0 .22 .46 .72 .94 1.21 1.47 n/h],[.70 .56 .72 .66 .50 .66 .55 .64],x);
a = paint(a,y>=ridge,[79 153 153]); b = paint(b,y>=ridge,[78 105 165]);
a = paint(a,y>.75,[52 139 162]); b = paint(b,y>.75,[36 66 117]);
for k = 1:3
    r = .76+.058*k;
    a = paint(a,abs(x-(.53+.025*k))<.19-.035*k & abs(y-r)<.007,[249 212 125]);
    b = paint(b,abs(x-(1.08-.018*k))<.19-.035*k & abs(y-r)<.007,[154 189 222]);
end
end

function imageData = paint(imageData,mask,rgb)
for ch = 1:3
    plane = imageData(:,:,ch); plane(mask) = rgb(ch); imageData(:,:,ch) = plane;
end
end
