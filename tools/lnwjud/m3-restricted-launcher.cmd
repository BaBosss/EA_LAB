@echo off
setlocal DisableDelayedExpansion
set "SCRIPT=%~dp0m3-restricted-launcher.cjs"
if not exist "%SCRIPT%" (
  echo EA_LAB M3 restricted launcher missing: %SCRIPT% 1>&2
  exit /b 1
)
set "NODE_EXE="
if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
if not defined NODE_EXE if exist "%LOCALAPPDATA%\Programs\nodejs\node.exe" set "NODE_EXE=%LOCALAPPDATA%\Programs\nodejs\node.exe"
if not defined NODE_EXE set "NODE_EXE=node"
set "LNWJUD_UNRESTRICTED="
"%NODE_EXE%" "%SCRIPT%"
