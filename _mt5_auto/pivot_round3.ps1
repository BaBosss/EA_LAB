<#
pivot_round3.ps1 — PivotBreakout H4: fan around sl1.5/tp3.0 (TpRR{2.5,3.5}) both-window to
confirm plateau, then Model-4 (real ticks) on the locked center since it's a breakout entry.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\gappivot"
$out   = "D:\EA_LAB\_mt5_auto\PIVOT_ROUND3.csv"

function Wait-TermGone(){ $t=[Diagnostics.Stopwatch]::StartNew()
  while((Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq 'D:\Meta 5\terminal64.exe'}) -and $t.Elapsed.TotalSeconds -lt 60){ Start-Sleep -Seconds 3 } }
function Get-Stat([string]$htm){
  if(-not (Test-Path $htm)){ return @{PF=$null;Tr=$null;Net=$null;WL=$null} }
  $c=[IO.File]::ReadAllText($htm,[Text.Encoding]::Unicode); $pf=$null;$tr=$null;$net=$null;$wl=$null
  if($c -match 'Profit Factor:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9.]+)'){ $pf=[double]$Matches[1] }
  if($c -match 'Total Trades:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9]+)'){ $tr=[int]$Matches[1] }
  if($c -match 'Total Net Profit:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(-?[0-9  .,]+)'){ $net=($Matches[1] -replace '[ ,]','') }
  if($c -match 'Largest loss trade:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(-?[0-9  .,]+)'){ $wl=($Matches[1] -replace '[ ,]','') }
  return @{PF=$pf;Tr=$tr;Net=$net;WL=$wl}
}
function RunChecked([string]$rm,[string]$from,[string]$to,[string]$set,[int]$model,[int]$tmo){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 2;$try++){ Wait-TermGone
    & $run -Expert 'c091c\PivotBreakout_XAU' -Symbol XAUUSD -Period H4 -FromDate $from -ToDate $to -Model $model -SetFile $set -ReportName $rm -TimeoutSec $tmo | Out-Null
    Start-Sleep -Seconds 3; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"test,cellname,model,window,pf,trades,net,largest_loss" | Out-File $out -Encoding utf8

# fan
foreach($tp in @(2.5,3.5)){
  $tag="sl1p5_tp$($tp -replace '\.','p')"; $set=Join-Path $setDir "C_$tag.set"
  @("_02_SlAtrMult=1.5","_02_TpRR=$tp") | Out-File $set -Encoding ascii
  foreach($w in @(@('MAIN','2023.01.01','2025.12.31'),@('BWD','2020.01.01','2022.12.31'))){
    $rm="PVC_${tag}_$($w[0])"
    RunChecked $rm $w[1] $w[2] $set 1 900
    $s=Get-Stat (Join-Path $repDir "$rm.htm")
    "fan,$tag,1,$($w[0]),$($s.PF),$($s.Tr),$($s.Net),$($s.WL)" | Out-File $out -Append -Encoding utf8
    Write-Host "fan $tag $($w[0]) -> PF $($s.PF)/$($s.Tr)"
  }
}

# Model-4 at locked center sl1.5/tp3.0
$setM4=Join-Path $setDir "D_locked_sl1p5_tp3.set"
@("_02_SlAtrMult=1.5","_02_TpRR=3.0") | Out-File $setM4 -Encoding ascii
foreach($w in @(@('MAIN','2023.01.01','2025.12.31'),@('BWD','2020.01.01','2022.12.31'),@('HOLD','2026.01.01','2026.06.30'))){
  $rm="PVM4_$($w[0])"
  Write-Host "starting Model-4 $($w[0]) (real ticks - slow)..."
  RunChecked $rm $w[1] $w[2] $setM4 4 3000
  $s=Get-Stat (Join-Path $repDir "$rm.htm")
  "model4,sl1p5_tp3,4,$($w[0]),$($s.PF),$($s.Tr),$($s.Net),$($s.WL)" | Out-File $out -Append -Encoding utf8
  Write-Host "M4 $($w[0]) -> PF $($s.PF)/$($s.Tr) / largest-loss $($s.WL)"
}
Write-Host "=== DONE $out ==="
