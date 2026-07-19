<#
s2_tsmom_bothwindow_sweep.ps1 — coarse both-window optimize for S2 (TsMom_XAU D1).
Grid: MomLookback x DeadAtrMult. Each cell run on MAIN (2023-2025) AND BWD (2020-2022).
Judges CANDIDATE bar: MAIN PF >= 1.2 AND BWD PF >= 1.0. Emits CSV.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\s2_tsmom"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\S2_TSMOM_BOTHWINDOW.csv"
New-Item -ItemType Directory -Force $setDir | Out-Null

$lookbacks = @(60,100,140)
$deadmults = @(1.0,2.0,3.0)

function Get-Stat([string]$htm){
  if(-not (Test-Path $htm)){ return @{PF=$null;Tr=$null;Net=$null} }
  $c = [IO.File]::ReadAllText($htm,[Text.Encoding]::Unicode)
  $pf=$null;$tr=$null;$net=$null
  if($c -match 'Profit Factor:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9.]+)'){ $pf=[double]$Matches[1] }
  if($c -match 'Total Trades:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9]+)'){ $tr=[int]$Matches[1] }
  if($c -match 'Total Net Profit:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(-?[0-9  .,]+)'){ $net=($Matches[1] -replace '[ ,]','') }
  return @{PF=$pf;Tr=$tr;Net=$net}
}

"lookback,deadmult,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $out -Encoding utf8
foreach($lb in $lookbacks){
  foreach($dm in $deadmults){
    $tag = "lb${lb}_dm$($dm -replace '\.','p')"
    $set = Join-Path $setDir "$tag.set"
    @("_01_MomLookback=$lb","_01_DeadAtrMult=$dm") | Out-File $set -Encoding ascii
    $rmMain="S2SW_${tag}_MAIN"; $rmBwd="S2SW_${tag}_BWD"
    & $run -Expert 'c091c\TsMom_XAU' -Symbol XAUUSD -Period D1 -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 1 -SetFile $set -ReportName $rmMain -TimeoutSec 600 | Out-Null
    & $run -Expert 'c091c\TsMom_XAU' -Symbol XAUUSD -Period D1 -FromDate 2020.01.01 -ToDate 2022.12.31 -Model 1 -SetFile $set -ReportName $rmBwd  -TimeoutSec 600 | Out-Null
    $m = Get-Stat (Join-Path $repDir "$rmMain.htm")
    $b = Get-Stat (Join-Path $repDir "$rmBwd.htm")
    $cand = if($m.PF -ne $null -and $b.PF -ne $null -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
    $row = "$lb,$dm,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand"
    $row | Out-File $out -Append -Encoding utf8
    Write-Host $row
  }
}
Write-Host "`n=== DONE -> $out ==="
Get-Content $out