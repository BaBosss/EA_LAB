# ORDER-054 — do the validated gold breakouts (BRK-XAU, Zeus) TRAVEL to other trending
# commodities (silver, oil)? 3-window funnel each. Pattern says each edge = one home, so
# this is the definitive travel test. Cells passing all 3 windows -> holdout+MC.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$out = "D:\EA_LAB\_mt5_auto\COMMODITY_HUNT.csv"
'"ea","symbol","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.06.01";t="2023.01.01"},@{w="HOLDOUT";f="2023.01.01";t="2025.01.01"},@{w="FWD";f="2025.01.01";t="2026.07.01"})
$brkSet = "D:\EA_LAB\_mt5_auto\ab_sets\brkxau_sets\brk_BOTH.set"          # both-direction for non-gold
$zeuSet = "D:\EA_LAB\_mt5_auto\ab_sets\zigl_sets\ZIGL_XAU_atr1.set"        # ATR-self-scaling gold config
$eas = @(@{n="BRK";exp="BRKXAU";set=$brkSet},@{n="ZEUS";exp="(Boss)_ZeusInspired_GridLog_rev01";set=$zeuSet})
foreach($e in $eas){
  foreach($sym in 'XAGUSD','WTI','BRENT'){
    foreach($win in $wins){
      Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
      $rep = "COMM_$($e.n)_${sym}_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert $e.exp -Symbol $sym -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $e.set -ReportName $rep -TimeoutSec 300 | Out-Null
      $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "`"$($e.n)`",`"$sym`",`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "`"$($e.n)`",`"$sym`",`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
}
"COMMODITY DONE"; Get-Content $out
