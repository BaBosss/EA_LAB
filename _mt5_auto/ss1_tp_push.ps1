<#
ss1_tp_push.ps1 — SS1 + trend filter: push the TpRR axis further.
MAIN is FLAT at 1.22 across TpRR 2.5/3.0/3.5 while BWD rises monotonically (1.05/1.07/1.13)
=> TP is not saturated. Test 4.0 / 5.0 on MAIN + BWD + HOLDOUT 2026H1.
Goal: lift holdout (1.17 at tp3.0) over the 1.2 deploy bar without giving up MAIN.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\ss1_holdout"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\SS1_TP_PUSH.csv"
function Wait-TermGone(){ $t=[Diagnostics.Stopwatch]::StartNew()
  while((Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq 'D:\Meta 5\terminal64.exe'}) -and $t.Elapsed.TotalSeconds -lt 45){ Start-Sleep -Seconds 2 } }
function Get-Stat([string]$htm){
  if(-not (Test-Path $htm)){ return @{PF=$null;Tr=$null;Net=$null} }
  $c=[IO.File]::ReadAllText($htm,[Text.Encoding]::Unicode); $pf=$null;$tr=$null;$net=$null
  if($c -match 'Profit Factor:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9.]+)'){ $pf=[double]$Matches[1] }
  if($c -match 'Total Trades:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9]+)'){ $tr=[int]$Matches[1] }
  if($c -match 'Total Net Profit:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(-?[0-9  .,]+)'){ $net=($Matches[1] -replace '[ ,]','') }
  return @{PF=$pf;Tr=$tr;Net=$net}
}
function RunChecked([string]$rm,[string]$from,[string]$to,[string]$set){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    & $run -Expert 'c091c\LondonORB_XAU' -Symbol XAUUSD -Period M15 -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 3; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"tprr,window,pf,trades,net" | Out-File $out -Encoding utf8
foreach($tp in @(4.0,5.0)){
  $tag=$tp -replace '\.','p'
  $set=Join-Path $setDir "push_tp$tag.set"
  @("_02_MinOrAtrH1=0.5","_02_MaxOrAtrH1=2.5","_03_TpRR=$tp","_04_LotSize=0.01",
    "_07_UseTrendFilter=true","_07_TrendEmaPeriod=200") | Out-File $set -Encoding ascii
  foreach($w in @(@('MAIN','2023.01.01','2025.12.31'), @('BWD','2020.01.01','2022.12.31'), @('HOLD','2026.01.01','2026.06.30'))){
    $rm="SS1P_tp${tag}_$($w[0])"
    RunChecked $rm $w[1] $w[2] $set
    $s=Get-Stat (Join-Path $repDir "$rm.htm")
    "$tp,$($w[0]),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
    Write-Host "tp$tp $($w[0]) -> PF $($s.PF) / $($s.Tr)"
  }
}
Write-Host "=== DONE $out ==="
