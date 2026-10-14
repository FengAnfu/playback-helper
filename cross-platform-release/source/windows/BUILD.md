# Windows source and reproducible build

`playback-helper.ps1` is the complete source. It runs as-is on Windows PowerShell 5.1 (built into Windows 10/11), so there is no compile step.

## Reproduce the package

1. Copy `playback-helper.ps1` to `windows/app/playback-helper.ps1`. Keep the encoding **UTF-8 with BOM**. Windows PowerShell 5.1 misreads the Chinese interface labels in UTF-8 files without a BOM.
2. Keep `windows/Start.cmd` as ASCII with CRLF line endings.

## Recommended first verification on Windows

```bat
powershell -NoProfile -Command "$e = $null; $null = [System.Management.Automation.Language.Parser]::ParseFile('app\playback-helper.ps1', [ref]$null, [ref]$e); $e"
Start.cmd -Help
Start.cmd -Inspect
```

Use the `-Inspect` output to confirm or correct the labels and process names at the top of the script. Then record which mappings were verified in `windows/README.md`.

## One-step .exe

`launcher/PlaybackHelperLauncher.cs` is a small C# 5 console program. It is identical to `windows/build-exe/PlaybackHelperLauncher.cs`. It embeds the script as a resource and runs it with the built-in Windows PowerShell. Build it on Windows with `windows/Build-Exe.cmd`, which runs:

```bat
%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:exe /platform:x64 /optimize+ ^
  /out:Playback-Helper.exe /resource:app\playback-helper.ps1,playback-helper.ps1 build-exe\PlaybackHelperLauncher.cs
```

The source has **not been compiled**, because no Windows or C# compiler was available when it was written. Report any compiler errors with the full output.
