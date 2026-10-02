@echo off
chcp 65001 >nul

rem ============================================================
rem  PTR Desktop パッチ適用バッチ (BONES-PATCH v2)
rem  対象: api_v2.py / server_protocol.py (tk-framework-desktopserver v1.8.8)
rem  ・配置先: Program Files 側の bundle_cache に対象バージョンがあればそこへ、
rem    無ければユーザーの bundle_cache (%APPDATA%\Shotgun\bundle_cache) へ
rem  ・Program Files 側に当てる場合のみ管理者権限へ自動昇格
rem  ・既存ファイルを .bak にリネームしてバックアップ
rem  ・batと同じフォルダのパッチ済みファイルを配置
rem  ・関係する __pycache__ を削除
rem ============================================================

set "FWVER=v1.8.8"
set "SUBPATH=app_store\tk-framework-desktopserver\%FWVER%\python\tk_framework_desktopserver"

rem --- 配置先の決定 ---
rem  1) Program Files 側 (インストーラー同梱の bundle_cache)
rem  2) 無ければユーザー側 (SHOTGUN_BUNDLE_CACHE_PATH があればそちらを優先)
set "PF_FWDIR=C:\Program Files\Shotgun\Resources\Desktop\Python\bundle_cache\%SUBPATH%"
set "CACHEDIR=%APPDATA%\Shotgun\bundle_cache"
if defined SHOTGUN_BUNDLE_CACHE_PATH set "CACHEDIR=%SHOTGUN_BUNDLE_CACHE_PATH%"
set "USER_FWDIR=%CACHEDIR%\%SUBPATH%"

if exist "%PF_FWDIR%\" goto :use_pf
if exist "%USER_FWDIR%\" goto :use_user

echo [エラー] tk-framework-desktopserver %FWVER% が見つかりません。
echo         %PF_FWDIR%
echo         %USER_FWDIR%
goto :fail

:use_pf
set "FWDIR=%PF_FWDIR%"

rem --- 権限昇格 (Program Files 側は管理者権限が必要) ---
for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if "%LEVEL%"=="High" goto :target_ok
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit

:use_user
set "FWDIR=%USER_FWDIR%"

:target_ok
echo 配置先: %FWDIR%

echo.
echo === PTR Desktop パッチ適用 (api_v2.py / server_protocol.py) ===
echo.

rem --- PTR Desktop 起動中チェック ---
tasklist /FI "IMAGENAME eq Shotgun.exe" | find /I "Shotgun.exe" >nul
if %errorlevel%==0 (
    echo [警告] PTR Desktop ^(Shotgun.exe^) が起動中です。
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
echo === 完了しました。PTR Desktop を起動して動作確認してください ===
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
    echo         %FWVER% のフォルダ構成が想定と異なる可能性があります。
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
