function panel = FL_phase_gui(parent)
%FL_PHASE_GUI Inspect and reassemble spatial sample phases.
% api = getappdata(parent,'PhaseActions'); api.Load(path); api.SetRounds(2);
% api.SelectPhase(3,2); d = api.GetDetail(); S = api.GetState();
% d.ROI=[x y width height]; d.Samples correspond to source(d.Rows,d.Cols,:).
if ~isdeployed, addpath(fullfile(fileparts(mfilename('fullpath')),'core')); end
theme = fl_ui_theme(); paper = theme.Paper; white = theme.Panel; ink = theme.Ink;
muted = theme.Muted; teal = theme.Accent; font = 'Microsoft YaHei UI';
source = []; state = []; selected = [1 1]; inspection = []; overview = [];
tilePics = gobjects(0); tileLabels = gobjects(0); tileFrames = gobjects(0);
lastStacked = []; lastHeights = [];
panel = uigridlayout(parent,[1 1],'Padding',[0 0 0 0],'BackgroundColor',paper,'Tag','PhasePanel');
try
    frame = uipanel(panel,'BorderType','none','BackgroundColor',paper,'AutoResizeChildren','off');
    page = grid(frame,{'1x'},{32,'1x',210,22},paper);
    page.Tag = 'PhasePage'; page.Padding = [10 6 10 6]; page.RowSpacing = 6; page.Scrollable = 'on';
    tools = grid(page,{'1x',90,74,106,92},{'1x'},paper);
    nameLabel = label(tools,'',16,ink,'PhaseSourceName'); nameLabel.FontWeight = 'bold';
    opener = button(tools,'打开照片…','PhaseLoad',@choosePhoto);
    opener.BackgroundColor = teal; opener.FontColor = theme.White;
    demoButton = button(tools,'内置山湖','PhaseDemo',@demo);
    roundsBox = uidropdown(tools,'Items',{'1 轮 · 4 张','2 轮 · 16 张'},'ItemsData',[1 2], ...
        'Value',1,'FontName',font,'Tag','PhaseRounds','ValueChangedFcn',@(s,~)guard(@()setRounds(s.Value)));
    exporter = button(tools,'导出整组…','PhaseExport',@chooseFolder);
    body = grid(page,{'2x','3x'},{'1x'},paper); body.ColumnSpacing = 10;
    left = grid(body,{'1x'},{28,'1x',20},white); left.Padding = [8 5 8 4];
    viewBar = grid(left,{'1x',84},{'1x'},white);
    viewTitle = label(viewBar,'整幅画面',15,ink,''); viewTitle.FontWeight = 'bold';
    viewBox = uidropdown(viewBar,'Items',{'原图','重建图'},'ItemsData',{'original','joined'}, ...
        'Value','original','FontName',font,'Tag','PhaseView','ValueChangedFcn',@(s,~)guard(@()showView(s.Value)));
    preview = uiimage(left,'ScaleMethod','fit','BackgroundColor',theme.Canvas,'Tag','PhasePreview');
    detail = label(left,'',12,muted,'PhaseDimensions'); detail.HorizontalAlignment = 'center';
    right = grid(body,{'1x'},{28,'1x'},white); right.Padding = [8 5 8 5];
    galleryTitle = label(right,'',15,ink,'PhaseGalleryTitle'); galleryTitle.FontWeight = 'bold';
    gallery = grid(right,{'1x'},{'1x'},white); gallery.Tag = 'PhaseGallery'; gallery.ColumnSpacing = 7; gallery.RowSpacing = 6;
    inspector = grid(page,{'1x'},{28,'1x',20},white); inspector.Padding = [8 5 8 4];
    inspectBar = grid(inspector,{'1x',86},{'1x'},white);
    choice = label(inspectBar,'',15,teal,'PhaseSelection'); choice.FontWeight = 'bold';
    regionBox = uidropdown(inspectBar,'Items',{'画面中心','左上角','右上角','左下角','右下角'}, ...
        'ItemsData',1:5,'Value',1,'FontName',font,'Tag','PhaseRegion','Tooltip','选择两幅局部图对照的位置', ...
        'ValueChangedFcn',@(~,~)guard(@updateDetail));
    compare = grid(inspector,{'2x','2x','1x'},{'1x'},white);
    [originalZoom,originalTitle] = pane(compare,'原图局部','PhaseDetailOriginal');
    [sampleZoom,sampleTitle] = pane(compare,'所选子图','PhaseDetailSamples');
    [sampleGrid,gridTitle] = pane(compare,'取样位置','PhaseSampleGrid');
    gridTitle.Tooltip = '显示对照区域左上角的真实像素，青点标出所选相位。';
    key = label(inspector,'',12,muted,'PhaseKey'); key.WordWrap = 'on';
    status = label(page,'',12,ink,'PhaseStatus'); status.WordWrap = 'on';
    demo(); fitView(); frame.SizeChangedFcn = @(~,~)fitView();
    api = struct('Load',@loadPhoto,'SetRounds',@setRounds,'GetState',@getState, ...
        'Export',@exportSet,'ShowJoined',@()showView('joined'),'ShowOriginal',@()showView('original'),'Demo',@demo, ...
        'SelectPhase',@selectPhase,'GetDetail',@getDetail);
    setappdata(panel,'PhaseActions',api); setappdata(parent,'PhaseActions',api);
catch err
    delete(panel); rethrow(err);
end

    function g = grid(host,widths,heights,bg)
        g = uigridlayout(host,[numel(heights) numel(widths)],'ColumnWidth',widths, ...
            'RowHeight',heights,'Padding',[0 0 0 0],'ColumnSpacing',6,'RowSpacing',2,'BackgroundColor',bg);
    end
    function l = label(host,txt,sz,color,tag)
        l = uilabel(host,'Text',txt,'FontName',font,'FontSize',sz,'FontColor',color,'Tag',tag);
    end
    function b = button(host,txt,tag,callback)
        b = uibutton(host,'Text',txt,'FontName',font,'Tag',tag,'ButtonPushedFcn',@(~,~)guard(callback));
    end
    function [im,caption] = pane(host,txt,tag)
        cellGrid = grid(host,{'1x'},{19,'1x'},white);
        caption = label(cellGrid,txt,12,ink,[tag 'Title']); caption.HorizontalAlignment = 'center';
        im = uiimage(cellGrid,'ScaleMethod','fit','Tag',tag);
    end
    function guard(action)
        try
            action();
        catch err
            if ~isempty(state), roundsBox.Value = state.Rounds; end
            status.Text = err.message; status.Tooltip = err.message;
        end
    end
    function choosePhoto()
        [file,folder] = uigetfile({'*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.bmp','照片（PNG / JPEG / TIFF / BMP）'},'选择一张照片');
        if ~isequal(file,0), loadPhoto(fullfile(folder,file)); end
    end
    function loadPhoto(path)
        [photo,note] = readPixels(path);
        [~,stem,ext] = fileparts(char(path)); install(photo,[stem ext],[char(path) note]);
    end
    function demo()
        install(lakeSample(),'山湖与帆船（内置）','奇数边长的内置图，可比较不同相位在边界的尺寸。');
    end
    function install(photo,name,tip)
        n = roundsBox.Value;
        if n == 2 && min(size(photo,1),size(photo,2)) < 4, n = 1; end
        next = fl_phase_split(photo,n);
        state = next; source = photo; selected = [1 1]; regionBox.Value = 1;
        nameLabel.Text = name; nameLabel.Tooltip = tip;
        viewBox.Value = 'original'; refresh();
    end
    function setRounds(n)
        validateattributes(n,{'numeric'},{'scalar','integer','>=',1,'<=',2});
        next = fl_phase_split(source,n); state = next;
        selected = min(selected,state.Step); refresh();
    end
    function S = getState()
        S = state;
    end
    function d = getDetail()
        d = inspection;
    end
    function refresh()
        step = state.Step; roundsBox.Value = state.Rounds;
        galleryTitle.Text = sprintf('接触印样　%d 张　·　起点 (行, 列)',step^2);
        if size(tilePics,1) ~= step
            delete(gallery.Children);
            gallery.ColumnWidth = repmat({'1x'},1,step); gallery.RowHeight = repmat({'1x'},1,step);
            tilePics = gobjects(step); tileLabels = gobjects(step); tileFrames = gobjects(step);
            for r = 1:step
                for c = 1:step
                    tileBox = grid(gallery,{'1x'},{'1x'},white);
                    place(tileBox,r,c); tileBox.Padding = [2 2 2 2]; tileFrames(r,c) = tileBox;
                    well = uipanel(tileBox,'BorderType','none','BackgroundColor',white,'AutoResizeChildren','off');
                    cap = button(well,'',sprintf('PhaseCaption_%d_%d',r,c),@()selectPhase(r,c));
                    cap.VerticalAlignment = 'bottom'; cap.FontSize = 12; tileLabels(r,c) = cap;
                    tag = sprintf('PhaseTile_%d_%d',r,c);
                    pic = uiimage(well,'ScaleMethod','fit','VerticalAlignment','bottom', ...
                        'BackgroundColor',white,'Tag',tag,'ImageClickedFcn',@(~,~)guard(@()selectPhase(r,c)));
                    tilePics(r,c) = pic;
                    well.SizeChangedFcn = @(src,~)sizePrint(src,cap,pic);
                    sizePrint(well,cap,pic);
                end
            end
        end
        for r = 1:step
            for c = 1:step
                tile = state.Tiles{r,c};
                tilePics(r,c).ImageSource = thumbnail(tile,round(850/step));
                tip = sprintf('起始行 %d、列 %d。宽 %d，高 %d 像素。',r,c,size(tile,2),size(tile,1));
                tileLabels(r,c).Tooltip = tip; tilePics(r,c).Tooltip = tip;
            end
        end
        markSelection(); showView(viewBox.Value); fitView();
        % Newly mounted panels can retain the startup size until first layout.
        drawnow nocallbacks;
        for idx = 1:numel(tilePics)
            sizePrint(tilePics(idx).Parent,tileLabels(idx),tilePics(idx));
        end
    end
    function selectPhase(r,c)
        validateattributes(r,{'numeric'},{'scalar','integer','>=',1,'<=',state.Step});
        validateattributes(c,{'numeric'},{'scalar','integer','>=',1,'<=',state.Step});
        selected = double([r c]); markSelection(); updateDetail();
    end
    function markSelection()
        for r = 1:state.Step
            for c = 1:state.Step
                cap = tileLabels(r,c); at = sprintf('(%d, %d)',r,c);
                if isequal(selected,[r c])
                    cap.Text = [at '  已选']; cap.FontWeight = 'bold'; cap.FontColor = teal;
                    cap.BackgroundColor = white; tileFrames(r,c).BackgroundColor = teal;
                else
                    cap.Text = at; cap.FontWeight = 'normal'; cap.FontColor = muted;
                    cap.BackgroundColor = white; tileFrames(r,c).BackgroundColor = white;
                end
            end
        end
    end
    function showView(mode)
        if strcmp(mode,'joined')
            pixels = fl_phase_join(state);
            if ~isequal(pixels,source), error('FL_phase_gui:join','重建像素与原图不一致。'); end
            msg = sprintf('重建完成：%d 张子图已放回采样位置，逐像素核对一致。',numel(state.Tiles));
        else
            pixels = source;
            msg = '每张子图都取自整幅照片。切换“重建图”，可核对所有像素。';
        end
        overview = thumbnail(pixels,1024); viewBox.Value = mode;
        if size(pixels,3)==1, channels = '灰度'; else, channels = 'RGB'; end
        detail.Text = sprintf('%d × %d px　%s　%s',size(pixels,2),size(pixels,1),channels,class(pixels));
        status.Text = msg; status.Tooltip = msg; updateDetail();
    end
    function updateDetail()
        k = state.Step; r = selected(1); c = selected(2); h = size(source,1); w = size(source,2);
        % Use whole stride blocks for both crops. The first source row/column
        % of every block is congruent to 1 modulo k, even for odd-sized photos.
        bh = min(48/k,floor(h/k)); bw = min(80/k,floor(w/k));
        anchors = [.5 .5; 0 0; 1 0; 0 1; 1 1]; pos = anchors(regionBox.Value,:);
        xBlock = floor((floor(w/k)-bw)*pos(1)); yBlock = floor((floor(h/k)-bh)*pos(2));
        x = 1+k*xBlock; y = 1+k*yBlock; ww = bw*k; hh = bh*k;
        rows = y-1+r+(0:bh-1)*k; cols = x-1+c+(0:bw-1)*k;
        tile = state.Tiles{r,c}; pix = tile(yBlock+(1:bh),xBlock+(1:bw),:);
        orig = source(y:y+hh-1,x:x+ww-1,:);
        inspection = struct('Phase',[r c],'Step',k,'ROI',[x y ww hh],'Original',orig, ...
            'Samples',pix,'Rows',rows,'Cols',cols);
        % Pre-expand with nearest neighbours so pixel blocks stay legible
        % when uiimage scales its copy to the available panel size.
        mag = max(1,min(16,ceil(480/max(ww,hh))));
        originalZoom.ImageSource = repelem(thumbnail(orig,max(ww,hh)),mag,mag,1);
        sampleZoom.ImageSource = repelem(thumbnail(pix,max(bw,bh)),k*mag,k*mag,1);
        gridRows = y:y+min(2*k,hh)-1; gridCols = x:x+min(2*k,ww)-1;
        sampleGrid.ImageSource = phaseDiagram(source(gridRows,gridCols,:), ...
            ismember(gridRows,rows),ismember(gridCols,cols),theme);
        preview.ImageSource = locator(overview,[x y ww hh],w,h,teal);
        choice.Text = sprintf('局部对照　已选 (%d, %d)',r,c);
        choice.Tooltip = sprintf('所选子图宽 %d、高 %d 像素。',size(tile,2),size(tile,1));
        originalTitle.Text = sprintf('原图局部　%d × %d',ww,hh);
        sampleTitle.Text = sprintf('子图局部　%d × %d',bw,bh);
        gridTitle.Text = sprintf('取样格点　%d × %d',numel(gridCols),numel(gridRows));
        key.Text = sprintf('原图框：行 %d–%d，列 %d–%d。格点图从框的左上角起，深青点为已取像素。',y,y+hh-1,x,x+ww-1);
        key.Tooltip = key.Text;
    end
    function fitView()
        sz = frame.Position(3:4); stacked = sz(1)<720;
        if ~isequal(lastStacked,stacked)
            if stacked
                tools.RowHeight = {28,30};
                place(nameLabel,1,[1 2]); place(roundsBox,1,3); place(opener,2,1);
                place(demoButton,2,2); place(exporter,2,3); tools.ColumnWidth = {'1x','1x',108};
                body.RowHeight = {190,400}; place(right,2,1); body.ColumnWidth = {'1x'};
                compare.RowHeight = {124,130}; place(sampleGrid.Parent,2,[1 2]);
                compare.ColumnWidth = {'1x','1x'}; inspector.RowHeight = {28,'1x',38};
            else
                tools.ColumnWidth = {'1x',90,74,106,92};
                place(nameLabel,1,1); place(opener,1,2); place(demoButton,1,3);
                place(roundsBox,1,4); place(exporter,1,5); tools.RowHeight = {'1x'};
                body.ColumnWidth = {'2x','3x'}; place(right,1,2); body.RowHeight = {'1x'};
                compare.ColumnWidth = {'2x','2x','1x'}; place(sampleGrid.Parent,1,3);
                compare.RowHeight = {'1x'}; inspector.RowHeight = {28,'1x',20};
            end
            lastStacked = stacked;
        end
        if stacked
            sheetHeight = 262 + 36*state.Step;
            body.RowHeight = {190,sheetHeight};
            heights = [60,192+sheetHeight,336,38];
        else
            zoomHeight = max(212,min(288,round(.31*sz(2))));
            heights = [32,max(360,sz(2)-zoomHeight-86),zoomHeight,24];
        end
        if ~isequal(lastHeights,heights), page.RowHeight = num2cell(heights); lastHeights = heights; end
    end
    function chooseFolder()
        dest = uigetdir(pwd,'选择整组子图及重建图的上级目录');
        if ~isequal(dest,0), exportSet(dest); end
    end
    function folder = exportSet(dest)
        folder = fl_phase_export(state,dest);
        status.Text = ['已导出子图与重建图至 ' char(folder)]; status.Tooltip = char(folder);
    end
end

function place(control,row,col)
control.Layout.Row = row; control.Layout.Column = col;
end

function sizePrint(well,cap,pic)
% A single native button serves the full print and its keyboard activation.
% Clip the stock bevel in the well so the bottom reads as a figure caption.
wh = max([1 1],well.Position(3:4));
cap.Position = [-5 -3 wh(1)+12 wh(2)+8];
pic.Position = [1 21 wh(1) max(1,wh(2)-20)];
end

function rgb = phaseDiagram(pixels,rowSelected,colSelected,theme)
% Enlarge actual source cells. The same source index vectors made Samples.
pitch = 32;
rgb = repelem(thumbnail(pixels,max(size(pixels,1),size(pixels,2))),pitch,pitch,1);
[x,y] = meshgrid(0:size(rgb,2)-1,0:size(rgb,1)-1);
distance2 = (mod(x,pitch)-(pitch-1)/2).^2 + (mod(y,pitch)-(pitch-1)/2).^2;
chosen = repelem(rowSelected(:) & reshape(colSelected,1,[]),pitch,pitch);
rule = mod(x,pitch)==0 | mod(y,pitch)==0 | x==size(rgb,2)-1 | y==size(rgb,1)-1;
for ch = 1:3
    plane = rgb(:,:,ch); plane(rule) = uint8(round(255*theme.Rule(ch)));
    plane(chosen & distance2<=10^2) = 255;
    plane(chosen & distance2<=7.5^2) = uint8(round(255*theme.Accent(ch)));
    rgb(:,:,ch) = plane;
end
end

function rgb = locator(rgb,roi,w,h,accent)
% Draw a two-tone locator on the display thumbnail only.
height = size(rgb,1); width = size(rgb,2);
xs = max(1,min(width,1+floor((roi(1)-1+[0 roi(3)-1])*width/w)));
ys = max(1,min(height,1+floor((roi(2)-1+[0 roi(4)-1])*height/h)));
if diff(xs)<4 || diff(ys)<4 || (roi(3)==w && roi(4)==h), return; end
colors = uint8(round(255*[accent; 1 1 1]));
for offset = 0:1
    a = xs(1)+offset; b = xs(2)-offset; t = ys(1)+offset; z = ys(2)-offset;
    for ch = 1:3
        rgb([t z],a:b,ch) = colors(offset+1,ch); rgb(t:z,[a b],ch) = colors(offset+1,ch);
    end
end
end

function [photo,note] = readPixels(path)
% Keep the native gray/RGB sample grid and bit depth of the first frame.
[~,~,ext] = fileparts(char(path)); note = '';
if strcmpi(ext,'.png')
    [photo,map,alpha] = imread(path);
    if ~isempty(alpha), note = '（按颜色样本拆分，透明度通道不参与）'; end
else
    [photo,map] = imread(path);
end
if ~isempty(map)
    index = double(photo); if isinteger(photo) || islogical(photo), index = index+1; end
    palette = uint16(round(65535*map));
    if all(mod(double(palette(:)),257)==0), palette = uint8(double(palette)/257); end
    photo = reshape(palette(index(:),:),size(photo,1),size(photo,2),3);
    note = ['（按调色板解码为 RGB）' note];
elseif islogical(photo)
    photo = uint8(photo).*uint8(255);
end
if ~isa(photo,'uint8') && ~isa(photo,'uint16')
    error('FL_phase_gui:depth','无损 PNG 导出需要 8 位或 16 位整数照片。');
end
if ndims(photo)>3 || ~ismember(size(photo,3),[1 3])
    error('FL_phase_gui:channels','请选择灰度、索引色或 RGB 照片。');
end
end

function rgb = thumbnail(pixels,limit)
% Bound the display samples before conversion. Split and join use full images.
[h,w,~] = size(pixels);
scale = min(1,limit/max(h,w)); nr = max(1,round(h*scale)); nc = max(1,round(w*scale));
rows = floor(((1:nr)-0.5)*h/nr)+1; cols = floor(((1:nc)-0.5)*w/nc)+1;
small = pixels(rows,cols,:);
if isa(small,'uint16'), rgb = uint8(double(small)./257); else, rgb = small; end
if size(rgb,3)==1, rgb = repmat(rgb,1,1,3); end
end

function rgb = lakeSample()
% Odd dimensions, a recognizable silhouette and fine ripples on the water.
[x,y] = meshgrid(linspace(0,1,641),linspace(0,1,401));
glow = exp(-((x-.70).^2/.13+(y-.43).^2/.06));
cloud = 4*cos(27*x+38*y).*sin(8*x-74*y).*exp(-((y-.30)/.13).^2);
rgb = cat(3,86+111*y+80*glow+cloud,145+62*y+36*glow+cloud,195+18*y-19*glow+cloud);
ridge = .48-.17*exp(-((x-.24)/.13).^2)-.09*exp(-((x-.68)/.16).^2)+.020*sin(41*x);
near = .57-.11*exp(-((x-.89)/.15).^2)+.032*sin(13*x)+.007*sin(104*x);
water = y>.61; sail = x>.59 & x<.69 & y<.735 & y>.48+2.3*(.69-x);
hull = y>.74 & y<.76 & x>.564+1.5*(y-.74) & x<.731-1.8*(y-.74);
mast = abs(x-.693)<.002 & y>.476 & y<.746;
ripple = 8*sin(390*y+7*sin(12*x)+13*x).*sin(21*x+58*y);
reflection = 28*exp(-((x-.70)./(.05+.22*y)).^2).*(1+sin(278*y+4*sin(10*x)));
farColor = [96 127 148]; nearColor = [54 91 97]; lakeColor = [61 125 153]; warm = [240 218 158];
for ch = 1:3
    plane = rgb(:,:,ch); plane(y>=ridge) = farColor(ch)+12*glow(y>=ridge);
    plane(y>=near) = nearColor(ch)+6*sin(58*x(y>=near));
    plane(water) = lakeColor(ch)+ripple(water)+reflection(water)*(4-ch)/3;
    plane(sail) = warm(ch)+8*sin(65*x(sail)); plane(hull|mast) = 43+4*ch;
    rgb(:,:,ch) = plane;
end
rgb = uint8(rgb);
end
