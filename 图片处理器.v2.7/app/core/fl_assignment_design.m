function F=fl_assignment_design()
%FL_ASSIGNMENT_DESIGN Exact assignment parameters; NEVER normalize FIR DC.
% Locked fallback references: Parks-McClellan (scipy.signal.remez), density 256,
% maxiter 100, fs=2, equal weights. Dense-grid alternation is checked below.
% Native remez/firpm is preferred when installed; slight grid differences are normal.
[b,a]=sl_butter(10,.4);
source='解析 Butterworth 极点 + 双线性变换';
if exist('butter','file')==2, source='MATLAB butter(10,0.4)'; end
F=struct('Name',{},'B',{},'A',{},'Order',{},'Source',{},'LinearPhase',{},'Certificate',{});
F(1)=struct('Name','Butterworth 10阶','B',b,'A',a,'Order',10,'Source',source,'LinearPhase',false,'Certificate',struct());
refs={ [0.075104739873257345 0.43693880707754257 0.34979052025348523 0.43693880707754257 0.075104739873257345], ...
 [0.087781519115786716 -0.032490571504481633 -0.099909808698654581 -0.082851712637601216 0.074628772856096301 0.28577910686051938 0.38421957181912514 0.28577910686051938 0.074628772856096301 -0.082851712637601216 -0.099909808698654581 -0.032490571504481633 0.087781519115786716]};
orders=[4 12];
for k=1:2
    n=orders(k); source='固定题目参数：Parks–McClellan 参考系数（已验证等纹波交替条件）';
    if exist('remez','file')==2
        b=remez(n,[0 .36 .44 1],[1 1 0 0]); source='MATLAB remez';
    elseif exist('firpm','file')==2
        b=firpm(n,[0 .36 .44 1],[1 1 0 0]); source='MATLAB firpm（remez 后继接口）';
    else, b=refs{k}; end
    certificate=certify(b,n);
    if ~certificate.Passed, error('fl_assignment_design:certificate','FIR 等纹波交替验证未通过。'); end
    F(k+1)=struct('Name',sprintf('等纹波 FIR %d阶',n),'B',b,'A',1,'Order',n, ...
        'Source',source,'LinearPhase',true,'Certificate',certificate);
end
end
function C=certify(b,n)
peaks=[]; freqs=[];
for band=1:2
    if band==1, w=linspace(0,.36,16385); desired=1; else, w=linspace(.44,1,16385); desired=0; end
    A=real(exp(-1i*pi*w(:)*(0:n))*b(:).*exp(1i*pi*w(:)*n/2)); e=A-desired;
    ids=[1;find((e(2:end-1)-e(1:end-2)).*(e(3:end)-e(2:end-1))<=0)+1;numel(e)];
    peaks=[peaks;e(ids)]; freqs=[freqs;w(ids)']; %#ok<AGROW>
end
peak=max(abs(peaks)); keep=abs(peaks)>peak*.98; peaks=peaks(keep); freqs=freqs(keep);
alternating=numel(peaks)>=n/2+2 && all(peaks(1:end-1).*peaks(2:end)<0);
spread=(max(abs(peaks))-min(abs(peaks)))/max(peak,eps);
C=struct('Passed',alternating&&spread<.02&&max(abs(b-fliplr(b)))<1e-12, ...
    'PeakError',peak,'RelativeSpread',spread,'Frequencies',freqs,'SignedErrors',peaks,'Alternations',numel(peaks));
end
