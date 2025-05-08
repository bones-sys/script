@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

REM ユーザーフォルダのパスを設定
set TARGET_DIR=%USERPROFILE%\AppData\Roaming\Shotgun

echo --------------------------------------------
REM 存在確認と削除処理
if exist "%TARGET_DIR%" (
    echo フォルダを削除しています: "%TARGET_DIR%"
    rmdir /s /q "%TARGET_DIR%"
    echo 削除が完了しました。
) else (
    echo フォルダは存在しません: "%TARGET_DIR%"
)

REG DELETE "HKCU\Software\Shotgun Software\tk-desktop" /f
echo Shotgun Software\tk-desktop レジストリを削除しました。
echo --------------------------------------------
echo.
echo.

timeout /t 2 /nobreak >nul
