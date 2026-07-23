<#
centscalp_round4.ps1
A. S2 RangeFade + D1 regime gate on the default cell (rb20/mr1500), both-window: does the D1
   trend-persistence overlay rescue BWD (baseline was 0.38, total collapse) where the shorter M15
   ADX kill-switch alone did not?
B. S3 MomentumBurst bd2_sl40 fan (BodyAtrMult{1.5,2.5} x SlPoints{30,50}), both-window H1: confirm
   the 1.05/1.36 result is a plateau, not a lucky single cell.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\centscalp"
$out   = "D:\EA_LAB\_mt5_auto\CENTSCALP_ROUND4.csv"

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
function RunChecked([string]$expert,[string]$per,[string]$rm,[string]$set,[string]$from,[string]$to){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"thread,cellname,window,pf,trades,net" | Out-File $out -Encoding utf8

# ---- A. S2 + D1 regime gate, both-window ----
$sA=Join-Path $setDir "A_s2regime.set"
@("_01_RangeBars=20","_01_MinRangePts=1500","_08_UseRegimeGate=true","_08_AdxD1Max=20.0","_08_SlopePersistDays=10") | Out-File $sA -Encoding ascii
foreach($w in @(@('MAIN','2023.01.01','2025.12.31'),@('BWD','2020.01.01','2022.12.31'))){
  $rm="CSR4A_$($w[0])"
  RunChecked 'c091c\RangeFade_XAUc' 'M5' $rm $sA $w[1] $w[2]
  $s=Get-Stat (Join-Path $repDir "$rm.htm")
  "A_S2regime,gateon,$($w[0]),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
  Write-Host "A(S2+regime) $($w[0]) -> PF $($s.PF)/$($s.Tr)"
}

# ---- B. S3 bd2_sl40 fan ----
foreach($bd in @(1.5,2.5)){
  foreach($sl in @(30,50)){
    $tag="bd$($bd -replace '\.','p')_sl$sl"; $set=Join-Path $setDir "B4_$tag.set"
    @("_01_BodyAtrMult=$bd","_02_SlPoints=$sl","_07_UseRegimeGate=false") | Out-File $set -Encoding ascii
    foreach($w in @(@('MAIN','2023.01.01','2025.12.31'),@('BWD','2020.01.01','2022.12.31'))){
      $rm="CSR4B_${tag}_$($w[0])"
      RunChecked 'c091c\MomentumBurst_XAUc' 'H1' $rm $set $w[1] $w[2]
      $s=Get-Stat (Join-Path $repDir "$rm.htm")
      "B_S3fan,$tag,$($w[0]),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
      Write-Host "B(S3 fan) $tag $($w[0]) -> PF $($s.PF)/$($s.Tr)"
    }
  }
}
Write-Host "=== DONE $out ==="