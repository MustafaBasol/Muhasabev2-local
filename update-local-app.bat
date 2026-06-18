@echo off
REM Comptario Local Guncelle
REM Yeni bir surum kopyalandiktan sonra uygulamayi guvenle yeniden insa edip baslatir.
REM Musteri verileri (veritabani, yedekler, ayarlar) korunur.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-local-app.ps1"
