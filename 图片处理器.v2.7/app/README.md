# FilterLab 照片与滤波工作室

基于 MATLAB 的统一照片编辑与滤波实验软件。同一个窗口包含“照片与创意编辑”“题目滤波实验”“扩展应用实验”和“频域实用工坊”四个工作区，覆盖自然 RGB 照片处理、原题六问、信号与系统扩展实验及日常频域工具。切换工作区保留照片参数和历史。

## 启动

MATLAB 当前文件夹切换到本目录，运行：

```matlab
FL_gui
% 等价入口：FL_photo 或 FL_main
FL_photo('File', 'my_photo.jpg')  % 直接打开照片
```

兼容目标为 MATLAB R2020b+，实际验证环境为 **R2025b Update 1**。核心处理不依赖 Image Processing Toolbox 或 Signal Processing Toolbox；六问实验的备用设计来源会明确标注。

## Windows EXE 封装

[分发使用说明](deploy/使用说明.md)介绍 `dist` 中的 Windows x64 启动封装包。完整解压后双击 `FilterLab.exe`，无需手动打开 MATLAB 编辑器或输入命令；EXE 必须与 `app` 文件夹一起保留。此版本仍需要本机已安装 MATLAB，仅有 MATLAB Runtime 不够。

构建机尚未安装 MATLAB Compiler，因此未生成免 MATLAB 的独立编译版。[build_launcher.py](deploy/build_launcher.py)可重建启动封装；[build_standalone.m](deploy/build_standalone.m)为安装 Compiler 后的独立版构建入口。Python 仅用于构建和验证，运行封装包不需要 Python。

## 照片与创意编辑

导入照片后，在右侧下拉菜单选择工具。先调整构图、色彩、去噪与锐化，再按需要开启创意效果。所有创意模块默认关闭。

| 工具 | 功能 |
| --- | --- |
| 色彩、去噪、锐化 | 线性光曝光与白平衡、保边亮度/色彩去噪、自动估噪联动、三尺度细节和光晕抑制 |
| 构图 | 自由/固定比例裁剪、90°旋转、水平/垂直翻转 |
| 频域画笔 | 在亮度频谱上抑制或恢复频率，自动配对共轭频率，可保护平均亮度 |
| 微缩景观 | 拖动定位清晰带，调节角度、宽度、过渡与背景模糊 |
| 长曝光与运动 | 方向、变焦、旋转拖影，可定位运动中心 |
| 局部蒙版 | 涂抹、擦除、羽化、反选；控制仅创意效果或全部照片调整 |
| 照片滤波 | 将题目三种滤波器用于照片亮度，采用保持直流亮度的双向处理 |

新工具的具体操作、蒙版与预设规则见 [创意工具说明](docs/创意工具说明.md)。

处理前、处理后和分割对比使用相同构图。100% 模式查看完整像素，可拖动、滚轮或使用方向按钮平移。频谱、红色蒙版和残差是检查视图；**导出始终保存正常 RGB 照片**，尺寸跟随裁剪和旋转，不包含界面标记。

导入支持 JPEG、PNG、TIFF、BMP；保留 RGB，灰度扩为三通道，纠正 EXIF/TIFF 方向，透明区域合成到白色。导出使用新文件名，原照片和已有目标均受覆盖保护。

## 基础调整与历史

默认亮度去噪 0.25、色彩去噪 0.35、细节保留 0.65、锐化强度 0.35；自动白平衡关闭。冷暖向右变暖，色调向右偏洋红。自动白平衡仅使用中间亮度、低色度区域，没有足够中性参照时保留原色。

“自动估噪并联动锐化阈值”根据原分辨率较平坦区域设置去噪强度和阈值，启用后暂时禁用手动去噪强度。估计可信度不是统计置信区间，纹理、JPEG 压缩与非均匀噪声会影响结果。

锐化中的细小纹理、结构清晰度、局部对比度对应保边尺度 2/6/18；正值增强、负值减弱，默认均为 0。建议从 0.1～0.3 开始。光晕抑制默认 0.75，越高越限制边缘越界。“去噪残差”和“细节增量”进入 100% 显示有符号亮度差，中灰表示无变化，以 4 倍差值显示。

裁剪支持自由、当前比例、1:1、4:3、3:2、16:9 及对应竖幅。拖动框内移动、角点缩放、框外建框；也可输入完整分辨率像素坐标。Enter 应用、Esc 取消。整数像素会带来最多约一像素的比例舍入误差。没有任意角度拉直。

参数、构图和每次画笔提交共用最多 50 步撤销/重做，快捷键为 Ctrl+Z、Ctrl+Y / Ctrl+Shift+Z。撤销后新编辑会清空重做分支；检查视图和导出不增加历史。“恢复完整构图”保留处理设置，“重置全部”恢复所有默认状态，二者都可撤销。打开新照片或关闭窗口后不保留历史。

保存/载入参数支持基础及创意设置、频域笔触；不携带裁剪、旋转、照片专属空间蒙版或历史。载入预设保留当前空间蒙版，旧预设自动补齐新默认值。原图始终保留，各次编辑从原图和参数重新计算。

## 直接完成题目六问

点击顶部“题目滤波实验”或右上角“题目实验 →”，再点“运行六问并导出”。软件读取给定 x/xn，固定原题参数，输出频响、相位、阶跃超调、原图/含噪图因果行列滤波、形状和延迟分析。实验不会修改照片编辑状态。

```matlab
FL_assignment_gui                   % 单独打开实验窗口
R = FL_assignment;                  % 无界面计算并导出报告
R = FL_assignment('Export', false);  % 只计算
```

报告包含 HTML、六图、结论、完整数组与复现脚本，保存到新的 `output/assignment-*`。原题使用原始系数、零初态和因果滤波；照片“滤波”页的直流归一化与双向处理不会影响原题。完整说明见 [题目实验说明](docs/题目实验说明.md)。

## 信号与系统扩展应用（四大模块）

在主界面顶部选择「扩展应用实验」，或运行 `FL_extensions_gui` 打开独立窗口，可完成摩尔纹与抗混叠、作业纸去横线去阴影、方向性运动去模糊、全通相位置乱与解密四项实验。运行 `R = FL_extensions()` 可计算并导出统一报告，`fl_ext_selftest` 可自动验收。参数、输入照片和复现步骤见[扩展应用说明](docs/扩展应用说明.md)。

## 频域实用工坊（四大工具）

主界面顶部「频域实用工坊」按需加载连拍对齐堆栈、自动挑最清晰照片、频域隐形水印和物理光学星芒/散景。四页均提供确定性样例，核心算法仅依赖 MATLAB 基础函数。独立窗口使用 `FL_freqtools_gui` 或 `FL_main('freqtools')`。

```matlab
R = FL_freqtools('burst');
R = FL_freqtools('sharpness','D:\照片\连拍');
R = FL_freqtools('watermark','Text','FILTERLAB','SaveTo','signed.png');
R = FL_main('freqtools-run','optics','Aperture','pent5');
assert(fl_ft_selftest(true));
```

默认处理最长边 512 px，可用 `MaxEdge` 调整，导出跟随处理及公共裁剪后的尺寸。详细参数、共享 GUI 接口和数值验收记录见[频域实用工坊说明](docs/频域实用工坊说明.md)。

## 命令行

```matlab
R = FL_process('my_photo.jpg', 'my_photo_edited.png');
R = FL_process('my_photo.jpg', 'my_photo_detail.jpg', ...
    'AutoNoise', true, 'FineDetail', 0.2, 'Clarity', 0.2, ...
    'LocalContrast', 0.1, 'HaloSuppression', 0.8);
R = FL_process('my_photo.jpg', '', 'Exposure', 0.2); % 只处理，不保存

% 完整创意流水线，输入 single/double RGB [0,1]。
addpath('core');
[X, meta] = fl_photo_load('my_photo.jpg');
S = fl_photo_spec();
C = fl_creative_spec(struct('TiltEnable', true, 'TiltBlur', 18));
Y = fl_photo_pipeline(X, S, C);
fl_photo_save('my_photo_16bit.png', Y, meta, 'BitDepth', 16);
```

`FL_process` 接受基础照片参数；完整创意设置使用 `fl_photo_pipeline`。参数范围见 `help fl_photo_spec` 和 `help fl_creative_spec`。

## 范围与预览

输入/输出以 sRGB 解释，不执行 ICC 转换、RAW 显影或深度学习去噪。Display P3、Adobe RGB、CMYK、RAW 应先转换为 sRGB。PNG/TIFF 支持 16 位读写；GUI 导出为 8 位，16 位使用命令行。输出不复制 EXIF/GPS/ICC，多页 TIFF 仅读第一页。

一般适应窗口模式先缩图再处理，细节可能与最终结果略有差别；自动估噪、频域滤波和照片适配滤波开启时，先处理完整图像再缩小显示。100% 和导出始终使用完整分辨率。长运动轨迹采用有限采样，可能出现重复轮廓；频域强抑制可能振铃。效果强度和最终细节应在 100% 检查。

## 代码与验证

GUI 状态与交互集中在 [FL_photo.m](FL_photo.m)，处理从 [fl_photo_pipeline.m](core/fl_photo_pipeline.m) 进入，基础调整与创意算法分别位于 [fl_photo_process.m](core/fl_photo_process.m)、[fl_creative_process.m](core/fl_creative_process.m)。蒙版、频域、几何和读写各有独立核心函数。原题计算与报告由 `core/fl_assignment_*.m` 提供，嵌入式与独立实验界面共用 [FL_assignment_gui.m](FL_assignment_gui.m)。

```matlab
addpath('tests');
validate_photo_release   % 193 项统一验证，生成新产物目录
run_tests                % 6 项旧版滤波核自检
% 按需运行单项：run_tests_photo / run_tests_photo_gui / run_tests_photo_edit
% run_tests_photo_gestures / run_tests_photo_upgrade / run_tests_assignment
% run_tests_creative / run_tests_creative_gui
```

本次实际验证结果、代码整理内容和边界见 [验证记录](docs/照片版验证记录.md)。真实照片无干净真值，因此不显示虚假的无参考 PSNR/SSIM 评分。

## 旧实验入口

`FL_lab_gui` 或 `FL_main('lab')` 保留旧信号滤波实验。`FL_main('demo')`、`FL_main('file','my.png')`、`FL_demo`、`FL_innov` 保持可用；旧 file 命令是灰度实验。旧说明 [用户手册](docs/用户手册.md) 和 [调参指南](docs/调参指南.md) 中的阶数、截止频率、加噪等操作只适用于旧实验模式。
