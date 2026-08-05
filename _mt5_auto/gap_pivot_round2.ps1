<#
gap_pivot_round2.ps1
A. GapContinuation: loosen MinGapAtrMult (0.15, 0.2) on H1 to get a healthy n before any verdict
   (n=11 at 0.3 is too thin to trust the PF17/PF9.8 headline numbers).
B. PivotBreakout optimize on H4 (best naked home, 1.14/n199): SlAtrMult x TpRR grid.
#>
$ErrorActionPreference = "Stop"
$run   = "D:\EA_LAB\scripts\mt5_run.ps1"
$repDir= "D:\EA_LAB\_mt5_auto\reports"
$setDir= "D:\EA_LAB\_mt5_auto\ab_sets\gappivot"
$out   = "D:\EA_LAB\_mt5_auto\GAPPIVOT_ROUND2.csv"
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
function RunChecked([string]$expert,[string]$per,[string]$rm,[string]$set,[string]$from,[string]$to){
  $htm=Join-Path $repDir "$rm.htm"
  for($try=1;$try -le 3;$try++){ Wait-TermGone
    & $run -Expert $expert -Symbol XAUUSD -Period $per -FromDate $from -ToDate $to -Model 1 -SetFile $set -ReportName $rm -TimeoutSec 900 | Out-Null
    Start-Sleep -Seconds 2; if(Test-Path $htm){ return }
    Write-Host "  retry $rm ($try)" }
}
"thread,cellname,window,pf,trades,net" | Out-File $out -Encoding utf8

# ---- A. GapContinuation threshold loosen, H1, MAIN + BWD ----
foreach($mg in @(0.15,0.2)){
  $tag="mg$($mg -replace '\.','p')"; $set=Join-Path $setDir "A_$tag.set"
  @("_01_MinGapAtrMult=$mg") | Out-File $set -Encoding ascii
  foreach($w in @(@('MAIN','2023.01.01','2025.12.31'),@('BWD','2020.01.01','2022.12.31'))){
    $rm="GPA_${tag}_$($w[0])"
    RunChecked 'c091c\GapContinuation_XAU' 'H1' $rm $set $w[1] $w[2]
    $s=Get-Stat (Join-Path $repDir "$rm.htm")
    "A_GapLoosen,$tag,$($w[0]),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
    Write-Host "A(Gap) $tag $($w[0]) -> PF $($s.PF)/$($s.Tr)"
  }
}

# ---- B. PivotBreakout optimize, H4 ----
foreach($sl in @(1.5,2.5)){
  foreach($tp in @(1.5,3.0)){
    $tag="sl$($sl -replace '\.','p')_tp$($tp -replace '\.','p')"; $set=Join-Path $setDir "B_$tag.set"
    @("_02_SlAtrMult=$sl","_02_TpRR=$tp") | Out-File $set -Encoding ascii
    foreach($w in @(@('MAIN','2023.01.01','2025.12.31'),@('BWD','2020.01.01','2022.12.31'))){
      $rm="GPB_${tag}_$($w[0])"
      RunChecked 'c091c\PivotBreakout_XAU' 'H4' $rm $set $w[1] $w[2]
      $s=Get-Stat (Join-Path $repDir "$rm.htm")
      "B_PivotOptimize,$tag,$($w[0]),$($s.PF),$($s.Tr),$($s.Net)" | Out-File $out -Append -Encoding utf8
      Write-Host "B(Pivot) $tag $($w[0]) -> PF $($s.PF)/$($s.Tr)"
    }
  }
}
Write-Host "=== DONE $out ==="