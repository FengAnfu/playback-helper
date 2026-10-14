@echo off
rem Builds Playback-Helper.exe next to this file (UNVERIFIED build script).
rem Uses only the C# compiler included with .NET Framework 4.x on Windows 10/11;
rem nothing is downloaded or installed. The helper script app\playback-helper.ps1
rem is embedded in the .exe, so the .exe can be copied and run on its own.
setlocal
set "HERE=%~dp0"
set "SRC=%HERE%build-exe\PlaybackHelperLauncher.cs"
set "PS1=%HERE%app\playback-helper.ps1"
set "OUT=%HERE%Playback-Helper.exe"

set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo ERROR: The .NET Framework 4 C# compiler, csc.exe, was not found.
  echo Expected under "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319".
  echo You can still use Start.cmd, which needs no build step.
  goto :done
)
if not exist "%SRC%" (
  echo ERROR: Missing source file "%SRC%". Re-extract the complete windows folder.
  goto :done
)
if not exist "%PS1%" (
  echo ERROR: Missing helper script "%PS1%". Re-extract the complete windows folder.
  goto :done
)

echo Building "%OUT%" ...
"%CSC%" /nologo /target:exe /platform:x64 /optimize+ /out:"%OUT%" /resource:"%PS1%",playback-helper.ps1 "%SRC%"
if errorlevel 1 (
  echo.
  echo ERROR: The build failed. Read the compiler messages above.
  goto :done
)
echo.
echo Done. Double-click Playback-Helper.exe to start the helper.
echo Windows SmartScreen may warn on first run because the .exe is not code-signed.

:done
echo.
pause
