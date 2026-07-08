# WFA for the re-opt reserve (sl1/tp5, rb60/kc2). 3 rolling windows, IS-opt RangeBars -> OOS.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\sqzcr_wfa"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\SQZCR_WFA.csv"
'"window","phase","rb","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$windows = @(
  @{w=1; is_f="2020.01.01"; is_t="2021.09.01"; oos_f="2021.09.01"; oos_t="2022.12.01"},
  @{w=2; is_f="2021.09.01"; is_t="2023.06.01"; oos_f="2023.06.01"; oos_t="2024.09.01"},
  @{w=3; is_f="2023.06.01"; is_t="2025.01.01"; oos_f="2025.01.01"; oos_t="2026.07.01"}
)
function RunPF { param([string]$f,[string]$t,[int]$rb,[string]$rep)
  $set="$setdir\wfa_rb$rb.set"; @("_01_RangeBars=$rb","_01_KcAtrMult=2.0","_03_SlAtrMult=1.0","_03_TpAtrMult=5.0") -join "`r`n" | Out-File $set -Encoding ascii
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
  & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "SQZ" -Symbol XAUUSD -Period H1 -FromDate $f -ToDate $t -Model 4 -SetFile $set -ReportName $rep | Out-Null
  $htm="D:\EA_LAB\_mt5_auto\reports\$rep.htm"
  if(-not(Test-Path $htm)){ return @{pf=0;dd=0;trd=0} }
  $j=python D:\EA_LAB\scripts\parse_mt5_report.py $htm
  return @{ pf=[double](($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim())
    dd=(($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim())
    trd=(($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()) }
}
foreach($win in $windows){
  $best=$null; $bestPf=-1
  foreach($rb in 40,60,80){
    $r=RunPF $win.is_f $win.is_t $rb "SQWFA_W$($win.w)_IS_$rb"
    "$($win.w),`"IS`",$rb,$($r.pf),$($r.dd),$($r.trd)" | Add-Content $out
    if($r.pf -gt $bestPf){ $bestPf=$r.pf; $best=$rb }
  }
  $ro=RunPF $win.oos_f $win.oos_t $best "SQWFA_W$($win.w)_OOS_$best"
  "$($win.w),`"OOS(rb=$best,isPF=$bestPf)`",$best,$($ro.pf),$($ro.dd),$($ro.trd)" | Add-Content $out
}
"SQZCR WFA DONE"; Get-Content $out
