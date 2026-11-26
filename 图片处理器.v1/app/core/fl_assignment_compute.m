function R=fl_assignment_compute(dataFile)
%FL_ASSIGNMENT_COMPUTE Six questions with original coefficients and causal filter.
if nargin<1||isempty(dataFile)
    paths=fl_app_paths(); dataFile=paths.Sample;
end
D=load(dataFile,'x','xn');
if ~isfield(D,'x')||~isfield(D,'xn'), error('fl_assignment_compute:data','MAT 文件必须同时包含 x 和 xn。'); end
validateattributes(D.x,{'numeric'},{'real','finite','2d','nonempty'});
validateattributes(D.xn,{'numeric'},{'real','finite','size',size(D.x)});
x=double(D.x); xn=double(D.xn);
if min(size(x))<16, error('fl_assignment_compute:size','实验图像至少为 16×16。'); end
F=fl_assignment_design(); w=linspace(0,pi,4097)';
for k=1:3
    b=F(k).B; a=F(k).A;
    H=(exp(-1i*w*(0:numel(b)-1))*b(:))./(exp(-1i*w*(0:numel(a)-1))*a(:));
    F(k).Frequency=w/pi; F(k).Response=H; F(k).Phase=unwrap(angle(H));
    F(k).GroupDelay=-gradient(F(k).Phase,w); pass=w/pi<=.36;
    F(k).GDMean=mean(F(k).GroupDelay(pass)); F(k).GDStd=std(F(k).GroupDelay(pass));
    F(k).DCGain=sum(b)/sum(a); F(k).Step=filter(b,a,ones(320,1));
    [F(k).StepPeak,peak]=max(F(k).Step); F(k).StepPeakIndex=peak-1;
    F(k).Overshoot=max(0,F(k).StepPeak-F(k).DCGain);
    F(k).RelativeOvershoot=F(k).Overshoot/abs(F(k).DCGain);
    % MATLAB filter default IC=0, row direction dim2 then column direction dim1.
    F(k).RowClean=filter(b,a,x,[],2); F(k).Clean=filter(b,a,F(k).RowClean,[],1);
    F(k).RowNoisy=filter(b,a,xn,[],2); F(k).Noisy=filter(b,a,F(k).RowNoisy,[],1);
    F(k).RawMSE=mean((F(k).Noisy(:)-x(:)).^2);
    residual=F(k).Noisy-F(k).Clean; F(k).NoiseResidualMSE=mean(residual(:).^2);
    normalized=F(k).Clean/F(k).DCGain^2;
    F(k).RangeExcursion=max([0 max(normalized(:))-max(x(:)) min(x(:))-min(normalized(:))]);
end
% Estimate IIR integer translation from CLEAN data only, never fit noisy output.
% Same fixed ROI for every candidate; FIR delays are exactly order/2 per axis.
maxSearch=min(8,floor(min(size(x))/4)); rows=1:size(x,1)-maxSearch; cols=1:size(x,2)-maxSearch;
reference=x(rows,cols); best=Inf; shift=[0 0];
for dy=0:maxSearch
    for dx=0:maxSearch
        z=F(1).Clean(rows+dy,cols+dx)/F(1).DCGain^2;
        mse=mean((z(:)-reference(:)).^2);
        if mse<best, best=mse; shift=[dy dx]; end
    end
end
F(1).Shift=shift; F(2).Shift=[2 2]; F(3).Shift=[6 6];
shifts=vertcat(F.Shift); roiRows=1:size(x,1)-max(shifts(:,1)); roiCols=1:size(x,2)-max(shifts(:,2));
reference=x(roiRows,roiCols);
inputRoi=xn(roiRows,roiCols); inputMSE=mean((inputRoi(:)-reference(:)).^2);
for k=1:3
    sh=F(k).Shift; clean=F(k).Clean(roiRows+sh(1),roiCols+sh(2));
    noisy=F(k).Noisy(roiRows+sh(1),roiCols+sh(2));
    F(k).AlignedMSE=mean((noisy(:)-reference(:)).^2);
    F(k).GainCorrectedMSE=mean((noisy(:)/F(k).DCGain^2-reference(:)).^2);
    F(k).ShapeMSE=mean((clean(:)/F(k).DCGain^2-reference(:)).^2);
    F(k).PSNR=10*log10(1/max(F(k).AlignedMSE,eps));
    aligned=nan(size(x)); aligned(1:end-sh(1),1:end-sh(2))=F(k).Clean(1+sh(1):end,1+sh(2):end)/F(k).DCGain^2;
    F(k).SymmetryError=symmetry(aligned); F(k).AlignedClean=aligned;
end
[~,stepWinner]=max([F.Overshoot]); [~,ringWinner]=max([F.RangeExcursion]);
[~,rawWinner]=min([F.RawMSE]); [~,alignedWinner]=min([F.AlignedMSE]); [~,gainWinner]=min([F.GainCorrectedMSE]);
answers=cell(1,6);
answers{1}=sprintf(['Wc=0.4；Butterworth 10 阶；等纹波 FIR 4/12 阶，频带 [0 0.36 0.44 1]、目标 [1 1 0 0]。' ...
    '使用原始系数，未另做直流归一化。三个 DC 增益分别为 %.6f、%.6f、%.6f；二维级联的 DC 增益是其平方。系数与来源列于报告。'],F.DCGain);
answers{2}=sprintf(['4 阶与 12 阶 FIR 系数关于中点对称，具有线性相位；群延迟分别为 2 和 6 个样本。' ...
    'Butterworth 相位非线性，在 0～0.36π 通带的群延迟均值 %.3f、标准差 %.3f。相位在幅度接近零处没有可靠解释。'],F(1).GDMean,F(1).GDStd);
answers{3}=sprintf('以 max(step)−H(1) 定义绝对超调，最大的是 %s（%.6f）。稳态取 sum(b)/sum(a)，而非假设为 1；相对超调也另列。',F(stepWinner).Name,F(stepWinner).Overshoot);
answers{4}=sprintf(['按 filter(b,a,x,[],2) 后 filter(b,a,行结果,[],1) 逐行、逐列处理，零初始状态。' ...
    '按去除 DC 增益后的输出超出原灰度范围的最大幅度衡量，%s 的边缘越界最大（%.6f）；' ...
    '同时查看中心行剖面判断实际振铃，不能只按二维图的亮暗排序。显示范围固定 0～1，但原始结果保留全部过冲数值。'],F(ringWinner).Name,F(ringWinner).RangeExcursion);
answers{5}=sprintf(['Butterworth 是三者中唯一的非线性相位设计，不同频率延迟不同，会引入不能由整体平移消除的轮廓失真。' ...
    'FIR 的固定延迟本身不等于形状失真，但幅频响应仍会改变细节。' ...
    '为区分因素，额外在同一有效区域比较补偿位移并除以 DC 增益平方后的干净图像误差：%.6g / %.6g / %.6g。' ...
    '对称误差也在有效镜像像素对上计算；有限图像的零初态和截断会影响对称性。'],F.ShapeMSE);
answers{6}=sprintf(['使用数据文件中的 xn，不重新加噪也不裁切。原坐标全图 MSE 最小：%s；' ...
    '补偿整数延迟、同一有效区域且保留原系数增益时，MSE 最小：%s；' ...
    '再额外校正 DC 增益后最小：%s（该项仅作诊断，不是题目原始输出）。' ...
    '共同区域的输入噪声 MSE=%.6g。行列移动来自因果滤波的延迟；FIR 分别每轴 2、6 像素，' ...
    'IIR 只有近似整体位移（本图估计 [%d,%d]），无法补偿全部频率的延迟。' ...
    '这是一幅指定噪声样本上的结果，不代表自然照片的通用排名。'], ...
    F(rawWinner).Name,F(alignedWinner).Name,F(gainWinner).Name,inputMSE,F(1).Shift);
R=struct('DataFile',char(dataFile),'X',x,'Xn',xn,'Filters',F,'Answers',{answers}, ...
    'Parameters',struct('Wc',.4,'Orders',[10 4 12],'Bands',[0 .36 .44 1]), ...
    'CommonRows',roiRows,'CommonCols',roiCols,'InputMSE',mean((xn(:)-x(:)).^2), ...
    'InputRoiMSE',inputMSE,'OriginalSymmetry',symmetry(x),'OutputDir','','Figures',{{}}, ...
    'Protocol','raw coefficients; dim2 then dim1; zero IC; no padding; no clipping; no circular shift');
end
function value=symmetry(x)
a=abs(x-fliplr(x)); b=abs(x-flipud(x)); v=[a(isfinite(a));b(isfinite(b))];
if isempty(v), value=NaN; else, value=mean(v); end
end
