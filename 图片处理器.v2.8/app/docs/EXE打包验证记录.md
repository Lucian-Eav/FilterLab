# Windows EXE 打包验证记录

> **旧版记录：20261119-130731 已被替代。** 下述历史测试只通过路径 API 读写文件，未覆盖系统文件选择框。用户实测发现其 `-batch` 启动参数会禁止阻塞式对话框。本次启动器已改为 `-nodesktop -r` 交互会话，并补充真实原生对话框验证；新版包的验证结果以相邻的 `.validation.json` 为准，不应继续分发旧版 ZIP。

验证日期：2026-11-19。交付的是依赖已安装 MATLAB 的 Windows x64 启动封装版。

## 交付产物

- [最终 ZIP](../dist/FilterLab-Windows-MATLAB-20261119-130731.zip)，183,007 字节。
- [机器验证结果](../dist/FilterLab-Windows-MATLAB-20261119-130731.validation.json)。
- [使用说明](../deploy/使用说明.md)。ZIP 内也包含相同说明。
- ZIP SHA-256：`569f6f08db028cba1620024f183c839d1614cef07e0b2793793bf89619549774`。

请使用上述最终包；dist 中更早时间的包是排障构建，不作为交付版本。

## 实际验证

环境：Windows x64，MATLAB 25.2.0.3042426（R2025b Update 1）。R2020b+ 是源码兼容目标，本次未逐版本验证。

将最终 ZIP 解压到原项目之外的普通用户目录；路径同时含中文、空格和英文单引号。校验清单中的 61 个文件均匹配，随后实际运行包中的 EXE，而非直接调用项目源代码代替。

1. EXE 自检退出码为 0：创建应用窗口，调整曝光、细节和移轴效果，按完整尺寸导出合成照片，检查撤销/重做。
2. 从包内 samples/plus.mat 加载题目数据，在同一窗口执行六问，报告写入默认用户输出目录；未依赖项目旁的原始题目文件夹。
3. 可见界面启动测试退出码为 0：启动进度、就绪标记、工作室界面和正常关闭均通过；测试只关闭自己创建的窗口。
4. portable.flag 便携模式通过。窗口截图已人工查看。
5. 打包路径修改后的完整源码回归为 193 项通过，旧版回归 6 项通过。详见[本次回归日志](../output/photo-validation-20261119-130456/validation.txt)。静态检查仍有非阻断的格式、清理与兼容性建议，不宣称零警告。

自检和界面测试详细输出保留在构建机 `%LOCALAPPDATA%/FilterLab/package-validation/exe-validation-20261119-130757`。机器验证结果已另存至项目 dist，供核对交付包。

## 启动与部署边界

完整解压后运行包内 FilterLab.exe，必须保留旁边的 app 文件夹。无需 Python，也不需要从 MATLAB 编辑器手动运行函数；但仍需要本机已安装 MATLAB，仅安装 MATLAB Runtime 不够。

构建工作区的 Windows 低完整性标签会限制该目录中 EXE 创建的子进程。启动器现在会识别并提示这种情况；验证采用普通用户目录中的解压副本，没有更改系统权限或关闭安全功能。推荐解压至 `%LOCALAPPDATA%/FilterLab/Studio` 等普通用户可写目录。

默认报告与日志写入 `%LOCALAPPDATA%/FilterLab`；便携模式使用 EXE 旁的 userdata。包内不包含个人照片、开发测试输出或 MATLAB 私有运行库。

## 独立编译版尚缺的条件

当前 MATLAB 安装中没有 mcc、compiler.build.standaloneApplication 或 Compiler 打包 API。许可证查询返回可用不能证明 Compiler 产品已安装，因此本次没有生成仅依赖免费 Runtime 的独立编译版。

[独立版构建脚本](../deploy/build_standalone.m)已经提供，缺少 Compiler 时明确报错；该错误分支已测试。取得并安装合法授权、同版本 MATLAB Compiler 后可执行构建，再在匹配 Runtime 的目标机验证。独立编译分支尚未实际执行，不计入本次通过项。

[启动器构建脚本](../deploy/build_launcher.py)和[EXE 验证脚本](../tests/validate_exe_package.py)保留在项目中用于复现。排障期间的一次性探针已移除。
