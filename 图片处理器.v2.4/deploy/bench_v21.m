function bench_v21(app,work,mode)
%BENCH_V21 In separate MATLAB processes run baseline first, candidate second.
assert(any(strcmp(mode,{'baseline','candidate'})));
if ~isfolder(work), mkdir(work); end
addpath(app,fullfile(app,'core'),'-begin');
assert(strcmpi(which('FL_photo'),fullfile(app,'FL_photo.m')));
inputs=fullfile(work,'inputs.mat');
if strcmp(mode,'baseline')
    rng(21,'twister'); D.rgb=rand(640,960,3,'single');
    D.burst=fl_ft_samples('burst_night'); D.sharp=fl_ft_samples('burst_sharpness');
    D.light=fl_ft_samples('night_lights'); D.wm=fl_ft_samples('watermark_photo');
    D.mountain=fl_ext_samples('mountain','synthetic'); [D.screen,D.scrMeta]=fl_ext_samples('screen_moire','synthetic');
    [D.doc,D.docMeta]=fl_ext_samples('notebook','synthetic'); D.naishu=fl_ext_samples('naishu','synthetic');
    save(inputs,'D','-v7');
else
    load(inputs,'D');
end
D.mat=fullfile(app,'samples','plus.mat');
cases={'photo-default','photo-detail','photo-brush','six-questions','moire','document','motion-sweep','allpass','burst','sharpness','watermark','starburst'};
for k=1:numel(cases)
    key=cases{k}; times=zeros(1,4);
    for j=1:numel(times)
        t=tic; values=runCase(key,D); times(j)=toc(t);
    end
    item=struct('Case',key,'First_s',times(1),'Runs_s',times(2:end),'Median_s',median(times(2:end)),'MaxAbs',0,'Pass',true);
    reference=fullfile(work,[key '.mat']);
    if strcmp(mode,'baseline')
        save(reference,'values','-v7');
    else
        ref=load(reference); assert(numel(values)==numel(ref.values));
        for n=1:numel(values)
            a=values{n}; b=ref.values{n};
            assert(isequal(size(a),size(b)) && strcmp(class(a),class(b)),'Shape or type mismatch: %s',key);
            assert(isequal(isnan(a),isnan(b)) && isequal(isinf(a),isinf(b)) && isequal(a(isinf(a)),b(isinf(b))),'Nonfinite mismatch: %s',key);
            finite=isfinite(a); diff=abs(double(a(finite))-double(b(finite))); err=max([0;diff(:)]);
            item.MaxAbs=max(item.MaxAbs,err); item.Pass=item.Pass && err<=2e-6;
        end
    end
    results(k)=item; %#ok<AGROW>
    fprintf('%s %s first %.5fs warm %.5fs maxdiff %.9g pass %d\n',mode,key,item.First_s,item.Median_s,item.MaxAbs,item.Pass);
end
report=struct('Matlab',version,'Platform',computer,'Mode',mode,'Results',results);
f=fopen(fullfile(work,[mode '.json']),'w','n','UTF-8'); assert(f>=0); cleaner=onCleanup(@()fclose(f)); fprintf(f,'%s',jsonencode(report));
assert(all([results.Pass]),'v2.1 differs beyond the absolute tolerance');
end
function out=runCase(key,D)
switch key
    case 'photo-default'
        out={fl_photo_pipeline(D.rgb,struct())};
    case 'photo-detail'
        out={fl_photo_pipeline(D.rgb,struct('FineDetail',.3,'Clarity',.3,'LocalContrast',.25,'Exposure',.25))};
    case 'photo-brush'
        brush=struct('Points',[linspace(.1,.7,15)' linspace(.2,.9,15)'],'Radius',.035,'Opacity',.8,'Mode','paint');
        effect=struct('TiltEnable',true,'TiltBlur',6,'MaskEnable',true,'MaskStrokes',{{brush}});
        out={fl_photo_pipeline(D.rgb,struct(),effect)};
    case 'six-questions'
        r=fl_assignment_compute(D.mat); out={r.Filters.Clean,r.Filters.Noisy,r.Filters.AlignedClean,r.Filters.Shift,r.Filters.RawMSE};
    case 'moire'
        r=fl_ext_moire(D.mountain,D.screen,D.scrMeta,struct()); out={r.Moire.Output,r.Sampling.ZeroPhase,r.Sampling.Causal,r.Phase.ZeroPhase};
    case 'document'
        r=fl_ext_document(D.doc,D.docMeta,struct()); out={r.Normalized,r.Background,r.CausalIIR,r.ZeroPhase};
    case 'motion-sweep'
        r=fl_ext_motion(D.mountain,struct()); out=[r.Restored,r.Filters,{r.StepResponses}];
    case 'allpass'
        r=fl_ext_allpass(D.naishu,struct()); out={r.Encrypted,r.Decrypted,r.WrongKey,r.WrongAngle};
    case 'burst'
        r=fl_ft_burst_stack(D.burst,struct('Mode','mean')); out={r.Stacked,r.Shifts,r.CropRect};
    case 'sharpness'
        r=fl_ft_sharpness_rank(D.sharp,[],struct()); out=[reshape(r.Spectra,1,[]),{r.BestIndex,r.RawScore,r.Order,r.ShakeAngle}];
    case 'watermark'
        r=fl_ft_watermark('embed',D.wm,struct()); out={r.Output,r.Spectrum,r.DetectCorr,r.PSNR,r.Attack.Noise.DetectCorr};
    case 'starburst'
        r=fl_ft_optics(D.light,struct()); out={r.Output,r.Glow,r.PSFKernel};
end
end
