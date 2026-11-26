function N = fl_photo_noise(X)
%FL_PHOTO_NOISE Estimate noise on distributed native-resolution low-texture tiles.
% A heuristic for rendered sRGB, not a camera/RAW noise calibration.
validateattributes(X,{'single','double'},{'real','finite','nonempty','>=',0,'<=',1});
if ndims(X)~=3||size(X,3)~=3, error('fl_photo_noise:rgb','需要 RGB 照片。'); end
h=size(X,1); w=size(X,2); tile=min([32 h w]);
N=struct('SigmaLuma',0,'SigmaChroma',0,'Confidence','不足','Tiles',0, ...
    'LumaStrength',0,'ColorStrength',0,'Threshold',0,'Method','native tiles / robust diagonal residual');
if tile<8, return; end
ys=unique(round(linspace(1,h-tile+1,min(8,max(1,floor(h/tile))))));
xs=unique(round(linspace(1,w-tile+1,min(8,max(1,floor(w/tile))))));
% Gather only the native tiles used by the estimator (at most 256 x 256).
% Ordering is row of tiles first, then column, as in the ranking below.
rows=reshape((0:tile-1)'+ys,1,[]); cols=reshape((0:tile-1)'+xs,1,[]);
red=X(rows,cols,1); blue=X(rows,cols,3);
Y=single(.2126)*red+single(.7152)*X(rows,cols,2)+single(.0722)*blue;
k=single([1 2 1]/4); ncols=numel(xs); count=ncols*numel(ys);
structure=zeros(count,1);
for i=1:count
    rr=floor((i-1)/ncols)*tile+(1:tile); cc=mod(i-1,ncols)*tile+(1:tile);
    p=Y(rr,cc); smooth=conv2(conv2(p,k,'valid'),k','valid');
    gx=diff(smooth,1,2); gy=diff(smooth,1,1);
    structure(i)=median(abs(gx(:)))+median(abs(gy(:)));
end
[~,order]=sort(structure); keep=order(1:max(1,ceil(count*.3)));
% Only retained low-texture tiles contribute to the noise statistics.
values=zeros(numel(keep),3);
for j=1:numel(keep)
    i=keep(j); rr=floor((i-1)/ncols)*tile+(1:tile); cc=mod(i-1,ncols)*tile+(1:tile);
    p=Y(rr,cc); cr=red(rr,cc)-p; cb=blue(rr,cc)-p;
    % Concatenate in the original precision before storing in the double table.
    values(j,:)=[cast(structure(i),'like',Y), robustSigma(p), (robustSigma(cr)+robustSigma(cb))/2];
end
N.SigmaLuma=median(values(:,2)); N.SigmaChroma=median(values(:,3)); N.Tiles=numel(keep);
if count>=16 && median(structure(keep))<max(.012,1.5*N.SigmaLuma)
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
