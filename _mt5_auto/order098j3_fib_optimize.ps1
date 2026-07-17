<#
order098j3_fib_optimize.ps1 - FibPullback XAU H1 optimize probe (ORDER-098-J3).
Both-window MAIN(2023-26)+BWD(2020-22). Sweep fib pocket (FibLo/FibHi) x TpRR to satisfy the
VERDICT GATE (>=3 levers on right home) before writing DEAD. Naked H1 was 1.34/1.02 = below bar.
#>
$ErrorActionPreference="Stop"
$auto="D:\EA_LAB\_mt5_auto"; $setDir="$auto\ab_sets\order098j"; $repDir="$auto\reports"
$CsvPath="$auto\order098j3_fib_optimize.csv"
New-Item -ItemType Directory -Force -Path $setDir | Out-Null
. D:\EA_LAB\scripts\use_python.ps1
$pockets=@(
  @{tag="p3862"; lo="0.382"; hi="0.618"}  # default
  @{tag="p5062"; lo="0.5";   hi="0.618"}  # deeper pocket
  @{tag="p3850"; lo="0.382"; hi="0.5"}    # shallow pocket
  @{tag="p5079"; lo="0.5";   hi="0.786"}  # deep-to-deep
)
$rrs=@("1.5","2.5")
$configs=@()
foreach($p in $pockets){ foreach($rr in $rrs){
  $tag="$($p.tag)_rr$($rr -replace '\.','')"
  $setp="$setDir\fib_$tag.set"
  Set-Content -Path $setp -Value @("_02_FibLo=$($p.lo)","_02_FibHi=$($p.hi)","_04_TpRR=$rr") -Encoding ascii
  $configs+=@{tag=$tag; set=$setp}
}}
"tag,window,PF,trades,winpct,eqDDpct,netprofit,report" | Out-File -FilePath $CsvPath -Encoding utf8
foreach($c in $configs){
  foreach($w in @(@{win="MAIN";from="2023.01.01";to="2026.01.01"},@{win="BWD";from="2020.01.01";to="2022.12.31"})){
    $name="O098J3_$($c.tag)_$($w.win)"
    Write-Output "=== RUN: $name ==="
    $a=@("-File","D:\EA_LAB\scripts\mt5_run.ps1","-Expert","FibPullback_Naked","-Symbol","XAUUSD","-Period","H1","-Model","1","-FromDate",$w.from,"-ToDate",$w.to,"-ReportName",$name,"-SetFile",$c.set,"-TimeoutSec","900")
    $out=& powershell $a 2>&1 | Out-String; Write-Output $out
    $status=if($out -match "OK REPORT"){"OK"}else{"ERROR"}
    $rep="$repDir\$name.htm"; $PF="";$T="";$W="";$DD="";$NP=""
    if($status -eq "OK" -and (Test-Path $rep)){
      try{ $obj=(python D:\EA_LAB\scripts\parse_mt5_report.py $rep --json | Out-String)|ConvertFrom-Json
        $PF=$obj.profit_factor;$T=$obj.total_trades;$W=$obj.profit_trades_pct;$DD=$obj.equity_drawdown_relative_pct;$NP=$obj.net_profit
      }catch{Write-Output "PARSE ERR: $($_.Exception.Message)";$status="ERROR"}
    }
    $row='{0},{1},{2},{3},{4},{5},{6},{7}' -f $c.tag,$w.win,$PF,$T,$W,$DD,$NP,$rep
    Add-Content -Path $CsvPath -Value $row; Write-Output "ROW: $row [$status]"
  }
}
Write-Output "DONE."
