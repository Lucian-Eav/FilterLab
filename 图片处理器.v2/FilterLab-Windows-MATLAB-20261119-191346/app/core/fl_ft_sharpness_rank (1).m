function R=fl_ft_sharpness_rank(frames,names,opts)
%FL_FT_SHARPNESS_RANK Compare the windowed spectra of a photographic burst.
if ~iscell(frames), frames={frames}; end
if isempty(frames), error('fl_ft_sharpness_rank:empty','请选择照片。'); end
n=numel(frames);
if nargin<2 || isempty(names), names=compose('照片 %02d',(1:n)'); end
if nargin<3, opts=struct(); end
p=inputParser; p.addParameter('MaxEdge',384); p.parse(opts);
names=cellstr(string(names(:)));
if numel(names)~=n, error('fl_ft_sharpness_rank:names','每帧需要一个名称。'); end
edge=min(p.Results.MaxEdge,min(cellfun(@(a)max(size(a,1),size(a,2)),frames)));
hfr=zeros(n,1); moment=zeros(n,1); sectors=zeros(n,18); spectra=cell(n,1);
for k=1:n
    img=fl_ft_samples('normalize',frames{k},edge);
    L=fl_ft_luma(img); [h,w]=size(L);
    if min(h,w)<16, error('fl_ft_sharpness_rank:size','频谱比较需要至少 16 × 16 像素。'); end
    wy=.5-.5*cos(2*pi*(0:h-1)'/(h-1)); wx=.5-.5*cos(2*pi*(0:w-1)/(w-1));
    P=abs(fftshift(fft2((L-mean(L(:))).*(wy*wx)))).^2;
    fy=(-floor(h/2):ceil(h/2)-1)'/h; fx=(-floor(w/2):ceil(w/2)-1)/w;
    radius=2*hypot(fx,fy);
    base=radius>=.03 & radius<=.75; band=radius>=.18 & radius<=.75;
    mid=radius>=.05 & radius<=.75;
    hfr(k)=sum(P(band))/max(sum(P(base)),eps);
    moment(k)=sum(P(mid).*radius(mid).^2)/max(sum(P(mid)),eps);
    spectra{k}=log10(1+P);
    bin=1+mod(floor((atan2d(fy,fx)+5)/10),18); ring=radius>=.16 & radius<=.65;
    sectors(k,:)=accumarray(bin(ring),P(ring),[18 1],@sum,0).';
end
raw=sqrt(hfr.*moment); [~,order]=sort(raw,'descend'); best=order(1);
score=100*raw/max(raw(best),eps); rank=zeros(n,1); rank(order)=1:n;
hi=max(sectors,[],2); lo=min(sectors,[],2);
anis=(hi-lo)./(hi+lo+eps);
% Remove scene orientation (e.g. window rows) using the best burst spectrum.
relative=sectors./max(sectors(best,:),eps);
if n==1, relative=sectors; end
% The second circular harmonic fits the broad surviving orthogonal ridge.
% Rotating that ridge by 90 degrees gives the image-coordinate shake angle.
harmonic=relative*exp(2i*deg2rad((0:10:170)'));
shakeAngle=mod(angle(harmonic)*90/pi+90,180);
relative=(circshift(relative,1,2)+2*relative+circshift(relative,-1,2))/4;
low=min(relative,[],2); high=max(relative,[],2);
directional=(high-low)./(high+low+eps);
diagnosis=cell(n,1);
for k=1:n
    if k==best && raw(k)>eps
        diagnosis{k}='清晰推荐';
    elseif directional(k)>.65 && anis(k)>.24
        diagnosis{k}=sprintf('疑似手抖模糊（约 %.0f°）',shakeAngle(k));
    elseif score(k)<48
        diagnosis{k}='虚焦模糊';
    else
        diagnosis{k}='轻度柔化';
    end
end
shakeAngle(directional<=.65 | anis<=.24)=NaN;
T=table(rank,(1:n)',names,score,raw,hfr,moment,anis,shakeAngle,diagnosis, ...
    'VariableNames',{'Rank','FrameIndex','Name','Score','RawScore','HFRatio','SpectralMoment','Anisotropy','ShakeAngle','Diagnosis'});
R=struct('Table',T(order,:),'BestIndex',best,'BestImage',frames{best},'Spectra',{spectra}, ...
    'RawScore',raw,'Rank',rank,'Order',order,'ShakeAngle',shakeAngle);
end
