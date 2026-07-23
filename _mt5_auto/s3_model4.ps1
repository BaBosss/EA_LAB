<#
s3_model4.ps1 — S3 MomentumBurst Model-4 (real ticks) confirmation at the locked center
(BodyAtrMult=2.0, SlPoints=40, H1, regime gate OFF). Fill-sensitive class (breakout entry +
trailing stop) -- lab precedent (grid M1 1.23 -> M4 0.61) makes M4 the deciding gate.
Bar: both-window PF >= 1.0 retained AND no largest-loss explosion.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$set   = "D:\EA_LAB\_mt5_auto\ab_sets\centscalp\S3_locked_center.set"
$out   = "D:\EA_LAB\_mt5_auto\S3_MODEL4.csv"

function Wait-TermGone(){ $t=[Diagnostics.Stopwatch]::StartNew()
  while((Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq 'D:\Meta 5\terminal64.exe'}) -and $t.Elapsed.TotalSeconds -lt 60){ Start-Sleep -Seconds 3 } }
function Get-Stat([string]$htm){
  if(-not (Test-Path $htm)){ return @{PF=$null;Tr=$null;Net=$null;WL=$null} }
  $c=[IO.File]::ReadAllText($htm,[Text.Encoding]::Unicode); $pf=$null;$tr=$null;$net=$null;$wl=$null
  if($c -match 'Profit Factor:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9.]+)'){ $pf=[double]$Matches[1] }
  if($c -match 'Total Trades:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9]+)'){ $tr=[int]$Matches[1] }
  if($c -match 'Total Net Profit:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(-?[0-9  .,]+)'){ $net=($Matches[1] -replace '[ ,]','') }
  if($c -match 'Largest loss trade:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(-?[0-9  .,]+)'){ $wl=($Matches[1] -replace '[ ,]','') }
  return @{PF=$pf;Tr=$tr;Net=$net;WL=$wl}
}
function RunChecked([string]$rm,[string]$from,[string]$to){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 2;$try++){ Wait-TermGone
    & $run -Expert 'c091c\MomentumBurst_XAUc' -Symbol XAUUSD -Period H1 -FromDate $from -ToDate $to -Model 4 -SetFile $set -ReportName $rm -TimeoutSec 3000 | Out-Null
    Start-Sleep -Seconds 3; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}

"window,pf,trades,net,largest_loss" | Out-File $out -Encoding utf8
foreach($w in @(@('MAIN','2023.01.01','2025.12.31'), @('BWD','2020.01.01','2022.12.31'), @('HOLD','2026.01.01','2026.06.30'))){
  $rm="S3M4_$($w[0])"
  Write-Host "starting Model-4 $($w[0]) (real ticks - slow)..."
  RunChecked $rm $w[1] $w[2]
  $s=Get-Stat (Join-Path $repDir "$rm.htm")
  "$($w[0]),$($s.PF),$($s.Tr),$($s.Net),$($s.WL)" | Out-File $out -Append -Encoding utf8
  Write-Host "M4 $($w[0]) -> PF $($s.PF) / $($s.Tr) trades / net $($s.Net) / largest-loss $($s.WL)"
}
Write-Host "=== DONE $out ==="