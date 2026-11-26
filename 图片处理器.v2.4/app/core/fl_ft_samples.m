function [data, meta] = fl_ft_samples(kind, source, maxEdge)
%FL_FT_SAMPLES Load image collections or deterministic frequency-tool demos.
% DATA is an RGB image for single-image kinds and a cell array for bursts.
if nargin < 1 || isempty(kind), kind = 'watermark_photo'; end
if nargin < 2, source = []; end
if nargin < 3 || isempty(maxEdge), maxEdge = 512; end
validateattributes(maxEdge,{'numeric'},{'scalar','integer','positive'});
kind = lower(char(kind));
if ~isempty(source)
    [data,meta] = load_source(source,maxEdge);
    return
end
if any(strcmp(kind,{'normalize','images'}))
    error('fl_ft_samples:source','A source is required when kind is normalize.');
end
switch kind
    case {'burst_crowd','burst_night','burst_sharpness'}
        [data,meta] = make_burst(kind);
    case {'watermark_photo','night_lights'}
        [data,meta] = make_still(kind);
    otherwise
        error('fl_ft_samples:kind','Unknown sample kind %s.',kind);
end
if iscell(data)
    oldSize=[size(data{1},1) size(data{1},2)];
    for k=1:numel(data), data{k}=resize_image(data{k},maxEdge); end
    meta.Clean=resize_image(meta.Clean,maxEdge);
    if isfield(meta,'TrueShifts')
        newSize=[size(data{1},1) size(data{1},2)];
        meta.TrueShifts=meta.TrueShifts.*((newSize-1)./(oldSize-1));
    end
else
    data=resize_image(data,maxEdge);
end
end

function [data,meta]=load_source(source,maxEdge)
if ischar(source) || (isstring(source)&&isscalar(source))
    path=char(source);
    if exist(path,'dir')==7
        listing=dir(path); files={};
        for k=1:numel(listing)
            if listing(k).isdir, continue; end
            [~,~,ext]=fileparts(listing(k).name);
            if any(strcmpi(ext,{'.jpg','.jpeg','.png','.bmp','.tif','.tiff'}))
                files{end+1}=fullfile(path,listing(k).name); %#ok<AGROW>
            end
        end
        if isempty(files), error('fl_ft_samples:emptyFolder','No supported images in %s.',path); end
        source=files;
    elseif exist(path,'file')==2
        source={path};
    else
        error('fl_ft_samples:notFound','Image or folder not found: %s',path);
    end
end
meta=struct('Source','user','Synthetic',false);
if isstring(source), source=cellstr(source); end
if iscell(source) && all(cellfun(@(x)ischar(x)||(isstring(x)&&isscalar(x)),source(:)))
    data=cell(size(source));
    meta.Names=cell(size(source)); meta.Paths=cell(size(source));
    for k=1:numel(source)
        [frame,info]=fl_photo_load(source{k});
        data{k}=resize_image(frame,maxEdge);
        [~,name,ext]=fileparts(info.Source);
        meta.Names{k}=[name ext]; meta.Paths{k}=info.Source;
    end
    meta.Source='files';
elseif iscell(source)
    data=cell(size(source));
    for k=1:numel(source), data{k}=resize_image(source{k},maxEdge); end
    meta.Source='arrays';
elseif isnumeric(source) || islogical(source)
    data=resize_image(source,maxEdge); meta.Source='array';
else
    error('fl_ft_samples:source','Input must be a path, folder, file list, or image array.');
end
end

function [frames,meta]=make_burst(kind)
state=rng; cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(seed_for(kind),'twister'); n=256; [x,y]=meshgrid(1:n,1:n);
if strcmp(kind,'burst_night')
    clean=night_scene(x,y);
    count=8; span=5; sigma=.08; frames=cell(1,count); shifts=zeros(count,2);
    for k=1:count
        shifts(k,:)=(2*rand(1,2)-1)*span;
        frames{k}=translate(clean,shifts(k,1),shifts(k,2));
        noise=sigma*randn(size(clean));
        frames{k}=min(1,max(0,frames{k}+noise));
    end
    meta=struct('Clean',clean,'TrueShifts',shifts,'NoiseSigma',sigma,'Kind',kind,'Synthetic',true);
elseif strcmp(kind,'burst_crowd')
    clean=day_scene(x,y);
    count=7; frames=cell(1,count); shifts=zeros(count,2);
    for k=1:count
        shifts(k,:)=(2*rand(1,2)-1)*6;
        frame=translate(clean,shifts(k,1),shifts(k,2));
        for person=1:randi([2 3])
            px=18+rand*215; py=155+rand*65;
            frame=draw_person(frame,px,py,person);
        end
        frame=min(1,max(0,frame+.012*randn(size(frame))));
        frames{k}=frame;
    end
    meta=struct('Clean',clean,'TrueShifts',shifts,'NoiseSigma',.012,'Kind',kind,'Synthetic',true);
else
    clean=day_scene(x,y); frames=cell(1,6); labels={'sharp','mild defocus','strong defocus','motion 35 deg','motion -20 deg','defocus + noise'};
    sharp=clean; mild=blur_image(clean,1.0); strong=blur_image(clean,2.2);
    motionA=motion_blur(clean,35,17); motionB=motion_blur(clean,-20,25);
    noisy=min(1,max(0,mild+.025*randn(size(clean))));
    unshuffled={sharp,mild,strong,motionA,motionB,noisy}; order=[4 2 6 1 5 3];
    for k=1:6, frames{k}=unshuffled{order(k)}; end
    angles=[nan nan nan 35 -20 nan];
    meta=struct('Clean',clean,'SharpIndex',find(order==1),'Degradation',{labels(order)}, ...
        'ShakeAngles',angles(order),'Kind',kind,'Synthetic',true);
end
end

function seed=seed_for(kind)
switch kind
    case 'burst_crowd', seed=901;
    case 'burst_night', seed=902;
    otherwise, seed=903;
end
end

function [img,meta]=make_still(kind)
state=rng; cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(904,'twister');
if strcmp(kind,'watermark_photo')
    n=256; [x,y]=meshgrid(0:n-1,0:n-1); u=x/n; v=y/n;
    sky=cat(3,.43+.20*(1-v),.62+.17*(1-v),.73+.15*(1-v));
    ridge=.38+.09*sin(6*pi*u)+.035*sin(23*pi*u);
    img=sky; land=v>ridge;
    layers={ [.22 .35 .29], [.38 .40 .31], [.16 .28 .22] };
    for k=3:-1:1
        mask=land;
        if k<3, mask=mask & v<ridge+.15*k; end
        for c=1:3, plane=img(:,:,c); plane(mask)=layers{k}(c)+.08*rand(sum(mask(:)),1); img(:,:,c)=plane; end
    end
    for k=1:45
        cx=rand*n; cy=(.40+rand*.55)*n; rad=1+rand*3;
        img=add_disc(img,cx,cy,rad,[.65+.3*rand .55+.35*rand .3+.55*rand]);
    end
else
    n=320; [x,y]=meshgrid(1:n,1:n); img=night_scene(x,y);
end
meta=struct('Kind',kind,'Synthetic',true,'Source',['builtin ' kind]);
end

function img=day_scene(x,y)
n=size(x,1); u=(x-1)/(n-1); v=(y-1)/(n-1);
img=cat(3,.55+.25*(1-v),.72+.20*(1-v),.83+.14*(1-v));
% Distant mountains and a large central building with window detail.
ridge=.31+.09*sin(5*pi*u)+.045*sin(17*pi*u);
for c=1:3
    plane=img(:,:,c); vals=[.28 .38 .34]; plane(v>ridge)=vals(c); img(:,:,c)=plane;
end
building=x>70 & x<188 & y>70 & y<190;
colors=[.62 .48 .34];
for c=1:3, plane=img(:,:,c); plane(building)=colors(c); img(:,:,c)=plane; end
for wx=82:18:172
    for wy=83:24:163
        img=paint_box(img,wx,wy,8,12,[.91 .77 .49]);
    end
end
for k=1:130
    cx=rand*n; cy=145+rand*95;
    img=add_disc(img,cx,cy,.6+rand*1.8,[.06+.28*rand,.12+.33*rand,.07+.18*rand]);
end
end

function img=night_scene(x,y)
n=size(x,1); u=(x-1)/(n-1); v=(y-1)/(n-1);
img=cat(3,.008+.025*(1-v),.018+.035*(1-v),.055+.09*(1-v));
% Water reflection and silhouette skyline.
water=v>.69; ripple=.006*sin(70*u+13*v);
for c=1:3, plane=img(:,:,c); plane(water)=plane(water)+ripple(water); img(:,:,c)=plane; end
skyline=35+18*sin(13*u)+12*sin(31*u);
building=v>skyline/n & v<.73;
bld=[.025 .035 .055];
for c=1:3, plane=img(:,:,c); plane(building)=bld(c); img(:,:,c)=plane; end
for k=1:70
    cx=8+rand*(n-16); cy=45+rand*n*.52;
    switch mod(k,3)
        case 0, col=[1,.55+.35*rand,.22+.2*rand];
        case 1, col=[1,.88+.12*rand,.68+.3*rand];
        otherwise, col=[.58+.3*rand,.78+.22*rand,1];
    end
    img=add_disc(img,cx,cy,1+rand*1.3,col);
    if rand<.6
        reflection=col.*[.36 .42 .58];
        img=paint_box(img,round(cx-2),round(n*.74+(.68*n-cy)*.32+rand*4),4,3,reflection);
    end
end
end

function img=draw_person(img,cx,base,kind)
color=[.8 .12 .08;.05 .22 .8;.85 .65 .08]; c=color(kind,:);
img=add_disc(img,cx,base-20,4,c);
img=paint_box(img,round(cx-4),round(base-16),8,14,c);
img=paint_box(img,round(cx-5),round(base-3),3,12,c*.65);
img=paint_box(img,round(cx+2),round(base-3),3,12,c*.65);
end
function img=paint_box(img,x,y,w,h,c)
x1=max(1,x); x2=min(size(img,2),x+w-1); y1=max(1,y); y2=min(size(img,1),y+h-1);
if x1<=x2 && y1<=y2
    for q=1:3, img(y1:y2,x1:x2,q)=c(q); end
end
end
function img=add_disc(img,cx,cy,r,c)
% A disc only touches its integer bounding box, including clipped edges.
x=max(1,ceil(cx-r)):min(size(img,2),floor(cx+r));
y=max(1,ceil(cy-r)):min(size(img,1),floor(cy+r));
if isempty(x)||isempty(y), return; end
mask=(x-cx).^2+(y(:)-cy).^2<=r^2;
for q=1:3
    patch=img(y,x,q); patch(mask)=c(q); img(y,x,q)=patch;
end
end
function out=translate(img,dy,dx)
[h,w,~]=size(img); y=(1:h)'; x=(1:w)'; out=zeros(size(img));
for c=1:3
    g=griddedInterpolant({y,x},double(img(:,:,c)),'linear','none');
    out(:,:,c)=g({y-dy,x-dx});
end
out=fill_missing(out,img);
end
function out=fill_missing(out,source)
for c=1:3
    a=out(:,:,c); b=source(:,:,c); bad=~isfinite(a); a(bad)=b(bad); out(:,:,c)=a;
end
end
function out=blur_image(img,sigma)
r=ceil(3*sigma); t=-r:r; g=exp(-t.^2/(2*sigma^2)); g=g/sum(g); out=zeros(size(img));
for c=1:3, out(:,:,c)=conv2(conv2(img(:,:,c),g,'same'),g','same'); end
end
function out=motion_blur(img,angle,len)
t=linspace(-(len-1)/2,(len-1)/2,len); dx=cosd(angle)*t; dy=sind(angle)*t;
[h,w,~]=size(img); y=(1:h)'; x=(1:w)'; out=zeros(size(img));
for c=1:3
    plane=double(img(:,:,c)); acc=zeros(h,w);
    g=griddedInterpolant({y,x},plane,'linear','none');
    border=plane(round((h+1)/2),round((w+1)/2));
    for k=1:len
        v=g({y-dy(k),x-dx(k)}); v(isnan(v))=border; acc=acc+v;
    end
    out(:,:,c)=acc/len;
end
end
function X=resize_image(X,maxEdge)
X=to_rgb(X); if max(size(X,1),size(X,2))>maxEdge, X=double(fl_photo_resize(single(X),maxEdge)); end
end
function X=to_rgb(X)
if ~(isnumeric(X)||islogical(X)) || isempty(X) || ~isreal(X)
    error('fl_ft_samples:image','请选择非空实数图像。');
end
if isinteger(X), X=double(X)/double(intmax(class(X))); else, X=double(X); end
if ismatrix(X), X=repmat(X,1,1,3); end
if ndims(X)~=3 || size(X,3)~=3 || any(~isfinite(X(:))) || any(X(:)<0 | X(:)>1)
    error('fl_ft_samples:image','Image arrays must be finite RGB/gray in [0,1].');
end
end
