@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Build on Windows x64 with MATLAB R2025b and MATLAB Compiler.
rem Optional: set "FILTERLAB_MATLAB_EXE=C:\path to MATLAB\bin\matlab.exe"
if not "%~2"=="" goto :usage
if /i "%~1"=="--help" goto :help
if /i "%~1"=="/?" goto :help
set "FILTERLAB_BUILD_MODE="
if "%~1"=="" set "FILTERLAB_BUILD_MODE=online"
if /i "%~1"=="online" set "FILTERLAB_BUILD_MODE=online"
if /i "%~1"=="offline" set "FILTERLAB_BUILD_MODE=offline"
if /i "%~1"=="both" set "FILTERLAB_BUILD_MODE=both"
if not defined FILTERLAB_BUILD_MODE goto :usage

set "FILTERLAB_BUILD_DEPLOY=%~dp0deploy"
if defined FILTERLAB_MATLAB_EXE goto :located
set "FILTERLAB_MATLAB_EXE=%ProgramFiles%\MATLAB\R2025b\bin\matlab.exe"
if exist "%FILTERLAB_MATLAB_EXE%" goto :located
set "FILTERLAB_MATLAB_EXE="
for %%M in (matlab.exe) do set "FILTERLAB_MATLAB_EXE=%%~$PATH:M"
:located
if not defined FILTERLAB_MATLAB_EXE goto :missing
if not exist "%FILTERLAB_MATLAB_EXE%" goto :missing
"%FILTERLAB_MATLAB_EXE%" -wait -sd "%FILTERLAB_BUILD_DEPLOY%" -batch "addpath(getenv('FILTERLAB_BUILD_DEPLOY')); build_v30(getenv('FILTERLAB_BUILD_MODE'));"
set "buildExit=%errorlevel%"
if not "%buildExit%"=="0" echo FilterLab build failed with exit code %buildExit%. 1>&2
exit /b %buildExit%

:missing
echo MATLAB R2025b was not found. Set FILTERLAB_MATLAB_EXE to its full matlab.exe path. 1>&2
exit /b 3
:usage
echo Usage: "%~nx0" [online^|offline^|both] 1>&2
exit /b 2
:help
echo Usage: "%~nx0" [online^|offline^|both]
echo Default: online. Offline packages include the matching MATLAB Runtime.
echo Successful output: dist\RUN\build.json lists actual installer paths.
exit /b 0
