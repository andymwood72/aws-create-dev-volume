@echo off
setlocal EnableExtensions

set "SCRIPT_NAME=%~nx0"

if /I "%~1"=="-h" goto :help
if /I "%~1"=="--help" goto :help

net session >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
    echo Run this script from an elevated Command Prompt.
    exit /b -1
)

call :queryDevDriveStatus STATUS
call :queryAvFilterStatus AV_STATUS
call :findExistingDevDrive EXISTING_DEVDRIVE

echo Dev Drive support: %STATUS%
if /I "%STATUS%"=="Disabled" (
    echo Not configured.
    echo Antivirus filter: n/a
    echo Dev Drive volume: none
    echo File System Type: n/a
    exit /b -1
)

if defined EXISTING_DEVDRIVE goto :showDrive
goto :showNone

:showDrive
set "VHD_PATH=UNAVAILABLE"
call :resolveVhdPathFromLetter %EXISTING_DEVDRIVE% VHD_PATH
if not defined VHD_PATH set "VHD_PATH=UNAVAILABLE"
call :queryFormatType %EXISTING_DEVDRIVE% FORMAT_TYPE
echo Antivirus filter: %AV_STATUS%
echo Dev Drive volume: %EXISTING_DEVDRIVE%:
echo Dev Drive path: %VHD_PATH%
echo File System Type: %FORMAT_TYPE%
exit /b 0

:showNone
echo Dev Drive volume: none
echo Antivirus filter: %AV_STATUS%
echo Dev Drive path: n/a
echo File System Type: n/a
exit /b 0

:queryDevDriveStatus
set "STATUS=Unknown"
set "QUERY_TMP=%TEMP%\devdrive_status_%RANDOM%.txt"
fsutil devdrv query > "%QUERY_TMP%" 2>&1
if not "%ERRORLEVEL%"=="0" (
    set "STATUS=Unknown"
    del /f /q "%QUERY_TMP%" >nul 2>&1
    set "%~1=%STATUS%"
    exit /b 0
)

findstr /I /C:"disabled" "%QUERY_TMP%" >nul
if not errorlevel 1 (
    set "STATUS=Disabled"
    goto :statusdone
)

findstr /I /C:"enabled" "%QUERY_TMP%" >nul
if not errorlevel 1 (
    set "STATUS=Enabled"
)

:statusdone
del /f /q "%QUERY_TMP%" >nul 2>&1
set "%~1=%STATUS%"
exit /b 0

:queryAvFilterStatus
set "AV_STATUS=Unknown"
set "QUERY_TMP=%TEMP%\devdrive_av_%RANDOM%.txt"
fsutil devdrv query > "%QUERY_TMP%" 2>&1
if not "%ERRORLEVEL%"=="0" (
    del /f /q "%QUERY_TMP%" >nul 2>&1
    set "%~1=%AV_STATUS%"
    exit /b 0
)

set "AV_TMP=%TEMP%\devdrive_avline_%RANDOM%.txt"
findstr /I /C:"Developer volumes are protected by antivirus filter" "%QUERY_TMP%" > "%AV_TMP%"
if not errorlevel 1 (
    set "AV_STATUS=Allowed"
) else (
    findstr /I /C:"Developer volumes are not protected by antivirus filter" "%QUERY_TMP%" > "%AV_TMP%"
    if not errorlevel 1 set "AV_STATUS=Disallowed"
)

del /f /q "%AV_TMP%" >nul 2>&1
del /f /q "%QUERY_TMP%" >nul 2>&1
set "%~1=%AV_STATUS%"
exit /b 0

:queryFormatType
set "LETTER=%~1"
set "FORMAT_TYPE=Unknown"
for /f "delims=:" %%D in ("%LETTER%") do set "LETTER=%%D"
set "LETTER=%LETTER:~0,1%"
if "%LETTER%"=="" (
    set "%~2=%FORMAT_TYPE%"
    exit /b 0
)
set "FSINFO_TMP=%TEMP%\devdrive_fsinfo_%RANDOM%.txt"
fsutil fsinfo volumeinfo %LETTER%: > "%FSINFO_TMP%" 2>&1
if not "%ERRORLEVEL%"=="0" (
    del /f /q "%FSINFO_TMP%" >nul 2>&1
    set "%~2=%FORMAT_TYPE%"
    exit /b 0
)

for /f "tokens=1,* delims=:" %%A in ('findstr /I /C:"File System Name" "%FSINFO_TMP%"') do (
    set "FORMAT_TYPE=%%B"
)
if "%FORMAT_TYPE%"=="Unknown" (
    for /f "tokens=1,* delims=:" %%A in ('findstr /I /C:"File System" "%FSINFO_TMP%"') do (
        set "FORMAT_TYPE=%%B"
    )
)
if "%FORMAT_TYPE%"=="Unknown" (
    for /f "tokens=2 delims==" %%A in ('wmic logicaldisk where "DeviceID='%LETTER%:'" get FileSystem /value ^| findstr /I "FileSystem"') do (
        set "FORMAT_TYPE=%%A"
    )
)
if "%FORMAT_TYPE%"=="Unknown" (
    findstr /I /C:"ReFS" "%FSINFO_TMP%" >nul
    if not errorlevel 1 set "FORMAT_TYPE=ReFS"
)
del /f /q "%FSINFO_TMP%" >nul 2>&1
for /f "tokens=* delims= " %%X in ("%FORMAT_TYPE%") do set "FORMAT_TYPE=%%X"
set "%~2=%FORMAT_TYPE%"
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
    for /f "tokens=1,2,3,4,5,6,7,*" %%A in ('findstr /R /C:"^ *VDisk [0-9]" "%VDISK_TMP%"') do (
        if /I not "%%F"=="Unknown" (
            if not "%%G"=="" set "FOUND_PATH=%%G %%H"
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
echo %SCRIPT_NAME% - show Dev Drive status and volume.
echo.
echo Usage:
echo   %SCRIPT_NAME%
echo.
exit /b 0
