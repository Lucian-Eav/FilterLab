function ok = fl_ft_selftest(verbose)
%FL_FT_SELFTEST Numerical, export, regression and headless UI acceptance.
if nargin<1, verbose=true; end
root=fileparts(mfilename('fullpath')); addpath(root,fullfile(root,'core'));
passed=0; failed=0;
runGroup('原有自检',@testRegression);
runGroup('公共输入',@testInput);
runGroup('连拍堆栈',@testBurst);
runGroup('清晰度排序',@testSharpness);
runGroup('隐形水印',@testWatermark);
runGroup('光学效果',@testOptics);
runGroup('CLI 与导出',@testCli);
runGroup('独立 GUI',@testGui);
runGroup('主界面嵌入',@testEmbedded);
ok=failed==0;
if verbose, fprintf('\n频域实用工坊自检：%d 项通过，%d 项失败。\n',passed,failed); end

    function runGroup(name,fn)
        try, fn(); catch ex
            check(false,[name '运行'],sprintf('%s %s',ex.identifier,ex.message));
        end
    end
    function check(condition,name,detail)
        if condition, passed=passed+1; label='PASS';
        else, failed=failed+1; label='FAIL'; end
        if verbose, fprintf(' [%s] %s  %s\n',label,name,detail); end
    end
    function testRegression()
        check(fl_selftest(false),'原有核心自检','fl_selftest(false)');
        check(fl_ext_selftest(false),'原有扩展自检','fl_ext_selftest(false)');
    end
    function testInput()
        state=rng;
        kinds={'burst_crowd','burst_night','burst_sharpness','watermark_photo','night_lights'};
        same=true; ranges=true;
        for k=1:numel(kinds)
            a=fl_ft_samples(kinds{k}); b=fl_ft_samples(kinds{k});
            same=same && isequal(a,b);
            if ~iscell(a), a={a}; end
            ranges=ranges && all(cellfun(@validImage,a));
        end
        check(same && ranges && isequal(state,rng),'五套确定性样例','合法 RGB，重复一致，恢复 rng');
        a=fl_ft_samples('normalize',{uint8(ones(20,30)*128),zeros(20,30,3)},16);
        check(numel(a)==2 && all(cellfun(@validImage,a)) && max(size(a{1},1),size(a{1},2))==16, ...
            '数值元胞规范化','整数灰度扩展 RGB 并限制最长边');
        [f,m]=fl_ft_samples('burst_crowd',[],128);
        [~,original]=fl_ft_samples('burst_crowd');
        check(size(f{1},1)==128 && size(m.Clean,1)==128 && ...
            max(abs(m.TrueShifts(:)-original.TrueShifts(:)*127/255))<1e-12, ...
            '样例真值缩放','Clean 与亚像素位移同步缩放');
    end
    function testBurst()
        kinds={'burst_crowd','burst_night'}; modes={'median','mean'};
        for k=1:2
            [f,m]=fl_ft_samples(kinds{k});
            o=struct('Mode',modes{k},'Clean',m.Clean,'TrueShifts',m.TrueShifts);
            r=fl_ft_burst_stack(f,o);
            err=max(hypot(r.Shifts(:,1)-(m.TrueShifts(:,1)-m.TrueShifts(1,1)), ...
                r.Shifts(:,2)-(m.TrueShifts(:,2)-m.TrueShifts(1,2))));
            check(err<.25,[kinds{k} ' 亚像素位移'],sprintf('最大欧氏误差 %.6f px',err));
            q=r.Metrics;
            check(q.StackPSNR>q.SinglePSNR+3 && q.StackSSIM>q.SingleSSIM+.03, ...
                [kinds{k} ' 质量'],sprintf('PSNR %.4f → %.4f dB，SSIM %.6f → %.6f', ...
                q.SinglePSNR,q.StackPSNR,q.SingleSSIM,q.StackSSIM));
            check(validImage(r.Stacked) && all(isfinite(r.Aligned(:))) && q.ResidualAfter<q.ResidualBefore, ...
                [kinds{k} ' 裁剪与残差'],sprintf('公共区域 %s，残差下降 %.2f%%',mat2str(r.CropRect),100*q.ResidualReduction));
            if k==2
                check(q.NoiseReduction>.55 && q.StackPSNR-q.SinglePSNR>6,'夜景降噪门槛', ...
                    sprintf('标准差下降 %.3f%%，PSNR 提升 %.4f dB',100*q.NoiseReduction,q.StackPSNR-q.SinglePSNR));
            end
        end
        [f,m]=fl_ft_samples('burst_crowd');
        r=fl_ft_burst_stack(f,struct('RefIndex',3,'Clean',m.Clean,'TrueShifts',m.TrueShifts,'Mode','trimmed','AutoCrop',false));
        err=r.Shifts-(m.TrueShifts-m.TrueShifts(3,:));
        check(validImage(r.Stacked) && isequal(size(r.Stacked),size(f{1})) && ...
            all(r.Shifts(3,:)==0) && max(hypot(err(:,1),err(:,2)))<.25, ...
            '截尾均值与非首帧参考','关闭裁剪仍保持有限像素与正确位移方向');
        r=fl_ft_burst_stack(f(1),struct('Mode','trimmed'));
        check(isequal(r.Stacked,f{1}) && r.Metrics.FrameCount==1,'单帧堆栈','截尾模式安全回退');
        expectError(@()fl_ft_burst_stack({f{1},f{2}(1:end-1,:,:)},struct()), ...
            'fl_ft_burst_stack:frames','不等尺寸连拍校验');
    end
    function testSharpness()
        [f,m]=fl_ft_samples('burst_sharpness'); r=fl_ft_sharpness_rank(f,[],struct());
        check(r.BestIndex==m.SharpIndex && r.Table.FrameIndex(1)==m.SharpIndex && r.Table.Score(1)==100, ...
            '锐利帧排名第一',sprintf('推荐帧 %d，真值 %d',r.BestIndex,m.SharpIndex));
        ids=find(isfinite(m.ShakeAngles)); errorDeg=abs(mod(r.ShakeAngle(ids)'-m.ShakeAngles(ids)+90,180)-90);
        check(all(errorDeg<12),'频谱正交手抖角度',sprintf('真实角 %s°，估计 %s°，误差 %s°', ...
            mat2str(m.ShakeAngles(ids)),mat2str(r.ShakeAngle(ids)',6),mat2str(errorDeg,5)));
        check(all(diff(r.Table.Score)<=0) && all(isnan(r.ShakeAngle(setdiff(1:6,ids)))) && ...
            numel(r.Spectra)==6 && isequal(r.BestImage,f{m.SharpIndex}), ...
            '排序与方向诊断','柔焦帧通过方向性筛选，频谱按原帧索引返回');
        single=fl_ft_sharpness_rank(f(4),{'single'},struct());
        check(single.BestIndex==1 && height(single.Table)==1,'单张清晰度体检','表格与推荐正常');
    end
    function testWatermark()
        x=fl_ft_samples('watermark_photo'); state=rng;
        r=fl_ft_watermark('embed',x,struct()); v=fl_ft_watermark('inspect',x,struct());
        check(r.ImagResidual<1e-11 && r.PSNR>=36 && r.SSIM>=.95,'水印实数与空域质量', ...
            sprintf('虚部 %.3g，PSNR %.5f dB，SSIM %.7f',r.ImagResidual,r.PSNR,r.SSIM));
        check(r.DetectCorr>.45 && r.Attack.Noise.DetectCorr>.4 && r.Attack.Tone.DetectCorr>.4 && ...
            min([r.DetectCorr,r.Attack.Noise.DetectCorr,r.Attack.Tone.DetectCorr])>v.DetectCorr+.3, ...
            '独立查验与两种扰动',sprintf('原图 %.5f，水印 %.5f，加噪 %.5f，调色 %.5f', ...
            v.DetectCorr,r.DetectCorr,r.Attack.Noise.DetectCorr,r.Attack.Tone.DetectCorr));
        check(isequal(state,rng),'水印 rng 保护','攻击验证使用局部随机流');
        icons={'heart','star','smile','plus'}; good=true;
        for k=1:numel(icons)
            q=fl_ft_watermark('embed',x(1:255,1:253,:), ...
                struct('Mode','icon','Icon',icons{k},'RunAttackTest',false));
            good=good && q.ImagResidual<1e-11 && validImage(q.Output);
        end
        q=fl_ft_watermark('embed',x(1:48,1:51,:),struct('Text','A1-_.!','RunAttackTest',false));
        check(good && q.ImagResidual<1e-11,'奇偶尺寸、点阵符号与图标','四种图标和小图均保持共轭对称');
        pattern=zeros(20); pattern(3:8,5:15)=1; pattern(9:17,9:11)=1;
        q=fl_ft_watermark('embed',x,struct('Mode','image','PatternImage',pattern,'RunAttackTest',false));
        check(validImage(q.Output) && q.ImagResidual<1e-11 && q.DetectCorr>.3, ...
            '自定义水印图标',sprintf('检出相关性 %.5f',q.DetectCorr));
    end
    function testOptics()
        x=fl_ft_samples('night_lights'); r=fl_ft_optics(x,struct('Aperture','pent5'));
        K=r.PSFKernel; symmetric=max(abs(K(:)-reshape(rot90(K,2),[],1)));
        center=(size(K,1)+1)/2; angles=0:359;
        rays=mean(interp2(K,center+(8:21)'.*cosd(angles),center+(8:21)'.*sind(angles)),1);
        peaks=find(rays>circshift(rays,1) & rays>=circshift(rays,-1))-1;
        check(symmetric<1e-12 && abs(sum(K(:))-1)<1e-12 && numel(peaks)==10 && ...
            max(abs(diff([peaks peaks(1)+360])-36))<=2, ...
            '五叶片衍射十射线',sprintf('中心对称误差 %.3g，方向 %s°',symmetric,mat2str(peaks)));
        mask=fl_ft_luma(r.Highlights)>0;
        support=conv2(double(mask),ones(size(K)),'same')>0;
        dark=~support & fl_ft_luma(x.^2.2)<.02;
        delta=fl_ft_luma(r.Output.^2.2-x.^2.2);
        farError=max(abs(delta(dark))); halo=support & ~mask;
        check(validImage(r.Output) && r.Metrics.EnergyIncrease>1e-5 && mean(delta(halo))>1e-4 && ...
            nnz(dark)>100 && farError<1e-10,'星芒增强与纯暗背景', ...
            sprintf('平均线性光增量 %.6g，光芒区域 %.6g，远暗区最大误差 %.3g', ...
            r.Metrics.EnergyIncrease,mean(delta(halo)),farError));
        b=fl_ft_optics(x,struct('Effect','bokeh','Aperture','heart'));
        z=fl_ft_optics(x,struct('Intensity',0));
        check(validImage(b.Output) && b.Metrics.EnergyIncrease>0 && isequal(z.Output,x), ...
            '心形散景与零强度','心形能量增强，零强度严格返回原像素');
        pattern=zeros(21); pattern(3:18,9:12)=1; pattern(9:12,3:18)=1;
        b=fl_ft_optics(x,struct('Effect','bokeh','Aperture','custom','CustomAperture',pattern,'RotationDeg',27));
        check(validImage(b.Output) && abs(sum(b.PSFKernel(:))-1)<1e-12,'自定义光圈','旋转与能量归一化');
    end
    function testCli()
        folder=tempname; mkdir(folder); guard=onCleanup(@()cleanupDir(folder)); %#ok<NASGU>
        files=cell(1,4); kinds={'burst','sharpness','watermark','optics'};
        allGood=true;
        for k=1:4
            files{k}=fullfile(folder,[kinds{k} '.png']);
            r=FL_main('freqtools-run',kinds{k},'SaveTo',files{k});
            [image,meta]=fl_photo_load(files{k});
            allGood=allGood && validImage(image) && strcmp(r.SavedTo,files{k}) && meta.Width>0;
        end
        check(allGood,'四个 CLI 路径与照片导出','FL_main 分发、默认样例、PNG 像素');
        v=FL_freqtools('watermark',files{3},'Action','inspect');
        check(v.DetectCorr>.4,'保存后独立水印查验',sprintf('8 位 PNG 相关性 %.6f',v.DetectCorr));
        expectError(@()FL_freqtools('optics','SaveTo',files{4}),'fl_photo_save:exists','已有文件覆盖保护');
        expectError(@()FL_freqtools('optics',files{4},'SaveTo',files{4}),'fl_photo_save:original','输入照片覆盖保护');
        collection=fullfile(folder,'collection'); mkdir(collection);
        for k=1:4, copyfile(files{k},collection); end
        a=fl_ft_samples('normalize',collection,96);
        check(iscell(a) && numel(a)==4 && all(cellfun(@validImage,a)) && ...
            all(cellfun(@(q)max(size(q,1),size(q,2))<=96,a)),'文件夹输入','扫描四张 PNG 并限制处理尺寸');
        r=FL_freqtools('sharpness',files(3:4),struct('MaxEdge',80,'Names',{{'A','B'}}));
        check(height(r.Table)==2 && max(size(r.BestImage,1),size(r.BestImage,2))<=80, ...
            '文件列表与结构体选项','不同尺寸照片统一比较尺度');
        r=FL_freqtools('watermark',zeros(80,96),'RunAttackTest',false);
        check(validImage(r.Output) && ~isfield(r.Attack,'Noise'),'数值单图 CLI','灰度输入与关闭攻击验证');
    end
    function testGui()
        f=FL_freqtools_gui('Visible','off'); guard=onCleanup(@()cleanupFigure(f)); %#ok<NASGU>
        a=getappdata(f,'FreqToolsActions'); output=a.RunAll(); st=getappdata(f,'FreqToolsState');
        check(numel(output)==4 && all(~cellfun(@isempty,st.Results)) && ~st.Busy,'四工具隐藏 GUI','共享计算入口与状态');
        a.SelectRank(2); st=getappdata(f,'FreqToolsState');
        check(st.SelectedRank==2,'排名联动','选中帧与频谱同步');
        a.UseSample(1,'burst_night'); n=a.RunModule(1);
        check(n.Metrics.NoiseReduction>.55,'GUI 夜景样例','均值模式联动');
        a.SetOptions(4,struct('Effect','bokeh','Aperture','heart')); b=a.RunModule(4);
        check(strcmp(b.Options.Effect,'bokeh') && strcmp(b.Options.Aperture,'heart'),'GUI 散景参数','下拉形状与半径联动');
        x=fl_ft_samples('watermark_photo'); a.SetInput(3,x); v=a.Inspect();
        check(isequal(v.Output,x) && ~isfield(v,'PSNR'),'GUI 仅查验','外部输入独立频谱查验');
        % Exercise the actual button callbacks, which share the Actions path.
        button=findall(f,'Type','uibutton','Text','写入隐形水印');
        feval(button.ButtonPushedFcn,button,[]);
        st=getappdata(f,'FreqToolsState');
        check(~isempty(st.Results{3}) && isfield(st.Results{3},'PSNR'),'真实写入按钮回调','水印生成与状态发布');
        a.SetOptions(3,struct('Text','中文'));
        expectError(@()a.RunModule(3),'fl_ft_watermark:text','GUI 异常传播');
        st=getappdata(f,'FreqToolsState');
        check(~st.Busy && isempty(st.Results{3}),'GUI 失败清理','恢复可操作状态并清空过期结果');
        a.SetOptions(3,struct('Text','FILTERLAB')); a.RunModule(3);
        folder=tempname; mkdir(folder); tempGuard=onCleanup(@()cleanupDir(folder)); %#ok<NASGU>
        path=fullfile(folder,'gui-watermark.png'); a.Export(3,path);
        a.SetInput(3,path); v=a.Inspect();
        check(v.DetectCorr>.4 && isfile(path),'GUI 导出再查验',sprintf('相关性 %.6f',v.DetectCorr));
        expectError(@()a.Export(3,path),'fl_photo_save:original','GUI 导出源文件保护');
    end
    function testEmbedded()
        f=FL_photo('Visible','off'); guard=onCleanup(@()cleanupFigure(f)); %#ok<NASGU>
        check(~isappdata(f,'FreqToolsActions') && numel(findall(f,'Tag','FreqToolsPage'))==1, ...
            '第四工作区懒加载','初始页签存在，工坊尚未实例化');
        photo=getappdata(f,'PhotoActions'); panel=photo.OpenFreqTools(); second=photo.OpenFreqTools();
        a=getappdata(panel,'FreqToolsActions'); host=getappdata(f,'FreqToolsActions');
        check(isequal(panel,second) && strcmp(panel.Tag,'FreqToolsWorkspace') && ...
            isa(a.RunModule,'function_handle') && isequal(a.RunModule,host.RunModule), ...
            '嵌入面板复用与双接口','面板和宿主共享 Actions');
        a.RunModule(4); st=getappdata(panel,'FreqToolsState'); hs=getappdata(f,'FreqToolsState');
        check(~st.Busy && ~isempty(st.Results{4}) && isequal(st,hs),'嵌入状态同步','宿主与面板结果一致');
        % Queued timers run at the calculation's drawnow while Busy is true.
        observed=false; rejected=false; protected=false;
        t=timer('StartDelay',0,'ExecutionMode','fixedSpacing','Period',.01,'TimerFcn',@busyProbe);
        timerGuard=onCleanup(@()cleanupTimer(t));
        start(t); a.RunModule(4); drawnow; clear timerGuard;
        check(observed && rejected && protected && isgraphics(f), ...
            '忙碌重入与主窗关闭保护','运行中拒绝重入，主窗等待完成');
        a.SetModule(1); a.UseSample(1); a.RunModule();
        st=getappdata(panel,'FreqToolsState');
        check(~st.Busy && ~isempty(st.Results{1}) && isfield(photo,'OpenExtensions') && ...
            numel(findall(f,'Tag','AssignmentPage'))==1 && numel(findall(f,'Tag','ExtensionsPage'))==1, ...
            '主窗工作区入口','当前模块运行及既有入口兼容');
        close(f); check(~isgraphics(f),'主窗空闲关闭','计算完成后清理窗口');

        function busyProbe(~,~)
            st=getappdata(panel,'FreqToolsState');
            if observed || ~st.Busy, return; end
            observed=true; stop(t);
            try, a.RunModule(1); catch ex, rejected=strcmp(ex.identifier,'FL_freqtools_gui:busy'); end
            close(f); protected=isgraphics(f);
        end
    end
    function expectError(fn,id,name)
        caught=''; try, fn(); catch ex, caught=ex.identifier; end
        check(strcmp(caught,id),name,['异常 ' caught]);
    end
end

function tf=validImage(image)
tf=isnumeric(image) && isreal(image) && ndims(image)==3 && size(image,3)==3 && ...
    ~isempty(image) && all(isfinite(image(:))) && all(image(:)>=0 & image(:)<=1);
end
function cleanupFigure(f)
if isgraphics(f), delete(f); end
end
function cleanupDir(folder)
if isfolder(folder), rmdir(folder,'s'); end
end
function cleanupTimer(t)
if isvalid(t), stop(t); delete(t); end
end
