# Playback Helper

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

A generic desktop playback automation template, with a Swift implementation for macOS and a PowerShell implementation for Windows.

## Status

**No target application is configured.** Application identifiers and control labels have been removed and replaced by `CONFIGURE_*` placeholders. Normal startup and inspection stop before reading or clicking controls until every placeholder is configured in the source and the program is rebuilt as needed. This is not a ready-to-use playback tool.

Windows compatibility testing is incomplete. No precompiled Windows EXE is included. Installing PowerShell on macOS does not provide Windows UI Automation.

## Files

- `main.swift`, `run.sh`: macOS source and launcher.
- `cross-platform-release/windows/`: Windows script, launcher, optional EXE builder, and instructions.
- `cross-platform-release/source/windows/`: Windows source and build instructions.

## Development

Use `bash run.sh --help` on macOS. Use `Start.cmd -Help` on Windows. Help does not inspect or click application controls.

Configure the target application and verify its accessibility interface before enabling automation. Windows UI Automation requires Windows; macOS accessibility requires macOS. Runtime and chapter transition limits remain in the source.

Released under the standard [MIT License](LICENSE). Read the [Disclaimer](DISCLAIMER.md). Copyright (c) 2026 FengAnfu.
