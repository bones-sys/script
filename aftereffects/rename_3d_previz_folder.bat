@echo off
setlocal enabledelayedexpansion

rem ���� UNC���h���C�u�}�b�s���O ����
pushd "%~dp0"
set "ROOT=%CD%\"

rem ���� 1�K�w�� ����
for /D %%A in ("%ROOT%*") do (
    rem ���� 2�K�w�� ����
    for /D %%B in ("%%~fA\*") do (
        rem ���� 3�K�w�� ����
        for /D %%C in ("%%~fB\*") do (
            rem �t�H���_���� __CGLO �Ȃ烊�l�[��
            if /I "%%~nxC"=="__CGLO" (
                echo Renaming "%%~fC" to "___3D_PREVIZ"
                ren "%%~fC" "___3D_PREVIZ"
            )
        )
    )
)

rem ���� ��Еt�� ����
popd

pause