<#
ss1_holdout_fan.ps1 — SS1 LondonORB + trend filter: HOLDOUT + finish the sensitivity fan.
Locked plateau-center = TrendEma200 / MinOr0.5 / TpRR3 (central cell, better BWD than the ema100 peak;
plateau-center doctrine, not peak-picking). Alternative center ema100 also holdout-tested.
Holdout window = 2026H1 (first use for THIS EA; note the window is already partially burned at cohort
level by TrendRider). Fan axis remaining = TpRR (2.5 / 3.5) on both windows.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\ss1_holdout"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\SS1_HOLDOUT_FAN.csv"
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
    Start-Sleep -Seconds 3; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
function MakeSet([string]$path,[int]$ema,[double]$mo,[double]$tp){
  @("_02_MinOrAtrH1=$mo","_02_MaxOrAtrH1=2.5","_03_TpRR=$tp","_04_LotSize=0.01",
    "_07_UseTrendFilter=true","_07_TrendEmaPeriod=$ema") | Out-File $path -Encoding ascii
}

"test,ema,minor,tprr,window,pf,trades,net" | Out-File $out -Encoding utf8

# ---- HOLDOUT 2026H1 on both candidate centers ----
foreach($ema in @(200,100)){
  $set=Join-Path $setDir "hold_ema$ema.set"; MakeSet $set $ema 0.5 3.0
  $rm="SS1H_ema${ema}_HOLD"
  RunChecked $rm '2026.01.01' '2026.06.30' $set
  $s=Get-Stat (Join-Path $repDir "$rm.htm")
  "holdout,$ema,0.5,3.0,2026H1,$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
  Write-Host "HOLDOUT ema$ema -> PF $($s.PF) / $($s.Tr) trades / net $($s.Net)"
}

# ---- FAN: TpRR axis on the locked center (ema200/mo0.5), both windows ----
foreach($tp in @(2.5,3.5)){
  $set=Join-Path $setDir "fan_tp$($tp -replace '\.','p').set"; MakeSet $set 200 0.5 $tp
  foreach($w in @(@('MAIN','2023.01.01','2025.12.31'), @('BWD','2020.01.01','2022.12.31'))){
    $rm="SS1F_tp$($tp -replace '\.','p')_$($w[0])"
    RunChecked $rm $w[1] $w[2] $set
    $s=Get-Stat (Join-Path $repDir "$rm.htm")
    "fan,200,0.5,$tp,$($w[0]),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
    Write-Host "FAN tp$tp $($w[0]) -> PF $($s.PF) / $($s.Tr)"
  }
}
Write-Host "=== DONE $out ==="
Write-Host "BAR: holdout PF >= 1.2 => deploy track · 1.0-1.2 => BUILD-ON · <1.0 => selection-fit"