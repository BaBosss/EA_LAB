<#
monitor_coverage.ps1 - the coverage verdict for the morning monitoring chain.

WHY THIS IS A LIBRARY AND NOT INLINE IN daily_monitor.ps1
  It used to be inline. daily_monitor.ps1 cannot be run in a test: step 0 rotates
  read-only logins through five MT5/MT4 terminals, which means the only way to
  exercise the coverage rules was to run the real chain against real accounts and
  read the log afterwards. So the rules were never tested, and two of them were
  wrong for as long as they existed (see the two defects below). Pulled out here so
  scripts\_test\run_monitor_integrity_tests.ps1 can drive every branch from a JSON
  fixture, offline, in milliseconds.

WHAT IT DECIDES
  Given portfolio\control_room_snapshot.json, answer three questions:
    1. can the chain READ the snapshot at all?
    2. is every LAB_MANAGED account's CLOSED-DEAL sensor fresh?   ($cr.system_health)
    3. is every LAB_MANAGED account's FLOATING-RISK sensor fresh?  ($cr.floating_risk)
  Anything that answers "no" for a LAB_MANAGED account returns a failure token, and
  daily_monitor.ps1 exits non-zero on any failure token. Accounts outside
  LAB_MANAGED scope (USER_OBSERVED / ARCHIVED / UNREGISTERED) are logged and never
  turn the chain red - this lab does not own their sensors.

THE TWO DEFECTS THIS SHAPE EXISTS TO PREVENT

  D1 - a dead floating sensor could not turn the chain red.
  The old check read $cr.system_health only. system_health measures the CLOSED-DEAL
  exporter (DealsExporter / OrdersExporterMT4). The floating-risk sensor is a
  different exporter (AccountSnapshotExporter) reported in a different section,
  $cr.floating_risk, and nothing consulted it. Closed-deal history could therefore
  be perfectly fresh - green chain, exit 0 - while the only instrument that can see
  OPEN baskets, margin level and floating loss had been dead for days. On a fleet
  that contains no-SL grid EAs, that is the sensor whose death costs money.

  D2 - "I could not read the input" was reported as "there was nothing to report".
  The old catch around ConvertFrom-Json built a message, wrote it to the log, and
  then did not append to $failed - so a corrupt snapshot exited 0. A MISSING
  snapshot was worse: it set the string "coverage check skipped" and moved on. On a
  chain whose entire job is coverage, "I have no coverage data" is the single
  loudest thing it can discover, not a reason to skip. Both are failures now.

WHAT IS DELIBERATELY NOT HERE: a floating P/L THRESHOLD.
  A negative floating P/L is not a failure and is not treated as one. Breaching a
  SIZE is a different, explicitly-named condition - and there is no per-account
  floating-loss threshold anywhere in the owner data to read: portfolio\ACCOUNTS.csv
  has no such column, and control_room_snapshot.ps1 publishes no such number. The
  per-magic kill_rule DD% in DEPLOYMENTS.csv is the nearest thing, but it is
  per-magic and expressed as a percentage of an account base equity that ACCOUNTS.csv
  records for exactly one of six accounts. Inventing a number here would produce a
  guard that fires on an arithmetic fiction, which is worse than no guard because it
  looks like one. If a threshold is wanted, it has to be recorded in owner data first.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
NOTE: this file deliberately sets NO $ErrorActionPreference and NO Set-StrictMode.
Dot-sourcing does not create a scope, so either one would silently change the rules
the CALLING script runs under, for the rest of that script (memory:
strictmode-in-dotsourced-library-leaks). A shared library must be inert to its caller.
#>

. (Join-Path $PSScriptRoot 'deployment_status.ps1')
. (Join-Path $PSScriptRoot 'repo_paths.ps1')

function Get-MonitorCoverage {
    <#
      Returns:
        Summary  [string]   one-line status, what daily_monitor logs as "COVERAGE: ..."
        Failures [string[]] failure tokens; ANY entry means the chain is unhealthy
        Log      [string[]] lines to write to the monitor log, in order
      Never throws on bad input: an unreadable snapshot is a RESULT, not an exception.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SnapshotPath,
        [string]$RepoRoot = ''
    )

    $failures = New-Object System.Collections.Generic.List[string]
    $log = New-Object System.Collections.Generic.List[string]

    # ---- 1. can we read it, AND is it verified? -------------------------------------
    # ORDER-612 (S4). This used to be Get-Content | ConvertFrom-Json, which answered "is this
    # valid JSON" and nothing else. Codex audit 6 measured that no reader anywhere called
    # load_verified(), so the entire build-side verdict machinery was guarding a door with no
    # wall attached: a hand-authored snapshot with sources:[] and reconciliation_clear:true was
    # structurally perfect JSON and this function would have read its sensor rows happily.
    #
    # PRE-REGISTERED for this reader, and deliberately stricter than make_status.ps1's:
    #   REFUSED     -> failure token. The document is present and its own verdict is wrong.
    #   UNAVAILABLE -> failure token. Missing snapshot, or the checker could not run.
    # Both are red HERE because this chain's entire job is coverage and it is on nobody's commit
    # path. make_status.ps1 makes the opposite call about its exit code, for the opposite reason,
    # and both are written down in scripts\lib\snapshot_reader.ps1.
    if (-not $RepoRoot) { $RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSScriptRoot }
    . (Join-Path $PSScriptRoot 'snapshot_reader.ps1')
    $verified = Get-VerifiedSnapshot -SnapshotPath $SnapshotPath -RepoRoot $RepoRoot
    if ($verified.State -ne 'OK') {
        # The token comes from Code, never from matching the Reason text. Four distinct facts,
        # four tokens, because they have four different fixes:
        #   snapshot-missing       nothing is there                -> run the builder
        #   snapshot-unreadable    corrupt, or not a snapshot      -> the writer truncated it
        #   snapshot-refused       it IS a snapshot and it lies    -> somebody typed a verdict
        #   snapshot-unverifiable  the CHECKER could not run       -> fix this machine
        # The first two names are the ones this cage already asserted and they keep their meaning.
        # The last two are new states that did not exist before this reader was verified at all.
        switch ($verified.Code) {
            'MISSING'   { $token = 'snapshot-missing' }
            'MALFORMED' { $token = 'snapshot-unreadable' }
            'VERDICT'   { $token = 'snapshot-refused' }
            default     { $token = 'snapshot-unverifiable' }
        }
        $msg = "coverage check FAILED [$token]: $($verified.Reason) - the chain cannot tell whether any sensor is alive, and NONE of this snapshot's numbers may be read"
        $failures.Add($token) | Out-Null
        $log.Add($msg) | Out-Null
        return [pscustomobject]@{ Summary = $msg; Failures = $failures.ToArray(); Log = $log.ToArray() }
    }
    $cr = $verified.Document
    if ($null -eq $cr -or $null -eq $cr.system_health) {
        # Valid JSON that is not a snapshot (empty file, an array, a truncated write).
        # Same class as a parse error: we have no coverage data.
        $msg = "coverage check FAILED: snapshot json has no system_health section - not a ControlRoomSnapshot?"
        $failures.Add('snapshot-unreadable') | Out-Null
        $log.Add($msg) | Out-Null
        return [pscustomobject]@{ Summary = $msg; Failures = $failures.ToArray(); Log = $log.ToArray() }
    }

    # Runtime identity is required for the current VPS DEMO / forward-test path. Older
    # snapshots without the policy flag remain readable for compatibility, but a current
    # snapshot with a missing, legacy, failed, or mixed identity result is explicitly red.
    if ($cr.meta.runtime_identity_required -eq $true) {
        $identitySummary = $cr.runtime_identity_summary
        $identityBad = ($null -eq $identitySummary -or "$($identitySummary.state)" -ne 'PASS')
        if (-not $identityBad -and $null -ne $cr.runtime_identity) {
            $identityBad = @($cr.runtime_identity | Where-Object { "$($_.validation_state)" -ne 'PASS' }).Count -gt 0
        }
        if ($identityBad) {
            $detail = if ($null -eq $identitySummary) { 'summary missing' } else { "$($identitySummary.state): $((@($identitySummary.reasons) | ForEach-Object { "$($_.code)=$($_.detail)" }) -join '; ')" }
            $failures.Add('runtime-identity-unverified') | Out-Null
            $log.Add("COVERAGE GAP: runtime identity is NON-GREEN ($detail); account/magic/build/config/symbol/timeframe/epoch evidence must not be read as healthy") | Out-Null
        }
        if ($null -ne $identitySummary -and "$($identitySummary.forward_test_state)" -eq 'FORWARD_TEST_UNTRUSTED') {
            $findings = (@($identitySummary.first_trade_findings) | ForEach-Object {
                "$($_.account_login)|$($_.magic):$($_.state)"
            }) -join '; '
            $failures.Add('first-trade-untrusted') | Out-Null
            $log.Add("COVERAGE GAP: first qualifying trade cannot be trusted ($findings); forward-test start remains fail-closed") | Out-Null
        }
    }

    # ---- 1b. deployment attachment/verification coverage (ORDER-944) ----------------
    # A deployment row is part of the monitoring universe even when its verification is
    # pending or absent. Normalize the rows through the same closed status contract used by
    # the writers; an unknown status is a data-integrity failure, never an omitted row.
    $deploymentRows = @()
    if ($null -ne $cr.deployments -and $null -ne $cr.deployments.rows) {
        try {
            $deploymentRows = @(Get-DeploymentMonitoringRows @($cr.deployments.rows))
        } catch {
            $msg = "coverage check FAILED [deployment-status-invalid]: $($_.Exception.Message) - deployment monitoring cannot classify every inventory row"
            $failures.Add('deployment-status-invalid') | Out-Null
            $log.Add($msg) | Out-Null
        }
    }
    $deploymentWarnings = 0
    $deploymentBlocks = 0
    foreach ($d in $deploymentRows) {
        if ($d.verification_state -eq 'UNVERIFIED') {
            $deploymentBlocks++
            $failures.Add("deployment-unverified-$($d.account)|$($d.magic)") | Out-Null
            $log.Add("COVERAGE GAP: deployment $($d.account)|$($d.magic) is visible but BLOCKED: operational=$($d.operational_status), verification=UNVERIFIED") | Out-Null
        } elseif ($d.verification_state -eq 'PENDING') {
            $deploymentWarnings++
            $failures.Add("deployment-pending-verification-$($d.account)|$($d.magic)") | Out-Null
            $log.Add("COVERAGE GAP: deployment $($d.account)|$($d.magic) is visible but WARNING: operational=$($d.operational_status), verification=PENDING") | Out-Null
        }
    }

    # ---- 2. closed-deal sensor freshness (system_health) ----------------------------
    $health = @($cr.system_health)
    $labAccts = @($health | Where-Object { $_.governance_scope -eq 'LAB_MANAGED' })
    $labFresh = @($labAccts | Where-Object { $_.state -eq 'FRESH' })
    $labMissing = @($labAccts | Where-Object { $_.state -ne 'FRESH' })

    $summary = "$($labFresh.Count)/$($labAccts.Count) LAB_MANAGED deal-sensor fresh"
    if ($labMissing.Count -gt 0) {
        $summary += "; deal-sensor missing: $(($labMissing | ForEach-Object { $_.account }) -join ', ')"
        foreach ($m in $labMissing) {
            $failures.Add("sensor-$($m.account)") | Out-Null
            $log.Add("COVERAGE GAP: account $($m.account) (LAB_MANAGED) deal-sensor state=$($m.state)") | Out-Null
        }
    }
    foreach ($o in @($health | Where-Object { $_.governance_scope -ne 'LAB_MANAGED' -and $_.state -ne 'FRESH' })) {
        $log.Add("coverage note (not red): account $($o.account) scope=$($o.governance_scope) deal-sensor state=$($o.state)") | Out-Null
    }

    # ---- 3. floating-risk sensor freshness (floating_risk) -- D1 --------------------
    # governance_scope is carried on system_health rows only, so system_health is the
    # scope authority and this section is joined onto it by account. An account that
    # appears in floating_risk but NOT in system_health cannot have its scope resolved;
    # it is reported rather than dropped (see the end of this block).
    $floatRows = @()
    if ($null -ne $cr.floating_risk) { $floatRows = @($cr.floating_risk) }
    $floatByAcct = @{}
    foreach ($f in $floatRows) { if ($null -ne $f.account) { $floatByAcct["$($f.account)"] = $f } }

    if ($floatRows.Count -eq 0 -and $labAccts.Count -gt 0) {
        # A snapshot with no floating_risk section at all (a pre-v3 writer, or a writer
        # that failed halfway). Every LAB_MANAGED account below will report MISSING; say
        # once, up front, WHY, so the log does not read as six unrelated sensor deaths.
        $log.Add("COVERAGE GAP: snapshot has no floating_risk section (schema version $($cr.meta.version)) - every LAB_MANAGED float sensor below is unreadable for that reason, not necessarily dead") | Out-Null
    }

    $floatOk = 0
    foreach ($h in $labAccts) {
        $acct = "$($h.account)"
        $fr = $floatByAcct[$acct]
        # The three states are kept distinct in the log on purpose. They are different
        # facts about the world and they have different fixes:
        #   FRESH   the exporter is writing
        #   STALE   a file exists but is older than the snapshot's bar -> the exporter
        #           or its terminal died at a knowable time; the file says when
        #   BLIND   no file at all -> the exporter was never attached, or its account
        #           was never rotated through; there is no "when"
        #   MISSING the account is not in the floating_risk array at all -> the snapshot
        #           writer did not even consider it. Not the same as BLIND.
        if ($null -eq $fr) {
            $failures.Add("float-$acct") | Out-Null
            $log.Add("COVERAGE GAP: account $acct (LAB_MANAGED) floating-risk sensor state=MISSING (no floating_risk entry in the snapshot at all)") | Out-Null
            continue
        }
        $st = "$($fr.state)"
        if ($st -eq 'FRESH') {
            $floatOk++
            continue
        }
        $failures.Add("float-$acct") | Out-Null
        $detail = ''
        if ($st -eq 'STALE') { $detail = " (age $($fr.age_hours)h - a file exists but the exporter stopped writing)" }
        elseif ($st -eq 'BLIND') { $detail = " (no AccountSnapshotExporter file for this account at all)" }
        else { $detail = " (unrecognised state - treated as not-fresh)" }
        $log.Add("COVERAGE GAP: account $acct (LAB_MANAGED) floating-risk sensor state=$st$detail") | Out-Null
    }
    $summary += " | $floatOk/$($labAccts.Count) LAB_MANAGED float-sensor fresh"
    if ($deploymentWarnings -gt 0 -or $deploymentBlocks -gt 0) {
        $summary += " | deployment verification: $deploymentWarnings pending, $deploymentBlocks UNVERIFIED"
    }
    if ($failures.Count -gt 0) {
        $floatBad = @($failures | Where-Object { $_ -like 'float-*' } | ForEach-Object { $_.Substring(6) })
        if ($floatBad.Count -gt 0) { $summary += "; float-sensor missing: $($floatBad -join ', ')" }
    }

    # non-LAB_MANAGED float sensors: logged, never red. Same rule as the deal sensors.
    foreach ($h in @($health | Where-Object { $_.governance_scope -ne 'LAB_MANAGED' })) {
        $acct = "$($h.account)"
        $fr = $floatByAcct[$acct]
        $st = if ($null -eq $fr) { 'MISSING' } else { "$($fr.state)" }
        if ($st -ne 'FRESH') {
            $log.Add("coverage note (not red): account $acct scope=$($h.governance_scope) floating-risk sensor state=$st") | Out-Null
        }
    }

    # accounts present in floating_risk with no system_health row -> scope unknown, so
    # neither rule above saw them. Report rather than drop; a silent drop here would be
    # the same defect in a new place.
    $healthAccts = @{}
    foreach ($h in $health) { $healthAccts["$($h.account)"] = $true }
    foreach ($f in $floatRows) {
        $acct = "$($f.account)"
        if (-not $healthAccts.ContainsKey($acct)) {
            $log.Add("coverage note (not red): account $acct is in floating_risk but has no system_health row - governance_scope unknown, so no rule was applied to it") | Out-Null
        }
    }

    # ---- 4. surface UNCLASSIFIED unknown magics (D5's counter) ----------------------
    # Not a failure: the classification bar for unknown magics is not this script's to
    # set. But a count that only exists inside a json file nobody opens is the shape of
    # problem this whole change is about, so it gets a line in the daily log.
    if ($null -ne $cr.summary -and [int]"$($cr.summary.unknown_magics_unclassified)" -gt 0) {
        $log.Add("coverage note (not red): $($cr.summary.unknown_magics_unclassified) unknown magic(s) UNCLASSIFIED - last_seen unparseable, so their age is UNKNOWN (see control_room_snapshot.json unknown_magics)") | Out-Null
    }

    return [pscustomobject]@{ Summary = $summary; Failures = $failures.ToArray(); Log = $log.ToArray() }
}
