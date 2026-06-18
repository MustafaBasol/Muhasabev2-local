@echo off
REM Comptario Local - Destek Menusu
REM Destek/yonetici kullanimi icindir (yedek, geri yukle, guncelle, durdur).
REM Gunluk musteri kullanimi icin DEGILDIR.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0comptario-local-support.ps1"
