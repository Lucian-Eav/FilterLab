function bench_interaction_v26(package,source,out,tag)
% Compare real UI actions including pending graphics flushes, in separate engines.
app=fullfile(package,'app'); addpath(app,fullfile(app,'core'),'-begin');
assert(strcmpi(which('FL_photo'),fullfile(app,'FL_photo.m')));
if ~isfolder(out), mkdir(out); end
R=struct('Version',version,'Tag',tag,'Source',source); R.Trials=cell(1,3);
for trial=1:3
    T=struct(); t=tic; fig=FL_photo(); done=onCleanup(@()delete(fig)); drawnow;
    T.EmptyShell=toc(t); A=getappdata(fig,'PhotoActions');
    t=tic; A.Open(source); drawnow; T.FirstPhoto=toc(t);
    A.SetView('result'); drawnow; spec=fl_photo_spec();
    for j=1:4
        spec.SharpenAmount=.25+j*.12; t=tic; A.SetSpec(spec); drawnow; T.Sharpen(j)=toc(t);
    end
    for j=1:4
        spec.Exposure=.10*j; t=tic; A.SetSpec(spec); drawnow; T.Exposure(j)=toc(t);
    end
    state=getappdata(fig,'PhotoState'); adjusted=state.PreviewResult; A.SetView('spectrum'); drawnow;
    for j=1:5
        points=[linspace(.03,.15,18)'+.018*j linspace(-.22,-.11,18)']; mode='paint'; if j==5, mode='erase'; end
        t=tic; A.PaintFrequency(points,.014,.65,mode); drawnow; T.SpectrumStroke(j)=toc(t);
    end
    t=tic; A.SetView('result'); drawnow; T.AfterBrush=toc(t); state=getappdata(fig,'PhotoState'); brushed=state.PreviewResult;
    file=fullfile(out,[tag '-' num2str(trial) '.png']); t=tic; A.Export(file); T.Export=toc(t);
    if trial==1
        ref=fullfile(out,'baseline-output.mat');
        if strcmp(tag,'baseline'), save(ref,'adjusted','brushed');
        else
            base=load(ref); T.PreviewError=[checkArray(base.adjusted,adjusted) checkArray(base.brushed,brushed)];
            T.ExportError=checkArray(imread(fullfile(out,'baseline-1.png')),imread(file));
            assert(max(T.PreviewError)<2e-6 && T.ExportError<=1,'Main editor output differs');
        end
    end
    for key={'OpenSampling','OpenBarrier','OpenFreqTools','OpenExtensions'}
        k=key{1}; t=tic; panel=A.(k)(); drawnow; T.(k)=toc(t); assert(isgraphics(panel)&&~isempty(panel.Children));
    end
    R.Trials{trial}=T; disp(T); clear done; drawnow;
    fid=fopen(fullfile(out,[tag '.json']),'w','n','UTF-8'); assert(fid>=0); fprintf(fid,'%s',jsonencode(R)); fclose(fid);
end
end
function err=checkArray(x,y)
assert(isequal(size(x),size(y))&&strcmp(class(x),class(y))&&all(isfinite(x(:)))&&all(isfinite(y(:)))); err=max(abs(double(x(:))-double(y(:))));
end
