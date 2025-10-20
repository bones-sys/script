@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

REM ホスト名を取得
for /f "tokens=2 delims=_" %%A in ('hostname') do set HOST_SUFFIX=%%A

REM 数値部分に100を加算（デフォルト値を設定）
if not defined HOST_SUFFIX set HOST_SUFFIX=0

for /f "tokens=* delims=0" %%B in ("%HOST_SUFFIX%") do set HOST_SUFFIX=%%B
set /a IP_SUFFIX=100 + %HOST_SUFFIX%

REM ネットワークアダプター名（環境に応じて変更）
set NETWORK_ADAPTER_NAME="イーサネット"
REM 固定IPアドレスのプレフィックス
set IP_PREFIX=192.168.33
REM サブネットマスク
set SUBNET_MASK=255.255.255.0
REM デフォルトゲートウェイ
set GATEWAY=192.168.33.254
REM 優先DNSサーバー
set DNS=192.168.30.60
REM 代替DNSサーバー
set ALT_DNS=192.168.30.70

REM IPアドレスの末尾をホスト名から設定
set IP_ADDRESS=%IP_PREFIX%.%IP_SUFFIX%

REM ネットワーク設定を変更
echo 設定中: %IP_ADDRESS%
netsh interface ip set address name=%NETWORK_ADAPTER_NAME% static %IP_ADDRESS% %SUBNET_MASK% %GATEWAY%
netsh interface ip set dns name=%NETWORK_ADAPTER_NAME% static %DNS%
netsh interface ip add dns name=%NETWORK_ADAPTER_NAME% %ALT_DNS% index=2

REM 完了メッセージ
echo IPアドレスが %IP_ADDRESS% に設定されました。


pause