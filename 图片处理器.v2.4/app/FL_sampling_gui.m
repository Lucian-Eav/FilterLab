function panel = FL_sampling_gui(varargin)
%FL_SAMPLING_GUI Host the two spatial sampling tools, preserving each view on return.
p = inputParser;
p.addParameter('Parent',[]);
p.parse(varargin{:});
panel = uipanel(p.Results.Parent,'BorderType','none','Tag','SamplingPanel');
try
    layout = uigridlayout(panel,[1 1],'Padding',[0 0 0 0]);
    pages = uitabgroup(layout,'Tag','SamplingExperiments');
    stripes = uitab(pages,'Title','条纹与混叠','Tag','SamplingStripeTab');
    photo = uitab(pages,'Title','照片抗混叠','Tag','SamplingPhotoTab');
    pages.SelectionChangedFcn = @(~,~)mount(pages.SelectedTab);
    actions = struct('ShowStripes',@()show(stripes),'ShowPhoto',@()show(photo));
    setappdata(panel,'SamplingActions',actions);
    show(stripes);
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
            else
                FL_sampling_photo(page);
            end
        catch err
            delete(page.Children);
            rethrow(err);
        end
    end
end
