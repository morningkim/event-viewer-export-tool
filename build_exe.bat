@echo off
setlocal
set ROOT=%~dp0
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
  echo C# compiler not found.
  exit /b 1
)
if not exist "%ROOT%dist" mkdir "%ROOT%dist"
"%CSC%" /nologo /target:winexe /out:"%ROOT%dist\EventViewerImageExport.exe" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll "%ROOT%src\EventViewerImageExport.cs"
if errorlevel 1 exit /b 1
copy /Y "%ROOT%dist\EventViewerImageExport.exe" "%ROOT%EventViewerImageExport.exe" >nul
