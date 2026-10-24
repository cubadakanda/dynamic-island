@echo off
title Oceru Dynamic Island Desktop
cd /d "%~dp0"
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0run-island.ps1"
