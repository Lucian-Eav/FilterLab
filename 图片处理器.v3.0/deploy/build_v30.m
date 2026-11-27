function artifacts = build_v30(mode)
%BUILD_V30 Build FilterLab's standalone Windows x64 executable and installers.
%   build_v30() builds an online installer. build_v30('offline') includes
%   Runtime. build_v30('both') compiles once and creates both installers.
%   For offline packaging, use the full R2025b win64 Runtime ZIP matching
%   the build MATLAB's update. Configure it in Settings > MATLAB Compiler,
%   or prepare it on a connected build host with compiler.runtime.download.
%   Results and actual installer filenames are recorded in dist/<run>/build.json.
%   https://www.mathworks.com/help/releases/R2025b/compiler/compiler.package.installer.html
    arguments
        mode (1,1) string {mustBeMember(mode,["online","offline","both"])} = "online"
    end
    deployDir = fileparts(mfilename('fullpath'));
    projectDir = fileparts(deployDir);
    appDir = fullfile(projectDir,'app');
    requireCompiler();

    originalDir = pwd;
    originalPath = path;
    restore = onCleanup(@() restoreSession(originalDir,originalPath));
    % Building from app preserves the relative paths used by fl_app_paths
    % and FL_landing inside the extracted archive.
    cd(appDir);
    addpath(appDir,fullfile(appDir,'core'),'-begin');
    entry = 'FilterLabApp.m';
    required = [string(entry),"FL_landing.m","FL_photo.m","core/fl_app_paths.m", ...
        "samples/plus.mat","assets/ridge-overview.jpg","assets/ridge-original.png", ...
        "assets/ridge-spectrum.png","assets/ridge-lowpass.png","assets/welcome-mountain.jpg"];
    validationTools = ["runtime_check.ps1","用户验收.cmd"];
    requireFiles([required,fullfile(deployDir,validationTools)]);

    % Include GUI modules selected at runtime through names or callbacks.
    modules = dir('*.m');
    modules = string({modules.name});
    modules(modules == entry | endsWith(modules,"_selftest.m")) = [];
    inputs = [modules,"core","samples","assets"];
    if isfolder('apps')
        addpath(genpath(fullfile(appDir,'apps')),'-begin');
        inputs(end+1) = "apps";
    end

    stamp = string(datetime('now','Format','yyyyMMdd-HHmmss'));
    suffix = char(java.util.UUID.randomUUID());
    runDir = fullfile(projectDir,'dist',stamp + "-" + string(suffix(1:8)));
    if isfolder(runDir)
        error('FilterLab:BuildDirectoryExists','Build directory already exists: %s',runDir);
    end
    standaloneDir = fullfile(runDir,'standalone');
    mkdirChecked(standaloneDir);
    fprintf('Building FilterLab 3.0 with MATLAB %s\nOutput: %s\n',version,runDir);
    result = compiler.build.standaloneWindowsApplication(entry, ...
        'ExecutableName','FilterLab','ExecutableVersion','3.0.0.0', ...
        'OutputDir',standaloneDir,'AdditionalFiles',inputs,'EmbedArchive','on', ...
        'TreatInputsAsNumeric','off','Verbose','on');
    exePath = fullfile(standaloneDir,'FilterLab.exe');
    requireFiles(exePath);
    if ~any(strcmpi(string(result.Files),exePath))
        error('FilterLab:MissingBuildResult','Compiler build result does not list %s.',exePath);
    end
    for tool = validationTools
        [ok,msg] = copyfile(fullfile(deployDir,tool),fullfile(standaloneDir,tool));
        if ~ok, error('FilterLab:CopyFailed','%s',msg); end
    end

    requested = mode;
    if mode == "both", requested = ["online","offline"]; end
    artifacts = struct('MATLAB',version,'Release',version('-release'),'Platform',computer('arch'), ...
        'Executable',exePath,'Installers',struct());
    for target = requested
        if target == "online"
            delivery = 'web';
            name = 'FilterLab_3_0_Online';
        else
            delivery = 'installer';
            name = 'FilterLab_3_0_Offline';
            fprintf(['Offline packaging requires the full R2025b win64 Runtime ZIP at the same update level.\n' ...
                'On a disconnected build host, specify it in MATLAB Compiler settings.\n']);
        end
        output = fullfile(runDir,target);
        mkdirChecked(output);
        compiler.package.installer(result,'ApplicationName','FilterLab', ...
            'InstallerName',name,'Version','3.0','RuntimeDelivery',delivery, ...
            'PackageType','auto','OptionalDependencies','all','Shortcut',exePath, ...
            'AdditionalFiles',fullfile(standaloneDir,validationTools), ...
            'OutputDir',output,'Verbose','on');
        % R2025b auto-selects ZIP when the installer is at least 2 GB.
        candidates = [dir(fullfile(output,'*.exe')); dir(fullfile(output,'*.zip'))];
        candidates = candidates(~[candidates.isdir] & [candidates.bytes] > 0);
        if numel(candidates) ~= 1
            error('FilterLab:UnexpectedInstallerOutput', ...
                'Expected one installer EXE or ZIP in %s, found %d. Inspect the packaging log.', ...
                output,numel(candidates));
        end
        artifacts.Installers.(target) = fullfile(output,candidates.name);
    end

    % Only complete runs get a manifest. Keep earlier successful runs intact.
    manifest = fullfile(runDir,'build.json');
    [fid,msg] = fopen(manifest,'w','n','UTF-8');
    if fid < 0, error('FilterLab:ManifestWrite','%s',msg); end
    closeFile = onCleanup(@() fclose(fid));
    fprintf(fid,'%s\n',jsonencode(artifacts,'PrettyPrint',true));
    fprintf('Application: %s\n',exePath);
    for target = requested
        fprintf('%s installer: %s\n',target,artifacts.Installers.(target));
    end
    fprintf('Build manifest: %s\n',manifest);
end

function requireCompiler()
    if ~ispc || ~strcmp(computer('arch'),'win64') || ~strcmp(version('-release'),'2025b')
        error('FilterLab:WrongBuildPlatform', ...
            'FilterLab 3.0 requires MATLAB R2025b for Windows x64. Found R%s / %s.', ...
            version('-release'),computer('arch'));
    end
    if isempty(which('compiler.build.standaloneWindowsApplication')) || isempty(which('compiler.package.installer'))
        error('FilterLab:CompilerUnavailable', ...
            ['MATLAB Compiler R2025b build/packaging APIs are unavailable in %s. ' ...
             'Build on a machine with MATLAB Compiler installed and licensed.'],matlabroot);
    end
    [ok,msg] = license('checkout','Compiler');
    if ~ok, error('FilterLab:CompilerLicense','MATLAB Compiler license checkout failed: %s',msg); end
end

function requireFiles(files)
    missing = files(~isfile(files));
    if ~isempty(missing)
        error('FilterLab:MissingInputs','Missing build inputs: %s',strjoin(missing,', '));
    end
end

function mkdirChecked(folder)
    [ok,msg] = mkdir(folder);
    if ~ok, error('FilterLab:CreateDirectory','%s',msg); end
end

function restoreSession(originalDir,originalPath)
    cd(originalDir);
    path(originalPath);
end
