@echo off
chcp 65001 >nul

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

set VER=1.0.0
title Install action-menu-item Ver %VER%

echo --------------------------------------------
echo CEPの開発者モードを許可しています...
echo --------------------------------------------


rem After Effects 2023 / Photoshop 2023
reg add HKEY_CURRENT_USER\Software\Adobe\CSXS.11 /v PlayerDebugMode /t REG_SZ /d 1 /f

rem After Effects 2024 / Photoshop 2024
reg add HKEY_CURRENT_USER\Software\Adobe\CSXS.12 /v PlayerDebugMode /t REG_SZ /d 1 /f

rem After Effects 2025 / Photoshop 2025
reg add HKEY_CURRENT_USER\Software\Adobe\CSXS.13 /v PlayerDebugMode /t REG_SZ /d 1 /f

echo.
echo.
echo バッチを終了します

timeout /t 1 /nobreak >nul