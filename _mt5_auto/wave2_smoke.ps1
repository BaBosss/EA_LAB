<#
wave2_smoke.ps1 — naked-default MAIN smoke for Wave 2 (S1 TrendRider H4, SS2 NyIgnition M15, SS4 SweepReversal M15).
Robust: kills leftover D:\Meta 5 terminal64 first, retries if report missing.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\WAVE2_SMOKE.csv"

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
function RunChecked([string]$expert,[string]$per,[string]$rm){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 1 -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"ea,tf,pf,trades,net" | Out-File $out -Encoding utf8
$jobs = @(
  @{e='c091c\TrendRider_XAU'; tf='H4';  rm='W2_S1_TrendRider_MAIN'},
  @{e='c091c\NyIgnition_XAU'; tf='M15'; rm='W2_SS2_NyIgnition_MAIN'},
  @{e='c091c\SweepReversal_XAU'; tf='M15'; rm='W2_SS4_SweepRev_MAIN'}
)
foreach($j in $jobs){
  RunChecked $j.e $j.tf $j.rm
  $s=Get-Stat (Join-Path $repDir "$($j.rm).htm")
  "$($j.e),$($j.tf),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
  Write-Host "$($j.e) $($j.tf) -> PF $($s.PF) / $($s.Tr) trades / net $($s.Net)"
}
Write-Host "=== DONE $out ==="