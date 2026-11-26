function [img,meta] = fl_ext_samples(kind,source)
%FL_EXT_SAMPLES Discover optional photographs or make deterministic benchmarks.
% SOURCE may be an RGB/gray array, file, search directory, 'synthetic', or
% 'plus'. No random state is left changed. Synthetic ground truth is in META.
if nargin<2, source=[]; end
kind=lower(char(kind));
if ~any(strcmp(kind,{'mountain','screen_moire','notebook','naishu'}))
    error('fl_ext_samples:kind','Unknown benchmark %s.',kind);
end
meta=struct('Source','','Synthetic',false,'Kind',kind);
if (isnumeric(source) || islogical(source)) && ~isempty(source)
    img=unit_rgb(source); meta.Source='用户数值图像';
elseif (ischar(source) || isstring(source)) && any(strcmpi(char(source),{'plus','plus.mat'}))
    paths=fl_app_paths(); [img,loaded]=fl_load_image(paths.Sample);
    img=unit_rgb(img); meta.Source=loaded.Source;
else
    file=discover(kind,source);
    if isempty(file)
        [img,truth]=synthetic(kind);
        fields=fieldnames(truth);
        for k=1:numel(fields), meta.(fields{k})=truth.(fields{k}); end
        meta.Source=['内置确定性合成基准 · ' kind]; meta.Synthetic=true;
    else
        [~,~,ext]=fileparts(file);
        if strcmpi(ext,'.mat'), [img,loaded]=fl_load_image(file);
        else, [img,loaded]=fl_photo_load(file); end
        img=unit_rgb(img); meta.Source=loaded.Source;
    end
end
meta.OriginalSize=size(img);
if max(size(img,1),size(img,2))>320
    img=double(fl_photo_resize(img,320));
end
if min(size(img,1),size(img,2))<32
    error('fl_ext_samples:size','Input image must be at least 32 pixels on each side.');
end
meta.Size=size(img);
if any(~isfinite(img(:))) || any(img(:)<0 | img(:)>1)
    error('fl_ext_samples:benchmarkRange','Benchmark pixels must lie in [0,1].');
end
end

function file=discover(kind,source)
file='';
if ischar(source) || isstring(source)
    source=char(source);
    if strcmpi(source,'synthetic'), return; end
    if exist(source,'file')==2, file=source; return; end
    if ~isempty(source) && exist(source,'dir')~=7
        error('fl_ext_samples:notFound','Image or directory does not exist %s.',source);
    end
elseif ~isempty(source)
    error('fl_ext_samples:source','Expected an image array or input path.');
end
paths=fl_app_paths(); root=fileparts(paths.Root);
folders={fullfile(paths.Root,'samples'),root,fileparts(root)};
if ~isempty(source), folders=[{source},folders]; end
switch kind
    case 'mountain', names={'山脉'};
    case 'naishu', names={'奶薯'};
    otherwise, names={};
end
extensions={'.jpg','.png','.jpeg','.JPG','.PNG','.JPEG'};
for k=1:numel(folders)
    for n=1:numel(names)
        for e=1:numel(extensions)
            candidate=fullfile(folders{k},[names{n} extensions{e}]);
            if exist(candidate,'file')==2, file=candidate; return; end
        end
    end
end
end

function img=unit_rgb(x)
if isinteger(x), img=double(x)/double(intmax(class(x))); else, img=double(x); end
if ismatrix(img), img=repmat(img,1,1,3); end
if ndims(img)~=3 || size(img,3)~=3 || ~isreal(img) || ...
        any(~isfinite(img(:))) || any(img(:)<0 | img(:)>1)
    error('fl_ext_samples:range','Input must be a finite RGB or gray image in [0,1].');
end
end

function [img,meta]=synthetic(kind)
state=rng; cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(74019,'twister'); n=256;
[x,y]=meshgrid(0:n-1,0:n-1); u=x/(n-1); v=y/(n-1);
meta=struct;
switch kind
    case 'mountain'
        img=cat(3,.68-.20*v,.83-.22*v,.97-.22*v);
        colors=[.36 .47 .56;.25 .38 .34;.13 .25 .20];
        for k=1:3
            ridge=.29+.14*k+.08*sin((2+k)*pi*u+.9*k)+.035*cos(17*pi*u);
            mask=v>ridge;
            texture=.035*sin(2*pi*(.31*x+.17*y))+.025*cos(2*pi*.39*y);
            for c=1:3
                plane=img(:,:,c); layer=colors(k,c)+.12*(1-v)+texture;
                plane(mask)=layer(mask); img(:,:,c)=plane;
            end
        end
        zone=u>.56 & v>.70;
        chirp=sin(2*pi*(.16*x+.00065*x.^2+.11*y));
        for c=1:3
            p=img(:,:,c); p(zone)=.48+.30*chirp(zone); img(:,:,c)=p;
        end
        img=min(1,max(0,img));
    case 'screen_moire'
        clean=screen_content(x,y);
        angle=28; frequency=.24;
        phase=pi*frequency*(x*cosd(angle)+y*sind(angle));
        img=clean;
        for c=1:3, img(:,:,c)=clean(:,:,c)+.15*cos(phase+(c-2)*.65); end
        meta.Clean=clean; meta.Angle=angle; meta.Frequency=frequency;
    case 'notebook'
        ink=false(n);
        % Short geometric glyphs include horizontal, vertical and diagonal strokes.
        for row=[35 72 162 198]
            for col=22:29:224
                dx=x-col; dy=y-row;
                glyph=(abs(dx)<1.6 & abs(dy)<8) | ...
                    (abs(dy+7)<1.5 & dx>=0 & dx<13) | ...
                    (abs(dx-.65*(dy+7))<1.5 & dy>=-7 & dy<8);
                ink=ink|glyph;
            end
        end
        % An isolated, symmetric stroke supplies an unambiguous profile ROI.
        ink=ink | (abs(y-123)<=3 & x>=102 & x<=153);
        clean=.96-.86*double(ink);
        background=.42+.58*(.65+.35*cos(pi*(u-.17))).*(.67+.33*cos(pi*(v-.23)));
        lines=.040*cos(2*pi*y/12)+.018*cos(4*pi*y/12);
        img=zeros(n,n,3);
        tint=[.70 .90 1.0];
        for c=1:3, img(:,:,c)=(clean-lines*tint(c)).*background; end
        img=min(1,max(0,img));
        meta.Clean=repmat(clean,1,1,3); meta.Background=background;
        meta.LinePeriod=12; meta.FgMask=ink;
        meta.BgMask=conv2(double(ink),ones(13),'same')==0;
        meta.ProfileCenter=[124 128]; meta.ProfileRadius=18;
    case 'naishu'
        % A printed textile around a localized gold emblem. The diagonal
        % weave has fixed 4 px axial period, with an orthogonal 8 px thread.
        % Radius sensitivity depends on the image spectrum and all-pass key.
        % These declared spatial frequencies remain fixed for every key.
        img=zeros(n,n,3);
        circle=(u-.5).^2+(v-.5).^2<.25^2;
        plus=(abs(u-.5)<.055 & abs(v-.5)<.20) | (abs(v-.5)<.055 & abs(u-.5)<.20);
        palette=[.91 .65 .18];
        for c=1:3
            phase=2*pi*.25*(x+y)+(c-2)*2*pi/3;
            p=.5+.4*cos(phase)+.035*cos(2*pi*.125*(x-y)+(c-2)*2*pi/3);
            p(circle)=palette(c)+.07*cos(phase(circle));
            p(plus)=.06; img(:,:,c)=p;
        end
        meta.PatternFrequencies=[.25 .25;.125 -.125]; % cycles per pixel [x,y]
        meta.BenchmarkNote=['固定45度四像素周期印花、正交八像素织纹和局部徽标；' ...
            '半径扰动效果取决于输入频谱与密钥。'];
end
end

function clean=screen_content(x,y)
n=size(x,1); clean=repmat(.68,n,n,3);
colors=[.15 .30 .58;.70 .32 .23;.25 .58 .35;.62 .48 .18];
for k=1:4
    mask=x>=16+(k-1)*58 & x<65+(k-1)*58 & y>=23 & y<67;
    for c=1:3, p=clean(:,:,c); p(mask)=colors(k,c); clean(:,:,c)=p; end
end
text=false(n);
for row=[99 140 183 222]
    for col=20:25:231
        dx=x-col; dy=y-row;
        glyph=(abs(dx)<1.4 & abs(dy)<7) | (abs(dy+6)<1.4 & dx>=0 & dx<13) | ...
            (abs(dy)<1.4 & dx>=0 & dx<10) | (abs(dx-.6*dy-8)<1.3 & abs(dy)<7);
        text=text|glyph;
    end
end
for c=1:3, p=clean(:,:,c); p(text)=.20; clean(:,:,c)=p; end
end
