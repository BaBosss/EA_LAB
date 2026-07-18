function Kill-Term { Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 800 }
$names2 = Get-Content 'D:\EA_LAB\_mt5_auto\sweeps\rsimom_xau_confirm\_names.txt'
foreach ($n in $names2) {
  $setPath = Join-Path 'D:\EA_LAB\_mt5_auto\sweeps\rsimom_xau_confirm' "$n.set"
  foreach ($tf in 'H4','H1') {
    foreach ($w in @(@{n='MAIN';f='2023.01.01';t='2025.12.31'}, @{n='BWD';f='2020.01.01';t='2022.12.31'})) {
      Kill-Term
      $reportName = "CONF_S2_${n}_XAUUSD_${tf}_$($w.n)"
      try {
        & D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'RsiMomentum_Naked' -Symbol 'XAUUSD' -Period $tf -FromDate $w.f -ToDate $w.t -Model 1 -SetFile $setPath -ReportName $reportName -TimeoutSec 90 -Force | Out-Null
      } catch { Write-Output "ERR $_" }
    }
  }
}
Write-Output 'SWEEP2 DONE'
