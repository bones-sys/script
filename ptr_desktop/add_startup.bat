@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process %~f0 -Verb runas"
exit
)

echo --------------------------------------------
echo スタートアップに登録しています...
set startupFolder=%AppData%\Microsoft\Windows\Start Menu\Programs\Startup
set shortcutName=Shotgun.lnk
set shortcutPath=%startupFolder%\%shortcutName%
powershell "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%shortcutPath%'); $s.TargetPath = 'C:\Program Files\Shotgun\Shotgun.exe'; $s.Save()"
echo --------------------------------------------
echo.
echo.

timeout /t 1 /nobreak >nul