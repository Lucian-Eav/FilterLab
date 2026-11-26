function [shown,mask,base]=fl_frequency_view(X,C,base)
%FL_FREQUENCY_VIEW Original-composition spectrum; red marks attenuated frequencies.
% Optional base is an unmarked thumbnail for this same X. Only geometry changes
% invalidate it, so brush edits can reuse the expensive FFT and downsampling.
if nargin<3||isempty(base)
    L=.2126*X(:,:,1)+.7152*X(:,:,2)+.0722*X(:,:,3);
    mag=log1p(abs(fftshift(fft2(L)))); mag=mag/max(max(mag(:)),eps('single'));
    base=fl_photo_resize(repmat(single(mag),1,1,3),1000);
end
mask=fl_frequency_mask(size(X),C);
alpha=fl_photo_resize(repmat(single(1-mask),1,1,3),1000)*.65;
shown=base.*(1-alpha); shown(:,:,1)=shown(:,:,1)+alpha(:,:,1);
end
