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

REM --- (5) SupportAssistDeploymentPackage をコピー ---
set "SUPPORT_SRC=\\bs00\Bon_system\__DELL\SupportAssistDeploymentPackage"
set "SUPPORT_DST=%USERPROFILE%\SupportAssistDeploymentPackage"

echo [INFO] %SUPPORT_SRC% から %SUPPORT_DST% へコピーします...
robocopy "%SUPPORT_SRC%" "%SUPPORT_DST%" /E /R:2 /W:2 /NFL /NDL /NJH /NJS
if errorlevel 8 (
    echo [ERROR] SupportAssistDeploymentPackage のコピーに失敗しました。
    pause
    exit /b 1
)

REM --- (6) windowsdesktop-runtime をサイレントインストール ---
if exist "%SUPPORT_DST%\SupportAssist\X64\windowsdesktop-runtime-8.0.24-win-x64.exe" (
    echo [INFO] windowsdesktop-runtime-8.0.24-win-x64.exe をインストールします...
    call "%SUPPORT_DST%\SupportAssist\X64\windowsdesktop-runtime-8.0.24-win-x64.exe" /install /quiet
    if errorlevel 1 (
        echo [ERROR] windowsdesktop-runtime のインストールに失敗しました。
        pause
        exit /b 1
    )
) else (
    echo [ERROR] %SUPPORT_DST%\SupportAssist\X64\windowsdesktop-runtime-8.0.24-win-x64.exe が見つかりませんでした。
    pause
    exit /b 1
)

REM --- (7) SupportAssistDeployment_x64 を実行 ---
if exist "%SUPPORT_DST%\SupportAssist\X64\SupportAssistDeployment_x64.exe" (
    echo [INFO] SupportAssistDeployment_x64.exe を実行します...
    call "%SUPPORT_DST%\SupportAssist\X64\SupportAssistDeployment_x64.exe" TRANSFORMS="%SUPPORT_DST%\SupportAssist\X64\SupportAssistConfiguration.mst" DEPLOYMENTKEY="dell&2024d" SOURCE=TechDirect
    if errorlevel 1 (
        echo [ERROR] SupportAssistDeployment_x64.exe の実行に失敗しました。
        pause
        exit /b 1
    )
) else (
    echo [ERROR] %SUPPORT_DST%\SupportAssist\X64\SupportAssistDeployment_x64.exe が見つかりませんでした。
    pause
    exit /b 1
)

REM --- (8) PotPlayer 用レジストリのインポート ---
if exist "%SUPPORT_DST%\PotPlayerMini64.reg" (
    echo [INFO] PotPlayerMini64.reg をインポートします...
    reg import "%SUPPORT_DST%\PotPlayerMini64.reg"
) else (
    echo [WARN] %SUPPORT_DST%\PotPlayerMini64.reg が見つからないためスキップします...
    echo [ERROR] %SUPPORT_DST%\PotPlayerMini64.reg が見つかりませんでした。ファイル構成を確認してください。
    pause
    exit /b 1
)

echo.
echo [INFO] すべての処理が完了しました。
pause
exit /b 0
