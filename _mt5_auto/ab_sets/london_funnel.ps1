# ORDER-052b — validate LondonConsoBreakout (prior CANDIDATE GBPUSD 2.08/3-OOS, never demo'd)
# through the rigorous 3-window funnel at DEFAULT params. Single-position session breakout,
# real SL/TP, fixed lot = cleanest L1 EA. Symbols: GBPUSD (candidate) + XAUUSD (gold breakout
# home) + EURUSD. 3 independent windows each. Cells passing all 3 -> MC + WFA.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$out = "D:\EA_LAB\_mt5_auto\LONDON_FUNNEL.csv"
'"symbol","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(
  @{w="BWD";f="2020.01.01";t="2023.01.01"},
  @{w="HOLDOUT";f="2023.01.01";t="2025.01.01"},
  @{w="FWD";f="2025.01.01";t="2026.07.01"}
)
foreach($sym in 'GBPUSD','XAUUSD','EURUSD'){
  foreach($win in $wins){
    $rep = "LDN_${sym}_$($win.w)"
    & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "LondonConso" -Symbol $sym -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -ReportName $rep | Out-Null
    $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
    if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
      $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
      $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
      $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
      "`"$sym`",`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
    else { "`"$sym`",`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
  }
}
"LONDON FUNNEL DONE"; Get-Content $out
