<#
w2_stageC_ss1_expand.ps1 — SS1 LondonORB BUILD-ON symbol x TF expansion (doctrine build-on).
Plateau-center set from SS1_ORB_BOTHWINDOW.csv: MinOrAtrH1=0.5, TpRR=3.
Symbols: GBPUSD, EURUSD, USDJPY @ M15 · XAUUSD @ M30 (TF axis). Both-window each.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\w2_ss1x"; New-Item -ItemType Directory -Force $setDir | Out-Null
$out   = "D:\EA_LAB\_mt5_auto\W2_SS1_EXPAND.csv"

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
function RunChecked([string]$sym,[string]$per,[string]$from,[string]$to,[string]$set,[string]$rm){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 2;$try++){ Wait-TermGone
    & $run -Expert 'c091c\LondonORB_XAU' -Symbol $sym -Period $per -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 1200 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
$set=Join-Path $setDir "plateau.set"
@("_02_MinOrAtrH1=0.5","_03_TpRR=3.0") | Out-File $set -Encoding ascii

"symbol,tf,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $out -Encoding utf8
$cells=@(
  @{s='GBPUSD'; p='M15'}, @{s='EURUSD'; p='M15'}, @{s='USDJPY'; p='M15'}, @{s='XAUUSD'; p='M30'}
)
foreach($c in $cells){
  $tag="$($c.s)_$($c.p)"
  RunChecked $c.s $c.p '2023.01.01' '2025.12.31' $set "W2C_SS1_${tag}_MAIN"
  RunChecked $c.s $c.p '2020.01.01' '2022.12.31' $set "W2C_SS1_${tag}_BWD"
  $m=Get-Stat (Join-Path $repDir "W2C_SS1_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "W2C_SS1_${tag}_BWD.htm")
  $cand= if($m.PF -ne $null -and $b.PF -ne $null -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
  "$($c.s),$($c.p),$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out -Append -Encoding utf8
  Write-Host "SS1 $tag -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)  [$cand]"
}
Write-Host "=== DONE $out ==="
