@echo off
setlocal

REM --- (1) �Ǘ��Ҍ����Ŏ��s����Ă��邩�m�F ---
for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
    powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
    exit
)

REM --- (2) ���̃o�b�`�t�@�C��������t�H���_�Ɉړ� ---
cd /d "%~dp0"
echo [INFO] ���݂̍�ƃf�B���N�g��: %cd%

REM --- (3) ���o�[�W������ madVR ������΃A���C���X�g�[�� ---
if exist "C:\madVR\uninstall.bat" (
    echo [INFO] ������ madVR ���A���C���X�g�[�����܂�...
    pushd "C:\madVR"
    call uninstall.bat
    popd
)

REM --- (4) ���o�[�W�����̃t�H���_���폜 ---
if exist "C:\madVR" (
    echo [INFO] ������ "C:\madVR" �t�H���_���폜���܂�...
    rd /s /q "C:\madVR"
)

REM --- (5) �V���� madVR �t�H���_�����邩�m�F ---
if not exist "madVR\" (
    echo [ERROR] "madVR" �t�H���_��������܂���B�o�b�`�Ɠ����ꏊ�ɒu���Ă��������B
    pause
    exit /b 1
)
if not exist "madVR\install.bat" (
    echo [ERROR] "madVR" �t�H���_���� "install.bat" ������܂���B�������𓀂���Ă��܂����H
    pause
    exit /b 1
)

REM --- (6) "madVR" �t�H���_�� "C:\madVR" �ɃR�s�[ ---
echo [INFO] "madVR" �t�H���_�� "C:\madVR" �ɃR�s�[���܂�...
md "C:\madVR" >nul 2>&1
xcopy /E /H /R /Y "madVR" "C:\madVR" >nul
if %errorlevel% neq 0 (
    echo [ERROR] �R�s�[�Ɏ��s���܂����B�t�H���_��A�N�Z�X�����m�F���Ă��������B
    pause
    exit /b 1
)

REM --- (7) �V���� madVR ���C���X�g�[�� (install.bat) ---
echo [INFO] install.bat �����s���܂�...
pushd "C:\madVR"
call install.bat
if %errorlevel% neq 0 (
    echo [ERROR] install.bat ���s���ɃG���[���������܂����B�Ǘ��Ҍ�����t�@�C���\�����m�F���Ă��������B
    popd
    pause
    exit /b 1
)
popd

REM --- (8) PotPlayer �p���W�X�g���̃C���|�[�g (�����) ---
if exist "madVRtoPotPlayerMini64.reg" (
    echo [INFO] madVRtoPotPlayerMini64.reg ���C���|�[�g���܂�...
    reg import "madVRtoPotPlayerMini64.reg"
) else (
    echo [WARN] madVRtoPotPlayerMini64.reg ��������Ȃ����߃X�L�b�v���܂�...
)

echo.
echo [INFO] ���ׂĂ̏������������܂����B���Ȃ���� madVR �� "C:\madVR" �ɃC���X�g�[������Ă��܂��B
pause
exit /b 0
