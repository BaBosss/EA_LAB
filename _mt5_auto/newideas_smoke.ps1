<#
newideas_smoke.ps1 — naked-default MAIN smoke (Model 2, signal-scanner Step 3) for 3 new ideas:
  A. VwapSnapback_EUR (EURUSD M15, reversion)
  B. AsianDriftCarry_XAU (XAU M15, momentum/carry)
  C. VolRegimeBreakout_XAU (XAU H1, momentum + vol-regime gate)
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\NEWIDEAS_SMOKE.csv"

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
function RunChecked([string]$expert,[string]$sym,[string]$per,[string]$rm){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    & $run -Expert $expert -Symbol $sym -Period $per -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 2 -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"idea,ea,sym,tf,pf,trades,net" | Out-File $out -Encoding utf8
$jobs = @(
  @{k='A_VwapSnapback'; e='c091c\VwapSnapback_EUR';     s='EURUSD'; tf='M15'},
  @{k='B_AsianDrift';    e='c091c\AsianDriftCarry_XAU';  s='XAUUSD'; tf='M15'},
  @{k='C_VolRegime';     e='c091c\VolRegimeBreakout_XAU';s='XAUUSD'; tf='H1'}
)
foreach($j in $jobs){
  $rm="NEW_$($j.k)_MAIN"
  RunChecked $j.e $j.s $j.tf $rm
  $st=Get-Stat (Join-Path $repDir "$rm.htm")
  "$($j.k),$($j.e),$($j.s),$($j.tf),$($st.PF),$($st.Tr),$($st.Net)" | Out-File $out -Append -Encoding utf8
  Write-Host "$($j.k) -> PF $($st.PF) / $($st.Tr) trades / net $($st.Net)"
}
Write-Host "=== DONE $out ==="