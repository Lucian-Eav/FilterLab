function R=fl_ext_export(R,folder)
%FL_EXT_EXPORT Publish selected modules into a new/empty directory.
if ~isfolder(folder)
    [ok,msg]=mkdir(folder); if ~ok, error('fl_ext_export:mkdir','%s',msg); end
end
[ok,attr]=fileattrib(folder);
if ~ok, error('fl_ext_export:folder','无法读取导出目录。'); end
folder=attr.Name;
if ~isempty(entries(folder)), error('fl_ext_export:exists','请选择空目录，已有结果将保留。'); end
% mkdir reports DirectoryExists to the losing writer, including an exact race.
stage=fullfile(folder,'.extensions-writing');
[ok,msg,id]=mkdir(stage);
if ~ok||~isempty(id), error('fl_ext_export:busy','无法独占导出目录。%s',msg); end
guard=onCleanup(@()removeStage(stage)); %#ok<NASGU>
files={'01-moire-antialiasing.png','01-moire-notch.png'; ...
    '02-document-lines.png','02-document-illumination.png'; ...
    '03-motion-blur.png','03-motion-deblur.png'; ...
    '04-allpass-response.png','04-allpass-crypto.png'};
R.OutputDir=folder;
R.Figures=reshape(files(R.Modules,:).',1,[]);
for k=R.Modules
    for v=1:2
        f=fl_ext_figure(R.Results{k}.Views(v),'off');
        closeFigure=onCleanup(@()delete(f));
        exportgraphics(f,fullfile(stage,files{k,v}),'Resolution',140);
        clear closeFigure
    end
end
writetable(R.Metrics,fullfile(stage,'metrics.csv'),'Encoding','UTF-8');
save(fullfile(stage,'results.mat'),'R','-v7');
[html,md]=reportText(R,files);
writeText(fullfile(stage,'report.html'),html);
writeText(fullfile(stage,'summary.md'),md);
paths=fl_app_paths(); quoted=strrep(paths.Root,'''','''''');
script={ ...
    '% 从 results.mat 中冻结的像素、标定和参数重新计算所有已选模块。'; ...
    '% 若移动了软件，请先 addpath 指向新的 app 目录，再运行本脚本。'; ...
    'if isempty(which(''FL_extensions''))'; ...
    ['    addpath(''' quoted ''');']; ...
    'end'; ...
    'addpath(fullfile(fileparts(which(''FL_extensions'')),''core''));'; ...
    'saved=load(fullfile(fileparts(mfilename(''fullpath'')),''results.mat''),''R'');'; ...
    'R=fl_ext_compute(saved.R.Modules,saved.R.Inputs,saved.R.Options);'; ...
    'disp(R.Metrics);'};
writeText(fullfile(stage,'reproduce_extensions.m'),strjoin(script,newline));
items=entries(folder);
if ~isequal(items,{'.extensions-writing'}), error('fl_ext_export:exists','导出时目录内容发生变化。'); end
names=entries(stage); moved={};
try
    for j=1:numel(names)
        src=fullfile(stage,names{j}); dst=fullfile(folder,names{j});
        % Java NIO move without REPLACE_EXISTING never overwrites a racing file.
        java.nio.file.Files.move(java.io.File(src).toPath(),java.io.File(dst).toPath(), ...
            javaArray('java.nio.file.CopyOption',0));
        moved{end+1}=dst; %#ok<AGROW>
    end
catch ex
    for j=1:numel(moved), delete(moved{j}); end
    rethrow(ex);
end
end

function names=entries(folder)
d=dir(folder); names=setdiff({d.name},{'.','..'},'stable');
end

function removeStage(stage)
if isfolder(stage), rmdir(stage,'s'); end
end

function [html,md]=reportText(R,files)
h={'<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">';
    '<title>FilterLab · 信号与系统扩展应用</title><style>';
    'body{max-width:1100px;margin:36px auto;padding:0 20px;background:#fafafa;color:#243039;font:16px/1.6 system-ui,sans-serif}';
    'table{border-collapse:collapse;width:100%;background:white}th,td{border:1px solid #d1d8dc;padding:6px 10px;text-align:left}';
    'img{display:block;width:100%;height:auto}h2{margin-top:2rem}figure{margin:1.2rem 0}figcaption{color:#365465}a{color:#155978}</style></head><body>';
    '<h1>信号与系统工程扩展实验</h1>'};
d={'# 信号与系统工程扩展实验'};
fields=fieldnames(R.Inputs);
for j=1:numel(fields)
    s=sprintf('%s · %s',fields{j},R.Inputs.(fields{j}).Meta.Source);
    h{end+1}=['<p>' escape(s) '</p>']; d{end+1}=mdCell(s); %#ok<AGROW>
end
h{end+1}='<h2>统一评价指标（规划书第 3 节）</h2>';
d{end+1}='## 统一评价指标（规划书第 3 节）';
[a,b]=formatTable({'模块编号','核心对比维度','关键定量评价指标','课程核心知识点'},table2cell(R.Summary));
h{end+1}=a; d{end+1}=b;
for k=R.Modules
    m=R.Results{k}; heading=char(m.Title);
    h{end+1}=['<h2>' escape(heading) '</h2>']; d{end+1}=['## ' heading]; %#ok<AGROW>
    h{end+1}=['<p>' escape(m.Conclusion) '</p>']; d{end+1}=char(m.Conclusion); %#ok<AGROW>
    [a,b]=formatTable({'指标','实测值','单位'},table2cell(m.Metrics(:,{'Metric','Value','Unit'})));
    h{end+1}=a; d{end+1}=b; %#ok<AGROW>
    for v=1:2
        name=files{k,v}; caption=char(m.Views(v).Title);
        h{end+1}=sprintf('<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>',name,escape(caption),escape(caption)); %#ok<AGROW>
        d{end+1}=sprintf('![%s](%s)',caption,name); %#ok<AGROW>
    end
end
note='频率归一化到奈奎斯特频率。PSNR 的峰值取 1；SSIM 按通道平均。缺少干净参考时，参考指标留空或记为 NaN。';
h=[h; {['<p>' note '</p>'];'<p><a href="metrics.csv">指标 CSV</a> · <a href="results.mat">原始结果 MAT</a> · <a href="reproduce_extensions.m">复现脚本</a> · <a href="summary.md">Markdown 报告</a></p></body></html>'}];
d{end+1}=note;
d{end+1}='在 MATLAB 运行同目录的 reproduce_extensions.m，使用 results.mat 中保存的输入重新计算。';
html=strjoin(h,newline); md=strjoin(d,[newline newline]);
end

function [html,md]=formatTable(headers,data)
h=cell(size(data,1)+2,1); d=h;
h{1}=['<table><thead><tr><th>' strjoin(headers,'</th><th>') '</th></tr></thead><tbody>'];
d{1}=['| ' strjoin(headers,' | ') ' |'];
d{2}=['|' repmat(' --- |',1,numel(headers))];
for r=1:size(data,1)
    values=data(r,:);
    for c=1:numel(values)
        if isnumeric(values{c}), values{c}=sprintf('%.12g',values{c}); end
    end
    row=cellfun(@escape,values,'UniformOutput',false);
    h{r+1}=['<tr><td>' strjoin(row,'</td><td>') '</td></tr>'];
    row=cellfun(@mdCell,values,'UniformOutput',false);
    d{r+2}=['| ' strjoin(row,' | ') ' |'];
end
h{end}='</tbody></table>'; html=strjoin(h,newline); md=strjoin(d,newline);
end

function s=escape(s)
s=strrep(char(s),'&','&amp;'); s=strrep(s,'<','&lt;'); s=strrep(s,'>','&gt;'); s=strrep(s,'"','&quot;');
end
function s=mdCell(s)
s=strrep(escape(s),'|','&#124;'); s=strrep(s,newline,' ');
end
function writeText(path,s)
[fid,msg]=fopen(path,'w','n','UTF-8'); if fid<0, error('fl_ext_export:write','%s',msg); end
guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',s);
[msg,err]=ferror(fid); if err, error('fl_ext_export:write','%s',msg); end
end
