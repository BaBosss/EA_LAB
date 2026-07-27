# =============================== HOLDOUT-BURNED ===============================
# ORDER-238 (2026-07-27). One or more test windows in this file end after
# 2025.12.31 -- that is, inside the 2026H1 holdout. They are deliberately LEFT
# AS-IS: they record what past runs actually did, and rewriting them would
# misrepresent that history.
#
# Therefore: do NOT re-run this script to produce selection evidence, and do NOT
# copy its window into new work. A holdout is spent the first time it is touched.
# The current MAIN window is pinned in the VERDICT GATE section of CLAUDE.md.
# ==============================================================================
<#
order104b_lambda_ibs.ps1 — ORDER-104 follow-up:
  Phase 1: HP lambda-sweep {1600,129600} on MAHP probe (16 runs)
  Phase 2: IBS mean-reversion probe W2 (8 runs)
Same matrix: {XAUUSD,EURUSD} × {H1,H4} × {BWD 2020-22, REC 2023-26}, Model 2.
Output -> _mt5_auto\reports\P104b_summary.csv
PREREQ: MT5 GUI closed; both ex5 already in roaming MQL5\Experts.
#>
$ErrorActionPreference="Stop"
$root="D:\EA_LAB"; $runner="$root\scripts\mt5_run.ps1"
$setDir="$root\_mt5_auto\ab_sets\order104"; $repDir="$root\_mt5_auto\reports"
New-Item -ItemType Directory -Force $setDir,$repDir | Out-Null

$symbols=@("XAUUSD","EURUSD"); $periods=@("H1","H4")
$windows=@(@{n="BWD";from="2020.01.01";to="2022.12.31"},@{n="REC";from="2023.01.01";to="2026.06.01"})
$rows=@()

function Run-Cell($expert,$combo,$set,$rep){
  & $runner -Expert $expert -Symbol $script:sym -Period $script:tf -FromDate $script:w.from -ToDate $script:w.to `
            -Model 2 -SetFile $set -ReportName $rep | Out-Null
  $htm="$repDir\$rep.htm"; $pf=""; $tr=""
  if(Test-Path $htm){ $t=Get-Content $htm -Raw -Encoding UTF8
    if($t -match 'Profit factor[^0-9\-]*([0-9]+\.[0-9]+)'){$pf=$matches[1]}
    if($t -match 'Total trades[^0-9\-]*([0-9]+)'){$tr=$matches[1]} }
  $script:rows += [PSCustomObject]@{combo=$combo;symbol=$script:sym;tf=$script:tf;window=$script:w.n;PF=$pf;trades=$tr;report=$rep}
}

# Phase 1: HP lambda sweep
$mahp="(TRD)_Probe_MAHP_TanhVol_rev01"
foreach($lam in @(1600,129600)){
  $setf="$setDir\hp$lam.set"
  Set-Content $setf @("_02_UseHPFilter=true","_02_HP_Window=120","_02_HP_Lambda=$lam","_03_UseTanhVol=false","_05_LotSize=0.01","_07_AllowLive=false") -Encoding ASCII
  foreach($s in $symbols){foreach($p in $periods){foreach($win in $windows){
    $script:sym=$s;$script:tf=$p;$script:w=$win
    $rep="P104b_hp$lam`_${s}_${p}_$($win.n)"; Write-Output "HP$lam $s $p $($win.n)"
    Run-Cell $mahp "hp$lam" $setf $rep
  }}}
}
# Phase 2: IBS probe (defaults)
$ibs="(TRD)_Probe_IBS_MR_rev01"
$ibsSet="$setDir\ibs.set"; Set-Content $ibsSet @("_01_BuyBelow=0.20","_01_SellAbove=0.80","_03_LotSize=0.01","_05_AllowLive=false") -Encoding ASCII
foreach($s in $symbols){foreach($p in $periods){foreach($win in $windows){
  $script:sym=$s;$script:tf=$p;$script:w=$win
  $rep="P105_ibs_${s}_${p}_$($win.n)"; Write-Output "IBS $s $p $($win.n)"
  Run-Cell $ibs "ibs" $ibsSet $rep
}}}

$csv="$repDir\P104b_summary.csv"; $rows | Export-Csv $csv -NoTypeInformation -Encoding UTF8
Write-Output "DONE. -> $csv"; $rows | Format-Table -AutoSize
