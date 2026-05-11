@echo off
setlocal
set SCRIPT_DIR=%~dp0
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "$p=Join-Path '%SCRIPT_DIR%' 'event_viewer_export.ps1'; $s=Get-Content -LiteralPath $p -Raw -Encoding UTF8; & ([scriptblock]::Create($s))"
if errorlevel 1 (
  echo.
  echo Failed to export Event Viewer image.
  pause
  exit /b 1
)
echo.
echo Export completed.
pause
