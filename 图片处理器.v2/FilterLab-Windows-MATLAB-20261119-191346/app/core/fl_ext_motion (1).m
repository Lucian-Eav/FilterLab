function M = fl_ext_motion(img, opts)
%FL_EXT_MOTION 任意方向的一维运动模糊与 FIR 锐化参数扫描。
% Angle 按图像坐标定义，由水平向右顺时针旋转，单位为度。
if nargin < 2, opts = struct; end
if ~isfield(opts,'Angle'), opts.Angle = 30; end
validateattributes(opts.Angle,{'numeric'},{'scalar','real','finite'});
img = double(img);
angles = [0 30 60];
blurB = [1 2 3 4 3 2 1]/16;
blurred = cell(1,3);
for k = 1:3
    blurred{k} = fl_ext_direction(img,angles(k),24,@(x) symmetric_fir(x,blurB));
end
at = find(abs(angles-opts.Angle)<1e-12,1);
if isempty(at)
    input = fl_ext_direction(img,opts.Angle,24,@(x) symmetric_fir(x,blurB));
else
    input = blurred{at};
end
orders = [16 24 32 40 48];
fp = [.12 .18 .2144 .26 .29];
fs = [.55 .48 .4256 .35 .32];
targets = [2 10 23 40 65];
restored = cell(1,5); filters = cell(1,5); steps = zeros(320,5);
overshoot = zeros(5,1); sharpness = overshoot; ringing = overshoot;
psnrValue = overshoot; ssimValue = overshoot; gain = overshoot;
g = mean(img,3);
edge = abs(conv2(g,[-1 0 1]/2,'same')) + abs(conv2(g,[-1;0;1]/2,'same'));
edge([1 end],:) = 0; edge(:,[1 end]) = 0;
edgeMask = edge > max(.04,.25*max(edge(:)));
gdens = conv2(double(edge > 0.04),ones(15)/225,'same');
cleanEdgeMask = edge > max(0.06,0.30*max(edge(:))) & gdens < 0.35;
if nnz(cleanEdgeMask) < 20, cleanEdgeMask = edgeMask; end
% Local 5x5 extrema of the original grayscale image for Gibbs excess.
lmin = g; lmax = g;
for dr = -2:2
    for dc = -2:2
        rs = max(1,1+dr):min(size(g,1),size(g,1)+dr);
        cs = max(1,1+dc):min(size(g,2),size(g,2)+dc);
        shifted = g(rs-dr,cs-dc);
        lmin(rs,cs) = min(lmin(rs,cs),shifted);
        lmax(rs,cs) = max(lmax(rs,cs),shifted);
    end
end
band = conv2(double(cleanEdgeMask),ones(9),'same') > 0;
for k = 1:5
    b = sl_remez(orders(k),[0 fp(k) fs(k) 1],[1 1 2 2],[1 1]);
    b = b/sum(b);
    unit = zeros(size(b)); unit(orders(k)/2+1) = 1;
    s = filter(b,1,ones(320,1));
    baseOvershoot = max(s)-1;
    if baseOvershoot <= 1e-6
        error('fl_ext_motion:design','高频增强滤波器未产生可测阶跃超调。');
    end
    % 沿同一等纹波形状缩放增强量，使五组实验的超调量可重复比较。
    alpha = (targets(k)/100)/baseOvershoot;
    b = unit + alpha*(b-unit);
    b = b/sum(b);
    filters{k} = b;
    step = fl_ext_metrics('step_overshoot',b,1);
    overshoot(k) = step.Percent; steps(:,k) = step.Response;
    h = sl_freqz(b,1,[0;pi]); gain(k) = abs(h(end));
    restored{k} = fl_ext_direction(input,opts.Angle,orders(k)+16,@(x) symmetric_fir(x,b));
    q = fl_ext_metrics('gradient_sharpness',restored{k}); sharpness(k) = q.RMS;
    yk_gray = mean(restored{k},3);
    excess = max(0,yk_gray-lmax) + max(0,lmin-yk_gray);
    if any(band(:)), ringing(k) = sqrt(mean(excess(band).^2)); end
    psnrValue(k) = fl_ext_metrics('psnr',img,restored{k});
    ssimValue(k) = fl_ext_metrics('ssim',img,restored{k});
end
M = struct('Title','模块三 · 动态追焦与方向性去模糊','Options',opts, ...
    'Original',img,'Angles',angles,'BlurFilter',blurB,'Blurred',{blurred}, ...
    'BlurInput',input,'Restored',{restored},'Filters',{filters},'StepResponses',steps, ...
    'EdgeMask',edgeMask);
M.Sweep = table(orders(:),fp(:),fs(:),gain,overshoot,sharpness,ringing,psnrValue,ssimValue, ...
    'VariableNames',{'Order','PassEdge','StopEdge','Gain','OvershootPercent','Sharpness','Ringing','PSNR','SSIM'});
M.Metrics = table({'最缓阶跃超调';'最陡阶跃超调';'最缓梯度 RMS';'最陡梯度 RMS';'最缓边缘振铃 RMS';'最陡边缘振铃 RMS'}, ...
    [overshoot(1);overshoot(end);sharpness(1);sharpness(end);ringing(1);ringing(end)], ...
    {'%';'%';'灰度/像素';'灰度/像素';'灰度';'灰度'},'VariableNames',{'Metric','Value','Unit'});
for k = 1:5
    prefix = sprintf('增强组 %d ',k);
    names = {'FIR 阶数';'通带边缘';'高频带边缘';'高频增益';'阶跃超调';'梯度 RMS';'边缘振铃 RMS';'PSNR';'SSIM'};
    values = [orders(k);fp(k);fs(k);gain(k);overshoot(k);sharpness(k);ringing(k);psnrValue(k);ssimValue(k)];
    units = {'阶';'倍奈奎斯特频率';'倍奈奎斯特频率';'倍';'%';'灰度/像素';'灰度';'dB';'1'};
    names = cellfun(@(s)[prefix s],names,'UniformOutput',false);
    M.Metrics = [M.Metrics;table(names,values,units,'VariableNames',{'Metric','Value','Unit'})]; %#ok<AGROW>
end
panels = {panel('image','清晰原图',img,[],{}), panel('image','0° 方向运动模糊',blurred{1},[],{}), ...
    panel('image','30° 方向运动模糊',blurred{2},[],{}),panel('image','60° 方向运动模糊',blurred{3},[],{})};
M.Views(1) = struct('Title','任意角度的一维运动模糊','Panels',{panels});
% 由原图最强边缘自动选择放大区域，避免固定裁剪错过真实照片的边缘。
cropEdge = edge .* double(cleanEdgeMask);
my = min(24,floor((size(img,1)-1)/2)); mx = min(36,floor((size(img,2)-1)/2));
cropEdge(1:my,:) = 0; cropEdge(end-my+1:end,:) = 0;
cropEdge(:,1:mx) = 0; cropEdge(:,end-mx+1:end) = 0;
[peak,idx] = max(cropEdge(:)); [r,c] = ind2sub(size(edge),idx);
if peak==0, r=ceil(size(img,1)/2); c=ceil(size(img,2)/2); end
rr = max(1,r-24):min(size(img,1),r+24); cc = max(1,c-36):min(size(img,2),c+36);
M.EdgeCrop = struct('Rows',rr,'Cols',cc,'Images',{{img(rr,cc,:),restored{1}(rr,cc,:),restored{5}(rr,cc,:)}});
panels = {panel('image','轻度增强',restored{1},[],{}),panel('image','强增强及振铃',restored{5},[],{}), ...
    panel('line','五组因果阶跃响应',steps,(0:319)',{'2%','10%','23%','40%','65%'}), ...
    panel('image','原始边缘放大',img(rr,cc,:),[],{}), ...
    panel('image','轻增强边缘放大',restored{1}(rr,cc,:),[],{}), ...
    panel('image','强增强边缘放大',restored{5}(rr,cc,:),[],{}), ...
    panel('line','超调量-清晰度-振铃权衡曲线',[sharpness/max(max(sharpness),eps),ringing/max(max(ringing),eps)],overshoot,{'归一化梯度清晰度','归一化边缘振铃'})};
panels{7}.XLabel = '阶跃超调量 / %'; panels{7}.YLabel = '相对指标（峰值=1）';
M.Views(2) = struct('Title','过渡带、清晰度与吉布斯振铃','Panels',{panels});
M.Conclusion = ['反射延拓后逐通道旋转，在运动轴上施加一维滤波，正交方向全通。' ...
    '增强 FIR 为偶阶分段常数等纹波设计，按阶跃超调量标定增强幅度。' ...
    sprintf('五组实测阶跃超调为 %.1f%% 至 %.1f%%，梯度 RMS 从 %.4f 变为 %.4f，边缘振铃 RMS 从 %.4f 变为 %.4f。', ...
    overshoot(1),overshoot(end),sharpness(1),sharpness(end),ringing(1),ringing(end)), ...
    '图像保留浮点超范围值用于测量，显示时裁到 [0,1]。双线性旋转本身引入少量插值平滑。'];
end

function y = symmetric_fir(x,b)
p = (numel(b)-1)/2;
n = size(x,2);
idx = reflect_index((1-p):(n+p),n);
y = conv2(x(:,idx),b,'valid');
end

function idx = reflect_index(idx,n)
if n == 1, idx(:) = 1; return; end
idx = mod(idx-1,2*n-2)+1;
idx(idx>n) = 2*n-idx(idx>n);
end

function p = panel(kind,title,data,x,labels)
p = struct('Kind',kind,'Title',title,'Data',data,'X',x,'Labels',{labels},'XLabel','','YLabel','');
if strcmp(kind,'line'), p.XLabel = '样本序号'; p.YLabel = '归一化阶跃幅度'; end
end
