@echo off
setlocal
set SCRIPT_DIR=%~dp0
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -File "%SCRIPT_DIR%event_viewer_export.ps1"
if errorlevel 1 (
  echo.
  echo Failed to export Event Viewer image.
  pause
  exit /b 1
)
echo.
echo Export completed.
pause
