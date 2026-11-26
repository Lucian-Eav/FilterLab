function ok = fl_selftest(verbose)
%FL_SELFTEST  自检：用已知答案的算例验证核心算法没有被改坏。
%
%   OK = FL_SELFTEST() 依次运行若干检查，全部通过返回 true 并打印 PASS。
%   OK = FL_SELFTEST(false) 只返回结果，不打印过程。
%
%   检查项与判据：
%       1. Butterworth 系数  与解析法参考值（10 阶、Wc=0.4）逐项比对，
%                            相对误差 < 1e-6
%       2. 等纹波性          Parks-McClellan 解的通带纹波与阻带峰值之比应
%                            接近 1（允许 2% 偏差），否则说明交换迭代未收敛
%       3. 线性相位          偶对称 FIR 的系数对称误差应为 0，群延迟标准差应为 0
%       4. 直流归一化        设计输出的 H(1) 应为 1（误差 < 1e-12）
%       5. 平移估计          对已知平移的人工图像应恢复出同样的位移
%       6. 可分离一致性      先列后行与先行后列两种顺序的结果应一致
%
%   这些检查对应软件开发过程中真实踩过的坑，保留下来是为了防止回归。
%
%   见 also FL_DESIGN, FL_SHIFT, FL_FILTER2.

if nargin < 1, verbose = true; end

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'core'));

res = {};

% ---- 1. Butterworth 系数 ----
[b, a] = sl_butter(10, 0.4);
bRef = [0.00049945 0.0049945 0.022475 0.059934 0.10489 0.12586];
aRef = [1 -1.9924 3.0195 -2.8185 2.0387 -1.0545 0.41445 -0.11572 0.022499 -0.0026689 0.00014876];
eb = max(abs(b(1:6) - bRef) ./ max(abs(bRef), eps));
ea = max(abs(a - aRef) ./ max(abs(aRef), eps));
res{end+1} = struct('Name', 'Butterworth 系数', 'Pass', eb < 1e-4 && ea < 1e-4, ...
    'Detail', sprintf('b 相对误差 %.2e，a 相对误差 %.2e', eb, ea)); %#ok<AGROW>

% ---- 2. 等纹波性 ----
band = [0 0.36 0.44 1];
amp  = [1 1 0 0];
bf = sl_remez(12, band, amp);
w = linspace(0, pi, 8192);
H = abs(sl_freqz(bf, 1, w));
idxP = w/pi <= 0.36;
idxS = w/pi >= 0.44;
rp = max(abs(1 - H(idxP)));
rs = max(H(idxS));
ratio = rp / rs;
res{end+1} = struct('Name', '等纹波性', 'Pass', abs(ratio - 1) < 0.02, ...
    'Detail', sprintf('通带纹波 %.4f，阻带峰值 %.4f，比值 %.4f', rp, rs, ratio)); %#ok<AGROW>

% ---- 3. 线性相位 ----
g = sl_grpdelay(bf, 1, linspace(0, pi*0.35, 512));
sym = max(abs(bf - fliplr(bf)));
res{end+1} = struct('Name', '线性相位', 'Pass', sym < 1e-12 && std(g) < 1e-9, ...
    'Detail', sprintf('对称误差 %.1e，群延迟 %.3f±%.1e', sym, mean(g), std(g))); %#ok<AGROW>

% ---- 4. 直流归一化 ----
S = fl_spec();
F = fl_design(S);
okDC = true;
dcs = zeros(1, numel(F));
for k = 1:numel(F)
    dcs(k) = real(sl_freqz(F(k).B, F(k).A, 0));
    if abs(dcs(k) - 1) > 1e-10, okDC = false; end
end
res{end+1} = struct('Name', '直流归一化', 'Pass', okDC, ...
    'Detail', sprintf('三个滤波器的 H(1) = %.12f / %.12f / %.12f', dcs(1), dcs(2), dcs(3))); %#ok<AGROW>

% ---- 5. 平移估计 ----
X0 = zeros(24, 24);
X0(3:5, 10:20) = 1;
X0(10:20, 3:5) = 1;
Xs = circshift(X0, [2 -3]);
[dr, dc] = fl_shift(Xs, X0);
res{end+1} = struct('Name', '平移估计', 'Pass', dr == 2 && dc == -3, ...
    'Detail', sprintf('真值 (2,-3)，估计 (%d,%d)', dr, dc)); %#ok<AGROW>

% ---- 6. 可分离一致性 ----
B = fl_design(fl_spec());
Y1 = fl_filter2(X0, B(1).B, B(1).A, 'Orient', 'rc');
Y2 = fl_filter2(X0, B(1).B, B(1).A, 'Orient', 'cr');
dsep = max(abs(Y1(:) - Y2(:)));
res{end+1} = struct('Name', '可分离一致性', 'Pass', dsep < 1e-10, ...
    'Detail', sprintf('两种顺序最大差异 %.2e', dsep)); %#ok<AGROW>

ok = true;
for k = 1:numel(res)
    ok = ok && res{k}.Pass;
end
if verbose
    fprintf('\n=========== 自检结果 ===========\n');
    for k = 1:numel(res)
        if res{k}.Pass
            fprintf(' [PASS] %-18s %s\n', res{k}.Name, res{k}.Detail);
        else
            fprintf(' [FAIL] %-18s %s\n', res{k}.Name, res{k}.Detail);
        end
    end
    if ok
        fprintf(' 全部通过。\n');
    else
        fprintf(' 存在失败项，请先排查再使用分析结果。\n');
    end
    fprintf('================================\n');
end
end
