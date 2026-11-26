function N = fl_photo_noise(X)
%FL_PHOTO_NOISE Estimate noise on distributed native-resolution low-texture tiles.
% A heuristic for rendered sRGB, not a camera/RAW noise calibration.
validateattributes(X,{'single','double'},{'real','finite','nonempty','>=',0,'<=',1});
if ndims(X)~=3||size(X,3)~=3, error('fl_photo_noise:rgb','需要 RGB 照片。'); end
Y=single(.2126)*X(:,:,1)+single(.7152)*X(:,:,2)+single(.0722)*X(:,:,3);
h=size(Y,1); w=size(Y,2); tile=min([32 h w]);
N=struct('SigmaLuma',0,'SigmaChroma',0,'Confidence','不足','Tiles',0, ...
    'LumaStrength',0,'ColorStrength',0,'Threshold',0,'Method','native tiles / robust diagonal residual');
if tile<8, return; end
ys=unique(round(linspace(1,h-tile+1,min(8,max(1,floor(h/tile))))));
xs=unique(round(linspace(1,w-tile+1,min(8,max(1,floor(w/tile))))));
values=zeros(numel(xs)*numel(ys),3); index=0;
for row=ys
    for col=xs
        index=index+1; rr=row:row+tile-1; cc=col:col+tile-1; p=Y(rr,cc);
        k=single([1 2 1]/4); smooth=conv2(conv2(p,k,'valid'),k','valid');
        gx=diff(smooth,1,2); gy=diff(smooth,1,1);
        structure=median(abs(gx(:)))+median(abs(gy(:)));
        cr=X(rr,cc,1)-p; cb=X(rr,cc,3)-p;
        values(index,:)=[structure robustSigma(p) (robustSigma(cr)+robustSigma(cb))/2];
    end
end
[~,order]=sort(values(:,1)); keep=order(1:max(1,ceil(index*.3)));
N.SigmaLuma=median(values(keep,2)); N.SigmaChroma=median(values(keep,3)); N.Tiles=numel(keep);
if index>=16 && median(values(keep,1))<max(.012,1.5*N.SigmaLuma)
    N.Confidence='中';
else
    N.Confidence='低';
end
% Do not present a noise estimate as certainty; cap suggestions conservatively.
N.LumaStrength=min(.85,max(0,(N.SigmaLuma-.002)/.055));
N.ColorStrength=min(.95,max(0,(N.SigmaChroma-.003)/.09));
N.Threshold=min(.08,max(0,1.4*N.SigmaLuma));
end
function s=robustSigma(p)
r=(p(1:end-1,1:end-1)-p(2:end,1:end-1)-p(1:end-1,2:end)+p(2:end,2:end))/2;
s=double(median(abs(r(:)-median(r(:)))))/.67448975;
end
