@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process %~f0 -Verb runas"
exit
)

REM --- 1) ���� "C:\Program Files\madVR" �t�H���_������΃A���C���X�g�[�� ---
IF EXIST "C:\Program Files\madVR\uninstall.bat" (
    echo [INFO] madVR ���C���X�g�[���ς݂̂��߁Auninstall.bat �����s���܂�...
    pushd "C:\Program Files\madVR"
    call uninstall.bat
    popd
)

REM --- 2) ������ "C:\Program Files\madVR" �t�H���_���폜 ---
IF EXIST "C:\Program Files\madVR" (
    echo [INFO] ������ madVR �t�H���_���폜���܂�...
    RD /S /Q "C:\Program Files\madVR"
)

REM --- 3) �����ꏊ�ɂ��� "madVR.zip" ��W�J���� "C:\Program Files\madVR" �ɃR�s�[ ---
echo [INFO] madVR.zip �� "C:\Program Files\madVR" �ɉ𓀂��܂�...
powershell -Command "Expand-Archive -LiteralPath 'madVR.zip' -DestinationPath 'C:\Program Files\madVR'"

REM --- 4) "install.bat" �����s���� madVR �����W�X�g���o�^ ---
echo [INFO] install.bat �����s���܂�...
pushd "C:\Program Files\madVR"
call install.bat

REM --- 5) "madVRtoPotPlayerMini64.reg" �����s (���W�X�g������荞��) ---
echo [INFO] madVRtoPotPlayerMini64.reg �����s���܂�...
reg import "madVRtoPotPlayerMini64.reg"

popd

echo [INFO] �S�Ă̏������������܂����B
pause