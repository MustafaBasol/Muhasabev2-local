@echo off
REM Comptario Local Baslat
REM Bu dosya, PowerShell betigini yonetici izni gerektirmeden calistirir.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-local-app.ps1"
