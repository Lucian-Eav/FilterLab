function FilterLabSession()
% A fresh studio per open, reusing the engine only if explicitly requested.
ready=getenv('FILTERLAB_READY_FILE'); pref=getenv('FILTERLAB_WARM_CONFIG');
restore=onCleanup(@()setenv('FILTERLAB_READY_FILE',ready)); %#ok<NASGU>
FilterLabApp();
if isempty(ready) || isempty(pref), return; end
folder=fileparts(ready); idle=fullfile(folder,'idle.flag');
reopen=fullfile(folder,'reopen.flag'); expired=fullfile(folder,'expired.flag');
warm=fullfile(folder,'warm-ready.flag');
while isfile(pref)
    if isfile(warm), delete(warm); end
    fid=fopen(idle,'w'); if fid<0, return; end; fclose(fid);
    t=tic;
    while ~isfile(reopen)
        if toc(t)>=120 || ~isfile(pref)
            % The launcher claims the same idle file. A rename on this volume
            % has one winner, including a double-click right at the deadline.
            try
                System.IO.File.Move(idle,expired); return
            catch err
                if ~isfile(reopen), rethrow(err); end
            end
        end
        pause(.15);
    end
    delete(reopen); setenv('FILTERLAB_READY_FILE',warm);
    FilterLabApp();
end
end
