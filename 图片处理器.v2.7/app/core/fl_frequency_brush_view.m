function [shown,cache]=fl_frequency_brush_view(X,C,cache)
%FL_FREQUENCY_BRUSH_VIEW Screen-size overlay on the true full-image spectrum.
% Cache belongs to one editor/working composition. The host discards it on
% opening a photo or changing geometry. No thumbnail is used to process photos.
if nargin<3 || isempty(cache)
    L=.2126*X(:,:,1)+.7152*X(:,:,2)+.0722*X(:,:,3);
    mag=log1p(abs(fftshift(fft2(L)))); mag=mag/max(max(mag(:)),eps('single'));
    rgb=fl_photo_resize(repmat(mag,1,1,3),1000);
    cache=struct('Gray',rgb(:,:,1),'Strokes',{{}},'Raw',ones(size(rgb,1),size(rgb,2),'single'));
end
strokes=C.FrequencyStrokes; n=numel(cache.Strokes);
append=n<=numel(strokes) && (n==0 || isequal(cache.Strokes,strokes(1:n)));
if append
    raw=cache.Raw;
else
    raw=ones(size(cache.Gray),'single'); n=0;
end
if n<numel(strokes)
    tail=struct('FrequencyStrokes',{strokes(n+1:end)},'FrequencyKeepDC',false);
    raw=fl_frequency_mask(size(raw),tail,raw);
end
cache.Raw=raw; cache.Strokes=strokes;
alpha=(1-raw)*.65;
if C.FrequencyKeepDC, alpha(floor(size(raw,1)/2)+1,floor(size(raw,2)/2)+1)=0; end
gray=cache.Gray.*(1-alpha);
shown=cat(3,gray+alpha,gray,gray);
end
