<#
hedge_recovery_sweep.ps1 - ORDER-158 part (2): RecoveryMode x HedgeMode 8-cell batch
harness built ON TOP OF scripts\ab_mode_test.ps1 (does not reimplement its backtest-
running / report-parsing logic - every actual MT5 run in this script is a call to
ab_mode_test.ps1, which itself calls mt5_run.ps1 twice per cell: base + override).

Sweeps RecoveryMode {80,81,82,83} x HedgeMode {0,1} = 8 cells on ONE fixed
EA/symbol/window (defaults: Boss_14_GridLog, AUDNZD, H1, MAIN window
2023.01.01-2025.12.31 per CLAUDE.md VERDICT GATE window pin). The (80,0) cell IS
the BaseSet as-shipped, so only the other 7 cells need an ab_mode_test.ps1 call
(base gets re-run each time as part of ab_mode_test.ps1's own base+variant pair -
that repeat cost is accepted in exchange for zero duplicated run/parse logic).

FLAT-LOT PAIRING (required by ORDER-158, not optional): RecoveryMode=81 (LIGHT) is
the built-in flat-lot twin of 82 (ADAPTIVE) and 83 (AGGRESSIVE) in this codebase -
Recovery_AddLot's REC_LIGHT branch returns baseLot unchanged (no escalation) while
using the EXACT SAME trigger/step/anti-spam add mechanism as 82/83 (see
ea_template\core\Recovery.mqh). So holding HedgeMode fixed, 81 isolates "does the
escalation curve help" from "does the add-mechanism itself help" - the escalated
82/83 rows in the summary table always carry their same-HedgeMode 81 sibling's
PF/trades right next to them (flat_lot_twin_* columns), whether or not 82/83 beat
baseline, so a human reviewer never sees an escalated PF number without its flat-
lot twin in the same row.

BASELINE = RecoveryMode=80 at the SAME HedgeMode (not always (80,0)): the (80,1)
cell is itself the baseline a Hedge-only reader compares 81/82/83-at-HedgeMode=1
against, since HedgeMode is an orthogonal axis to Recovery escalation.

This order does NOT judge any EA or any mode - see CLAUDE.md VERDICT GATE. The bar
here is purely "does the harness work": all 8 cells run to completion and one
comparison table comes out the other end, recorded to -SummaryCsv as this run's
baseline for next time.

Example (defaults - safe lane2/portable to avoid the primary MT5 install, which may
have a live account connected; override -Terminal/-DataDir/-Portable to use lane1):
  powershell -File scripts\hedge_recovery_sweep.ps1
#>
[CmdletBinding()]
param(
  [string]$Expert    = "EALabTpl\Boss_14_GridLog",
  [string]$Symbol    = "AUDNZD",
  [string]$Period    = "H1",
  [string]$FromDate  = "2023.01.01",   # MAIN window pin (CLAUDE.md VERDICT GATE) - ends before HOLDOUT
  [string]$ToDate    = "2025.12.31",
  [string]$BaseSet   = "D:\EA_LAB\_mt5_auto\ab_sets\ORDER158_HRS_base.set",
  [string]$LabelPrefix = "hrs",
  [string]$OutCsv    = "D:\EA_LAB\_mt5_auto\ab_results.csv",
  [string]$SummaryCsv = "D:\EA_LAB\_mt5_auto\HEDGE_RECOVERY_SWEEP_SUMMARY.csv",
  # default lane2/portable: the primary D:\Meta 5 install can have a live account
  # attached (found connected 2026-07-23 while building this harness - see
  # ORDER-158 report) - default here to the secondary portable tester so this
  # script never has to touch/close that GUI. Pass the lane1 values explicitly
  # to use the primary install once it is free.
  [string]$Terminal = "D:\Meta 5b\terminal64.exe",
  [string]$DataDir  = "D:\Meta 5b",
  [switch]$Portable = $true,
  [int]$TimeoutSec  = 1800
)
$ErrorActionPreference = "Stop"

$abMode = Join-Path $PSScriptRoot "ab_mode_test.ps1"
if (-not (Test-Path $abMode)) { throw "ab_mode_test.ps1 not found: $abMode" }
if (-not (Test-Path $BaseSet)) { throw "BaseSet not found: $BaseSet" }

# sanity: BaseSet must actually BE the (80,0) cell, else the "beats_baseline" /
# flat-lot-twin math below is comparing against the wrong thing.
$baseLines = Get-Content $BaseSet
$hasRec80 = $baseLines | Where-Object { $_.Trim() -eq "RecoveryMode=80" }
$hasHedge0 = $baseLines | Where-Object { $_.Trim() -eq "HedgeMode=0" }
if (-not $hasRec80 -or -not $hasHedge0) {
  throw "BaseSet must be the (RecoveryMode=80, HedgeMode=0) baseline cell - got RecoveryMode/HedgeMode lines: $((Get-Content $BaseSet | Where-Object { $_ -match '^(RecoveryMode|HedgeMode)=' }) -join ', ')"
}

# the 7 non-baseline cells - (80,0) is the BaseSet itself, captured as part of
# every ab_mode_test.ps1 call's "base" row (identical every time).
$cells = @(
  @{ Rec = 80; Hedge = 1 },
  @{ Rec = 81; Hedge = 0 },
  @{ Rec = 81; Hedge = 1 },
  @{ Rec = 82; Hedge = 0 },
  @{ Rec = 82; Hedge = 1 },
  @{ Rec = 83; Hedge = 0 },
  @{ Rec = 83; Hedge = 1 }
)

$runLabels = @()
Write-Host "=== ORDER-158 Hedge/Recovery sweep: $Expert | $Symbol $Period | $FromDate..$ToDate ===" -ForegroundColor Yellow
Write-Host "BaseSet (cell RecoveryMode=80,HedgeMode=0): $BaseSet"
$i = 0
foreach ($c in $cells) {
  $i++
  $label = "${LabelPrefix}_$($c.Rec)_$($c.Hedge)_$Symbol"
  $runLabels += $label
  Write-Host ""
  Write-Host "--- cell $i/7: RecoveryMode=$($c.Rec) HedgeMode=$($c.Hedge)  (label=$label) ---" -ForegroundColor Cyan
  $abArgs = @{
    Expert    = $Expert
    Symbol    = $Symbol
    Period    = $Period
    FromDate  = $FromDate
    ToDate    = $ToDate
    BaseSet   = $BaseSet
    Overrides = "RecoveryMode=$($c.Rec);HedgeMode=$($c.Hedge)"
    Label     = $label
    OutCsv    = $OutCsv
    Terminal  = $Terminal
    DataDir   = $DataDir
    TimeoutSec = $TimeoutSec
  }
  if ($Portable) { $abArgs.Portable = $true }
  & $abMode @abArgs
}

if (-not (Test-Path $OutCsv)) { throw "ab_mode_test.ps1 never wrote $OutCsv - no rows to summarize." }
$allRows = Import-Csv $OutCsv
$myRows  = $allRows | Where-Object { $runLabels -contains $_.label }
if ($myRows.Count -ne $cells.Count) {
  Write-Warning "expected $($cells.Count) rows in $OutCsv for this sweep's labels, found $($myRows.Count) - a cell may have failed to append. Continuing with what's there."
}

function ToNum([string]$s) {
  if (-not $s) { return $null }
  $m = [regex]::Match($s, '[-+]?\d+(?:,\d{3})*(?:\.\d+)?')
  if (-not $m.Success) { return $null }
  return [double]($m.Value -replace ',', '')
}

# baseline row (80,0) - identical base_* columns on every one of the 7 rows above,
# take it from the first.
$b = $myRows | Select-Object -First 1
$summary = New-Object System.Collections.Generic.List[object]
$summary.Add([pscustomobject]@{
  recovery_mode = 80; hedge_mode = 0; is_baseline = $true
  pf = $b.base_pf; net = $b.base_net; trades = $b.base_trades
  eqdd = $b.base_eqdd; baldd = $b.base_baldd
  beats_baseline = ""; flat_lot_twin_mode = ""; flat_lot_twin_pf = ""; flat_lot_twin_trades = ""
  escalation_lift_vs_flatlot_pf = ""
})

foreach ($row in $myRows) {
  $rec = [int]$row.overrides.Split(';')[0].Split('=')[1]
  $hed = [int]$row.overrides.Split(';')[1].Split('=')[1]
  $summary.Add([pscustomobject]@{
    recovery_mode = $rec; hedge_mode = $hed; is_baseline = $false
    pf = $row.variant_pf; net = $row.variant_net; trades = $row.variant_trades
    eqdd = $row.variant_eqdd; baldd = $row.variant_baldd
    beats_baseline = ""; flat_lot_twin_mode = ""; flat_lot_twin_pf = ""; flat_lot_twin_trades = ""
    escalation_lift_vs_flatlot_pf = ""
  })
}

# baseline-per-hedge-column: RecoveryMode=80 at the SAME HedgeMode (0 -> the
# BaseSet row above; 1 -> whichever of the 7 rows is (80,1)).
function BaselinePF([int]$hedgeMode) {
  $row = $summary | Where-Object { $_.recovery_mode -eq 80 -and $_.hedge_mode -eq $hedgeMode }
  if ($row) { return (ToNum $row.pf) }
  return $null
}

foreach ($row in $summary) {
  if ($row.recovery_mode -eq 80) { continue }   # baseline rows don't compare to themselves
  $basePfNum = BaselinePF $row.hedge_mode
  $rowPfNum  = ToNum $row.pf
  if ($null -ne $basePfNum -and $null -ne $rowPfNum) {
    $row.beats_baseline = ($rowPfNum -gt $basePfNum)
  }
  if ($row.recovery_mode -eq 82 -or $row.recovery_mode -eq 83) {
    $twin = $summary | Where-Object { $_.recovery_mode -eq 81 -and $_.hedge_mode -eq $row.hedge_mode }
    if ($twin) {
      $row.flat_lot_twin_mode = 81
      $row.flat_lot_twin_pf = $twin.pf
      $row.flat_lot_twin_trades = $twin.trades
      $twinPfNum = ToNum $twin.pf
      if ($null -ne $rowPfNum -and $null -ne $twinPfNum) {
        $row.escalation_lift_vs_flatlot_pf = "{0:+0.00;-0.00;0.00}" -f ($rowPfNum - $twinPfNum)
      }
    }
  }
}

$summary = $summary | Sort-Object hedge_mode, recovery_mode

Write-Host ""
Write-Host "=== 8-CELL SUMMARY (Expert=$Expert Symbol=$Symbol $Period $FromDate..$ToDate) ===" -ForegroundColor Green
$summary | Format-Table recovery_mode, hedge_mode, is_baseline, pf, net, trades, eqdd, beats_baseline, flat_lot_twin_mode, flat_lot_twin_pf, escalation_lift_vs_flatlot_pf -AutoSize | Out-Host

$provRow = [pscustomobject]@{
  timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  expert = $Expert; symbol = $Symbol; period = $Period
  from = $FromDate; to = $ToDate; base_set = $BaseSet
  terminal = $Terminal; data_dir = $DataDir; portable = [bool]$Portable
  ab_results_csv = $OutCsv
}
Write-Host "provenance:" -ForegroundColor DarkGray
$provRow | Format-List | Out-Host

$exists = Test-Path $SummaryCsv
$summary | Export-Csv -Path $SummaryCsv -NoTypeInformation -Encoding UTF8 -Append:$exists
$provPath = $SummaryCsv -replace '\.csv$', '_provenance.csv'
$provExists = Test-Path $provPath
$provRow | Export-Csv -Path $provPath -NoTypeInformation -Encoding UTF8 -Append:$provExists

Write-Host ""
Write-Host "CSV appended -> $SummaryCsv (+ provenance -> $provPath)" -ForegroundColor Green
Write-Host "NOTE: this is harness output only - no EA/mode is judged good/bad/dead here (CLAUDE.md VERDICT GATE)." -ForegroundColor Yellow
