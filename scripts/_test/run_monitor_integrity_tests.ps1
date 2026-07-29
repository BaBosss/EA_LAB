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
    [string]$CoverageLib = ''
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
$dashScript = Join-Path $RepoRoot 'scripts\live_dashboard.ps1'

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
function Cover([string]$name) { Get-MonitorCoverage -SnapshotPath (Join-Path $snapDir $name) }
# Convenience: the two things daily_monitor.ps1 actually consumes.
function IsRed($r) { return ([int]$r.Failures.Count -gt 0) }
function LogText($r) { return (($r.Log) -join "`n") }

Write-Host '   -- GREEN: everything fresh (specificity: this must NOT be red) --'
$g = Cover 'green.json'
Assert-Equal 'green fixture produces no failure token' 0 $g.Failures.Count
Assert-True  'green fixture summary reports both sensors' `
    ($g.Summary -match 'deal-sensor fresh' -and $g.Summary -match 'float-sensor fresh')

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

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail) -ForegroundColor Red
    exit 1
}
Write-Host ("PASS  {0}/{0}" -f $script:pass) -ForegroundColor Green
exit 0
