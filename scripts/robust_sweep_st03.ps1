<#
robust_sweep_st03.ps1 — reliable serial grid sweep for EA_RUNNER_ST03 exit/scaling params.
Works around the grid_sweep terminal-close race: guarantees a clean terminal each run and
parses the report straight from the MT5 DATA folder (the location it reliably lands), instead
of relying on mt5_run's move step which raced under back-to-back invocation.
#>
param(
  [string]$Base   = "D:\EA_LAB\_mt5_auto\ST03_edge.set",
  [string]$OutCsv = "D:\EA_LAB\_mt5_auto\sweeps\ST03_exit_opt.csv",
  [int]$Model = 4
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"
$Terminal = "D:\Meta 5\terminal64.exe"
$auto = "D:\EA_LAB\_mt5_auto"

# exit/scaling grid
$tp3s  = 30,50,80,120        # OCO group-close threshold (points; 3/5/8/12 pip)
$nears = 50,100,150          # pyramid leg spacing (points; 5/10/15 pip)
$wins  = @(
  @{l='IS' ; f='2024.01.01'; t='2024.03.01'},
  @{l='OOS'; f='2024.09.01'; t='2024.11.01'}
)

# read base set (skip comments/blank). NOTE: PowerShell vars are case-insensitive, so this
# map MUST NOT be named $base (would clobber the $Base param path).
$baseMap = [ordered]@{}
foreach($l in Get-Content $Base){ $t=$l.Trim(); if($t -and -not $t.StartsWith(";") -and $t.Contains("=")){ $k,$v=$t.Split("=",2); $baseMap[$k.Trim()]=$v.Trim() } }

function Wait-TerminalGone($maxSec){ $sw=[Diagnostics.Stopwatch]::StartNew(); while((Get-Process terminal64 -EA SilentlyContinue) -and $sw.Elapsed.TotalSeconds -lt $maxSec){ Start-Sleep 2 } }
function Parse-Report($path){
  $raw=[IO.File]::ReadAllText($path,[Text.Encoding]::Unicode); $txt=($raw -replace '<[^>]+>',' ') -replace '&nbsp;',' '
  function G($lbl){ $m=[regex]::Match($txt,[regex]::Escape($lbl)+'\s*([-\d.,]+)'); if($m.Success){ ($m.Groups[1].Value -replace ',','') } else { '' } }
  $mdd=[regex]::Match($txt,'Equity Drawdown Maximal:\s*([\d.,]+)\s*\(([\d.,]+)%\)')
  $win=[regex]::Match($txt,'Profit Trades \(% of total\):\s*(\d+)\s*\(([\d.,]+)%\)')
  [PSCustomObject]@{ PF=(G 'Profit Factor:'); Net=(G 'Total Net Profit:'); Trades=(G 'Total Trades:'); Sharpe=(G 'Sharpe Ratio:'); DDpct=$(if($mdd.Success){$mdd.Groups[2].Value}else{''}); Win=$(if($win.Success){$win.Groups[2].Value}else{''}) }
}

"tp3,near,window,PF,Net,Trades,DDpct,Win,Sharpe,Status" | Set-Content $OutCsv -Encoding ASCII
$total = $tp3s.Count * $nears.Count * $wins.Count; $n=0
foreach($tp in $tp3s){ foreach($nr in $nears){
  # build per-combo set
  $set=[ordered]@{}; foreach($k in $baseMap.Keys){ $set[$k]=$baseMap[$k] }; $set['InpTp3Pts']=$tp; $set['InpNearbyPip']=$nr
  $setPath="$auto\sweeps\_sets\ST03X_${tp}_${nr}.set"
  $lines=@("; ST03X tp3=$tp near=$nr"); foreach($k in $set.Keys){ $lines+="$k=$($set[$k])" }; [IO.File]::WriteAllLines($setPath,$lines)
  foreach($w in $wins){
    $n++; $rep="ST03X_${tp}_${nr}_$($w.l)"
    Write-Output "[$n/$total] tp3=$tp near=$nr $($w.l)"
    # clean slate: kill any lingering terminal so mt5_run's GUI-guard passes (we use -Force anyway)
    Get-Process terminal64 -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue; Wait-TerminalGone 20
    # delegate to mt5_run (proven: launches, waits for the report FILE, moves it to reports/).
    # ORDER-372: report existence != this run produced it (mt5_run.ps1 clears a stale report only
    # AFTER its abort checks). Gate on the exit code and on the file being newer than this run.
    $runStart = Get-Date
    & "$PSScriptRoot\mt5_run.ps1" -Expert "EA_RUNNER_ST03" -Symbol GBPUSD -Period H1 -Model $Model `
        -FromDate $w.f -ToDate $w.t -SetFile $setPath -ReportName $rep -Force 2>&1 | Out-Null
    $runnerExit = $LASTEXITCODE
    Start-Sleep 2
    $htm="$auto\reports\$rep.htm"; if(-not (Test-Path $htm)){ $htm="$DataDir\$rep.htm" }
    if(Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit $runnerExit -Label $rep){
      $r=Parse-Report $htm
      "$tp,$nr,$($w.l),$($r.PF),$($r.Net),$($r.Trades),$($r.DDpct),$($r.Win),$($r.Sharpe),OK" | Add-Content $OutCsv
      Write-Output "    -> PF=$($r.PF) t=$($r.Trades) DD%=$($r.DDpct)"
    } else {
      "$tp,$nr,$($w.l),,,,,,,NO_REPORT" | Add-Content $OutCsv
      Write-Output "    -> NO REPORT"
    }
  }
}}
Write-Output "DONE -> $OutCsv"
