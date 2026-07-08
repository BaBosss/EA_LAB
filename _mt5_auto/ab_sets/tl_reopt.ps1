# re-opt Trendline breakout with the tight-SL lever that saved SqueezeBRK (0.87->needs clearing).
# converge=true (triangle), sweep SlAtrMult x TpAtrMult on XAUUSD both regimes.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\tl_sets"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\TL_REOPT.csv"
'"sl","tp","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})
foreach($sl in 1.0,1.5){
  foreach($tp in 5.0,6.0,7.0,8.0){
    $set = "$setdir\tl_sl${sl}_tp$tp.set"
    @("_01_RequireConverge=true","_02_SlAtrMult=$sl","_02_TpAtrMult=$tp") -join "`r`n" | Out-File $set -Encoding ascii
    foreach($win in $wins){
      Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
      $rep="TLR_${sl}_${tp}_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "TLBRK" -Symbol XAUUSD -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
      $h="D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $h){ $j=python D:\EA_LAB\scripts\parse_mt5_report.py $h
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "$sl,$tp,`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "$sl,$tp,`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
}
"TL REOPT DONE"; Get-Content $out
