@echo off
REM Comptario Local
REM Ana baslatici: Docker'i kontrol eder, uygulamayi baslatir ve tarayicida acar.
REM Yonetici izni gerektirmez. Veritabani, yedekler ve ayarlar korunur.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0comptario-local.ps1"
