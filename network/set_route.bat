@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
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
:: バックアップ準備
::-----------------------------------------
set BKDIR=C:\temp\route_backup
if not exist "%BKDIR%" mkdir "%BKDIR%"
set TS=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%
set TS=%TS: =0%
set REGBK=%BKDIR%\PersistentRoutes_%COMPUTERNAME%_%TS%.reg
set LOGBK=%BKDIR%\route_print_%COMPUTERNAME%_%TS%.log

::-----------------------------------------
:: レジストリバックアップ（永続ルートの完全な復元用）
::-----------------------------------------
echo PersistentRoutes をバックアップしています...
reg export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\PersistentRoutes" "%REGBK%" /y
if errorlevel 1 (
    echo [ERROR] レジストリのバックアップに失敗しました。中断します。
    pause
    exit /b 1
)
echo   保存先: %REGBK%

:: 参考情報としてルートテーブル全体も保存
route print -4 > "%LOGBK%"
echo   ルートテーブル: %LOGBK%
echo.

::-----------------------------------------
:: 削除前の永続ルートを表示
::-----------------------------------------
echo ===== 現在の永続ルート =====
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\PersistentRoutes"
echo.

::-----------------------------------------
:: 永続ルートを全て削除
:: レジストリ値名の形式: 宛先,マスク,GW,メトリック
::-----------------------------------------
echo 永続ルートを削除しています...
set DELCOUNT=0
for /f "tokens=1 delims=," %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\PersistentRoutes" ^| findstr /r "^    "') do (
    echo   route delete %%a
    route delete %%a >nul 2>&1
    set /a DELCOUNT+=1
)
echo   !DELCOUNT! 件削除しました。
echo.

::-----------------------------------------
:: 統一ルートを追加（VRRP 仮想 GW 経由、永続化）
::-----------------------------------------
echo 統一ルートを追加: 192.168.30.0/24 via 192.168.80.1 ...
route add 192.168.30.0 mask 255.255.255.0 192.168.80.1 -p
if errorlevel 1 (
    echo [ERROR] route add に失敗しました。
    echo 復元する場合: "%REGBK%" をダブルクリック後、再起動してください。
    pause
    exit /b 1
)
echo.

::-----------------------------------------
:: 変更後の確認
::-----------------------------------------
echo ===== 変更後の永続ルート =====
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\PersistentRoutes"
echo.
echo 完了しました。
echo   バックアップ: %REGBK%
echo   復元方法: reg ファイルをダブルクリック → 再起動（または route add で再投入）
pause