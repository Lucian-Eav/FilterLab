function check_phase_workspace_v25(sourcePath,outputDir)
%CHECK_PHASE_WORKSPACE_V25 Verify a photograph via the normal workspace, then read back every exported PNG.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'app'),fullfile(root,'app','core'));
if ~isfolder(outputDir), mkdir(outputDir); end
studio = FL_photo('Visible','on');
cleanup = onCleanup(@()closeIfAlive(studio)); %#ok<NASGU>
workspaces = findall(studio,'Tag','FilterLabWorkspaces');
select(workspaces,findall(workspaces,'Tag','SamplingPage'));
tabs = findall(workspaces.SelectedTab,'Tag','SamplingExperiments');
phase = findall(tabs,'Tag','SamplingPhaseTab');
assert(isempty(phase.Children));
select(tabs,phase);
api = getappdata(phase,'PhaseActions');
api.Load(sourcePath);
source = imread(sourcePath); % Unrotated RGB fixture
roundBox = findall(phase,'Tag','PhaseRounds');
assert(isscalar(roundBox));
for rounds = [1 2]
    roundBox.Value = rounds;
    feval(roundBox.ValueChangedFcn,roundBox,struct('Value',rounds));
    drawnow;
    s = api.GetState();
    k = 2^rounds;
    assert(s.Step == k && isequal(size(s.Tiles),[k k]));
    assert(isequal(fl_phase_join(s),source));
    for row = 1:k
        for col = 1:k
            tile = s.Tiles{row,col};
            assert(isequal(tile,source(row:k:end,col:k:end,:)));
            icon = findall(phase,'Tag',sprintf('PhaseTile_%d_%d',row,col));
            assert(isscalar(icon) && ~isempty(icon.ImageSource));
        end
    end
    api.ShowOriginal(); drawnow;
    exportapp(studio,fullfile(outputDir,sprintf('山脉-%d张子图.png',k*k)));
    api.ShowJoined(); drawnow;
    folder = api.Export(outputDir);
    assert(numel(dir(fullfile(folder,'*.png'))) == k*k+1);
    assert(isequal(imread(fullfile(folder,'joined.png')),source));
    for row = 1:k
        for col = 1:k
            tileFile = fullfile(folder,sprintf('phase_r%d_c%d.png',row,col));
            assert(isequal(imread(tileFile),s.Tiles{row,col}));
        end
    end
    fprintf('PASS %d phase PNGs and joined PNG; source %d x %d, first phase %d x %d.\n', ...
        k*k,size(source,2),size(source,1),size(s.Tiles{1,1},2),size(s.Tiles{1,1},1));
end
select(tabs,findall(tabs,'Tag','SamplingStripeTab'));
select(tabs,phase);
s = api.GetState(); assert(s.Rounds==2 && isequal(fl_phase_join(s),source));
close(studio); assert(~isgraphics(studio));
end
function select(group,page)
assert(isscalar(group) && isscalar(page));
group.SelectedTab = page;
feval(group.SelectionChangedFcn,group,[]);
drawnow;
end
function closeIfAlive(studio)
if isgraphics(studio), delete(studio); end
end
