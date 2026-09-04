# daily_monitor.ps1 - morning monitoring chain (registered as Windows scheduled task "EA_LAB_DailyMonitor")
# 1) collect exporter CSVs from Common\Files -> portfolio\live_deals\ (git audit trail)
# 2) rebuild portfolio\LIVE_DASHBOARD.html
# Safe to run with no data (collector exits 1, dashboard renders no-data rows).
# CODEX-AUDIT A3 (2026-07-11): fail-open -> fail-visible. Every child step's exit code is
# captured; failures are logged, gist publish is skipped when the dashboard step failed
# (never republish a stale dashboard), and the task exits non-zero so LastTaskResult
# shows the failure instead of a false green.
param([switch]$Force)   # -Force = manual run, bypass the freshness guard
. (Join-Path $PSScriptRoot 'lib\repo_paths.ps1')
$RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath
$log = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\daily_monitor.log'
$successMarker = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\daily_monitor_last_success.txt'
$alertFile = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\MONITOR_ALERT.txt'
$monitorRotation = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\monitor_rotation.ps1'
$collectLiveDeals = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\collect_live_deals.ps1'
$newsCalendar = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\news_calendar.ps1'
$mrisRun = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\mris\mris_run.ps1'
$publishGuards = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\publish_guard_feeds_to_vps.ps1'
$mrisExport = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\mris\mris_export_regime.ps1'
$liveDashboard = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\live_dashboard.ps1'
$controlRoomSnapshot = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\control_room_snapshot.ps1'
$detectorDigest = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\detector_digest.ps1'
$monitorCoverage = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\lib\monitor_coverage.ps1'
$publishDashboardGist = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\publish_dashboard_gist.ps1'
$pythonExe = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'tools\python312\python.exe'
$safeProjection = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath '_triage\factory_os\safe_projection.py'
$notifier = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath '_triage\factory_os\notifier.py'
function Invoke-RepoPythonUtf8 {
    param([string]$PythonExe,[string]$ScriptPath,[string[]]$Arguments,[string]$RepoRoot)
    $oldPyIo = $env:PYTHONIOENCODING
    Push-Location -LiteralPath $RepoRoot
    try {
        $env:PYTHONIOENCODING = 'utf-8'
        $output = @(& $PythonExe $ScriptPath @Arguments 2>&1)
        $rc = $LASTEXITCODE
        return [pscustomobject]@{ Output=$output; ExitCode=$rc }
    } finally {
        if ($null -eq $oldPyIo) { Remove-Item Env:PYTHONIOENCODING -ErrorAction SilentlyContinue }
        else { $env:PYTHONIOENCODING = $oldPyIo }
        Pop-Location
    }
}
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
Step 'rotation'  { powershell -NoProfile -File $monitorRotation *>> $log }
Step 'collect'   { powershell -NoProfile -File $collectLiveDeals *>> $log }
Step 'news'      { powershell -NoProfile -File $newsCalendar *>> $log }
# ORDER-073: refresh the MRIS macro-regime whisper (barometers -> regime -> brief) BEFORE
# the dashboard so it embeds the fresh whisper_brief.html. Its own stages are non-fatal and
# a mris failure never blocks the dashboard/gist (only a 'dashboard' failure skips the gist).
Step 'mris'      { powershell -NoProfile -File $mrisRun *>> $log }
# ORDER-073 Phase-3: append today's MRIS macro state after MRIS refresh.
# This must precede guard publishing so the VPS staging copy is the same-day regime file.
Step 'export-regime' { powershell -NoProfile -File $mrisExport *>> $log }
# Unified guard-feed publisher: validate NewsGuard + MacroGate independently, then publish each
# valid feed atomically to local Common\Files and OneDrive staging. A bad feed preserves its
# last-good destination and marks the chain unhealthy without blocking the other feed.
Step 'guard-feeds' { powershell -NoProfile -File $publishGuards *>> $log }
Step 'dashboard' { powershell -NoProfile -File $liveDashboard *>> $log }
# CR-001b (ROADMAP Phase 4.5, 2026-07-19): regenerate the ControlRoomSnapshot after collect+
# dashboard so it reads the freshest data. Read-only projection (never writes owners); a
# failure here is fail-visible like any step but never blocks dashboard/gist above.
Step 'snapshot'  { powershell -NoProfile -File $controlRoomSnapshot -Root $RepoRoot *>> $log }
# ORDER-1200 (S12): build the SafeProjection and send the Telegram alerts + Morning Brief.
#
# WHY IT SITS HERE AND NOWHERE ELSE, and why it is not a separate scheduled task. Every finding
# the notifier can report is derived from the snapshot the line above just rebuilt, and that
# rebuild happens ONCE A DAY. So an alerter running on its own timer would re-read the same
# document and learn nothing - it would only manufacture the impression of watching. Owner
# decision 2026-08-03: run it here, immediately after its input exists. If alert latency ever
# needs to be shorter, the thing to shorten is the SNAPSHOT cadence, not this call.
#
# DELIBERATELY NOT A `Step`, for exactly the ORDER-219 reason written just below: until the owner
# creates the `EA LAB Control Room` bot, every WARN/INFO alert and the Morning Brief report
# UNCONFIGURED, and a chain that goes red every single morning gets muted inside a week. So the
# notifier splits its exit codes and this block honours the split:
#   1  a CONFIGURED channel failed to deliver  -> marks the chain unhealthy
#   4  a channel has no credentials yet        -> logged loudly, chain stays healthy
#   3  the local inputs could not be read      -> marks the chain unhealthy (an instrument fault)
# `--brief` is passed because the Morning Brief is a rendering of the same page model, so it
# costs one extra event rather than a second computation.
"--- telegram notifier (ORDER-1200) ---" | Add-Content $log
# THE CAPTURE ENCODING, and it is set here rather than assumed. PowerShell decodes a native
# command's stdout using [Console]::OutputEncoding, which defaults to the ANSI codepage -- so
# the child's UTF-8 Thai is mangled AT CAPTURE TIME, before `Add-Content -Encoding utf8` ever
# sees it. Writing the file as UTF-8 therefore fixes nothing on its own; both halves are
# needed. Saved and RESTORED so no other Step in this chain changes behaviour because of a
# global this block set for itself.
$prevOutEnc = [Console]::OutputEncoding
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
try {
# CAPTURED and appended with an EXPLICIT UTF-8 encoding rather than `*>> $log` like the
# Steps above. Those emit ASCII; these two emit THAI, and `*>>` decodes a child's UTF-8
# bytes with the ANSI codepage, so the message arrives as mojibake and the log stops being
# readable exactly where it matters most. Measured, not assumed - the first run of this
# block wrote its Thai as question marks.
$projResult = Invoke-RepoPythonUtf8 -PythonExe $pythonExe -ScriptPath $safeProjection -Arguments @('build','--repo-root',$RepoRoot) -RepoRoot $RepoRoot
$projExit = [int]$projResult.ExitCode
$projResult.Output | ForEach-Object { "$_" } | Add-Content $log -Encoding utf8
if ($projExit -ne 0) {
    $failed += 'notify-projection'
    "ALERT: the SafeProjection could not be built, so NOTHING was sent - the sender has no other document it is allowed to read" | Add-Content $log
} else {
    $notifyResult = Invoke-RepoPythonUtf8 -PythonExe $pythonExe -ScriptPath $notifier -Arguments @('send','--confirm','--brief','--repo-root',$RepoRoot) -RepoRoot $RepoRoot
    $notifyExit = [int]$notifyResult.ExitCode
    $notifyResult.Output | ForEach-Object { "$_" } | Add-Content $log -Encoding utf8
    if ($notifyExit -eq 4) {
        "NOTE: a Telegram channel is not configured yet - see ops\delivery_ledger.jsonl. Logged, and deliberately NOT marking the chain unhealthy (ORDER-219 rule: a daily red gets muted)." | Add-Content $log
    } elseif ($notifyExit -ne 0) {
        $failed += 'notify'
        "ALERT: the notifier exited $notifyExit - a configured channel did not deliver, or the local inputs could not be read" | Add-Content $log
    }
}
} finally {
    [Console]::OutputEncoding = $prevOutEnc
}
# ORDER-219: surface what the run-time detectors already wrote. This is deliberately NOT a
# Step - the digest exits 2 whenever anything is flagged, and a report that turns the chain
# red every single morning is a report that gets muted inside a week. So:
#   - the FULL digest goes to the log every day (so the history is there to look back at)
#   - only flags NEWER THAN 2 DAYS mark the chain unhealthy
# That split is the actual ORDER-218 finding: the Boss_16 truncation flag was ONE DAY old and
# still invisible, while 180-odd historical sidecars were never the problem.
"--- detector digest ---" | Add-Content $log
powershell -NoProfile -File $detectorDigest *>> $log
powershell -NoProfile -File $detectorDigest -SinceDays 2 -Quiet *>> $log
if ($LASTEXITCODE -eq 2) {
    $failed += 'detector-flags'
    "ALERT: a detector flagged something in the last 2 days - see the digest above before trusting any recent run or building a bundle" | Add-Content $log
}
# CR-003a: coverage check - the chain can run clean (every Step above exit 0) while a
# LAB_MANAGED account's sensor is dead, which is the actual failure mode that bit us with
# 463666728/69424711. This is an ADDITIONAL layer on top of the stale-data guard below,
# not a replacement - that guard checks the newest file across ALL accounts; this one
# checks PER-ACCOUNT freshness scoped to governance_scope.
#
# 2026-07-30 (Stage 0B, D1+D2): the rules moved into scripts\lib\monitor_coverage.ps1 and
# two of them were wrong for as long as they existed. Read that file's header for the full
# account; the short version is:
#   D1  this block read $cr.system_health ONLY. That section measures the CLOSED-DEAL
#       exporter. The FLOATING-risk sensor is a different exporter reported in
#       $cr.floating_risk, and nothing here ever looked at it -- so the only instrument
#       that can see open baskets and margin could be dead for days while the chain went
#       green on fresh closed-deal history.
#   D2  the catch this replaced built a message, logged it, and did NOT append to $failed, so a
#       corrupt snapshot exited 0. A MISSING snapshot set "coverage check skipped" and
#       moved on -- on a chain whose entire job is coverage.
# It is a library rather than inline code because daily_monitor.ps1 cannot be run in a
# test (step 0 rotates logins through five real terminals), which is exactly why these two
# rules were never exercised. Cage: scripts\_test\run_monitor_integrity_tests.ps1.
. $monitorCoverage
$crJson = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\control_room_snapshot.json'
# AUDIT C, C-A7 (2026-08-20, lane M0-L1). The 'snapshot' Step above can fail while leaving
# portfolio\control_room_snapshot.json byte-for-byte intact -- control_room_snapshot.ps1 says so
# in its own throw text ("$OutFile was NOT replaced and still holds the previous validated
# snapshot"). This call then read that PREVIOUS document and logged its derived counts under
# today's date as though they were this morning's measurement.
#
# The evidence that it actually happened is in the repo: portfolio\MONITOR_ALERT.txt records
#   "2026-08-05 07:37 monitoring chain UNHEALTHY: snapshot, notify-projection, ...
#    (newest data 0h old; 4/6 LAB_MANAGED deal-sensor fresh; ...)"
# -- the snapshot step FAILED and a "4/6 fresh" coverage measurement was published in the same
# sentence. Only this caller knows the build failed; after a failed build the file on disk is a
# perfectly valid snapshot, just not this run's. So the fact is PASSED IN, not inferred.
$snapshotBuildFailed = ($failed -contains 'snapshot')
$cov = Get-MonitorCoverage -SnapshotPath $crJson -RepoRoot $RepoRoot -SnapshotBuildFailed $snapshotBuildFailed
foreach ($line in $cov.Log) { $line | Add-Content $log }
$failed += $cov.Failures
$coverageMsg = $cov.Summary
"COVERAGE: $coverageMsg" | Add-Content $log
# push to the secret gist for phone viewing - only after the user has run
# publish_dashboard_gist.ps1 once themselves (that first run = publish consent + creates the id file)
if (Test-Path 'D:\Monitor\dashboard_gist_id.txt') {
    if ($failed -contains 'dashboard') {
        "gist publish SKIPPED: dashboard step failed - refusing to republish a stale dashboard" | Add-Content $log
    } else {
        Step 'gist' { powershell -NoProfile -File $publishDashboardGist *>> $log }
    }
}
# commit the snapshot (audit trail) - quiet if nothing changed
Set-Location -LiteralPath $RepoRoot
# CR-TOOL-01: the same pathspec is used for both `add` and `commit`. This is a shared
# worktree (see memory shared-worktree-concurrent-writers) - a bare `git commit` with no
# pathspec would sweep in whatever another concurrent session has staged in the meantime.
# Scoping the commit to exactly what we just added removes that race.
$monitorPaths = @(
    'portfolio/live_deals',
    'portfolio/LIVE_DASHBOARD.html',
    'portfolio/news_today.html',
    'portfolio/news_week.csv',
    'portfolio/mris/whisper_brief.html',
    'portfolio/mris/whisper_brief.md',
    'portfolio/mris/regime_state.json',
    'portfolio/mris/barometer_snapshot.csv',
    'portfolio/EA_LAB_mris_regime.csv',
    'portfolio/control_room_snapshot.json'
)
git add $monitorPaths 2>> $log
$staged = git diff --cached --name-only
if ($staged) {
    git commit $monitorPaths -m "[auto] daily monitor snapshot $(Get-Date -Format 'yyyy-MM-dd')" *>> $log
}
# ORDER-128 health check: stale exporter data means the chain "ran" but the eyes are
# still blind - surface it as loudly as a step failure instead of a quiet green.
$newest = Get-ChildItem (Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\live_deals') -File -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending | Select-Object -First 1
$dataAgeH = if ($newest) { ((Get-Date) - $newest.LastWriteTime).TotalHours } else { [double]::MaxValue }
if ($dataAgeH -gt 26) {
    $failed += 'stale-data'
    "ALERT: newest live_deals snapshot is $([math]::Round($dataAgeH,1))h old (>26h)" | Add-Content $log
}
if ($failed.Count -gt 0) {
    # distinguish "the chain ran (steps exited 0)" from "sensor coverage is healthy" - a
    # clean step run with a dead LAB_MANAGED sensor is still an UNHEALTHY chain (CR-003a).
    $msg = "$(Get-Date -Format 'yyyy-MM-dd HH:mm') monitoring chain UNHEALTHY: $($failed -join ', ') (newest data $([math]::Round($dataAgeH,1))h old; $coverageMsg)"
    Set-Content $alertFile $msg -Encoding utf8
    "done WITH FAILURES: $($failed -join ', ')" | Add-Content $log
    exit 1
}
if (Test-Path $alertFile) { Remove-Item $alertFile -Force }
Set-Content $successMarker (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding ASCII
"done" | Add-Content $log
exit 0
