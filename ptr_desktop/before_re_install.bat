@echo off

for /f "tokens=3 delims=\ " %%i in ('whoami /groups^|find "Mandatory"') do set LEVEL=%%i
if NOT "%LEVEL%"=="High" (
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "Start-Process '%~f0' -Verb runas"
exit
)

REM ���[�U�[�t�H���_�̃p�X��ݒ�
set TARGET_DIR=%USERPROFILE%\AppData\Roaming\Shotgun

echo --------------------------------------------
REM ���݊m�F�ƍ폜����
if exist "%TARGET_DIR%" (
    echo �t�H���_���폜���Ă��܂�: "%TARGET_DIR%"
    rmdir /s /q "%TARGET_DIR%"
    echo �폜���������܂����B
) else (
    echo �t�H���_�͑��݂��܂���: "%TARGET_DIR%"
)

REG DELETE "HKCU\Software\Shotgun Software\tk-desktop" /f
echo Shotgun Software\tk-desktop ���W�X�g�����폜���܂����B
echo --------------------------------------------
echo.
echo.

timeout /t 2 /nobreak >nul
