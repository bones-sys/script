@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process %~f0 -Verb runas"
exit
)

echo --------------------------------------------
echo 高速スタートアップを無効にしています...
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo スリープを無効にしています...
powercfg -x standby-timeout-ac 0
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo 縮小表示のキャッシュを無効に設定しています...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableThumbsDBOnNetworkFolders /t REG_DWORD /d 1 /f
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo RDPを有効にしています...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
powershell "Enable-NetFirewallRule -DisplayGroup 'リモート デスクトップ'"
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo ネットワーク探索とファイルとプリンターの共有を有効化しています...
powershell "Set-NetFirewallRule -DisplayGroup 'ネットワーク探索' -Profile Domain,Private -Enabled True"
powershell "Set-NetFirewallRule -DisplayGroup 'ファイルとプリンターの共有' -Profile Domain -Enabled True"
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo 自動ログオンを設定しています...
set /p username=ユーザー名（ドメイン以外）を入力してください:
set /p password=パスワードを入力してください:

for /f "tokens=2 delims=@" %%i in ('whoami /upn') do (
    set domain_name=%%i
)
for /f %%A in ('powershell -command "[cultureinfo]::CurrentCulture.TextInfo.ToTitleCase('%domain_name%')"') do (
    set domain_name=%%A
)

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d %username% /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d %password% /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /t REG_SZ /d %domain_name% /f
echo --------------------------------------------
echo.
echo.

set installer_source=\\bonehead-5\VFX01\__Deadline\__installer
set client_destination=%USERPROFILE%\Desktop

robocopy %installer_source% %client_destination% DeadlineClient.exe

set wol_source=\\bonehead-5\VFX01\__Deadline\__installer\Scripts\WOL
set wol_destination=C:\Windows\System32\GroupPolicy\User\Scripts\WOL

robocopy %wol_source% %wol_destination% /e

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f

echo.
echo.
echo --------------------------------------------
echo DeadlineClientをインストール中です...
echo インストールには数分かかる場合があります、このウィンドウを閉じないでください

%client_destination%\DeadlineClient.exe --mode unattended --connectiontype Direct --repositorydir \\bonehead-5\VFX01\__Deadline --killprocesses true --slavestartup true --blockautoupdateoverride NotBlocked --launcherservice false

set deadline_ini=%UserProfile%\AppData\Local\Thinkbox\Deadline10\deadline.ini
set entry="LaunchPulseAtStartup=True"

powershell -NoProfile -Command "& { Add-Content -Path '%deadline_ini%' -Value '%entry%' -Encoding UTF8 }"

set thinkbox=%USERPROFILE%\AppData\Local\Thinkbox
del %client_destination%\DeadlineClient.exe
if exist "%thinkbox%" (
    icacls %thinkbox% /reset /t
)

set pulse="C:\Program Files\Thinkbox\Deadline10\bin\deadlinepulse.exe"
netsh advfirewall firewall add rule name="Deadline Pulse" dir=in action=allow program=%pulse% enable=yes profile=any

set launcher="C:\Program Files\Thinkbox\Deadline10\bin\deadlinelauncher.exe"
netsh advfirewall firewall add rule name="Deadline Launcher" dir=in action=allow program=%launcher% enable=yes profile=any

set monitor="C:\Program Files\Thinkbox\Deadline10\bin\deadlinemonitor.exe"
netsh advfirewall firewall add rule name="Deadline Monitor" dir=in action=allow program=%monitor% enable=yes profile=any

set worker="C:\Program Files\Thinkbox\Deadline10\bin\deadlineworker.exe"
netsh advfirewall firewall add rule name="Deadline Worker" dir=in action=allow program=%worker% enable=yes profile=any

echo インストールは完了しました
echo --------------------------------------------
echo.
echo.
pause