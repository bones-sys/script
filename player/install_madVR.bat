@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process %~f0 -Verb runas"
exit
)

REM --- 1) もし "C:\Program Files\madVR" フォルダがあればアンインストール ---
IF EXIST "C:\Program Files\madVR\uninstall.bat" (
    echo [INFO] madVR がインストール済みのため、uninstall.bat を実行します...
    pushd "C:\Program Files\madVR"
    call uninstall.bat
    popd
)

REM --- 2) 既存の "C:\Program Files\madVR" フォルダを削除 ---
IF EXIST "C:\Program Files\madVR" (
    echo [INFO] 既存の madVR フォルダを削除します...
    RD /S /Q "C:\Program Files\madVR"
)

REM --- 3) 同じ場所にある "madVR.zip" を展開して "C:\Program Files\madVR" にコピー ---
echo [INFO] madVR.zip を "C:\Program Files\madVR" に解凍します...
powershell -Command "Expand-Archive -LiteralPath 'madVR.zip' -DestinationPath 'C:\Program Files\madVR'"

REM --- 4) "install.bat" を実行して madVR をレジストリ登録 ---
echo [INFO] install.bat を実行します...
pushd "C:\Program Files\madVR"
call install.bat

REM --- 5) "madVRtoPotPlayerMini64.reg" を実行 (レジストリを取り込み) ---
echo [INFO] madVRtoPotPlayerMini64.reg を実行します...
reg import "madVRtoPotPlayerMini64.reg"

popd

echo [INFO] 全ての処理が完了しました。
pause