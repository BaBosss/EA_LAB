# daily_monitor.ps1 - morning monitoring chain (registered as Windows scheduled task "EA_LAB_DailyMonitor")
# 1) collect exporter CSVs from Common\Files -> portfolio\live_deals\ (git audit trail)
# 2) rebuild portfolio\LIVE_DASHBOARD.html
# Safe to run with no data (collector exits 1, dashboard renders no-data rows).
# CODEX-AUDIT A3 (2026-07-11): fail-open -> fail-visible. Every child step's exit code is
# captured; failures are logged, gist publish is skipped when the dashboard step failed
# (never republish a stale dashboard), and the task exits non-zero so LastTaskResult
# shows the failure instead of a false green.
$log = "D:\EA_LAB\portfolio\daily_monitor.log"
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Add-Content $log
$failed = @()
function Step([string]$name, [scriptblock]$body) {
    & $body
    if ($LASTEXITCODE -ne 0) {
        $script:failed += $name
        "STEP FAILED: $name (exit $LASTEXITCODE)" | Add-Content $log
    }
}
# 0) rotate read-only logins through the monitor terminals so exporters snapshot all 5 accounts
Step 'rotation'  { powershell -NoProfile -File D:\EA_LAB\scripts\monitor_rotation.ps1 *>> $log }
Step 'collect'   { powershell -NoProfile -File D:\EA_LAB\scripts\collect_live_deals.ps1 *>> $log }
Step 'news'      { powershell -NoProfile -File D:\EA_LAB\scripts\news_calendar.ps1 *>> $log }
# ORDER-073: refresh the MRIS macro-regime whisper (barometers -> regime -> brief) BEFORE
# the dashboard so it embeds the fresh whisper_brief.html. Its own stages are non-fatal and
# a mris failure never blocks the dashboard/gist (only a 'dashboard' failure skips the gist).
Step 'mris'      { powershell -NoProfile -File D:\EA_LAB\scripts\mris\mris_run.ps1 *>> $log }
# ORDER-083: publish the news CSV where the (Boss)_NewsGuard EA reads it (MT5 Common\Files)
if (Test-Path 'D:\EA_LAB\portfolio\news_week.csv') {
    try {
        Copy-Item 'D:\EA_LAB\portfolio\news_week.csv' 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files\EA_LAB_news_week.csv' -Force
    } catch {
        $failed += 'newsguard-csv'
        "newsguard csv copy failed: $($_.Exception.Message)" | Add-Content $log
    }
}
Step 'dashboard' { powershell -NoProfile -File D:\EA_LAB\scripts\live_dashboard.ps1 *>> $log }
# push to the secret gist for phone viewing - only after the user has run
# publish_dashboard_gist.ps1 once themselves (that first run = publish consent + creates the id file)
if (Test-Path 'D:\Monitor\dashboard_gist_id.txt') {
    if ($failed -contains 'dashboard') {
        "gist publish SKIPPED: dashboard step failed - refusing to republish a stale dashboard" | Add-Content $log
    } else {
        Step 'gist' { powershell -NoProfile -File D:\EA_LAB\scripts\publish_dashboard_gist.ps1 *>> $log }
    }
}
# commit the snapshot (audit trail) - quiet if nothing changed
Set-Location D:\EA_LAB
git add portfolio/live_deals portfolio/LIVE_DASHBOARD.html portfolio/news_today.html portfolio/news_week.csv portfolio/mris/whisper_brief.html portfolio/mris/whisper_brief.md portfolio/mris/regime_state.json portfolio/mris/barometer_snapshot.csv 2>> $log
$staged = git diff --cached --name-only
if ($staged) {
    git commit -m "[auto] daily monitor snapshot $(Get-Date -Format 'yyyy-MM-dd')" *>> $log
}
if ($failed.Count -gt 0) {
    "done WITH FAILURES: $($failed -join ', ')" | Add-Content $log
    exit 1
}
"done" | Add-Content $log
exit 0
