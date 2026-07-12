@echo off
REM EA_LAB VPS transport - PULL news (OneDrive -> Common\Files), every 5 min.
REM One writer per direction: the LAB writes news to OneDrive; the VPS only reads.
REM --max-age 26h: skip a stale source so the last good local file is retained.
REM --min-size 1: never overwrite with a zero-byte file. rclone downloads to a
REM temp then renames = atomic on the local FS.
setlocal
set RCLONE=C:\rclone\rclone.exe
set CONF=C:\rclone\rclone.conf
set DEST=C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files
"%RCLONE%" copy onedrive:EA_LAB_VPS_SYNC/lab-to-vps/news "%DEST%" --config "%CONF%" --include "EA_LAB_news_week.csv" --max-age 26h --min-size 1 --log-file C:\rclone\logs\pull_news.log --log-level INFO
