<#
run_certification_scope_tests.ps1 - RUNTIME_IDENTITY_COVERAGE_CONTRACT_20260905 acceptance suite.

Three layers, cheapest-first, mirroring the existing runtime-identity test family:
  PART 1  pure Python unit tests for _triage/factory_os/certification_scope.py (parse/classify).
  PART 2  the PowerShell bridge (scripts/lib/certification_scope.ps1) against temp CSV fixtures --
          this is where the required negative tests live (MT4 visible, user-owned visible, UNKNOWN
          fail-closed, same-account-different-magic no shortcut, reconciliation/no vanishing rows).
  PART 3  Get-MonitorCoverage end-to-end against a REAL, verifiable V5 snapshot (built the same way
          run_monitor_integrity_tests.ps1 does, through snapshot_build.py, never hand-typed) proving
          the new certification-scope block is informational-only: it never adds a failure token,
          never changes the pre-existing ORDER-353/deployment-unverified tokens, and is silently
          absent-tolerant for an older writer that has not published it yet.

Offline, deterministic, no MT5, no network. ASCII-only (PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}
$py = Join-Path $RepoRoot 'tools\python312\python.exe'

$script:pass = 0
$script:fail = 0
function Check([string]$Name, [bool]$Condition, [string]$Detail = '') {
    if ($Condition) { $script:pass++; Write-Host "[PASS] $Name" }
    else { $script:fail++; Write-Host "[FAIL] $Name :: $Detail" -ForegroundColor Red }
}

# =====================================================================================
# PART 1 -- pure Python unit tests (certification_scope.py)
# =====================================================================================
Write-Host '=== PART 1: certification_scope.py unit tests ==='
$pyTest = Join-Path $RepoRoot '_triage\factory_os\run_certification_scope_tests.py'
& $py $pyTest
if ($LASTEXITCODE -ne 0) { Write-Host 'PART 1 FAILED' -ForegroundColor Red; exit 1 }

# =====================================================================================
# PART 2 -- PowerShell bridge negative tests
# =====================================================================================
Write-Host ''
Write-Host '=== PART 2: certification_scope.ps1 bridge + negative fixtures ==='
. (Join-Path $RepoRoot 'scripts\lib\certification_scope.ps1')

$work = Join-Path ([IO.Path]::GetTempPath()) ('cert_scope_ps_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    function Write-Csv([string]$Path, [string[]]$Lines) {
        $header = 'account,magic,identity_mechanism_capability,identity_certification_scope,evidence_ref,status'
        [IO.File]::WriteAllText($Path, (@($header) + $Lines -join "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
    }

    # ---- MT4 ACTIVE row is classified mechanism-unavailable, remains visible ----
    $csv1 = Join-Path $work 'mt4.csv'
    Write-Csv $csv1 @(
        '141049900,7777,NO_NATIVE_RUNTIME_IDENTITY_MT4,UNKNOWN,DEPLOYMENTS.csv platform=MT4,TRANSCRIBED'
    )
    $r1 = Get-CertificationScopeCoverage -RepoRoot $RepoRoot -ExpectedScope @('141049900|7777') -CsvPath $csv1 -PythonPath $py
    Check 'MT4 ACTIVE row -> scope_mechanism_unavailable=1, still in scope_total_forward_observed' `
        ($r1.scope_mechanism_unavailable -eq 1 -and $r1.scope_total_forward_observed -eq 1) ($r1 | ConvertTo-Json -Compress)
    Check 'MT4 row is NOT reported missing (it has a scope row, just an unavailable mechanism)' `
        (@($r1.missing_scope_fact).Count -eq 0) ($r1 | ConvertTo-Json -Compress)

    # ---- explicit user-owned/uncertified row remains visible, never becomes lab-certified ----
    $csv2 = Join-Path $work 'usermix.csv'
    Write-Csv $csv2 @(
        '159475669,8001,UNKNOWN,USER_OWNED_UNCERTIFIED,"DEPLOYMENTS.csv notes: literal ""lab does not certify""",TRANSCRIBED'
    )
    $r2 = Get-CertificationScopeCoverage -RepoRoot $RepoRoot -ExpectedScope @('159475669|8001') -CsvPath $csv2 -PythonPath $py
    Check 'user-owned/uncertified row -> scope_user_owned_uncertified=1, scope_lab_certified=0' `
        ($r2.scope_user_owned_uncertified -eq 1 -and $r2.scope_lab_certified -eq 0) ($r2 | ConvertTo-Json -Compress)
    Check 'user-owned/uncertified row still counted in scope_total_forward_observed (visible, not dropped)' `
        ($r2.scope_total_forward_observed -eq 1) ($r2 | ConvertTo-Json -Compress)

    # ---- no explicit scope fact -> UNKNOWN, never silently excluded ----
    $csv3 = Join-Path $work 'empty.csv'
    Write-Csv $csv3 @()
    $r3 = Get-CertificationScopeCoverage -RepoRoot $RepoRoot -ExpectedScope @('999999999|1') -CsvPath $csv3 -PythonPath $py
    Check 'expected key with no CERTIFICATION_SCOPE.csv row -> scope_unknown=1, missing_scope_fact contains it' `
        ($r3.scope_unknown -eq 1 -and (@($r3.missing_scope_fact) -contains '999999999|1')) ($r3 | ConvertTo-Json -Compress)
    Check 'row is still counted in scope_total_forward_observed (UNKNOWN != excluded)' `
        ($r3.scope_total_forward_observed -eq 1) ($r3 | ConvertTo-Json -Compress)

    # ---- same account, different magic: no account-level shortcut ----
    $csv4 = Join-Path $work 'sameacct.csv'
    Write-Csv $csv4 @(
        '159475669,8001,UNKNOWN,USER_OWNED_UNCERTIFIED,"lab does not certify",TRANSCRIBED'
        '159475669,990005,UNKNOWN,UNKNOWN,no explicit statement,TRANSCRIBED'
    )
    $r4 = Get-CertificationScopeCoverage -RepoRoot $RepoRoot -ExpectedScope @('159475669|8001','159475669|990005') -CsvPath $csv4 -PythonPath $py
    Check 'same account, different magic -> independently classified (1 uncertified, 2 unknown: mechanism UNKNOWN on both rows), no account-level default' `
        ($r4.scope_user_owned_uncertified -eq 1 -and $r4.scope_unknown -eq 2 -and $r4.scope_total_forward_observed -eq 2) ($r4 | ConvertTo-Json -Compress)

    # ---- arithmetic reconciliation: no disappearing rows, orphan detection ----
    $csv5 = Join-Path $work 'orphan.csv'
    Write-Csv $csv5 @(
        '111111111,1,UNKNOWN,UNKNOWN,no fact,TRANSCRIBED'
        '222222222,2,UNKNOWN,UNKNOWN,no fact,TRANSCRIBED'
    )
    $r5 = Get-CertificationScopeCoverage -RepoRoot $RepoRoot -ExpectedScope @('111111111|1') -CsvPath $csv5 -PythonPath $py
    Check 'row outside the current forward-observed scope is reported orphaned, not silently merged in' `
        ((@($r5.orphaned_scope_rows) -contains '222222222|2') -and $r5.scope_total_forward_observed -eq 1) ($r5 | ConvertTo-Json -Compress)
    Check 'orphan makes state GAP (a real discrepancy, not swallowed)' ($r5.state -eq 'GAP') ($r5 | ConvertTo-Json -Compress)

    # ---- CSV parse-error rows make counts untrustworthy (FAIL, not a silent partial pass) ----
    $csv6 = Join-Path $work 'bad_enum.csv'
    Write-Csv $csv6 @(
        '141049900,7777,NOT_A_REAL_VALUE,UNKNOWN,bad row,TRANSCRIBED'
    )
    $r6 = Get-CertificationScopeCoverage -RepoRoot $RepoRoot -ExpectedScope @('141049900|7777') -CsvPath $csv6 -PythonPath $py
    Check 'invalid enum value in CERTIFICATION_SCOPE.csv -> state FAIL with parse_errors, not a silent pass' `
        ($r6.state -eq 'FAIL' -and @($r6.parse_errors).Count -gt 0) ($r6 | ConvertTo-Json -Compress)

    # ---- trade-history / mapping evidence cannot influence this module at all ----
    # Get-CertificationScopeCoverage's parameter set has no deals/trade-history/runtime-identity
    # input by construction -- it can only read CERTIFICATION_SCOPE.csv and the expected key list.
    $bridgeSource = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\certification_scope.ps1') -Raw
    $paramBlock = ($bridgeSource -split 'function Get-CertificationScopeCoverage')[1]
    $paramBlock = $paramBlock.Substring(0, $paramBlock.IndexOf('#>') )
    Check 'Get-CertificationScopeCoverage has no trade-history/deal/mapping parameter (structurally cannot infer from it)' `
        ($paramBlock -notmatch 'Deal' -and $paramBlock -notmatch 'Trade' -and $paramBlock -notmatch 'RuntimeIdentityMap') $paramBlock

    # ---- the real committed CERTIFICATION_SCOPE.csv reconciles exactly against DEPLOYMENTS.csv ----
    . (Join-Path $RepoRoot 'scripts\lib\deployment_status.ps1')
    . (Join-Path $RepoRoot 'scripts\lib\runtime_identity.ps1')
    $deployRows = Import-Csv -LiteralPath (Join-Path $RepoRoot 'portfolio\DEPLOYMENTS.csv')
    $normalized = Get-DeploymentMonitoringRows -Rows @($deployRows)
    $expectedRealScope = @(Get-RuntimeIdentityExpectedScope -DeploymentRows $normalized)
    $realCsv = Join-Path $RepoRoot 'portfolio\CERTIFICATION_SCOPE.csv'
    $rReal = Get-CertificationScopeCoverage -RepoRoot $RepoRoot -ExpectedScope $expectedRealScope -CsvPath $realCsv -PythonPath $py
    Check 'real portfolio\CERTIFICATION_SCOPE.csv is structurally reconciled (no missing, no orphan)' `
        (@($rReal.missing_scope_fact).Count -eq 0 -and @($rReal.orphaned_scope_rows).Count -eq 0) ($rReal | ConvertTo-Json -Compress)
    Check 'real CERTIFICATION_SCOPE.csv scope_total_forward_observed matches the real x58 expected scope' `
        ($rReal.scope_total_forward_observed -eq $expectedRealScope.Count) ($rReal | ConvertTo-Json -Compress)
    Check 'real CERTIFICATION_SCOPE.csv has exactly 9 MT4 mechanism-unavailable rows' `
        ($rReal.scope_mechanism_unavailable -eq 9) ($rReal | ConvertTo-Json -Compress)
    Check 'real CERTIFICATION_SCOPE.csv has exactly 12 explicit user-owned/uncertified rows' `
        ($rReal.scope_user_owned_uncertified -eq 12) ($rReal | ConvertTo-Json -Compress)
    Check 'real CERTIFICATION_SCOPE.csv reports 0 lab-certified and 0 native-capable rows (no fact invented)' `
        ($rReal.scope_lab_certified -eq 0 -and $rReal.scope_native_identity_capable -eq 0) ($rReal | ConvertTo-Json -Compress)
    # UNKNOWN is fail-closed (RUNTIME_IDENTITY_COVERAGE_CONTRACT_20260905): every one of the 58
    # rows still carries an unresolved dimension (MT4 rows have UNKNOWN certification, user-owned
    # rows have UNKNOWN mechanism, everything else is UNKNOWN on both) -- structural completeness
    # must not be laundered into PASS while that remains true.
    Check 'real CERTIFICATION_SCOPE.csv is fail-closed GAP: every row still carries an UNKNOWN scope fact' `
        ($rReal.state -eq 'GAP' -and $rReal.scope_unknown -eq $expectedRealScope.Count) ($rReal | ConvertTo-Json -Compress)
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

# =====================================================================================
# PART 3 -- Get-MonitorCoverage end-to-end: informational-only, ORDER-353/x58 unchanged
# =====================================================================================
Write-Host ''
Write-Host '=== PART 3: monitor_coverage.ps1 wiring is informational-only ==='
. (Join-Path $RepoRoot 'scripts\lib\monitor_coverage.ps1')

$fxRoot = Join-Path ([IO.Path]::GetTempPath()) ('cert_scope_snap_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fxRoot -Force | Out-Null
Set-Content -Path (Join-Path $fxRoot 'srcA.txt') -Value 'fixture source A' -Encoding ASCII
cmd /c mklink /J "$(Join-Path $fxRoot 'tools')" "$(Join-Path $RepoRoot 'tools')" | Out-Null
cmd /c mklink /J "$(Join-Path $fxRoot '_triage')" "$(Join-Path $RepoRoot '_triage')" | Out-Null
$builder = Join-Path $RepoRoot '_triage\factory_os\snapshot_build.py'

function Build-Fixture([hashtable]$Extra) {
    $inp = [ordered]@{
        entity = 'SnapshotBuilderInput'
        meta = [ordered]@{
            schema = 'ControlRoomSnapshot'
            version = 5
            generated_at = (Get-Date).ToString('s')
            stale_bar_hours = 30
            runtime_identity_required = $true
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
        system_health   = @([ordered]@{ account='100000001'; collector='MT5'; state='FRESH'; age_hours=0.1; governance_scope='LAB_MANAGED' })
        floating_risk   = @([ordered]@{ account='100000001'; state='FRESH'; age_hours=0.0; equity=10000.0; balance=10000.0; floating_pl=0.0; magics=@() })
        deployments     = [ordered]@{ rows = @([ordered]@{ account='69424711'; magic=''; status='UNVERIFIED' }) }
        unknown_magics  = @()
        attestation     = @()
        judge_readiness = @()
        judge_cohorts   = @()
        runtime_identity = @()
        runtime_identity_summary = [ordered]@{
            state = 'LEGACY_UNVERIFIED'; records = 0; identity_findings = @()
        }
        summary = [ordered]@{
            unknown_magics_unclassified = 0
            identity_coverage = [ordered]@{
                state = 'GAP'; expected = 1; expected_source = 'DEPLOYMENTS.csv forward-observed, non-REMOVED rows'
                mapped = 0; records = 0; validated_pass = 0; fully_bound = 0
                unmapped_count = 1; unobserved_count = 0; orphaned_count = 0
                unmapped = @('100000001|900001'); unobserved = @(); orphaned = @(); fully_bound_keys = @()
                reason = 'fixture GAP'
            }
        }
    }
    if ($Extra.ContainsKey('certification_scope_coverage')) {
        $inp.summary.certification_scope_coverage = $Extra['certification_scope_coverage']
    }
    $name = 'fixture_' + [guid]::NewGuid().ToString('N')
    $inPath = Join-Path $fxRoot ("in_" + $name + '.json')
    $outPath = Join-Path $fxRoot ("v5_" + $name + '.json')
    [IO.File]::WriteAllText($inPath, ($inp | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    $buildOut = & $py $builder build $inPath $outPath $fxRoot --no-reconcile 2>&1
    if ($LASTEXITCODE -ne 0) { throw "fixture did not build: $($buildOut -join ' ')" }
    return $outPath
}

try {
    $baselinePath = Build-Fixture @{}
    $baseline = Get-MonitorCoverage -SnapshotPath $baselinePath -RepoRoot $fxRoot

    Check 'baseline (no certification_scope_coverage) still reports the deployment-unverified token' `
        (@($baseline.Failures) -contains 'deployment-unverified-69424711|') ($baseline.Failures -join ',')
    Check 'baseline still reports the runtime-identity-coverage-gap token' `
        (@($baseline.Failures) -like 'runtime-identity-coverage-gap*').Count -gt 0 ($baseline.Failures -join ',')
    Check 'baseline logs an absent-block note, does not crash on a missing certification_scope_coverage' `
        (($baseline.Log -join "`n") -match 'no summary\.certification_scope_coverage block') ($baseline.Log -join '|')

    $withScopePath = Build-Fixture @{
        certification_scope_coverage = [ordered]@{
            state = 'GAP'; source = 'portfolio/CERTIFICATION_SCOPE.csv'
            expected_source = 'DEPLOYMENTS.csv forward-observed, non-REMOVED rows'
            scope_total_forward_observed = 1; scope_native_identity_capable = 0
            scope_mechanism_unavailable = 0; scope_lab_certified = 0
            scope_user_owned_uncertified = 0; scope_unknown = 1
            missing_scope_fact = @('100000001|900001'); orphaned_scope_rows = @(); parse_errors = @()
            reason = 'fixture missing row'
        }
    }
    $withScope = Get-MonitorCoverage -SnapshotPath $withScopePath -RepoRoot $fxRoot

    Check 'adding certification_scope_coverage does not change the Failures set at all (informational-only)' `
        (((@($withScope.Failures) | Sort-Object) -join ',') -eq ((@($baseline.Failures) | Sort-Object) -join ',')) `
        ("with=" + ($withScope.Failures -join ',') + " baseline=" + ($baseline.Failures -join ','))
    Check 'certification-scope informational log line is present with the right counts' `
        (($withScope.Log -join "`n") -match 'certification scope GAP.*total_forward_observed=1.*unknown=1') ($withScope.Log -join '|')
    Check 'certification-scope MISSING sub-line is present' `
        (($withScope.Log -join "`n") -match 'certification scope MISSING.*100000001\|900001') ($withScope.Log -join '|')
    Check 'global monitoring does not go green because of certification_scope_coverage (Failures still non-empty)' `
        (@($withScope.Failures).Count -gt 0) ($withScope.Failures -join ',')
} finally {
    Remove-Item -LiteralPath $fxRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($script:fail -gt 0) { Write-Host "FAIL $($script:fail)/$($script:pass + $script:fail)" -ForegroundColor Red; exit 1 }
Write-Host "PASS $($script:pass)/$($script:pass)" -ForegroundColor Green
exit 0
