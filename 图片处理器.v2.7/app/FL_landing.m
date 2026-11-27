function [root,openButton,enterButton] = FL_landing(parent,openPhoto,enterEditor,openTask)
%FL_LANDING Two entry points into the photo studio and its experiment directory.
ink = [.11 .15 .16]; paper = [.935 .945 .93]; teal = [.035 .33 .34]; secondary = [.29 .34 .34];
root = uipanel(parent,'BorderType','none','BackgroundColor',paper,'Tag','PhotoStart');
root.AutoResizeChildren='off';
root.Layout.Row = [1 2];
stack = uigridlayout(root,[1 1],'Padding',[0 0 0 0],'BackgroundColor',paper);
home = uigridlayout(stack,[1 2],'ColumnWidth',{'1.05x','1x'},'Padding',[0 0 0 0], ...
    'ColumnSpacing',0,'BackgroundColor',paper);
home.Layout.Row = 1; home.Layout.Column = 1;
intro = uigridlayout(home,[8 1],'RowHeight',{'1x',28,72,54,46,40,28,'1x'}, ...
    'RowSpacing',6,'Padding',[42 18 20 18],'BackgroundColor',paper);
intro.Layout.Column=1;
placeLabel(intro,'FilterLab   /   v2.7',2,18,teal,'bold');
title = placeLabel(intro,'图像工作室',3,40,ink,'bold'); title.Tag='PhotoStartTitle';
hint = placeLabel(intro,'编辑照片，或从一个采样与滤波实验开始。',4,15,secondary,'normal'); hint.Tag='PhotoStartHint'; hint.WordWrap='on';
commands = uigridlayout(intro,[1 3],'ColumnWidth',{132,132,'1x'},'Padding',[0 0 0 0], ...
    'ColumnSpacing',8,'BackgroundColor',paper); commands.Layout.Row=5;
openButton = uibutton(commands,'Text','打开照片…','Tag','PhotoOpen','FontSize',15,'FontWeight','bold', ...
    'FontColor',[1 1 1],'BackgroundColor',teal,'ButtonPushedFcn',@(~,~)openPhoto());
uibutton(commands,'Text','浏览实验','Tag','PhotoBrowseExperiments','FontSize',15,'FontColor',ink, ...
    'BackgroundColor',[.99 .99 .98],'ButtonPushedFcn',@(~,~)showDirectory());
links = uigridlayout(intro,[1 2],'ColumnWidth',{132,'1x'},'Padding',[0 3 0 3],'BackgroundColor',paper); links.Layout.Row=6;
enterButton = uibutton(links,'Text','进入空白编辑器','Tag','PhotoEnterEditor','FontSize',12, ...
    'FontColor',secondary,'BackgroundColor',paper,'ButtonPushedFcn',@(~,~)enterEditor());
plate = uigridlayout(home,[2 1],'RowHeight',{'1x',26},'RowSpacing',6,'Padding',[12 18 12 10], ...
    'BackgroundColor',[.105 .145 .15]); plate.Layout.Column=2;
uiimage(plate,'ImageSource',fullfile(fileparts(mfilename('fullpath')),'assets','welcome-mountain.jpg'), ...
    'ScaleMethod','fit','Tag','HomeMountain');
caption=placeLabel(plate,'山脉  /  工作区样片',2,12,[.82 .86 .84],'normal'); caption.HorizontalAlignment='center';
directory=[];
window=ancestor(root,'figure');
setappdata(root,'FitLanding',@fit);
root.SizeChangedFcn=@(~,~)fit();
fit();
    function showDirectory()
        if isempty(directory) || ~isvalid(directory)
            directory=uigridlayout(stack,[3 1],'RowHeight',{44,36,'1x'},'RowSpacing',6, ...
                'Padding',[26 16 26 16],'BackgroundColor',paper,'Tag','PhotoExperimentDirectory');
            directory.Layout.Row=1; directory.Layout.Column=1;
            head=uigridlayout(directory,[1 2],'ColumnWidth',{'1x',110},'Padding',[0 0 0 0],'BackgroundColor',paper);
            placeLabel(head,'实验目录',1,28,ink,'bold');
            uibutton(head,'Text','返回首页','Tag','HomeDirectoryBack','ButtonPushedFcn',@(~,~)back());
            placeLabel(directory,'选择想观察的现象，直接进入对应实验。',2,14,secondary,'normal');
            list=uigridlayout(directory,[7 2],'ColumnWidth',{'1.4x','1x'},'RowHeight',repmat({46},1,7), ...
                'Padding',[8 8 8 8],'RowSpacing',7,'ColumnSpacing',12,'BackgroundColor',[.98 .985 .975]);
            list.Layout.Row=3; list.Scrollable='on';
            names={'移动光栅，切换两幅图','把照片拆成 4 或 16 张','比较细纹抽样效果','找出条纹里的混叠','运行六道滤波实验','去除摩尔纹或文档底纹','叠加连拍、比较清晰度'};
            topics={'栅栏图像错觉','多相拆图与重组','照片抗混叠','条纹与混叠','题目滤波实验','扩展应用实验','频域实用工坊'};
            keys={'Barrier','Phase','Photo','Stripes','Assignment','Extensions','FreqTools'};
            for k=1:numel(keys)
                id=keys{k}; b=uibutton(list,'Text',names{k},'FontSize',14,'FontColor',teal,'FontWeight','bold', ...
                    'BackgroundColor',[.92 .95 .935],'Tag',['HomeGo' id],'ButtonPushedFcn',@(~,~)openTask(id));
                b.Layout.Row=k; b.Layout.Column=1;
                txt=placeLabel(list,topics{k},k,13,secondary,'normal'); txt.Layout.Column=2;
            end
        end
        home.Visible='off'; directory.Visible='on';
    end
    function back()
        directory.Visible='off'; home.Visible='on';
    end
    function fit()
        if window.Position(3)<800
            home.ColumnWidth={'1x',0}; plate.Visible='off'; intro.Padding=[22 8 18 8];
        else
            home.ColumnWidth={'1.05x','1x'}; plate.Visible='on'; intro.Padding=[42 18 20 18];
        end
    end
end
function txt=placeLabel(parent,text,row,size,color,weight)
txt=uilabel(parent,'Text',text,'FontSize',size,'FontColor',color,'FontWeight',weight);
txt.Layout.Row=row; txt.Layout.Column=1;
end
