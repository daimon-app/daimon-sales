@echo off
cd /d "%~dp0"
start "AI5 HUB Server" /min powershell -NoProfile -ExecutionPolicy Bypass -File ".\start.ps1"
timeout /t 2 /nobreak >nul
start "" "http://127.0.0.1:43125/"
