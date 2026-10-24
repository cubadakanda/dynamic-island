@echo off
title Oceru Dynamic Island - Development Mode (Live Reload)
color 0B
cls
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev-watch.ps1"
pause
