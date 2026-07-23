<#
ss1_lever_sweep.ps1 — SS1 LondonORB (992003) BUILD-ON levers, unblocking ORDER-143 (was N/A:
the EA had no partial-TP / trend-filter inputs; added 2026-07-23, both default OFF).
Vehicle: plateau center MinOr=0.5 / TpRR=3 on XAU M15 (the home that produced MAIN 1.17 / BWD 1.07 @ n~730).

Configs (NO stacking in round 1, per ORDER-143 discipline):
  base_off    levers off, lot 0.01   -> REGRESSION: must reproduce MAIN ~1.17/732t, BWD ~1.07/717t
  trend_on    UseTrendFilter=true (EMA200 direction-align; OCO becomes one-sided)
  lot02_ctrl  lot 0.02, partial off  -> PF-invariance control (PF must equal base_off)
  part30      lot 0.02, PartialPct=30 @ +1R then SL->BE
  part50      lot 0.02, PartialPct=50 @ +1R then SL->BE
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\ss1_levers"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\SS1_LEVERS_BOTHWINDOW.csv"
New-Item -ItemType Directory -Force $setDir | Out-Null

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
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}

# name -> extra .set lines (plateau center always pinned)
$cfg = [ordered]@{
  base_off   = @("_04_LotSize=0.01")
  trend_on   = @("_04_LotSize=0.01","_07_UseTrendFilter=true","_07_TrendEmaPeriod=200")
  lot02_ctrl = @("_04_LotSize=0.02")
  part30     = @("_04_LotSize=0.02","_07_PartialPct=30","_07_PartialAtR=1.0")
  part50     = @("_04_LotSize=0.02","_07_PartialPct=50","_07_PartialAtR=1.0")
}

"config,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net" | Out-File $out -Encoding utf8
foreach($k in $cfg.Keys){
  $set=Join-Path $setDir "$k.set"
  (@("_02_MinOrAtrH1=0.5","_02_MaxOrAtrH1=2.5","_03_TpRR=3.0") + $cfg[$k]) | Out-File $set -Encoding ascii
  RunChecked "SS1L_${k}_MAIN" '2023.01.01' '2025.12.31' $set
  RunChecked "SS1L_${k}_BWD"  '2020.01.01' '2022.12.31' $set
  $m=Get-Stat (Join-Path $repDir "SS1L_${k}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "SS1L_${k}_BWD.htm")
  "$k,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net)" | Out-File $out -Append -Encoding utf8
  Write-Host "$k -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)"
}
Write-Host "=== DONE $out ==="
Write-Host "REGRESSION CHECK: base_off must be ~1.17/732 (MAIN) and ~1.07/717 (BWD)"