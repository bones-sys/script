@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

REM �z�X�g�����擾
for /f "tokens=2 delims=_" %%A in ('hostname') do set HOST_SUFFIX=%%A

REM ���l������100�����Z�i�f�t�H���g�l��ݒ�j
if not defined HOST_SUFFIX set HOST_SUFFIX=0

for /f "tokens=* delims=0" %%B in ("%HOST_SUFFIX%") do set HOST_SUFFIX=%%B
set /a IP_SUFFIX=100 + %HOST_SUFFIX%

REM �l�b�g���[�N�A�_�v�^�[���i���ɉ����ĕύX�j
set NETWORK_ADAPTER_NAME="�C�[�T�l�b�g"
REM �Œ�IP�A�h���X�̃v���t�B�b�N�X
set IP_PREFIX=192.168.33
REM �T�u�l�b�g�}�X�N
set SUBNET_MASK=255.255.255.0
REM �f�t�H���g�Q�[�g�E�F�C
set GATEWAY=192.168.33.254
REM �D��DNS�T�[�o�[
set DNS=192.168.30.60
REM ���DNS�T�[�o�[
set ALT_DNS=192.168.30.70

REM IP�A�h���X�̖������z�X�g������ݒ�
set IP_ADDRESS=%IP_PREFIX%.%IP_SUFFIX%

REM �l�b�g���[�N�ݒ��ύX
echo �ݒ蒆: %IP_ADDRESS%
netsh interface ip set address name=%NETWORK_ADAPTER_NAME% static %IP_ADDRESS% %SUBNET_MASK% %GATEWAY%
netsh interface ip set dns name=%NETWORK_ADAPTER_NAME% static %DNS%
netsh interface ip add dns name=%NETWORK_ADAPTER_NAME% %ALT_DNS% index=2

REM �������b�Z�[�W
echo IP�A�h���X�� %IP_ADDRESS% �ɐݒ肳��܂����B


pause