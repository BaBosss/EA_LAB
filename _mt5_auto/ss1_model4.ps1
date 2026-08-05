<#
ss1_model4.ps1 — SS1 + trend filter: MODEL-4 (real ticks) confirmation + finish center selection.
SS1 places PENDING STOP orders at the OR edges = fill-sensitive class. Everything so far ran on
Model 1 (1-min OHLC). Lab precedent: Model-2 manufactured a fake grid plateau that Model-4 cut to 0.61.
M4 is therefore the gate that decides whether this result is real.
Center under test = TrendEma200 / MinOr0.5 / TpRR4.0 (balanced: MAIN 1.20 / BWD 1.09 / HOLD 1.21).
Also runs the missing tp3.5 holdout on Model 1 to finish center selection.
BAR (gate): Model-4 both-window PF >= 1.0 retained AND no largest-loss explosion.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\ss1_holdout"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\SS1_MODEL4.csv"
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
function RunChecked([string]$rm,[string]$from,[string]$to,[string]$set,[int]$model,[int]$tmo){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 2;$try++){ Wait-TermGone
    & $run -Expert 'c091c\LondonORB_XAU' -Symbol XAUUSD -Period M15 -FromDate $from -ToDate $to -Model $model -SetFile $set -ReportName $rm -TimeoutSec $tmo | Out-Null
    Start-Sleep -Seconds 3; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
function MakeSet([string]$p,[double]$tp){
  @("_02_MinOrAtrH1=0.5","_02_MaxOrAtrH1=2.5","_03_TpRR=$tp","_04_LotSize=0.01",
    "_07_UseTrendFilter=true","_07_TrendEmaPeriod=200") | Out-File $p -Encoding ascii }

"test,tprr,model,window,pf,trades,net,largest_loss" | Out-File $out -Encoding utf8

# finish center selection: tp3.5 holdout on Model 1 (fast)
$s35=Join-Path $setDir "hold_tp3p5.set"; MakeSet $s35 3.5
RunChecked "SS1H_tp3p5_HOLD" '2026.01.01' '2026.06.30' $s35 1 900
$s=Get-Stat (Join-Path $repDir "SS1H_tp3p5_HOLD.htm")
"holdout,3.5,1,2026H1,$($s.PF),$($s.Tr),$($s.Net),$($s.WL)" | Out-File $out -Append -Encoding utf8
Write-Host "M1 holdout tp3.5 -> PF $($s.PF) / $($s.Tr)"

# MODEL-4 on the tp4.0 center, all three windows
$s40=Join-Path $setDir "m4_tp4.set"; MakeSet $s40 4.0
foreach($w in @(@('MAIN','2023.01.01','2025.12.31'), @('HOLD','2026.01.01','2026.06.30'), @('BWD','2020.01.01','2022.12.31'))){
  $rm="SS1M4_tp4_$($w[0])"
  Write-Host "starting Model-4 $($w[0]) (real ticks - slow)..."
  RunChecked $rm $w[1] $w[2] $s40 4 3000
  $st=Get-Stat (Join-Path $repDir "$rm.htm")
  "model4,4.0,4,$($w[0]),$($st.PF),$($st.Tr),$($st.Net),$($st.WL)" | Out-File $out -Append -Encoding utf8
  Write-Host "M4 $($w[0]) -> PF $($st.PF) / $($st.Tr) / largest-loss $($st.WL)"
}
Write-Host "=== DONE $out ==="
