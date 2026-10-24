@echo off
title Uninstall Oceru Dynamic Island (Disable Auto-Start)
color 0C
cls
echo ==============================================================
echo   Mencopot Oceru Dynamic Island dari Windows Startup...
echo ==============================================================
echo.

:: 1. Hapus dari Windows Registry Startup
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OceruIsland" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "DynamicIsland" /f >nul 2>&1

:: 2. Hapus Shortcut dari Startup & Desktop serta hentikan aplikasi
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$s = Join-Path ([Environment]::GetFolderPath('Startup')) 'OceruIsland.lnk'; if (Test-Path $s) { Remove-Item $s -Force };" ^
  "$sOld = Join-Path ([Environment]::GetFolderPath('Startup')) 'DynamicIsland.lnk'; if (Test-Path $sOld) { Remove-Item $sOld -Force };" ^
  "$d = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Oceru Dynamic Island.lnk'; if (Test-Path $d) { Remove-Item $d -Force };" ^
  "$dOld = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Dynamic Island.lnk'; if (Test-Path $dOld) { Remove-Item $dOld -Force };" ^
  "$pidFile = Join-Path '%~dp0' '.oceru.pid';" ^
  "if (Test-Path $pidFile) {" ^
  "  $pId = Get-Content $pidFile -ErrorAction SilentlyContinue;" ^
  "  if ($pId) { Stop-Process -Id $pId -Force -ErrorAction SilentlyContinue; }" ^
  "  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue;" ^
  "}" ^
  "$pidOld = Join-Path '%~dp0' '.island.pid';" ^
  "if (Test-Path $pidOld) {" ^
  "  $pId2 = Get-Content $pidOld -ErrorAction SilentlyContinue;" ^
  "  if ($pId2) { Stop-Process -Id $pId2 -Force -ErrorAction SilentlyContinue; }" ^
  "  Remove-Item $pidOld -Force -ErrorAction SilentlyContinue;" ^
  "}" ^
  "Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like '*Oceru*' -or $_.MainWindowTitle -like '*Dynamic Island*' } | Stop-Process -Force -ErrorAction SilentlyContinue;" >nul 2>&1

echo [OK] Oceru Dynamic Island berhasil dicopot dari Windows Startup.
echo.
echo ==============================================================
echo   SELESAI.
echo ==============================================================
echo.
echo Aplikasi tidak akan otomatis berjalan lagi saat laptop menyala.
echo.
echo Tekan sembarang tombol untuk keluar...
pause >nul
