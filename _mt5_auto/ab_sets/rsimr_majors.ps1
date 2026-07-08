# ORDER-048 phase D — RSI-MR across ALL major forex (user: test majors ทั้งหมด, not 4-5).
# COARSE scan at the EURUSD-tuned plateau config (LOG5, ATR9 self-scaling, wide SL),
# M30 + H1, BOTH regimes. Cells clearing PF>1 both windows at DD<25% -> own ATR fine-sweep.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$set = "D:\EA_LAB\_mt5_auto\ab_sets\rsimr_atr\RSIMR_ATRf_9.set"
$out = "D:\EA_LAB\_mt5_auto\RSIMR_MAJORS.csv"
'"symbol","tf","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})
$syms = 'EURUSD','GBPUSD','USDJPY','USDCHF','USDCAD','AUDUSD','NZDUSD','EURJPY','GBPJPY','EURGBP','EURCHF','AUDJPY','CHFJPY','EURAUD'

foreach($sym in $syms){
  foreach($tf in 'M30','H1'){
    foreach($win in $wins){
      $rep = "RSIMR_MJ_${sym}_${tf}_$($win.w)"
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
"MAJORS DONE"; Get-Content $out
