<#
walkforward.ps1 — ORDER-157: generalized walk-forward runner.

Generalizes the shape shared by the 4 hand-written scripts in _mt5_auto/ab_sets/
(rsimr_wfa.ps1, sqzcr_wfa.ps1, brk_wfa.ps1, zigl_xau_wfa.ps1): for each fold,
IS-optimize one or more .set params over a grid on an in-sample window, pick the
best-scoring (highest PF) combo, then run ONE forward out-of-sample test with that
combo on the next window slice. Repeat across folds.

Two things those 4 scripts never actually did, which this script does:
  1. REAL summarizer — per fold: efficiency ratio (OOS PF / IS-best PF) and whether
     that fold's OOS was profitable (PF>1). Across folds: mean efficiency ratio and
     %-of-folds-OOS-profitable. Written as real numbers into a JSON summary, not a
     raw CSV dump left for a human to eyeball.
  2. Canonical window pin — dates come from ONE place (scripts/window_pin.ps1, the
     machine-readable mirror of CLAUDE.md's VERDICT GATE pin: MAIN 2023.01-2025.12 /
     BWD 2020-2022 / HOLDOUT 2026H1) instead of being re-typed ad hoc per script.
     Before any MT5 process is launched, EVERY fold's IS and OOS window is checked
     against HOLDOUT and the whole run is refused (no partial execution) if any
     window overlaps it. This is a structural fix for the exact leakage class
     Codex caught in the system review on 2026-07-18 (MAIN re-pinned over the
     current HOLDOUT and nobody noticed until later).

Provenance recorded per run: EA source file SHA-256 (best-effort discovery under
ea_projects\), the merged .set file used, the actual IS/OOS date windows, the
Strategy Tester model number, and the report file path.

NOT for verdicts: this script only produces numbers. It never judges, kills, or
promotes an EA — the caller (a human, or another order) does that with the output.
Model-2 is never used for reported numbers (fixed at Model=4 by default; overriding
to Model=2 is intentionally not blocked here at the type level, but the project
rule is: never report Model-2 numbers as results — pass -Model 4 or higher).

USAGE (auto-generated canon-pinned folds, single param):
  .\walkforward.ps1 -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol EURUSD -Period H1 `
    -ParamGrid @(@{Name="_03_DistAtrMult"; Values=8.0,9.0,10.0}) `
    -BaseInputs @("_02_SlAtrMult=25.0","_02_SlMaxPips=600.0","_05_LotMode=3","_05_LogFactor=5.0") `
    -OutPrefix RSIMR_EURUSD_H1 -Folds 3 -ISMonths 14 -OOSMonths 10

USAGE (explicit windows — e.g. regression-testing against a legacy script's exact
dates, or deliberately probing the holdout-refusal path):
  .\walkforward.ps1 ... -Windows @(
    @{ISFrom="2020.01.01"; ISTo="2021.09.01"; OOSFrom="2021.09.01"; OOSTo="2022.12.01"}
  )
#>
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period = "H1",
  # Array of @{Name="_xx_Param"; Values=<double[]>}. Cartesian product across entries
  # when more than one param is given (matches the 4 legacy scripts' single-param
  # case when only one entry is passed).
  [Parameter(Mandatory)][object[]]$ParamGrid,
  [string[]]$BaseInputs = @(),
  [string]$EaSourcePath = "",          # optional; auto-discovered under ea_projects\ by exact basename if omitted
  [int]$Model = 4,
  [Parameter(Mandatory)][string]$OutPrefix,
  [string]$SetDir = "",                 # default: _mt5_auto\ab_sets\walkforward\<OutPrefix>
  [string]$OutCsv = "",                 # default: _mt5_auto\<OutPrefix>_WFA.csv
  [string]$SummaryJson = "",            # default: _mt5_auto\<OutPrefix>_WFA_SUMMARY.json
  # --- fold generation (used unless -Windows is supplied explicitly) ---
  # Defaults (Folds=3, IS=14mo, OOS=10mo) tile exactly BWD.From (2020.01.01) through
  # HOLDOUT.From (2026.01.01) with zero gap and zero HOLDOUT overlap -- i.e. the full
  # canon BWD+MAIN span, 3 non-overlapping folds, nothing invented. Override per-call
  # for a different fold count/width; the HOLDOUT gate below still applies regardless.
  [int]$Folds = 3,
  [int]$ISMonths = 14,
  [int]$OOSMonths = 10,
  [string]$StartDate = "",              # default: pin.BWD.From ("yyyy.MM.dd"); NOT free-invented
  # --- explicit override: array of @{ISFrom;ISTo;OOSFrom;OOSTo} strings "yyyy.MM.dd" ---
  [object[]]$Windows = $null,
  [switch]$DryRun,                      # validate + print the fold plan, run nothing
  [switch]$Force,                       # passthrough to mt5_run.ps1 -Force
  [int]$TimeoutSec = 1800,
  [string]$Terminal = "",               # passthrough to mt5_run.ps1 -Terminal (e.g. a 2nd portable install)
  [string]$DataDir = "",                # passthrough to mt5_run.ps1 -DataDir
  [switch]$Portable                     # passthrough to mt5_run.ps1 -Portable
)
$ErrorActionPreference = "Stop"
$root = "D:\EA_LAB"
. "$root\scripts\use_python.ps1"
. "$root\scripts\window_pin.ps1"
$pin = Get-WindowPin

if ($Model -eq 2) {
  Write-Output "ABORT: Model=2 is disallowed for reported walk-forward numbers (project rule: Model-2 filters zero-trade only, never a result). Use -Model 4 (default) or a documented higher-fidelity model."
  exit 2
}

# ---------- fold construction ----------
function Fmt([datetime]$d) { $d.ToString("yyyy.MM.dd") }

$foldList = @()
if ($Windows) {
  $i = 0
  foreach ($w in $Windows) {
    $i++
    $foldList += [PSCustomObject]@{
      Fold    = $i
      ISFrom  = [datetime]::ParseExact($w.ISFrom,  "yyyy.MM.dd", $null)
      ISTo    = [datetime]::ParseExact($w.ISTo,    "yyyy.MM.dd", $null)
      OOSFrom = [datetime]::ParseExact($w.OOSFrom, "yyyy.MM.dd", $null)
      OOSTo   = [datetime]::ParseExact($w.OOSTo,   "yyyy.MM.dd", $null)
    }
  }
} else {
  $start = if ($StartDate) { [datetime]::ParseExact($StartDate, "yyyy.MM.dd", $null) } else { $pin.BWD.From }
  for ($f = 1; $f -le $Folds; $f++) {
    $isFrom  = $start.AddMonths(($f - 1) * ($ISMonths + $OOSMonths))
    $isTo    = $isFrom.AddMonths($ISMonths)
    $oosFrom = $isTo
    $oosTo   = $oosFrom.AddMonths($OOSMonths)
    $foldList += [PSCustomObject]@{ Fold = $f; ISFrom = $isFrom; ISTo = $isTo; OOSFrom = $oosFrom; OOSTo = $oosTo }
  }
}

# ---------- HOLDOUT-overlap gate: refuse BEFORE launching anything ----------
$violations = @()
foreach ($fw in $foldList) {
  if (Test-WindowOverlap $fw.ISFrom $fw.ISTo $pin.HOLDOUT.From $pin.HOLDOUT.To) {
    $violations += "fold $($fw.Fold) IS window $(Fmt $fw.ISFrom)-$(Fmt $fw.ISTo) overlaps HOLDOUT $(Fmt $pin.HOLDOUT.From)-$(Fmt $pin.HOLDOUT.To)"
  }
  if (Test-WindowOverlap $fw.OOSFrom $fw.OOSTo $pin.HOLDOUT.From $pin.HOLDOUT.To) {
    $violations += "fold $($fw.Fold) OOS window $(Fmt $fw.OOSFrom)-$(Fmt $fw.OOSTo) overlaps HOLDOUT $(Fmt $pin.HOLDOUT.From)-$(Fmt $pin.HOLDOUT.To)"
  }
}
if ($violations.Count -gt 0) {
  Write-Output "REFUSED: walk-forward plan leaks into HOLDOUT ($(Fmt $pin.HOLDOUT.From)-$(Fmt $pin.HOLDOUT.To)). MAIN (a HOLDOUT b HOLDOUT = empty) is the iron rule (CLAUDE.md VERDICT GATE). Nothing was run."
  foreach ($v in $violations) { Write-Output "  - $v" }
  Write-Output "Fix: shorten ISMonths/OOSMonths/Folds, pick an earlier -StartDate, or (if -Windows was explicit) correct the offending window. Do not hand-edit HOLDOUT to make this pass."
  exit 3
}

# ---------- provenance: EA source hash ----------
if (-not $EaSourcePath) {
  $hit = Get-ChildItem -Path "$root\ea_projects" -Recurse -Filter "*.mq5" -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -eq $Expert } | Select-Object -First 1
  if ($hit) { $EaSourcePath = $hit.FullName }
}
$eaHash = $null
if ($EaSourcePath -and (Test-Path $EaSourcePath)) {
  $eaHash = (Get-FileHash -LiteralPath $EaSourcePath -Algorithm SHA256).Hash
} else {
  Write-Output "WARNING: EA source (.mq5) not found for provenance hash (Expert='$Expert', EaSourcePath='$EaSourcePath'). Continuing without it -- provenance will show ea_source_sha256=NOT_FOUND."
}

# ---------- output paths ----------
if (-not $SetDir)      { $SetDir      = "$root\_mt5_auto\ab_sets\walkforward\$OutPrefix" }
if (-not $OutCsv)      { $OutCsv      = "$root\_mt5_auto\${OutPrefix}_WFA.csv" }
if (-not $SummaryJson) { $SummaryJson = "$root\_mt5_auto\${OutPrefix}_WFA_SUMMARY.json" }
New-Item -ItemType Directory -Force $SetDir | Out-Null
'"fold","phase","params","pf","dd_pct","trades","window_from","window_to","model","set_path","report_path"' |
  Out-File $OutCsv -Encoding utf8

Write-Output "=== walkforward.ps1 plan ==="
Write-Output "Expert=$Expert Symbol=$Symbol Period=$Period Model=$Model"
Write-Output "EA source: $EaSourcePath (sha256=$eaHash)"
Write-Output "Window pin: MAIN $(Fmt $pin.MAIN.From)-$(Fmt $pin.MAIN.To) | BWD $(Fmt $pin.BWD.From)-$(Fmt $pin.BWD.To) | HOLDOUT $(Fmt $pin.HOLDOUT.From)-$(Fmt $pin.HOLDOUT.To) (pinned $(Fmt $pin.PinnedOn))"
foreach ($fw in $foldList) {
  Write-Output "  fold $($fw.Fold): IS $(Fmt $fw.ISFrom)-$(Fmt $fw.ISTo)  ->  OOS $(Fmt $fw.OOSFrom)-$(Fmt $fw.OOSTo)"
}
if ($DryRun) { Write-Output "DRY RUN: plan validated (no HOLDOUT overlap), no backtests executed."; exit 0 }

# ---------- cartesian product of ParamGrid ----------
function Get-Combos([object[]]$grid) {
  $combos = @(@{})
  foreach ($p in $grid) {
    $name = $p.Name
    $next = @()
    foreach ($c in $combos) {
      foreach ($v in $p.Values) {
        $nc = $c.Clone()
        $nc[$name] = $v
        $next += ,$nc
      }
    }
    $combos = $next
  }
  return $combos
}
$combos = Get-Combos $ParamGrid
function ComboTag($combo) {
  ($combo.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ";"
}
function ComboFileTag($combo) {
  (ComboTag $combo) -replace '[^A-Za-z0-9=;.\-]', '_'
}

function RunCombo {
  param([datetime]$From, [datetime]$To, [hashtable]$Combo, [string]$ReportName)
  $tag = ComboFileTag $Combo
  $set = Join-Path $SetDir "$tag.set"
  $lines = @()
  $lines += $BaseInputs
  foreach ($k in $Combo.Keys) { $lines += "$k=$($Combo[$k])" }
  $lines -join "`r`n" | Out-File $set -Encoding ascii
  $mt5Args = @{
    Expert = $Expert; Symbol = $Symbol; Period = $Period
    FromDate = (Fmt $From); ToDate = (Fmt $To)
    Model = $Model; SetFile = $set; ReportName = $ReportName
    TimeoutSec = $TimeoutSec
  }
  if ($Force) { $mt5Args["Force"] = $true }
  if ($Terminal) { $mt5Args["Terminal"] = $Terminal }
  if ($DataDir)  { $mt5Args["DataDir"]  = $DataDir }
  if ($Portable) { $mt5Args["Portable"] = $true }
  & "$root\scripts\mt5_run.ps1" @mt5Args | Out-Null
  $htm = "$root\_mt5_auto\reports\$ReportName.htm"
  if (-not (Test-Path $htm)) {
    return [PSCustomObject]@{ pf = 0; dd = 0; trd = 0; report = $htm; set = $set; ok = $false }
  }
  $j = python "$root\scripts\parse_mt5_report.py" $htm
  $pf  = [double](($j | Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim())
  $dd  = (($j | Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim())
  $trd = (($j | Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim())
  return [PSCustomObject]@{ pf = $pf; dd = $dd; trd = $trd; report = $htm; set = $set; ok = $true }
}

$foldSummaries = @()
foreach ($fw in $foldList) {
  $best = $null; $bestPf = -1; $bestCombo = $null
  foreach ($combo in $combos) {
    $rn = "WF_${OutPrefix}_F$($fw.Fold)_IS_$(ComboFileTag $combo)"
    $r = RunCombo $fw.ISFrom $fw.ISTo $combo $rn
    "$($fw.Fold),`"IS`",`"$(ComboTag $combo)`",$($r.pf),$($r.dd),$($r.trd),$(Fmt $fw.ISFrom),$(Fmt $fw.ISTo),$Model,`"$($r.set)`",`"$($r.report)`"" | Add-Content $OutCsv
    if ($r.pf -gt $bestPf) { $bestPf = $r.pf; $bestCombo = $combo; $best = $r }
  }
  $rn = "WF_${OutPrefix}_F$($fw.Fold)_OOS_$(ComboFileTag $bestCombo)"
  $ro = RunCombo $fw.OOSFrom $fw.OOSTo $bestCombo $rn
  "$($fw.Fold),`"OOS(is_best=$(ComboTag $bestCombo);isPF=$bestPf)`",`"$(ComboTag $bestCombo)`",$($ro.pf),$($ro.dd),$($ro.trd),$(Fmt $fw.OOSFrom),$(Fmt $fw.OOSTo),$Model,`"$($ro.set)`",`"$($ro.report)`"" | Add-Content $OutCsv

  $er = if ($bestPf -gt 0) { [math]::Round($ro.pf / $bestPf, 4) } else { $null }
  $foldSummaries += [PSCustomObject]@{
    fold                 = $fw.Fold
    is_window            = "$(Fmt $fw.ISFrom)-$(Fmt $fw.ISTo)"
    oos_window           = "$(Fmt $fw.OOSFrom)-$(Fmt $fw.OOSTo)"
    is_best_params       = (ComboTag $bestCombo)
    is_best_pf           = $bestPf
    oos_pf               = $ro.pf
    oos_trades           = $ro.trd
    efficiency_ratio      = $er
    oos_profitable       = ($ro.pf -gt 1)
    is_report            = $best.report
    oos_report           = $ro.report
    is_set               = $best.set
    oos_set              = $ro.set
  }
}

## @()-wrap every Where-Object result below on purpose: Windows PowerShell 5.1 returns a bare
## scalar (no .Count member) instead of a 1-element array when exactly one item matches a
## filter, which silently coerces .Count to $null -> 0 in arithmetic. Caught live during
## acceptance testing (Folds=1 run reported "pct_folds_oos_profitable=0" despite the single
## fold's OOS actually being profitable) -- do not remove these wrappers.
$validEr = @($foldSummaries | Where-Object { $null -ne $_.efficiency_ratio } | ForEach-Object { $_.efficiency_ratio })
$avgEr = if ($validEr.Count -gt 0) { [math]::Round(($validEr | Measure-Object -Average).Average, 4) } else { $null }
$profitableFolds = @($foldSummaries | Where-Object { $_.oos_profitable })
$pctOosProfitable = [math]::Round(($profitableFolds.Count / [double]$foldSummaries.Count) * 100, 1)

$summary = [PSCustomObject]@{
  order          = "ORDER-157"
  generated_at   = (Get-Date).ToString("s")
  expert         = $Expert
  symbol         = $Symbol
  period         = $Period
  model          = $Model
  ea_source_path = $EaSourcePath
  ea_source_sha256 = $(if ($eaHash) { $eaHash } else { "NOT_FOUND" })
  base_inputs    = $BaseInputs
  param_grid     = ($ParamGrid | ForEach-Object { [PSCustomObject]@{ name = $_.Name; values = $_.Values } })
  window_pin_used = [PSCustomObject]@{
    MAIN    = "$(Fmt $pin.MAIN.From)-$(Fmt $pin.MAIN.To)"
    BWD     = "$(Fmt $pin.BWD.From)-$(Fmt $pin.BWD.To)"
    HOLDOUT = "$(Fmt $pin.HOLDOUT.From)-$(Fmt $pin.HOLDOUT.To)"
    pinned_on = (Fmt $pin.PinnedOn)
  }
  folds                       = $foldSummaries
  n_folds                     = $foldSummaries.Count
  avg_efficiency_ratio        = $avgEr
  pct_folds_oos_profitable    = $pctOosProfitable
  note = "Tooling output only (ORDER-157). Not a verdict -- do not use these numbers to judge/kill/promote an EA without going through the VERDICT GATE in CLAUDE.md."
}
$summary | ConvertTo-Json -Depth 8 | Out-File $SummaryJson -Encoding utf8

Write-Output "=== SUMMARY ==="
Write-Output "avg_efficiency_ratio = $avgEr"
Write-Output "pct_folds_oos_profitable = $pctOosProfitable%"
foreach ($fs in $foldSummaries) {
  Write-Output ("  fold {0}: IS-best {1} pf={2}  ->  OOS pf={3} trd={4}  ER={5}  OOS-profitable={6}" -f `
    $fs.fold, $fs.is_best_params, $fs.is_best_pf, $fs.oos_pf, $fs.oos_trades, $fs.efficiency_ratio, $fs.oos_profitable)
}
Write-Output "CSV: $OutCsv"
Write-Output "Summary JSON: $SummaryJson"
