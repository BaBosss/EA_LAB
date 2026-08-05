<#
wave1_finish_optimize.ps1 — S5 TpRR last-optimize (healthy n) + SS1 both-window optimize.
Robust: kills leftover D:\Meta 5 terminal64 first, retries a run if report missing.
CANDIDATE = MAIN>=1.2 AND BWD>=1.0 at APPROPRIATE n (judged by hand, not just flag).
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
function RunChecked([string]$expert,[string]$sym,[string]$per,[string]$rm,[string]$from,[string]$to,[string]$set){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){
    Wait-TermGone
    & $run -Expert $expert -Symbol $sym -Period $per -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2
    if(Test-Path $htm){ return }
    Write-Host "  retry $rm (attempt $try no report)"
  }
}

# ---- S5 TpRR last-optimize at healthy n (mr0.30, both directions) ----
$s5set="D:\EA_LAB\_mt5_auto\ab_sets\s5_asian"; New-Item -ItemType Directory -Force $s5set|Out-Null
$s5out="D:\EA_LAB\_mt5_auto\S5_TPRR_LASTOPT.csv"
"tprr,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $s5out -Encoding utf8
foreach($tp in @(1.5,2.5,4.0)){
  $tag="mr0p30_tp$($tp -replace '\.','p')"; $set=Join-Path $s5set "$tag.set"
  @("_02_MaxRangeAtrD1=0.30","_03_TpRR=$tp") | Out-File $set -Encoding ascii
  RunChecked 'c091c\AsianRange_XAU' 'XAUUSD' 'M30' "S5TP_${tag}_MAIN" '2023.01.01' '2025.12.31' $set
  RunChecked 'c091c\AsianRange_XAU' 'XAUUSD' 'M30' "S5TP_${tag}_BWD"  '2020.01.01' '2022.12.31' $set
  $m=Get-Stat (Join-Path $repDir "S5TP_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "S5TP_${tag}_BWD.htm")
  $cand= if($m.PF -and $b.PF -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
  "$tp,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $s5out -Append -Encoding utf8
  Write-Host "S5 tp$tp -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)"
}

# ---- SS1 both-window optimize: MinOrAtrH1 x TpRR ----
$s1set="D:\EA_LAB\_mt5_auto\ab_sets\ss1_orb"; New-Item -ItemType Directory -Force $s1set|Out-Null
$s1out="D:\EA_LAB\_mt5_auto\SS1_ORB_BOTHWINDOW.csv"
"minor,tprr,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $s1out -Encoding utf8
foreach($mo in @(0.5,0.8,1.2)){
  foreach($tp in @(2.0,3.0)){
    $tag="mo$($mo -replace '\.','p')_tp$($tp -replace '\.','p')"; $set=Join-Path $s1set "$tag.set"
    @("_02_MinOrAtrH1=$mo","_02_MaxOrAtrH1=2.5","_03_TpRR=$tp") | Out-File $set -Encoding ascii
    RunChecked 'c091c\LondonORB_XAU' 'XAUUSD' 'M15' "SS1_${tag}_MAIN" '2023.01.01' '2025.12.31' $set
    RunChecked 'c091c\LondonORB_XAU' 'XAUUSD' 'M15' "SS1_${tag}_BWD"  '2020.01.01' '2022.12.31' $set
    $m=Get-Stat (Join-Path $repDir "SS1_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "SS1_${tag}_BWD.htm")
    $cand= if($m.PF -and $b.PF -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
    "$mo,$tp,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $s1out -Append -Encoding utf8
    Write-Host "SS1 mo$mo tp$tp -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)"
  }
}
Write-Host "=== DONE  S5:$s5out  SS1:$s1out ==="