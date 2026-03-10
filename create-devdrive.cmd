@echo off
setlocal EnableExtensions

set "SCRIPT_NAME=%~nx0"
set "VHD_PATH="
set "SIZE_INPUT=50GB"
set "DRIVE_LETTER=B"
set "LABEL=DevDrive"
set "FILTERS="
set "FORCE=0"
set "AV_MODE=allow"
set "VHD_TYPE=expandable"
set "DEFAULTS=0"
set "DEFAULTS_LOCK=0"

if "%~1"=="" goto :help

:parse
if "%~1"=="" goto :haveran
if /I "%~1"=="--path" (
    set "VHD_PATH=%~2"
    shift & shift
    goto :parse
)
if /I "%~1"=="--size" (
    set "SIZE_INPUT=%~2"
    shift & shift
    goto :parse
)
if /I "%~1"=="--letter" (
    set "DRIVE_LETTER=%~2"
    shift & shift
    goto :parse
)
if /I "%~1"=="--label" (
    set "LABEL=%~2"
    shift & shift
    goto :parse
)
if /I "%~1"=="--filters" (
    set "FILTERS=%~2"
    shift & shift
    goto :parse
)
if /I "%~1"=="--force" (
    set "FORCE=1"
    shift
    goto :parse
)
if /I "%~1"=="--no-av" (
    set "AV_MODE=disallow"
    shift
    goto :parse
)
if /I "%~1"=="--allow-av" (
    set "AV_MODE=allow"
    shift
    goto :parse
)
if /I "%~1"=="--fixed" (
    set "VHD_TYPE=fixed"
    shift
    goto :parse
)
if /I "%~1"=="--defaults" (
    if "%DEFAULTS_LOCK%"=="0" (
        set "VHD_PATH="
        set "SIZE_INPUT=50GB"
        set "DRIVE_LETTER=B"
        set "LABEL=DevDrive"
        set "FILTERS="
        set "FORCE=0"
        set "AV_MODE=allow"
        set "VHD_TYPE=expandable"
        set "DEFAULTS_LOCK=1"
    )
    set "DEFAULTS=1"
    shift
    goto :parse
)
if /I "%~1"=="-h" goto :help
if /I "%~1"=="--help" goto :help

echo Unknown argument: %~1
goto :help

:haveran
net session >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
    echo Run this script from an elevated Command Prompt.
    exit /b 1
)

set "DEFAULT_DIR=%USERPROFILE%\dev-drive"
if not exist "%DEFAULT_DIR%" (
    mkdir "%DEFAULT_DIR%" >nul 2>&1
)
if not defined VHD_PATH (
    set "VHD_PATH=%DEFAULT_DIR%\devdrive.vhdx"
)

call :findExistingDevDrive EXISTING_DEVDRIVE
if defined EXISTING_DEVDRIVE (
    echo Dev Drive already exists at %EXISTING_DEVDRIVE%:. Remove it before creating a new one.
    exit /b 1
)

for /f "delims=:" %%D in ("%DRIVE_LETTER%") do set "DRIVE_LETTER=%%D"
set "DRIVE_LETTER=%DRIVE_LETTER:~0,1%"
if "%DRIVE_LETTER%"=="" (
    echo Drive letter is required.
    exit /b 1
)
set "VALID_LETTER="
for %%A in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if /I "%%A"=="%DRIVE_LETTER%" set "VALID_LETTER=1"
)
if not defined VALID_LETTER (
    echo Invalid drive letter: %DRIVE_LETTER%
    exit /b 1
)

if exist "%DRIVE_LETTER%:\NUL" (
    echo Drive letter %DRIVE_LETTER%: is already in use.
    exit /b 1
)

set "DP_SCRIPT_ATTACH=%TEMP%\devdrive_attach_%RANDOM%.txt"
if "%DEFAULTS%"=="1" if exist "%VHD_PATH%" (
    if exist "%VHD_PATH%\NUL" (
        echo VHDX path resolved to a directory: %VHD_PATH%
        exit /b 1
    )
    for %%P in ("%VHD_PATH%") do (
        if /I not "%%~xP"==".vhdx" if /I not "%%~xP"==".vhd" (
            echo VHDX path does not look like a VHD/VHDX file: %VHD_PATH%
            exit /b 1
        )
    )

    if /I "%AV_MODE%"=="disallow" (
        fsutil devdrv enable /disallowAv >nul 2>&1
    ) else (
        fsutil devdrv enable /allowAv >nul 2>&1
    )
    if not "%ERRORLEVEL%"=="0" (
        echo Failed to enable Dev Drive support.
        exit /b 1
    )

    (
        echo select vdisk file="%VHD_PATH%"
        echo attach vdisk
    ) > "%DP_SCRIPT_ATTACH%"
    if not exist "%DP_SCRIPT_ATTACH%" (
        echo Diskpart script file was not created: %DP_SCRIPT_ATTACH%
        exit /b 1
    )

    diskpart /s "%DP_SCRIPT_ATTACH%"
    if errorlevel 1 (
        del /f /q "%DP_SCRIPT_ATTACH%" >nul 2>&1
        echo diskpart attach failed.
        exit /b 1
    )
    del /f /q "%DP_SCRIPT_ATTACH%" >nul 2>&1
    echo Dev Drive mounted from existing VHDX at %VHD_PATH%.
    exit /b 0
)

if exist "%VHD_PATH%" (
    if "%FORCE%"=="1" (
        del /f /q "%VHD_PATH%" >nul 2>&1
    ) else (
        choice /M "VHD already exists. Overwrite?"
        if errorlevel 2 (
            echo Aborted.
            exit /b 1
        )
        del /f /q "%VHD_PATH%" >nul 2>&1
    )
)

for %%P in ("%VHD_PATH%") do (
    if not exist "%%~dpP" mkdir "%%~dpP" >nul 2>&1
)

call :parseSize "%SIZE_INPUT%" SIZE_MB
if not "%ERRORLEVEL%"=="0" exit /b 1

if /I "%AV_MODE%"=="disallow" (
    fsutil devdrv enable /disallowAv >nul 2>&1
) else (
    fsutil devdrv enable /allowAv >nul 2>&1
)
if not "%ERRORLEVEL%"=="0" (
    echo Failed to enable Dev Drive support.
    exit /b 1
)

set "DP_SCRIPT=%TEMP%\devdrive_diskpart_%RANDOM%.txt"
(
    echo create vdisk file="%VHD_PATH%" maximum=%SIZE_MB% type=%VHD_TYPE%
    echo select vdisk file="%VHD_PATH%"
    echo attach vdisk
    echo convert gpt
    echo create partition primary
    echo assign letter=%DRIVE_LETTER%
) > "%DP_SCRIPT%"

diskpart /s "%DP_SCRIPT%"
set "DP_EXIT=%ERRORLEVEL%"
del /f /q "%DP_SCRIPT%" >nul 2>&1
if not "%DP_EXIT%"=="0" (
    echo diskpart failed.
    exit /b 1
)

format %DRIVE_LETTER%: /FS:ReFS /DevDrv /V:%LABEL% /Q /Y
if not "%ERRORLEVEL%"=="0" (
    echo format failed.
    exit /b 1
)

if defined FILTERS (
    fsutil devdrv setFiltersAllowed /F /volume "%DRIVE_LETTER%:" %FILTERS% >nul 2>&1
    if not "%ERRORLEVEL%"=="0" (
        echo Failed to set allowed filters.
        exit /b 1
    )
)

echo Dev Drive created and mounted at %DRIVE_LETTER%:
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

:parseSize
set "RAW=%~1"
set "RAW=%RAW: =%"
set "NUM=%RAW%"
set "MULT=1024"
if /I "%RAW:~-2%"=="GB" (
    set "NUM=%RAW:~0,-2%"
    set "MULT=1024"
) else if /I "%RAW:~-2%"=="MB" (
    set "NUM=%RAW:~0,-2%"
    set "MULT=1"
)

set "BAD="
if "%NUM%"=="" set "BAD=1"
for /f "delims=0123456789" %%X in ("%NUM%") do set "BAD=1"
if defined BAD (
    echo Invalid size value: %~1
    exit /b 1
)

set /a SIZE_MB=%NUM%*%MULT% >nul 2>&1
if errorlevel 1 (
    echo Invalid size value: %~1
    exit /b 1
)

set "%~2=%SIZE_MB%"
exit /b 0

:help
echo.
echo %SCRIPT_NAME% - create and mount a VHDX Dev Drive (no PowerShell/Hyper-V).
echo.
echo Usage:
echo   %SCRIPT_NAME% --path "%USERPROFILE%\Dev-Drive\devdrive.vhdx" [--size 50GB] [--letter B] [--label DevDrive]
echo   %SCRIPT_NAME% --path "%USERPROFILE%\Dev-Drive\devdrive.vhdx" [--filters PrjFlt,MsSecFlt,DfmFlt] [--force]
echo.
echo Options:
echo   --path     Optional. VHDX path to create (default is %%USERPROFILE%%\dev-drive\devdrive.vhdx).
echo   --size     Optional. Size in GB or MB. Default is 50GB.
echo   --letter   Optional. Drive letter to assign. Default is B.
echo   --label    Optional. Volume label. Default is DevDrive.
echo   --filters  Optional. Comma-separated filter list for fsutil devdrv.
echo   --force    Optional. Skip overwrite prompt.
echo   --no-av    Optional. Disable antivirus filters for Dev Drive.
echo   --allow-av Optional. Allow antivirus filters (default).
echo   --fixed    Optional. Create a fixed-size VHDX (default is expandable).
echo   --defaults Optional. Use default parameters.
echo.
exit /b 1
