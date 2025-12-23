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

REM --- (3) 旧バージョンの madVR があればアンインストール ---
if exist "C:\madVR\uninstall.bat" (
    echo [INFO] 既存の madVR をアンインストールします...
    call "C:\madVR\uninstall.bat"
)

REM --- (4) 旧バージョンのフォルダを削除 ---
if exist "C:\madVR" (
    echo [INFO] 既存の "C:\madVR" フォルダを削除します...
    rd /s /q "C:\madVR"
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

REM --- (6) "madVR" フォルダを "C:\madVR" にコピー ---
echo [INFO] "madVR" フォルダを "C:\madVR" にコピーします...
md "C:\madVR" >nul 2>&1
xcopy /E /H /R /Y "madVR" "C:\madVR" >nul
if %errorlevel% neq 0 (
    echo [ERROR] コピーに失敗しました。フォルダやアクセス権を確認してください。
    pause
    exit /b 1
)

REM --- (7) 新しい madVR をインストール (install.bat) ---
echo [INFO] 既存の madVR の設定を初期化します...
call "C:\madVR\restore default settings.bat"
echo [INFO] install.bat を実行します...
call "C:\madVR\install.bat"
if %errorlevel% neq 0 (
    echo [ERROR] install.bat 実行時にエラーが発生しました。管理者権限やファイル構成を確認してください。
    pause
    exit /b 1
)

REM --- (8) PotPlayer 用レジストリのインポート (あれば) ---
if exist "C:\madVR\madVRtoPotPlayerMini64.reg" (
    echo [INFO] madVRtoPotPlayerMini64.reg をインポートします...
    reg import "C:\madVR\madVRtoPotPlayerMini64.reg"
) else (
    echo [WARN] C:\madVR\madVRtoPotPlayerMini64.reg が見つからないためスキップします...
    echo [ERROR] C:\madVR\madVRtoPotPlayerMini64.reg が見つかりませんでした。ファイル構成を確認してください。
    pause
    exit /b 1
)

echo.
echo [INFO] すべての処理が完了しました。問題なければ madVR が "C:\madVR" にインストールされています。
pause
exit /b 0
