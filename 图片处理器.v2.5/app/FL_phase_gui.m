function panel = FL_phase_gui(parent)
%FL_PHASE_GUI Mount the polyphase photo workspace in an empty sampling tab.
% api = getappdata(parent,'PhaseActions'); api.Load(path); api.SetRounds(2);
% S = api.GetState(); api.ShowJoined(); folder = api.Export(parentDir);
if ~isdeployed, addpath(fullfile(fileparts(mfilename('fullpath')),'core')); end
paper = [.96 .97 .98]; white = [1 1 1]; ink = [.10 .17 .22];
muted = [.26 .34 .39]; teal = [.03 .36 .42]; font = 'Microsoft YaHei UI';
source = []; state = []; tilePics = gobjects(0); tileLabels = gobjects(0);
panel = uigridlayout(parent,[4 1],'RowHeight',{34,'1x',22,22}, ...
    'Padding',[12 8 12 6],'RowSpacing',4,'BackgroundColor',paper,'Tag','PhasePanel');
try
    tools = grid(panel,{'1x',92,80,115,105},{'1x'},paper);
    nameLabel = label(tools,'',16,ink,'PhaseSourceName'); nameLabel.FontWeight = 'bold';
    opener = button(tools,'打开照片…','PhaseLoad',@choosePhoto);
    opener.BackgroundColor = teal; opener.FontColor = white;
    button(tools,'内置山湖','PhaseDemo',@demo);
    roundsBox = uidropdown(tools,'Items',{'1 轮 · 4 张','2 轮 · 16 张'},'ItemsData',[1 2], ...
        'Value',1,'FontName',font,'Tag','PhaseRounds','ValueChangedFcn',@(s,~)guard(@()setRounds(s.Value)));
    button(tools,'导出整组…','PhaseExport',@chooseFolder);
    body = grid(panel,{'2x','3x'},{'1x'},paper);
    left = grid(body,{'1x'},{30,'1x',22},white); left.Padding = [8 6 8 4];
    viewBar = grid(left,{'1x',92},{'1x'},white);
    viewTitle = label(viewBar,'整张照片',15,ink,''); viewTitle.FontWeight = 'bold';
    viewBox = uidropdown(viewBar,'Items',{'原图','重建图'},'ItemsData',{'original','joined'}, ...
        'Value','original','FontName',font,'Tag','PhaseView','ValueChangedFcn',@(s,~)guard(@()showView(s.Value)));
    preview = uiimage(left,'ScaleMethod','fit','Tag','PhasePreview');
    detail = label(left,'',12,muted,'PhaseDimensions'); detail.HorizontalAlignment = 'center';
    right = grid(body,{'1x'},{30,'1x'},white); right.Padding = [8 6 8 4];
    galleryTitle = label(right,'',15,ink,'PhaseGalleryTitle'); galleryTitle.FontWeight = 'bold';
    gallery = grid(right,{'1x'},{'1x'},white); gallery.Tag = 'PhaseGallery';
    status = label(panel,'',13,ink,'PhaseStatus');
    label(panel,'格中 (行, 列) 是各子图在原图上的采样起点，从 1 开始。宽高均为实际像素尺寸。',12,muted,'PhaseKey');
    demo();
    api = struct('Load',@loadPhoto,'SetRounds',@setRounds,'GetState',@getState, ...
        'Export',@exportSet,'ShowJoined',@()showView('joined'),'ShowOriginal',@()showView('original'),'Demo',@demo);
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
        [~,stem,ext] = fileparts(char(path));
        install(photo,[stem ext],[char(path) note]);
    end
    function demo()
        install(lakeSample(),'山湖与帆船（内置）','合成山湖示例，奇数边长可观察各相位尺寸相差一个像素。');
    end
    function install(photo,name,tip)
        n = roundsBox.Value;
        if n == 2 && min(size(photo,1),size(photo,2)) < 4, n = 1; end
        next = fl_phase_split(photo,n);
        state = next; source = photo;
        nameLabel.Text = name; nameLabel.Tooltip = tip;
        viewBox.Value = 'original'; refresh();
    end
    function setRounds(n)
        validateattributes(n,{'numeric'},{'scalar','integer','>=',1,'<=',2});
        next = fl_phase_split(source,n);
        state = next; refresh();
    end
    function S = getState()
        S = state;
    end
    function refresh()
        step = state.Step; roundsBox.Value = state.Rounds;
        galleryTitle.Text = sprintf('%d 张子图　行列采样步长均为 %d',step^2,step);
        if size(tilePics,1) ~= step
            delete(gallery.Children);
            gallery.ColumnWidth = repmat({'1x'},1,step);
            gallery.RowHeight = repmat({'1x',18},1,step);
            tilePics = gobjects(step); tileLabels = gobjects(step);
            for r = 1:step
                for c = 1:step
                    pic = uiimage(gallery,'ScaleMethod','fit','Tag',sprintf('PhaseTile_%d_%d',r,c));
                    pic.Layout.Row = 2*r-1; pic.Layout.Column = c; tilePics(r,c) = pic;
                    cap = label(gallery,'',11,muted,sprintf('PhaseCaption_%d_%d',r,c));
                    cap.Layout.Row = 2*r; cap.Layout.Column = c;
                    cap.HorizontalAlignment = 'center'; tileLabels(r,c) = cap;
                end
            end
        end
        for r = 1:step
            for c = 1:step
                tile = state.Tiles{r,c};
                tilePics(r,c).ImageSource = thumbnail(tile,round(1024/step));
                tileLabels(r,c).Text = sprintf('(%d,%d)  %d×%d',r,c,size(tile,2),size(tile,1));
                tileLabels(r,c).Tooltip = sprintf('起始行 %d、列 %d。宽 %d，高 %d 像素。',r,c,size(tile,2),size(tile,1));
            end
        end
        showView(viewBox.Value);
    end
    function showView(mode)
        switch mode
            case 'joined'
                pixels = fl_phase_join(state);
                if ~isequal(pixels,source), error('FL_phase_gui:join','重建像素与原图不一致。'); end
                msg = sprintf('已将 %d 张子图放回各自的采样位置。逐像素核对与原图一致。',numel(state.Tiles));
            otherwise
                pixels = source;
                msg = '每张子图都覆盖整幅画面。切换到“重建图”可检查所有采样点能否还原照片。';
        end
        preview.ImageSource = thumbnail(pixels,1024); viewBox.Value = mode;
        if size(pixels,3)==1, channels = '灰度'; else, channels = 'RGB'; end
        detail.Text = sprintf('%d × %d px　%s　%s',size(pixels,2),size(pixels,1),channels,class(pixels));
        status.Text = msg; status.Tooltip = msg;
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
