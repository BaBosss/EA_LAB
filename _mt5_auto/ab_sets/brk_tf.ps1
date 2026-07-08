# ORDER-052e — BRK-XAU across timeframes (user: try other TFs). H1 was thin (~13 trd/yr);
# lower TFs = more trades = better stats IF the edge holds. XAUUSD, BUY-only, 3 windows each.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$out = "D:\EA_LAB\_mt5_auto\BRK_TF.csv"
'"tf","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$set = "D:\EA_LAB\_mt5_auto\ab_sets\brkxau_sets\brk_BUYONLY.set"
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"},@{w="HOLDOUT";f="2023.01.01";t="2025.01.01"},@{w="FWD";f="2025.01.01";t="2026.07.01"})
foreach($tf in 'M15','M30','H4'){
  foreach($win in $wins){
    Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
    $rep = "BRKTF_${tf}_$($win.w)"
    & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "BRKXAU" -Symbol XAUUSD -Period $tf -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
    $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
    if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
      $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
      $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
      $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
      "`"$tf`",`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
    else { "`"$tf`",`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
  }
}
"BRK TF DONE"; Get-Content $out
