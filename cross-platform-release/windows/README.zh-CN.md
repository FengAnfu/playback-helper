# Playback Helper Windows 版

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

**当前为未配置模板，Windows 测试尚未完成。** 应用标识、窗口名称和控件匹配字符串已清除，`app/playback-helper.ps1` 使用 `CONFIGURE_*` 占位符。配置完成前，正常启动和 `-Inspect` 都会在读取或点击控件前退出。目前不能直接自动播放。

## 环境与帮助

需要 Windows 10/11 x64、自带的 Windows PowerShell 5.1 和 .NET Framework。Mac 或 Linux 上安装 PowerShell 不能提供 Windows UI Automation。在 Windows 上运行 `Start.cmd -Help` 查看帮助。

开发者需先配置并验证应用进程名、窗口名称和控件名称，再运行 `Start.cmd -Inspect`。检查输出可能包含个人页面信息，分享前请清理。

## 可选 EXE

包中未附带预编译 EXE。可用 `Build-Exe.cmd` 生成 `Playback-Helper.exe`；它内嵌脚本，修改脚本后需重新构建。Windows 编译和运行结果尚未验证。程序文件未签名。

完成配置后，控制台按键为 `p` 暂停自动操作、`r` 恢复、`q` 退出。停止自动操作不会暂停已播放的视频。

源码及构建说明：https://github.com/FengAnfu/playback-helper/tree/main/cross-platform-release/source/windows

适用标准 [MIT 许可证](../LICENSE)和英文[免责声明](../DISCLAIMER.md)。
