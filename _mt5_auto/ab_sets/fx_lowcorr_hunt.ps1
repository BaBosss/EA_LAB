# ORDER-056 — hunt low-corr EAs: run the working Trendline + Squeeze configs on EURUSD/GBPUSD
# (different instrument = different corr with the gold cohort). 3-window funnel each.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\fxhunt_sets"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\FX_LOWCORR.csv"
'"ea","symbol","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"},@{w="HOLDOUT";f="2023.01.01";t="2025.01.01"},@{w="FWD";f="2025.01.01";t="2026.07.01"})
# Trendline config
"_01_RequireConverge=true`r`n_02_SlAtrMult=1.5`r`n_02_TpAtrMult=8.0" | Out-File "$setdir\tl.set" -Encoding ascii
# Squeeze (DonchSqz) config
"_01_RangeBars=60`r`n_01_KcAtrMult=2.0`r`n_03_SlAtrMult=1.0`r`n_03_TpAtrMult=5.0" | Out-File "$setdir\sqz.set" -Encoding ascii
$eas=@(@{n="TL";exp="TLBRK";set="$setdir\tl.set"},@{n="SQZ";exp="SQZ";set="$setdir\sqz.set"})
foreach($e in $eas){
  foreach($sym in 'EURUSD','GBPUSD'){
    foreach($win in $wins){
      Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
      $rep="FXH_$($e.n)_${sym}_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert $e.exp -Symbol $sym -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $e.set -ReportName $rep | Out-Null
      $h="D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $h){ $j=python D:\EA_LAB\scripts\parse_mt5_report.py $h
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "`"$($e.n)`",`"$sym`",`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "`"$($e.n)`",`"$sym`",`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
}
"FX LOWCORR DONE"; Get-Content $out
