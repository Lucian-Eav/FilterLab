function report=check_freq_v21(oldApp,newApp)
%CHECK_FREQ_V21 Reproducible numerical regression of the four frequency tools.
previousPath=path; previousDir=pwd; previousRng=rng;
cleanup=onCleanup(@()restore(previousPath,previousDir,previousRng)); %#ok<NASGU>
[ok,oldDir]=fileattrib(oldApp); assert(ok && oldDir.directory);
[ok,newDir]=fileattrib(newApp); assert(ok && newDir.directory);
assert(~strcmpi(oldDir.Name,newDir.Name),'Source directories must differ.');
old=collect(oldDir.Name); new=collect(newDir.Name);
keys=fieldnames(old); report=repmat(struct('Case','','MaxAbs',0),numel(keys),1);
for i=1:numel(keys)
    key=keys{i}; worst=compare_value(old.(key),new.(key),key);
    report(i)=struct('Case',key,'MaxAbs',worst);
    fprintf('freq diff %-25s max_abs %.6g\n',key,worst);
end
fprintf('Frequency regression passed %d cases.\n',numel(keys));
end

function r=collect(app)
cd(app); core=fullfile(app,'core'); addpath(app,core,'-begin');
clear fl_ft_samples fl_ft_sharpness_rank fl_ft_burst_stack fl_ft_watermark fl_ft_optics fl_ft_luma fl_ext_metrics fl_photo_resize
used={'fl_ft_samples','fl_ft_sharpness_rank','fl_ft_burst_stack','fl_ft_watermark','fl_ft_optics','fl_ft_luma','fl_ext_metrics','fl_photo_resize'};
for i=1:numel(used)
    assert(strcmpi(which(used{i}),fullfile(core,[used{i} '.m'])),'Wrong source for %s',used{i});
end
stream=RandStream('mt19937ar','Seed',2101);
img=.04+.92*rand(stream,65,78,3);
img(1:4,1:4,:)=1; img(end-4:end,end-2:end,:)=1;
% Fixed images isolate registration from changes to the sample generator.
truth=[0 0;2 -3;-4 1;1 4]; frames=cell(1,size(truth,1));
for i=1:numel(frames), frames{i}=circshift(img,[truth(i,:) 0]); end
for entry={'median','mean','trimmed'}
    for cropped=[false true]
        mode=entry{1}; key=sprintf('burst_%s_%d',mode,cropped);
        o=struct('RefIndex',3,'AutoCrop',cropped,'Mode',mode,'Clean',img,'TrueShifts',truth);
        b=fl_ft_burst_stack(frames,o); r.(key)=b;
        validate_image(b.Stacked); validate_image(b.Reference);
        expected=all(isfinite(b.Aligned(:,:,1,:)),4);
        assert(isequal(b.ValidMask,expected));
        assert(isequal(size(b.Stacked),[b.CropRect(4) b.CropRect(3) 3]));
        if cropped, assert(all(expected(:)) && numel(expected)<size(img,1)*size(img,2));
        else, assert(~all(expected(:)) && isequal(size(b.Stacked),size(img))); end
    end
end
r.burst_single=fl_ft_burst_stack(frames(1),struct('Mode','trimmed'));
assert(isequal(r.burst_single.Stacked,img));
r.burst_pair=fl_ft_burst_stack(frames(1:2),struct('Mode','trimmed','RefIndex',2));
% Same shape, changed aspect ratio, then return to the first shape.
rankFrames={img,frames{2},img(1:54,:,:),img(2:end,:,:),img};
r.sharp_mixed=fl_ft_sharpness_rank(rankFrames,[],struct('MaxEdge',78));
assert(isequal(r.sharp_mixed.BestImage,rankFrames{r.sharp_mixed.BestIndex}));
assert(isequal(sort(r.sharp_mixed.Order),(1:numel(rankFrames))'));
r.sharp_flat=fl_ft_sharpness_rank({zeros(32,33,3)},[],struct());
% Mixed-parity image pairs exercise both conjugate-index conventions.
r.wm_icon=fl_ft_watermark('embed',img,struct('Mode','icon','Icon','plus','RunAttackTest',true));
r.wm_text=fl_ft_watermark('embed',img(1:64,1:77,:),struct('Text','V21','RunAttackTest',false));
r.wm_inspect=fl_ft_watermark('inspect',r.wm_icon.Output,struct('Mode','icon','Icon','plus'));
validate_image(r.wm_icon.Output); validate_image(r.wm_text.Output);
assert(r.wm_icon.ImagResidual<1e-12 && r.wm_text.ImagResidual<1e-12);
assert(isequal(r.wm_icon.WatermarkSpectrum,r.wm_inspect.WatermarkSpectrum));
r.opt_rgb=fl_ft_optics(img,struct('Dispersion',true,'Size',46));
r.opt_mono=fl_ft_optics(img,struct('Dispersion',false,'Size',17));
r.opt_bokeh=fl_ft_optics(img,struct('Effect','bokeh','Size',19,'Aperture','ring'));
r.opt_dark=fl_ft_optics(.1*ones(34,31,3),struct('Size',9));
assert(~any(r.opt_dark.Glow(:)) && r.opt_dark.Metrics.HighlightFraction==0);
for opt={'opt_rgb','opt_mono','opt_bokeh','opt_dark'}
    o=r.(opt{1}); validate_image(o.Output);
    assert(all(o.Glow(:)>=0) && abs(sum(o.PSFKernel(:))-1)<1e-12);
    for c=1:3, kernel=o.ChannelKernels(:,:,c); assert(abs(sum(kernel(:))-1)<1e-12); end
end
% Also compare deterministic sample pixels, metadata and RNG isolation.
state=rng;
for kind={'burst_night','burst_crowd','burst_sharpness','watermark_photo','night_lights'}
    key=kind{1}; [a,m]=fl_ft_samples(key,[],512); r.(['sample_' key])={a,m};
end
assert(isequal(state,rng),'Sample generation changed caller RNG.');
end

function validate_image(x)
assert(isreal(x) && all(isfinite(x(:))) && all(x(:)>=-1e-14 & x(:)<=1+1e-14));
end

function worst=compare_value(a,b,key)
assert(strcmp(class(a),class(b)) && isequal(size(a),size(b)),'Class/shape differs in %s',key);
worst=0;
if istable(a)
    names=a.Properties.VariableNames; assert(isequal(names,b.Properties.VariableNames));
    for i=1:numel(names)
        name=names{i}; worst=max(worst,compare_value(a.(name),b.(name),[key '.' name]));
    end
elseif isstruct(a)
    names=fieldnames(a); assert(isequal(names,fieldnames(b)),'Fields differ in %s',key);
    for i=1:numel(names)
        name=names{i}; worst=max(worst,compare_value(a.(name),b.(name),[key '.' name]));
    end
elseif iscell(a)
    for i=1:numel(a), worst=max(worst,compare_value(a{i},b{i},sprintf('%s{%d}',key,i))); end
elseif isfloat(a)
    assert(isequal(isnan(a),isnan(b)) && isequal(isinf(a),isinf(b)) && isequal(a(isinf(a)),b(isinf(b))),'NaN/Inf differs in %s',key);
    valid=isfinite(a); ref=double(a(valid)); delta=abs(ref-double(b(valid)));
    if ~isempty(delta)
        worst=max(delta(:));
        assert(all(delta(:)<=2e-10+2e-10*abs(ref(:))),'Numeric difference %.6g in %s',worst,key);
    end
else
    assert(isequaln(a,b),'Discrete value differs in %s',key);
end
end

function restore(previousPath,previousDir,previousRng)
cd(previousDir); path(previousPath); rng(previousRng);
clear fl_ft_samples fl_ft_sharpness_rank fl_ft_burst_stack fl_ft_watermark fl_ft_optics fl_ft_luma fl_ext_metrics fl_photo_resize
end
