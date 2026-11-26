function check_barrier_v23(artifactDir)
%CHECK_BARRIER_V23 Exercise the visible workspace and its two registration layers.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'app'),fullfile(root,'app','core'));
if ~isfolder(artifactDir), mkdir(artifactDir); end
[x,y]=meshgrid(0:18,0:8);
a=uint8(cat(3,15+x,40+y,90+x+y));
b=uint8(cat(3,180+x,150+y,200+x+y));
for w=[1 2 3 5 9]
    result=fl_barrier_build(a,b,w);
    assert(isequal(result.Size,[9 19]) && result.Width==w);
    stripeA=mod(floor(x(1,:)/w),2)==0;
    expected=b; expected(:,stripeA,:)=a(:,stripeA,:);
    assert(isequal(expected,result.Base),'Interlacing shifted a source column.');
    for offset=0:2*w
        [frame,alpha]=fl_barrier_view(result.Base,w,offset);
        % Express the moving sheet as a circularly shifted two-stripe tile.
        tile=circshift([zeros(1,w,'uint8') 255*ones(1,w,'uint8')],[0 offset]);
        row=repmat(tile,1,ceil(size(a,2)/(2*w))); row=row(1:size(a,2));
        assert(isequal(alpha,repmat(row,size(a,1),1)));
        visible=expected; visible(:,row==255,:)=0; assert(isequal(visible,frame));
    end
end
% B is wider; choose a case where a centred crop needs no interpolation.
wide=uint8(repmat(1:21,[7 1 3])); crop=fl_barrier_build(false(7,9),wide,1);
expectedWide=wide(:,7:15,:); assert(isequal(crop.Base(:,2:2:end,:),expectedWide(:,2:2:end,:)));
light=fl_barrier_build(uint16(65535*ones(2,5)),single(zeros(2,5)),1);
assert(isequal(light.Base(1,:,2),uint8([255 0 255 0 255])));
fprintf('PASS: alternating source columns, partial final stripe, every pixel offset through two widths, centred crop and image conversion.\n');

host=FL_photo('Visible','on'); guard=onCleanup(@()discard(host)); %#ok<NASGU>
tabs=widget(host,'FilterLabWorkspaces'); page=widget(host,'BarrierPage');
assert(isempty(findall(page,'Tag','BarrierPanel')),'Workspace unexpectedly constructed at launch.');
tabs.SelectedTab=page; feval(tabs.SelectionChangedFcn,tabs,[]); drawnow;
panel=widget(page,'BarrierPanel'); api=getappdata(panel,'BarrierActions');
ui=widget(panel,'BarrierPreview'); width=widget(panel,'BarrierWidth');
slider=widget(panel,'BarrierOffset'); mode=widget(panel,'BarrierMode');
press(widget(panel,'BarrierShowA')); sampleA=ui.CData; assert(~isempty(sampleA));
exportapp(host,fullfile(artifactDir,'示例-图A.png'));
press(widget(panel,'BarrierShowB')); sampleB=ui.CData; assert(~isequal(sampleA,sampleB));
assert(slider.Value==width.Value); exportapp(host,fullfile(artifactDir,'示例-图B.png'));
photoApi=getappdata(host,'PhotoActions'); assert(isequal(photoApi.OpenBarrier(),panel));
% Wide enough to keep the same strip alignment while exercising true file I/O.
[x,y]=meshgrid(0:250,0:136);
a=uint8(cat(3,mod(x,248)+5,mod(y,249)+4,mod(x+y,223)+12));
b=uint8(cat(3,zeros(size(x))+190,mod(x,85)+80,mod(y,115)+20));
fileA=fullfile(artifactDir,'input-A.png'); fileB=fullfile(artifactDir,'input-B.png');
imwrite(a,fileA); imwrite(b,fileB); api.LoadA(fileA); api.LoadB(fileB);
change(width,8); press(widget(panel,'BarrierShowA')); cA=ui.CData;
slider.Value=4; feval(slider.ValueChangingFcn,slider,struct('Value',4)); drawnow;
half=ui.CData; assert(~isequal(cA,half),'Drag did not update preview before release.');
change(slider,4); press(widget(panel,'BarrierShowB')); assert(slider.Value==8);
assert(~isequal(cA,ui.CData) && ~isequal(half,ui.CData));
change(mode,'base'); baseFrame=ui.CData; change(mode,'overlay'); assert(~isequal(baseFrame,ui.CData));
paths=api.Export(artifactDir); second=api.Export(artifactDir);
assert(isfile(paths.Base) && isfile(paths.Grating) && ~strcmp(paths.Base,second.Base));
stripeA=mod(floor(x(1,:)/8),2)==0; expected=b; expected(:,stripeA,:)=a(:,stripeA,:);
assert(isequal(imread(paths.Base),expected));
[black,~,alpha]=imread(paths.Grating); assert(~isempty(alpha) && all(black(:)==0));
assert(isequal(alpha,repmat(uint8(~stripeA)*255,size(a,1),1)));
% The physical sheet can be reused with the same registration at every row.
blackMask=alpha~=0; shifted=~blackMask;
assert(all(all(all(expected.*uint8(~blackMask)==a.*uint8(~blackMask)))));
assert(all(all(all(expected.*uint8(~shifted)==b.*uint8(~shifted)))));
% Exercise the reduced preview with stripes narrower than some thumbnail bins.
[x,y]=meshgrid(0:1598,0:798); ca=uint8(cat(3,mod(x,250),mod(y,250),mod(x+y,250)));
cb=uint8(255-ca); imwrite(ca,fileA); imwrite(cb,fileB); api.LoadA(fileA); api.LoadB(fileB); change(width,3);
full=fl_barrier_build(ca,cb,3);
for off=[0 1 3 5 6]
    change(slider,off); frame=ui.CData; reference=fl_barrier_view(full.Base,3,off);
    [h,w,~]=size(frame); assert(w<size(ca,2) && h<size(ca,1));
    xe=round(linspace(0,size(ca,2),w+1)); ye=round(linspace(0,size(ca,1),h+1));
    for i=unique(round(linspace(1,h,7)))
        for j=unique(round(linspace(1,w,11)))
            block=reference(ye(i)+1:ye(i+1),xe(j)+1:xe(j+1),:);
            avg=squeeze(mean(mean(double(block),1),2));
            assert(max(abs(squeeze(double(frame(i,j,:)))-avg))<=0.51,'Scaled preview lost original pixel registration.');
        end
    end
end
close(host); assert(~isgraphics(host));
fprintf('PASS: app tab, default A/B, real slider drag, view controls, source files, full-resolution PNG+alpha, and repeat export.\n');
end

function h=widget(parent,tag)
h=findall(parent,'Tag',tag); assert(isscalar(h),'Missing or duplicate %s.',tag);
end
function press(h)
feval(h.ButtonPushedFcn,h,[]); drawnow;
end
function change(h,v)
h.Value=v; feval(h.ValueChangedFcn,h,struct('Value',v)); drawnow;
end
function discard(f)
if isgraphics(f), delete(f); end
end
