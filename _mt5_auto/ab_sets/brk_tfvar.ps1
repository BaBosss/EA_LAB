# BRK-XAU TF-configurable variant: test the breakout on M15/M30/H4/H1 (chart TF = signal TF).
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1
$setdir = "D:\EA_LAB\_mt5_auto\ab_sets\brktf_sets"; New-Item -ItemType Directory -Force $setdir | Out-Null
$out = "D:\EA_LAB\_mt5_auto\BRK_TFVAR.csv"
'"tf","window","pf","dd_pct","trades"' | Out-File $out -Encoding utf8
$wins = @(@{w="BWD";f="2020.01.01";t="2023.01.01"},@{w="HOLDOUT";f="2023.01.01";t="2025.01.01"},@{w="FWD";f="2025.01.01";t="2026.07.01"})
# tf name -> ENUM_TIMEFRAMES value
$tfs = @(@{n="M15";v=15},@{n="M30";v=30},@{n="H4";v=16388})
foreach($tf in $tfs){
  $set = "$setdir\brk_tf$($tf.n).set"; @("_05_BuyOnly=true","_08_SigTF=$($tf.v)") -join "`r`n" | Out-File $set -Encoding ascii
  foreach($win in $wins){
    Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq 'D:\Meta 5\terminal64.exe' } | Stop-Process -Force -Confirm:$false; Start-Sleep 2
    $rep = "BRKTFV_$($tf.n)_$($win.w)"
    & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "BRKTFVAR" -Symbol XAUUSD -Period $($tf.n) -FromDate $win.f -ToDate $win.t -Model 4 -SetFile $set -ReportName $rep | Out-Null
    $htm = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
    if(Test-Path $htm){ $j = python D:\EA_LAB\scripts\parse_mt5_report.py $htm
      $pf=($j|Select-String 'profit_factor:\s*(.+)').Matches.Groups[1].Value.Trim()
      $dd=($j|Select-String 'equity_drawdown_maximal_pct:\s*(.+)').Matches.Groups[1].Value.Trim()
      $trd=($j|Select-String 'total_trades:\s*(.+)').Matches.Groups[1].Value.Trim()
      "`"$($tf.n)`",`"$($win.w)`",$pf,$dd,$trd"|Add-Content $out }
    else { "`"$($tf.n)`",`"$($win.w)`",,,NO_REPORT"|Add-Content $out }
  }
}
"BRK TFVAR DONE"; Get-Content $out
