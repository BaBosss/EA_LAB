<#
multisym_st03.ps1 — run ST03_optimized_v1.set across several 5-digit FX symbols, IS + held-out,
to find which symbols the optimized framework EA also has an edge on (= more runnable options).
Same proven pattern as robust_sweep: kill terminal before each run, delegate to mt5_run, parse
from reports/ with datadir fallback. Params are point-based (5-digit FX only — no JPY/XAU here).
#>
param(
  [string]$Set   = "D:\EA_LAB\_mt5_auto\ST03_optimized_v1.set",
  [string]$OutCsv= "D:\EA_LAB\_mt5_auto\sweeps\ST03_multisym.csv",
  [int]$Model = 2,
  [string[]]$Symbols = @("USDCAD","EURUSD","AUDUSD","NZDUSD","GBPUSD")
)
. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
$ErrorActionPreference="Stop"
$DataDir="C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"
$auto="D:\EA_LAB\_mt5_auto"
$wins=@(@{l='IS';f='2024.01.01';t='2024.03.01'},@{l='OOS';f='2024.09.01';t='2024.11.01'})
function Parse-Report($path){
  $raw=[IO.File]::ReadAllText($path,[Text.Encoding]::Unicode); $txt=($raw -replace '<[^>]+>',' ') -replace '&nbsp;',' '
  function G($lbl){ $m=[regex]::Match($txt,[regex]::Escape($lbl)+'\s*([-\d.,]+)'); if($m.Success){($m.Groups[1].Value -replace ',','')}else{''} }
  $mdd=[regex]::Match($txt,'Equity Drawdown Maximal:\s*([\d.,]+)\s*\(([\d.,]+)%\)')
  $win=[regex]::Match($txt,'Profit Trades \(% of total\):\s*(\d+)\s*\(([\d.,]+)%\)')
  [PSCustomObject]@{ PF=(G 'Profit Factor:'); Net=(G 'Total Net Profit:'); Trades=(G 'Total Trades:'); Sharpe=(G 'Sharpe Ratio:'); DDpct=$(if($mdd.Success){$mdd.Groups[2].Value}else{''}); Win=$(if($win.Success){$win.Groups[2].Value}else{''}) }
}
"symbol,window,model,PF,Net,Trades,DDpct,Win,Sharpe,Status" | Set-Content $OutCsv -Encoding ASCII
$total=$Symbols.Count*$wins.Count; $n=0
foreach($sym in $Symbols){ foreach($w in $wins){
  $n++; $rep="ST03MS_${sym}_$($w.l)"
  Write-Output "[$n/$total] $sym $($w.l)"
  Get-Process terminal64 -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
  $g=[Diagnostics.Stopwatch]::StartNew(); while((Get-Process terminal64 -EA SilentlyContinue) -and $g.Elapsed.TotalSeconds -lt 20){ Start-Sleep 2 }
  # ORDER-372: capture the exit code and the run's start time - "the .htm exists" does not mean THIS
  # run wrote it. mt5_run.ps1 clears a stale report only AFTER its abort checks, so an abort leaves
  # the previous run's file in place; the DataDir fallback below reads exactly the file that clear
  # is meant to remove, so it is gated too.
  $runStart = Get-Date
  & "$PSScriptRoot\mt5_run.ps1" -Expert "EA_RUNNER_ST03" -Symbol $sym -Period H1 -Model $Model `
      -FromDate $w.f -ToDate $w.t -SetFile $Set -ReportName $rep -Force 2>&1 | Out-Null
  $runnerExit = $LASTEXITCODE
  Start-Sleep 2
  $htm="$auto\reports\$rep.htm"; if(-not(Test-Path $htm)){ $htm="$DataDir\$rep.htm" }
  if(Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit $runnerExit -Label $rep){
    $r=Parse-Report $htm
    "$sym,$($w.l),$Model,$($r.PF),$($r.Net),$($r.Trades),$($r.DDpct),$($r.Win),$($r.Sharpe),OK" | Add-Content $OutCsv
    Write-Output "    -> PF=$($r.PF) t=$($r.Trades) DD%=$($r.DDpct)"
  } else { "$sym,$($w.l),$Model,,,,,,,NO_REPORT" | Add-Content $OutCsv; Write-Output "    -> NO REPORT" }
}}
Write-Output "DONE -> $OutCsv"
