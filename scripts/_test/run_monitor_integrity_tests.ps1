<#
.SYNOPSIS
    Stage 0B cage for the morning monitoring chain: coverage, base equity, account
    universe, and unknown-magic age classification.

.DESCRIPTION
    WHAT THIS EXISTS TO PIN
      Four of the defects it covers share one shape -- the shape this repo has now
      shipped five separate times (ORDER-260, 341, 370, 390, 411): a detector keeps
      running, keeps producing a green artifact, and quietly stops reporting.

        D1  daily_monitor.ps1 read only $cr.system_health for its coverage check.
            system_health measures the CLOSED-DEAL exporter. The floating-risk
            sensor (AccountSnapshotExporter) lives in $cr.floating_risk and was
            never consulted, so an account's live/open-position eye could be dead
            while closed-deal history stayed fresh and the chain exited 0.
        D2  the catch around ConvertFrom-Json built a message, logged it, and did
            NOT append to $failed. "I could not read the input" was reported the
            same way as "there was nothing to report". Same for a MISSING snapshot,
            which set the string "coverage check skipped" -- on a chain whose entire
            job is coverage.
        D3  live_dashboard.ps1 applied one hardcoded $BaseEquity = 10000 to every
            account. ACCOUNTS.csv records base_equity for exactly one account
            (463666728 = 100000), so every DD% and every kill-DD-equivalent on the
            other five was a number computed from a denominator nobody had recorded.
        D4  the dashboard's account universe came from whatever CSV happened to be
            in live_deals\, not from ACCOUNTS.csv -- so a Strategy-Tester login
            (146237) rendered indistinguishably from a lab account.
        D5  control_room_snapshot.ps1 defaulted $ageClass to 'HISTORICAL' and only
            promoted to ACTIVE on a parseable recent date. An UNPARSEABLE timestamp
            therefore landed in the quiet bucket. Its comment called that "the safer
            bucket"; it is not -- it converts "I don't know" into "nothing to see".

    HOW IT IS TESTED
      Three different techniques, chosen per target, and none of them reimplements
      the thing it tests (a test that reimplements its subject proves nothing):

        PART 1 (D5)      AST-lifts the real classifier functions out of the shipped
                         control_room_snapshot.ps1. The file cannot be dot-sourced
                         (it runs a whole snapshot build), so the functions are
                         extracted by name and REQUIRED to exist -- a rename fails
                         the suite loudly rather than testing nothing.
        PART 2-3 (D1/D2) dot-sources scripts\lib\monitor_coverage.ps1, the library
                         daily_monitor.ps1 itself calls, and drives it with the JSON
                         fixtures under fixtures\monitor\.
        PART 4-5 (D3/D4) runs the REAL live_dashboard.ps1 end to end against a
                         fixture portfolio\ tree and asserts on the HTML it writes.

    SENSITIVITY *AND* SPECIFICITY (memory: gate-specificity-not-just-sensitivity)
      Every red case has a green twin. An implementation that returns red for
      everything fails the green cases; one that returns green for everything fails
      the red cases. The two base-equity accounts carry DIFFERENT values (10000 and
      100000) against the SAME trade series, so a fix that resolves per-account but
      reads the wrong row still fails -- "it varies" is not the assertion, the two
      specific numbers are.

.NOTES
    Offline, deterministic, no MT5, no network, no process launched. Writes only
    into a fresh temp directory, which it removes.
    Pure ASCII on purpose: PowerShell 5.1 decodes a BOM-less .ps1 as ANSI.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    # MUTATION-TEST LEVER. Points PART 2/3 at a different implementation of
    # Get-MonitorCoverage. It exists so the claim "this cage discriminates" can be
    # DEMONSTRATED rather than asserted: transcribe the pre-fix inline block from
    # daily_monitor.ps1 into a file and run
    #   run_monitor_integrity_tests.ps1 -CoverageLib <that file>
    # -- the red cases must go red. A cage nobody has watched fail is UNTESTED.
    # Defaults to the shipped library, which is what the pre-commit tier runs.
    [string]$CoverageLib = '',
    # Same lever for PART 4/5. Copy scripts\live_dashboard.ps1, reintroduce the defect
    # (e.g. make Get-AcctBase return a flat 10000, or make Get-AcctLabel never say
    # UNREGISTERED), and point this at the copy: the D3/D4 assertions must go red.
    [string]$DashScript = ''
)

$ErrorActionPreference = 'Stop'

# scripts/_test/ -> repo root is TWO levels up. $PSScriptRoot is empty under
# `powershell.exe -File <relative>` from a non-PowerShell shell, so fall back
# rather than silently computing a wrong root.
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}

$fixtures = Join-Path $RepoRoot 'scripts\_test\fixtures\monitor'
$snapScript = Join-Path $RepoRoot 'scripts\control_room_snapshot.ps1'
if (-not $CoverageLib) { $CoverageLib = Join-Path $RepoRoot 'scripts\lib\monitor_coverage.ps1' }
if (-not $DashScript) { $DashScript = Join-Path $RepoRoot 'scripts\live_dashboard.ps1' }
$dashScript = $DashScript
$statusLib = Join-Path $RepoRoot 'scripts\lib\deployment_status.ps1'

$script:pass = 0
$script:fail = 0

function Assert-Equal {
    param([string]$What, $Expected, $Actual)
    if ("$Expected" -eq "$Actual") {
        $script:pass++
        Write-Host ("   [PASS] {0}" -f $What) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("   [FAIL] {0}`n          expected: {1}`n          actual  : {2}" -f $What, $Expected, $Actual) -ForegroundColor Red
    }
}

function Assert-True {
    param([string]$What, $Condition)
    Assert-Equal $What $true ([bool]$Condition)
}

# =====================================================================================
# ORDER-944 -- deployment status is a closed, fail-visible model. This is the public
# seam shared by the snapshot, dashboard, and coverage reader; the consumers are tested
# below at their real boundaries as well.
# =====================================================================================
Write-Host ''
Write-Host '=== ORDER-944: deployment visibility and verification state ==='
if (-not (Test-Path $statusLib)) { throw "missing: $statusLib" }
. $statusLib

$statusRows = @(
    [pscustomobject]@{ account='100000001'; magic='900001'; status='ACTIVE'; ea_name='ACTIVE_EA' },
    [pscustomobject]@{ account='100000001'; magic='900004'; status='ACTIVE-PENDING-VERIFY'; ea_name='PENDING_EA' },
    [pscustomobject]@{ account='100000001'; magic='900005'; status='UNVERIFIED'; ea_name='UNVERIFIED_EA' },
    [pscustomobject]@{ account='100000001'; magic='900006'; status='PENDING_ATTACH'; ea_name='PENDING_ATTACH_EA' },
    [pscustomobject]@{ account='100000001'; magic='900007'; status='REMOVED'; ea_name='REMOVED_EA' }
)
$normalised = @(Get-DeploymentMonitoringRows $statusRows)
$active = $normalised | Where-Object { $_.magic -eq '900001' }
$pending = $normalised | Where-Object { $_.magic -eq '900004' }
$unverified = $normalised | Where-Object { $_.magic -eq '900005' }
Assert-True 'ACTIVE row remains visible and verified' ($active.monitoring_visible -and $active.operational_status -eq 'ATTACHED' -and $active.verification_state -eq 'VERIFIED' -and $active.attention -eq 'NONE')
Assert-True 'ACTIVE-PENDING-VERIFY remains visible as attached but pending verification' ($pending.monitoring_visible -and $pending.forward_observed -and $pending.operational_status -eq 'ATTACHED' -and $pending.verification_state -eq 'PENDING' -and $pending.attention -eq 'WARNING')
Assert-True 'UNVERIFIED remains visible and blocked' ($unverified.monitoring_visible -and $unverified.verification_state -eq 'UNVERIFIED' -and $unverified.attention -eq 'BLOCKED')
Assert-Equal 'all declared statuses are accepted' 5 $normalised.Count
$unknownRejected = $false
try { Get-DeploymentMonitoringRows @([pscustomobject]@{ account='100000001'; magic='900008'; status='MYSTERY' }) | Out-Null } catch { $unknownRejected = $true }
Assert-True 'unknown deployment status is rejected fail-closed' $unknownRejected
Assert-True 'pending/unverified rows stay visible to snapshot and judge/attestation consumers' `
    ((Get-Content $snapScript -Raw) -match 'Get-DeploymentMonitoringRows' -and
     (Get-Content $snapScript -Raw) -match 'operational_status' -and
     (Get-Content $snapScript -Raw) -match 'verification_state')
Assert-True 'coverage consumer has a deployment-status visibility check' `
    ((Get-Content $CoverageLib -Raw) -match 'deployment-pending-verification' -and
     (Get-Content $CoverageLib -Raw) -match 'deployment-unverified')

# =====================================================================================
# PART 1 (D5) -- unknown-magic age classification
# =====================================================================================
# Same extraction idiom as run_mris_asof_tests.ps1: take EVERY function out of the file
# by AST and REQUIRE the ones under test. A curated subset goes stale the moment a helper
# is added; requiring by name means a rename throws instead of silently testing nothing.
function Get-FunctionSource {
    param([string]$Path, [string[]]$Require)
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    $found = [ordered]@{}
    foreach ($d in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        if (-not $found.Contains($d.Name)) { $found[$d.Name] = $d.Extent.Text }
    }
    $missing = @($Require | Where-Object { -not $found.Contains($_) })
    if ($missing.Count -gt 0) {
        throw ("cannot extract {0} from {1} -- renamed or removed? A cage that silently tests nothing is the bug it is meant to catch." -f ($missing -join ', '), (Split-Path -Leaf $Path))
    }
    return $found
}

Write-Host ''
Write-Host '=== PART 1 (D5): an unparseable last_seen must not be filed as HISTORICAL ==='
if (-not (Test-Path $snapScript)) { throw "missing: $snapScript" }
$snapSrc = Get-FunctionSource -Path $snapScript -Require @('TryParseTradeTime', 'ClassifyUnknownAge')
foreach ($t in $snapSrc.Values) { . ([ScriptBlock]::Create($t)) }
Write-Host ("   extracted {0} function(s) from the shipped control_room_snapshot.ps1" -f $snapSrc.Count)

$asOf = [datetime]'2026-07-30 06:00:00'

# The three buckets. The MT5/MT4 report shape is "2026.05.07 07:12:09" (dot-separated date).
Assert-Equal 'a close 1 day ago is ACTIVE' 'ACTIVE' (ClassifyUnknownAge '2026.07.29 14:59:18' $asOf)
Assert-Equal 'a close exactly 14 days ago is still ACTIVE (boundary, inclusive)' 'ACTIVE' (ClassifyUnknownAge '2026.07.16 06:00:00' $asOf)
Assert-Equal 'a close 15 days ago is HISTORICAL' 'HISTORICAL' (ClassifyUnknownAge '2026.07.15 05:00:00' $asOf)
Assert-Equal 'a close 3 months ago is HISTORICAL (specificity: the quiet bucket still works)' 'HISTORICAL' (ClassifyUnknownAge '2026.05.07 07:12:09' $asOf)

# THE DEFECT. Every one of these used to answer HISTORICAL.
Assert-Equal 'garbage timestamp is UNCLASSIFIED, not HISTORICAL' 'UNCLASSIFIED' (ClassifyUnknownAge 'not-a-date' $asOf)
Assert-Equal 'empty timestamp is UNCLASSIFIED, not HISTORICAL' 'UNCLASSIFIED' (ClassifyUnknownAge '' $asOf)
Assert-Equal 'whitespace timestamp is UNCLASSIFIED, not HISTORICAL' 'UNCLASSIFIED' (ClassifyUnknownAge '   ' $asOf)
Assert-Equal 'a bare integer where a time string belongs is UNCLASSIFIED' 'UNCLASSIFIED' (ClassifyUnknownAge '0' $asOf)
Assert-Equal 'an out-of-range date is UNCLASSIFIED' 'UNCLASSIFIED' (ClassifyUnknownAge '2026-13-45 99:99:99' $asOf)
Assert-Equal 'a spreadsheet error value is UNCLASSIFIED' 'UNCLASSIFIED' (ClassifyUnknownAge '#N/A' $asOf)

# A classifier that answered UNCLASSIFIED for everything would pass the six lines above
# and fail the four before them. Both directions are asserted on purpose.
#
# MEASURED, and left here as a warning rather than an assertion: [datetime]::TryParse is
# LENIENT. A truncated "2026.07." parses cleanly as 2026-07-01, and "2026.07.29 14:5" as
# 14:05. So UNCLASSIFIED catches unreadable input, not WRONG input -- a half-written
# timestamp still becomes a confident, plausible, silently incorrect date. Detecting that
# needs a shape check on the field, which is a separate change and is not made here.
Assert-Equal 'documented lenient-parse hazard: a truncated date parses as day 1, it does NOT reach UNCLASSIFIED' `
    'HISTORICAL' (ClassifyUnknownAge '2026.07.' $asOf)

Write-Host ''
Write-Host '=== PART 1b (D5): the UNCLASSIFIED count reaches the summary and the console ==='
$snapRaw = Get-Content $snapScript -Raw
Assert-True 'summary carries unknown_magics_unclassified next to _active/_historical' `
    ($snapRaw -match 'unknown_magics_unclassified')
Assert-True 'the console UNKNOWN line reports the unclassified count too' `
    ($snapRaw -match "UNKNOWN\s+\{0\}[^`n]*unclassified")

# =====================================================================================
# PART 2 (D1) -- a dead FLOATING sensor must be able to turn the chain red
# PART 3 (D2) -- an unreadable / missing snapshot must be able to turn the chain red
# =====================================================================================
Write-Host ''
Write-Host '=== PART 2/3 (D1/D2): coverage rules over control_room_snapshot.json ==='
if (-not (Test-Path $CoverageLib)) { throw "missing coverage library: $CoverageLib" }
. $CoverageLib
if (-not (Get-Command Get-MonitorCoverage -ErrorAction SilentlyContinue)) {
    throw "$CoverageLib did not define Get-MonitorCoverage"
}
Write-Host ("   library under test: {0}" -f $CoverageLib)

$snapDir = Join-Path $fixtures 'snapshots'

# ORDER-612 (S4). Get-MonitorCoverage now obtains the snapshot through snapshot_validator, so a
# fixture must be a document that VERIFIES -- the whole point of the change is that an
# unverified document reaches no reader. Two ways to get there, and only one of them is honest:
#
#   (a) hand-author v5 fixtures with a stored `verdict` typed in by hand. That is precisely the
#       attack the verifier exists to refuse, and the fixtures would have to be re-typed by hand
#       every time the verdict logic changes -- i.e. they would drift into agreeing with nothing.
#   (b) BUILD each fixture through the real pipeline at test time.
#
# (b). The .json files under snapshots\ stay exactly what they were: readable FRAGMENTS carrying
# the system_health / floating_risk / summary shapes under test. This function wraps a fragment in
# the v5 scaffolding and runs snapshot_build.py over it, so the fixture's verdict is computed by
# the same code the production writer uses. A fixture that stops building is a real failure.
#
# The source rows resolve against a TEMP ROOT created here, not against the repo: a source row
# pointing at a repo file would derive `fresh` from that file's mtime, so the fixtures would go
# red by the passage of time rather than by any change to the code -- the same defect as the
# drift guard that regenerated against HEAD (memory: drift-guard-regenerating-against-head).
$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$builder = Join-Path $RepoRoot '_triage\factory_os\snapshot_build.py'
$fxRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("crfx_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fxRoot -Force | Out-Null
Set-Content -Path (Join-Path $fxRoot 'srcA.txt') -Value 'fixture source A' -Encoding ASCII
$fxBuilt = @{}

function New-V5Fixture([string]$name) {
    if ($fxBuilt.ContainsKey($name)) { return $fxBuilt[$name] }
    $fragPath = Join-Path $snapDir $name
    $frag = Get-Content -LiteralPath $fragPath -Raw | ConvertFrom-Json
    $inp = [ordered]@{
        entity = 'SnapshotBuilderInput'
        meta = [ordered]@{
            schema = 'ControlRoomSnapshot'
            version = 5
            generated_at = (Get-Date).ToString('s')
            stale_bar_hours = 30
            mandatory_sources = @('srcA')
            sources = @([ordered]@{ name='srcA'; path='srcA.txt'; mandatory=$true
                                    read_ok=$null; sha256=$null; mtime=$null; age_hours=$null; fresh=$null })
            reconciliation = [ordered]@{
                discovered = 0; categorized = 0
                categories = [ordered]@{ actionable=0; running=0; waiting=0; review_audit=0; completed=0; cancelled_by_user=0 }
                duplicates = 0; conflicts = 0; unclassified = 0
                coverage = [ordered]@{ cells_in_universe=0; tested=0; untested=0; not_applicable=0 }
            }
        }
        system_health   = @($(if ($null -ne $frag.system_health)   { $frag.system_health }   else { @() }))
        floating_risk   = @($(if ($null -ne $frag.floating_risk)   { $frag.floating_risk }   else { @() }))
        deployments     =   $(if ($null -ne $frag.deployments)     { $frag.deployments }     else { [ordered]@{} })
        unknown_magics  = @($(if ($null -ne $frag.unknown_magics)  { $frag.unknown_magics }  else { @() }))
        attestation     = @($(if ($null -ne $frag.attestation)     { $frag.attestation }     else { @() }))
        judge_readiness = @($(if ($null -ne $frag.judge_readiness) { $frag.judge_readiness } else { @() }))
        judge_cohorts   = @($(if ($null -ne $frag.judge_cohorts)   { $frag.judge_cohorts }   else { @() }))
        summary         =   $(if ($null -ne $frag.summary)         { $frag.summary }         else { [ordered]@{} })
    }
    # MEASURED 2026-07-31 (ORDER-612 / S4): no_floating_section.json exists to test the branch
    # that fires when a snapshot carries no floating-risk data. Under v4 that meant an ABSENT
    # KEY, and this wrapper originally deleted the key to reproduce it. v5 refuses to build such
    # a document at all -- `floating_risk` is REQUIRED by ControlRoomSnapshotV5, and the build
    # failed naming it. That is the defence getting STRONGER, not the fixture getting weaker:
    # the absent-key case is now impossible to publish, so the reader branch is exercised by the
    # case that IS still reachable -- a writer that produced ZERO rows (an empty array), which
    # means the same operational thing and is what the fragment now carries.
    #
    # The criterion is unchanged: "when there are no floating-risk rows, say once and up front
    # why every account below reads MISSING." Only its input shape moved, because the contract
    # closed the other shape.
    $inPath  = Join-Path $fxRoot ("in_" + $name)
    $outPath = Join-Path $fxRoot ("v5_" + $name)
    [System.IO.File]::WriteAllText($inPath, ($inp | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($false)))
    # --no-reconcile: $fxRoot is a throwaway temp root with no real AGENT_TASKBOARD.md, so the
    # builder cannot derive a real reconciliation to verify meta.reconciliation against. Explicit
    # now (was implicit from passing a <source-root> at all, before snapshot_build.py's CLI split
    # the two independent switches -- see snapshot_build.py main()).
    $buildOut = & $py $builder build $inPath $outPath $fxRoot --no-reconcile 2>&1
    if ($LASTEXITCODE -ne 0) { throw "fixture $name did not build: $($buildOut -join ' ')" }
    $fxBuilt[$name] = $outPath
    return $outPath
}

# RAW fixtures: the three cases that are ABOUT the reader's failure paths and must NOT be built
# into valid documents, because then they would stop testing what they exist to test.
$RAW_FIXTURES = @('unreadable.json', 'not_a_snapshot.json')

function Cover([string]$name) {
    if ($RAW_FIXTURES -contains $name) { return Get-MonitorCoverage -SnapshotPath (Join-Path $snapDir $name) }
    return Get-MonitorCoverage -SnapshotPath (New-V5Fixture $name)
}
# Convenience: the two things daily_monitor.ps1 actually consumes.
function IsRed($r) { return ([int]$r.Failures.Count -gt 0) }
function LogText($r) { return (($r.Log) -join "`n") }

Write-Host '   -- GREEN: everything fresh (specificity: this must NOT be red) --'
$g = Cover 'green.json'
Assert-Equal 'green fixture produces no failure token' 0 $g.Failures.Count
Assert-True  'green fixture summary reports both sensors' `
    ($g.Summary -match 'deal-sensor fresh' -and $g.Summary -match 'float-sensor fresh')

Write-Host '   -- ORDER-944: deployment rows are visible to coverage --'
$dg = Cover 'deployment_status_gaps.json'
Assert-True 'ACTIVE row remains in the coverage snapshot input' ((LogText $dg) -notmatch 'deployment-status-invalid')
Assert-True 'pending verification cannot disappear from coverage' ((LogText $dg) -match '100000001\|900004.*WARNING.*ATTACHED.*PENDING' -and ($dg.Failures -join ',') -match 'deployment-pending-verification-100000001\|900004')
Assert-True 'UNVERIFIED cannot disappear from coverage and is blocked' ((LogText $dg) -match '100000001\|900005.*BLOCKED.*UNVERIFIED' -and ($dg.Failures -join ',') -match 'deployment-unverified-100000001\|900005')
$du = Cover 'deployment_status_unknown.json'
Assert-True 'unknown status in a snapshot fails coverage closed' (($du.Failures -join ',') -match 'deployment-status-invalid' -and (LogText $du) -match 'MYSTERY')

Write-Host '   -- WARN: a non-LAB_MANAGED account degraded on BOTH sensors --'
$w = Cover 'warn_nonlab.json'
Assert-Equal 'a USER_OBSERVED account never turns the chain red' 0 $w.Failures.Count
Assert-True  'but its dead deal sensor is logged' ((LogText $w) -match '900000001.*USER_OBSERVED.*deal-sensor')
Assert-True  'and its BLIND float sensor is logged too' ((LogText $w) -match '900000001.*USER_OBSERVED.*floating-risk sensor state=BLIND')

Write-Host '   -- RED: LAB_MANAGED float sensor BLIND (the D1 defect, verbatim) --'
$rb = Cover 'red_float_blind.json'
Assert-True  'a BLIND float sensor on a LAB_MANAGED account IS red' (IsRed $rb)
Assert-Equal 'exactly one failure token, naming the account' 'float-100000002' ($rb.Failures -join ',')
Assert-True  'the log names the account and says BLIND' ((LogText $rb) -match 'COVERAGE GAP: account 100000002 \(LAB_MANAGED\) floating-risk sensor state=BLIND')
Assert-True  'BLIND is explained as "no file at all", not as an age' ((LogText $rb) -match 'no AccountSnapshotExporter file')
Assert-True  'the healthy sibling account is NOT in the failure list' (($rb.Failures -join ',') -notmatch '100000001')

Write-Host '   -- RED: LAB_MANAGED float sensor STALE, kept distinct from BLIND --'
$rs = Cover 'red_float_stale.json'
Assert-True  'a STALE float sensor on a LAB_MANAGED account IS red' (IsRed $rs)
Assert-Equal 'exactly one failure token, naming the account' 'float-100000002' ($rs.Failures -join ',')
Assert-True  'the log says STALE, not BLIND' ((LogText $rs) -match 'floating-risk sensor state=STALE')
Assert-True  'STALE carries the age, which is the thing that distinguishes it from BLIND' ((LogText $rs) -match 'age 73\.5h')
Assert-True  'STALE is never described as BLIND' ((LogText $rs) -notmatch 'state=BLIND')

Write-Host '   -- RED: account missing from the floating_risk array entirely --'
$rm = Cover 'red_float_missing.json'
Assert-True  'an account with no floating_risk entry IS red' (IsRed $rm)
Assert-Equal 'the missing account is the one named' 'float-100000002' ($rm.Failures -join ',')
Assert-True  'MISSING is its own word - not folded into BLIND' ((LogText $rm) -match 'floating-risk sensor state=MISSING')
Assert-True  'a floating_risk row with no system_health row is reported, not dropped' ((LogText $rm) -match '900000009 is in floating_risk but has no system_health row')

Write-Host '   -- RED: the pre-existing deal-sensor rule must keep working (regression) --'
$rd = Cover 'red_deal_stale.json'
Assert-True  'a STALE deal sensor on a LAB_MANAGED account is still red' (IsRed $rd)
Assert-Equal 'and still uses the sensor- token the chain already logged' 'sensor-100000002' ($rd.Failures -join ',')

Write-Host '   -- RED: no floating_risk section at all --'
$nf = Cover 'no_floating_section.json'
Assert-True  'a snapshot with no floating_risk section is red' (IsRed $nf)
Assert-True  'and says once, up front, WHY every account below reads MISSING' ((LogText $nf) -match 'no floating_risk section')

Write-Host '   -- RED (D2): the snapshot cannot be read --'
$ur = Cover 'unreadable.json'
Assert-True  'malformed json IS red' (IsRed $ur)
Assert-Equal 'and says so with its own token' 'snapshot-unreadable' ($ur.Failures -join ',')
Assert-True  'the summary says FAILED, never "skipped"' ($ur.Summary -match 'FAILED' -and $ur.Summary -notmatch 'skipped')

# The chain does NOT run under $ErrorActionPreference = 'Stop' -- daily_monitor.ps1 sets
# none, so it inherits 'Continue', while this suite sets 'Stop' at the top. A try/catch that
# only catches under Stop would pass here and let a corrupt snapshot through in production.
# Assert the branch under the preference the real caller actually uses.
$savedEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$urC = Cover 'unreadable.json'
$ErrorActionPreference = $savedEap
Assert-Equal 'malformed json is still caught under $ErrorActionPreference = Continue (what daily_monitor runs under)' `
    'snapshot-unreadable' ($urC.Failures -join ',')

$ns = Cover 'not_a_snapshot.json'
Assert-True  'valid json that is not a snapshot IS red' (IsRed $ns)
Assert-Equal 'same token: we have no coverage data either way' 'snapshot-unreadable' ($ns.Failures -join ',')

Write-Host '   -- RED (D2): the snapshot is absent --'
$mi = Get-MonitorCoverage -SnapshotPath (Join-Path $snapDir 'this_file_does_not_exist.json')
Assert-True  'a missing snapshot IS red on a chain whose job is coverage' (IsRed $mi)
Assert-Equal 'with a token that distinguishes absent from corrupt' 'snapshot-missing' ($mi.Failures -join ',')
Assert-True  'the summary no longer says "skipped"' ($mi.Summary -notmatch 'skipped')

Write-Host '   -- NOT red: a negative floating P/L is not a failure --'
# green.json account 100000002 sits at equity 10000 vs balance 10500 = -500 floating.
# Deliberately unflagged: see the "WHAT IS DELIBERATELY NOT HERE" note in the library.
# There is no per-account floating-loss threshold in any owner file to read, and a
# guard that fires on an invented number is worse than no guard.
Assert-Equal 'an account 500 down on open positions, sensor alive, is green' 0 $g.Failures.Count
Assert-True  'and nothing in the log claims a P/L threshold was evaluated' ((LogText $g) -notmatch 'threshold')

Write-Host '   -- NOT red, but surfaced: UNCLASSIFIED unknown magics (D5 counter) --'
$uc = Cover 'unclassified.json'
Assert-Equal 'unclassified magics do not turn the chain red' 0 $uc.Failures.Count
Assert-True  'but the count reaches the daily log instead of only the json' ((LogText $uc) -match '2 unknown magic\(s\) UNCLASSIFIED')

Write-Host ''
Write-Host '=== PART 3b (D1/D2): daily_monitor.ps1 actually CONSUMES all of that ==='
# The rules being right is worthless if the chain does not act on them. These assert the
# wiring, which is the half that was broken: the old code computed $coverageMsg, logged
# it, and dropped the verdict on the floor.
$dm = Get-Content (Join-Path $RepoRoot 'scripts\daily_monitor.ps1') -Raw
Assert-True 'daily_monitor dot-sources the coverage library rather than inlining the rules' `
    ($dm -match 'monitor_coverage\.ps1')
Assert-True 'daily_monitor appends the coverage failures into $failed (which drives exit 1)' `
    ($dm -match '\$failed\s*\+=\s*\$cov(erage)?\.Failures')
# Match the SHAPE of the defect, not its vocabulary. The first draft of this assertion
# searched for the literal phrase "coverage check skipped" anywhere in the file -- and went
# red on the COMMENT that explains the fix. That is the check_state.ps1 section-7 lesson
# arriving one more time: an assertion over prose gets satisfied by rewording, so it tests
# the writing rather than the code. Assert the assignment and the parse call instead.
Assert-True 'daily_monitor no longer ASSIGNS a "skipped" coverage status' `
    ($dm -notmatch '\$coverageMsg\s*=\s*"coverage check skipped')
Assert-True 'daily_monitor no longer parses the snapshot inline (that is the library job now)' `
    ($dm -notmatch 'ConvertFrom-Json')

# =====================================================================================
# PART 4 (D3) -- base equity is per account, and UNKNOWN when it is not recorded
# PART 5 (D4) -- the account universe comes from ACCOUNTS.csv, and a stranger is
#                CLASSIFIED rather than hidden
# =====================================================================================
# This part runs the REAL live_dashboard.ps1 end to end and reads the HTML it writes.
# That is deliberate: the alternative is to re-derive the DD arithmetic in the test, and a
# test that reimplements its subject agrees with itself no matter what the subject does.
Write-Host ''
Write-Host '=== PART 4/5 (D3/D4): live_dashboard.ps1 over a fixture portfolio tree ==='
if (-not (Test-Path $dashScript)) { throw "missing: $dashScript" }

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("monitor_cage_" + [guid]::NewGuid().ToString('N'))
try {
    Copy-Item (Join-Path $fixtures 'dash\portfolio') (Join-Path $work 'portfolio') -Recurse -Force
    $wDeals = Join-Path $work 'portfolio\live_deals'
    # The floating panel greys anything older than 26h and drops it from the aggregates.
    # Fixture mtimes come from whenever git checked the files out, so stamp them now --
    # otherwise this suite would pass or fail depending on how old the clone is.
    Get-ChildItem (Join-Path $wDeals 'EA_LAB_snapshot_*.csv') | ForEach-Object { $_.LastWriteTime = (Get-Date) }
    $outHtml = Join-Path $work 'DASH.html'

    $dashOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dashScript `
        -LiveDealsDir $wDeals -OutFile $outHtml 2>&1
    $dashExit = $LASTEXITCODE
    Assert-Equal 'the dashboard runs clean over the fixture tree' 0 $dashExit
    if ($dashExit -ne 0) { Write-Host ($dashOut | Out-String) }
    $html = Get-Content $outHtml -Raw

    # ORDER-944 real dashboard seam: append one attached-but-pending row and one
    # unverified row (including the current blank-magic shape) to the isolated inventory.
    # Both must render as non-green rows with the two states printed separately.
    $invPath = Join-Path $work 'portfolio\DEPLOYMENTS.csv'
    $invRows = @(Import-Csv $invPath)
    $pendingInv = $invRows[0].PSObject.Copy()
    $pendingInv.account = '100000001'; $pendingInv.ea_name = 'PENDING_EA'; $pendingInv.magic = '900004'; $pendingInv.status = 'ACTIVE-PENDING-VERIFY'
    $unverifiedInv = $invRows[0].PSObject.Copy()
    $unverifiedInv.account = '100000001'; $unverifiedInv.ea_name = 'UNVERIFIED_EA'; $unverifiedInv.magic = ''; $unverifiedInv.status = 'UNVERIFIED'
    $invRows += $pendingInv; $invRows += $unverifiedInv
    $invRows | Export-Csv -LiteralPath $invPath -NoTypeInformation -Encoding UTF8
    $statusOut = Join-Path $work 'DASH_STATUS.html'
    $statusDashOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dashScript -LiveDealsDir $wDeals -OutFile $statusOut 2>&1
    Assert-Equal 'ACTIVE row remains visible in the dashboard' 0 $LASTEXITCODE
    $statusHtml = Get-Content $statusOut -Raw
    function StatusRow([string]$doc, [string]$needle) {
        foreach ($m in [regex]::Matches($doc, '(?s)<tr[^>]*>.*?</tr>')) {
            if ($m.Value -match 'status-cell' -and $m.Value -match [regex]::Escape($needle)) { return $m.Value }
        }
        return ''
    }
    $pendingHtmlRow = StatusRow $statusHtml 'PENDING_EA'
    $unverifiedHtmlRow = StatusRow $statusHtml 'UNVERIFIED_EA'
    Assert-True 'ACTIVE-PENDING-VERIFY remains visible in the dashboard' ($pendingHtmlRow -ne '')
    Assert-True 'pending verification is warning/non-green and names both states' ($pendingHtmlRow -match 'st-yellow' -and $pendingHtmlRow -match 'ATTACHED' -and $pendingHtmlRow -match 'PENDING' -and $pendingHtmlRow -notmatch 'st-green')
    Assert-True 'UNVERIFIED remains visible in the dashboard as blocked/non-green' ($unverifiedHtmlRow -match 'st-red' -and $unverifiedHtmlRow -match 'UNKNOWN' -and $unverifiedHtmlRow -match 'UNVERIFIED' -and $unverifiedHtmlRow -notmatch 'st-green')

    # Pull the CLOSED-DEALS <tr> for a magic. Scoped by the status-cell, which only the
    # closed-deals tables emit -- the first draft matched the first <tr> containing the
    # magic and kept landing on the FLOATING panel row instead, so five assertions were
    # reading the wrong table and reporting the code as broken when it was not. A test
    # that looks at the wrong place fails in the same shape as a real defect.
    function Row([string]$needle) {
        foreach ($m in [regex]::Matches($html, '(?s)<tr[^>]*>.*?</tr>')) {
            if ($m.Value -match 'status-cell' -and $m.Value -match [regex]::Escape($needle)) { return $m.Value }
        }
        return ''
    }

    Write-Host '   -- D3: SAME trades, DIFFERENT base equity -> different DD% --'
    # All three fixture accounts trade the identical series (+1000, -2000, +500), so any
    # difference between them can only come from the denominator.
    #   base  10000 -> peak 11000, trough  9000 -> 2000/11000  = 18.2%
    #   base 100000 -> peak 101000, trough 99000 -> 2000/101000 =  2.0%
    # Asserting the two SPECIFIC numbers, not merely that they differ: an implementation
    # that resolved per account but read the wrong row would still "vary".
    $rowSmall = Row '900001'
    $rowLarge = Row '900002'
    $rowNone  = Row '900003'
    Assert-True 'account with base_equity 10000 shows DD 18.2%' ($rowSmall -match '>18\.2%<')
    Assert-True 'account with base_equity 100000 shows DD 2% on the identical trades' ($rowLarge -match '>2%<')
    Assert-True 'the two are not the same number (the 10000-for-everyone defect)' `
        (($rowSmall -match '>18\.2%<') -and ($rowLarge -notmatch '>18\.2%<'))

    Write-Host '   -- D3: the two DD numbers drive DIFFERENT kill-switch verdicts --'
    # kill 20%, warn 16% (0.8 x kill). 18.2 -> yellow, 2.0 -> green. The denominator is
    # not cosmetic: it decides the flag colour on identical trading.
    Assert-True 'small-base account is flagged yellow (18.2% >= warn 16%)' ($rowSmall -match 'st-yellow')
    Assert-True 'large-base account is green on the same trades' ($rowLarge -match 'st-green')

    Write-Host '   -- D3: a blank base_equity renders UNKNOWN and computes NOTHING --'
    Assert-True 'no-base account shows UNKNOWN in its DD cell' ($rowNone -match '>UNKNOWN<')
    Assert-True 'no-base account shows NO percentage at all in that cell' ($rowNone -notmatch '>\d+(\.\d+)?%<\/td>\s*<td class="num-cell">\d+%')
    Assert-True 'no-base account is not silently painted green' ($rowNone -notmatch 'st-green')
    Assert-True 'no-base account gets its own status class' ($rowNone -match 'st-nobase')
    Assert-True 'and its label names the missing field and the account' `
        ($rowNone -match 'NOT COMPUTABLE' -and $rowNone -match 'base_equity' -and $rowNone -match '100000003')
    Assert-True 'the page never claims a 10000 default was applied' ($html -notmatch 'assumed 10,000')

    Write-Host '   -- D3: the floating panel kill-DD EQUIVALENT is per account too --'
    # Identical float_pl of -2500 on all three accounts, identical kill 20%.
    #   base  10000 -> equivalent  2000 -> -2500 breaches   -> red
    #   base 100000 -> equivalent 20000 -> -2500 does not   -> plain ref
    #   base UNKNOWN                                        -> no equivalent computable
    Assert-True 'small-base float basket breaches its kill-DD equivalent' `
        ($html -match 'float loss &ge; kill-DD equivalent \(20% of 10,000\)')
    Assert-True 'large-base float basket does NOT breach, on the identical -2500' `
        ($html -notmatch 'float loss &ge; kill-DD equivalent \(20% of 100,000\)')
    Assert-True 'large-base account shows the computed reference amount (20,000)' `
        ($html -match 'kill 20% ref \(20,000\)')
    Assert-True 'no-base account computes no currency equivalent at all' `
        ($html -match 'UNKNOWN</b>: no base_equity for account 100000003')

    Write-Host '   -- D3: the reader is told which denominator produced each column --'
    Assert-True 'the legend lists base equity per account' `
        ($html -match '100000001 = 10,000' -and $html -match '100000002 = 100,000' -and $html -match '100000003 = UNKNOWN')
    Assert-True 'and states how many accounts are missing one' ($html -match '1 registered account\(s\) have no base_equity recorded')

    Write-Host '   -- D4: an unregistered login is CLASSIFIED, not hidden --'
    Assert-True 'the unregistered login still appears on the page' ($html -match '900000009')
    Assert-True 'it is labelled UNREGISTERED / not a lab account' `
        ($html -match 'UNREGISTERED &mdash; not a lab account')
    Assert-True 'with the file it came from as provenance' `
        ($html -match 'EA_LAB_deals_900000009_20260730\.csv')
    Assert-True 'the account-universe panel exists' ($html -match 'ACCOUNT UNIVERSE')
    Assert-True 'its section header also carries the UNREGISTERED marker' `
        ($html -match 'UNREGISTERED / not a lab account - no row in ACCOUNTS\.csv')

    Write-Host '   -- D4 specificity: registered accounts must NOT be called unregistered --'
    # A "fix" that labelled everything UNREGISTERED would pass every assertion above.
    foreach ($reg in @('100000001', '100000002', '100000003')) {
        $seg = ''
        foreach ($m in [regex]::Matches($html, '(?s)<div class="acct-head">.*?</div>')) {
            if ($m.Value -match $reg) { $seg = $m.Value; break }
        }
        Assert-True "registered account $reg is not labelled UNREGISTERED" `
            ($seg -ne '' -and $seg -notmatch 'UNREGISTERED')
        Assert-True "registered account $reg carries its LAB_MANAGED scope" ($seg -match 'LAB_MANAGED')
    }

    Write-Host '   -- D4: a registered account with no collected data is surfaced too --'
    # Rebuild with account 100000002 removed from live_deals: it must move from a data
    # section to the "registered, no data" row rather than vanishing from the page.
    Remove-Item (Join-Path $wDeals 'EA_LAB_deals_100000002_20260730.csv') -Force
    Remove-Item (Join-Path $wDeals 'EA_LAB_snapshot_100000002_20260730.csv') -Force
    $out2 = Join-Path $work 'DASH2.html'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dashScript -LiveDealsDir $wDeals -OutFile $out2 | Out-Null
    $html2 = Get-Content $out2 -Raw
    Assert-True 'an account with a row in ACCOUNTS.csv but no data is named on the page' `
        ($html2 -match 'REGISTERED \(LAB_MANAGED\) but NO collected data')
    Assert-True 'and it is that specific account' `
        ([regex]::Matches($html2, '(?s)<tr class="st-white"><td class="num-cell"><b>100000002</b>').Count -ge 1)
    Assert-True 'it is NOT reported as unregistered (it is registered - the data is what is missing)' `
        ($html2 -notmatch '(?s)<b>100000002</b></td><td class="label-cell">UNREGISTERED')
}
finally {
    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail) -ForegroundColor Red
    exit 1
}
Write-Host ("PASS  {0}/{0}" -f $script:pass) -ForegroundColor Green
exit 0
