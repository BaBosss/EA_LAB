<#
centscalp_multitf_triage.ps1 — multi-TF naked smoke (Model 1, fast triage) for the 5-strategy
cent-scalp portfolio. Finds the right home TF per strategy before spending Model-4 time on it.
Symbol = XAUUSD (XAUUSDc has no Market Watch entry under the current tester login; price action
is identical 1:1 per Exness cent-account convention -- see memory note).
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\CENTSCALP_MULTITF_TRIAGE.csv"

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
function RunChecked([string]$expert,[string]$per,[string]$rm){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 1 -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"strategy,tf,pf,trades,net,dd_pct" | Out-File $out -Encoding utf8
$jobs = @(
  @{k='S1_EmaScalp';        e='c091c\EmaScalp_XAUc';           tfs=@('M1','M5','M15')},
  @{k='S2_RangeFade';       e='c091c\RangeFade_XAUc';          tfs=@('M5','M15')},
  @{k='S3_MomentumBurst';   e='c091c\MomentumBurst_XAUc';      tfs=@('M1','M5','M15')},
  @{k='S4_AsianPingPong';   e='c091c\AsianPingPong_XAUc';      tfs=@('M5','M15')},
  @{k='S5_PostNewsReversion'; e='c091c\PostNewsReversion_XAUc'; tfs=@('M5','M15')}
)
foreach($j in $jobs){
  foreach($tf in $j.tfs){
    $rm="CS_$($j.k)_$tf"
    RunChecked $j.e $tf $rm
    $s=Get-Stat (Join-Path $repDir "$rm.htm")
    "$($j.k),$tf,$($s.PF),$($s.Tr),$($s.Net),$($s.DD)" | Out-File $out -Append -Encoding utf8
    Write-Host "$($j.k) $tf -> PF $($s.PF) / $($s.Tr) trades / DD $($s.DD)%"
  }
}
Write-Host "=== DONE $out ==="