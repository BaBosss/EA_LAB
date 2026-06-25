<#
gridsweep_robust.ps1 — generic cartesian param sweep for ST03 (or any EA), reliable.
Replaces grid_sweep.ps1 (which raced on back-to-back mt5_run -> all NO_REPORT). This one
force-kills terminal64 before each run, delegates to mt5_run (-Force), and parses the report
from reports\ with a datadir fallback. Captures equity-DD (floating-inclusive).

  -Overrides "InpStopLossPoints=0,100,200;InpHoldBars=40,80"   (cartesian)
  -Windows   "IS:2024.01.01:2024.03.01;CRISIS:2022.08.01:2022.11.01"
#>
param(
  [Parameter(Mandatory)][string]$BaseSet,
  [Parameter(Mandatory)][string]$Overrides,
  [Parameter(Mandatory)][string]$Windows,
  [Parameter(Mandatory)][string]$OutCsv,
  [Parameter(Mandatory)][string]$Prefix,
  [string]$Expert="EA_RUNNER_ST03",
  [string]$Symbol="GBPUSD",
  [int]$Model=2
)
$ErrorActionPreference="Stop"
$DataDir="C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"
$auto="D:\EA_LAB\_mt5_auto"
New-Item -ItemType Directory -Force "$auto\sweeps\_sets" | Out-Null
# base map (NOT $base — case-insensitive clobber of param)
$bmap=[ordered]@{}
foreach($l in Get-Content $BaseSet){ $t=$l.Trim(); if($t -and -not $t.StartsWith(";") -and $t.Contains("=")){ $k,$v=$t.Split("=",2); $bmap[$k.Trim()]=$v.Trim() } }
# cartesian
$dims=@(); foreach($p in $Overrides.Split(";")){ if(-not $p.Contains("=")){continue}; $k,$vs=$p.Split("=",2); $dims+=,@{K=$k.Trim();V=@($vs.Split(",")|ForEach-Object{$_.Trim()})} }
$combos=@(@{}); foreach($d in $dims){ $nx=@(); foreach($c in $combos){ foreach($v in $d.V){ $cc=@{}; foreach($kk in $c.Keys){$cc[$kk]=$c[$kk]}; $cc[$d.K]=$v; $nx+=$cc } }; $combos=$nx }
$wins=@(); foreach($w in $Windows.Split(";")){ $l,$f,$t=$w.Split(":",3); $wins+=@{l=$l;f=$f;t=$t} }
function Parse($path){ $raw=[IO.File]::ReadAllText($path,[Text.Encoding]::Unicode); $txt=($raw -replace '<[^>]+>',' ') -replace '&nbsp;',' '
  function G($x){ $m=[regex]::Match($txt,[regex]::Escape($x)+'\s*([-\d.,]+)'); if($m.Success){($m.Groups[1].Value -replace ',','')}else{''} }
  $e=[regex]::Match($txt,'Equity Drawdown Maximal:\s*([\d.,]+)\s*\(([\d.,]+)%\)'); $w=[regex]::Match($txt,'Profit Trades \(% of total\):\s*(\d+)\s*\(([\d.,]+)%\)')
  [PSCustomObject]@{PF=(G 'Profit Factor:');Net=(G 'Total Net Profit:');Trades=(G 'Total Trades:');Sharpe=(G 'Sharpe Ratio:');DDpct=$(if($e.Success){$e.Groups[2].Value}else{''});Win=$(if($w.Success){$w.Groups[2].Value}else{''})} }
"combo,params,window,PF,Net,Trades,EqDDpct,Win,Sharpe,Status" | Set-Content $OutCsv -Encoding ASCII
$total=$combos.Count*$wins.Count; $n=0
for($ci=0;$ci -lt $combos.Count;$ci++){ $combo=$combos[$ci]
  $set=[ordered]@{}; foreach($k in $bmap.Keys){$set[$k]=$bmap[$k]}; $tag=@(); foreach($k in $combo.Keys){$set[$k]=$combo[$k]; $tag+=($k -replace '^Inp','')+$combo[$k]}
  $tagS=($tag -join "_") -replace '[^A-Za-z0-9._]',''
  $sp="$auto\sweeps\_sets\${Prefix}_c$ci.set"; $sl=@("; $Prefix c$ci $tagS"); foreach($k in $set.Keys){$sl+="$k=$($set[$k])"}; [IO.File]::WriteAllLines($sp,$sl)
  foreach($w in $wins){ $n++; $rep="${Prefix}_c${ci}_$($w.l)"
    Write-Output "[$n/$total] c$ci $tagS $($w.l)"
    Get-Process terminal64 -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    $g=[Diagnostics.Stopwatch]::StartNew(); while((Get-Process terminal64 -EA SilentlyContinue) -and $g.Elapsed.TotalSeconds -lt 20){Start-Sleep 2}
    & "$PSScriptRoot\mt5_run.ps1" -Expert $Expert -Symbol $Symbol -Period H1 -Model $Model -FromDate $w.f -ToDate $w.t -SetFile $sp -ReportName $rep -Force 2>&1 | Out-Null
    Start-Sleep 2
    $htm="$auto\reports\$rep.htm"; if(-not(Test-Path $htm)){$htm="$DataDir\$rep.htm"}
    if(Test-Path $htm){ $r=Parse $htm; "$ci,$tagS,$($w.l),$($r.PF),$($r.Net),$($r.Trades),$($r.DDpct),$($r.Win),$($r.Sharpe),OK"|Add-Content $OutCsv; Write-Output "    -> PF=$($r.PF) t=$($r.Trades) eqDD%=$($r.DDpct)" }
    else { "$ci,$tagS,$($w.l),,,,,,,NO_REPORT"|Add-Content $OutCsv; Write-Output "    -> NO REPORT" }
  }
}
Write-Output "DONE -> $OutCsv"
