# ORDER-053c — CMART recovery lot-law + ATR-distance COARSE sweep (user: try linear/fix/log
# + optimize ATR distance, full procedure coarse->fine). Base = confluence + no-pullback (the
# gate that made entries clean). Skip martingale (holdout-proven overfit). Both regimes.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\cmart_ll"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\CMART_LOTLAW.csv"
'"mode","atr","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})
# mode: 0=FIXED 1=LINEAR 3=LOG
foreach($m in @(@{n="FIXED";v=0},@{n="LINEAR";v=1},@{n="LOG";v=3})){
  foreach($atr in 1.0,1.5,2.5,4.0){
    $set = "$setdir\cm_$($m.n)_atr$atr.set"
    @("_01_UseTrendlineToo=true","_01_UsePullback=false","_03_LotMode=$($m.v)","_03_AddAtrMult=$atr") -join "`r`n" | Out-File $set -Encoding ascii
    foreach($win in $wins){
      Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
      $rep = "CMLL_$($m.n)_${atr}_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "CMART" -Symbol XAUUSD -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
      $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "`"$($m.n)`",$atr,`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "`"$($m.n)`",$atr,`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
}
"CMART LOTLAW DONE"; Get-Content $out
