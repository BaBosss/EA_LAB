# ORDER-052c — optimize LondonConso frequency+edge (user 2026-07-08: low freq = tight
# ConsoAtrMult / far TP, should be tunable). Sweep the entry filter _01_ConsoAtrMult
# (0.8 default = very tight = few trades) + _02_TpAtrMult, GBPUSD both regimes.
# Looser filter -> more setups qualify -> higher frequency. Find config with adequate
# trades (>=40/window) AND both-regime PF>1 -> holdout.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\london_sets"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\LONDON_OPT.csv"
'"conso","tp","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})
foreach($conso in 0.8,1.2,1.6,2.0){
  foreach($tp in 2.0,3.0){
    $set = "$setdir\LDN_c${conso}_tp$tp.set"
    @("_01_ConsoAtrMult=$conso","_02_TpAtrMult=$tp") -join "`r`n" | Out-File $set -Encoding ascii
    foreach($win in $wins){
      Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false
      Start-Sleep 2
      $rep = "LDNOPT_c${conso}_tp${tp}_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "LondonConso" -Symbol GBPUSD -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
      $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "$conso,$tp,`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "$conso,$tp,`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
}
"LONDON OPT DONE"; Get-Content $out
