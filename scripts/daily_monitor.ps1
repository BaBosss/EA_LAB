# daily_monitor.ps1 - morning monitoring chain (registered as Windows scheduled task "EA_LAB_DailyMonitor")
# 1) collect exporter CSVs from Common\Files -> portfolio\live_deals\ (git audit trail)
# 2) rebuild portfolio\LIVE_DASHBOARD.html
# Safe to run with no data (collector exits 1, dashboard renders no-data rows).
# CODEX-AUDIT A3 (2026-07-11): fail-open -> fail-visible. Every child step's exit code is
# captured; failures are logged, gist publish is skipped when the dashboard step failed
# (never republish a stale dashboard), and the task exits non-zero so LastTaskResult
# shows the failure instead of a false green.
param([switch]$Force)   # -Force = manual run, bypass the freshness guard
$log = "D:\EA_LAB\portfolio\daily_monitor.log"
$successMarker = "D:\EA_LAB\portfolio\daily_monitor_last_success.txt"
$alertFile     = "D:\EA_LAB\portfolio\MONITOR_ALERT.txt"
# ORDER-128 freshness guard: the task now also fires at logon (to catch up runs the
# 07:30 trigger missed while logged out / asleep). Skip quietly when the last full
# success is recent so the logon trigger can't double-run the chain.
if (-not $Force -and (Test-Path $successMarker)) {
    $ageH = ((Get-Date) - (Get-Item $successMarker).LastWriteTime).TotalHours
    if ($ageH -lt 20) {
        "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') === skipped (last success $([math]::Round($ageH,1))h ago < 20h)" | Add-Content $log
        exit 0
    }
}
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
# ORDER-073 Phase-3: append today's MRIS macro state to the rolling regime CSV that the
# (Boss)_MacroGate watchdog reads. Runs after 'mris' so regime_state.json is fresh. The
# script mirrors the CSV to local Common\Files; the VPS copy is delivered by rclone (runbook).
Step 'export-regime' { powershell -NoProfile -File D:\EA_LAB\scripts\mris\mris_export_regime.ps1 *>> $log }
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
git add portfolio/live_deals portfolio/LIVE_DASHBOARD.html portfolio/news_today.html portfolio/news_week.csv portfolio/mris/whisper_brief.html portfolio/mris/whisper_brief.md portfolio/mris/regime_state.json portfolio/mris/barometer_snapshot.csv portfolio/EA_LAB_mris_regime.csv 2>> $log
$staged = git diff --cached --name-only
if ($staged) {
    git commit -m "[auto] daily monitor snapshot $(Get-Date -Format 'yyyy-MM-dd')" *>> $log
}
# ORDER-128 health check: stale exporter data means the chain "ran" but the eyes are
# still blind — surface it as loudly as a step failure instead of a quiet green.
$newest = Get-ChildItem 'D:\EA_LAB\portfolio\live_deals' -File -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
$dataAgeH = if ($newest) { ((Get-Date) - $newest.LastWriteTime).TotalHours } else { [double]::MaxValue }
if ($dataAgeH -gt 26) {
    $failed += 'stale-data'
    "ALERT: newest live_deals snapshot is $([math]::Round($dataAgeH,1))h old (>26h)" | Add-Content $log
}
if ($failed.Count -gt 0) {
    $msg = "$(Get-Date -Format 'yyyy-MM-dd HH:mm') monitoring chain UNHEALTHY: $($failed -join ', ') (newest data $([math]::Round($dataAgeH,1))h old)"
    Set-Content $alertFile $msg -Encoding utf8
    "done WITH FAILURES: $($failed -join ', ')" | Add-Content $log
    exit 1
}
if (Test-Path $alertFile) { Remove-Item $alertFile -Force }
Set-Content $successMarker (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding ASCII
"done" | Add-Content $log
exit 0
