# SqueezeBreakout optimize on XAUUSD: KcAtrMult (squeeze tightness) x TpAtrMult, both regimes.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\sqz_sets"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\SQZ_OPT.csv"
'"kc","tp","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})
foreach($kc in 1.0,1.5,2.0){
  foreach($tp in 3.0,4.0,5.0){
    $set = "$setdir\sqz_kc${kc}_tp$tp.set"; @("_01_KcAtrMult=$kc","_03_TpAtrMult=$tp") -join "`r`n" | Out-File $set -Encoding ascii
    foreach($win in $wins){
      Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
      $rep="SQZOPT_${kc}_${tp}_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "SQZ" -Symbol XAUUSD -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
      $h="D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $h){ $j=python D:\EA_LAB\scripts\parse_mt5_report.py $h
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "$kc,$tp,`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "$kc,$tp,`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
}
"SQZ OPT DONE"; Get-Content $out
