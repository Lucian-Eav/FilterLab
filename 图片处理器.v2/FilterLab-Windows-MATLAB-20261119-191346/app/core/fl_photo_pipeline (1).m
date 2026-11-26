function [Y,info,stages]=fl_photo_pipeline(X,S,C,context)
%FL_PHOTO_PIPELINE Photo adjustments -> classic -> frequency -> tilt -> motion -> mask.
if nargin<3, C=fl_creative_spec(); else, C=fl_creative_spec(C); end
if nargin<4, context=struct('OriginalSize',size(X),'Geometry',{{}}); end
if nargout>2, [base,info,stages]=fl_photo_process(X,S);
else, [base,info]=fl_photo_process(X,S); end
[effect,creativeInfo]=fl_creative_process(base,C,context);
if C.MaskEnable
    M=fl_photo_mask(size(X),C,context);
    if strcmp(C.MaskTarget,'all'), anchor=single(X); else, anchor=base; end
    Y=anchor+(effect-anchor).*M;
else, Y=effect; end
info.Creative=creativeInfo;
Y=min(1,max(0,Y));
end
