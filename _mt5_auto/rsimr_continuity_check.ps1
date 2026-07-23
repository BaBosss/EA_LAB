# RSI-MR (990103) continuous-span probe — Step 0 flat-lot + Step 4 both-window,
# run as SINGLE CONTINUOUS spans (not stitched WFA folds) because this is a per-side
# BASKET/grid EA (MaxPositions=8, dual-side, LotMode=LOG escalation). The existing
# WFA (ORDER-168) ran 3 separate ~2yr resets, which the skill's own catalog warns can
# lie ~10x for basket EAs vs one continuous span. Also: existing flat-lot number
# (RSIMR_LOTLAW.csv, PF 0.78) used a PARTIAL .set predating the ORDER-165 cache fix,
# so it is not trustworthy as-is. This script re-runs both escalated + flat-lot on
# the SAME full-pinned config, MAIN + BWD, on D:\Meta 5b to avoid the primary lane
# (D:\Meta 5) currently in use by another session.
$ErrorActionPreference = "Continue"
$run = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_continuity_check"
$repDir = "D:\EA_LAB\_mt5_auto\reports"
$out = "D:\EA_LAB\_mt5_auto\RSIMR_CONTINUITY_CHECK.csv"
'"tag","window","pf","net","trades","dd_pct","win_pct"' | Out-File $out -Encoding utf8

function Parse-Htm($Path) {
  $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::Unicode)
  $txt = ($raw -replace '<[^>]+>', ' ') -replace '&nbsp;', ' '
  function Grab($label) {
    $m = [regex]::Match($txt, [regex]::Escape($label) + '\s*(-?[\d]{1,3}(?:[ ,]\d{3})*(?:\.\d+)?)')
    if ($m.Success) { return ($m.Groups[1].Value -replace '[ ,]', '') }
    return $null
  }
  $pf = Grab 'Profit Factor:'
  $np = Grab 'Total Net Profit:'
  $tr = Grab 'Total Trades:'
  $mddm = [regex]::Match($txt, 'Equity Drawdown Maximal:\s*([\d.,]+)\s*\(([\d.,]+)%\)')
  $ddpct = if ($mddm.Success) { $mddm.Groups[2].Value } else { "" }
  $pt = [regex]::Match($txt, 'Profit Trades \(% of total\):\s*(\d+)\s*\(([\d.,]+)%\)')
  $winp = if ($pt.Success) { $pt.Groups[2].Value } else { "" }
  return [PSCustomObject]@{ PF=$pf; Net=$np; Trades=$tr; DDpct=$ddpct; Win=$winp }
}

$windows = @(
  @{tag="MAIN"; f="2023.01.01"; t="2026.01.01"},
  @{tag="BWD";  f="2020.01.01"; t="2023.01.01"}
)
$configs = @(
  @{tag="ESCALATED_LOG5"; set="$setDir\RSIMR_atr9_escalated_full.set"},
  @{tag="FLATLOT"; set="$setDir\RSIMR_atr9_flat_full.set"}
)

foreach ($cfg in $configs) {
  foreach ($w in $windows) {
    $rep = "RSIMR_CONT_$($cfg.tag)_$($w.tag)"
    Write-Output "[$(Get-Date -Format s)] START $rep"
    & $run -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol EURUSD -Period H1 `
        -FromDate $w.f -ToDate $w.t -Model 4 -SetFile $cfg.set -ReportName $rep `
        -Terminal "D:\Meta 5b\terminal64.exe" -DataDir "D:\Meta 5b" -Portable `
        -TimeoutSec 1800 | Out-Null
    $htm = "$repDir\$rep.htm"
    if (Test-Path $htm) {
      $s = Parse-Htm $htm
      Write-Output "[$(Get-Date -Format s)] DONE $rep -> PF=$($s.PF) Net=$($s.Net) Trades=$($s.Trades) DD=$($s.DDpct)% Win=$($s.Win)%"
      "`"$($cfg.tag)`",`"$($w.tag)`",$($s.PF),$($s.Net),$($s.Trades),$($s.DDpct),$($s.Win)" | Add-Content $out
    } else {
      Write-Output "[$(Get-Date -Format s)] NO_REPORT $rep"
      "`"$($cfg.tag)`",`"$($w.tag)`",,,,,NO_REPORT" | Add-Content $out
    }
  }
}
Write-Output "CONTINUITY CHECK DONE -> $out"
