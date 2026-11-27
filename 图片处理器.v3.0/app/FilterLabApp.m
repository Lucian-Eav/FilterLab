function FilterLabApp(varargin)
%FILTERLABAPP Windows standalone entry point; accepts a photo or --self-test.
if ~isdeployed, addpath(fullfile(fileparts(mfilename('fullpath')),'core')); end
if nargin > 1, error('FilterLab:Arguments','请传入一张照片的路径，或使用 --self-test。'); end
if nargin == 0
    fig = FL_photo();
elseif strcmp(varargin{1},'--self-test')
    folder = getenv('FILTERLAB_TEST_OUTPUT');
    if isempty(folder), folder = tempname(); end
    smokeTest(folder); return
else
    filename = char(varargin{1});
    assert(isfile(filename),'FilterLab:FileNotFound','找不到照片：%s',filename);
    fig = FL_photo('File',filename);
end
waitfor(fig);
end
function smokeTest(folder)
if exist(folder,'dir')==7
    items=dir(folder); assert(numel(items)<=2,'Test output folder must be empty.');
else
    [ok,msg]=mkdir(folder); assert(ok,msg);
end
p=fl_app_paths();
assert(exist(p.Sample,'file')==2,'Bundled sample data missing.');
plates={'ridge-overview.jpg','ridge-original.png','ridge-spectrum.png','ridge-lowpass.png','welcome-mountain.jpg'};
for k=1:numel(plates)
    info=imfinfo(fullfile(p.Assets,plates{k})); assert(info.Width>0 && info.Height>0);
end
rng(7); X=single(.2+.6*rand(80,120,3)); input=fullfile(folder,'input.png'); imwrite(X,input);
fig=FL_photo('Visible','off'); done=onCleanup(@()delete(fig)); %#ok<NASGU>
assert(isscalar(findall(fig,'Tag','HomeMountain')));
api=getappdata(fig,'PhotoActions'); api.Open(input);
api.SetSpec(struct('Exposure',.2,'FineDetail',.1));
api.SetCreative(struct('TiltEnable',true,'TiltBlur',4));
api.SetZoom('100'); api.Export(fullfile(folder,'photo-export.png'));
A=imread(fullfile(folder,'photo-export.png')); assert(isequal(size(A),[80 120 3]));
api.Undo(); api.Redo();
sampled=fl_photo_samples(X,[1 1 120 80],4);
assert(isequal(sampled.Direct,X(1:4:end,1:4:end,:)));
assert(isequal(size(sampled.Lowpass),[20 30 3]) && all(isfinite(sampled.Lowpass(:))));
assert(isequal(fl_phase_join(fl_phase_split(A,2)),A));
panel=api.OpenAssignment(); actions=getappdata(panel,'AssignmentActions');
R=actions.Run();
assert(numel(R.Answers)==6&&exist(fullfile(R.OutputDir,'report.html'),'file')==2);
assert(strcmp(fileparts(R.OutputDir),p.Output),'Default report output path was not used.');
for k=1:6, actions.SetQuestion(k); end
exportapp(fig,fullfile(folder,'packaged-workspace.png'));
results=struct('Version',version,'Deployed',isdeployed,'Packaged',p.Packaged, ...
    'Root',p.Root,'Sample',p.Sample,'DefaultOutput',p.Output,'PhotoSize',size(A),'Questions',numel(R.Answers));
save(fullfile(folder,'smoke-results.mat'),'results');
writeText(fullfile(folder,'report-path.txt'),fullfile(R.OutputDir,'report.html'));
writeText(fullfile(folder,'PASS.txt'),sprintf('FILTERLAB_EXE_SMOKE_PASS\nAppVersion=3.0\nHomeAssets=5\nSampling=1\nPolyphase=1\nMATLAB=%s\nDeployed=%d\nPackaged=%d\nSample=%s\nDefaultOutput=%s\n',version,isdeployed,p.Packaged,p.Sample,p.Output));
fprintf('FILTERLAB_EXE_SMOKE_PASS OUTPUT=%s\n',folder);
end
function writeText(path,text)
[f,msg]=fopen(path,'w','n','UTF-8'); assert(f~=-1,msg);
done=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'%s',text);
end
