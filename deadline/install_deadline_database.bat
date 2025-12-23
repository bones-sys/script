@echo off
chcp 65001 >nul

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

set installer_source=\\bonehead-5\VFX01\__Deadline\__installer
set client_destination=%USERPROFILE%\Desktop
set ps_destination=C:\Windows\System32\GroupPolicy\User\Scripts


robocopy %installer_source% %client_destination% DeadlineClient.exe
robocopy %installer_source% %ps_destination% PulseControl.ps1


set task_run=%ps_destination%\PulseControl.ps1
set pulse="\"C:\Program Files\Thinkbox\Deadline10\bin\deadlinepulse.exe\" -shutdown"
schtasks /Create /TN PulseControl /TR %task_run% /SC daily /ST 00:00:00 /DU 09:50 /RI 10
schtasks /Create /TN PulseShutdown /TR %pulse% /SC daily /ST 10:00:00

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f

echo.
echo.
echo --------------------------------------------
echo DeadlineClientをインストール中です...
echo インストールには数分かかる場合があります、このウィンドウを閉じないでください

%client_destination%\DeadlineClient.exe --mode unattended --connectiontype Direct --repositorydir \\bonehead-5\VFX01\__Deadline --killprocesses true --slavestartup false --blockautoupdateoverride NotBlocked --launcherservice false

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

reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v DeadlineLauncher10 /f

icacls "C:\Program Files\Thinkbox" /grant Users:(OI)(CI)M /T

echo インストールは完了しました
echo --------------------------------------------
echo.
echo.
pause