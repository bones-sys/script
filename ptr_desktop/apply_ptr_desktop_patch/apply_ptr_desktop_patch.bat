@echo off
chcp 65001 >nul

rem ============================================================
rem  FPT Desktop パッチ適用バッチ (BONES-PATCH v2)
rem  対象: api_v2.py / server_protocol.py (tk-framework-desktopserver v1.8.7)
rem  ・管理者権限へ自動昇格
rem  ・既存ファイルを .bak にリネームしてバックアップ
rem  ・batと同じフォルダのパッチ済みファイルを配置
rem  ・関係する __pycache__ を削除
rem ============================================================

rem --- 権限昇格 ---
for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
    exit
)

set "FWDIR=C:\Program Files\Shotgun\Resources\Desktop\Python\bundle_cache\app_store\tk-framework-desktopserver\v1.8.7\python\tk_framework_desktopserver"

echo.
echo === FPT Desktop パッチ適用 (api_v2.py / server_protocol.py) ===
echo.

rem --- FPT Desktop 起動中チェック ---
tasklist /FI "IMAGENAME eq Shotgun.exe" | find /I "Shotgun.exe" >nul
if %errorlevel%==0 (
    echo [警告] FPT Desktop ^(Shotgun.exe^) が起動中です。
    echo タスクトレイから終了してから、このbatを再実行してください。
    goto :fail
)

rem --- タイムスタンプ生成（既存.bak退避用） ---
set "TS=%date:/=%_%time::=%"
set "TS=%TS: =0%"
set "TS=%TS:.=%"

set "FAILED="

call :apply "api_v2.py"           "%FWDIR%\shotgun"
call :apply "server_protocol.py"  "%FWDIR%"

if defined FAILED goto :fail

rem --- __pycache__ 削除 ---
if exist "%FWDIR%\__pycache__"          rd /S /Q "%FWDIR%\__pycache__"
if exist "%FWDIR%\shotgun\__pycache__"  rd /S /Q "%FWDIR%\shotgun\__pycache__"
echo [OK] __pycache__ を削除しました。

echo.
echo === 完了しました。FPT Desktop を起動して動作確認してください ===
echo.
pause
exit /b 0

rem ============================================================
rem  サブルーチン: %1=ファイル名 %2=配置先フォルダ
rem ============================================================
:apply
set "NAME=%~1"
set "SRC=%~dp0%~1"
set "DST=%~2\%~1"

if not exist "%SRC%" (
    echo [エラー] batと同じフォルダに %NAME% が見つかりません。
    set "FAILED=1"
    goto :eof
)
if not exist "%DST%" (
    echo [エラー] 置き換え対象が見つかりません: %DST%
    echo         v1.8.7 以外のバージョンの可能性があります。
    set "FAILED=1"
    goto :eof
)

if exist "%DST%.bak" ren "%DST%.bak" "%NAME%.bak_%TS%"
ren "%DST%" "%NAME%.bak"
if errorlevel 1 (
    echo [エラー] %NAME% のバックアップに失敗しました。
    set "FAILED=1"
    goto :eof
)

copy /Y "%SRC%" "%DST%" >nul
if errorlevel 1 (
    echo [エラー] %NAME% のコピーに失敗しました。バックアップを戻します。
    ren "%DST%.bak" "%NAME%"
    set "FAILED=1"
    goto :eof
)
echo [OK] %NAME% を置き換えました（旧ファイルは %NAME%.bak）。
goto :eof

:fail
echo.
echo === 適用は完了していません。メッセージを確認してください ===
echo.
pause
exit /b 1
