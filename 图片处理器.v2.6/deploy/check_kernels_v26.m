function R=check_kernels_v26(oldApp,newApp,repeats)
%CHECK_KERNELS_V26 Exact same-input results and timings for common edit gestures.
% R=check_kernels_v26('.../v2.5/app','.../v2.6/app'); repeats defaults to 3.
if nargin<3, repeats=3; end
validateattributes(repeats,{'numeric'},{'scalar','integer','positive','finite'});
oldCore=fullfile(oldApp,'core'); newCore=fullfile(newApp,'core');
assert(isfolder(oldCore)&&isfolder(newCore)&&~strcmpi(oldCore,newCore),'Supply distinct absolute app paths.');
oldDir=pwd; oldPath=path; oldRng=rng;
cleanup=onCleanup(@()restore(oldDir,oldPath,oldRng)); %#ok<NASGU>
rng(2601,'twister'); P=single(randi([0 255],432,640,3,'uint8'))/255;
F=single(randi([0 255],900,1350,3,'uint8'))/255; I=rand(65,81,3,'single');
keys={'sharpen','exposure8','tilt','motion','classic','fullExport16'};
selectCore(oldCore); reference=exercise(I,P(1:65,1:81,:));
selectCore(newCore); candidate=exercise(I,P(1:65,1:81,:));
names=fieldnames(reference); assert(isequal(names,fieldnames(candidate)));
for k=1:numel(names)
    assert(isequaln(reference.(names{k}),candidate.(names{k})),'Kernel mismatch at %s',names{k});
end
R=struct('Matlab',version,'CaseCount',numel(names),'PreviewSize',size(P),'ExportSize',size(F),'Repeats',repeats);
% Identical parameter sequences, warm-up and setup outside the measured time.
% Full exports start on a different-sized preview at each iteration.
for k=1:numel(keys)
    key=keys{k};
    selectCore(oldCore); [base,expected]=measure(key,P,F,repeats);
    selectCore(newCore); [next,actual]=measure(key,P,F,repeats);
    assert(isequal(expected,actual),'Timed output differs for %s.',key);
    R.Timings.(key)=struct('BaselineSeconds',base,'CandidateSeconds',next, ...
        'BaselineMedian',median(base),'CandidateMedian',median(next),'Speedup',median(base)/median(next));
    fprintf('%s baseline %.5f s candidate %.5f s ratio %.2fx\n',key,median(base),median(next),median(base)/median(next));
end
fprintf('Matched %d kernel cases, plus %d benchmark outputs.\n',numel(names),numel(keys));
end

function R=exercise(I,Q)
S=fl_photo_spec(struct('AutoNoise',true,'AutoWB',true,'WB',[1.09 .97 1.01], ...
    'Exposure',-.21,'Clarity',.12,'FineDetail',.09,'LocalContrast',-.17));
R=struct();
for source=1:2
    if source==1, X=I; else, X=Q; end
    R.(sprintf('two%d',source))=fl_photo_process(X,S);
    for i=1:4
        S.SharpenAmount=.23*i; S.SharpenThreshold=.008*i;
        R.(sprintf('sharp%d_%d',source,i))=photo(X,S);
    end
    R.(sprintf('repeat%d',source))=photo(X,S);
    for i=1:3
        S.Exposure=.29*i;
        R.(sprintf('ev%d_%d',source,i))=photo(X,S);
    end
    T=X; T(end-2,end-5,2)=1-T(end-2,end-5,2);
    R.(sprintf('source%d',source))=photo(T,S);
    R.(sprintf('restore%d',source))=photo(X,S);
end
R.row=photo(Q(1,:,:),S); R.col=photo(Q(:,1,:),S);
R.double=photo(double(Q),S); R.preview=photo(I(1:2:end,1:2:end,:),S); R.full=photo(I,S);
Q(end-1,3,2)=single(.012345); R.mixed=photo(Q,S);
R.invalid=invalidPixel(I,S);
C=struct('ClassicType','fir4','ClassicAmount',.31,'TiltEnable',true,'TiltBlur',3.6, ...
    'TiltCenter',[.15 .7],'MotionEnable',true,'MotionAngle',0,'MotionLength',11,'MotionAmount',.4);
ctx=struct('OriginalSize',size(I),'Geometry',{{}});
R.initial=fl_creative_process(I,C,ctx); C.MotionAmount=.86; R.amount=fl_creative_process(I,C,ctx);
C.MotionAngle=90; R.vertical=fl_creative_process(I,C,ctx);
C.MotionAngle=-23; R.diagonal=fl_creative_process(I,C,ctx);
C.MotionType='zoom'; R.zoom=fl_creative_process(I,C,ctx);
C.MotionType='spin'; R.spin=fl_creative_process(I,C,ctx);
C.TiltCenter=[.53 .48]; R.focus=fl_creative_process(I,C,ctx);
C.ClassicAmount=.54; R.classic=fl_creative_process(I,C,ctx);
ctx.OriginalSize=2*size(I); ctx.OriginalSize(3)=3; R.scale=fl_creative_process(I,C,ctx);
R.replace=fl_creative_process(Q,C,ctx);
end
function values=photo(X,S)
[y,info,st]=fl_photo_process(X,S); values={y,rmfield(info,'ElapsedSeconds'),st};
end
function id=invalidPixel(X,S)
X(end)=NaN; id='';
try, fl_photo_process(X,S); catch err, id=err.identifier; end
assert(~isempty(id),'Invalid pixel accepted.');
end

function [times,last]=measure(key,P,F,repeats)
times=zeros(1,repeats); last=[];
for i=0:repeats
    S=struct(); C=struct();
    switch key
        case 'sharpen'
            S.SharpenAmount=.2; S.FineDetail=.12;
        case 'exposure8'
            S.Exposure=-.1; S.SharpenEnable=false; S.DenoiseEnable=false;
        case 'tilt'
            C.TiltEnable=true; C.TiltBlur=13; C.TiltCenter=[.5 .5];
        case 'motion'
            C.MotionEnable=true; C.MotionAmount=.4; C.MotionLength=40; C.MotionAngle=0;
        case 'classic'
            C.ClassicType='fir12'; C.ClassicAmount=.4;
        case 'fullExport16'
            S.Exposure=.37; S.Vibrance=.09; f=[tempname '.png'];
            cleanup=onCleanup(@()deleteIfPresent(f)); %#ok<NASGU>
    end
    [~,~,~]=fl_photo_pipeline(P,S,C);
    t=tic;
    if strcmp(key,'fullExport16')
        [last,~,~]=fl_photo_pipeline(F,S,C);
        fl_photo_save(f,last,struct('Height',size(F,1),'Width',size(F,2)),'BitDepth',16);
        elapsed=toc(t); last=imread(f); clear cleanup
        assert(isa(last,'uint16')&&isequal(size(last),size(F)));
    else
        for j=1:3
            switch key
                case 'sharpen', S.SharpenAmount=.3*j;
                case 'exposure8', S.Exposure=.18*j;
                case 'tilt', C.TiltCenter=[.21*j .3];
                case 'motion', C.MotionAmount=.25*j;
                case 'classic', C.ClassicAmount=.25*j;
            end
            [last,~,~]=fl_photo_pipeline(P,S,C);
        end
        elapsed=toc(t);
    end
    if i>0, times(i)=elapsed; end
end
end
function deleteIfPresent(f)
if isfile(f), delete(f); end
end
function selectCore(core)
cd(core); addpath(core,'-begin'); clear fl_photo_process fl_photo_noise fl_photo_pipeline fl_creative_process
assert(strcmpi(which('fl_photo_process'),fullfile(core,'fl_photo_process.m')));
end
function restore(folder,savedPath,savedRng)
cd(folder); path(savedPath); rng(savedRng); clear fl_photo_process fl_photo_noise fl_photo_pipeline fl_creative_process
end
