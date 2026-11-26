function report=bench_brush_v26(appDir,visible)
%BENCH_BRUSH_V26 Time editor stroke commits, UI flush, and the first photo view.
% Run this SAME function once per version with its absolute app directory.
% visible='on' includes visible figure drawing. Source is deterministic.
if nargin<2, visible='on'; end
savedPath=path; savedDir=pwd; temp=tempname; mkdir(temp);
cleanup=onCleanup(@()restore(savedPath,savedDir,temp)); %#ok<NASGU>
cd(appDir); addpath(appDir,fullfile(appDir,'core'),'-begin');
clear FL_photo fl_photo_pipeline fl_photo_process fl_creative_process fl_frequency_view fl_frequency_mask fl_frequency_brush_view
assert(strcmpi(which('FL_photo'),fullfile(appDir,'FL_photo.m')),'Wrong app on path.');
[X,Y]=meshgrid(1:1536,1:1024);
pic=uint8(cat(3,mod(X+2*Y,256),128+100*cos(2*pi*(X/11+Y/19)),mod(3*X+Y,256)));
source=fullfile(temp,'bench.png'); imwrite(pic,source);
h=FL_photo('File',source,'Visible',visible); cleanFigure=onCleanup(@()delete(h)); %#ok<NASGU>
a=getappdata(h,'PhotoActions'); clk=tic; a.SetTool('frequency'); drawnow; enter=toc(clk);
N=8; commit=zeros(1,N); flush=commit; t=(0:31)'/31;
for j=1:N
    points=[-.3+.18*t+.025*j, .09+.07*sin(2*pi*t+.2*j)]; mode='paint'; if mod(j,3)==0, mode='erase'; end
    clk=tic; a.PaintFrequency(points,.028,.75,mode); commit(j)=toc(clk);
    drawnow; flush(j)=toc(clk);
end
clk=tic; a.SetTool('none'); drawnow; photo=toc(clk); st=getappdata(h,'PhotoState');
assert(numel(st.Creative.FrequencyStrokes)==N && ~isempty(st.Result));
report=struct('App',appDir,'Visibility',visible,'Size',[1024 1536],'Strokes',N, ...
    'EnterSpectrumSeconds',enter,'CommitSeconds',commit,'ThroughFlushSeconds',flush, ...
    'MedianCommitSeconds',median(commit),'MedianThroughFlushSeconds',median(flush), ...
    'FirstPhotoSeconds',photo,'TotalThroughPhotoSeconds',sum(flush)+photo, ...
    'PhotoMean',double(mean(st.Result(:))));
fprintf('BRUSH %s | %s | 1536x1024 | %d strokes | open spectrum %.3fs | median commit %.3fs | median with flush %.3fs | first photo %.3fs | edits + first photo %.3fs | photo mean %.8f\n', ...
    appDir,visible,N,enter,median(commit),median(flush),photo,report.TotalThroughPhotoSeconds,report.PhotoMean);
end
function restore(savedPath,savedDir,temp)
cd(savedDir); path(savedPath); if isfolder(temp), rmdir(temp,'s'); end
end
