function FilterLabApp(varargin)
%FILTERLABAPP Desktop entry for launcher and MATLAB Compiler builds.
root=fileparts(mfilename('fullpath'));
if ~isdeployed, addpath(root,fullfile(root,'core')); end
selfTest=any(strcmp(varargin,'--self-test'))||strcmp(getenv('FILTERLAB_SELF_TEST'),'1');
if selfTest
    folder=getenv('FILTERLAB_TEST_OUTPUT');
    if isempty(folder), folder=fullfile(tempdir,['FilterLab-smoke-' char(java.util.UUID.randomUUID)]); end
    smokeTest(folder); return
end
ready=getenv('FILTERLAB_READY_FILE');
startupClock=tic;
markStartup('MATLAB 已就绪，正在创建照片工作室…');
if ~isempty(ready)
    writeText(fullfile(fileparts(ready),'engine-pid.txt'),sprintf('%d',feature('getpid')));
end
source=getenv('FILTERLAB_OPEN_FILE');
fig=FL_photo('File',source);
markStartup('窗口已创建，正在完成首次显示…');
drawnow;
if ~isempty(ready), writeText(ready,'READY'); end
markStartup('照片工作室已就绪');
if strcmp(getenv('FILTERLAB_DIALOG_TEST'),'1')
    dialogTest(fig,getenv('FILTERLAB_TEST_OUTPUT')); return
end
if strcmp(getenv('FILTERLAB_UI_TEST'),'1')
    folder=getenv('FILTERLAB_TEST_OUTPUT');
    [ok,msg]=mkdir(folder); assert(ok,msg);
    exportapp(fig,fullfile(folder,'normal-launch.png'));
    closer=timer('StartDelay',5,'TimerFcn',@(~,~)close(fig));
    cleanup=onCleanup(@()delete(closer)); %#ok<NASGU>
    start(closer);
end
waitfor(fig);
if strcmp(getenv('FILTERLAB_UI_TEST'),'1'), writeText(fullfile(folder,'PASS.txt'),'FILTERLAB_UI_LAUNCH_PASS'); end

    function markStartup(message)
        if isempty(ready), return; end
        logFolder=fileparts(ready);
        writeText(fullfile(logFolder,'stage.txt'),message);
        [file,msg]=fopen(fullfile(logFolder,'startup-timing.log'),'a','n','UTF-8');
        assert(file~=-1,msg);
        cleanup=onCleanup(@()fclose(file)); %#ok<NASGU>
        fprintf(file,'%s  +%.3f s  %s\n',datestr(now,'yyyy-mm-dd HH:MM:SS.FFF'),toc(startupClock),message);
    end
end
function smokeTest(folder)
if exist(folder,'dir')==7
    items=dir(folder); assert(numel(items)<=2,'Test output folder must be empty.');
else
    [ok,msg]=mkdir(folder); assert(ok,msg);
end
p=fl_app_paths();
assert(exist(p.Sample,'file')==2,'Bundled sample data missing.');
if p.Packaged, assert(strcmp(p.Sample,fullfile(p.Root,'samples','plus.mat'))); end
rng(7); X=single(.2+.6*rand(80,120,3)); input=fullfile(folder,'input.png'); imwrite(X,input);
fig=FL_photo('Visible','off','File',input); done=onCleanup(@()delete(fig)); %#ok<NASGU>
api=getappdata(fig,'PhotoActions');
api.SetSpec(struct('Exposure',.2,'FineDetail',.1));
api.SetCreative(struct('TiltEnable',true,'TiltBlur',4));
api.SetZoom('100'); api.Export(fullfile(folder,'photo-export.png'));
A=imread(fullfile(folder,'photo-export.png')); assert(isequal(size(A),[80 120 3]));
api.Undo(); api.Redo();
panel=api.OpenAssignment(); actions=getappdata(panel,'AssignmentActions');
R=actions.Run();
assert(numel(R.Answers)==6&&exist(fullfile(R.OutputDir,'report.html'),'file')==2);
assert(strcmp(fileparts(R.OutputDir),p.Output),'Default report output path was not used.');
for k=1:6, actions.SetQuestion(k); end
exportapp(fig,fullfile(folder,'packaged-workspace.png'));
results=struct('Version',version,'Deployed',isdeployed,'Packaged',p.Packaged, ...
    'Root',p.Root,'Sample',p.Sample,'DefaultOutput',p.Output,'PhotoSize',size(A),'Questions',numel(R.Answers));
save(fullfile(folder,'smoke-results.mat'),'results');
writeText(fullfile(folder,'PASS.txt'),sprintf('FILTERLAB_EXE_SMOKE_PASS\nMATLAB=%s\nDeployed=%d\nPackaged=%d\nSample=%s\nDefaultOutput=%s\n',version,isdeployed,p.Packaged,p.Sample,p.Output));
fprintf('FILTERLAB_EXE_SMOKE_PASS OUTPUT=%s\n',folder);
end
function dialogTest(fig,folder)
% The external Windows test driver selects files in the real native dialogs.
assert(~batchStartupOptionUsed,'File dialogs require an interactive MATLAB engine.');
assert(exist(folder,'dir')~=7,'Dialog test output must be new.');
[ok,msg]=mkdir(folder); assert(ok,msg);
done=onCleanup(@()delete(fig)); %#ok<NASGU>
input=fullfile(folder,'input.png'); output=fullfile(folder,'saved.png');
X=uint8(repmat(reshape(mod(0:359,256),[1 120 3]),[80 1 1])); imwrite(X,input);
writeText(fullfile(folder,'matlab-pid.txt'),sprintf('%d',feature('getpid')));
api=getappdata(fig,'PhotoActions');
press('open-select','PhotoOpen');
s=getappdata(fig,'PhotoState'); assert(isequal(size(s.Original),[80 120 3]));
assert(strcmp(s.Source,input),'Open dialog did not load the selected photo.');
api.SetSpec(struct('Exposure',.35)); api.SetZoom('100');
s=getappdata(fig,'PhotoState'); expected=uint8(round(255*s.FullResult));
press('export-select','PhotoExport');
assert(exist(output,'file')==2&&isequal(imread(output),expected),'Save dialog output mismatch.');
press('open-cancel','PhotoOpen');
s=getappdata(fig,'PhotoState'); assert(strcmp(s.Source,input)&&s.Spec.Exposure==.35);
press('export-cancel','PhotoExport');
assert(isequal(imread(output),expected),'Cancel modified an exported file.');
press('preset-save','PhotoPresetSave');
assert(exist(fullfile(folder,'settings.mat'),'file')==2);
api.SetSpec(struct('Exposure',-.2));
press('preset-load','PhotoPresetLoad');
s=getappdata(fig,'PhotoState'); assert(s.Spec.Exposure==.35,'Preset dialog did not restore parameters.');
exportapp(fig,fullfile(folder,'dialogs-complete.png'));
writeText(fullfile(folder,'PASS.txt'),'FILTERLAB_NATIVE_DIALOGS_PASS: open/export/cancel/preset');
writeText(fullfile(folder,'stage.txt'),'complete');
fprintf('FILTERLAB_NATIVE_DIALOGS_PASS OUTPUT=%s\n',folder);
    function press(stage,tag)
        writeText(fullfile(folder,'stage.txt'),stage);
        b=findall(fig,'Tag',tag); assert(isscalar(b)&&strcmp(b.Enable,'on'));
        b.ButtonPushedFcn(b,[]); drawnow;
    end
end
function writeText(path,text)
[f,msg]=fopen(path,'w','n','UTF-8'); assert(f~=-1,msg);
done=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'%s',text);
end
