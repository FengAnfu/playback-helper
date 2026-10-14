# Playback Helper（播放辅助模板）

## 使用前必须替换标识符

**用户必须先替换目标应用标识符和控件名称，才能使用本模板。** `CONFIGURE_*` 全部是占位符，不是可直接运行的默认值。请填写你实际使用的目标应用所暴露的值，不要照抄其他应用的名称。

| 平台 | 需要修改的文件 | 需要替换的内容 |
| --- | --- | --- |
| macOS 源码启动 | 仓库根目录 `main.swift` | `bundleID` 和七个 `*Label` 常量 |
| macOS 打包程序（如有） | `cross-platform-release/source/macos/main.swift` | `bundleID` 和七个 `*Label` 常量，修改后重新构建 |
| Windows 启动 | 发布文件夹中的 `windows/app/playback-helper.ps1` | `$ProcessNames`、`$TitleHint` 和全部七个 `$Label*` 变量 |

1. **应用标识：** macOS 填写目标应用的真实 Bundle ID；Windows 填写不带 `.exe` 的进程名，以及窗口标题中可识别的文字。
2. **控件名称：** 替换页面、播放器、章节信息、播放、暂停、重播、下一项对应的七个标签。名称必须来自目标应用的辅助功能接口；控件类型和页面结构也必须与代码匹配，只改名称不保证能运行。
3. **同步源码：** 如果修改 Windows 的 `source/windows/` 源码，请同步复制到 `windows/app/playback-helper.ps1`，保留 UTF-8 BOM 编码。
4. **重新构建：** macOS 根目录的 `run.sh` 会按源码变化重新编译；打包 App 需在 `source/macos/` 依次运行 `build.sh`、`build-app.sh`。Windows EXE 内嵌脚本，修改后需重新运行 `Build-Exe.cmd`。
5. **先检查再使用：** 替换完所有必填占位符后，在 macOS 使用 `--inspect`，在 Windows 使用 `-Inspect`。此模式只读取控件，不点击；确认识别结果正确后再尝试正常运行。

只要还有必填 `CONFIGURE_*` 占位符，程序就会在操作界面前退出。Windows 的识别测试必须在 Windows 系统中完成。

[English](README.md) | [简体中文](README.zh-CN.md)

提供 macOS Swift 与 Windows PowerShell 实现的通用桌面播放辅助模板。

## 当前状态

**尚未配置目标应用。** 应用标识和控件名称已清除，源码使用 `CONFIGURE_*` 占位符。配置完成并按需重新编译前，正常启动和检查模式都会在读取、点击控件之前退出。本项目目前不能直接用于自动播放。

Windows 兼容性测试尚未完成，未附带预编译 EXE。Mac 上安装 PowerShell 不会提供 Windows 的界面接口。

## 开发与使用

- macOS 源码和启动脚本：`main.swift`、`run.sh`。运行 `bash run.sh --help` 查看帮助。
- Windows 启动文件：`cross-platform-release/windows/`。在 Windows 上运行 `Start.cmd -Help` 查看帮助。
- Windows 源码：`cross-platform-release/source/windows/`。

开发者需要自行配置并验证目标应用标识、窗口和控件名称；配置检查通过后才能进行界面测试。帮助命令不会读取或点击控件。

本项目采用标准 [MIT 许可证](LICENSE)，英文[免责声明](DISCLAIMER.md)不改变许可证条款。
