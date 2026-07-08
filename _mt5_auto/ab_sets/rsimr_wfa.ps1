# ORDER-048 phase F — proper anchored Walk-Forward for RSI-MR EURUSD H1 (the one
# test the robustness-validator skill flagged SKIPPED -> was capping it at MARGINAL).
# 3 rolling windows (SWING requires 3). Each: IS-optimize ATR {8,9,10} -> pick best PF
# -> test that ATR on the FORWARD OOS slice. Reports ER + OOS-profitable% for WFA scoring.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_wfa"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\RSIMR_WFA.csv"
'"window","phase","atr","pf","dd_pct","trades"' | Out-File $out -Encoding utf8

$windows = @(
  @{w=1; is_f="2020.01.01"; is_t="2021.09.01"; oos_f="2021.09.01"; oos_t="2022.12.01"},
  @{w=2; is_f="2021.09.01"; is_t="2023.06.01"; oos_f="2023.06.01"; oos_t="2024.09.01"},
  @{w=3; is_f="2023.06.01"; is_t="2025.01.01"; oos_f="2025.01.01"; oos_t="2026.07.01"}
)

function RunPF { param([string]$f,[string]$t,[double]$atr,[string]$rep)
  $set = "$setdir\wfa_$atr.set"
  @("_02_SlAtrMult=25.0","_02_SlMaxPips=600.0","_05_LotMode=3","_05_LogFactor=5.0","_03_DistAtrMult=$atr") -join "`r`n" | Out-File $set -Encoding ascii
  & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol EURUSD -Period H1 -FromDate $f -ToDate $t -Model 4 -SetFile $set -ReportName $rep | Out-Null
  $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
  if(-not(Test-Path $htm)){ return @{pf=0;dd=0;trd=0} }
  $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
  return @{
    pf=[double](($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim())
    dd=(($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim())
    trd=(($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim())
  }
}

foreach($win in $windows){
  # IS optimize over ATR 8/9/10
  $best=$null; $bestPf=-1
  foreach($atr in 8.0,9.0,10.0){
    $r = RunPF $win.is_f $win.is_t $atr "WFA_W$($win.w)_IS_$atr"
    "$($win.w),`"IS`",$atr,$($r.pf),$($r.dd),$($r.trd)" | Add-Content $out
    if($r.pf -gt $bestPf){ $bestPf=$r.pf; $best=$atr }
  }
  # OOS test at IS-best ATR
  $ro = RunPF $win.oos_f $win.oos_t $best "WFA_W$($win.w)_OOS_$best"
  "$($win.w),`"OOS(atr=$best,isPF=$bestPf)`",$best,$($ro.pf),$($ro.dd),$($ro.trd)" | Add-Content $out
}
"WFA DONE"; Get-Content $out
