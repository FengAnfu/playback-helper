@echo off
rem Double-click launcher for the Playback Helper Windows helper (UNVERIFIED build).
rem Resolves files relative to this file, so the folder can live anywhere,
rem including paths with spaces or non-English characters.
setlocal
chcp 65001 >nul
set "HERE=%~dp0"
set "SCRIPT=%HERE%app\playback-helper.ps1"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%SCRIPT%" (
  echo ERROR: The helper script was not found:
  echo   "%SCRIPT%"
  echo Re-extract the complete windows folder and try again.
  goto :fail
)
if not exist "%PS%" (
  echo ERROR: Windows PowerShell 5.1 was not found at "%PS%".
  echo It is included with Windows 10 and 11. Check that it has not been removed or blocked.
  goto :fail
)

rem -ExecutionPolicy Bypass applies only to this one PowerShell process; it does
rem not change any system or user setting. See README.md.
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
set "CODE=%ERRORLEVEL%"
echo.
if not "%CODE%"=="0" echo The helper exited with an error (code %CODE%). Read the messages above.
pause
exit /b %CODE%

:fail
echo.
pause
exit /b 1
