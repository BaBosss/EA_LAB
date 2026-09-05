@echo off
REM EA_LAB VPS transport - PUSH snapshots + RuntimeIdentity sidecars (Common\Files -> OneDrive), every 5 min.
REM Two scoped passes prevent a second successful copy from hiding a first-pass failure.
REM Snapshots: only real-account CSVs; partial *.tmp files do not match the include.
REM RuntimeIdentity: only non-zero login/magic JSON sidecars; collector revalidates producer timestamp/shape.
REM Do NOT sync Common\Files wholesale and do NOT mix --include with --exclude.
setlocal
set RCLONE=C:\rclone\rclone.exe
set CONF=C:\rclone\rclone.conf
set SRC=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files
set DEST=onedrive:EA_LAB_VPS_SYNC/vps-to-lab/snapshots
set LOG=C:\rclone\logs\push_snap.log
set RC=0
"%RCLONE%" copy "%SRC%" "%DEST%" --config "%CONF%" --include "EA_LAB_snapshot_[1-9]*.csv" --max-age 1h --min-size 1 --log-file "%LOG%" --log-level INFO
if errorlevel 1 set RC=1
"%RCLONE%" copy "%SRC%" "%DEST%" --config "%CONF%" --include "EA_LAB_identity_[1-9]*_[1-9]*.json" --max-age 30h --min-size 1 --log-file "%LOG%" --log-level INFO
if errorlevel 1 set RC=1
exit /b %RC%
