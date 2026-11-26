function F = fl_design(S)
%FL_DESIGN  按 S.Filters 逐个设计滤波器，并给出相位与频带信息。
%
%   F = FL_DESIGN(S) 返回 1×N 结构体数组，N = numel(S.Filters)，字段：
%       Name     显示名
%       Kind     'butter' | 'remez' | 'coeff' | 'identity'
%       Type     'FIR' 或 'IIR'
%       Order    阶数
%       B, A     归一化后的系数（H(1) = 1）
%       Braw, Araw  归一化之前的原始设计结果
%       DCGain   原始直流增益 sum(Braw)/sum(Araw)
%       Len      系数长度
%       Linear   是否线性相位（只有 FIR 可能为真）
%       GDMean   通带平均群延迟（样本）
%       GDStd    通带群延迟标准差；线性相位时为 0
%       Band     该滤波器对应的 [0,通带边,阻带边,1]，供绘图用
%       Source   来源说明
%
%   三类都会统一归一化到直流增益 1，这样不同设计的振荡幅度可以直接比较；
%   原始增益另存 DCGain，报告里会说明"差异来自设计本身而非归一化"。
%
%   见 also FL_SPEC, SL_BUTTER, SL_REMEZ, SL_GRPDELAY.

specs = S.Filters;
nF = numel(specs);

F = struct('Name', {}, 'Kind', {}, 'Type', {}, 'Order', {}, ...
           'B', {}, 'A', {}, 'Braw', {}, 'Araw', {}, ...
           'DCGain', {}, 'Len', {}, 'Linear', {}, ...
           'GDMean', {}, 'GDStd', {}, 'PassMin', {}, 'PassMax', {}, ...
           'Band', {}, 'Source', {});

for k = 1:nF
    sp = specs(k);
    wc = sp.Wc;
    if isnan(wc), wc = S.Wc; end
    tw = sp.TransWidth;
    if isnan(tw), tw = S.TransWidth; end
    ord = sp.Order;
    if (isnan(ord) || isempty(ord)) && ~isempty(sp.OrderSrc)
        ord = S.(sp.OrderSrc);
    end

    % 设计（只在需要的分支里算过渡带）
    switch sp.Kind
        case 'butter'
            if ord > 20
                warning('fl_design:highOrder', ...
                    '%s 的阶数 %d 偏高，双线性变换在高阶时数值条件变差。', sp.Name, ord);
            end
            [b, a] = sl_butter(ord, wc);

        case 'remez'
            fp = wc - tw/2;
            fs = wc + tw/2;
            b = sl_remez(ord, [0 fp fs 1], [1 1 0 0]);
            a = 1;

        case 'coeff'
            b = double(sp.B(:).');
            a = double(sp.A(:).');
            a = a / a(1);

        case 'identity'
            b = 1;
            a = 1;

        otherwise
            error('fl_design:kind', '未知滤波器类型：%s', sp.Kind);
    end

    if all(b == 0)
        error('fl_design:zeroB', '%s 的分子系数全为 0。', sp.Name);
    end

    % ---- 原始直流增益与归一化 ----
    dc = sum(b) / sum(a);
    if abs(dc) < 1e-12
        error('fl_design:zeroDC', ...
            '%s 的直流增益为 0（在 ω=0 处被完全抑制），无法归一化到 H(1)=1。', sp.Name);
    end
    braw = b; araw = a;
    % 只缩放分子，使 H(1) = sum(b)/sum(a) = 1；分母保持原样便于比较极点
    b = braw / dc;

    % ---- 通带平坦度：这个滤波器到底"平不平" ----
    % 只看 H(1)=1 是不够的：等纹波设计的直流点可能正好落在纹波极值上，
    % 归一化之后通带整段塌下去（b2 最低 0.456）或者鼓起来（b3 最高 1.375）。
    % 照片上这两件事分别表现为"整体发灰"和"边缘光晕"。
    wpb = linspace(0, pi*max(wc - tw/2, 0.02), 256).';
    Hb  = exp(-1i*wpb*(0:numel(b)-1)) * b(:);
    Ha  = exp(-1i*wpb*(0:numel(a)-1)) * a(:);
    gpb = abs(Hb ./ Ha);
    a = araw;

    % ---- 阶数与类型 ----
    if isnan(ord) || isempty(ord)
        ord = max(numel(b), numel(a)) - 1;
    end
    if numel(a) > 1
        typ = 'IIR';
    else
        typ = 'FIR';
    end

    % ---- 线性相位判定 ----
    % 只看分子是否偶对称是不够的：偶数阶 Butterworth 的分子天生回文，
    % 但它的相位由极点决定，仍然是非线性的。所以 IIR 一律判为非线性。
    if strcmp(typ, 'IIR')
        isLin = false;
    else
        L = numel(b);
        isLin = all(abs(b - fliplr(b)) < 1e-10);
        if isLin && mod(L, 2) == 0
            isLin = true;     % 偶数长度：对称中心在半个样本处
        end
    end

    % ---- 群延迟：只在通带内统计 ----
    wp = min(S.PassW / S.Wc, 0.9) * wc;      % 相对自己的通带，不写死全局 PassW
    w = linspace(0, pi * wp, 512);
    gd = sl_grpdelay(b, a, w);
    if isLin
        gdStd = 0;
        gdMean = (numel(b) - 1) / 2;
    else
        gdMean = mean(gd);
        gdStd = std(gd);
        if gdStd < 1e-9
            isLin = true;
        end
    end

    % ---- 频带：设计类给真实的过渡带，直接给系数的两条边重合 ----
    switch sp.Kind
        case {'butter', 'remez'}
            band = [0, wc - tw/2, wc + tw/2, 1];
        otherwise
            band = [0, wc, wc, 1];
    end

    F(k) = struct('Name', sp.Name, 'Kind', sp.Kind, 'Type', typ, ...
                  'Order', ord, 'B', b, 'A', a, ...
                  'Braw', braw, 'Araw', araw, 'DCGain', dc, ...
                  'Len', numel(b), 'Linear', isLin, ...
                  'GDMean', gdMean, 'GDStd', gdStd, ...
                  'PassMin', min(gpb), 'PassMax', max(gpb), ...
                  'Band', band, 'Source', sp.Source);
    % 用两个标量而不是一个 1×2 向量：struct(...) 里的向量会被当成
    % 结构体数组的第二行，导致后续 F(k) 赋值报"在不同结构体之间进行下标赋值"。
end
end
