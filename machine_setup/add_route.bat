@echo off
chcp 65001 >nul
::-----------------------------------------
:: 管理者権限チェック（Mandatory Level）
::-----------------------------------------
for /f "tokens=3 delims=\ " %%i in ('whoami /groups ^| find "Mandatory"') do set LEVEL=%%i

if NOT "%LEVEL%"=="High" (
    echo 管理者権限で再実行します...
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
    exit /b
)

echo 管理者権限を確認しました。
echo.

::-----------------------------------------
:: ルート設定
::-----------------------------------------
echo Adding static route to 192.168.30.0/24 subnet via 192.168.80.6 ...
route add 192.168.30.0 mask 255.255.255.0 192.168.80.6 -p

echo.
echo Route added successfully.
pause
