function fl_ext_draw_panel(ax,p)
%FL_EXT_DRAW_PANEL Draw numerical data with explicit image/plot conventions.
persistent font
if isempty(font)
    available=listfonts;
    preferred={'Microsoft YaHei','Microsoft YaHei UI','Noto Sans CJK SC','PingFang SC','SimHei'};
    hit=find(ismember(preferred,available),1);
    if isempty(hit), font=get(groot,'defaultAxesFontName'); else, font=preferred{hit}; end
end
ax.FontName=font; ax.FontSize=10;
switch p.Kind
    case 'image'
        if ismatrix(p.Data)
            imagesc(ax,p.Data,[0 1]); colormap(ax,gray(256));
        else
            image(ax,min(1,max(0,p.Data)));
        end
        axis(ax,'image'); ax.XTick=[]; ax.YTick=[];
    case 'line'
        if isempty(p.X), plot(ax,p.Data,'LineWidth',1.25);
        else, plot(ax,p.X,p.Data,'LineWidth',1.25); end
        grid(ax,'on');
        if ~isempty(p.Labels), legend(ax,p.Labels,'Interpreter','none','Location','best'); end
    case 'pz'
        phi=linspace(0,2*pi,257); plot(ax,cos(phi),sin(phi),':','Color',[.4 .4 .4]);
        hold(ax,'on'); z=p.Data;
        plot(ax,real(z(:,1)),imag(z(:,1)),'x','LineWidth',1.4);
        plot(ax,real(z(:,2)),imag(z(:,2)),'o','LineWidth',1.2);
        hold(ax,'off'); axis(ax,'equal'); grid(ax,'on');
        legend(ax,{'单位圆','极点','零点'},'Location','best');
    otherwise
        error('fl_ext_draw_panel:kind','未知图示类型 %s',p.Kind);
end
ax.FontName=font;
title(ax,p.Title,'Interpreter','none','FontName',font,'FontSize',11);
if isfield(p,'XLabel'), xlabel(ax,p.XLabel,'Interpreter','none'); end
if isfield(p,'YLabel'), ylabel(ax,p.YLabel,'Interpreter','none'); end
end
