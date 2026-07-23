<#
centscalp_regime_and_optimize.ps1
A. Regime-overlay regression + both-window compare on S3 MomentumBurst H1 (gate OFF must reproduce
   baseline 0.86/n502 exactly; gate ON tested both-window to see if it rescues BWD).
B. S3 optimize (gate OFF still, raw entry params): BodyAtrMult x SlPoints, both-window H1.
C. S5 optimize: SpikeBarAtrMult x ExtendPts, both-window M5.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\centscalp"
$out   = "D:\EA_LAB\_mt5_auto\CENTSCALP_REGIME_OPT.csv"
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
function RunChecked([string]$expert,[string]$per,[string]$rm,[string]$set,[string]$from,[string]$to){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"thread,cellname,window,pf,trades,net" | Out-File $out -Encoding utf8

function MakeS3Set([string]$p,[bool]$gate,[double]$body=1.5,[int]$sl=60,[double]$adx=20.0,[int]$persist=10){
  $g = if($gate){"true"}else{"false"}
  @("_01_BodyAtrMult=$body","_02_SlPoints=$sl","_07_UseRegimeGate=$g","_07_AdxD1Min=$adx","_07_SlopePersistDays=$persist") | Out-File $p -Encoding ascii
}

# ---- A. regression (gate off) + both-window gate-on compare, H1 ----
$sOff=Join-Path $setDir "A_gateoff.set"; MakeS3Set $sOff $false
RunChecked 'c091c\MomentumBurst_XAUc' 'H1' 'CSREG_gateoff_MAIN' $sOff '2023.01.01' '2025.12.31'
$r=Get-Stat (Join-Path $repDir "CSREG_gateoff_MAIN.htm")
"A_regression,gateoff,MAIN,$($r.PF),$($r.Tr),$($r.Net)" | Out-File $out -Append -Encoding utf8
Write-Host "A(regression gate-off MAIN) -> PF $($r.PF)/$($r.Tr) (expect ~0.86/502)"

$sOn=Join-Path $setDir "A_gateon.set"; MakeS3Set $sOn $true
foreach($w in @(@('MAIN','2023.01.01','2025.12.31'),@('BWD','2020.01.01','2022.12.31'))){
  $rm="CSREG_gateon_$($w[0])"
  RunChecked 'c091c\MomentumBurst_XAUc' 'H1' $rm $sOn $w[1] $w[2]
  $s=Get-Stat (Join-Path $repDir "$rm.htm")
  "A_regimegate,gateon,$($w[0]),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
  Write-Host "A(gate-ON) $($w[0]) -> PF $($s.PF)/$($s.Tr)"
}
# baseline BWD for comparison (gate off)
RunChecked 'c091c\MomentumBurst_XAUc' 'H1' 'CSREG_gateoff_BWD' $sOff '2020.01.01' '2022.12.31'
$rb=Get-Stat (Join-Path $repDir "CSREG_gateoff_BWD.htm")
"A_regression,gateoff,BWD,$($rb.PF),$($rb.Tr),$($rb.Net)" | Out-File $out -Append -Encoding utf8
Write-Host "A(gate-OFF) BWD -> PF $($rb.PF)/$($rb.Tr)"

# ---- B. S3 optimize (gate off): BodyAtrMult x SlPoints, both-window H1 ----
foreach($bd in @(1.0,2.0)){
  foreach($sl in @(40,80)){
    $tag="bd$($bd -replace '\.','p')_sl$sl"; $set=Join-Path $setDir "B_$tag.set"; MakeS3Set $set $false $bd $sl
    foreach($w in @(@('MAIN','2023.01.01','2025.12.31'),@('BWD','2020.01.01','2022.12.31'))){
      $rm="CSB_${tag}_$($w[0])"
      RunChecked 'c091c\MomentumBurst_XAUc' 'H1' $rm $set $w[1] $w[2]
      $s=Get-Stat (Join-Path $repDir "$rm.htm")
      "B_S3optimize,$tag,$($w[0]),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
      Write-Host "B(S3) $tag $($w[0]) -> PF $($s.PF)/$($s.Tr)"
    }
  }
}

# ---- C. S5 optimize: SpikeBarAtrMult x ExtendPts, both-window M5 ----
foreach($sb in @(2.0,2.5,3.5)){
  foreach($ex in @(150,300)){
    $tag="sb$($sb -replace '\.','p')_ex$ex"; $set=Join-Path $setDir "C_$tag.set"
    @("_01_SpikeBarAtrMult=$sb","_02_ExtendPts=$ex","_04_LotSize=0.01") | Out-File $set -Encoding ascii
    foreach($w in @(@('MAIN','2023.01.01','2025.12.31'),@('BWD','2020.01.01','2022.12.31'))){
      $rm="CSC_${tag}_$($w[0])"
      RunChecked 'c091c\PostNewsReversion_XAUc' 'M5' $rm $set $w[1] $w[2]
      $s=Get-Stat (Join-Path $repDir "$rm.htm")
      "C_S5optimize,$tag,$($w[0]),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
      Write-Host "C(S5) $tag $($w[0]) -> PF $($s.PF)/$($s.Tr)"
    }
  }
}
Write-Host "=== DONE $out ==="