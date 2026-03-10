@echo off
setlocal EnableExtensions

set "SCRIPT_NAME=%~nx0"
set "VHD_PATH="
set "DELETE_VHD=0"
set "FORCE=0"
set "DEFAULTS=0"

if "%~1"=="" goto :help

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
if /I "%~1"=="--defaults" (
    set "DEFAULTS=1"
    shift
    goto :parse
)
if /I "%~1"=="-h" goto :help
if /I "%~1"=="--help" goto :help

echo Unknown argument: %~1
goto :help

:haveran
if "%DEFAULTS%"=="1" set "VHD_PATH="
net session >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
    echo Run this script from an elevated Command Prompt.
    exit /b 1
)
if defined VHD_PATH goto :havePath
call :findExistingDevDrive EXISTING_DEVDRIVE
for /f "tokens=* delims= " %%X in ("%EXISTING_DEVDRIVE%") do set "EXISTING_DEVDRIVE=%%X"
if "%EXISTING_DEVDRIVE%"=="" set "EXISTING_DEVDRIVE="
if "%EXISTING_DEVDRIVE: =%"=="" set "EXISTING_DEVDRIVE="
if not defined EXISTING_DEVDRIVE (
    echo No Dev Drive found.
    exit /b 1
)
call :resolveVhdPathFromLetter %EXISTING_DEVDRIVE% VHD_PATH
if not defined VHD_PATH (
    echo Unable to resolve VHDX path from drive %EXISTING_DEVDRIVE%:.
    exit /b 1
)
:havePath

for %%P in ("%VHD_PATH%") do echo Dev Drive path: %%~fP

if not exist "%VHD_PATH%" (
    echo VHDX not found: %VHD_PATH%
    exit /b 1
)
if exist "%VHD_PATH%\NUL" (
    echo VHDX path resolved to a directory: %VHD_PATH%
    exit /b 1
)
set "VHD_EXT="
for %%P in ("%VHD_PATH%") do set "VHD_EXT=%%~xP"
if /I not "%VHD_EXT%"==".vhdx" if /I not "%VHD_EXT%"==".vhd" (
    echo VHDX path does not look like a VHD/VHDX file: %VHD_PATH%
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
    if exist "%VHD_PATH%\NUL" (
        echo Refusing to delete because path is a directory: %VHD_PATH%
        exit /b 1
    )
    set "VHD_EXT="
    for %%P in ("%VHD_PATH%") do set "VHD_EXT=%%~xP"
    if /I not "%VHD_EXT%"==".vhdx" if /I not "%VHD_EXT%"==".vhd" (
        echo Refusing to delete because path is not a VHD/VHDX file: %VHD_PATH%
        exit /b 1
    )
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
fsutil devdrv query > "%QUERY_TMP%" 2>&1
if "%ERRORLEVEL%"=="0" (
    for /f "tokens=* delims= " %%L in ('findstr /I /C:"Dev Drive" /C:"Developer volume" "%QUERY_TMP%"') do (
        for %%T in (%%L) do (
            echo %%T | findstr /R /I "^[A-Z]:$" >nul
            if not errorlevel 1 set "FOUND=%%T"
        )
    )
)
if defined FOUND (
    set "FOUND=%FOUND::=%"
    del /f /q "%QUERY_TMP%" >nul 2>&1
    goto :found
)
del /f /q "%QUERY_TMP%" >nul 2>&1
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
if defined FOUND (
    for /f "tokens=* delims= " %%X in ("%FOUND%") do set "FOUND=%%X"
)
if defined FOUND (
    set "%~1=%FOUND%"
) else (
    set "%~1="
)
exit /b 0

:resolveVhdPathFromLetter
set "LETTER=%~1"
set "FOUND_PATH="
set "VDISK_TMP=%TEMP%\devdrive_vdisk_%RANDOM%.txt"
set "DP_SCRIPT=%TEMP%\devdrive_vdisk_%RANDOM%.txt"
(
    echo list vdisk
) > "%DP_SCRIPT%"

diskpart /s "%DP_SCRIPT%" > "%VDISK_TMP%" 2>&1
set "DP_EXIT=%ERRORLEVEL%"
del /f /q "%DP_SCRIPT%" >nul 2>&1
if "%DP_EXIT%"=="0" (
    for /f "tokens=1,2,3,4,5,6,7,8,*" %%A in ('findstr /R /C:"^ *VDisk [0-9]" "%VDISK_TMP%"') do (
        if /I not "%%F"=="Unknown" (
            if /I "%%G"=="open" if /I "%%H"=="Expandable" (
                if not "%%I"=="" set "FOUND_PATH=%%I"
            ) else (
                if not "%%G"=="" set "FOUND_PATH=%%G %%H"
            )
        )
    )
)
del /f /q "%VDISK_TMP%" >nul 2>&1

if defined FOUND_PATH (
    for /f "tokens=* delims= " %%X in ("%FOUND_PATH%") do set "FOUND_PATH=%%X"
    set "%~2=%FOUND_PATH%"
    exit /b 0
)
set "VOL_TMP=%TEMP%\devdrive_vol_%RANDOM%.txt"
set "DP_SCRIPT=%TEMP%\devdrive_vol_%RANDOM%.txt"
(
    echo select volume %LETTER%
    echo detail volume
) > "%DP_SCRIPT%"

diskpart /s "%DP_SCRIPT%" > "%VOL_TMP%" 2>&1
set "DP_EXIT=%ERRORLEVEL%"
del /f /q "%DP_SCRIPT%" >nul 2>&1
if not "%DP_EXIT%"=="0" (
    del /f /q "%VOL_TMP%" >nul 2>&1
    exit /b 1
)

set "DISK_NUM="
for /f "tokens=1,2,3" %%A in ('findstr /R /C:"Disk [0-9]" "%VOL_TMP%"') do (
    if /I "%%A"=="Disk" set "DISK_NUM=%%B"
    if /I "%%B"=="Disk" set "DISK_NUM=%%C"
)
del /f /q "%VOL_TMP%" >nul 2>&1
if not defined DISK_NUM exit /b 1

set "OUT_TMP=%TEMP%\devdrive_detail_%RANDOM%.txt"
set "DP_SCRIPT=%TEMP%\devdrive_detail_%RANDOM%.txt"
(
    echo select disk %DISK_NUM%
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
for /f "tokens=1,* delims=:" %%A in ('findstr /I /C:"Location Path" "%OUT_TMP%"') do (
    set "FOUND_PATH=%%B"
)
if not defined FOUND_PATH (
    for /f "tokens=1,* delims=:" %%A in ('findstr /I /C:"Virtual Disk" "%OUT_TMP%"') do (
        set "FOUND_PATH=%%B"
    )
)
if not defined FOUND_PATH (
    for /f "tokens=1,* delims=:" %%A in ('findstr /I /C:"File:" "%OUT_TMP%"') do (
        set "FOUND_PATH=%%B"
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
echo Running without parameters shows this help.
echo.
echo Options:
echo   --path    Optional. VHDX path to detach. If omitted, auto-detects dev drive.
echo   --delete  Optional. Prompt to delete the VHDX after detaching.
echo   --force   Optional. Skip delete confirmation when using --delete.
echo   --defaults Optional. Remove the default Dev Drive (auto-detect).
echo             Safe delete: only deletes .vhd/.vhdx file paths, never directories.
echo.
exit /b 1
