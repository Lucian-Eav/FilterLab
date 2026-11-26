function R=fl_assignment_export(R,folder)
%FL_ASSIGNMENT_EXPORT Six-question evidence: plots, UTF-8 report, raw arrays, replay.
if exist(folder,'dir')==7
    items=dir(folder); items=items(~ismember({items.name},{'.','..'}));
    if ~isempty(items), error('fl_assignment_export:exists','请选择空文件夹，避免覆盖已有实验结果。'); end
else, [ok,msg]=mkdir(folder); if ~ok, error('fl_assignment_export:mkdir','%s',msg); end
end
R.OutputDir=folder; F=R.Filters;
figs={'01-input.png','02-frequency.png','03-step.png','04-clean.png','05-shape.png','06-noise.png'};
R.Figures=figs;
for page=1:6
    f=figure('Visible','off','Color','w','Position',[50 50 1400 900]);
    cleanup=onCleanup(@()close(f));
    switch page
        case 1
            t=tiledlayout(f,1,2,'Padding','compact');
            ax=nexttile(t); image(ax,64*R.X); colormap(ax,gray(64)); axis(ax,'image'); title(ax,'原图 x：image(64*x)');
            ax=nexttile(t); image(ax,64*R.Xn); colormap(ax,gray(64)); axis(ax,'image'); title(ax,'题目 xn：image(64*xn)（仅显示裁切）');
            title(t,sprintf('原始数据 %d × %d · xn 范围 %.4f ～ %.4f',size(R.X,2),size(R.X,1),min(R.Xn(:)),max(R.Xn(:))));
        case 2
            t=tiledlayout(f,2,2,'Padding','compact');
            ax=nexttile(t); hold(ax,'on'); for k=1:3, plot(ax,F(k).Frequency,abs(F(k).Response),'LineWidth',1.3); end
            title(ax,'幅频响应（原始增益）'); xlabel(ax,'频率 / π'); grid(ax,'on'); legend(ax,{F.Name},'Location','northeast');
            ax=nexttile(t); hold(ax,'on');
            for k=1:3, p=F(k).Phase; p(abs(F(k).Response)<1e-4)=NaN; plot(ax,F(k).Frequency,p,'LineWidth',1.3); end
            title(ax,'展开相位（幅度 < 10^{-4} 隐去）'); xlabel(ax,'频率 / π'); ylabel(ax,'弧度'); grid(ax,'on');
            ax=nexttile(t); hold(ax,'on');
            for k=1:3, pass=F(k).Frequency<=.36; plot(ax,F(k).Frequency(pass),F(k).GroupDelay(pass),'LineWidth',1.3); end
            title(ax,'通带群延迟'); xlabel(ax,'频率 / π'); ylabel(ax,'样本'); grid(ax,'on');
            ax=nexttile(t); hold(ax,'on'); for k=1:3, stem(ax,0:24,filter(F(k).B,F(k).A,[1 zeros(1,24)]),'.'); end
            title(ax,'冲激响应（前 25 点）'); xlabel(ax,'样本'); grid(ax,'on');
        case 3
            t=tiledlayout(f,3,1,'Padding','compact');
            for k=1:3
                ax=nexttile(t); plot(ax,0:79,F(k).Step(1:80),'LineWidth',1.5); hold(ax,'on'); yline(ax,F(k).DCGain,'--');
                plot(ax,F(k).StepPeakIndex,F(k).StepPeak,'ro'); grid(ax,'on');
                title(ax,sprintf('%s · 稳态 %.5f · 超调 %.5f（%.2f%%）',F(k).Name,F(k).DCGain,F(k).Overshoot,100*F(k).RelativeOvershoot));
                xlabel(ax,'样本 n（从 0 开始）');
            end
        case {4,6}
            t=tiledlayout(f,3,3,'Padding','compact','TileSpacing','compact');
            for k=1:3
                if page==4, images={R.X,F(k).RowClean,F(k).Clean}; else, images={R.Xn,F(k).RowNoisy,F(k).Noisy}; end
                labels={'输入','仅行滤波','行→列滤波'};
                for j=1:3
                    ax=nexttile(t); imagesc(ax,images{j},[0 1]); colormap(ax,gray(256)); axis(ax,'image');
                    title(ax,[F(k).Name ' · ' labels{j}]);
                end
            end
            title(t,'固定显示范围 [0,1]；计算与 MAT 中保留负值/过冲，无平移、无归一化');
        case 5
            t=tiledlayout(f,2,2,'Padding','compact'); r=round(size(R.X,1)/2); c=round(size(R.X,2)/2);
            ax=nexttile(t); plot(ax,R.X(r,:),'k--','LineWidth',2); hold(ax,'on');
            for k=1:3, plot(ax,F(k).Clean(r,:),'LineWidth',1.2); end
            title(ax,'中心行：原始输出，含延迟与增益'); legend(ax,[{'原图'} {F.Name}],'Location','best'); grid(ax,'on');
            ax=nexttile(t); plot(ax,R.X(:,c),'k--','LineWidth',2); hold(ax,'on');
            for k=1:3, plot(ax,F(k).Clean(:,c),'LineWidth',1.2); end
            title(ax,'中心列：原始输出'); grid(ax,'on');
            ax=nexttile(t); plot(ax,R.X(r,:),'k--','LineWidth',2); hold(ax,'on');
            for k=1:3, plot(ax,F(k).AlignedClean(r,:),'LineWidth',1.2); end
            title(ax,'诊断：补偿整数位移 + DC 增益后'); grid(ax,'on');
            ax=nexttile(t); bar(ax,[[F.RawMSE]' [F.AlignedMSE]' [F.GainCorrectedMSE]']);
            ax.XTick=1:3; ax.XTickLabel={F.Name}; ylabel(ax,'MSE（越小越好）');
            title(ax,'含噪结果：三种口径分别比较'); legend(ax,{'原坐标全图','同域补偿延迟','同域再校正增益'},'Location','best'); grid(ax,'on');
    end
    exportgraphics(f,fullfile(folder,figs{page}),'Resolution',130); clear cleanup;
end
x=R.X; xn=R.Xn; %#ok<NASGU>
save(fullfile(folder,'results.mat'),'R','x','xn','-v7');
html=['<!doctype html><html lang="zh"><meta charset="utf-8"><title>FilterLab 六问实验报告</title>' ...
    '<style>body{max-width:1120px;margin:40px auto;padding:0 24px;font:16px/1.65 system-ui;color:#243039;background:#fafafa}' ...
    'h1,h2{line-height:1.3}table{border-collapse:collapse;width:100%;font-size:14px}td,th{border:1px solid #ccd3d7;padding:7px;text-align:left}' ...
    'img{width:100%;background:white}pre{overflow:auto;background:#edf0f2;padding:14px}small{color:#596873}</style><body>' ...
    '<h1>基于一维滤波器的图像处理</h1><p>FilterLab · 原题参数 · 可复现实验</p><p>数据：' esc(R.DataFile) ...
    '</p><p>频率归一化到奈奎斯特频率。保留原始系数和 xn；行维度 2 → 列维度 1，零初态。未增加噪声、预填充、循环移位或裁切计算值。</p>'];
html=[html '<h2>设计来源与原始系数</h2>'];
for k=1:3
    html=[html '<p><b>' esc(F(k).Name) '</b>：' esc(F(k).Source) '</p><pre>b = ' mat2str(F(k).B,17) ';\na = ' mat2str(F(k).A,17) ';</pre>']; %#ok<AGROW>
    if F(k).LinearPhase
        html=[html sprintf('<p>交替极值数 %d，峰值相对离散度 %.3g（稠密网格证据，非符号证明）。</p>',F(k).Certificate.Alternations,F(k).Certificate.RelativeSpread)]; %#ok<AGROW>
    end
end
html=[html '<h2>定量结果</h2><table><tr><th>滤波器</th><th>DC</th><th>绝对超调</th><th>相对超调</th><th>位移 [行,列]</th><th>全图 MSE</th><th>同域延迟补偿 MSE</th><th>同域增益校正 MSE</th><th>对称误差</th></tr>'];
for k=1:3
    html=[html sprintf('<tr><td>%s</td><td>%.6f</td><td>%.6f</td><td>%.2f%%</td><td>%s</td><td>%.6g</td><td>%.6g</td><td>%.6g</td><td>%.6g</td></tr>', ...
        esc(F(k).Name),F(k).DCGain,F(k).Overshoot,F(k).RelativeOvershoot*100,mat2str(F(k).Shift),F(k).RawMSE,F(k).AlignedMSE,F(k).GainCorrectedMSE,F(k).SymmetryError)]; %#ok<AGROW>
end
html=[html sprintf('</table><p>同域比较参考区：行 1～%d，列 1～%d；所有滤波器使用相同参考像素。IIR 位移由干净图像估计，不拟合噪声。原图对称误差 %.6g。</p>', ...
    R.CommonRows(end),R.CommonCols(end),R.OriginalSymmetry)];
for k=1:6
    html=[html sprintf('<h2>第 %d 问</h2><p>%s</p><img src="%s" alt="第 %d 问图示">',k,esc(R.Answers{k}),figs{k},k)]; %#ok<AGROW>
end
html=[html '<h2>复现与解释范围</h2><p><a href="results.mat">原始数组、系数、指标 MAT</a> · <a href="reproduce.m">无工具箱复现脚本</a> · <a href="original_design.m">原题设计语句（需信号工具箱）</a></p>' ...
    '<p>FIR 的固定参数备用系数由 Parks–McClellan 数值交换算法离线生成，并检查通/阻带交替误差；不是当前机器调用原生 remez 的记录。' ...
    '安装 Signal Processing Toolbox 后会优先调用原生 butter 与 remez/firpm。不同实现的离散设计网格可造成末位差异。' ...
    '照片版使用 RGB 保边与非线性细节处理，不能把这里的三滤波器排名推广为照片处理质量排名。</p></body></html>'];
html=strrep(html,';\na',';<br>a'); writeText(fullfile(folder,'report.html'),html);
md='# 一维滤波图像处理：六问结论';
for k=1:6, md=[md sprintf('\n\n## 第 %d 问\n\n%s\n',k,R.Answers{k})]; end %#ok<AGROW>
md=[md sprintf('\n完整系数、图示、指标口径与设计来源见同目录 report.html；数组见 results.mat。\n')];
writeText(fullfile(folder,'answers.md'),md);
script=sprintf('%% FilterLab 原题复现；放在导出目录运行，无附加工具箱。\nD=load(fullfile(fileparts(mfilename(''fullpath'')),''results.mat''));\nx=D.x; xn=D.xn;\n');
for k=1:3
    script=[script sprintf('b%d=%s; a%d=%s;\nrow%d=filter(b%d,a%d,x,[],2); y%d=filter(b%d,a%d,row%d,[],1);\nyn%d=filter(b%d,a%d,filter(b%d,a%d,xn,[],2),[],1);\n', ...
        k,mat2str(F(k).B,17),k,mat2str(F(k).A,17),k,k,k,k,k,k,k,k,k,k,k,k)]; %#ok<AGROW>
end
script=[script sprintf('figure; image(64*x); colormap(gray(64)); axis image; title(''题目原图'');\n')];
writeText(fullfile(folder,'reproduce.m'),script);
native=sprintf(['%% 原题 MATLAB 设计语句；此文件需 Signal Processing Toolbox。\n' ...
    'Wc=0.4; n1=10; n2=4; n3=12;\n' ...
    'if exist(''butter'',''file'')~=2, error(''需要 Signal Processing Toolbox；无工具箱请运行 reproduce.m。''); end\n' ...
    '[b1,a1]=butter(n1,Wc); a2=1; a3=1;\n' ...
    'if exist(''remez'',''file'')==2\n' ...
    '    b2=remez(n2,[0 Wc-.04 Wc+.04 1],[1 1 0 0]);\n' ...
    '    b3=remez(n3,[0 Wc-.04 Wc+.04 1],[1 1 0 0]);\n' ...
    'else\n' ...
    '    b2=firpm(n2,[0 Wc-.04 Wc+.04 1],[1 1 0 0]);\n' ...
    '    b3=firpm(n3,[0 Wc-.04 Wc+.04 1],[1 1 0 0]);\n' ...
    'end\n' ...
    '%% 各版本设计网格不同，系数末位可不同；不要自行做 DC 归一化。\n']);
writeText(fullfile(folder,'original_design.m'),native);
end
function s=esc(s)
s=strrep(char(s),'&','&amp;'); s=strrep(s,'<','&lt;'); s=strrep(s,'>','&gt;'); s=strrep(s,'"','&quot;');
end
function writeText(path,text)
f=fopen(path,'w','n','UTF-8'); if f<0, error('fl_assignment_export:write','不能写入 %s',path); end
c=onCleanup(@()fclose(f)); fprintf(f,'%s',text);
end
