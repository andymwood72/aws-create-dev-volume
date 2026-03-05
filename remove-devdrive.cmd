@echo off
setlocal EnableExtensions

set "SCRIPT_NAME=%~nx0"
set "VHD_PATH="
set "DELETE_VHD=0"
set "FORCE=0"

if "%~1"=="" goto :haveran

:parse
if "%~1"=="" goto :haveran
if /I "%~1"=="--path" (
    set "VHD_PATH=%~2"
    shift & shift
    goto :parse
)
if /I "%~1"=="--delete" (
    set "DELETE_VHD=1"
    shift
    goto :parse
)
if /I "%~1"=="--force" (
    set "FORCE=1"
    shift
    goto :parse
)
if /I "%~1"=="-h" goto :help
if /I "%~1"=="--help" goto :help

echo Unknown argument: %~1
goto :help

:haveran
if not defined VHD_PATH (
    call :findExistingDevDrive EXISTING_DEVDRIVE
    if not defined EXISTING_DEVDRIVE (
        echo No Dev Drive found.
        exit /b 1
    )
    call :resolveVhdPathFromLetter %EXISTING_DEVDRIVE% VHD_PATH
    if not defined VHD_PATH (
        echo Unable to resolve VHDX path from drive %EXISTING_DEVDRIVE%:.
        exit /b 1
    )
)

net session >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
    echo Run this script from an elevated Command Prompt.
    exit /b 1
)

if not exist "%VHD_PATH%" (
    echo VHDX not found: %VHD_PATH%
    exit /b 1
)

set "DP_SCRIPT=%TEMP%\devdrive_detach_%RANDOM%.txt"
(
    echo select vdisk file="%VHD_PATH%"
    echo detach vdisk
) > "%DP_SCRIPT%"

diskpart /s "%DP_SCRIPT%"
set "DP_EXIT=%ERRORLEVEL%"
del /f /q "%DP_SCRIPT%" >nul 2>&1
if not "%DP_EXIT%"=="0" (
    echo diskpart detach failed.
    exit /b 1
)

if "%DELETE_VHD%"=="1" (
    if "%FORCE%"=="1" (
        del /f /q "%VHD_PATH%" >nul 2>&1
    ) else (
        choice /M "Delete VHDX file?"
        if errorlevel 2 (
            echo Detached. File kept.
            exit /b 0
        )
        del /f /q "%VHD_PATH%" >nul 2>&1
    )
)

echo Dev Drive detached.
exit /b 0

:findExistingDevDrive
set "FOUND="
set "QUERY_TMP=%TEMP%\devdrive_query_%RANDOM%.txt"
for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%L:\" (
        fsutil devdrv query %%L: > "%QUERY_TMP%" 2>&1
        findstr /I /C:"dev drive" /C:"developer volume" "%QUERY_TMP%" >nul
        if not errorlevel 1 (
            findstr /I /C:"not a dev drive" /C:"not a developer volume" /C:"is not a developer volume" "%QUERY_TMP%" >nul
            if errorlevel 1 (
                set "FOUND=%%L"
                goto :found
            )
        )
    )
)
:found
del /f /q "%QUERY_TMP%" >nul 2>&1
set "%~1=%FOUND%"
exit /b 0

:resolveVhdPathFromLetter
set "LETTER=%~1"
set "OUT_TMP=%TEMP%\devdrive_detail_%RANDOM%.txt"
set "DP_SCRIPT=%TEMP%\devdrive_detail_%RANDOM%.txt"
(
    echo select volume %LETTER%
    echo detail disk
) > "%DP_SCRIPT%"

diskpart /s "%DP_SCRIPT%" > "%OUT_TMP%" 2>&1
set "DP_EXIT=%ERRORLEVEL%"
del /f /q "%DP_SCRIPT%" >nul 2>&1
if not "%DP_EXIT%"=="0" (
    del /f /q "%OUT_TMP%" >nul 2>&1
    exit /b 1
)

set "FOUND_PATH="
for /f "usebackq delims=" %%L in ("%OUT_TMP%") do (
    echo %%L | findstr /I /C:"Location Path" >nul
    if not errorlevel 1 (
        for /f "tokens=2,* delims=:" %%A in ("%%L") do (
            set "FOUND_PATH=%%A:%%B"
        )
    )
)
del /f /q "%OUT_TMP%" >nul 2>&1

if defined FOUND_PATH (
    for /f "tokens=* delims= " %%X in ("%FOUND_PATH%") do set "FOUND_PATH=%%X"
    set "%~2=%FOUND_PATH%"
)
exit /b 0

:help
echo.
echo %SCRIPT_NAME% - detach a VHDX Dev Drive.
echo.
echo Usage:
echo   %SCRIPT_NAME% [--path "C:\DevDrives\devdrive.vhdx"] [--delete] [--force]
echo.
echo Options:
echo   --path    Optional. VHDX path to detach. If omitted, auto-detects dev drive.
echo   --delete  Optional. Delete the VHDX after detaching.
echo   --force   Optional. Skip delete confirmation.
echo.
exit /b 1
