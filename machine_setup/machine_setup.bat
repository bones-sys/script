@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process %~f0 -Verb runas"
exit
)

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

pause
