@echo off
setlocal

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

REM --- (2) このバッチファイルがあるフォルダに移動 ---
cd /d "%~dp0"
echo [INFO] 現在の作業ディレクトリ: %cd%

REM --- (3) 旧バージョンの madVR があればアンインストール ---
if exist "C:\Program Files\madVR\uninstall.bat" (
    echo [INFO] 既存の madVR をアンインストールします...
    pushd "C:\Program Files\madVR"
    call uninstall.bat
    popd
)

REM --- (4) 旧バージョンのフォルダを削除 ---
if exist "C:\Program Files\madVR" (
    echo [INFO] 既存の "C:\Program Files\madVR" フォルダを削除します...
    rd /s /q "C:\Program Files\madVR"
)

REM --- (5) 新しい madVR フォルダがあるか確認 ---
if not exist "madVR\" (
    echo [ERROR] "madVR" フォルダが見つかりません。バッチと同じ場所に置いてください。
    pause
    exit /b 1
)
if not exist "madVR\install.bat" (
    echo [ERROR] "madVR" フォルダ内に "install.bat" がありません。正しく解凍されていますか？
    pause
    exit /b 1
)

REM --- (6) "madVR" フォルダを "C:\Program Files\madVR" にコピー ---
echo [INFO] "madVR" フォルダを "C:\Program Files\madVR" にコピーします...
md "C:\Program Files\madVR" >nul 2>&1
xcopy /E /H /R /Y "madVR" "C:\Program Files\madVR" >nul
if %errorlevel% neq 0 (
    echo [ERROR] コピーに失敗しました。フォルダやアクセス権を確認してください。
    pause
    exit /b 1
)

REM --- (7) 新しい madVR をインストール (install.bat) ---
echo [INFO] install.bat を実行します...
pushd "C:\Program Files\madVR"
call install.bat
if %errorlevel% neq 0 (
    echo [ERROR] install.bat 実行時にエラーが発生しました。管理者権限やファイル構成を確認してください。
    popd
    pause
    exit /b 1
)

REM --- (8) PotPlayer 用レジストリのインポート (あれば) ---
if exist "madVRtoPotPlayerMini64.reg" (
    echo [INFO] madVRtoPotPlayerMini64.reg をインポートします...
    reg import "madVRtoPotPlayerMini64.reg"
) else (
    echo [WARN] madVRtoPotPlayerMini64.reg が見つからないためスキップします...
)

popd

echo.
echo [INFO] すべての処理が完了しました。問題なければ madVR がインストールされています。
pause
exit /b 0