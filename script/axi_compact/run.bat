@echo off
setlocal enableextensions

set "SCRIPT_DIR=%~dp0"
set "SRC=%SCRIPT_DIR%uart2fpga.c"
set "EXE=%SCRIPT_DIR%uart2fpga.exe"
set "GCC=C:\Tools\GNU Octave\Octave-11.3.0\mingw64\bin\gcc.exe"

if not exist "%GCC%" (
    echo ERROR: gcc not found at "%GCC%"
    exit /b 1
)

"%GCC%" -O2 -std=c11 -Wall -Wextra -o "%EXE%" "%SRC%" -lwinmm
if errorlevel 1 (
    echo ERROR: build failed
    exit /b 1
)

"%EXE%"
