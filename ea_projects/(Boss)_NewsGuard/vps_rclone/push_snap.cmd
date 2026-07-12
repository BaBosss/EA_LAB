@echo off
REM EA_LAB VPS transport - PUSH snapshots (Common\Files -> OneDrive), every 5 min.
REM One writer per direction: the VPS writes snapshots; the LAB only reads.
REM --include "EA_LAB_snapshot_[1-9]*.csv": only real accounts (login 0 / test
REM names excluded by the glob). --exclude "*.tmp": never push a partial file.
REM --max-age 1h: only push reasonably fresh snapshots (exporter rewrites ~60s).
setlocal
set RCLONE=C:\rclone\rclone.exe
set CONF=C:\rclone\rclone.conf
set SRC=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files
"%RCLONE%" copy "%SRC%" onedrive:EA_LAB_VPS_SYNC/vps-to-lab/snapshots --config "%CONF%" --include "EA_LAB_snapshot_[1-9]*.csv" --exclude "*.tmp" --max-age 1h --min-size 1 --log-file C:\rclone\logs\push_snap.log --log-level INFO
