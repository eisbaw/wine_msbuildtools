set "OFFLINE_DIR=%~1"

echo If OFFLINE_DIR not specified, default to C:\vs_buildtools_2019
if "%OFFLINE_DIR%"=="" (
    set "OFFLINE_DIR=C:\vs_buildtools_2019"
)

echo.
echo [Stage 2: Offline install]
echo Installing from layout folder: %OFFLINE_DIR%
echo.

"%OFFLINE_DIR%\vs_buildtools.exe" ^
    --quiet ^
    --wait ^
    --norestart ^
    --noweb ^
    --add Microsoft.VisualStudio.Workload.VCTools ^
    --includeRecommended ^
    --includeOptional

echo Installation (offline) completed.
