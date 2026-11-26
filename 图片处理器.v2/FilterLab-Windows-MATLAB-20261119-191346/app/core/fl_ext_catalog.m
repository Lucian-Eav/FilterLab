function T=fl_ext_catalog(ids)
%FL_EXT_CATALOG Section 3 of the course brief, shared by GUI and reports.
Module=(1:4)';
Comparison={'直接、因果与零相位抽样；定向去摩尔纹';'因果与零相位去横线；背景归一化'; ...
    '不同方向的运动模糊；五档定向增强';'原图、密文、正确密钥与扰动密钥解密'};
Measures={'PSNR、SSIM、RGB 边缘位移和频谱峰衰减';'底纹衰减、背景标准差、对比度和笔画对称度'; ...
    '阶跃超调、梯度清晰度、边缘振铃、PSNR 和 SSIM';'加密 SSIM、能量和幅度谱误差、解密 PSNR、密钥敏感度'};
Theory={'奈奎斯特采样、混叠、零相位与定向滤波';'非对称可分离滤波、群时延与频带分离'; ...
    '方向滤波、阶跃响应与吉布斯振荡';'全通系统、幅相解耦与时间反转相位共轭'};
T=table(Module,Comparison,Measures,Theory);
T=T(ids,:);
end
