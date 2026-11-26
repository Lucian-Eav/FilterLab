function ok = fl_ext_selftest(verbose)
%FL_EXT_SELFTEST Validate the four extensions and their public entry points.
%   OK = FL_EXT_SELFTEST() prints each result. FL_EXT_SELFTEST(false) is quiet.
if nargin < 1, verbose = true; end
root = fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'core'));
passed = 0; failed = 0;
runGroup('原有核心自检',@testCore);
runGroup('模块一',@testMoire);
runGroup('模块二',@testDocument);
runGroup('模块三',@testMotion);
runGroup('模块四',@testAllpass);
runGroup('端到端导出',@testExport);
runGroup('无头 GUI',@testGui);
ok = failed == 0;
if verbose, fprintf('\n扩展自检：%d 项通过，%d 项失败。\n',passed,failed); end

    function runGroup(name,fn)
        try
            fn();
        catch ex
            check(false,[name '运行'],sprintf('%s: %s',ex.identifier,ex.message));
        end
    end

    function check(condition,name,detail)
        if condition, passed=passed+1; status='PASS';
        else, failed=failed+1; status='FAIL'; end
        if verbose, fprintf(' [%s] %s  %s\n',status,name,detail); end
    end

    function testCore()
        check(fl_selftest(false),'原有核心自检','包含标量频率直流响应');
        h=sl_freqz([1 2],[1 -.5],0);
        check(isscalar(h) && abs(h-6)<1e-12,'标量频率响应',sprintf('H(0)=%.12g',h));
    end

    function testMoire()
        [mountain,~]=fl_ext_samples('mountain','synthetic');
        [screen,meta]=fl_ext_samples('screen_moire','synthetic');
        m=fl_ext_moire(mountain,screen,meta,struct());
        s=m.Sampling; ref=s.Reference;
        pd=fl_ext_metrics('psnr',ref,s.Direct); pz=fl_ext_metrics('psnr',ref,s.ZeroPhase);
        sd=fl_ext_metrics('ssim',ref,s.Direct); sz=fl_ext_metrics('ssim',ref,s.ZeroPhase);
        check(pz>pd && sz>sd,'四倍抗混叠',sprintf('PSNR %.3f → %.3f dB，SSIM %.5f → %.5f',pd,pz,sd,sz));
        c=m.Phase.CausalShift.Max; z=m.Phase.ZeroPhaseShift.Max;
        check(z<.1 && z<c,'全分辨率 RGB 错位',sprintf('因果 %.4f px，零相位 %.4f px',c,z));
        q=m.Moire;
        check(abs(q.DetectedFrequency-.24)<.02 && abs(q.DetectedAngle-28)<3 && q.AttenuationDB>15, ...
            '定向摩尔纹检测与衰减',sprintf('频率 %.5f，角度 %.3f°，衰减 %.3f dB',q.DetectedFrequency,q.DetectedAngle,q.AttenuationDB));
        pb=fl_ext_metrics('psnr',meta.Clean,q.Input); pa=fl_ext_metrics('psnr',meta.Clean,q.Output);
        sb=fl_ext_metrics('ssim',meta.Clean,q.Input); sa=fl_ext_metrics('ssim',meta.Clean,q.Output);
        check(pa>pb && sa>sb,'去摩尔纹质量',sprintf('PSNR %.3f → %.3f dB，SSIM %.5f → %.5f',pb,pa,sb,sa));
    end

    function testDocument()
        [img,meta]=fl_ext_samples('notebook','synthetic');
        m=fl_ext_document(img,meta,struct());
        check(abs(m.DetectedPeriod-12)<.5,'横线周期',sprintf('%.4f px',m.DetectedPeriod));
        check(m.LineAttenuationDB(1)>15,'基频衰减',sprintf('%.3f dB',m.LineAttenuationDB(1)));
        c=m.Profile.CausalSymmetry.Score; z=m.Profile.ZeroPhaseSymmetry.Score;
        check(z>c,'笔画对称度',sprintf('因果 IIR %.5f，零相位 %.5f',c,z));
        pb=fl_ext_metrics('psnr',meta.Clean,img); pa=fl_ext_metrics('psnr',meta.Clean,m.Normalized);
        check(m.BackgroundAfter.Reduction>50 && m.BackgroundAfter.Improvement>.9 && pa>pb+1, ...
            '背景与文字',sprintf('背景标准差下降 %.2f%%，对比度 %.4f 倍，PSNR %.3f → %.3f dB', ...
            m.BackgroundAfter.Reduction,m.BackgroundAfter.Improvement,pb,pa));
    end

    function testMotion()
        [img,~]=fl_ext_samples('mountain','synthetic'); m=fl_ext_motion(img,struct());
        d=[max(abs(m.Blurred{1}(:)-m.Blurred{2}(:))), ...
            max(abs(m.Blurred{1}(:)-m.Blurred{3}(:))),max(abs(m.Blurred{2}(:)-m.Blurred{3}(:)))];
        check(all(d>1e-10),'三种运动方向',sprintf('两两最大差 %s',mat2str(d,4)));
        o=m.Sweep.OvershootPercent; s=m.Sweep.Sharpness; r=m.Sweep.Ringing;
        check(all(diff(o)>0) && o(1)<5 && o(end)>40,'阶跃超调',sprintf('%s %%',mat2str(o.',4)));
        check(s(end)>s(1) && r(end)>r(1) && all(diff(r)>0), ...
            '清晰度与边缘振铃',sprintf('梯度 %s，振铃 %s',mat2str(s.',5),mat2str(r.',5)));
    end

    function testAllpass()
        [img,~]=fl_ext_samples('naishu','synthetic');
        m=fl_ext_allpass(img,struct('DeltaRadius',.01));
        check(m.MagnitudeError<1e-11 && m.EnergyError<1e-10 && m.RelativePowerError<1e-10, ...
            '全通幅度与能量',sprintf('幅度 %.3g，能量 %.3g，功率 %.3g',m.MagnitudeError,m.EnergyError,m.RelativePowerError));
        check(m.EncryptedSSIM<.25,'密文置乱',sprintf('SSIM %.6f',m.EncryptedSSIM));
        check(m.DecryptedPSNR>200 && m.DecryptedSSIM>.999999 && m.MaxError<1e-10, ...
            '正确密钥解密',sprintf('PSNR %.3f dB，SSIM %.9f，最大误差 %.3g',m.DecryptedPSNR,m.DecryptedSSIM,m.MaxError));
        check(m.WrongKeyPSNR<25 && m.WrongKeyPSNR<m.DecryptedPSNR-20, ...
            '半径扰动密钥',sprintf('Δr=0.01，PSNR %.3f dB',m.WrongKeyPSNR));
    end

    function testExport()
        tmpDir=tempname; guard=onCleanup(@()cleanupDir(tmpDir)); %#ok<NASGU>
        FL_extensions('Modules',1:4,'Export',true,'Visible','off','OutputDir',tmpDir);
        files={'report.html','summary.md','metrics.csv','results.mat','reproduce_extensions.m', ...
            '01-moire-antialiasing.png','01-moire-notch.png','02-document-lines.png', ...
            '02-document-illumination.png','03-motion-blur.png','03-motion-deblur.png', ...
            '04-allpass-response.png','04-allpass-crypto.png'};
        missing={};
        for i=1:numel(files)
            info=dir(fullfile(tmpDir,files{i}));
            if isempty(info) || info(1).isdir || info(1).bytes==0, missing{end+1}=files{i}; end %#ok<AGROW>
        end
        if isempty(missing), detail=sprintf('%d 个文件均非空',numel(files));
        else, detail=['缺失或为空：' strjoin(missing,', ')]; end
        check(isempty(missing),'导出文件',detail);
    end

    function testGui()
        f=FL_extensions_gui('Visible','off'); guard=onCleanup(@()cleanupFigure(f)); %#ok<NASGU>
        a=getappdata(f,'ExtensionsActions');
        a.SetImage('NaishuImage','synthetic');
        result=a.RunModule(4); st=getappdata(f,'ExtensionsState');
        check(isstruct(result) && ~isempty(result.Results{4}) && ~isempty(st.Results{4}) && ~st.Busy, ...
            '独立扩展界面','模块四运行及状态');
        p=FL_photo('Visible','off'); photoGuard=onCleanup(@()cleanupFigure(p)); %#ok<NASGU>
        photo=getappdata(p,'PhotoActions'); panel=photo.OpenExtensions();
        pa=getappdata(panel,'ExtensionsActions'); ps=getappdata(panel,'ExtensionsState');
        check(isvalid(panel) && strcmp(panel.Tag,'ExtensionsWorkspace') && isstruct(pa) && ...
            isa(pa.RunModule,'function_handle') && isstruct(ps) && isfield(ps,'Results') && ...
            isappdata(p,'ExtensionsActions') && isappdata(p,'ExtensionsState'), ...
            '主界面嵌入扩展','面板、操作与状态');
    end
end

function cleanupDir(path)
if isfolder(path), rmdir(path,'s'); end
end

function cleanupFigure(fig)
if isgraphics(fig), delete(fig); end
end
