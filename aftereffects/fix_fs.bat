@echo off
chcp 65001 >nul

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

echo --------------------------------------------
echo パスを脅威の保護の対象から除外中です...

powershell Add-MpPreference -ExclusionPath 'C:\Program Files\Adobe\Common\Plug-ins\7.0\MediaCore\F''s Plugins'

echo --------------------------------------------
echo.
echo.

timeout /t 1 /nobreak >nul