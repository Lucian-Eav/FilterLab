function panel = FL_sampling_photo(parent)
%FL_SAMPLING_PHOTO Interactive ROI sampling comparison in an empty uitab.
% api = getappdata(panel,'SamplingPhotoActions'); api.Load(path);
% api.SetROI([x y width height]); api.SetStep(d); r = api.GetResult();
if ~isdeployed, addpath(fullfile(fileparts(mfilename('fullpath')),'core')); end
paper = [.96 .97 .98]; white = [1 1 1]; ink = [.10 .17 .22];
muted = [.26 .34 .39]; teal = [.03 .36 .42]; font = 'Microsoft YaHei UI';
fig = ancestor(parent,'figure'); source = []; step = 4; result = []; drag = [];
moveFcn = @moveDrag; upFcn = @endDrag;
panel = uigridlayout(parent,[4 1],'RowHeight',{38,'1x',26,24}, ...
    'Padding',[14 10 14 8],'RowSpacing',4,'BackgroundColor',paper,'Tag','SamplingPhotoPanel');
panel.DeleteFcn = @(~,~)releaseDrag();
try
    header = uigridlayout(panel,[1 6],'ColumnWidth',{'1x',100,94,96,62,95}, ...
        'ColumnSpacing',6,'Padding',[0 0 0 0],'BackgroundColor',paper);
    sourceName = label(header,'',17,ink,'SamplingPhotoName'); sourceName.FontWeight = 'bold';
    open = button(header,'打开照片…','SamplingPhotoLoad',@chooseFile);
    open.BackgroundColor = teal; open.FontColor = white;
    button(header,'内置织样','SamplingPhotoDemo',@demo);
    titleStep = label(header,'采样步长（px）',12,ink,''); titleStep.HorizontalAlignment = 'right';
    stepBox = uieditfield(header,'numeric','Limits',[1 16],'RoundFractionalValues','on', ...
        'Value',step,'Tag','SamplingPhotoStep','FontName',font, ...
        'ValueChangedFcn',@(s,~)guard(@()setStep(s.Value)));
    button(header,'选取全图','SamplingPhotoReset',@resetROI);
    views = uigridlayout(panel,[2 2],'ColumnWidth',{'1x','1x'},'RowHeight',{'1x','1x'}, ...
        'Padding',[0 0 0 0],'ColumnSpacing',8,'RowSpacing',8,'BackgroundColor',paper);
    [nav,navImg] = view(views,'整张照片','按住左键拖框，可重新框选','Navigator');
    [origAx,origImg,origCaption] = view(views,'选区原图','','Original');
    [rawAx,rawImg,rawCaption] = view(views,'直接抽样','','Direct');
    [lpAx,lpImg,lpCaption] = view(views,'先低通，再抽样','','Lowpass');
    navImg.HitTest = 'on'; navImg.PickableParts = 'all'; navImg.ButtonDownFcn = @startDrag;
    frameHalo = rectangle('Parent',nav,'Position',[.5 .5 1 1],'EdgeColor',[.08 .12 .15], ...
        'LineWidth',3,'HitTest','off','PickableParts','none');
    frame = rectangle('Parent',nav,'Position',[.5 .5 1 1],'EdgeColor',[1 .84 .32], ...
        'LineWidth',1.5,'HitTest','off','PickableParts','none','Tag','SamplingPhotoFrame');
    status = label(panel,'',13,ink,'SamplingPhotoStatus');
    note = label(panel,'',12,muted,'SamplingPhotoMethod');
    setappdata(panel,'SamplingPhotoActions',struct('Load',@loadFile,'Demo',@demo, ...
        'SetROI',@setROI,'SetStep',@setStep,'ResetROI',@resetROI,'GetResult',@getResult));
    demo();
catch err
    delete(panel); rethrow(err);
end
    function textLabel = label(host,text,sz,color,tag)
        textLabel = uilabel(host,'Text',text,'FontName',font,'FontSize',sz,'FontColor',color,'Tag',tag);
    end
    function control = button(host,text,tag,action)
        control = uibutton(host,'Text',text,'FontName',font,'Tag',tag, ...
            'ButtonPushedFcn',@(~,~)guard(action));
    end
    function [ax,img,caption] = view(host,text,detail,key)
        g = uigridlayout(host,[2 1],'RowHeight',{24,'1x'},'Padding',[6 4 6 4], ...
            'RowSpacing',1,'BackgroundColor',white);
        bar = uigridlayout(g,[1 2],'ColumnWidth',{'fit','1x'},'ColumnSpacing',6, ...
            'Padding',[0 0 0 0],'BackgroundColor',white);
        name = label(bar,text,15,ink,''); name.FontWeight = 'bold';
        caption = label(bar,detail,12,muted,''); caption.HorizontalAlignment = 'right';
        ax = uiaxes(g,'Tag',['SamplingPhoto' key 'Axes'],'Color',white);
        ax.Toolbar.Visible = 'off'; disableDefaultInteractivity(ax);
        ax.Visible = 'off'; ax.YDir = 'reverse'; ax.DataAspectRatio = [1 1 1];
        ax.PositionConstraint = 'innerposition'; ax.LooseInset = [0 0 0 0];
        img = image('Parent',ax,'CData',zeros(2,2,3,'single'),'HitTest','off', ...
            'PickableParts','none','Tag',['SamplingPhoto' key]);
        if isprop(img,'Interpolation'), img.Interpolation = 'nearest'; end
    end
    function guard(action)
        try
            action();
        catch err
            releaseDrag();
            stepBox.Value = step; status.Text = err.message; status.Tooltip = err.message;
            if ~isempty(result), drawFrame(result.ROI); end
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
        overview = displayPixels(img); source = img;
        showImage(nav,navImg,overview,w,h);
        sourceName.Text = name; sourceName.Tooltip = tip; render(next);
    end
    function output = getResult()
        output = result;
    end
    function resetROI()
        setROI([1 1 size(source,2) size(source,1)]);
    end
    function setROI(roi)
        releaseDrag(); render(fl_photo_samples(source,roi,step));
    end
    function setStep(d)
        releaseDrag(); render(fl_photo_samples(source,result.ROI,d));
    end
    function render(next)
        result = next; step = result.Step; stepBox.Value = step; roi = result.ROI;
        [h,w,~] = size(result.Direct);
        showImage(origAx,origImg,displayPixels(result.Original),roi(3),roi(4));
        showImage(rawAx,rawImg,displayPixels(result.Direct),w,h);
        showImage(lpAx,lpImg,displayPixels(result.Lowpass),w,h);
        origCaption.Text = sprintf('%d × %d px',roi(3),roi(4));
        rawCaption.Text = sprintf('%d × %d 个采样点',w,h); lpCaption.Text = rawCaption.Text;
        drawFrame(roi);
        status.Text = sprintf('从选区左上角 (列 %d, 行 %d) 起，每隔 %d 像素取一点。下方两图使用相同格点和显示倍率。',roi(1),roi(2),step);
        if step==1
            note.Text = '步长为 1，保留所有像素并旁路低通。';
        else
            note.Text = sprintf('高斯低通 σ = %.1f px，核权重和为 1。跨选区边缘取真实邻像素，仅在照片边缘复制最近像素。',result.Sigma);
        end
        status.Tooltip = status.Text; note.Tooltip = note.Text;
    end
    function drawFrame(roi)
        pos = [roi(1:2)-.5 roi(3:4)]; frame.Position = pos; frameHalo.Position = pos;
    end
    function point = pointer(event)
        % A graphics hit event provides axes coordinates on mouse-down.
        % Figure motion/release events use the source axes' current point.
        if (isstruct(event) && isfield(event,'IntersectionPoint')) || ...
                (isobject(event) && isprop(event,'IntersectionPoint'))
            xyz = event.IntersectionPoint;
        else
            xyz = nav.CurrentPoint(1,:);
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

function showImage(ax,img,data,w,h)
% Coordinates stay in native pixels even when a large view has a thumbnail.
[n,m,~] = size(data); dx = w/m; dy = h/n;
% MATLAB treats a singleton image dimension as one unit wide. Duplicate
% that texel for display so even a 1-row panorama fills its physical extent.
if m==1, data = data(:,[1 1],:); dx = w/2; end
if n==1, data = data([1 1],:,:); dy = h/2; end
img.CData = data; img.XData = [.5+dx/2, w+.5-dx/2]; img.YData = [.5+dy/2, h+.5-dy/2];
ax.XLim = [.5 w+.5]; ax.YLim = [.5 h+.5];
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
