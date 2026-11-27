function panel = FL_sampling_gui(varargin)
%FL_SAMPLING_GUI Mount spatial sampling tools on demand and retain their views.
p = inputParser;
p.addParameter('Parent',[]);
p.addParameter('Initial','Stripes',@(name)any(strcmp(name,{'Stripes','Photo','Phase'})));
p.parse(varargin{:});
if ~isdeployed, addpath(fullfile(fileparts(mfilename('fullpath')),'core')); end
theme = fl_ui_theme();
panel = uipanel(p.Results.Parent,'BorderType','none','BackgroundColor',theme.Paper,'Tag','SamplingPanel');
try
    layout = uigridlayout(panel,[1 1],'Padding',[0 0 0 0],'BackgroundColor',theme.Paper);
    pages = uitabgroup(layout,'Tag','SamplingExperiments');
    stripes = uitab(pages,'Title','条纹与混叠','BackgroundColor',theme.Paper,'Tag','SamplingStripeTab');
    photo = uitab(pages,'Title','照片抗混叠','BackgroundColor',theme.Paper,'Tag','SamplingPhotoTab');
    phase = uitab(pages,'Title','多相拆图与重组','Tag','SamplingPhaseTab');
    pages.SelectionChangedFcn = @(~,~)mount(pages.SelectedTab);
    actions = struct('ShowStripes',@()show(stripes),'ShowPhoto',@()show(photo),'ShowPhase',@()show(phase));
    setappdata(panel,'SamplingActions',actions);
    actions.(['Show' p.Results.Initial])();
catch err
    delete(panel);
    rethrow(err);
end

    function show(page)
        mount(page);
        pages.SelectedTab = page;
    end
    function mount(page)
        if ~isempty(page.Children), return; end
        try
            if isequal(page,stripes)
                FL_sampling_stripes(page);
            elseif isequal(page,photo)
                FL_sampling_photo(page);
            else
                FL_phase_gui(page);
            end
        catch err
            delete(page.Children);
            rethrow(err);
        end
    end
end
