@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\watch_report_drop.ps1" -RunType auto -AllowSingleProjectFallback
pause
