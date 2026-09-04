@echo off
setlocal enabledelayedexpansion
::-----------------------------------------
:: set_network_v33.bat
::   Network-only setup for static-IP hosts on 192.168.33.0/24
::   1. Derive IP from hostname suffix (NAME_xx -> 192.168.33.(100+xx))
::   2. Set static IP / mask / gateway / DNS
::   3. Add persistent routes to core segments via L3 switch
::      (static-IP hosts do not receive DHCP Option 121)
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
::-----------------------------------------
set IP_PREFIX=192.168.33
set SUBNET_MASK=255.255.255.0
set GATEWAY=192.168.33.254
set DNS=192.168.30.60
set ALT_DNS=192.168.30.70
set L3_GW=192.168.33.1

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
:: Detect the physical adapter that is currently Up
::   (avoids hard-coding a localized adapter name)
::-----------------------------------------
set ADAPTER=
for /f "usebackq delims=" %%N in (`powershell.exe -NoProfile -Command "(Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Sort-Object ifIndex | Select-Object -First 1).Name"`) do set ADAPTER=%%N
if not defined ADAPTER (
    echo [ERROR] No physical adapter in Up state was found.
    pause
    exit /b 1
)

::-----------------------------------------
:: Confirm before applying
::-----------------------------------------
echo ===== Planned network settings =====
echo   Hostname : %COMPUTERNAME%
echo   Adapter  : %ADAPTER%
echo   IP       : %IP_ADDRESS% / %SUBNET_MASK%
echo   Gateway  : %GATEWAY%
echo   DNS      : %DNS%, %ALT_DNS%
echo   Routes   : 192.168.30.0/24 and 192.168.61.61/32 via %L3_GW% (persistent)
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
:: Apply IP / DNS
::-----------------------------------------
echo Setting static IP %IP_ADDRESS% on "%ADAPTER%" ...
netsh interface ip set address name="%ADAPTER%" static %IP_ADDRESS% %SUBNET_MASK% %GATEWAY%
if errorlevel 1 (
    echo [ERROR] Failed to set IP address. Aborting before route changes.
    pause
    exit /b 1
)
netsh interface ip set dns name="%ADAPTER%" static %DNS%
netsh interface ip add dns name="%ADAPTER%" %ALT_DNS% index=2
echo.

::-----------------------------------------
:: Persistent static routes via L3 switch
::   Delete first so an old entry with a different gateway does not remain.
::-----------------------------------------
echo Adding persistent routes via %L3_GW% ...
route delete 192.168.30.0 mask 255.255.255.0 >nul 2>&1
route add 192.168.30.0 mask 255.255.255.0 %L3_GW% -p
route delete 192.168.61.61 mask 255.255.255.255 >nul 2>&1
route add 192.168.61.61 mask 255.255.255.255 %L3_GW% -p
echo.

::-----------------------------------------
:: Verify
::-----------------------------------------
echo ===== Active routes for target networks =====
route print -4 | findstr /c:"0.0.0.0" /c:"192.168.30.0" /c:"192.168.61.61"
echo.
echo ===== Persistent routes =====
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\PersistentRoutes"
echo.
echo Done. IP address set to %IP_ADDRESS%.
pause
