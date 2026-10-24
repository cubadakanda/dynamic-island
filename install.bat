@echo off
title Install Oceru Dynamic Island (Auto-Start on Boot)
color 0A
cls
echo ==============================================================
echo   Menginstall Oceru Dynamic Island Desktop...
echo ==============================================================
echo.

:: 1. Daftarkan ke Windows Registry Startup (HKCU - Standar Windows)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OceruIsland" /t REG_SZ /d "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%~dp0run-island.ps1\"" /f >nul

:: 2. Buat Shortcut di Startup & Desktop via scripts\install.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1" >nul 2>&1

echo [OK] Berhasil didaftarkan ke Windows Startup!
echo.
echo ==============================================================
echo   SUKSES! Oceru Dynamic Island Sudah Ter-install.
echo ==============================================================
echo.
echo Aplikasi sekarang akan OTOMATIS BERJALAN setiap kali kamu
echo menyalakan laptop Windows kamu!
echo.
echo Menjalankan Oceru Dynamic Island sekarang...
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0run-island.ps1"
echo.
echo Selesai! Tekan sembarang tombol untuk menutup jendela ini...
pause >nul
