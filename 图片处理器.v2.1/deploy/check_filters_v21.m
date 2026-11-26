function report = check_filters_v21(oldApp,newApp)
%CHECK_FILTERS_V21 Compare two application trees on identical in-memory inputs.
% Supply paths to the old and new app directories. A mismatch throws with its field path.
[found,oldDir] = fileattrib(oldApp); assert(found,'Old app directory missing.');
[found,newDir] = fileattrib(newApp); assert(found,'New app directory missing.');
savedPath = path; savedDir = pwd; savedRng = rng;
cleanup = onCleanup(@() restore_environment(savedPath,savedDir,savedRng)); %#ok<NASGU>
cd(fileparts(mfilename('fullpath')));
activate(oldDir.Name,savedPath);
rng(19406,'twister'); X = rand(97,151); rgb = rand(63,79,3);
[screen,sm] = fl_ext_samples('screen_moire','synthetic');
rows=1:96; cols=1:128;
screen=screen(rows,cols,:); sm.Clean=sm.Clean(rows,cols,:);
[doc,dm]=fl_ext_samples('notebook','synthetic');
sample=fullfile(oldDir.Name,'samples','plus.mat');
inputs=struct('X',X,'RGB',rgb,'screen',screen,'sm',sm,'doc',doc,'dm',dm,'sample',sample);
names={'filter-matrix','filter-singletons','moire','document-roi','document-auto', ...
       'motion-oblique','allpass-hit','allpass-miss','six-questions'};
report=table(names(:),zeros(numel(names),1),zeros(numel(names),1),zeros(numel(names),1), ...
    'VariableNames',{'Case','OldSeconds','NewSeconds','MaxAbsDifference'});
for k=1:numel(names)
    activate(oldDir.Name,savedPath); timer=tic;
    expected=run_case(names{k},inputs); report.OldSeconds(k)=toc(timer);
    activate(newDir.Name,savedPath); timer=tic;
    actual=run_case(names{k},inputs); report.NewSeconds(k)=toc(timer);
    report.MaxAbsDifference(k)=compare(expected,actual,names{k});
    fprintf('[PASS] %-17s old %.4fs new %.4fs max abs %.3g\n',names{k}, ...
        report.OldSeconds(k),report.NewSeconds(k),report.MaxAbsDifference(k));
    clear expected actual
end
end

function activate(app,originalPath)
path(originalPath); addpath(app,'-begin'); core=fullfile(app,'core'); addpath(core,'-begin');
clear fl_filter2 fl_shift fl_eval fl_ext_* fl_assignment_* fl_sweep sl_*
assert(strcmpi(fileparts(which('fl_filter2')),core),'Wrong filter implementation on path.');
end

function restore_environment(savedPath,savedDir,savedRng)
path(savedPath); cd(savedDir); rng(savedRng);
clear fl_filter2 fl_shift fl_eval fl_ext_* fl_assignment_* fl_sweep sl_*
end

function value=run_case(name,p)
switch name
    case 'filter-matrix'
        % Asymmetric filters and a non-square image expose direction and edge errors.
        filters={{[.1 .2 .3 .4],1},{[.125 .5],[1 -.25 .03]}};
        edges={'zero','symmetric','replicate'}; orientations={'rc','cr'};
        value=cell(2,3,2,2);
        for i=1:2
            ba=filters{i};
            for e=1:3
                for o=1:2
                    for z=0:1
                        [img,meta]=fl_filter2(p.X,ba{1},ba{2},'Orient',orientations{o}, ...
                            'Edge',edges{e},'ZeroPhase',logical(z));
                        value{i,e,o,z+1}=struct('image',img,'info',meta);
                    end
                end
            end
        end
    case 'filter-singletons'
        % MATLAB filtfilt may reject a single sample. Match the installed branch's outcome.
        tiny={p.X(1,:),p.X(:,1),p.X(1:2,1:3),p.X(1)};
        edges={'zero','symmetric','replicate'}; value=cell(4,3,2);
        for i=1:4
            for e=1:3
                for z=0:1
                    try
                        value{i,e,z+1}=fl_filter2(tiny{i},[.2 .3 .4],[1 -.25], ...
                            'Edge',edges{e},'ZeroPhase',logical(z));
                    catch ex
                        value{i,e,z+1}=struct('errorId',ex.identifier);
                    end
                end
            end
        end
    case 'moire'
        value=fl_ext_moire(p.RGB,p.screen,p.sm,struct());
    case 'document-roi'
        value=fl_ext_document(p.doc,p.dm,struct());
    case 'document-auto'
        value=fl_ext_document(p.doc(1:95,1:127,1),struct(),struct('LinePeriod',12));
    case 'motion-oblique'
        value=fl_ext_motion(p.RGB,struct('Angle',43));
    case 'allpass-hit'
        value=fl_ext_allpass(p.RGB,struct('NumPairs',6,'DeltaRadius',.01));
    case 'allpass-miss'
        value=fl_ext_allpass(p.RGB(:,:,1),struct('NumPairs',3,'DeltaRadius',.012));
    case 'six-questions'
        value=fl_assignment_compute(p.sample);
end
end

function worst=compare(a,b,label)
assert(strcmp(class(a),class(b)) && isequal(size(a),size(b)), ...
    'check_filters_v21:shape','Type or size changed at %s.',label);
worst=0;
if isnumeric(a)
    assert(isequaln(a(~isfinite(a)),b(~isfinite(a))) && isequal(isfinite(a),isfinite(b)), ...
        'check_filters_v21:nonfinite','NaN/Inf mismatch at %s.',label);
    mask=isfinite(a); expected=a(mask); difference=abs(expected-b(mask));
    if ~isempty(difference)
        worst=max(difference(:));
        assert(all(difference(:)<=2e-11+1e-10*abs(expected(:))), ...
            'check_filters_v21:numeric','Tolerance exceeded at %s (max abs %.6g).',label,worst);
    end
elseif istable(a)
    keys=a.Properties.VariableNames; assert(isequal(keys,b.Properties.VariableNames),'Table names changed at %s.',label);
    for i=1:numel(keys), worst=max(worst,compare(a.(keys{i}),b.(keys{i}),[label '.' keys{i}])); end
elseif isstruct(a)
    keys=fieldnames(a); assert(isequal(keys,fieldnames(b)),'Struct fields changed at %s.',label);
    for j=1:numel(a)
        for i=1:numel(keys), worst=max(worst,compare(a(j).(keys{i}),b(j).(keys{i}),sprintf('%s(%d).%s',label,j,keys{i}))); end
    end
elseif iscell(a)
    for i=1:numel(a), worst=max(worst,compare(a{i},b{i},sprintf('%s{%d}',label,i))); end
else
    assert(isequaln(a,b),'check_filters_v21:exact','Value changed at %s.',label);
end
end
