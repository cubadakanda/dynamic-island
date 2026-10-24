@echo off
title Hentikan Oceru Dynamic Island
color 0E
cls
echo ==============================================================
echo   Menghentikan Oceru Dynamic Island Desktop...
echo ==============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$pidFile = Join-Path '%~dp0' '.oceru.pid';" ^
  "if (Test-Path $pidFile) {" ^
  "  $targetPid = Get-Content $pidFile -ErrorAction SilentlyContinue;" ^
  "  if ($targetPid) { Stop-Process -Id $targetPid -Force -ErrorAction SilentlyContinue; }" ^
  "  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue;" ^
  "}" ^
  "$pidOld = Join-Path '%~dp0' '.island.pid';" ^
  "if (Test-Path $pidOld) {" ^
  "  $targetPid2 = Get-Content $pidOld -ErrorAction SilentlyContinue;" ^
  "  if ($targetPid2) { Stop-Process -Id $targetPid2 -Force -ErrorAction SilentlyContinue; }" ^
  "  Remove-Item $pidOld -Force -ErrorAction SilentlyContinue;" ^
  "}" ^
  "Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like '*Oceru*' -or $_.MainWindowTitle -like '*Dynamic Island*' } | Stop-Process -Force -ErrorAction SilentlyContinue;"

echo [OK] Oceru Dynamic Island berhasil dihentikan / ditutup.
echo.
echo Kamu bisa menjalankannya kembali kapan saja dengan klik:
echo   'run-island.bat' atau melalui icon di Desktop.
echo.
timeout /t 2 >nul
