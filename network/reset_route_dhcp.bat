@echo off
setlocal enabledelayedexpansion
::-----------------------------------------
:: reset_route_dhcp.bat
::   1. Back up PersistentRoutes registry key
::   2. Delete all persistent static routes (except default route)
::   3. ipconfig /renew  -> receive DHCP Option 121 routes
::   4. Verify expected routes are present
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
:: DHCP check
::   Abort if no connected IPv4 interface uses DHCP.
::   Static-IP machines will not receive Option 121,
::   so deleting their routes would break connectivity.
::-----------------------------------------
set DHCPIF=
for /f "usebackq delims=" %%d in (`powershell.exe -NoProfile -Command "(Get-NetIPInterface -AddressFamily IPv4 -Dhcp Enabled -ConnectionState Connected | Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } | Measure-Object).Count"`) do set DHCPIF=%%d

if "%DHCPIF%"=="" set DHCPIF=0
if "%DHCPIF%"=="0" (
    echo [ERROR] No connected DHCP-enabled IPv4 interface found.
    echo         This PC appears to use a static IP. Aborting without changes.
    pause
    exit /b 1
)
echo DHCP-enabled interface count: %DHCPIF%
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
set REGKEY=HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\PersistentRoutes

::-----------------------------------------
:: Registry backup (full restore point for persistent routes)
::-----------------------------------------
echo Backing up PersistentRoutes...
reg export "%REGKEY%" "%REGBK%" /y
if errorlevel 1 (
    echo [ERROR] Registry backup failed. Aborting.
    pause
    exit /b 1
)
echo   Saved: %REGBK%

:: Save full route table for reference
route print -4 > "%LOGBK%"
echo   Route table: %LOGBK%
echo.

::-----------------------------------------
:: Show persistent routes before deletion
::-----------------------------------------
echo ===== Persistent routes (before) =====
reg query "%REGKEY%"
echo.

::-----------------------------------------
:: Delete all persistent routes
::   Registry value name format: dest,mask,gw,metric
::   Default route (0.0.0.0) is skipped for safety.
::-----------------------------------------
echo Deleting persistent routes...
set DELCOUNT=0
set SKIPCOUNT=0
for /f "tokens=1,2,3 delims=," %%a in ('reg query "%REGKEY%" ^| findstr /r "^    "') do (
    if "%%a"=="0.0.0.0" (
        echo   SKIP  %%a mask %%b via %%c  ^(default route^)
        set /a SKIPCOUNT+=1
    ) else (
        echo   DEL   %%a mask %%b via %%c
        route delete %%a mask %%b %%c >nul 2>&1
        set /a DELCOUNT+=1
    )
)
echo   Deleted: !DELCOUNT!  Skipped: !SKIPCOUNT!
echo.

::-----------------------------------------
:: Renew DHCP lease
::   /renew only (no /release) so the current IP is kept
::   and remote sessions are not dropped.
::-----------------------------------------
echo Renewing DHCP lease...
ipconfig /renew >nul
if errorlevel 1 (
    echo [WARN] ipconfig /renew returned an error. Check output below.
)
timeout /t 3 /nobreak >nul
echo.

::-----------------------------------------
:: Verify routes received via Option 121
::-----------------------------------------
echo ===== Active IPv4 routes for target networks =====
route print -4 | findstr /c:"192.168.30.0" /c:"192.168.61.61" /c:"192.168.33.0" /c:"192.168.70.0"
echo.

set MISSING=0
route print -4 | findstr /c:"192.168.30.0" >nul || set MISSING=1

if "%MISSING%"=="1" (
    echo [WARN] Route to 192.168.30.0/24 was NOT found after renew.
    echo        Possible causes: DHCP scope has no Option 121, or lease not refreshed.
    echo        To restore previous routes: double-click "%REGBK%" then reboot,
    echo        or re-add manually with: route add 192.168.30.0 mask 255.255.255.0 192.168.80.1 -p
) else (
    echo [OK] Route to 192.168.30.0/24 is present.
)
echo.

echo ===== Persistent routes (after) =====
reg query "%REGKEY%"
echo.
echo Done.
echo   Backup: %REGBK%
echo   Restore: double-click the .reg file and reboot, or re-add routes with route add -p
pause
