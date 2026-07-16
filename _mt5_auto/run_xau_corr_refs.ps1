# ORDER-112E: full-window XAU passes for corr (Ichimoku-XAU vs the saturated XAU book).
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$runs=@(
  @{rep='CORR_ICHI_XAU';  exp='(EXP)_IchiADX_Naked_rev00'; tf='H1'; set="$root\_mt5_auto\ab_sets\ichi_kumo\KUMO_slow_H1.set"},
  @{rep='CORR_BRK_XAU';   exp='EA_BREAKOUT_XAU';           tf='H1'; set="$root\_vps_deploy\BRK_XAU_live_v3.set"},
  @{rep='CORR_KAU_XAU';   exp='EA_KAUFMAN_ER';             tf='H4'; set="$root\_mt5_auto\sweeps\_sets\KAUERMAN_buyonly.set"},
  @{rep='CORR_ST_XAU';    exp='EA_SUPERTREND';             tf='H4'; set="$root\_vps_deploy\ST_XAU_H4_live_v1.set"}
)
foreach($r in $runs){ Write-Host ">> $($r.rep)"
  if(-not(Test-Path $r.set)){Write-Host "  [no set: $($r.set)]"; continue}
  & "$root\scripts\mt5_run.ps1" -Expert $r.exp -Symbol XAUUSD -Period $r.tf -FromDate '2020.01.01' -ToDate '2026.07.01' -Model 4 -ReportName $r.rep -SetFile $r.set | Out-Null
  $h="$root\_mt5_auto\reports\$($r.rep).htm"; if(Test-Path $h){$o=& "$root\scripts\parse_htm.ps1" -Path $h 2>$null; Write-Host (($o|Out-String).Trim())} else {Write-Host "  [no report]"}
}
Write-Host "DONE"
