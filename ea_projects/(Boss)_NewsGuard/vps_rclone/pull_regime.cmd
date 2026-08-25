@echo off
REM DEMO-safe MacroGate-only entrypoint. Does not fetch or publish NewsGuard feed.
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pull_guard_feeds.ps1" -RegimeOnly
exit /b %ERRORLEVEL%
