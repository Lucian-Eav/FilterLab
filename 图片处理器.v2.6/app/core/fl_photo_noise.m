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
% Smooth the packed rectangle once. Read only interiors of individual tiles,
% so artificial edges between the packed tiles never enter a statistic.
smooth=conv2(conv2(Y,k,'valid'),k','valid');
ny=numel(ys); m=tile-2; r0=(0:ny-1)*tile; c0=(0:ncols-1)*tile;
ri=reshape((1:m)'+r0,1,[]); ci=reshape((1:m)'+c0,1,[]);
rg=reshape((1:m-1)'+r0,1,[]); cg=reshape((1:m-1)'+c0,1,[]);
gx=abs(smooth(ri,cg+1)-smooth(ri,cg)); gy=abs(smooth(rg+1,ci)-smooth(rg,ci));
% Within each column the samples have the original MATLAB linear order;
% statistics across columns retain the original row-major tile ranking.
gx=reshape(permute(reshape(gx,m,ny,m-1,ncols),[1 3 4 2]),[],count);
gy=reshape(permute(reshape(gy,m-1,ny,m,ncols),[1 3 4 2]),[],count);
structure=double(median(gx,1)+median(gy,1)).';
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
