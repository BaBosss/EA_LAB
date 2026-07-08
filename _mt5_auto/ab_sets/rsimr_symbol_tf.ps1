# ORDER-048 phase C — RSI-MR broad symbol x TF COARSE scan, both regimes.
# Config = the EURUSD-tuned plateau centre (LOG5 lot, ATR9 spacing, wide SL).
# ATR spacing is self-scaling so ATR9 should adapt across symbol/TF — coarse test
# of that claim. Any symbol x TF cell that clears PF>1 in BOTH windows at DD<25%
# becomes a fine-tune candidate (its OWN ATR plateau, not assumed = 9).
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$set = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_atr\RSIMR_ATRf_9.set"   # LOG5 + ATR9 + wide SL
$out = "D:\EA_LAB\_mt5_auto\RSIMR_SYMTF.csv"
'"symbol","tf","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})

foreach($sym in 'EURUSD','GBPUSD','USDJPY','AUDUSD'){
  foreach($tf in 'M30','H1','H4'){
    foreach($win in $wins){
      $rep = "RSIMR_ST_${sym}_${tf}_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "(Boss)_RSI_MR_GridLog_rev01" -Symbol $sym -Period $tf -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
      $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "`"$sym`",`"$tf`",`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "`"$sym`",`"$tf`",`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
}
"SYMTF DONE"; Get-Content $out
