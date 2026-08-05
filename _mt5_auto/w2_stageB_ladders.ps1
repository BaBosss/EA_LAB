<#
w2_stageB_ladders.ps1 — Wave-2 Stage B both-window optimize ladders.
S1 TrendRider H4: AdxMin{20,25,30} x SepAtrMult{0.3,0.5,0.8} x ChAtrMult{2.0,2.5,3.0} = 27 cells.
SS4 SweepRev M15: AdxMax{22,28,35} x SweepAtrMult{0.3,0.5} x TpAtrMult{1.2,1.8,2.5} = 18 cells.
Each cell MAIN 2023-2025 + BWD 2020-2022, Model 1. CANDIDATE bar = MAIN>=1.2 AND BWD>=1.0.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"

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
function RunChecked([string]$expert,[string]$per,[string]$from,[string]$to,[string]$set,[string]$rm){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 2;$try++){ Wait-TermGone
    & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 1200 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}

# ---------- S1 TrendRider H4 ----------
$setDir="D:\EA_LAB\_mt5_auto\ab_sets\w2_s1"; New-Item -ItemType Directory -Force $setDir | Out-Null
$out1="D:\EA_LAB\_mt5_auto\W2_S1_LADDER.csv"
"adxmin,sepatr,chatr,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $out1 -Encoding utf8
foreach($adx in @(20,25,30)){ foreach($sep in @(0.3,0.5,0.8)){ foreach($ch in @(2.0,2.5,3.0)){
  $tag="a${adx}_s$($sep -replace '\.','p')_c$($ch -replace '\.','p')"
  $set=Join-Path $setDir "$tag.set"
  @("_01_AdxMin=$adx","_01_SepAtrMult=$sep","_02_ChAtrMult=$ch") | Out-File $set -Encoding ascii
  RunChecked 'c091c\TrendRider_XAU' 'H4' '2023.01.01' '2025.12.31' $set "W2B_S1_${tag}_MAIN"
  RunChecked 'c091c\TrendRider_XAU' 'H4' '2020.01.01' '2022.12.31' $set "W2B_S1_${tag}_BWD"
  $m=Get-Stat (Join-Path $repDir "W2B_S1_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "W2B_S1_${tag}_BWD.htm")
  $cand= if($m.PF -ne $null -and $b.PF -ne $null -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
  "$adx,$sep,$ch,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out1 -Append -Encoding utf8
  Write-Host "S1 $tag -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)  [$cand]"
}}}
Write-Host "=== S1 ladder done ==="

# ---------- SS4 SweepRev M15 ----------
$setDir2="D:\EA_LAB\_mt5_auto\ab_sets\w2_ss4"; New-Item -ItemType Directory -Force $setDir2 | Out-Null
$out2="D:\EA_LAB\_mt5_auto\W2_SS4_LADDER.csv"
"adxmax,sweepatr,tpatr,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $out2 -Encoding utf8
foreach($adx in @(22,28,35)){ foreach($sw in @(0.3,0.5)){ foreach($tp in @(1.2,1.8,2.5)){
  $tag="a${adx}_w$($sw -replace '\.','p')_t$($tp -replace '\.','p')"
  $set=Join-Path $setDir2 "$tag.set"
  @("_02_AdxMax=$adx","_01_SweepAtrMult=$sw","_03_TpAtrMult=$tp") | Out-File $set -Encoding ascii
  RunChecked 'c091c\SweepReversal_XAU' 'M15' '2023.01.01' '2025.12.31' $set "W2B_SS4_${tag}_MAIN"
  RunChecked 'c091c\SweepReversal_XAU' 'M15' '2020.01.01' '2022.12.31' $set "W2B_SS4_${tag}_BWD"
  $m=Get-Stat (Join-Path $repDir "W2B_SS4_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "W2B_SS4_${tag}_BWD.htm")
  $cand= if($m.PF -ne $null -and $b.PF -ne $null -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
  "$adx,$sw,$tp,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out2 -Append -Encoding utf8
  Write-Host "SS4 $tag -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)  [$cand]"
}}}
Write-Host "=== DONE both ladders ==="
