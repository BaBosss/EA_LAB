# ORDER-053 — optimize TrendlineBreakout on XAUUSD (gold=proven breakout home), both regimes.
# Levers: _02_TpAtrMult (RR) x _01_RequireConverge (triangle-only vs any trendline). Coarse.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\tlbrk_sets"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\TLBRK_OPT.csv"
'"tp","converge","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})
foreach($tp in 3.0,4.0,5.0,6.0){
  foreach($cv in 'true','false'){
    $set = "$setdir\tl_tp${tp}_cv$cv.set"; @("_02_TpAtrMult=$tp","_01_RequireConverge=$cv") -join "`r`n" | Out-File $set -Encoding ascii
    foreach($win in $wins){
      Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
      $rep = "TLOPT_tp${tp}_$($cv)_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "TLBRK" -Symbol XAUUSD -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
      $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "$tp,`"$cv`",`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "$tp,`"$cv`",`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
}
"TLBRK OPT DONE"; Get-Content $out
