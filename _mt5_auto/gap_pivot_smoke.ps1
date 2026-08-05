<#
gap_pivot_smoke.ps1 — naked smoke (Model 1, MAIN, multi-TF) for the 2 new gap/pivot ideas.
GapContinuation: D1-gap driven, works off working-TF bars but references D1 -- test H1/H4/D1.
PivotBreakout: classic pivot, test M15/H1/H4.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\GAPPIVOT_SMOKE.csv"

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
"idea,tf,pf,trades,net" | Out-File $out -Encoding utf8
$jobs = @(
  @{k='GapContinuation'; e='c091c\GapContinuation_XAU'; tfs=@('H1','H4','D1')},
  @{k='PivotBreakout';   e='c091c\PivotBreakout_XAU';   tfs=@('M15','H1','H4')}
)
foreach($j in $jobs){
  foreach($tf in $j.tfs){
    $rm="GP_$($j.k)_$tf"
    RunChecked $j.e $tf $rm
    $s=Get-Stat (Join-Path $repDir "$rm.htm")
    "$($j.k),$tf,$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
    Write-Host "$($j.k) $tf -> PF $($s.PF) / $($s.Tr) trades / net $($s.Net)"
  }
}
Write-Host "=== DONE $out ==="