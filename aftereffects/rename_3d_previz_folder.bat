@echo off
setlocal enabledelayedexpansion

rem ── UNC→ドライブマッピング ──
pushd "%~dp0"
set "ROOT=%CD%\"

rem ── 1階層目 ──
for /D %%A in ("%ROOT%*") do (
    rem ── 2階層目 ──
    for /D %%B in ("%%~fA\*") do (
        rem ── 3階層目 ──
        for /D %%C in ("%%~fB\*") do (
            rem フォルダ名が __CGLO ならリネーム
            if /I "%%~nxC"=="__CGLO" (
                echo Renaming "%%~fC" to "___3D_PREVIZ"
                ren "%%~fC" "___3D_PREVIZ"
            )
        )
    )
)

rem ── 後片付け ──
popd

pause