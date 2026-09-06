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
        [string]$RepoRoot = '',
        # AUDIT C, C-A7. The caller states, as a FACT it owns, whether the snapshot BUILD step of
        # this run succeeded. daily_monitor.ps1 knows this ($failed -contains 'snapshot') and used
        # to throw the knowledge away, then read the file anyway -- so a failed build published
        # the PREVIOUS snapshot's coverage counts under today's date, as if newly measured.
        # There is no way for this function to infer it: after a failed build the file on disk is
        # a perfectly valid snapshot. It is just not THIS run's snapshot.
        [bool]$SnapshotBuildFailed = $false
    )

    $failures = New-Object System.Collections.Generic.List[string]
    $log = New-Object System.Collections.Generic.List[string]

    # ---- 0. C-A7: did the build that was supposed to produce this document actually run? -----
    # NOT MEASURED is not a softer failure than a dead sensor; it is a different one, and it must
    # not be dressed up in derived counts. Returning here is what makes that impossible.
    if ($SnapshotBuildFailed) {
        $msg = "coverage NOT MEASURED [snapshot-build-failed]: the snapshot build step of THIS run failed, so portfolio\control_room_snapshot.json still holds a PREVIOUS build. No coverage count is derived from it - a stale document's numbers are not this morning's measurement"
        $failures.Add('snapshot-build-failed') | Out-Null
        $log.Add($msg) | Out-Null
        return [pscustomobject]@{ Summary = $msg; Failures = $failures.ToArray(); Log = $log.ToArray() }
    }

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
    # AUDIT C, C-A1/C-A6. Integrity OK is not the same as "these numbers describe now". The two
    # new refusals get their own tokens because they have their own fixes:
    #   snapshot-stale           rebuild it (scripts\control_room_snapshot.ps1)
    #   snapshot-source-changed  a recorded source moved under the document -> rebuild, and find
    #                            out who wrote to the source after the build
    # Trust is resolved by the reader; matching Reason text would be the shape ORDER-612 already
    # banned in this file.
    $trust = Resolve-SnapshotTrustToken $verified
    if ($trust -ne 'OK') {
        $token = if ("$($verified.SourceIntegrity.State)" -in @('CHANGED','UNREADABLE','UNKNOWN')) { 'snapshot-source-changed' } else { 'snapshot-stale' }
        $msg = "coverage check FAILED [$token]: $($verified.Reason) - the document is intact but NOT current, so none of its sensor rows may be read as today's measurement"
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
        # AUDIT C, C-A3 + C-A9. The identity COVERAGE gap is a different finding from the identity
        # VALIDATION state above, and only this one can see a deployment that has no mapping at
        # all. A snapshot too old to carry the coverage block gets its own token rather than a
        # pass: "the writer did not publish it" must not read as "there is no gap".
        #
        # READS FROM $cr.summary.identity_coverage, NOT $identitySummary.coverage: the builder
        # (scripts\control_room_snapshot.ps1) writes it there because
        # _triage\factory_os\schemas.json's runtime_identity_summary is closed
        # (unevaluatedProperties:false) and does not list `coverage` -- see that file's own note
        # at the C-A3/C-A9 block for the measured detail and the INTEGRATION REQUEST to move it
        # back once the schema is widened.
        $identityCov = $null
        if ($null -ne $cr.summary) { $identityCov = $cr.summary.identity_coverage }
        if ($null -eq $identityCov) {
            $failures.Add('runtime-identity-coverage-unknown') | Out-Null
            $log.Add("COVERAGE GAP: this snapshot publishes no summary.identity_coverage block, so the number of forward-observed deployments owed an identity mapping is UNKNOWN - not zero") | Out-Null
        } elseif ("$($identityCov.state)" -ne 'PASS') {
            $failures.Add("runtime-identity-coverage-$("$($identityCov.state)".ToLower())") | Out-Null
            $log.Add("COVERAGE GAP: runtime identity coverage $($identityCov.state) - expected $($identityCov.expected) forward-observed deployment(s) from $($identityCov.expected_source); mapped $($identityCov.mapped), validated PASS $($identityCov.validated_pass), FULLY BOUND $($identityCov.fully_bound). $($identityCov.reason)") | Out-Null
            $unmappedList = @($identityCov.unmapped)
            if ($unmappedList.Count -gt 0) {
                $log.Add("  identity UNMAPPED (no RUNTIME_IDENTITY_MAP.csv row): " + ((@($unmappedList | Select-Object -First 12)) -join ', ') + $(if ($unmappedList.Count -gt 12) { " ... +$($unmappedList.Count - 12) more" } else { '' })) | Out-Null
            }
        }

        # RUNTIME_IDENTITY_COVERAGE_CONTRACT_20260905. Informational only, on purpose: this block
        # never adds to $failures, so the pre-existing x58/global DEGRADED_MONITORING behavior is
        # byte-identical to before this sub-reporting existed. It surfaces the two scope dimensions
        # (mechanism capability, certification responsibility) that used to be invisible inside the
        # single x58 denominator, reading only the structured portfolio\CERTIFICATION_SCOPE.csv via
        # $cr.summary.certification_scope_coverage (the builder writes it there for the same closed-
        # schema reason identity_coverage lives there -- see control_room_snapshot.ps1).
        $certScope = $null
        if ($null -ne $cr.summary) { $certScope = $cr.summary.certification_scope_coverage }
        if ($null -eq $certScope) {
            $log.Add("coverage note (not red): this snapshot publishes no summary.certification_scope_coverage block (older writer or missing portfolio\CERTIFICATION_SCOPE.csv)") | Out-Null
        } else {
            $log.Add("COVERAGE (informational): certification scope $($certScope.state) - total_forward_observed=$($certScope.scope_total_forward_observed) native_identity_capable=$($certScope.scope_native_identity_capable) mechanism_unavailable=$($certScope.scope_mechanism_unavailable) lab_certified=$($certScope.scope_lab_certified) user_owned_uncertified=$($certScope.scope_user_owned_uncertified) unknown=$($certScope.scope_unknown)") | Out-Null
            $missingScope = @($certScope.missing_scope_fact)
            if ($missingScope.Count -gt 0) {
                $log.Add("  certification scope MISSING (no CERTIFICATION_SCOPE.csv row): " + ((@($missingScope | Select-Object -First 12)) -join ', ') + $(if ($missingScope.Count -gt 12) { " ... +$($missingScope.Count - 12) more" } else { '' })) | Out-Null
            }
            $orphanedScope = @($certScope.orphaned_scope_rows)
            if ($orphanedScope.Count -gt 0) {
                $log.Add("  certification scope ORPHANED (CERTIFICATION_SCOPE.csv row outside current forward-observed scope): " + ($orphanedScope -join ', ')) | Out-Null
            }
            $certParseErrors = @($certScope.parse_errors)
            if ($certParseErrors.Count -gt 0) {
                $log.Add("  certification scope CSV parse errors (counts above are UNTRUSTED until fixed): " + (($certParseErrors | ForEach-Object { "$($_.code)=$($_.detail)" }) -join '; ')) | Out-Null
            }
        }
    }

    # ---- 1b. deployment attachment/verification coverage (ORDER-944) ----------------
    # A deployment row is part of the monitoring universe even when its verification is
    # pending or absent. Normalize the rows through the same closed status contract used by
    # the writers; an unknown status is a data-integrity failure, never an omitted row.
    #
    # AUDIT C, C-A2 + C-A5 (2026-08-20, lane M0-L1). The rows are re-derived here THROUGH THE
    # SNAPSHOT'S OWN EVIDENCE SECTIONS rather than trusted as written. The snapshot on disk was
    # built when the ACTIVE lifecycle word alone produced verification_state=VERIFIED, so reading
    # its verification_state field back would re-import the very claim C-A2 removed. Building the
    # evidence table from $cr.attestation + $cr.runtime_identity and re-resolving is what makes
    # the hand-written attestation confidence reach an operator FAILURE TOKEN (C-A5) instead of
    # sitting in a JSON field nobody opens.
    $evidence = @{}
    foreach ($a in @($cr.attestation)) {
        if ($null -eq $a) { continue }
        $evidence["$($a.account)|$($a.magic)"] = @{
            attestation_state      = "$($a.state)"
            attestation_confidence = "$($a.confidence)"
            runtime_identity_state = ''
        }
    }
    foreach ($ri in @($cr.runtime_identity)) {
        if ($null -eq $ri) { continue }
        $k = "$($ri.account_login)|$($ri.magic)"
        if (-not $evidence.ContainsKey($k)) {
            $evidence[$k] = @{ attestation_state = ''; attestation_confidence = ''; runtime_identity_state = '' }
        }
        $evidence[$k].runtime_identity_state = "$($ri.validation_state)"
    }
    $deploymentRows = @()
    if ($null -ne $cr.deployments -and $null -ne $cr.deployments.rows) {
        try {
            $deploymentRows = @(Get-DeploymentMonitoringRows -Rows @($cr.deployments.rows) -Evidence $evidence)
        } catch {
            $msg = "coverage check FAILED [deployment-status-invalid]: $($_.Exception.Message) - deployment monitoring cannot classify every inventory row"
            $failures.Add('deployment-status-invalid') | Out-Null
            $log.Add($msg) | Out-Null
        }
    }
    $deploymentWarnings = 0
    $deploymentBlocks = 0
    $deploymentUnderived = New-Object System.Collections.Generic.List[string]
    $deploymentVerified = 0
    foreach ($d in $deploymentRows) {
        if ($d.verification_state -eq 'UNVERIFIED') {
            $deploymentBlocks++
            $failures.Add("deployment-unverified-$($d.account)|$($d.magic)") | Out-Null
            $log.Add("COVERAGE GAP: deployment $($d.account)|$($d.magic) is visible but BLOCKED: operational=$($d.operational_status), verification=UNVERIFIED") | Out-Null
        } elseif ($d.verification_state -eq 'PENDING' -and $d.verification_basis -eq 'NO_EVIDENCE') {
            # C-A2. The row the CSV calls ACTIVE and nothing verifies. Aggregated into ONE token
            # deliberately: on the measured fleet this is 58 rows, and 58 tokens in the alert line
            # is a wall of text that gets muted inside a week (the ORDER-219 lesson). The per-row
            # detail still goes to the log, capped, with the count stated.
            $deploymentUnderived.Add("$($d.account)|$($d.magic) [$($d.verification_evidence)]") | Out-Null
        } elseif ($d.verification_state -eq 'PENDING') {
            $deploymentWarnings++
            $failures.Add("deployment-pending-verification-$($d.account)|$($d.magic)") | Out-Null
            $log.Add("COVERAGE GAP: deployment $($d.account)|$($d.magic) is visible but WARNING: operational=$($d.operational_status), verification=PENDING") | Out-Null
        } elseif ($d.verification_state -eq 'VERIFIED') {
            $deploymentVerified++
        }
    }
    if ($deploymentUnderived.Count -gt 0) {
        $failures.Add("deployment-verification-underived-x$($deploymentUnderived.Count)") | Out-Null
        $log.Add("COVERAGE GAP: $($deploymentUnderived.Count) deployment(s) are ACTIVE in DEPLOYMENTS.csv with NO verification evidence in this snapshot (attestation HASHED/high + runtime_identity PASS are both required). The lifecycle word ACTIVE is an attachment intent, not a verification claim") | Out-Null
        foreach ($u in @($deploymentUnderived | Select-Object -First 12)) {
            $log.Add("  verification underived: $u") | Out-Null
        }
        if ($deploymentUnderived.Count -gt 12) {
            $log.Add("  ... and $($deploymentUnderived.Count - 12) more (full list in control_room_snapshot.json deployments.rows[].verification_evidence)") | Out-Null
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
    if ($deploymentWarnings -gt 0 -or $deploymentBlocks -gt 0 -or $deploymentUnderived.Count -gt 0) {
        # C-A2/C-A5: the derived-VERIFIED count is stated even when it is 0, next to the underived
        # count. "0 verified / 58 underived" is the sentence the old code could not produce.
        $summary += " | deployment verification: $deploymentVerified evidence-VERIFIED, $($deploymentUnderived.Count) underived (ACTIVE, no evidence), $deploymentWarnings declared-pending, $deploymentBlocks UNVERIFIED"
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


<#
AUDIT C REPAIR, C-A10 (2026-08-20, lane M0-L1): monitoring-chain health had no route to either
operator surface.

MEASURED on canonical 649207d6:
  portfolio\daily_monitor_last_success.txt = "2026-07-31 07:37:35"  (20 days before today)
  portfolio\MONITOR_ALERT.txt              = "2026-08-05 07:37 monitoring chain UNHEALTHY:
                                              snapshot, notify-projection, sensor-141049900,
                                              sensor-69424711 ..."
  grep -i 'last success|daily_monitor|MONITOR_ALERT|UNHEALTHY' STATUS.html  -> 0 hits
  same grep over scripts\status_template.html                               -> 0 hits

So the two files the chain writes to say "I have not succeeded in 20 days, and here is the
standing alert" were invisible on both surfaces, while {{MONITORING_LABEL}} was derived
exclusively from the SNAPSHOT VERDICT -- a document the dead chain is no longer refreshing. That
is the worst possible arrangement: the indicator is fed by the very thing the outage stops
updating.

Note what that alert text independently proves about C-A7: it names `snapshot` as a FAILED step
and then reports "4/6 LAB_MANAGED deal-sensor fresh" in the same sentence. Those counts came from
a PREVIOUS build. The operator's own alert file recorded the defect.

NO NEW THRESHOLD IS INVENTED HERE. The overdue bar is supplied by the caller from the same
canonical authority C-A1 uses (meta.stale_bar_hours). A run with no bar available reports UNKNOWN;
it is never quietly called healthy.
#>
function Get-MonitorChainHealth {
    <#
      Returns:
        State        'OK' | 'ALERT' | 'OVERDUE' | 'UNKNOWN'
        LastSuccess  [string] as recorded by daily_monitor.ps1, or '' when unavailable
        AgeHours     [double] hours since that recorded success, or $null
        BarHours     [double] the overdue bar actually used, or $null
        AlertText    [string] the standing MONITOR_ALERT.txt text on one line, or ''
        Reason       [string] one human line
      Never throws: an unreadable marker is a RESULT ('UNKNOWN'), never an exception and never a
      silent OK.
    #>
    param(
        [string]$RepoRoot = '',
        # Supplied by the caller from the snapshot's own meta.stale_bar_hours. 0 or absent means
        # the caller could not establish a bar, which yields UNKNOWN rather than a guessed number.
        [double]$BarHours = 0,
        [datetime]$Now = (Get-Date)
    )
    if (-not $RepoRoot) { $RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSScriptRoot }
    $markerPath = Join-Path $RepoRoot 'portfolio\daily_monitor_last_success.txt'
    $alertPath  = Join-Path $RepoRoot 'portfolio\MONITOR_ALERT.txt'

    $alertText = ''
    if (Test-Path -LiteralPath $alertPath) {
        try {
            $raw = [System.IO.File]::ReadAllText($alertPath)
            if ($raw.Length -gt 0 -and [int]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
            $alertText = ($raw -replace '[\r\n]+', ' ').Trim()
            if ($alertText -eq '') { $alertText = '(MONITOR_ALERT.txt exists but is empty)' }
        } catch {
            $alertText = "MONITOR_ALERT.txt exists and could not be read: $($_.Exception.Message)"
        }
    }

    $lastText = ''
    $ageH = $null
    $markerReadable = $false
    if (Test-Path -LiteralPath $markerPath) {
        try {
            $raw = [System.IO.File]::ReadAllText($markerPath)
            if ($raw.Length -gt 0 -and [int]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
            $lastText = $raw.Trim()
            $markerReadable = $true
        } catch { $lastText = '' }
    }
    $parsed = [datetime]::MinValue
    if ($markerReadable -and $lastText -ne '' -and [datetime]::TryParse($lastText, [ref]$parsed)) {
        $ageH = [math]::Round(($Now - $parsed).TotalHours, 1)
    }

    # PRECEDENCE, and it is deliberate: a standing ALERT outranks any age computation. The alert
    # file is the chain's own statement that its last attempt did not succeed; letting a
    # recent-enough timestamp paint over it would be the "green with a dead sensor" shape again.
    if ($alertText -ne '') {
        return [pscustomobject]@{
            State = 'ALERT'; LastSuccess = $lastText; AgeHours = $ageH
            BarHours = $(if ($BarHours -gt 0) { $BarHours } else { $null })
            AlertText = $alertText
            Reason = "the monitoring chain left a standing alert: $alertText"
        }
    }
    if ($null -eq $ageH) {
        return [pscustomobject]@{
            State = 'UNKNOWN'; LastSuccess = $lastText; AgeHours = $null
            BarHours = $(if ($BarHours -gt 0) { $BarHours } else { $null })
            AlertText = ''
            Reason = "no readable last-success marker at portfolio\daily_monitor_last_success.txt, so it is not known whether the chain has ever completed"
        }
    }
    if ($BarHours -le 0) {
        return [pscustomobject]@{
            State = 'UNKNOWN'; LastSuccess = $lastText; AgeHours = $ageH; BarHours = $null; AlertText = ''
            Reason = "last success $lastText (${ageH}h ago), but no overdue bar was available to judge it against"
        }
    }
    if ($ageH -gt $BarHours) {
        return [pscustomobject]@{
            State = 'OVERDUE'; LastSuccess = $lastText; AgeHours = $ageH; BarHours = $BarHours; AlertText = ''
            Reason = "the chain last succeeded $lastText = ${ageH}h ago, past the ${BarHours}h bar"
        }
    }
    return [pscustomobject]@{
        State = 'OK'; LastSuccess = $lastText; AgeHours = $ageH; BarHours = $BarHours; AlertText = ''
        Reason = ''
    }
}

function Format-MonitorChainBlock {
    <#
      STATUS.md rendering of Get-MonitorChainHealth. EVERY state prints a line; there is no state
      that prints nothing, because "nothing" is exactly what this defect looked like.
    #>
    param([Parameter(Mandatory = $true)]$Health)
    $out = @()
    $last = if ("$($Health.LastSuccess)" -ne '') { "$($Health.LastSuccess)" } else { 'never recorded' }
    $age  = if ($null -ne $Health.AgeHours) { "$($Health.AgeHours)h ago" } else { 'age unknown' }
    $bar  = if ($null -ne $Health.BarHours) { "$($Health.BarHours)h" } else { 'no bar available' }
    if ($Health.State -eq 'OK') {
        $out += "- monitoring chain: **OK** - last full success ``$last`` ($age, bar $bar), no standing alert"
        return $out
    }
    $out += "> :rotating_light: **MONITORING CHAIN $($Health.State)**"
    $out += ">"
    $out += "> last full success: ``$last`` ($age, bar $bar)"
    if ("$($Health.AlertText)" -ne '') {
        $out += "> standing alert (``portfolio\MONITOR_ALERT.txt``):"
        $out += "> ``$($Health.AlertText)``"
    }
    $out += "> $($Health.Reason)"
    return $out
}

function Format-MonitorChainHtml {
    <#
      STATUS.html twin of Format-MonitorChainBlock. The text is HTML-escaped: MONITOR_ALERT.txt
      carries arbitrary step/operator text and this sink is a browser.
    #>
    param([Parameter(Mandatory = $true)]$Health)
    function _EscChain([string]$s) {
        if ($null -eq $s) { return '' }
        return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;')
    }
    $last = if ("$($Health.LastSuccess)" -ne '') { "$($Health.LastSuccess)" } else { 'never recorded' }
    $age  = if ($null -ne $Health.AgeHours) { "$($Health.AgeHours)h ago" } else { 'age unknown' }
    $bar  = if ($null -ne $Health.BarHours) { "$($Health.BarHours)h" } else { 'no bar available' }
    if ($Health.State -eq 'OK') {
        return "<div class='note'>monitoring chain: <b>OK</b> - last full success <span class='mono'>$(_EscChain $last)</span> ($(_EscChain $age), bar $(_EscChain $bar)), no standing alert</div>"
    }
    $alertHtml = ''
    if ("$($Health.AlertText)" -ne '') {
        $alertHtml = "<br>standing alert (<span class='mono'>portfolio\MONITOR_ALERT.txt</span>): <span class='mono'>$(_EscChain $Health.AlertText)</span>"
    }
    return "<div class='todo'><span class='dot' style='color:var(--red)'>&#9679;</span><div><b>MONITORING CHAIN $(_EscChain $Health.State)</b><br>last full success <span class='mono'>$(_EscChain $last)</span> ($(_EscChain $age), bar $(_EscChain $bar))$alertHtml<br>$(_EscChain $Health.Reason)</div></div>"
}
