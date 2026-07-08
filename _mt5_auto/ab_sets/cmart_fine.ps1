# ORDER-053c FINE — map the FIXED-lot ATR-distance surface across all 3 windows to find a
# hole-free plateau (atr1.0 & 2.5 passed holdout, 1.5 failed = noisy). Fill 0.8/1.2/2.0/3.0.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\cmart_ll"
$out = "D:\EA_LAB\_mt5_auto\CMART_FINE.csv"
'"atr","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"},@{w="HOLDOUT";f="2023.01.01";t="2025.01.01"},@{w="FWD";f="2025.01.01";t="2026.07.01"})
foreach($atr in 0.8,1.2,2.0,3.0){
  $set = "$setdir\cm_FIXED_fine$atr.set"
  @("_01_UseTrendlineToo=true","_01_UsePullback=false","_03_LotMode=0","_03_AddAtrMult=$atr") -join "`r`n" | Out-File $set -Encoding ascii
  foreach($win in $wins){
    Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
    $rep = "CMFINE_${atr}_$($win.w)"
    & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "CMART" -Symbol XAUUSD -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
    $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
    if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
      $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
      $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
      $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
      "$atr,`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
    else { "$atr,`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
  }
}
"CMART FINE DONE"; Get-Content $out
