@echo off
chcp 65001 >nul

rem ============================================================
rem  FPT Desktop api_v2.py パッチ適用バッチ (BONES-PATCH)
rem  ・管理者権限へ自動昇格
rem  ・既存 api_v2.py を .bak にリネームしてバックアップ
rem  ・同フォルダの新しい api_v2.py を配置
rem  ・__pycache__ を削除
rem ============================================================

rem --- 権限昇格 ---
for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
    exit
)

rem 昇格後はカレントが system32 になるため、bat自身の場所を基準にする
set "SRC=%~dp0api_v2.py"
set "DSTDIR=C:\Program Files\Shotgun\Resources\Desktop\Python\bundle_cache\app_store\tk-framework-desktopserver\v1.8.7\python\tk_framework_desktopserver\shotgun"
set "DST=%DSTDIR%\api_v2.py"

echo.
echo === FPT Desktop api_v2.py パッチ適用 ===
echo.

rem --- 事前チェック ---
if not exist "%SRC%" (
    echo [エラー] batと同じフォルダに api_v2.py が見つかりません:
    echo   %SRC%
    goto :fail
)

if not exist "%DST%" (
    echo [エラー] 置き換え対象が見つかりません:
    echo   %DST%
    echo FPT Desktop のバージョンが v1.8.7 と異なる可能性があります。
    goto :fail
)

rem --- FPT Desktop 起動中チェック ---
tasklist /FI "IMAGENAME eq Shotgun.exe" | find /I "Shotgun.exe" >nul
if %errorlevel%==0 (
    echo [警告] FPT Desktop ^(Shotgun.exe^) が起動中です。
    echo タスクトレイから終了してから、このbatを再実行してください。
    goto :fail
)

rem --- バックアップ（既に.bakがあれば日時付きで退避） ---
if exist "%DST%.bak" (
    set "TS=%date:/=%_%time::=%"
    set "TS=%TS: =0%"
    set "TS=%TS:.=%"
    ren "%DST%.bak" "api_v2.py.bak_%TS%"
)
ren "%DST%" "api_v2.py.bak"
if errorlevel 1 (
    echo [エラー] バックアップ用リネームに失敗しました。
    goto :fail
)
echo [OK] 既存ファイルを api_v2.py.bak にバックアップしました。

rem --- 新ファイル配置 ---
copy /Y "%SRC%" "%DST%" >nul
if errorlevel 1 (
    echo [エラー] 新しい api_v2.py のコピーに失敗しました。バックアップを戻します。
    ren "%DST%.bak" "api_v2.py"
    goto :fail
)
echo [OK] パッチ済み api_v2.py を配置しました。

rem --- __pycache__ 削除 ---
if exist "%DSTDIR%\__pycache__" (
    rd /S /Q "%DSTDIR%\__pycache__"
    echo [OK] __pycache__ を削除しました。
) else (
    echo [情報] __pycache__ はありませんでした。
)

echo.
echo === 完了しました。FPT Desktop を起動して動作確認してください ===
echo.
pause
exit /b 0

:fail
echo.
echo === 適用は行われませんでした ===
echo.
pause
exit /b 1
