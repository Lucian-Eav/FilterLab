function [X, meta] = fl_load_image(src, varargin)
%FL_LOAD_IMAGE  读取图像或 MAT 文件中的二维数组，统一转成 double。
%
%   [X,META] = FL_LOAD_IMAGE(SRC) 读取 SRC。支持两类输入：
%       - MAT 文件（.mat）：默认取其中第一个二维数值变量；可用
%         'Var','x' 指定变量名。
%       - 常见位图（.png/.jpg/.jpeg/.bmp/.tif/.tiff）：用 imread 读取，
%         彩色图按亮度公式 0.2989R+0.5870G+0.1140B 转灰度。
%
%   名值对参数：
%       'Var'      MAT 文件中的变量名，默认自动挑选
%       'Scale'    是否把数据换算到 [0,1]，默认 true。
%                  位图按存储类型的满量程除（uint8÷255、uint16÷65535），
%                  不做 min-max 拉伸——拉伸会连对比度和噪声一起改掉。
%                  默认开启是因为下游所有指标（PSNR、越界能量、平坦区阈值）
%                  都以 [0,1] 为量纲；照片若保持 0..255，PSNR 会算成负数。
%                  单独要研究原始数值时传 'Scale', false。
%
%   返回 META 结构体：Source（来源路径）、Var（变量名，位图为空）、
%   RawRange（原始 min/max）、Class（原始类型）、Scaled（是否做了缩放）。
%
%   说明：位图转灰度与色彩转换都是逐元素运算，不依赖 Image Processing
%   Toolbox，因此在没有工具箱的环境里也能用。
%
%   见 also FL_MAIN, FL_FILTER2.

opt = struct('Var','', 'Scale',true);
if mod(numel(varargin), 2) ~= 0
    error('fl_load_image:badArgs', '名值对参数必须是偶数个输入。');
end
for k = 1:2:numel(varargin)
    nm = char(varargin{k});
    if ~isfield(opt, nm)
        error('fl_load_image:unknownField', '未知参数名：%s', nm);
    end
    opt.(nm) = varargin{k+1};
end

if ~exist(src, 'file')
    error('fl_load_image:notFound', '文件不存在：%s', src);
end

[~, ~, ext] = fileparts(src);
meta = struct('Source', src, 'Var', '', 'RawRange', [], ...
              'Class', '', 'Scaled', logical(opt.Scale));

if strcmpi(ext, '.mat')
    info = whos('-file', src);
    names = {info.name};
    is2D = false(1, numel(info));
    for i = 1:numel(info)
        is2D(i) = (numel(info(i).size) == 2) && ~info(i).sparse;
    end
    d2 = find(is2D & strcmp({info.class}, 'double'));
    if isempty(d2)
        d2 = find(is2D);
    end
    if isempty(d2)
        error('fl_load_image:no2D', 'MAT 文件里没有二维数值变量：%s', src);
    end
    if isempty(opt.Var)
        vi = d2(1);
    else
        vi = find(strcmp(names, opt.Var), 1);
        if isempty(vi)
            error('fl_load_image:noVar', 'MAT 文件里没有变量 %s。', opt.Var);
        end
    end
    meta.Var = names{vi};
    tmp = load(src, meta.Var);
    X = double(tmp.(meta.Var));
    srcClass = info(vi).class;
else
    A = imread(src);
    srcClass = class(A);
    X = double(A);
    if ndims(X) == 3 && size(X,3) >= 3
        X = 0.2989*X(:,:,1) + 0.5870*X(:,:,2) + 0.1140*X(:,:,3);
    end
end

meta.RawRange = [min(X(:)), max(X(:))];
meta.Class = srcClass;
if opt.Scale
    % 按存图类型的满量程归一，而不是 min-max 拉伸。
    % min-max 会把对比度连同噪声一起改掉，让"噪声标准差""平坦区残留"
    % 这类依赖绝对尺度的指标失去意义；照片一进来就是 0..255，
    % 不归一的话 PSNR 会算成负数（实测 -13 dB 量级）。
    switch lower(srcClass)
        case 'uint8',  s = 255;
        case 'uint16', s = 65535;
        case 'int16',  s = 32767;
        otherwise,     s = 0;
    end
    if s == 0 && meta.RawRange(2) > 1.5
        % 已经是 double，但量纲明显不是 [0,1]（例如 .mat 里存的 0..255）
        if meta.RawRange(2) > 300
            s = 65535;
        else
            s = 255;
        end
    end
    if s > 0
        X = X / s;
        meta.Scaled = true;
    end
end
end
