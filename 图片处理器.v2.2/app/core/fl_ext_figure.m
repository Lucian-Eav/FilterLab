function f=fl_ext_figure(view,visible)
%FL_EXT_FIGURE Use the same panels for report figures and interactive displays.
f=figure('Name',view.Title,'NumberTitle','off','Visible',visible,'Color','white',...
    'Units','pixels','Position',[60 60 1200 740]);
try
    count=numel(view.Panels); cols=min(3,count);
    t=tiledlayout(f,ceil(count/cols),cols,'Padding','compact','TileSpacing','compact');
    for j=1:count, fl_ext_draw_panel(nexttile(t),view.Panels{j}); end
    h=title(t,view.Title,'Interpreter','none'); h.FontName=f.CurrentAxes.FontName;
catch ex
    delete(f); rethrow(ex);
end
end
