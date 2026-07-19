<#
w2_stageA_bothwindow.ps1 — Wave-2 Stage A screen: naked both-window landscape for
S1 TrendRider (H4 + H1) and SS4 SweepReversal (M15 + M30) before designing optimize grids.
MAIN 2023.01-2025.12 / BWD 2020.01-2022.12, Model 1. Reuses proven RunChecked pattern.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\W2_STAGEA_BOTHWINDOW.csv"

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
function RunChecked([string]$expert,[string]$per,[string]$from,[string]$to,[string]$rm){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate $from -ToDate $to -Model 1 -ReportName $rm -TimeoutSec 1200 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"ea,tf,window,pf,trades,net" | Out-File $out -Encoding utf8
$jobs = @(
  @{e='c091c\TrendRider_XAU';    tf='H4';  w='BWD';  f='2020.01.01'; t='2022.12.31'; rm='W2A_S1_H4_BWD'},
  @{e='c091c\TrendRider_XAU';    tf='H1';  w='MAIN'; f='2023.01.01'; t='2025.12.31'; rm='W2A_S1_H1_MAIN'},
  @{e='c091c\TrendRider_XAU';    tf='H1';  w='BWD';  f='2020.01.01'; t='2022.12.31'; rm='W2A_S1_H1_BWD'},
  @{e='c091c\SweepReversal_XAU'; tf='M15'; w='BWD';  f='2020.01.01'; t='2022.12.31'; rm='W2A_SS4_M15_BWD'},
  @{e='c091c\SweepReversal_XAU'; tf='M30'; w='MAIN'; f='2023.01.01'; t='2025.12.31'; rm='W2A_SS4_M30_MAIN'},
  @{e='c091c\SweepReversal_XAU'; tf='M30'; w='BWD';  f='2020.01.01'; t='2022.12.31'; rm='W2A_SS4_M30_BWD'}
)
foreach($j in $jobs){
  RunChecked $j.e $j.tf $j.f $j.t $j.rm
  $s=Get-Stat (Join-Path $repDir "$($j.rm).htm")
  "$($j.e),$($j.tf),$($j.w),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
  Write-Host "$($j.e) $($j.tf) $($j.w) -> PF $($s.PF) / $($s.Tr)t / net $($s.Net)"
}
Write-Host "=== DONE $out ==="
