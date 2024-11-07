@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process %~f0 -Verb runas"
exit
)

set VER=3.0.0
title Install action-menu-item Ver %VER%

echo --------------------------------------------
echo slackの設定を変更しています...
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
    echo ファイルが見つかりません: %jsonFilePath%
)
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
echo initialKeyboardIndicatorsを2147483650に変更してNUMLOCKをオンにしてます...
reg add "HKEY_USERS\.DEFAULT\Control Panel\Keyboard" /v initialKeyboardIndicators /t REG_SZ /d 2147483650 /f
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

set REMOTE_FOLDER=\\bs00\Bon_system\ami_launcher
set LAUNCHER_FOLDER=%USERPROFILE%\ami_launcher

set CHROME_HKEY=HKLM\SOFTWARE\Policies\Google\Chrome\URLWhitelist
set LAUNCHER_HKEY=HKCR\ami
set LAUNCH_LAUNCHER="\"%LAUNCHER_FOLDER%\ami_launcher.exe\" \"%%1\""
set OPLINK_HKEY=HKCR\oplink
set LAUNCH_OPLINK="\"%LAUNCHER_FOLDER%\oplink.exe\" \"%%1\""

echo action-menu-item インストール Ver.%VER%
echo.
echo.

echo --------------------------------------------
echo パスを脅威の保護の対象から除外中です...

powershell Add-MpPreference -ExclusionPath %USERPROFILE%\ami_version
powershell Add-MpPreference -ExclusionPath '%LAUNCHER_FOLDER%'
powershell Add-MpPreference -ExclusionPath \\bs00\Bon_system

echo --------------------------------------------
echo.
echo.


cd /d %~dp0

echo.
echo --------------------------------------------
echo インストール中です...

timeout /t 1 /nobreak >nul
echo.

if exist %REMOTE_FOLDER% (
    if exist %LAUNCHER_FOLDER% (
        rmdir /s /q %LAUNCHER_FOLDER%
        echo 既存のフォルダを削除しました
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
            echo インストール中にエラーが発生しました
    ) else (
        echo インストールは完了しました
        echo.
    )
) else (
    echo %REMOTE_FOLDER% が存在しません
)
echo --------------------------------------------
:End

echo.
echo.
echo バッチを終了します

timeout /t 1 /nobreak >nul