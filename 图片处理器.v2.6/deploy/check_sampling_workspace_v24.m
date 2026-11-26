function check_sampling_workspace_v24(outputDir)
%CHECK_SAMPLING_WORKSPACE_V24 Check the two actual entry points and tab lifecycle.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'app'),fullfile(root,'app','core'));
if ~isfolder(outputDir), mkdir(outputDir); end
studio = FL_photo('Visible','on');
cleanup = onCleanup(@()discard(studio)); %#ok<NASGU>
workspaces = widget(studio,'FilterLabWorkspaces');
page = widget(studio,'SamplingPage');
assert(isempty(page.Children),'Sampling was built before the tab was opened.');
selectTab(workspaces,page);
panel = widget(page,'SamplingPanel');
experiments = widget(panel,'SamplingExperiments');
stripePage = widget(panel,'SamplingStripeTab');
photoPage = widget(panel,'SamplingPhotoTab');
assert(isequal(experiments.SelectedTab,stripePage) && isempty(photoPage.Children));
assert(~isempty(findall(stripePage,'Type','axes')),'Missing stripe axes.');
originalStripes = stripePage.Children;
% UIAxes layout propagates asynchronously when a nested tab first becomes visible.
a = widget(stripePage,'StripesProfile'); b = widget(stripePage,'StripesSpectrum');
t = tic;
while toc(t)<6
    drawnow; pause(.08);
    if a.Position(3)>160 && b.Position(3)>160 && abs(a.Position(3)-b.Position(3))<50 && b.Position(1)>a.Position(1)+100, break; end
end
assert(b.Position(1)>a.Position(1)+100 && b.Position(3)>160,'Spectrum did not finish laying out.');
exportapp(studio,fullfile(outputDir,'条纹与混叠.png'));
selectTab(experiments,photoPage);
assert(~isempty(findall(photoPage,'Type','axes')),'Missing photo axes.');
originalPhoto = photoPage.Children;
exportapp(studio,fullfile(outputDir,'照片抗混叠.png'));
selectTab(workspaces,widget(studio,'BarrierPage'));
link = widget(workspaces.SelectedTab,'BarrierOpenSampling');
link.ButtonPushedFcn(link,[]); drawnow;
assert(isequal(workspaces.SelectedTab,page) && isequal(experiments.SelectedTab,stripePage));
selectTab(experiments,photoPage);
assert(isequal(stripePage.Children,originalStripes) && isequal(photoPage.Children,originalPhoto));
selectTab(workspaces,widget(studio,'PhotoWorkspace'));
selectTab(workspaces,page);
assert(isequal(experiments.SelectedTab,photoPage),'Switching workspaces lost the active experiment.');
close(studio); assert(~isgraphics(studio));
fprintf('PASS: direct tab, two lazy tools, barrier shortcut, retained views and window close.\n');
end
function h = widget(parent,tag)
h = findall(parent,'Tag',tag);
assert(isscalar(h),'Missing or duplicate control %s.',tag);
end
function selectTab(group,tab)
group.SelectedTab = tab;
group.SelectionChangedFcn(group,[]);
drawnow;
end
function discard(fig)
if isgraphics(fig), delete(fig); end
end
