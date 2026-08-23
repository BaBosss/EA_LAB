@echo off
REM Compatibility entrypoint for the existing VPS scheduled task.
REM The PowerShell worker now pulls, validates, and atomically publishes BOTH
REM EA_LAB_news_week.csv (NewsGuard) and EA_LAB_mris_regime.csv (MacroGate).
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pull_guard_feeds.ps1"
exit /b %ERRORLEVEL%
