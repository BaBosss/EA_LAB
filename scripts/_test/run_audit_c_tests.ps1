<#
run_audit_c_tests.ps1 - AUDIT C repair (2026-08-20, lane M0-L1): focused fixtures for the three
gates that run_snapshot_s4_tests.ps1 and run_monitor_integrity_tests.ps1 exercise only indirectly
(through the full snapshot-build pipeline) or not at all:

  C-A7   Get-MonitorCoverage -SnapshotBuildFailed: a failed build step must yield NOT MEASURED,
         never the previous snapshot's derived counts under today's date.
  C-A3   Get-RuntimeIdentityExpectedScope / Get-RuntimeIdentityCoverage: the expected identity
         universe comes from the canonical deployment scope, not from the map file itself, so a
         deployment absent from RUNTIME_IDENTITY_MAP.csv is UNMAPPED (a visible gap), not invisible.
  C-A10  Get-MonitorChainHealth: OK / ALERT / OVERDUE / UNKNOWN, and the precedence between them
         (a standing alert outranks a fresh-enough timestamp; a missing bar is UNKNOWN, never OK).
  C-A8   ResolveForwardTradeBound / CountBoundedTrades (scripts\control_room_snapshot.ps1): a
         forward trade count may be trusted as bounded/current evidence ONLY when a valid
         deterministic lower-time bound exists. Codex M0 review (2026-08-20) found this fail-open:
         with no valid bound, Counted silently became the raw unbounded count, and the emitted
         judge_readiness row never carried the bound source/value/state at all (0 of 59 real rows
         did). Extracted by AST from control_room_snapshot.ps1, not dot-sourced -- it is a runner,
         not a lib, and dot-sourcing it would execute the whole snapshot build.

Every assertion here is checked in BOTH directions per the VERDICT GATE guard rule: a case where
the gate SHOULD fire and a case where it should NOT, so a guard that never fires is caught as
UNTESTED rather than reported as passing.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_audit_c_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }

$script:pass = 0
$script:fail = 0
function Assert-True([string]$name, $cond) {
    if ($cond) { $script:pass++; Write-Host "   [PASS] $name" }
    else { $script:fail++; Write-Host "   [FAIL] $name" }
}
function Assert-Equal([string]$name, $expected, $actual) {
    if ("$expected" -eq "$actual") { $script:pass++; Write-Host "   [PASS] $name" }
    else {
        $script:fail++
        Write-Host "   [FAIL] $name"
        Write-Host "          expected: $expected"
        Write-Host "          actual  : $actual"
    }
}

. (Join-Path $RepoRoot 'scripts\lib\monitor_coverage.ps1')
. (Join-Path $RepoRoot 'scripts\lib\runtime_identity.ps1')
. (Join-Path $RepoRoot 'scripts\lib\deployment_status.ps1')

$fired = @{}

Write-Host '=== C-A7: a failed snapshot BUILD must yield NOT MEASURED, never stale-as-new ==='
# Positive: the caller states the build failed. The snapshot PATH given here does not even need
# to exist -- that is the point: this must short-circuit before any read is attempted, because a
# failed build can leave a perfectly valid PREVIOUS document on disk (control_room_snapshot.ps1's
# own throw text says so), and reading it would republish old derived counts under today's date.
$covFailed = Get-MonitorCoverage -SnapshotPath (Join-Path $RepoRoot 'portfolio\control_room_snapshot.json') -SnapshotBuildFailed $true
Assert-True 'C-A7 a failed build produces the snapshot-build-failed token' ($covFailed.Failures -contains 'snapshot-build-failed')
Assert-True 'C-A7 the summary says NOT MEASURED, not a coverage count' ($covFailed.Summary -match 'NOT MEASURED')
Assert-True 'C-A7 the log names the reason (previous build, not this run)' (($covFailed.Log -join ' ') -match 'PREVIOUS build')
if ($covFailed.Failures -contains 'snapshot-build-failed') { $fired['snapshot-build-failed'] = 1 }

# Negative / BASE CONTROL: the same call, $SnapshotBuildFailed=$false, against a snapshot path
# that does not exist either -- so the only variable that changed is the flag itself, and the
# gate must NOT fire on account of it (the failure this run sees instead is the ordinary
# missing-snapshot path, which is a DIFFERENT and pre-existing token).
$covNotFailed = Get-MonitorCoverage -SnapshotPath (Join-Path $RepoRoot 'portfolio\__no_such_snapshot__.json') -SnapshotBuildFailed $false
Assert-True 'C-A7 BASE CONTROL: SnapshotBuildFailed=$false never emits the token' (-not ($covNotFailed.Failures -contains 'snapshot-build-failed'))
Assert-True 'C-A7 BASE CONTROL: the summary does not claim NOT MEASURED for this reason' ($covNotFailed.Summary -notmatch 'NOT MEASURED \[snapshot-build-failed\]')

Write-Host ''
Write-Host '=== C-A3: the expected identity universe comes from deployment scope, not the map ==='
$depRows = @(
    [pscustomobject]@{ account='100000001'; magic='900001'; operational_status='ATTACHED'; forward_observed=$true },
    [pscustomobject]@{ account='100000002'; magic='900002'; operational_status='ATTACHED'; forward_observed=$true },
    [pscustomobject]@{ account='100000003'; magic='900003'; operational_status='PENDING_ATTACH'; forward_observed=$false },
    [pscustomobject]@{ account='100000004'; magic='900004'; operational_status='REMOVED'; forward_observed=$true },
    [pscustomobject]@{ account=''; magic='900005'; operational_status='ATTACHED'; forward_observed=$true }
)
$scope = @(Get-RuntimeIdentityExpectedScope -DeploymentRows $depRows)
Assert-Equal 'C-A3 scope keeps only forward-observed, non-REMOVED, well-formed rows' 2 $scope.Count
Assert-True 'C-A3 scope includes the first forward-observed ACTIVE row' ($scope -contains '100000001|900001')
Assert-True 'C-A3 scope includes the second forward-observed ACTIVE row' ($scope -contains '100000002|900002')
Assert-True 'C-A3 scope excludes the non-forward-observed row' (-not ($scope -contains '100000003|900003'))
Assert-True 'C-A3 scope excludes the REMOVED row even though forward_observed=true' (-not ($scope -contains '100000004|900004'))
Assert-True 'C-A3 scope excludes the malformed-account row rather than crashing' (-not ($scope -contains '|900005'))

# MEASURED-ON-649207d6 shape, reproduced at small scale: the map covers ONE of the two expected
# keys. Before C-A3 the expected universe was drawn FROM the map, so the second key could never
# be reported missing -- it simply did not exist as an expectation. Here it must.
$expectations = [ordered]@{ '100000001|900001' = [ordered]@{ account='100000001'; magic='900001' } }
$records = @(
    [pscustomobject]@{ account_login='100000001'; magic='900001'; validation_state='PASS' }
)
$cov = Get-RuntimeIdentityCoverage -ExpectedScope $scope -Expectations $expectations -Records $records
Assert-Equal 'C-A3 coverage state is GAP (one of two expected keys unmapped)' 'GAP' $cov.State
Assert-True 'C-A3 the unmapped key is NAMED, not silently absent' (@($cov.Unmapped) -contains '100000002|900002')
Assert-Equal 'C-A3 fully-bound count is exactly the one mapped+validated key' 1 $cov.FullyBoundCount
if ($cov.State -eq 'GAP' -and (@($cov.Unmapped) -contains '100000002|900002')) { $fired['identity-unmapped'] = 1 }

# BASE CONTROL: both expected keys mapped and validated PASS -> PASS, zero unmapped. Proves the
# GAP above fired because of the missing mapping, not because the function always says GAP.
$expectationsFull = [ordered]@{
    '100000001|900001' = [ordered]@{ account='100000001'; magic='900001' }
    '100000002|900002' = [ordered]@{ account='100000002'; magic='900002' }
}
$recordsFull = @(
    [pscustomobject]@{ account_login='100000001'; magic='900001'; validation_state='PASS' },
    [pscustomobject]@{ account_login='100000002'; magic='900002'; validation_state='PASS' }
)
$covFull = Get-RuntimeIdentityCoverage -ExpectedScope $scope -Expectations $expectationsFull -Records $recordsFull
Assert-Equal 'C-A3 BASE CONTROL: fully mapped+validated universe is PASS' 'PASS' $covFull.State
Assert-Equal 'C-A3 BASE CONTROL: zero unmapped' 0 (@($covFull.Unmapped).Count)

# Specificity: an empty deployment scope must not read as PASS (nothing owed = fine); it must
# read as UNKNOWN (the universe itself could not be established), so it is never mistaken for a
# clean bill of health by a reader that only checks "not GAP".
$covEmpty = Get-RuntimeIdentityCoverage -ExpectedScope @() -Expectations $expectations -Records $records
Assert-Equal 'C-A3 an empty expected scope is UNKNOWN, never PASS' 'UNKNOWN' $covEmpty.State

Write-Host ''
Write-Host '=== C-A10: monitoring-chain health (OK / ALERT / OVERDUE / UNKNOWN) ==='
$chainRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("chainhealth_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $chainRoot 'portfolio') -Force | Out-Null
$markerPath = Join-Path $chainRoot 'portfolio\daily_monitor_last_success.txt'
$alertPath  = Join-Path $chainRoot 'portfolio\MONITOR_ALERT.txt'

# Case 1 (RED): a standing alert file. MUST win over a recent-looking timestamp -- precedence is
# deliberate (see the function's own docstring): the alert IS the chain's own statement that its
# last attempt did not succeed.
Set-Content -LiteralPath $markerPath -Value ((Get-Date).ToString('s')) -Encoding ASCII
Set-Content -LiteralPath $alertPath -Value 'monitoring chain UNHEALTHY: snapshot' -Encoding ASCII
$hAlert = Get-MonitorChainHealth -RepoRoot $chainRoot -BarHours 30
Assert-Equal 'C-A10 a standing alert file forces State=ALERT' 'ALERT' $hAlert.State
Assert-True 'C-A10 ALERT outranks a fresh-looking last-success timestamp' ($hAlert.AlertText -match 'UNHEALTHY')
if ($hAlert.State -eq 'ALERT') { $fired['chain-alert'] = 1 }
Remove-Item -LiteralPath $alertPath -Force

# Case 2 (RED): no alert, but last success is older than the bar -> OVERDUE.
(Get-Item $markerPath).LastWriteTime | Out-Null
Set-Content -LiteralPath $markerPath -Value ((Get-Date).AddHours(-100).ToString('s')) -Encoding ASCII
$hOverdue = Get-MonitorChainHealth -RepoRoot $chainRoot -BarHours 30
Assert-Equal 'C-A10 a last-success older than the bar is OVERDUE' 'OVERDUE' $hOverdue.State
Assert-True 'C-A10 OVERDUE reports an age past the bar' ($hOverdue.AgeHours -gt 30)
if ($hOverdue.State -eq 'OVERDUE') { $fired['chain-overdue'] = 1 }

# Case 3 (GREEN / BASE CONTROL): no alert, last success within the bar -> OK. Proves OVERDUE above
# fired because of the age, not because this function always reports red.
Set-Content -LiteralPath $markerPath -Value ((Get-Date).AddHours(-1).ToString('s')) -Encoding ASCII
$hOk = Get-MonitorChainHealth -RepoRoot $chainRoot -BarHours 30
Assert-Equal 'C-A10 BASE CONTROL: a recent last-success with no alert is OK' 'OK' $hOk.State

# Case 4 (specificity): a readable, old marker but NO bar supplied (BarHours=0, meaning the caller
# could not establish one) must be UNKNOWN, never a guessed OVERDUE or a silent OK.
$hNoBar = Get-MonitorChainHealth -RepoRoot $chainRoot -BarHours 0
Assert-Equal 'C-A10 no overdue bar available is UNKNOWN, not a guessed verdict' 'UNKNOWN' $hNoBar.State
if ($hNoBar.State -eq 'UNKNOWN') { $fired['chain-unknown-nobar'] = 1 }

# Case 5 (specificity): no marker file at all (chain has never recorded a success) -> UNKNOWN.
Remove-Item -LiteralPath $markerPath -Force
$hNoMarker = Get-MonitorChainHealth -RepoRoot $chainRoot -BarHours 30
Assert-Equal 'C-A10 no marker file at all is UNKNOWN (never recorded), not OVERDUE' 'UNKNOWN' $hNoMarker.State
Assert-Equal 'C-A10 LastSuccess is empty when never recorded' '' $hNoMarker.LastSuccess

Write-Host ''
Write-Host '=== C-A8: a forward trade count may be BOUNDED evidence only when a real time bound exists ==='
# Extract the real functions by AST, from the real file, by name -- a rename must break this
# cage, not silently leave it testing a stale private copy. control_room_snapshot.ps1 is a
# runner (builds a whole snapshot on load), so it cannot be dot-sourced directly.
$snapPath = Join-Path $RepoRoot 'scripts\control_room_snapshot.ps1'
Assert-True 'control_room_snapshot.ps1 exists' (Test-Path -LiteralPath $snapPath) $snapPath
$snapParseErrors = $null
$snapAst = [System.Management.Automation.Language.Parser]::ParseFile($snapPath, [ref]$null, [ref]$snapParseErrors)
if ($snapParseErrors -and $snapParseErrors.Count -gt 0) { throw "control_room_snapshot.ps1 does not parse: $($snapParseErrors[0].Message)" }
$wantedBoundFns = @('TryParseUnixSeconds', 'TryParseTradeTime', 'ResolveForwardTradeBound', 'CountBoundedTrades')
$boundDefs = @{}
foreach ($fn in $snapAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    if ($wantedBoundFns -contains $fn.Name) { $boundDefs[$fn.Name] = $fn.Extent.Text }
}
foreach ($w in $wantedBoundFns) {
    Assert-True ("control_room_snapshot.ps1 still defines {0}" -f $w) ($boundDefs.ContainsKey($w)) `
        'the cage extracts this function by name; a rename must break the cage, not silently skip it'
}
# TryParseUnixSeconds reads the script-scoped $EPOCH_UTC constant defined next to it in the real
# file (not itself a function, so AST-by-name above does not capture it) -- mirrored here with the
# exact same value/kind so the extracted function behaves identically to the shipped one.
$EPOCH_UTC = [datetime]::SpecifyKind((New-Object datetime(1970,1,1)), [System.DateTimeKind]::Utc)
foreach ($w in $wantedBoundFns) { if ($boundDefs.ContainsKey($w)) { . ([scriptblock]::Create($boundDefs[$w])) } }

# Fixture deals: two MT5 closed trades (entry='1') on magic 555, one before and one after an
# epoch bound of 2026-08-01T00:00:00Z (Unix 1785542400).
$epochBoundUnix = 1785542400  # 2026-08-01T00:00:00Z
$dealsMT5 = @(
    [pscustomobject]@{ magic = '555'; entry = '1'; time_unix = ($epochBoundUnix - 3600); time = '2026.07.31 23:00:00' }   # before
    [pscustomobject]@{ magic = '555'; entry = '1'; time_unix = ($epochBoundUnix + 3600); time = '2026.08.01 01:00:00' }   # after
)

# --- A: valid runtime-attach epoch -> bound carried, count attributed to it ---
$identityWithEpoch = [pscustomobject]@{ attach_time_unix = "$epochBoundUnix" }
$boundA = ResolveForwardTradeBound ([pscustomobject]@{ start_date = '2020-01-01' }) $identityWithEpoch $null
Assert-Equal 'C-A8/A bound source is RUNTIME_ATTACH_EPOCH when a real attach epoch exists' 'RUNTIME_ATTACH_EPOCH' $boundA.Source
$countedA = CountBoundedTrades $dealsMT5 '555' 'MT5' $boundA
Assert-Equal 'C-A8/A only the post-epoch deal is Counted' 1 $countedA.Counted
Assert-Equal 'C-A8/A state is BOUNDED, not UNBOUNDED, when a real epoch bound applied' 'BOUNDED' $countedA.State
if ($countedA.State -eq 'BOUNDED' -and $countedA.Counted -eq 1) { $fired['bound-epoch-attributed'] = 1 }

# --- B: valid observation-start-date bound (no identity epoch available) -> source/value carried ---
$boundB = ResolveForwardTradeBound ([pscustomobject]@{ start_date = '2026-08-01' }) $null $null
Assert-Equal 'C-A8/B bound source is OBSERVATION_START_DATE with no identity epoch' 'OBSERVATION_START_DATE' $boundB.Source
Assert-True 'C-A8/B bound value is the real start_date, not invented' ($boundB.Bound -eq [datetime]'2026-08-01')
if ($boundB.Source -eq 'OBSERVATION_START_DATE') { $fired['bound-observation-start'] = 1 }

# --- C: no valid bound (no epoch, no parseable start_date) -> MUST NOT trust the raw count ---
$boundNone = ResolveForwardTradeBound ([pscustomobject]@{ start_date = '' }) $null $null
Assert-Equal 'C-A8/C bound source is NONE when neither rung resolves' 'NONE' $boundNone.Source
$countedNone = CountBoundedTrades $dealsMT5 '555' 'MT5' $boundNone
Assert-Equal 'C-A8/C ATTACK: Counted must be NULL, not the raw unbounded count, when unbounded' '' "$($countedNone.Counted)"
Assert-Equal 'C-A8/C state is explicitly UNBOUNDED, not silently BOUNDED' 'UNBOUNDED' $countedNone.State
if ($null -eq $countedNone.Counted -and $countedNone.State -eq 'UNBOUNDED') { $fired['unbounded-refuses-counted'] = 1 }

# --- D: the raw/unbounded diagnostic count survives, but visibly separate from Counted ---
Assert-Equal 'C-A8/D the raw diagnostic count is still preserved (both real deals) as Unbounded' 2 $countedNone.Unbounded
Assert-True 'C-A8/D Unbounded is a DIFFERENT field from Counted, never read back into it' ($null -eq $countedNone.Counted -and $countedNone.Unbounded -eq 2)
if ($countedNone.Unbounded -eq 2 -and $null -eq $countedNone.Counted) { $fired['unbounded-diagnostic-separate'] = 1 }

# --- BASE CONTROL: a bounded run with a real epoch is not itself broken by the fail-closed fix ---
Assert-Equal 'C-A8 BASE CONTROL: a genuinely bounded, resolvable count still reports the real number' 1 $countedA.Counted

Write-Host ''
Write-Host ("GUARD FIRE COUNT: {0}/9 codes observed firing -> {1}" -f $fired.Count, (($fired.Keys | Sort-Object) -join ', '))
Assert-Equal 'all 9 AUDIT C guard codes were OBSERVED FIRING (0 would mean UNTESTED, not safe)' 9 $fired.Count

Write-Host ''
if ($script:fail -eq 0) {
    Write-Host ("PASS  {0}/{1}" -f $script:pass, ($script:pass + $script:fail))
    exit 0
} else {
    Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail)
    exit 1
}
