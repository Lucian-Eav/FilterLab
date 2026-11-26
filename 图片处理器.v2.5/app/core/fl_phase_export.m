function folder = fl_phase_export(S, parentDir)
%FL_PHASE_EXPORT Save native-resolution phases and their exact interleave.
%   Returns a fresh child directory of parentDir. PNG accepts uint8 and
%   uint16 here; other numeric classes would need an explicit conversion.
if isstring(parentDir) && isscalar(parentDir), parentDir = char(parentDir); end
if ~ischar(parentDir) || ~isrow(parentDir) || ~isfolder(parentDir)
    error('fl_phase_export:parent', '请选择一个已有的导出目录。');
end
joined = fl_phase_join(S);
if ~isa(joined,'uint8') && ~isa(joined,'uint16')
    error('fl_phase_export:type', '无损 PNG 导出仅支持 uint8 和 uint16 原图。');
end
[~,token] = fileparts(tempname(parentDir));
folder = fullfile(parentDir, sprintf('phases_%dx%d_%s', S.Step, S.Step, token));
[ok,msg] = mkdir(folder);
% mkdir reports success with a nonempty message for an existing directory.
if ~ok || ~isempty(msg)
    error('fl_phase_export:mkdir', '无法创建专用导出目录：%s', msg);
end
cleanup = onCleanup(@() removeIncomplete(folder)); %#ok<NASGU>
for r = 1:S.Step
    for c = 1:S.Step
        name = sprintf('phase_r%d_c%d.png',r,c);
        imwrite(S.Tiles{r,c}, fullfile(folder,name), 'png');
    end
end
% Publish joined.png only after its writer has closed successfully. Its
% final name also serves as the commit marker for cleanup on interruption.
pending = fullfile(folder,'joined.partial.png');
imwrite(joined,pending,'png');
[ok,msg] = movefile(pending,fullfile(folder,'joined.png'));
if ~ok, error('fl_phase_export:commit', '无法完成导出：%s',msg); end
end

function removeIncomplete(folder)
if isfolder(folder) && ~isfile(fullfile(folder,'joined.png'))
    [ok,msg] = rmdir(folder,'s');
    if ~ok, warning('fl_phase_export:cleanup','未能清理不完整的导出目录 %s：%s',folder,msg); end
end
end
