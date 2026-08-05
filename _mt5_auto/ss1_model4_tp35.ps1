<#
ss1_model4_tp35.ps1 — SS1 Model-4 (real ticks) at the CORRECTED plateau center.
Center = TrendEma200 / MinOr0.5 / TpRR3.5, chosen on MAIN+BWD evidence ONLY
(MAIN 1.22 tied-best, BWD 1.13 best) so the 2026H1 holdout stays an independent test.
The earlier tp4.0 lock was contaminated: it used the holdout to help pick the center.
BAR (gate): Model-4 both-window PF >= 1.0 retained AND largest loss does not explode.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\ss1_holdout"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\SS1_MODEL4_TP35.csv"

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
function RunChecked([string]$rm,[string]$from,[string]$to,[string]$set){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 2;$try++){ Wait-TermGone
    & $run -Expert 'c091c\LondonORB_XAU' -Symbol XAUUSD -Period M15 -FromDate $from -ToDate $to -Model 4 -SetFile $set -ReportName $rm -TimeoutSec 3000 | Out-Null
    Start-Sleep -Seconds 3; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}

$set=Join-Path $setDir "m4_tp3p5.set"
@("_02_MinOrAtrH1=0.5","_02_MaxOrAtrH1=2.5","_03_TpRR=3.5","_04_LotSize=0.01",
  "_07_UseTrendFilter=true","_07_TrendEmaPeriod=200") | Out-File $set -Encoding ascii

"test,tprr,model,window,pf,trades,net,largest_loss" | Out-File $out -Encoding utf8
foreach($w in @(@('MAIN','2023.01.01','2025.12.31'), @('BWD','2020.01.01','2022.12.31'), @('HOLD','2026.01.01','2026.06.30'))){
  $rm="SS1M4_tp3p5_$($w[0])"
  Write-Host "starting Model-4 $($w[0]) (real ticks - slow)..."
  RunChecked $rm $w[1] $w[2] $set
  $s=Get-Stat (Join-Path $repDir "$rm.htm")
  "model4,3.5,4,$($w[0]),$($s.PF),$($s.Tr),$($s.Net),$($s.WL)" | Out-File $out -Append -Encoding utf8
  Write-Host "M4 $($w[0]) -> PF $($s.PF) / $($s.Tr) / largest-loss $($s.WL)"
}
Write-Host "=== DONE $out ==="