<#
centscalp_round2.ps1 — three parallel threads of investigation (sequential on one tester lane):
A. S5 sanity check: loosen SpikeBarAtrMult to confirm the mechanism can fire at all (0 trades
   at 3.0x on both TFs is suspicious - bug-check before any verdict).
B. S3 MomentumBurst on H1/H4: PF climbed monotonically with TF (0.56/0.70/0.81 at M1/M5/M15) -
   test if the trend continues past 1.0 on longer TFs.
C. S2 RangeFade optimize: the ONE strategy that cleared 1.2 naked at default (M5, PF1.26/n190).
   RangeBars x MinRangePts grid to find a real plateau, not a lucky default.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\centscalp"
$out   = "D:\EA_LAB\_mt5_auto\CENTSCALP_ROUND2.csv"
New-Item -ItemType Directory -Force $setDir | Out-Null

function Wait-TermGone(){ $t=[Diagnostics.Stopwatch]::StartNew()
  while((Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq 'D:\Meta 5\terminal64.exe'}) -and $t.Elapsed.TotalSeconds -lt 45){ Start-Sleep -Seconds 2 } }
function Get-Stat([string]$htm){
  if(-not (Test-Path $htm)){ return @{PF=$null;Tr=$null;Net=$null;DD=$null} }
  $c=[IO.File]::ReadAllText($htm,[Text.Encoding]::Unicode); $pf=$null;$tr=$null;$net=$null;$dd=$null
  if($c -match 'Profit Factor:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9.]+)'){ $pf=[double]$Matches[1] }
  if($c -match 'Total Trades:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9]+)'){ $tr=[int]$Matches[1] }
  if($c -match 'Total Net Profit:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(-?[0-9  .,]+)'){ $net=($Matches[1] -replace '[ ,]','') }
  if($c -match 'Equity Drawdown Maximal:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(?:-?[0-9  .,]+)\s*\(([0-9.]+)%\)'){ $dd=[double]$Matches[1] }
  return @{PF=$pf;Tr=$tr;Net=$net;DD=$dd}
}
function RunChecked([string]$expert,[string]$per,[string]$rm,[string]$set,[string]$from='2023.01.01',[string]$to='2025.12.31'){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    if($set){ & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null }
    else    { & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate $from -ToDate $to -Model 1 -ReportName $rm -TimeoutSec 900 | Out-Null }
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"thread,cellname,tf,pf,trades,net,dd_pct" | Out-File $out -Encoding utf8

# ---- A. S5 sanity check (loosen threshold) ----
foreach($sb in @(1.5,2.0)){
  $tag="sb$($sb -replace '\.','p')"; $set=Join-Path $setDir "A_$tag.set"
  @("_01_SpikeBarAtrMult=$sb") | Out-File $set -Encoding ascii
  $rm="CSA_${tag}_M5"
  RunChecked 'c091c\PostNewsReversion_XAUc' 'M5' $rm $set
  $s=Get-Stat (Join-Path $repDir "$rm.htm")
  "A_S5sanity,$tag,M5,$($s.PF),$($s.Tr),$($s.Net),$($s.DD)" | Out-File $out -Append -Encoding utf8
  Write-Host "A(S5 sanity) $tag M5 -> PF $($s.PF) / $($s.Tr) trades"
}

# ---- B. S3 on H1/H4 ----
foreach($tf in @('H1','H4')){
  $rm="CSB_S3_$tf"
  RunChecked 'c091c\MomentumBurst_XAUc' $tf $rm ""
  $s=Get-Stat (Join-Path $repDir "$rm.htm")
  "B_S3longtf,$tf,$tf,$($s.PF),$($s.Tr),$($s.Net),$($s.DD)" | Out-File $out -Append -Encoding utf8
  Write-Host "B(S3) $tf -> PF $($s.PF) / $($s.Tr) trades"
}

# ---- C. S2 RangeFade optimize (M5, the confirmed home) ----
foreach($rb in @(15,30)){
  foreach($mr in @(1000,2000)){
    $tag="rb${rb}_mr$mr"; $set=Join-Path $setDir "C_$tag.set"
    @("_01_RangeBars=$rb","_01_MinRangePts=$mr") | Out-File $set -Encoding ascii
    $rm="CSC_${tag}_M5"
    RunChecked 'c091c\RangeFade_XAUc' 'M5' $rm $set
    $s=Get-Stat (Join-Path $repDir "$rm.htm")
    "C_S2optimize,$tag,M5,$($s.PF),$($s.Tr),$($s.Net),$($s.DD)" | Out-File $out -Append -Encoding utf8
    Write-Host "C(S2) $tag -> PF $($s.PF) / $($s.Tr) trades"
  }
}
Write-Host "=== DONE $out ==="