# Playback Helper packages

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

**Unconfigured template.** All target application identifiers and control mappings must be configured in source before use. Help is available; normal startup and inspection stop before accessing controls while placeholders remain.

- [Windows instructions](windows/README.md) / [中文说明](windows/README.zh-CN.md)
- [Windows source and build](source/windows/BUILD.md)
- Windows package: `dist/playback-helper-windows.zip`

Windows compatibility testing is incomplete. No precompiled Windows EXE is included.

See [LICENSE](LICENSE) and [DISCLAIMER.md](DISCLAIMER.md).
