@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

echo --------------------------------------------
echo �����X�^�[�g�A�b�v�𖳌��ɂ��Ă��܂�...
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo �X���[�v�𖳌��ɂ��Ă��܂�...
powercfg -x standby-timeout-ac 0
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo �k���\���̃L���b�V���𖳌��ɐݒ肵�Ă��܂�...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableThumbsDBOnNetworkFolders /t REG_DWORD /d 1 /f
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo RDP��L���ɂ��Ă��܂�...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
powershell "Enable-NetFirewallRule -DisplayGroup '�����[�g �f�X�N�g�b�v'"
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo �l�b�g���[�N�T���ƃt�@�C���ƃv�����^�[�̋��L��L�������Ă��܂�...
powershell "Set-NetFirewallRule -DisplayGroup '�l�b�g���[�N�T��' -Profile Domain,Private -Enabled True"
powershell "Set-NetFirewallRule -DisplayGroup '�t�@�C���ƃv�����^�[�̋��L' -Profile Domain -Enabled True"
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo �������O�I����ݒ肵�Ă��܂�...
set /p username=���[�U�[���i�h���C���ȊO�j����͂��Ă�������:
set /p password=�p�X���[�h����͂��Ă�������:

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
echo DeadlineClient���C���X�g�[�����ł�...
echo �C���X�g�[���ɂ͐���������ꍇ������܂��A���̃E�B���h�E����Ȃ��ł�������

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

icacls "C:\Program Files\Thinkbox" /grant Users:(OI)(CI)M /T

echo �C���X�g�[���͊������܂���
echo --------------------------------------------
echo.
echo.

echo.
echo.
echo --------------------------------------------
echo IP�A�h���X��ݒ蒆�ł�...
REM �z�X�g�����擾
for /f "tokens=2 delims=_" %%A in ('hostname') do set HOST_SUFFIX=%%A

REM ���l������100�����Z�i�f�t�H���g�l��ݒ�j
if not defined HOST_SUFFIX set HOST_SUFFIX=0

for /f "tokens=* delims=0" %%B in ("%HOST_SUFFIX%") do set HOST_SUFFIX=%%B
set /a IP_SUFFIX=100 + %HOST_SUFFIX%

REM �l�b�g���[�N�A�_�v�^�[���i���ɉ����ĕύX�j
set NETWORK_ADAPTER_NAME="�C�[�T�l�b�g"
REM �Œ�IP�A�h���X�̃v���t�B�b�N�X
set IP_PREFIX=192.168.33
REM �T�u�l�b�g�}�X�N
set SUBNET_MASK=255.255.255.0
REM �f�t�H���g�Q�[�g�E�F�C
set GATEWAY=192.168.33.254
REM �D��DNS�T�[�o�[
set DNS=192.168.30.60
REM ���DNS�T�[�o�[
set ALT_DNS=192.168.30.70

REM IP�A�h���X�̖������z�X�g������ݒ�
set IP_ADDRESS=%IP_PREFIX%.%IP_SUFFIX%

REM �l�b�g���[�N�ݒ��ύX
echo �ݒ蒆: %IP_ADDRESS%
netsh interface ip set address name=%NETWORK_ADAPTER_NAME% static %IP_ADDRESS% %SUBNET_MASK% %GATEWAY%
netsh interface ip set dns name=%NETWORK_ADAPTER_NAME% static %DNS%
netsh interface ip add dns name=%NETWORK_ADAPTER_NAME% %ALT_DNS% index=2

REM �������b�Z�[�W
echo IP�A�h���X�� %IP_ADDRESS% �ɐݒ肳��܂����B
echo --------------------------------------------
echo.
echo.
pause