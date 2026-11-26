function U=fl_creative_controls(parent,C,cb,requestedTag,U)
%FL_CREATIVE_CONTROLS Creative tool panels; callbacks owned by main workspace.
% An optional tab tag builds only that tool, using an existing placeholder tab.
panel=[.18 .19 .20]; textColor=[.91 .92 .93]; muted=[.65 .69 .73]; input=[.23 .25 .27];
if nargin<5, U=struct('Controls',struct(),'Buttons',gobjects(0),'Tabs',gobjects(0)); end
tags={'PhotoTabFrequency','PhotoTabTilt','PhotoTabMotion','PhotoTabMask','PhotoTabClassic'};
if nargin>=4, tags={char(requestedTag)}; end
for k=1:numel(tags)
    switch tags{k}
        case 'PhotoTabFrequency'
            f=tab('频域','PhotoTabFrequency'); g=grid(f,26);
            U.LessonButton=uibutton(g,'Text','交互教程：从照片到频谱','Tag','PhotoFrequencyLesson', ...
                'BackgroundColor',input,'FontColor',textColor,'FontWeight','bold', ...
                'ButtonPushedFcn',@(~,~)cb.SpectrumLesson());
            U.LessonButton.Layout.Row=1;
            flag(g,'FrequencyEnable','启用频域滤波',3); flag(g,'FrequencyKeepDC','保护平均亮度（DC）',4);
            U.FrequencyMode=drop(g,{'抑制频率','恢复频率'},{'paint','erase'},5,'PhotoFrequencyMode',[]);
            U.FrequencyRadius=slider(g,'笔刷半径 / 频率',.003,.18,.035,6,'PhotoFrequencyRadius',[]);
            U.FrequencyOpacity=slider(g,'笔刷强度',.05,1,1,8,'PhotoFrequencyOpacity',[]);
            btn(g,'在频谱上绘制','PhotoFrequencyPaint',10,@()cb.Tool('frequency'));
            btn(g,'查看照片 / 停止绘制','PhotoFrequencyPhoto',12,@()cb.Tool('none'));
            btn(g,'清空频域笔触','PhotoFrequencyClear',14,@()cb.FrequencyClear());
            note(g,{'红色表示被抑制的频率，正负频率自动成对。','按下拖动绘制，松开后计算照片；每笔可撤销。','频谱来自当前构图的原图亮度。','频域按完整尺寸计算，较大的照片可能稍慢。','强抑制可能产生振铃，降低强度或缩小画笔。'},16,26);
        case 'PhotoTabTilt'
            t=tab('微缩','PhotoTabTilt'); g=grid(t,23);
            flag(g,'TiltEnable','启用微缩景观',1); parameter(g,'TiltWidth','清晰带宽 / 短边',.01,1,3);
            parameter(g,'TiltFeather','过渡宽度 / 短边',.001,.8,5); parameter(g,'TiltBlur','模糊半径 / 原图像素',0,60,7);
            parameter(g,'TiltAngle','清晰带角度 / °',-180,180,9);
            btn(g,'在照片上定位清晰带','PhotoTiltPlace',12,@()cb.Tool('tilt'));
            btn(g,'结束定位','PhotoTiltStop',14,@()cb.Tool('none'));
            note(g,{'拖动照片定位清晰带中心，松开应用。','角度控制清晰带的方向。','清晰带以外逐渐模糊，适合俯拍城市。','可与局部蒙版配合，仅改变指定区域。'},16,23);
        case 'PhotoTabMotion'
            t=tab('运动','PhotoTabMotion'); g=grid(t,27);
            flag(g,'MotionEnable','启用长曝光与运动效果',1);
            U.Controls.MotionType=drop(g,{'方向拖影','变焦拖影','旋转轨迹'},{'directional','zoom','spin'},3,'PhotoCreative_MotionType',@(s,~)cb.Change('MotionType',s.Value));
            parameter(g,'MotionLength','方向拖影长度 / 原图像素',0,120,5); parameter(g,'MotionAngle','方向角度 / °',-180,180,7);
            parameter(g,'MotionZoom','变焦幅度',0,.7,9); parameter(g,'MotionSpin','旋转角度 / °',0,90,11);
            parameter(g,'MotionAmount','效果混合强度',0,1,13);
            btn(g,'在照片上定位运动中心','PhotoMotionPlace',16,@()cb.Tool('motion'));
            btn(g,'结束定位','PhotoMotionStop',18,@()cb.Tool('none'));
            note(g,{'运动中心用于变焦和旋转。','这是对单张照片的艺术模拟。','较长轨迹采用有限次采样，可能出现重复轮廓。','用蒙版擦除主体上的效果，保留背景速度感。'},20,27);
        case 'PhotoTabMask'
            t=tab('蒙版','PhotoTabMask'); g=grid(t,29);
            flag(g,'MaskEnable','启用局部蒙版',1);
            U.Controls.MaskTarget=drop(g,{'仅创意效果','照片调整 + 创意效果'},{'creative','all'},3,'PhotoCreative_MaskTarget',@(s,~)cb.Change('MaskTarget',s.Value));
            U.MaskMode=drop(g,{'涂抹生效区','擦除生效区'},{'paint','erase'},5,'PhotoMaskMode',[]);
            U.MaskRadius=slider(g,'画笔半径 / 当前短边',.005,.3,.07,6,'PhotoMaskRadius',[]);
            U.MaskOpacity=slider(g,'画笔不透明度',.05,1,1,8,'PhotoMaskOpacity',[]);
            parameter(g,'MaskSoftness','边缘羽化',0,1,10); flag(g,'MaskInvert','反选蒙版',12);
            btn(g,'开始涂抹 / 擦除','PhotoMaskPaint',14,@()cb.Tool('mask'));
            btn(g,'结束绘制','PhotoMaskStop',16,@()cb.Tool('none'));
            btn(g,'显示 / 隐藏红色蒙版','PhotoMaskShow',18,@()cb.Mask('show'));
            row=uigridlayout(g,[1 2],'Padding',[0 0 0 0],'BackgroundColor',panel); row.Layout.Row=20;
            btn(row,'清空','PhotoMaskClear',1,@()cb.Mask('clear')); h=btn(row,'全选','PhotoMaskFill',1,@()cb.Mask('fill')); h.Layout.Column=2;
            note(g,{'红色表示效果生效区域；清空后需先涂抹。','每一笔可撤销，羽化可在绘制后调整。','蒙版跟随裁剪、旋转、翻转，原图保持不变。','“仅创意效果”保留整张照片的基础调整。'},22,29);
        case 'PhotoTabClassic'
            t=tab('滤波','PhotoTabClassic'); g=grid(t,19);
            U.Controls.ClassicType=drop(g,{'关闭','Butterworth 10 阶','等波纹 FIR 4 阶','等波纹 FIR 12 阶'}, ...
                {'off','butter10','fir4','fir12'},1,'PhotoCreative_ClassicType',@(s,~)cb.Change('ClassicType',s.Value));
            parameter(g,'ClassicAmount','照片滤波混合强度',0,1,3);
            note(g,{'将题目的三个滤波器用于照片亮度。','照片适配：直流归一化 + 双向行列滤波。','它保持整体亮度、减小相位位移，但幅频响应变为平方。','题目实验页仍严格使用原始系数与因果滤波。','可以用局部蒙版仅处理天空或背景。'},6,19);
        otherwise
            error('fl_creative_controls:tab','未知创意工具标签：%s',tags{k});
    end
end
    function t=tab(name,tag)
        t=findobj(parent,'-depth',1,'Tag',tag);
        if isempty(t), t=uitab(parent,'Title',name,'BackgroundColor',panel,'Tag',tag); end
        U.Tabs(end+1)=t;
    end
    function g=grid(p,n)
        g=uigridlayout(p,[n 1],'RowHeight',repmat({25},1,n),'Padding',[14 14 14 14], ...
            'RowSpacing',5,'BackgroundColor',panel,'Scrollable','on');
    end
    function flag(g,key,txt,row)
        h=uicheckbox(g,'Text',txt,'Value',C.(key),'FontColor',textColor,'Tag',['PhotoCreative_' key], ...
            'ValueChangedFcn',@(s,~)cb.Change(key,s.Value)); h.Layout.Row=row; U.Controls.(key)=h;
    end
    function h=drop(g,items,values,row,tag,fn)
        h=uidropdown(g,'Items',items,'ItemsData',values,'Value',values{1},'Tag',tag, ...
            'BackgroundColor',input,'FontColor',textColor); h.Layout.Row=row;
        if ~isempty(fn), h.ValueChangedFcn=fn; end
    end
    function h=slider(g,txt,lo,hi,value,row,tag,fn)
        hlabel=uilabel(g,'Text',sprintf('%s  %.3g',txt,value),'FontColor',textColor,'FontSize',12); hlabel.Layout.Row=row;
        h=uislider(g,'Limits',[lo hi],'Value',value,'MajorTicks',[],'MinorTicks',[],'Tag',tag, ...
            'ValueChangingFcn',@(~,e)set(hlabel,'Text',sprintf('%s  %.3g',txt,e.Value)));
        h.Layout.Row=row+1; if ~isempty(fn), h.ValueChangedFcn=fn; end
        setappdata(h,'CreativeLabel',hlabel); setappdata(h,'CreativeTitle',txt);
    end
    function parameter(g,key,txt,lo,hi,row)
        U.Controls.(key)=slider(g,txt,lo,hi,C.(key),row,['PhotoCreative_' key],@(s,~)cb.Change(key,s.Value));
    end
    function h=btn(g,txt,tag,row,fn)
        h=uibutton(g,'Text',txt,'Tag',tag,'BackgroundColor',input,'FontColor',textColor, ...
            'ButtonPushedFcn',@(~,~)fn()); h.Layout.Row=row; U.Buttons(end+1)=h;
    end
    function note(g,txt,first,last)
        h=uilabel(g,'Text',txt,'WordWrap','on','FontColor',muted,'FontSize',11); h.Layout.Row=[first last];
    end
end
