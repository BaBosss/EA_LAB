# ORDER-091C-D1g A/B batch: EURGBP H1, market vs pending, both windows, Model 4 (every tick).
# Sequential on Meta5b (parallel lane; D:\Meta 5 is busy with a concurrent NuiIndy run).
$ErrorActionPreference = 'Stop'
$run  = 'D:\EA_LAB\scripts\mt5_run.ps1'
$sets = 'D:\EA_LAB\_mt5_auto\ab_sets\jumstoch_d1g'
$term = 'D:\Meta 5b\terminal64.exe'
$dd   = 'D:\Meta 5b'
$cells = @(
  @{ arm='MKT';  set="$sets\D1G_market_cage.set" },
  @{ arm='PEND'; set="$sets\D1G_pending.set" }
)
$wins = @(
  @{ w='REC'; from='2023.01.01'; to='2026.07.01' },
  @{ w='BWD'; from='2020.01.01'; to='2022.12.31' }
)
foreach ($c in $cells) {
  foreach ($win in $wins) {
    $rn = "D1G_{0}_EURGBP_H1_{1}" -f $c.arm, $win.w
    Write-Output "=== $rn ==="
    & $run -Expert 'c091c\(EXP)_JUMSTOCH_Pending' -Symbol EURGBP -Period H1 `
        -FromDate $win.from -ToDate $win.to -Model 4 -Deposit 10000 -Leverage 100 `
        -SetFile $c.set -ReportName $rn -Terminal $term -DataDir $dd -Portable -TimeoutSec 1500
  }
}
Write-Output "=== D1G EURGBP A/B batch DONE ==="
