@echo off
:: Samsung Device Optimizer v2.0 — Windows Launcher
:: This batch file launches the PowerShell script for Windows users.
::
:: Usage:
::   optimize-samsung.bat                   Interactive mode
::   optimize-samsung.bat --all             Apply all optimizations
::   optimize-samsung.bat --dry-run         Preview without changes
::   optimize-samsung.bat --revert          Undo all changes
::   optimize-samsung.bat --updates         Disable/re-enable OS updates
::   optimize-samsung.bat --report          Device status report
::   optimize-samsung.bat --install-adb     Download and install ADB
::   optimize-samsung.bat --help            Show help

setlocal enabledelayedexpansion

:: Map batch-style arguments to PowerShell parameters
set "PS_ARGS="

:parse_args
if "%~1"=="" goto run
if /I "%~1"=="--all"         set "PS_ARGS=!PS_ARGS! -All"         & shift & goto parse_args
if /I "%~1"=="--dry-run"     set "PS_ARGS=!PS_ARGS! -DryRun"      & shift & goto parse_args
if /I "%~1"=="--revert"      set "PS_ARGS=!PS_ARGS! -Revert"      & shift & goto parse_args
if /I "%~1"=="--report"      set "PS_ARGS=!PS_ARGS! -Report"       & shift & goto parse_args
if /I "%~1"=="--rotation"    set "PS_ARGS=!PS_ARGS! -Rotation"     & shift & goto parse_args
if /I "%~1"=="--battery"     set "PS_ARGS=!PS_ARGS! -Battery"      & shift & goto parse_args
if /I "%~1"=="--memory"      set "PS_ARGS=!PS_ARGS! -Memory"       & shift & goto parse_args
if /I "%~1"=="--bloatware"   set "PS_ARGS=!PS_ARGS! -Bloatware"    & shift & goto parse_args
if /I "%~1"=="--per-app"     set "PS_ARGS=!PS_ARGS! -PerApp"       & shift & goto parse_args
if /I "%~1"=="--updates"    set "PS_ARGS=!PS_ARGS! -Updates"      & shift & goto parse_args
if /I "%~1"=="--install-adb" set "PS_ARGS=!PS_ARGS! -InstallAdb"   & shift & goto parse_args
if /I "%~1"=="--help"        set "PS_ARGS=!PS_ARGS! -Help"         & shift & goto parse_args
if /I "%~1"=="-h"            set "PS_ARGS=!PS_ARGS! -Help"         & shift & goto parse_args
:: Assume anything else is a serial number
set "PS_ARGS=!PS_ARGS! -Serial %~1"
shift
goto parse_args

:run
:: Launch the PowerShell script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0optimize-samsung.ps1" %PS_ARGS%

if errorlevel 1 (
    echo.
    echo Script exited with an error. If you see a PowerShell execution policy error, run:
    echo   powershell -ExecutionPolicy Bypass -File optimize-samsung.ps1
    echo.
)

endlocal
