function [Y, info] = fl_filter2(X, B, A, varargin)
%FL_FILTER2  可分离二维滤波引擎：把一维滤波器分别沿行、列作用一次。
%
%   Y = FL_FILTER2(X,B,A) 对二维数组 X 做可分离滤波，等价于先沿行做一维
%   滤波、再沿列做一维滤波。二维可分离滤波器是 (B,A) 与自身的张量积，因此
%   两步的顺序在数学上不改变结果；但在零初值条件下两种顺序的边界效应略有
%   差异，故仍提供开关以便对照实验。
%
%   Y = FL_FILTER2(...,'Orient','cr')     先列后行（默认 'rc' 先列后行？否：
%                                         默认 'rc' 表示先沿行再沿列）
%   Y = FL_FILTER2(...,'Edge','symmetric') 边界处理：'zero'（默认，零延拓）、
%                                         'symmetric'（镜像延拓后裁回）、
%                                         'replicate'（复制边界像素）
%   Y = FL_FILTER2(...,'ZeroPhase',true)   零相位模式：每行/每列用前后向
%                                         滤波（等效幅频为 |H|^2，相位为 0）
%
%   [Y,INFO] = FL_FILTER2(...) 额外返回 INFO 结构体，字段 Pad（延拓像素数）、
%   Orient、Edge、ZeroPhase，便于报告里写明实验条件。
%
%   输出 Y 与输入同尺寸，类型为 double。
%
%   见 also FL_EVAL, FL_SHIFT, SL_FILTFILT.

opt = struct('Orient','rc', 'Edge','zero', 'ZeroPhase',false);
if mod(numel(varargin), 2) ~= 0
    error('fl_filter2:badArgs', '名值对参数必须是偶数个输入。');
end
for k = 1:2:numel(varargin)
    nm = char(varargin{k});
    if ~isfield(opt, nm)
        error('fl_filter2:unknownField', '未知参数名：%s', nm);
    end
    opt.(nm) = varargin{k+1};
end

X = double(X);
if ~ismatrix(X)
    error('fl_filter2:not2D', '输入必须是二维数组，本引擎不做多通道展开。');
end
if ~any(strcmpi(opt.Edge, {'zero','symmetric','replicate'}))
    error('fl_filter2:badEdge', 'Edge 只能是 zero / symmetric / replicate。');
end
if ~any(strcmpi(opt.Orient, {'rc','cr'}))
    error('fl_filter2:badOrient', 'Orient 只能是 rc 或 cr。');
end

[m, n] = size(X);
L = max(numel(B), numel(A)) - 1;         % 需要的历史长度
pad = 0;
switch lower(opt.Edge)
    case 'zero'
        pad = 0;
    case {'symmetric','replicate'}
        pad = L;
end

if pad > 0
    if strcmpi(opt.Edge, 'symmetric')
        Xp = local_padsym(X, pad);
    else
        Xp = local_padrep(X, pad);
    end
else
    Xp = X;
end

zp = opt.ZeroPhase;
if strcmpi(opt.Orient, 'rc')
    Z = local_along_rows(Xp, B, A, zp);
    Y = local_along_cols(Z,  B, A, zp);
else
    Z = local_along_cols(Xp, B, A, zp);
    Y = local_along_rows(Z,  B, A, zp);
end

if pad > 0
    Y = Y(pad+1:pad+m, pad+1:pad+n);
end

info = struct('Pad', pad, 'Orient', lower(opt.Orient), ...
              'Edge', lower(opt.Edge), 'ZeroPhase', logical(zp));
end

% ------------------------------------------------------------------------
function Y = local_along_rows(X, B, A, zp)
% 双向滤波接口按列处理，非共轭转置后可一次处理所有行。
if zp
    Y = local_along_cols(X.', B, A, true).';
else
    Y = double(filter(B, A, X, [], 2));
end
end

% ------------------------------------------------------------------------
function Y = local_along_cols(X, B, A, zp)
% MATLAB filter 的 dim=1 将矩阵每列当作独立序列，与逐列循环同义。
if ~zp
    Y = double(filter(B, A, X, [], 1));
elseif size(X,1) == 1
    % sl_filtfilt 将行向量视为一条长信号，此处每列实际是单像素。
    Y = zeros(size(X));
    for j = 1:size(X,2), Y(j) = sl_filtfilt(B, A, X(j)); end
else
    Y = double(sl_filtfilt(B, A, X));
end
end

% ------------------------------------------------------------------------
function Y = local_padsym(X, p)
% 镜像延拓，不重复边界像素（对应 numpy 的 reflect 语义）。
[m, n] = size(X);
ii = [p:-1:1, 1:m, m-1:-1:m-p];
jj = [p:-1:1, 1:n, n-1:-1:n-p];
ii = min(max(ii, 1), m);
jj = min(max(jj, 1), n);
Y = X(ii, jj);
end

% ------------------------------------------------------------------------
function Y = local_padrep(X, p)
% 复制边界像素延拓。
[m, n] = size(X);
ii = [ones(1,p), 1:m, m*ones(1,p)];
jj = [ones(1,p), 1:n, n*ones(1,p)];
Y = X(ii, jj);
end
