function check_phase_split_v25()
%CHECK_PHASE_SPLIT_V25 Verify native phase coordinates, interleaving and PNGs.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'app','core'));
gray8 = reshape(uint8(0:62),7,9);
rgb16 = reshape(uint16(mod((0:3*9*11-1)*1009,65536)),9,11,3);
signed = reshape(int16(-24:23),6,8);
realData = single([-Inf -1 0 1; NaN .25 4 Inf; -.5 2 3 -2; 11 12 13 14]);
for X = {gray8, rgb16, signed, realData, zeros(4,13), ones(12,4)}
    for rounds = 1:2
        checkLattice(X{1},rounds);
    end
end
checkLattice(uint8([1 2; 3 4]),1);
expectError(@() fl_phase_split(gray8,0),'fl_phase_split:rounds');
expectError(@() fl_phase_split(gray8,1.5),'fl_phase_split:rounds');
expectError(@() fl_phase_split(zeros(3,8),2),'fl_phase_split:size');
expectError(@() fl_phase_split(zeros(10,1),1),'fl_phase_split:size');
expectError(@() fl_phase_split(zeros(4,4,2),1),'fl_phase_split:image');
bad = fl_phase_split(gray8,1); bad.Tiles{2,1} = bad.Tiles{1,1};
expectError(@() fl_phase_join(bad),'fl_phase_join:tile');
bad = fl_phase_split(rgb16,2); bad.Tiles{1,2} = double(bad.Tiles{1,2});
expectError(@() fl_phase_join(bad),'fl_phase_join:tile');

parent = tempname;
[ok,msg] = mkdir(parent); assert(ok && isempty(msg));
cleanup = onCleanup(@() rmdir(parent,'s')); %#ok<NASGU>
folders = {};
for X = {gray8, rgb16}
    for rounds = 1:2
        S = fl_phase_split(X{1},rounds);
        folder = fl_phase_export(S,parent);
        assert(ischar(folder) && strcmp(fileparts(folder),parent) && ~any(strcmp(folder,folders)));
        folders{end+1} = folder; %#ok<AGROW>
    end
end
% Reload after every export so a later export cannot silently alter earlier files.
k = 0;
for X = {gray8, rgb16}
    source = X{1};
    for rounds = 1:2
        k = k+1;
        folder = folders{k}; step = 2^rounds;
        assert(numel(dir(fullfile(folder,'*.png'))) == step^2+1);
        disk = fl_phase_split(source,rounds);
        for r = 1:step
            for c = 1:step
                tile = imread(fullfile(folder,sprintf('phase_r%d_c%d.png',r,c)));
                assert(strcmp(class(tile),class(source)) && isequal(tile, source(r:step:end,c:step:end,:)));
                disk.Tiles{r,c} = tile;
            end
        end
        joined = imread(fullfile(folder,'joined.png'));
        assert(strcmp(class(joined),class(source)) && isequal(joined,source) && isequal(fl_phase_join(disk),source));
    end
end
expectError(@() fl_phase_export(fl_phase_split(realData,1),parent),'fl_phase_export:type');
children = dir(parent); assert(sum(~ismember({children.name},{'.','..'})) == numel(folders));
fprintf('PASS v2.5 phase split: coordinates, disjoint coverage, class-preserving inverse, 4 exact PNG export/reload sets.\n');
end

function checkLattice(source,rounds)
S = fl_phase_split(source,rounds);
d = 2^rounds;
assert(S.Rounds == rounds && S.Step == d && isequal(S.SourceSize,size(source)) && isequal(size(S.Tiles),[d d]));
% Independently visit each source pixel and derive its destination from residues.
for y = 1:size(source,1)
    r = mod(y-1,d)+1; i = floor((y-1)/d)+1;
    for x = 1:size(source,2)
        c = mod(x-1,d)+1; j = floor((x-1)/d)+1;
        assert(isequaln(S.Tiles{r,c}(i,j,:),source(y,x,:)));
    end
end
assert(sum(cellfun(@numel,S.Tiles(:))) == numel(source));
result = fl_phase_join(S);
assert(strcmp(class(result),class(source)) && isequaln(result,source));
end

function expectError(f,id)
try
    f();
catch err
    assert(strcmp(err.identifier,id), 'Expected %s, got %s: %s', id, err.identifier, err.message);
    return
end
error('check_phase_split_v25:missingError','Expected %s.',id);
end
