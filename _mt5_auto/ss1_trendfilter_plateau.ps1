<#
ss1_trendfilter_plateau.ps1 — SS1 LondonORB trend-filter PLATEAU confirmation.
Single cell (EMA200 @ MinOr0.5/TpRR3) hit MAIN 1.22 / BWD 1.07 = clears the CANDIDATE bar,
but one cell is a spike until proven a plateau. Vary the new lever axis (TrendEmaPeriod)
against the existing selection axis (MinOrAtrH1). If the region holds MAIN>=1.2 AND BWD>=1.0
broadly -> CANDIDATE; if only the one cell holds -> spike, stays BUILD-ON.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\ss1_tfplateau"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\SS1_TRENDFILTER_PLATEAU.csv"
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

"ema,minor,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $out -Encoding utf8
foreach($ema in @(100,200,300)){
  foreach($mo in @(0.5,0.8)){
    $tag="ema${ema}_mo$($mo -replace '\.','p')"
    $set=Join-Path $setDir "$tag.set"
    @("_02_MinOrAtrH1=$mo","_02_MaxOrAtrH1=2.5","_03_TpRR=3.0","_04_LotSize=0.01",
      "_07_UseTrendFilter=true","_07_TrendEmaPeriod=$ema") | Out-File $set -Encoding ascii
    RunChecked "SS1TF_${tag}_MAIN" '2023.01.01' '2025.12.31' $set
    RunChecked "SS1TF_${tag}_BWD"  '2020.01.01' '2022.12.31' $set
    $m=Get-Stat (Join-Path $repDir "SS1TF_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "SS1TF_${tag}_BWD.htm")
    $cand= if($m.PF -and $b.PF -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
    "$ema,$mo,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out -Append -Encoding utf8
    Write-Host "ema$ema mo$mo -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)  [$cand]"
  }
}
Write-Host "=== DONE $out ==="