<#
centscalp_round3.ps1
A. S5 bug isolation: ExtendPts=0 (any distance passes) isolates whether FindSpike ever fires at all,
   separate from the EMA-overshoot condition.
B. S2 push MinRangePts further (2500,3000) at rb30 (the leading axis), then BWD check on best cell.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\centscalp"
$out   = "D:\EA_LAB\_mt5_auto\CENTSCALP_ROUND3.csv"

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
    & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"thread,cellname,tf,pf,trades,net,dd_pct" | Out-File $out -Encoding utf8

# ---- A. S5 bug isolation ----
$setA=Join-Path $setDir "A_isolate.set"
@("_01_SpikeBarAtrMult=1.5","_02_ExtendPts=0") | Out-File $setA -Encoding ascii
RunChecked 'c091c\PostNewsReversion_XAUc' 'M5' 'CSA_isolate_M5' $setA
$sA=Get-Stat (Join-Path $repDir "CSA_isolate_M5.htm")
"A_S5isolate,extend0_sb1p5,M5,$($sA.PF),$($sA.Tr),$($sA.Net),$($sA.DD)" | Out-File $out -Append -Encoding utf8
Write-Host "A(S5 isolate ExtendPts=0) -> PF $($sA.PF) / $($sA.Tr) trades"

# ---- B. S2 push MinRangePts + BWD check ----
foreach($mr in @(2500,3000)){
  $tag="rb30_mr$mr"; $set=Join-Path $setDir "B_$tag.set"
  @("_01_RangeBars=30","_01_MinRangePts=$mr") | Out-File $set -Encoding ascii
  $rm="CSB_${tag}_M5"
  RunChecked 'c091c\RangeFade_XAUc' 'M5' $rm $set
  $s=Get-Stat (Join-Path $repDir "$rm.htm")
  "B_S2push,$tag,M5,$($s.PF),$($s.Tr),$($s.Net),$($s.DD)" | Out-File $out -Append -Encoding utf8
  Write-Host "B(S2 push) $tag -> PF $($s.PF) / $($s.Tr) trades"
}
# BWD check on rb30/mr2000 (best confirmed cell so far)
$setBwd=Join-Path $setDir "B_rb30_mr2000_bwd.set"
@("_01_RangeBars=30","_01_MinRangePts=2000") | Out-File $setBwd -Encoding ascii
RunChecked 'c091c\RangeFade_XAUc' 'M5' 'CSB_rb30_mr2000_BWD' $setBwd '2020.01.01' '2022.12.31'
$sBwd=Get-Stat (Join-Path $repDir "CSB_rb30_mr2000_BWD.htm")
"B_S2bwd,rb30_mr2000,M5,$($sBwd.PF),$($sBwd.Tr),$($sBwd.Net),$($sBwd.DD)" | Out-File $out -Append -Encoding utf8
Write-Host "B(S2 BWD) rb30_mr2000 -> PF $($sBwd.PF) / $($sBwd.Tr) trades"

Write-Host "=== DONE $out ==="
