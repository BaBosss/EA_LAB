<#
newideas_optimize.ps1 — quick both-window optimize for the 3 new signal-scanner ideas.
A. VwapSnapback_EUR: ExtendSigma x SigmaLookback (is the trigger threshold/window wrong?)
B. AsianDriftCarry_XAU: MinDriftAtr x TpRR (is the drift filter too loose / TP too tight?)
C. VolRegimeBreakout_XAU: DonchianN x ExpandMult (is the vol gate killing good breakouts,
   or is the Donchian lookback itself wrong? ExpandMult=1.0 effectively disables the gate)
CANDIDATE-ish bar (triage, not full deploy gate) = MAIN>=1.2 AND BWD>=1.0.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\newideas"
$out   = "D:\EA_LAB\_mt5_auto\NEWIDEAS_OPTIMIZE.csv"
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
function RunChecked([string]$expert,[string]$sym,[string]$per,[string]$rm,[string]$from,[string]$to,[string]$set){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    & $run -Expert $expert -Symbol $sym -Period $per -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"idea,cellname,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $out -Encoding utf8

# ---- A. VwapSnapback_EUR: ExtendSigma x SigmaLookback ----
foreach($es in @(2.0,3.0)){
  foreach($lb in @(40,90)){
    $tag="es$($es -replace '\.','p')_lb$lb"; $set=Join-Path $setDir "A_$tag.set"
    @("_01_ExtendSigma=$es","_01_SigmaLookback=$lb") | Out-File $set -Encoding ascii
    RunChecked 'c091c\VwapSnapback_EUR' 'EURUSD' 'M15' "NEWA_${tag}_MAIN" '2023.01.01' '2025.12.31' $set
    RunChecked 'c091c\VwapSnapback_EUR' 'EURUSD' 'M15' "NEWA_${tag}_BWD"  '2020.01.01' '2022.12.31' $set
    $m=Get-Stat (Join-Path $repDir "NEWA_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "NEWA_${tag}_BWD.htm")
    $cand= if($m.PF -and $b.PF -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
    "A_VwapSnapback,$tag,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out -Append -Encoding utf8
    Write-Host "A $tag -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)"
  }
}

# ---- B. AsianDriftCarry_XAU: MinDriftAtr x TpRR ----
foreach($md in @(0.3,0.8)){
  foreach($tp in @(1.5,3.0)){
    $tag="md$($md -replace '\.','p')_tp$($tp -replace '\.','p')"; $set=Join-Path $setDir "B_$tag.set"
    @("_01_MinDriftAtr=$md","_02_TpRR=$tp") | Out-File $set -Encoding ascii
    RunChecked 'c091c\AsianDriftCarry_XAU' 'XAUUSD' 'M15' "NEWB_${tag}_MAIN" '2023.01.01' '2025.12.31' $set
    RunChecked 'c091c\AsianDriftCarry_XAU' 'XAUUSD' 'M15' "NEWB_${tag}_BWD"  '2020.01.01' '2022.12.31' $set
    $m=Get-Stat (Join-Path $repDir "NEWB_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "NEWB_${tag}_BWD.htm")
    $cand= if($m.PF -and $b.PF -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
    "B_AsianDrift,$tag,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out -Append -Encoding utf8
    Write-Host "B $tag -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)"
  }
}

# ---- C. VolRegimeBreakout_XAU: DonchianN x ExpandMult ----
foreach($dn in @(10,30)){
  foreach($em in @(1.0,1.3)){
    $tag="dn${dn}_em$($em -replace '\.','p')"; $set=Join-Path $setDir "C_$tag.set"
    @("_01_DonchianN=$dn","_02_ExpandMult=$em") | Out-File $set -Encoding ascii
    RunChecked 'c091c\VolRegimeBreakout_XAU' 'XAUUSD' 'H1' "NEWC_${tag}_MAIN" '2023.01.01' '2025.12.31' $set
    RunChecked 'c091c\VolRegimeBreakout_XAU' 'XAUUSD' 'H1' "NEWC_${tag}_BWD"  '2020.01.01' '2022.12.31' $set
    $m=Get-Stat (Join-Path $repDir "NEWC_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "NEWC_${tag}_BWD.htm")
    $cand= if($m.PF -and $b.PF -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
    "C_VolRegime,$tag,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out -Append -Encoding utf8
    Write-Host "C $tag -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)"
  }
}
Write-Host "=== DONE $out ==="