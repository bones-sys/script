@echo off
chcp 65001 >nul
setlocal

REM --- (1) 管理者権限で実行されているか確認 ---
for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
    exit
)

REM --- (2) このバッチファイルがあるフォルダに移動 ---
cd /d "%~dp0"
echo [INFO] 現在の作業ディレクトリ: %cd%

REM --- (3) madVR があればアンインストール ---
if exist "C:\madVR\uninstall.bat" (
    echo [INFO] 既存の madVR をアンインストールします...
    call "C:\madVR\uninstall.bat"
)

REM --- (4) フォルダを削除 ---
if exist "C:\madVR" (
    echo [INFO] 既存の "C:\madVR" フォルダを削除します...
    rd /s /q "C:\madVR"
)

REM --- (5) PotPlayer 用レジストリのインポート ---
if exist "%USERPROFILE%\PotPlayerMini64.reg" (
    echo [INFO] PotPlayerMini64.reg をインポートします...
    reg import "%USERPROFILE%\PotPlayerMini64.reg"
) else (
    echo [WARN] %USERPROFILE%\PotPlayerMini64.reg が見つからないためスキップします...
    echo [ERROR] %USERPROFILE%\PotPlayerMini64.reg が見つかりませんでした。ファイル構成を確認してください。
    pause
    exit /b 1
)

echo.
echo [INFO] すべての処理が完了しました。
pause
exit /b 0
