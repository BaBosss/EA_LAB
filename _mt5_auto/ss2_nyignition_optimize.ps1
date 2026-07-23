<#
ss2_nyignition_optimize.ps1 — SS2 NyIgnition (992005) both-window optimize ladder.
Diagnosis: naked smoke 1.02 @ n=639 (~213 trades/yr = fires nearly EVERY session) ->
the BodyAtrMult=0.7 impulse filter is not selective. Primary lever = impulse strength,
secondary = TP (tp3>tp2 helped SS1 ORB).
Levers: BodyAtrMult {0.7,1.0,1.4} x TpAtrMult {2.0,3.0}. Both-window.
CANDIDATE = MAIN>=1.2 AND BWD>=1.0 at appropriate n (judged by hand, not just the flag).
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\ss2_nyig"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\SS2_NYIG_BOTHWINDOW.csv"
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
    & $run -Expert 'c091c\NyIgnition_XAU' -Symbol XAUUSD -Period M15 -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}

"body,tp,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $out -Encoding utf8
foreach($bd in @(0.7,1.0,1.4)){
  foreach($tp in @(2.0,3.0)){
    $tag="bd$($bd -replace '\.','p')_tp$($tp -replace '\.','p')"
    $set=Join-Path $setDir "$tag.set"
    @("_01_BodyAtrMult=$bd","_02_TpAtrMult=$tp") | Out-File $set -Encoding ascii
    RunChecked "SS2_${tag}_MAIN" '2023.01.01' '2025.12.31' $set
    RunChecked "SS2_${tag}_BWD"  '2020.01.01' '2022.12.31' $set
    $m=Get-Stat (Join-Path $repDir "SS2_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "SS2_${tag}_BWD.htm")
    $cand= if($m.PF -and $b.PF -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
    "$bd,$tp,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out -Append -Encoding utf8
    Write-Host "SS2 body$bd tp$tp -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)  [$cand]"
  }
}
Write-Host "=== DONE $out ==="