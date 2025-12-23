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
:: ルート削除
::-----------------------------------------
echo Deleting static route to 192.168.30.44 ...
route delete 192.168.30.44

echo.
echo Route deleted successfully.
pause
