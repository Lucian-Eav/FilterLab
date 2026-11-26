function report = check_pages_v26(repetitions,appDir)
%CHECK_PAGES_V26 Measure a visible workspace switch through a real control callback.
% check_pages_v26(3,fullfile(v25,'app')) works in a fresh MATLAB for baseline.
if nargin<1, repetitions=3; end
if nargin<2, appDir=fullfile(fileparts(fileparts(mfilename('fullpath'))),'app'); end
validateattributes(repetitions,{'numeric'},{'scalar','integer','positive'});
oldPath=path; pathGuard=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(appDir,fullfile(appDir,'core'),'-begin');
assert(strcmpi(which('FL_photo'),fullfile(appDir,'FL_photo.m')),'Another app shadows the benchmark target.');
tags={'SamplingPage','ExtensionsPage','FreqToolsPage','BarrierPage'};
rows=cell(2*numel(tags)*repetitions,6); next=0;
for run=1:repetitions
    fig=FL_photo('Visible','on'); figGuard=onCleanup(@()delete(fig));
    group=one(fig,'FilterLabWorkspaces'); home=one(group,'PhotoWorkspace'); drawnow;
    % Rotate the order so the same page does not always pay first graphics use.
    order=circshift(1:numel(tags),[0 1-run]); handles=cell(1,numel(tags));
    for pass=1:2
        for id=order
            tab=one(group,tags{id}); clock=tic;
            select(group,tab); drawnow; switchTime=toc(clock);
            [control,verify]=probe(tab,id);
            assert(isequal(group.SelectedTab,tab) && isvalid(control) && strcmp(control.Enable,'on'));
            clock=tic; verify(); drawnow; elapsed=switchTime+toc(clock);
            if pass==1, handles{id}=control; else, assert(isequal(control,handles{id}),'Rebuilt control on revisit.'); end
            next=next+1; rows(next,:)={run,tags{id},pass,elapsed,numel(findall(tab)),numel(findall(tab,'Type','axes'))};
            fprintf('page run=%d name=%s visit=%d interactive_sec=%.4f objects=%d axes=%d\n',rows{next,:});
            if id==4
                % Restore phase A outside the timed visit. Both visits test an A-to-B change.
                reset=one(tab,'BarrierShowA'); feval(reset.ButtonPushedFcn,reset,[]); drawnow;
            end
            select(group,home); drawnow;
        end
    end
    clear figGuard
end
report=cell2table(rows,'VariableNames',{'Run','Page','Visit','InteractiveSeconds','Objects','Axes'});
for id=1:numel(tags)
    subset=strcmp(report.Page,tags{id});
    fprintf('page median %s first=%.4fs revisit=%.4fs (n=%d each)\n',tags{id}, ...
        median(report.InteractiveSeconds(subset & report.Visit==1)),median(report.InteractiveSeconds(subset & report.Visit==2)),repetitions);
end
end

function select(group,tab)
group.SelectedTab=tab; feval(group.SelectionChangedFcn,group,[]);
end

function [control,verify]=probe(tab,id)
switch id
    case 1
        control=one(tab,'StripesStep'); api=getappdata(one(tab,'StripesView'),'StripesActions');
        verify=@()stepProbe(control,api);
    case 2
        control=one(tab,'ExtensionsOrder'); status=one(tab,'ExtensionsStatus');
        verify=@()extensionsProbe(control,status);
    case 3
        panel=one(tab,'FreqToolsWorkspace'); status=one(tab,'FreqToolsStatus');
        control=findall(panel,'Type','uidropdown','Value','median');
        if isempty(control), control=findall(panel,'Type','uidropdown','Value','mean'); end
        assert(isscalar(control),'Missing default stack-mode selector.'); verify=@()freqProbe(control,status);
    case 4
        control=one(tab,'BarrierShowB'); offset=one(tab,'BarrierOffset'); width=one(tab,'BarrierWidth');
        verify=@()barrierProbe(control,offset,width);
end
end

function stepProbe(control,api)
if control.Value==4, control.Value=2; else, control.Value=4; end
feval(control.ValueChangedFcn,control,[]); state=api.GetState();
assert(state.Step==control.Value && numel(state.SampleX)==256/control.Value);
end

function extensionsProbe(control,status)
control.Value=2+mod(control.Value,6); status.Text=''; feval(control.ValueChangedFcn,control,[]);
assert(contains(status.Text,'已更改'));
end

function freqProbe(control,status)
if strcmp(control.Value,'median'), control.Value='mean'; else, control.Value='median'; end
status.Text=''; feval(control.ValueChangedFcn,control,[]); assert(contains(status.Text,'已更新'));
end

function barrierProbe(control,offset,width)
assert(offset.Value==0); feval(control.ButtonPushedFcn,control,[]); assert(offset.Value==width.Value);
end

function h=one(host,tag)
h=findall(host,'Tag',tag); assert(isscalar(h),'Missing or duplicate %s.',tag);
end
