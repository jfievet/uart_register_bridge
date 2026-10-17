
@echo off
setlocal

set "QUARTUS_BIN=C:\Tools\altera\13.1\quartus\bin"
set "PROJECT=top"
set "REVISION=top"

rem -----------------------------------------
rem Check protocol argument
rem 0 = Extended
rem 1 = Compact
rem -----------------------------------------

if "%~1"=="0" (
    set "PROTOCOL=extended"
) else if "%~1"=="1" (
    set "PROTOCOL=compact"
) else (
    echo ERROR: Invalid or missing protocol argument.
    echo Usage: %~nx0 0 ^| 1
    echo   0 = Extended
    echo   1 = Compact
    exit /b 1
)

echo Selected protocol: %PROTOCOL%

rem -----------------------------------------
rem Navigate to src directory
rem -----------------------------------------

cd ..
cd ..
cd src

rem -----------------------------------------
rem Create tmp directory if necessary
rem -----------------------------------------

if not exist "tmp\" (
    mkdir "tmp"
    if errorlevel 1 exit /b 1
)

rem -----------------------------------------
rem Copy selected integration package
rem -----------------------------------------

set "SOURCE_PKG=conf\top_integration_%PROTOCOL%_pkg.vhd"
set "DEST_PKG=tmp\top_integration_pkg.vhd"

if not exist "%SOURCE_PKG%" (
    echo ERROR: Package not found: %SOURCE_PKG%
    exit /b 1
)

copy /Y "%SOURCE_PKG%" "%DEST_PKG%" >nul
if errorlevel 1 (
    echo ERROR: Failed to copy integration package.
    exit /b 1
)

echo Package selected: %SOURCE_PKG%

rem -----------------------------------------
rem Generate timestamp package
rem -----------------------------------------

cd ..
cd script

python generate_timestamp_pkg.py
if errorlevel 1 exit /b 1

rem -----------------------------------------
rem Navigate to Quartus project
rem -----------------------------------------

cd ..
cd board
cd de0
cd de0_top
cd prj

rem -----------------------------------------
rem Quartus compilation
rem -----------------------------------------

"%QUARTUS_BIN%\quartus_map.exe" ^
    --read_settings_files=on ^
    --write_settings_files=off ^
    %PROJECT% ^
    -c %REVISION%
if errorlevel 1 exit /b 1

"%QUARTUS_BIN%\quartus_fit.exe" ^
    --read_settings_files=off ^
    --write_settings_files=off ^
    %PROJECT% ^
    -c %REVISION%
if errorlevel 1 exit /b 1

"%QUARTUS_BIN%\quartus_asm.exe" ^
    --read_settings_files=off ^
    --write_settings_files=off ^
    %PROJECT% ^
    -c %REVISION%
if errorlevel 1 exit /b 1

"%QUARTUS_BIN%\quartus_sta.exe" ^
    %PROJECT% ^
    -c %REVISION%
if errorlevel 1 exit /b 1

echo.
echo Compilation completed successfully.
echo Protocol: %PROTOCOL%

endlocal
exit /b 0
