# ORDER-053b — can the martingale-recovery breakout be made profitable? Sweep the
# signal (confluence vs Donchian-only), pullback on/off, MartMult, XAUUSD both regimes.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\cmart_sets"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\CMART_OPT.csv"
'"tl","pb","mart","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"}, @{w="FWD";f="2025.01.01";t="2026.07.01"})
foreach($tl in 'true','false'){
 foreach($pb in 'true','false'){
  foreach($mm in 1.3,1.6){
    $set = "$setdir\cm_tl${tl}_pb${pb}_mm$mm.set"
    @("_01_UseTrendlineToo=$tl","_01_UsePullback=$pb","_03_MartMult=$mm") -join "`r`n" | Out-File $set -Encoding ascii
    foreach($win in $wins){
      Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
      $rep = "CMOPT_${tl}_${pb}_${mm}_$($win.w)"
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "CMART" -Symbol XAUUSD -Period H1 -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
      $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
      if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
        $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
        $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
        $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
        "`"$tl`",`"$pb`",$mm,`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
      else { "`"$tl`",`"$pb`",$mm,`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
    }
  }
 }
}
"CMART OPT DONE"; Get-Content $out
