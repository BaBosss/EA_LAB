<#
run_optimize_guard_tests.ps1 - regression cage for scripts/optimize_guard.ps1

WHY THIS EXISTS
  The guard's job is to refuse an optimizer sweep that is provably wasted or
  provably touches the safety cage. A guard that refuses VALID sweeps is not
  "extra safe" - it is the failure that trains operators to pass
  -SkipOptimizeGuard on every run, which silences the checks that DO have
  evidence behind them. That happened: classification=OVERRIDE was being read
  as "this parameter is dead" when it actually means "this parameter is a
  member of a precedence chain", so _2_BasketTP_ATRmult (Boss 14) and
  _17_UseStructLevels (Boss 17) - both real, working dials - were REFUSED.

  Precedence is NOT decided by the classification column. It is decided by the
  override-pair table in docs/PARAM_LINKAGE.md TOGETHER WITH the sibling values
  present in the same run: a loser is only dead when its winner is actually
  switched on. So this cage asserts both directions of every pair it covers -
  a test set that only asserted REFUSE could be passed by a guard that refuses
  everything, which is exactly the bug being fixed.

WHAT IS COVERED (each case names the check it discriminates)
  classification : OVERRIDE winner allowed · INACTIVE refused · unknown refused
  precedence     : loser refused while winner ON · same loser allowed while winner OFF
  build inertness: TrendFilter refused on 14, allowed on 11 (same name, same run)
  safety         : by name (RC_*, ProtectLevel) and by registry context, and the
                   OVERRIDE+safety row that must stay refused after the loosening

USAGE
  powershell -NoProfile -File scripts\_test\run_optimize_guard_tests.ps1
EXIT CODE
  0 = every case matched its expected verdict · 1 = at least one mismatch
#>
[CmdletBinding()]
param([switch]$Verbose_)

$ErrorActionPreference = 'Stop'
$root  = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$guard = Join-Path $root 'scripts\optimize_guard.ps1'
if (-not (Test-Path $guard)) { Write-Host "[FAIL] guard not found: $guard" -ForegroundColor Red; exit 1 }

# Each case: the parameter whose verdict is asserted, the build, any sibling
# values that must be present for the precedence check to have something to
# read, and the expected verdict for THAT parameter.
$cases = @(
  # --- classification: an OVERRIDE winner is a live dial, not a dead one -----
  @{ id='ovr-winner-basketATR-allowed';  param='_2_BasketTP_ATRmult'; build=14
     args=@('_2_BasketTP_ATRmult','_2_BasketTP_BalPct=0')
     expect='ALLOW'; why='OVERRIDE winner with no higher-precedence value active' }
  @{ id='ovr-winner-structlevels-allowed'; param='_17_UseStructLevels'; build=17
     args=@('_17_UseStructLevels')
     expect='ALLOW'; why='OVERRIDE winner on its own build (Codex P0 repro #2)' }
  @{ id='ovr-winner-slmaxatr-allowed';   param='_33_SL_MaxATRmult'; build=14
     args=@('_33_SL_MaxATRmult')
     expect='ALLOW'; why='third OVERRIDE row - proves the fix is not special-cased to two names' }

  # --- precedence: BOTH directions of the same pair -------------------------
  @{ id='loser-refused-when-winner-on';  param='_2_BasketTP_ATRmult'; build=14
     args=@('_2_BasketTP_ATRmult','_2_BasketTP_BalPct=1.5')
     expect='REFUSE'; why='BalPct>0 supersedes ATRmult in the same run' }
  @{ id='money-refused-when-atr-on';     param='_2_BasketTP_Money'; build=14
     args=@('_2_BasketTP_Money','_2_BasketTP_ATRmult=2.0','_2_BasketTP_BalPct=0')
     expect='REFUSE'; why='ATRmult>0 supersedes the fixed-money target' }
  @{ id='money-allowed-when-both-off';   param='_2_BasketTP_Money'; build=14
     args=@('_2_BasketTP_Money','_2_BasketTP_ATRmult=0','_2_BasketTP_BalPct=0')
     expect='ALLOW'; why='same loser, both winners off - refusing here would be the mirror bug' }

  # --- build inertness: same parameter, opposite verdicts on two builds -----
  @{ id='inert-trendfilter-refused-b14'; param='TrendFilter'; build=14
     args=@('TrendFilter')
     expect='REFUSE'; why='PARAM_INACTIVE_AUDIT: TrendFilter is not wired into build 14' }
  @{ id='inert-trendfilter-allowed-b11'; param='TrendFilter'; build=11
     args=@('TrendFilter')
     expect='ALLOW'; why='same dial IS wired on build 11 - proves the check discriminates' }

  # --- classification: INACTIVE stays refused -------------------------------
  @{ id='inactive-stackmode-b16-refused'; param='StackMode'; build=16
     args=@('StackMode')
     expect='REFUSE'; why='classification=INACTIVE on build 16 (permanently dead)' }

  # --- safety: three independent routes, none may leak through the fix ------
  @{ id='safety-name-rcmaxlot-refused';  param='RC_MaxLot'; build=14
     args=@('RC_MaxLot')
     expect='REFUSE'; why='safety by ^RC_ name rule' }
  @{ id='safety-name-protectlevel-refused'; param='ProtectLevel'; build=14
     args=@('ProtectLevel')
     expect='REFUSE'; why='safety by explicit name rule' }
  @{ id='safety-ctx-emergencydd-refused'; param='_16_EmergencyDDPct'; build=16
     args=@('_16_EmergencyDDPct')
     expect='REFUSE'; why='safety by registry context column, not by name' }
  @{ id='safety-override-rcmaxlevels-refused'; param='RC_MaxLevelsOverride'; build=14
     args=@('RC_MaxLevelsOverride')
     expect='REFUSE'; why='OVERRIDE *and* safety - the loosening must not reach this row' }

  # --- unknown identifier stays fail-closed ---------------------------------
  @{ id='unknown-name-refused';          param='_99_NotARealInput'; build=14
     args=@('_99_NotARealInput')
     expect='REFUSE'; why='not in PARAM_REGISTRY.csv - fail closed' }
)

function Get-VerdictFor {
    param([string[]]$ParamArgs, [int]$Build, [string]$Param)
    # -WarnOnly so the process exit code never masks a per-parameter verdict:
    # this cage asserts the VERDICT LINE, and several cases deliberately expect
    # a REFUSE that would otherwise make the runner exit 1 and abort the loop.
    # NOTE: invoked via -Command, not -File. Under `powershell -File`, a
    # comma-joined value for a [string[]] parameter arrives as ONE string
    # element ("a,b"), which the guard then reports as an unknown identifier -
    # the cage's first run failed 4 cases that way before the guard was even
    # touched. -Command parses the argument list with real PowerShell syntax.
    $joined = ($ParamArgs | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ','
    $cmd = "& '$guard' -ParamNames $joined -Build $Build -WarnOnly"
    $out = & powershell -NoProfile -Command $cmd 2>&1
    $text = ($out | Out-String)
    # the verdict line looks like: [ALLOW] _2_BasketTP_ATRmult  (from: -ParamNames)
    $line = @($text -split "`r?`n" | Where-Object { $_ -match ("^\[(ALLOW|REFUSE)\]\s+" + [regex]::Escape($Param) + "(\s|\[|$)") }) | Select-Object -First 1
    if (-not $line) { return [pscustomobject]@{ Verdict='(no verdict line)'; Text=$text } }
    $v = if ($line -match '^\[(ALLOW|REFUSE)\]') { $Matches[1] } else { '(unparsed)' }
    return [pscustomobject]@{ Verdict=$v; Text=$text }
}

Write-Host "=== optimize_guard regression cage ===" -ForegroundColor Cyan
Write-Host "guard: $guard"
Write-Host ""

$pass = 0; $fail = 0
foreach ($c in $cases) {
    $r = Get-VerdictFor -ParamArgs $c.args -Build $c.build -Param $c.param
    if ($r.Verdict -eq $c.expect) {
        Write-Host ("[PASS] {0,-36} {1} {2} (build {3})" -f $c.id, $c.expect, $c.param, $c.build) -ForegroundColor Green
        $pass++
    } else {
        Write-Host ("[FAIL] {0,-36} expected {1}, got {2}  -  {3}" -f $c.id, $c.expect, $r.Verdict, $c.why) -ForegroundColor Red
        Write-Host ("       param={0} build={1} args={2}" -f $c.param, $c.build, ($c.args -join ','))
        foreach ($l in ($r.Text -split "`r?`n" | Where-Object { $_ -match '^\s*-\s' })) { Write-Host "       $l" }
        $fail++
    }
}

Write-Host ""
Write-Host ("--- {0} passed / {1} failed / {2} total ---" -f $pass, $fail, $cases.Count)
if ($fail -gt 0) { Write-Host "=== OPTIMIZE-GUARD CAGE RED ===" -ForegroundColor Red; exit 1 }
Write-Host "=== OPTIMIZE-GUARD CAGE GREEN ===" -ForegroundColor Green
exit 0
