@echo off
REM Comptario Local Ac
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-local-app.ps1"
