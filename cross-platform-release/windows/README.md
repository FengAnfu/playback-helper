# Playback Helper for Windows

## Before use: replace the identifiers

**You must replace the target identifiers and control labels before using this template.** All `CONFIGURE_*` values are placeholders, not working defaults. Obtain the real values from your own target application; do not copy example values from another application.

| Platform | File to edit | Identifiers to replace |
| --- | --- | --- |
| macOS source launcher | `main.swift` at the repository root | `bundleID` and the seven `*Label` constants |
| macOS packaged app, if present | `cross-platform-release/source/macos/main.swift` | `bundleID` and the seven `*Label` constants, then rebuild |
| Windows launcher | `windows/app/playback-helper.ps1` inside the release folder | `$ProcessNames`, `$TitleHint`, and all seven `$Label*` variables |

- **Application identity:** use the actual macOS bundle identifier or Windows executable process name (without `.exe`). For Windows, also set the window-title fragment.
- **Control labels:** replace the page, player, chapter-details, Play, Pause, Replay, and Next labels with values actually exposed by your application's accessibility interface. Labels must match the expected control types and structure in the source; changing names alone does not guarantee compatibility.
- **Keep copies synchronized:** if you edit the Windows source under `source/windows/`, copy it to `windows/app/playback-helper.ps1` and preserve UTF-8 with BOM.
- **Rebuild:** the macOS root launcher recompiles changed source. For the packaged macOS app, run `build.sh` then `build-app.sh` under `source/macos/`. Rebuild a Windows EXE with `Build-Exe.cmd` whenever its embedded script changes.
- **Verify first:** after every required placeholder is replaced, run `--inspect` on macOS or `-Inspect` on Windows. Inspect mode reads controls without clicking. Review the output before trying normal operation.

The program exits without operating the UI while any required `CONFIGURE_*` placeholder remains. Windows inspection requires Windows; PowerShell on a Mac cannot provide it.

[English](README.md) | [简体中文](README.zh-CN.md)

**Unconfigured template. Windows testing is incomplete.** No application is selected. The target process name, window title, and control labels in `app/playback-helper.ps1` use `CONFIGURE_*` placeholders. Normal operation and `-Inspect` stop before accessing controls until these are configured. No successful compatibility or playback results are claimed.

## Environment and help

Requires Windows 10/11 x64 with Windows PowerShell 5.1 and .NET Framework. PowerShell on macOS or Linux cannot provide Windows UI Automation. On Windows, run `Start.cmd -Help` to view options.

After configuring and verifying the target interface, use `Start.cmd -Inspect` before normal operation. Inspection output may contain private page text; review it before sharing.

## Optional EXE

No precompiled EXE is included. `Build-Exe.cmd` uses the .NET Framework C# compiler to build `Playback-Helper.exe` from `build-exe/PlaybackHelperLauncher.cs`, embedding `app/playback-helper.ps1`. Rebuild after changing the script. Windows compilation and operation remain unverified. The launcher stores its embedded script under `%LOCALAPPDATA%\PlaybackHelper\`.

The files are unsigned. The launcher's execution-policy setting applies only to its PowerShell process; organizational policy remains in effect.

Once configured, console keys are `p` (pause automation), `r` (resume), and `q` (quit). Stopping automation does not pause an already playing video.

Source and build instructions: https://github.com/FengAnfu/playback-helper/tree/main/cross-platform-release/source/windows

See the [MIT License](../LICENSE) and [Disclaimer](../DISCLAIMER.md).
