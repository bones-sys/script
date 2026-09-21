@echo off
setlocal enabledelayedexpansion
::-----------------------------------------
:: set_network_v33.bat
::   Network-only setup for static-IP hosts on 192.168.33.0/24
::   1. Derive IP from hostname suffix (NAME_xx -> 192.168.33.(100+xx))
::   2. Back up PersistentRoutes registry key and current route table
::   3. Delete ALL persistent routes (including stale per-segment routes)
::   4. Set static IP / mask / gateway / DNS with netsh
::
::   The default gateway is the L3 switch (192.168.33.1), which routes
::   inter-site traffic directly and forwards Internet-bound traffic to
::   the SonicWall (192.168.33.254). Per-segment persistent routes are
::   therefore no longer required and are removed by this script.
::   The SonicWall management UI stays reachable at https://192.168.33.254
::-----------------------------------------

::-----------------------------------------
:: Admin check (Mandatory Level)
::-----------------------------------------
for /f "tokens=3 delims=\ " %%i in ('whoami /groups ^| find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
    echo Relaunching with administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
    exit /b
)
echo Administrator privileges confirmed.
echo.

::-----------------------------------------
:: Network parameters
::   GATEWAY was 192.168.33.254 (SonicWall) before the L3 switch cutover.
::   It is now 192.168.33.1 (L3 switch) to match the DHCP clients.
::-----------------------------------------
set IP_PREFIX=192.168.33
set SUBNET_MASK=255.255.255.0
set GATEWAY=192.168.33.1
set DNS=192.168.30.60
set ALT_DNS=192.168.30.70
set REGKEY=HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\PersistentRoutes

::-----------------------------------------
:: Derive IP suffix from hostname (token after "_")
::-----------------------------------------
set HOST_SUFFIX=
for /f "tokens=2 delims=_" %%A in ('hostname') do set HOST_SUFFIX=%%A
if not defined HOST_SUFFIX (
    echo [ERROR] Hostname has no "_" suffix. Cannot derive IP address.
    hostname
    pause
    exit /b 1
)
:: Strip leading zeros so "05" becomes "5"
for /f "tokens=* delims=0" %%B in ("%HOST_SUFFIX%") do set HOST_SUFFIX=%%B
if not defined HOST_SUFFIX set HOST_SUFFIX=0
set /a IP_SUFFIX=100 + %HOST_SUFFIX%
set IP_ADDRESS=%IP_PREFIX%.%IP_SUFFIX%

::-----------------------------------------
:: Resolve the interface index of the first physical adapter in Up state.
:: netsh accepts a numeric index in place of the adapter name, which avoids
:: passing a localized name through a code page conversion.
:: The index is written to a temp file because reading it directly through
:: for /f produced a blank value on some hosts.
::-----------------------------------------
echo Current adapters:
powershell.exe -NoProfile -Command "Get-NetAdapter -Physical | Sort-Object ifIndex | Format-Table Name, ifIndex, Status -AutoSize"

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

::-----------------------------------------
:: Confirm before applying
::-----------------------------------------
echo ===== Planned network settings =====
echo   Hostname : %COMPUTERNAME%
echo   ifIndex  : %IFINDEX%
echo   IP       : %IP_ADDRESS% / %SUBNET_MASK%
echo   Gateway  : %GATEWAY%  (L3 switch)
echo   DNS      : %DNS%, %ALT_DNS%
echo   Routes   : none. Inter-site traffic follows the default gateway.
echo.
echo   All existing persistent routes will be backed up and then removed.
echo.
echo NOTE: If you are connected remotely and the IP changes, the session will drop.
set /p CONFIRM=Apply these settings? [Y/N]: 
if /i not "%CONFIRM%"=="Y" (
    echo Cancelled. No changes made.
    pause
    exit /b 0
)
echo.

::-----------------------------------------
:: Backup preparation
::-----------------------------------------
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

::-----------------------------------------
:: Show persistent routes before deletion
::-----------------------------------------
echo ===== Persistent routes (before) =====
reg query "%REGKEY%" 2>nul
echo.

::-----------------------------------------
:: Delete every persistent route. Only value lines are processed:
:: they always end with the REG_SZ type, while the key header line
:: printed by reg query does not.
:: This clears the old per-segment routes (192.168.30.0/24 and
:: 192.168.61.61/32 via the L3 switch) that this script used to add,
:: as well as any stale default route. They are not re-added: the
:: default gateway now points at the L3 switch and covers both.
::-----------------------------------------
echo Deleting all persistent routes...
set DELCOUNT=0
for /f "tokens=1,2,3 delims=," %%a in ('reg query "%REGKEY%" 2^>nul ^| findstr /c:"REG_SZ"') do (
    echo   DEL  %%a mask %%b via %%c
    route delete %%a mask %%b %%c >nul 2>&1
    set /a DELCOUNT+=1
)
echo   Deleted: !DELCOUNT!
echo.

::-----------------------------------------
:: Apply network settings. netsh is used with the numeric interface index.
:: validate=no skips the DNS reachability probe, which often fails right
:: after the adapter is reconfigured and prints a misleading error even
:: though the setting is applied correctly.
::-----------------------------------------
echo Setting static IP %IP_ADDRESS% on ifIndex %IFINDEX% ...
netsh interface ipv4 set address name=%IFINDEX% static %IP_ADDRESS% %SUBNET_MASK% %GATEWAY%
netsh interface ipv4 set dns name=%IFINDEX% static %DNS% validate=no
netsh interface ipv4 add dns name=%IFINDEX% %ALT_DNS% index=2 validate=no

:: Verify the address was actually applied. netsh can return a non-zero
:: exit code on a harmless warning, so the address itself is checked.
:: The check is retried because the stack needs a moment to settle.
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

::-----------------------------------------
:: Verify
::-----------------------------------------
echo ===== Default route =====
route print -4 | findstr /c:"0.0.0.0"
echo.
echo ===== Persistent routes (after, should be empty) =====
reg query "%REGKEY%" 2>nul
echo.
echo ===== DNS servers =====
netsh interface ipv4 show dnsservers name=%IFINDEX%
echo.

::-----------------------------------------
:: Reachability check. The default gateway must answer, and the core
:: segment must be reachable through it now that the explicit route
:: is gone. 192.168.33.254 is checked as well because the SonicWall
:: management UI is accessed directly at that address.
::-----------------------------------------
echo ===== Reachability =====
set NGFAIL=0

ping -n 2 %GATEWAY% >nul 2>&1
if errorlevel 1 (
    echo   [WARN] Gateway %GATEWAY% did not respond.
    set NGFAIL=1
) else (
    echo   [OK]   Gateway %GATEWAY%
)

ping -n 2 %DNS% >nul 2>&1
if errorlevel 1 (
    echo   [WARN] Core segment host %DNS% did not respond.
    echo          Check that the L3 switch routes 192.168.30.0/24.
    set NGFAIL=1
) else (
    echo   [OK]   Core segment %DNS%
)

ping -n 2 192.168.33.254 >nul 2>&1
if errorlevel 1 (
    echo   [WARN] SonicWall 192.168.33.254 did not respond.
    set NGFAIL=1
) else (
    echo   [OK]   SonicWall 192.168.33.254
)
echo.

if "%NGFAIL%"=="1" (
    echo [WARN] One or more checks failed.
    echo        To roll back: double-click "%REGBK%" then reboot,
    echo        or re-run this script with GATEWAY set to 192.168.33.254.
) else (
    echo [OK] All reachability checks passed.
)
echo.
echo Done. IP address set to %IP_ADDRESS%.
echo   Backup: %REGBK%
pause
