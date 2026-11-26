function check_photo_sampling_v24(artifactDir)
%CHECK_PHOTO_SAMPLING_V24 Check ROI sampling, file I/O, UI and drag callback ownership.
% check_photo_sampling_v24() or check_photo_sampling_v24(folder) to save a PNG.
if nargin==0, artifactDir=''; end
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'app'),fullfile(root,'app','core'));
[x,y]=meshgrid(0:30,0:22);
photo=single(cat(3,mod(3*x+5*y,23)/22,mod(y,11)/10,mod(x+2*y,17)/16));
% Compare with independent full-photo convolution, including each physical
% boundary, a non-divisible ROI, a single retained point, and shifted phase.
rects={[1 1 31 23],[3 4 15 16],[26 17 6 7],[1 6 4 1],[20 12 1 1]};
for d=[1 2 3 4 7 16]
    for k=1:numel(rects)
        roi=rects{k}; r=fl_photo_samples(photo,roi,d);
        xs=roi(1):d:roi(1)+roi(3)-1; ys=roi(2):d:roi(2)+roi(4)-1;
        assert(isequal(r.SampleX,xs) && isequal(r.SampleY,ys));
        assert(isequal(r.Original,photo(roi(2):roi(2)+roi(4)-1,roi(1):roi(1)+roi(3)-1,:)));
        assert(isequal(r.Direct,photo(ys,xs,:)) && isequal(size(r.Direct),size(r.Lowpass)));
        sigma=.6*d; radius=ceil(3*sigma);
        g=exp(-(-radius:radius).^2/(2*sigma*sigma)); g=g/sum(g);
        if d==1, g=1; radius=0; end
        assert(abs(sum(r.Kernel)-1)<1e-12 && max(abs(g-r.Kernel))<1e-12);
        rows=max(1,min(23,1-radius:23+radius)); cols=max(1,min(31,1-radius:31+radius));
        for ch=1:3
            reference=conv2(double(photo(rows,cols,ch)),g.'*g,'valid');
            expected=reference(ys,xs); actual=double(r.Lowpass(:,:,ch));
            assert(max(abs(actual(:)-expected(:)))<2e-6,'ROI halo, kernel or sampling phase differs from full photo.');
        end
    end
end
flat=fl_photo_samples(.375*ones(7,8,3,'single'),[1 1 8 7],6);
assert(max(abs(flat.Lowpass(:)-.375))<2e-6);
col=0:319; fine=single(.5+.42*cos(2*pi*.225*col)); coarse=single(.5+.42*cos(2*pi*.0125*col));
pattern=repmat(reshape([fine;coarse;fine].',1,320,3),12,1,1);
r=fl_photo_samples(pattern,[16 4 288 6],4);
fineRatio=std(double(r.Lowpass(1,:,1)))/std(double(r.Direct(1,:,1)));
coarseRatio=std(double(r.Lowpass(1,:,2)))/std(double(r.Direct(1,:,2)));
assert(fineRatio<.025 && coarseRatio>.96,'Fine or coarse tone response unexpected.');
fprintf('PASS photo sampling: native lattice, full-photo reference, DC, fine/coarse amplitude ratios %.5f / %.5f.\n',fineRatio,coarseRatio);

vis='off'; if ~isempty(artifactDir), vis='on'; end
host=uifigure('Name','照片抗混叠','Position',[100 80 1150 760],'Visible',vis);
closeHost=onCleanup(@()discard(host)); %#ok<NASGU>
outer=uigridlayout(host,[1 1],'Padding',[0 0 0 0]); group=uitabgroup(outer);
page=uitab(group,'Title','照片抗混叠');
oldMotion=@(~,~)disp('host motion'); oldUp=@(~,~)disp('host up');
host.WindowButtonMotionFcn=oldMotion; host.WindowButtonUpFcn=oldUp;
panel=FL_sampling_photo(page); api=getappdata(panel,'SamplingPhotoActions'); drawnow;
assert(isequal(host.WindowButtonMotionFcn,oldMotion) && isequal(host.WindowButtonUpFcn,oldUp));
default=api.GetResult(); assert(default.Step==4 && std(double(default.Direct(:)-default.Lowpass(:)))>.03);
if ~isempty(artifactDir)
    if ~isfolder(artifactDir), mkdir(artifactDir); end
    exportapp(host,fullfile(artifactDir,'照片抗混叠-内置织样.png'));
end
inputPath=[tempname '.png']; inputCleanup=onCleanup(@()removeFile(inputPath)); %#ok<NASGU>
imwrite(uint8(255*photo),inputPath); api.Load(inputPath);
box=widget(panel,'SamplingPhotoStep'); box.Value=3; feval(box.ValueChangedFcn,box,struct('Value',3));
api.SetROI([3 2 17 13]); readback=api.GetResult();
assert(readback.Step==3 && isequal(readback.ROI,[3 2 17 13]));
file=fl_photo_load(inputPath); assert(isequal(readback.Direct,file(2:3:14,3:3:19,:)));
raw=widget(panel,'SamplingPhotoDirect'); lp=widget(panel,'SamplingPhotoLowpass');
assert(isequal(raw.CData,readback.Direct) && isequal(lp.CData,readback.Lowpass));
assert(isequal(raw.XData,lp.XData) && isequal(raw.YData,lp.YData));
assert(isequal(raw.Parent.XLim,lp.Parent.XLim) && isequal(raw.Parent.YLim,lp.Parent.YLim));
assert(isequal(raw.Parent.DataAspectRatio,lp.Parent.DataAspectRatio));
nav=widget(panel,'SamplingPhotoNavigator'); frame=widget(panel,'SamplingPhotoFrame');
% Dispatch actual registered down/move/up handlers using known axes points.
feval(nav.ButtonDownFcn,nav,hit(19,17)); feval(host.WindowButtonMotionFcn,host,hit(5,4));
assert(isequal(frame.Position,[4.5 3.5 15 14])); tmp=api.GetResult(); assert(isequal(tmp.ROI,readback.ROI));
feval(host.WindowButtonUpFcn,host,hit(5,4)); tmp=api.GetResult(); assert(isequal(tmp.ROI,[5 4 15 14]));
assert(isequal(host.WindowButtonMotionFcn,oldMotion) && isequal(host.WindowButtonUpFcn,oldUp));
feval(nav.ButtonDownFcn,nav,hit(6,5)); feval(host.WindowButtonUpFcn,host,hit(-70,90));
tmp=api.GetResult(); assert(isequal(tmp.ROI,[1 5 6 19]));
reset=widget(panel,'SamplingPhotoReset'); feval(reset.ButtonPushedFcn,reset,[]);
tmp=api.GetResult(); assert(isequal(tmp.ROI,[1 1 31 23]));
api.SetStep(1); tmp=api.GetResult(); assert(isequal(tmp.Direct,tmp.Original,tmp.Lowpass));
% Even a deleted mid-drag panel must give existing figure callbacks back.
feval(nav.ButtonDownFcn,nav,hit(7,3)); delete(panel);
assert(isequal(host.WindowButtonMotionFcn,oldMotion) && isequal(host.WindowButtonUpFcn,oldUp));
fprintf('PASS photo GUI: native file decode, ROI/grid agreement, equal axes, reselection, reset, drag preview/commit and callback cleanup.\n');
end

function event=hit(x,y)
event=struct('IntersectionPoint',[x y 0]);
end
function obj=widget(parent,tag)
obj=findall(parent,'Tag',tag); assert(isscalar(obj),'Missing or duplicate %s.',tag);
end
function removeFile(path)
if isfile(path), delete(path); end
end
function discard(host)
if isgraphics(host), delete(host); end
end
