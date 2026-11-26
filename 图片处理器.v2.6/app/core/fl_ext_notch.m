function [b, info] = fl_ext_notch(frequency, order)
%FL_EXT_NOTCH Remez FIR notches; frequencies normalized to Nyquist (0..1).
if nargin < 2 || isempty(order), order = 96; end
validateattributes(frequency,{'numeric'},{'vector','nonempty','positive','finite','<',1});
validateattributes(order,{'numeric'},{'scalar','integer','>=',8,'<=',512});
order = 2*ceil(order/2); b = 1;
frequency = unique(frequency(:).');
for f = frequency
    center = f;
    halfwidth = min([.018, center/5, (1-center)/5]);
    transition = min([.038, center/4, (1-center)/4]);
    bands = [0 center-halfwidth-transition center-halfwidth ...
        center+halfwidth center+halfwidth+transition 1];
    section = sl_remez(order,bands,[1 1 0 0 1 1],[2 1 2]);
    section = section/sum(section);
    b = conv(b,section);
end
f = linspace(0,1,1025).';
H = sl_freqz(b,1,pi*f);
info = struct('Centers',frequency,'Order',numel(b)-1,'Frequency',f, ...
    'Response',abs(H),'ZeroPhaseResponse',abs(H).^2);
end
