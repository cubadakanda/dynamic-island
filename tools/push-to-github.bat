@echo off
title Push Dynamic Island to GitHub
color 0B
cls
cd /d "%~dp0.."
echo ==============================================================
echo   Push Dynamic Island Repository ke GitHub
echo ==============================================================
echo.
echo Pastikan kamu sudah membuat repository baru di:
echo https://github.com/new
echo.
set /p REPO_URL="Masukkan URL Repository GitHub (contoh: https://github.com/cubadakanda/dynamic-island.git): "

if "%REPO_URL%"=="" (
    echo.
    echo [ERROR] URL tidak boleh kosong!
    pause
    exit /b 1
)

echo.
echo Menghubungkan remote origin ke: %REPO_URL%...
git remote remove origin >nul 2>&1
git remote add origin %REPO_URL%
git branch -M main

echo Melakukan push ke GitHub...
git push -u origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ==============================================================
    echo   SUKSES! Repository berhasil di-push ke GitHub!
    echo ==============================================================
) else (
    echo.
    echo [GAGAL] Terjadi kendala saat push. Pastikan kamu sudah login ke GitHub.
)

echo.
pause
