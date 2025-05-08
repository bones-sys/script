@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

echo --------------------------------------------
echo ƒpƒX‚ð‹ºˆÐ‚Ì•ÛŒì‚Ì‘ÎÛ‚©‚çœŠO’†‚Å‚·...

powershell Add-MpPreference -ExclusionPath 'C:\Program Files\Adobe\Common\Plug-ins\7.0\MediaCore\F''s Plugins'

echo --------------------------------------------
echo.
echo.

timeout /t 1 /nobreak >nul