function [preview, alpha] = fl_barrier_view(base, w, offset)
%FL_BARRIER_VIEW Overlay the grating on a uint8 RGB base, at integer offset.
% offset=0 reveals A, offset=w reveals B. Positive offsets move right.
% Optional alpha is the black layer's uint8 opacity, 0 clear and 255 opaque.
if ~isa(base,'uint8') || isempty(base) || ndims(base)~=3 || size(base,3)~=3
    error('fl_barrier_view:base','底图必须为非空的 uint8 RGB 图像。');
end
blocked = fl_barrier_columns(size(base,2),w,offset);
preview = base;
preview(:,blocked,:) = 0;
if nargout>1
    alpha = repmat(uint8(blocked).*uint8(255),size(base,1),1);
end
end
