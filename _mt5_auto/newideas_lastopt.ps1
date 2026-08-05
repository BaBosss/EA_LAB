<#
newideas_lastopt.ps1 — last-optimize round for B and C (untried axis, mirrors the SS1 lesson:
wider TP lifted BWD without hurting MAIN). Skip A this round (still far from 1.0 after 2 levers,
lowest priority; needs a code-level lever - TP-overshoot - not a set-file lever).
B. AsianDriftCarry_XAU @ MinDriftAtr=0.8 (best cell): push TpRR wider {4.0, 5.0}
C. VolRegimeBreakout_XAU @ ExpandMult=1.0 (gate effectively off): push DonchianN wider {40, 55}
   (classic Turtle-style lookback - is the 10-30 range simply too short for XAU H1?)
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\newideas"
$out   = "D:\EA_LAB\_mt5_auto\NEWIDEAS_LASTOPT.csv"

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

foreach($tp in @(4.0,5.0)){
  $tag="md0p8_tp$($tp -replace '\.','p')"; $set=Join-Path $setDir "B_lo_$tag.set"
  @("_01_MinDriftAtr=0.8","_02_TpRR=$tp") | Out-File $set -Encoding ascii
  RunChecked 'c091c\AsianDriftCarry_XAU' 'XAUUSD' 'M15' "NEWBL_${tag}_MAIN" '2023.01.01' '2025.12.31' $set
  RunChecked 'c091c\AsianDriftCarry_XAU' 'XAUUSD' 'M15' "NEWBL_${tag}_BWD"  '2020.01.01' '2022.12.31' $set
  $m=Get-Stat (Join-Path $repDir "NEWBL_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "NEWBL_${tag}_BWD.htm")
  $cand= if($m.PF -and $b.PF -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
  "B_AsianDrift,$tag,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out -Append -Encoding utf8
  Write-Host "B $tag -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)"
}

foreach($dn in @(40,55)){
  $tag="dn${dn}_em1"; $set=Join-Path $setDir "C_lo_$tag.set"
  @("_01_DonchianN=$dn","_02_ExpandMult=1.0") | Out-File $set -Encoding ascii
  RunChecked 'c091c\VolRegimeBreakout_XAU' 'XAUUSD' 'H1' "NEWCL_${tag}_MAIN" '2023.01.01' '2025.12.31' $set
  RunChecked 'c091c\VolRegimeBreakout_XAU' 'XAUUSD' 'H1' "NEWCL_${tag}_BWD"  '2020.01.01' '2022.12.31' $set
  $m=Get-Stat (Join-Path $repDir "NEWCL_${tag}_MAIN.htm"); $b=Get-Stat (Join-Path $repDir "NEWCL_${tag}_BWD.htm")
  $cand= if($m.PF -and $b.PF -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
  "C_VolRegime,$tag,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out -Append -Encoding utf8
  Write-Host "C $tag -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)"
}
Write-Host "=== DONE $out ==="