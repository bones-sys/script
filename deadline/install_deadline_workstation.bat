@echo off
chcp 65001 >nul

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

echo --------------------------------------------
echo スリープを無効にしています...
powercfg -x standby-timeout-ac 0
echo --------------------------------------------
echo.
echo.

set installer_source=\\bonehead-5\VFX01\__Deadline\__installer
set client_destination=%USERPROFILE%\Desktop
set destination_link="C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"

robocopy %installer_source% %destination_link% "Deadline Pulse 10.lnk"
robocopy %installer_source% %client_destination% DeadlineClient.exe

for /f "tokens=1 delims=\" %%i in ('whoami') do (
    set domain_name=%%i
)

set windows_user_code=%USERNAME:~-3%
set windows_user=%domain_name%\bon_x0%windows_user_code%
set user_pass=boncam%windows_user_code%

set bat_source=%installer_source%\Scripts
set bat_destination=C:\Windows\System32\GroupPolicy\User\Scripts

robocopy %bat_source% %bat_destination% /e

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v "NoLockScreen" /t REG_DWORD /d 1 /f

schtasks /Create /TN "DeadlineLauncherServiceStart" ^
    /TR "C:\Windows\System32\GroupPolicy\User\Scripts\Start\StartDeadlineService.bat" ^
    /SC ONEVENT ^
    /EC System ^
    /MO "*[System[Provider[@Name='Microsoft-Windows-Winlogon'] and (EventID=7002)]]" ^
    /RU "SYSTEM" ^
    /RL HIGHEST

schtasks /Create /TN "DeadlineLauncherServiceStop" ^
    /TR "C:\Windows\System32\GroupPolicy\User\Scripts\Stop\StopDeadlineService.bat" ^
    /SC ONLOGON ^
    /RU "SYSTEM" ^
    /RL HIGHEST

schtasks /Create /TN "DeadlinePulseStop" ^
    /TR "\"C:\Program Files\Thinkbox\Deadline10\bin\deadlinepulse.exe\" -s" ^
    /SC ONEVENT ^
    /EC System ^
    /MO "*[System[Provider[@Name='Microsoft-Windows-Winlogon'] and (EventID=7002)]]" ^
    /RU "SYSTEM" ^
    /RL HIGHEST

echo.
echo.
echo --------------------------------------------
echo DeadlineClientをインストール中です...
echo インストールには数分かかる場合があります、このウィンドウを閉じないでください

%client_destination%\DeadlineClient.exe --mode unattended --connectiontype Direct --repositorydir \\bonehead-5\VFX01\__Deadline_2025 --killprocesses true --slavestartup true --blockautoupdateoverride NotBlocked --launcherservice true --serviceuser %windows_user% --servicepassword %user_pass%

set thinkbox=%USERPROFILE%\AppData\Local\Thinkbox
del %client_destination%\DeadlineClient.exe
if exist "%thinkbox%" (
    icacls %thinkbox% /reset /t
)
if exist "%bat_destination%" (
    icacls %bat_destination% /reset /t
)

setlocal enabledelayedexpansion
set shortcut_folder=C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Thinkbox\Deadline 10
set "file_list="Deadline Balancer 10","Deadline Launcher 10","Deadline Pulse 10","Deadline Pulse 10","Deadline Worker 10","Deadline Monitor 10""
for %%i in (%file_list%) do (
    if exist "%shortcut_folder%\%%~i.lnk" (
        del "%shortcut_folder%\%%~i.lnk"
    )
)
robocopy "%installer_source%" "%shortcut_folder%" "Deadline Monitor 10.lnk"
endlocal

set pulse="C:\Program Files\Thinkbox\Deadline10\bin\deadlinepulse.exe"
netsh advfirewall firewall add rule name="Deadline Pulse" dir=in action=allow program=%pulse% enable=yes profile=any

set launcher="C:\Program Files\Thinkbox\Deadline10\bin\deadlinelauncher.exe"
netsh advfirewall firewall add rule name="Deadline Launcher" dir=in action=allow program=%launcher% enable=yes profile=any

set launcher_service="C:\Program Files\Thinkbox\Deadline10\bin\deadlinelauncherservice.exe"
netsh advfirewall firewall add rule name="Deadline Launcher Service" dir=in action=allow program=%launcher_service% enable=yes profile=any

set monitor="C:\Program Files\Thinkbox\Deadline10\bin\deadlinemonitor.exe"
netsh advfirewall firewall add rule name="Deadline Monitor" dir=in action=allow program=%monitor% enable=yes profile=any

set worker="C:\Program Files\Thinkbox\Deadline10\bin\deadlineworker.exe"
netsh advfirewall firewall add rule name="Deadline Worker" dir=in action=allow program=%worker% enable=yes profile=any

reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v DeadlineLauncher10 /f

icacls "C:\Program Files\Thinkbox" /grant Users:(OI)(CI)M /T

echo インストールは完了しました
echo --------------------------------------------
echo.
echo.

echo.
echo.
echo --------------------------------------------
echo IPアドレスを設定中です...
REM ホスト名を取得
for /f "tokens=2 delims=_" %%A in ('hostname') do set HOST_SUFFIX=%%A

REM 数値部分に100を加算（デフォルト値を設定）
if not defined HOST_SUFFIX set HOST_SUFFIX=0

for /f "tokens=* delims=0" %%B in ("%HOST_SUFFIX%") do set HOST_SUFFIX=%%B
set /a IP_SUFFIX=100 + %HOST_SUFFIX%

REM ネットワークアダプター名（環境に応じて変更）
set NETWORK_ADAPTER_NAME="イーサネット"
REM 固定IPアドレスのプレフィックス
set IP_PREFIX=192.168.33
REM サブネットマスク
set SUBNET_MASK=255.255.255.0
REM デフォルトゲートウェイ
set GATEWAY=192.168.33.254
REM 優先DNSサーバー
set DNS=192.168.30.60
REM 代替DNSサーバー
set ALT_DNS=192.168.30.70

REM IPアドレスの末尾をホスト名から設定
set IP_ADDRESS=%IP_PREFIX%.%IP_SUFFIX%

REM ネットワーク設定を変更
echo 設定中: %IP_ADDRESS%
netsh interface ip set address name=%NETWORK_ADAPTER_NAME% static %IP_ADDRESS% %SUBNET_MASK% %GATEWAY%
netsh interface ip set dns name=%NETWORK_ADAPTER_NAME% static %DNS%
netsh interface ip add dns name=%NETWORK_ADAPTER_NAME% %ALT_DNS% index=2

REM 完了メッセージ
echo IPアドレスが %IP_ADDRESS% に設定されました。
echo --------------------------------------------
echo.
echo.

pause