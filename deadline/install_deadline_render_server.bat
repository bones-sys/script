@echo off
setlocal enabledelayedexpansion

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

echo --------------------------------------------
echo Disabling sleep...
powercfg -x standby-timeout-ac 0
echo --------------------------------------------
echo.
echo.

echo --------------------------------------------
echo Configuring auto logon...
set /p username=Enter user name (without domain): 
set /p password=Enter password: 

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
echo Installing DeadlineClient...
echo This may take several minutes. Do not close this window.

%client_destination%\DeadlineClient.exe --mode unattended --connectiontype Direct --repositorydir \\bonehead-5\VFX01\__Deadline_2025 --killprocesses true --slavestartup true --blockautoupdateoverride NotBlocked --launcherservice false

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

echo Installation completed.
echo --------------------------------------------
echo.
echo.

echo.
echo.
echo --------------------------------------------
echo Configuring IP address...
REM Get host name suffix
for /f "tokens=2 delims=_" %%A in ('hostname') do set HOST_SUFFIX=%%A

REM Add 100 to the numeric part (set a default value if missing)
if not defined HOST_SUFFIX set HOST_SUFFIX=0

for /f "tokens=* delims=0" %%B in ("%HOST_SUFFIX%") do set HOST_SUFFIX=%%B
set /a IP_SUFFIX=100 + %HOST_SUFFIX%

REM Static IP prefix
set IP_PREFIX=192.168.33
REM Subnet mask
set SUBNET_MASK=255.255.255.0
REM Default gateway
set GATEWAY=192.168.33.254
REM Preferred DNS server
set DNS=192.168.30.60
REM Alternate DNS server
set ALT_DNS=192.168.30.70

REM Build the IP address from the host name suffix
set IP_ADDRESS=%IP_PREFIX%.%IP_SUFFIX%

REM Resolve the interface index of the first physical adapter in Up state.
REM netsh accepts a numeric index in place of the adapter name, which avoids
REM passing a localized name through a code page conversion.
REM The index is written to a temp file because reading it directly through
REM for /f produced a blank value on some hosts.
set IFTMP=%TEMP%\ifindex_%RANDOM%.txt
powershell.exe -NoProfile -Command "$a = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Sort-Object ifIndex | Select-Object -First 1; if ($a) { [string]$a.ifIndex | Set-Content -Path '%IFTMP%' -Encoding ASCII -NoNewline }"
set IFINDEX=
if exist "%IFTMP%" set /p IFINDEX=<"%IFTMP%"
del "%IFTMP%" >nul 2>&1
if not defined IFINDEX (
    echo [ERROR] No physical adapter in Up state was found.
    pause
    exit /b 1
)
echo   Adapter ifIndex: %IFINDEX%

REM --- Back up and clear existing persistent routes ---
REM The registry key is exported first so the previous state can be restored.
REM All persistent routes are removed, including any stale default route that
REM would otherwise survive future gateway changes. The netsh command below
REM re-creates the active default route immediately.
set REGKEY=HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\PersistentRoutes
set BKDIR=C:\temp\route_backup
if not exist "%BKDIR%" mkdir "%BKDIR%"
set TS=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%
set TS=%TS: =0%
set REGBK=%BKDIR%\PersistentRoutes_%COMPUTERNAME%_%TS%.reg
set LOGBK=%BKDIR%\route_print_%COMPUTERNAME%_%TS%.log

echo Backing up PersistentRoutes...
reg export "%REGKEY%" "%REGBK%" /y >nul 2>&1
if errorlevel 1 (
    echo   [WARN] Backup skipped. The key does not exist because this PC
    echo          has no persistent routes yet.
) else (
    echo   Saved: %REGBK%
)
route print -4 > "%LOGBK%"
echo   Route table: %LOGBK%
echo.

echo ===== Persistent routes (before) =====
reg query "%REGKEY%" 2>nul
echo.

REM Delete every persistent route. Only value lines are processed:
REM they always end with the REG_SZ type, while the key header line
REM printed by reg query does not.
echo Deleting all persistent routes...
set DELCOUNT=0
for /f "tokens=1,2,3 delims=," %%a in ('reg query "%REGKEY%" 2^>nul ^| findstr /c:"REG_SZ"') do (
    echo   DEL  %%a mask %%b via %%c
    route delete %%a mask %%b %%c >nul 2>&1
    set /a DELCOUNT+=1
)
echo   Deleted: !DELCOUNT!
echo.

REM Apply network settings. netsh is used with the numeric interface index.
REM validate=no skips the DNS reachability probe, which often fails right
REM after the adapter is reconfigured and prints a misleading error even
REM though the setting is applied correctly.
echo Applying: %IP_ADDRESS%
netsh interface ipv4 set address name=%IFINDEX% static %IP_ADDRESS% %SUBNET_MASK% %GATEWAY%
netsh interface ipv4 set dns name=%IFINDEX% static %DNS% validate=no
netsh interface ipv4 add dns name=%IFINDEX% %ALT_DNS% index=2 validate=no

REM Verify the address was actually applied. netsh can return a non-zero
REM exit code on a harmless warning, so the address itself is checked.
REM The check is retried because the stack needs a moment to settle.
set IPOK=0
for /l %%r in (1,1,10) do (
    if "!IPOK!"=="0" (
        ipconfig | findstr /c:"%IP_ADDRESS%" >nul && set IPOK=1
        if "!IPOK!"=="0" timeout /t 1 /nobreak >nul
    )
)
if "!IPOK!"=="0" (
    echo [ERROR] IP address %IP_ADDRESS% was not applied.
    echo         Restore routes with: "%REGBK%" then reboot.
    ipconfig
    pause
    exit /b 1
)
echo   Applied: %IP_ADDRESS%
echo.

REM --- Static routes to core segments via L3 switch (bypass SonicWall hairpin) ---
REM Static-IP hosts do not receive DHCP Option 121, so persistent routes are added here.
set L3_GW=192.168.33.1
echo Adding static routes via %L3_GW% ...
route add 192.168.30.0 mask 255.255.255.0 %L3_GW% -p
route add 192.168.61.61 mask 255.255.255.255 %L3_GW% -p

echo.
echo ===== Persistent routes (after) =====
reg query "%REGKEY%" 2>nul
echo.
echo ===== DNS servers =====
netsh interface ipv4 show dnsservers name=%IFINDEX%
echo.

REM Completion message
echo IP address has been set to %IP_ADDRESS%.
echo   Route backup: %REGBK%
echo --------------------------------------------
echo.
echo.
pause
