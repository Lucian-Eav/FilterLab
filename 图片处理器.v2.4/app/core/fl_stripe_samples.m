function s = fl_stripe_samples(step,frequencies)
%FL_STRIPE_SAMPLES Compare two in-phase gray cosines across a 256 px field.
% Rows of Original and Samples correspond to A and B. Frequency bins are
% cycles per full original width, including after decimation.
if nargin < 1, step = 4; end
if nargin < 2, frequencies = [24 40]; end
width = 256;
steps = [1 2 4 8 16 32];
validateattributes(step,{'numeric'},{'real','finite','scalar','integer'});
if ~ismember(step,steps)
    error('fl_stripe_samples:step','采样步长可取 1、2、4、8、16 或 32 像素。');
end
validateattributes(frequencies,{'numeric'},{'real','finite','vector','numel',2,'integer','>=',0,'<=',width/2});
step = double(step);
frequencies = double(frequencies(:));
x = 0:width-1;
% Integer phase wrapping and even symmetry give identical pixel values for
% coincident cosines, including frequencies that fold onto the same bin.
phase = mod(frequencies*x,width);
original = .5 + .5*cos((2*pi/width)*min(phase,width-phase));
indices = 1:step:width;
samples = original(:,indices);
count = numel(indices);
% Subtract the fixed gray background to preserve genuine contrast at DC
% when a cosine lands on bin zero. DC and Nyquist have no partner.
amp = abs(fft(samples-.5,[],2))/count;
amp = amp(:,1:count/2+1);
amp(:,2:end-1) = 2*amp(:,2:end-1);
[~,peaks] = max(amp,[],2);
s = struct('Width',width,'Step',step,'Steps',steps,'Frequencies',frequencies.', ...
    'X',x,'Original',original,'SampleX',x(indices),'Samples',samples, ...
    'Count',count,'Nyquist',count/2,'Bins',0:count/2,'Amplitude',amp, ...
    'Peaks',peaks.'-1,'MaxDifference',max(abs(samples(1,:)-samples(2,:))));
end
