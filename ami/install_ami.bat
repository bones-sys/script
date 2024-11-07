@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process %~f0 -Verb runas"
exit
)

set VER=3.0.0
title Install action-menu-item Ver %VER%

echo --------------------------------------------
echo slack�̐ݒ��ύX���Ă��܂�...
echo --------------------------------------------
set "jsonFilePath=%USERPROFILE%\AppData\Roaming\Slack\storage\root-state.json"

if exist "%jsonFilePath%" (
    setlocal enabledelayedexpansion
    set "PSCOMMAND="
    set "PSCOMMAND=!PSCOMMAND! $jsonContent = Get-Content -Path '%jsonFilePath%' | ConvertFrom-Json;"
    set "PSCOMMAND=!PSCOMMAND! $jsonContent.settings.userChoices | Add-Member -MemberType NoteProperty -Name 'win32' -Value @{ 'windowFlashBehavior' = 'always'; 'hasExplainedWindowFlash' = $true } -Force;"
    set "PSCOMMAND=!PSCOMMAND! $jsonContent.settings.userChoices | Add-Member -MemberType NoteProperty -Name 'notificationMethod' -Value 'winrt' -Force;"
    set "PSCOMMAND=!PSCOMMAND! $jsonContent.settings.userChoices | Add-Member -MemberType NoteProperty -Name 'runFromTray' -Value $true -Force;"
    set "PSCOMMAND=!PSCOMMAND! $jsonContent.settings.userChoices | Add-Member -MemberType NoteProperty -Name 'hideOnStartup' -Value $true -Force;"
    set "PSCOMMAND=!PSCOMMAND! $jsonContent.settings.userChoices | Add-Member -MemberType NoteProperty -Name 'locale' -Value 'ja-JP' -Force;"
    set "PSCOMMAND=!PSCOMMAND! $jsonUpdated = $jsonContent | ConvertTo-Json -Depth 10;"
    set "PSCOMMAND=!PSCOMMAND! Set-Content -Path '%jsonFilePath%' -Value $jsonUpdated;"
    powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "!PSCOMMAND!"
    endlocal
) else (
    echo �t�@�C����������܂���: %jsonFilePath%
)
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
echo initialKeyboardIndicators��2147483650�ɕύX����NUMLOCK���I���ɂ��Ă܂�...
reg add "HKEY_USERS\.DEFAULT\Control Panel\Keyboard" /v initialKeyboardIndicators /t REG_SZ /d 2147483650 /f
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

set REMOTE_FOLDER=\\bs00\Bon_system\ami_launcher
set LAUNCHER_FOLDER=%USERPROFILE%\ami_launcher

set CHROME_HKEY=HKLM\SOFTWARE\Policies\Google\Chrome\URLWhitelist
set LAUNCHER_HKEY=HKCR\ami
set LAUNCH_LAUNCHER="\"%LAUNCHER_FOLDER%\ami_launcher.exe\" \"%%1\""
set OPLINK_HKEY=HKCR\oplink
set LAUNCH_OPLINK="\"%LAUNCHER_FOLDER%\oplink.exe\" \"%%1\""

echo action-menu-item �C���X�g�[�� Ver.%VER%
echo.
echo.

echo --------------------------------------------
echo �p�X�����Ђ̕ی�̑Ώۂ��珜�O���ł�...

powershell Add-MpPreference -ExclusionPath %USERPROFILE%\ami_version
powershell Add-MpPreference -ExclusionPath '%LAUNCHER_FOLDER%'
powershell Add-MpPreference -ExclusionPath \\bs00\Bon_system

echo --------------------------------------------
echo.
echo.


cd /d %~dp0

echo.
echo --------------------------------------------
echo �C���X�g�[�����ł�...

timeout /t 1 /nobreak >nul
echo.

if exist %REMOTE_FOLDER% (
    if exist %LAUNCHER_FOLDER% (
        rmdir /s /q %LAUNCHER_FOLDER%
        echo �����̃t�H���_���폜���܂���
    )

    robocopy %REMOTE_FOLDER% %LAUNCHER_FOLDER% /s
    reg add %CHROME_HKEY% /v "1" /t "REG_SZ" /d "ami://*" /f

    reg add %LAUNCHER_HKEY% /t "REG_SZ" /d "URL:ami" /f
    reg add %LAUNCHER_HKEY% /v "URL Protocol" /t "REG_SZ" /d "" /f
    reg add %LAUNCHER_HKEY%\shell\open\command /t "REG_SZ" /d %LAUNCH_LAUNCHER% /f

    reg add %OPLINK_HKEY% /t "REG_SZ" /d "URL:oplink" /f
    reg add %OPLINK_HKEY% /v "URL Protocol" /t "REG_SZ" /d "" /f
    reg add %OPLINK_HKEY%\shell\open\command /t "REG_SZ" /d %LAUNCH_OPLINK% /f

    if not "%ERRORLEVEL%" == "0" (
            echo �C���X�g�[�����ɃG���[���������܂���
    ) else (
        echo �C���X�g�[���͊������܂���
        echo.
    )
) else (
    echo %REMOTE_FOLDER% �����݂��܂���
)
echo --------------------------------------------
:End

echo.
echo.
echo �o�b�`���I�����܂�

timeout /t 1 /nobreak >nul