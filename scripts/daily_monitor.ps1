# daily_monitor.ps1 - morning monitoring chain (registered as Windows scheduled task "EA_LAB_DailyMonitor")
# 1) collect exporter CSVs from Common\Files -> portfolio\live_deals\ (git audit trail)
# 2) rebuild portfolio\LIVE_DASHBOARD.html
# Safe to run with no data (collector exits 1, dashboard renders no-data rows).
$log = "D:\EA_LAB\portfolio\daily_monitor.log"
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Add-Content $log
# 0) rotate read-only logins through the monitor terminals so exporters snapshot all 5 accounts
powershell -NoProfile -File D:\EA_LAB\scripts\monitor_rotation.ps1 *>> $log
powershell -NoProfile -File D:\EA_LAB\scripts\collect_live_deals.ps1 *>> $log
powershell -NoProfile -File D:\EA_LAB\scripts\live_dashboard.ps1 *>> $log
# commit the snapshot (audit trail) - quiet if nothing changed
Set-Location D:\EA_LAB
git add portfolio/live_deals portfolio/LIVE_DASHBOARD.html 2>> $log
$staged = git diff --cached --name-only
if ($staged) {
    git commit -m "[auto] daily monitor snapshot $(Get-Date -Format 'yyyy-MM-dd')" *>> $log
}
"done" | Add-Content $log
