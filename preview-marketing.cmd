@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0marketing\lp\preview-server.ps1"
endlocal
