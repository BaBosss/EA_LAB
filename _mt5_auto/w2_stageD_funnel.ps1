<#
w2_stageD_funnel.ps1 — Wave-2 Stage D:
 (1) S1 plateau-center funnel: HOLDOUT 2026H1 (M1) + Model-4 MAIN + Model-4 BWD on locked a20/s0.5/c2.5
 (2) SS4 last-optimize (untouched lever = RSI confirm band) at best-MAIN cell a28/w0.5/t1.8, both-window
 (3) SS1 build-on expansion (calls w2_stageC_ss1_expand.ps1)
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"

function Wait-TermGone(){ $t=[Diagnostics.Stopwatch]::StartNew()
  while((Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq 'D:\Meta 5\terminal64.exe'}) -and $t.Elapsed.TotalSeconds -lt 45){ Start-Sleep -Seconds 2 } }
function Get-Stat([string]$htm){
  if(-not (Test-Path $htm)){ return @{PF=$null;Tr=$null;Net=$null;DD=$null} }
  $c=[IO.File]::ReadAllText($htm,[Text.Encoding]::Unicode); $pf=$null;$tr=$null;$net=$null;$dd=$null
  if($c -match 'Profit Factor:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9.]+)'){ $pf=[double]$Matches[1] }
  if($c -match 'Total Trades:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9]+)'){ $tr=[int]$Matches[1] }
  if($c -match 'Total Net Profit:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(-?[0-9  .,]+)'){ $net=($Matches[1] -replace '[ ,]','') }
  if($c -match 'Equity Drawdown Relative:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9.]+)'){ $dd=[double]$Matches[1] }
  return @{PF=$pf;Tr=$tr;Net=$net;DD=$dd}
}
function RunChecked([string]$expert,[string]$sym,[string]$per,[string]$from,[string]$to,[int]$model,[string]$set,[string]$rm){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 2;$try++){ Wait-TermGone
    if($set){ & $run -Expert $expert -Symbol $sym -Period $per -FromDate $from -ToDate $to -Model $model -SetFile $set -ReportName $rm -TimeoutSec 2400 | Out-Null }
    else    { & $run -Expert $expert -Symbol $sym -Period $per -FromDate $from -ToDate $to -Model $model -ReportName $rm -TimeoutSec 2400 | Out-Null }
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}

# ---------- (1) S1 funnel on locked plateau center ----------
$s1set="D:\EA_LAB\_mt5_auto\ab_sets\w2_s1\a20_s0p5_c2p5.set"
$out1="D:\EA_LAB\_mt5_auto\W2_S1_FUNNEL.csv"
"stage,model,pf,trades,net,eqdd" | Out-File $out1 -Encoding utf8
$fjobs=@(
  @{st='HOLDOUT_2026H1'; m=1; f='2026.01.01'; t='2026.06.30'; rm='W2D_S1_HOLDOUT'},
  @{st='MAIN_M4';        m=4; f='2023.01.01'; t='2025.12.31'; rm='W2D_S1_MAIN_M4'},
  @{st='BWD_M4';         m=4; f='2020.01.01'; t='2022.12.31'; rm='W2D_S1_BWD_M4'}
)
foreach($j in $fjobs){
  RunChecked 'c091c\TrendRider_XAU' 'XAUUSD' 'H4' $j.f $j.t $j.m $s1set $j.rm
  $s=Get-Stat (Join-Path $repDir "$($j.rm).htm")
  "$($j.st),$($j.m),$($s.PF),$($s.Tr),$($s.Net),$($s.DD)" | Out-File $out1 -Append -Encoding utf8
  Write-Host "S1 $($j.st) -> PF $($s.PF) / $($s.Tr)t / net $($s.Net) / eqDD $($s.DD)"
}

# ---------- (2) SS4 last-optimize: RSI band at a28/w0.5/t1.8 ----------
$setDir="D:\EA_LAB\_mt5_auto\ab_sets\w2_ss4"; New-Item -ItemType Directory -Force $setDir | Out-Null
$out2="D:\EA_LAB\_mt5_auto\W2_SS4_LASTOPT.csv"
"rsihi,rsilo,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $out2 -Encoding utf8
foreach($hi in @(70,75)){ foreach($lo in @(30,25)){
  $tag="rsi${hi}_${lo}"
  $set=Join-Path $setDir "$tag.set"
  @("_02_AdxMax=28","_01_SweepAtrMult=0.5","_03_TpAtrMult=1.8","_01_RsiHi=$hi","_01_RsiLo=$lo") | Out-File $set -Encoding ascii
  RunChecked 'c091c\SweepReversal_XAU' 'XAUUSD' 'M15' '2023.01.01' '2025.12.31' 1 $set "W2D_SS4_${tag}_MAIN"
  RunChecked 'c091c\SweepReversal_XAU' 'XAUUSD' 'M15' '2020.01.01' '2022.12.31' 1 $set "W2D_SS4_${tag}_BWD"
  $m=Get-Stat (Join-Path $repDir "W2D_SS4_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "W2D_SS4_${tag}_BWD.htm")
  $cand= if($m.PF -ne $null -and $b.PF -ne $null -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
  "$hi,$lo,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out2 -Append -Encoding utf8
  Write-Host "SS4 $tag -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)  [$cand]"
}}

# ---------- (3) SS1 expansion ----------
& powershell -NoProfile -ExecutionPolicy Bypass -File "D:\EA_LAB\_mt5_auto\w2_stageC_ss1_expand.ps1"
Write-Host "=== STAGE D DONE ==="
