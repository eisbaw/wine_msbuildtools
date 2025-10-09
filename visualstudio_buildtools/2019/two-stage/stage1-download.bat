REM Change the current directory to the path of this .bat file
cd /d "%~dp0"

set "OFFLINE_DIR=%~1"
set "LANG=%~2"

echo If OFFLINE_DIR not specified, default to C:\vs_buildtools_2019
if "%OFFLINE_DIR%"=="" (
    set "OFFLINE_DIR=C:\vs_buildtools_2019"
)

if "%LANG%"=="" (
    set "LANG=en-US"
)

echo.
echo [Stage 1 - Download and create layout]
echo Folder:   %OFFLINE_DIR%
echo Language: %LANG%
echo.

echo Downloading packages...
vs_buildtools.exe ^
    --layout "%OFFLINE_DIR%" ^
    --lang %LANG% ^
    --add Microsoft.VisualStudio.Workload.VCTools ^
    --includeRecommended ^
    --includeOptional ^
    --passive

echo.
echo Offline layout creation complete, see folder:
echo   %OFFLINE_DIR%
echo Copy that folder to the offline machine and run stage2 to install.
