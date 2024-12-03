@echo off
REM ホスト名を取得
for /f "tokens=2 delims=_" %%A in ('hostname') do set HOST_SUFFIX=%%A

REM 数値部分に100を加算
set /a IP_SUFFIX=100 + %HOST_SUFFIX%

REM IPアドレスを固定する設定
REM 必要に応じて以下の値を変更してください
REM ネットワークアダプター名（例: "Wi-Fi", "Ethernet"）
set NETWORK_ADAPTER_NAME="Ethernet"
REM 固定IPアドレスのプレフィックス
set IP_PREFIX=192.168.33
REM サブネットマスク
set SUBNET_MASK=255.255.255.0
REM デフォルトゲートウェイ
set GATEWAY=192.168.33.1
REM 優先DNSサーバー
set DNS=8.8.8.8

REM IPアドレスの末尾をホスト名から設定
set IP_ADDRESS=%IP_PREFIX%.%IP_SUFFIX%

REM ネットワーク設定を変更
echo 設定中: %IP_ADDRESS%
netsh interface ip set address name=%NETWORK_ADAPTER_NAME% static %IP_ADDRESS% %SUBNET_MASK% %GATEWAY%