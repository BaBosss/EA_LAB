function Kill-Term { Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 800 }
$names1 = Get-Content 'D:\EA_LAB\_mt5_auto\sweeps\order117_gbp_confirm\_names.txt'
foreach ($n in $names1) {
  $setPath = Join-Path 'D:\EA_LAB\_mt5_auto\sweeps\order117_gbp_confirm' "$n.set"
  foreach ($w in @(@{n='MAIN';f='2023.01.01';t='2025.12.31'}, @{n='BWD';f='2020.01.01';t='2022.12.31'})) {
    Kill-Term
    $reportName = "CONF_S1_${n}_GBPUSD_D1_$($w.n)"
    try {
      & D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'MacdDiv_Naked' -Symbol 'GBPUSD' -Period 'D1' -FromDate $w.f -ToDate $w.t -Model 1 -SetFile $setPath -ReportName $reportName -TimeoutSec 90 -Force | Out-Null
    } catch { Write-Output "ERR $_" }
  }
}
Write-Output 'SWEEP1 DONE'
