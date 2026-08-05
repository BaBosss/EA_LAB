<#
s5_asianrange_sweep.ps1 — both-window optimize for S5 (AsianRange_XAU M30). ROBUST rev.
Levers: MaxRangeAtrD1 x SellOk. Retries a run if its report is missing (shutdown-race guard).
CANDIDATE = MAIN>=1.2 AND BWD>=1.0.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\s5_asian"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$out   = "D:\EA_LAB\_mt5_auto\S5_ASIAN_BOTHWINDOW.csv"
New-Item -ItemType Directory -Force $setDir | Out-Null

function Wait-TermGone(){ $t=[Diagnostics.Stopwatch]::StartNew()
  while((Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq 'D:\Meta 5\terminal64.exe'}) -and $t.Elapsed.TotalSeconds -lt 40){ Start-Sleep -Seconds 2 } }

function Invoke-RunChecked([string]$rm,[string]$from,[string]$to,[string]$set){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 2;$try++){
    Wait-TermGone
    & $run -Expert 'c091c\AsianRange_XAU' -Symbol XAUUSD -Period M30 -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2
    if(Test-Path $htm){ return }
    Write-Host "  retry $rm (attempt $try produced no report)"
  }
}
function Get-Stat([string]$htm){
  if(-not (Test-Path $htm)){ return @{PF=$null;Tr=$null;Net=$null} }
  $c=[IO.File]::ReadAllText($htm,[Text.Encoding]::Unicode); $pf=$null;$tr=$null;$net=$null
  if($c -match 'Profit Factor:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9.]+)'){ $pf=[double]$Matches[1] }
  if($c -match 'Total Trades:</td>\s*<td[^>]*>\s*(?:<b>)?\s*([0-9]+)'){ $tr=[int]$Matches[1] }
  if($c -match 'Total Net Profit:</td>\s*<td[^>]*>\s*(?:<b>)?\s*(-?[0-9  .,]+)'){ $net=($Matches[1] -replace '[ ,]','') }
  return @{PF=$pf;Tr=$tr;Net=$net}
}

"maxrange,sellok,main_pf,main_tr,main_net,bwd_pf,bwd_tr,bwd_net,candidate" | Out-File $out -Encoding utf8
foreach($mr in @(0.30,0.20,0.15)){
  foreach($so in @('true','false')){
    $tag="mr$($mr -replace '\.','p')_so$so"
    $set=Join-Path $setDir "$tag.set"
    @("_02_MaxRangeAtrD1=$mr","_04_SellOk=$so") | Out-File $set -Encoding ascii
    $rmMain="S5SW_${tag}_MAIN"; $rmBwd="S5SW_${tag}_BWD"
    Invoke-RunChecked $rmMain '2023.01.01' '2025.12.31' $set
    Invoke-RunChecked $rmBwd  '2020.01.01' '2022.12.31' $set
    $m=Get-Stat (Join-Path $repDir "$rmMain.htm"); $b=Get-Stat (Join-Path $repDir "$rmBwd.htm")
    $cand= if($m.PF -ne $null -and $b.PF -ne $null -and $m.PF -ge 1.2 -and $b.PF -ge 1.0){"YES"}else{"no"}
    "$mr,$so,$($m.PF),$($m.Tr),$($m.Net),$($b.PF),$($b.Tr),$($b.Net),$cand" | Out-File $out -Append -Encoding utf8
    Write-Host "mr$mr so$so -> MAIN $($m.PF)/$($m.Tr)  BWD $($b.PF)/$($b.Tr)  [$cand]"
  }
}
Write-Host "=== DONE $out ==="