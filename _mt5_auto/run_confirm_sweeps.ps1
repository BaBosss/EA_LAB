$ErrorActionPreference = "Continue"
$csv = "D:\EA_LAB\_mt5_auto\RSIMOM_MACDDIV_CONFIRM_SWEEPS.csv"
"Sweep,Expert,Symbol,Period,Window,SetName,PF,Trades,DDpct,Net,RF" | Set-Content $csv

function Kill-Term {
  Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
}

function Run-One($sweep, $expert, $symbol, $period, $window, $from, $to, $setPath, $setName) {
  Kill-Term
  $reportName = "CONF_$($sweep)_$($setName)_$($symbol)_$($period)_$($window)"
  Write-Output "=== RUN $reportName ==="
  try {
    & D:\EA_LAB\scripts\mt5_run.ps1 -Expert $expert -Symbol $symbol -Period $period -FromDate $from -ToDate $to -Model 1 -SetFile $setPath -ReportName $reportName -TimeoutSec 300 -Force
  } catch {
    Write-Output "RUN ERROR: $_"
  }
  $rep = "D:\EA_LAB\_mt5_auto\reports\$reportName.htm"
  if (Test-Path $rep) {
    $r = D:\EA_LAB\scripts\parse_htm.ps1 -Path $rep | Out-String
    $pf = [regex]::Match($r,'PF\s*:\s*([\-\d.]+)').Groups[1].Value
    $tr = [regex]::Match($r,'Trades\s*:\s*(\d+)').Groups[1].Value
    $dd = [regex]::Match($r,'DDpct\s*:\s*([\-\d.]+)').Groups[1].Value
    $net= [regex]::Match($r,'Net\s*:\s*([\-\d.]+)').Groups[1].Value
    $rf = [regex]::Match($r,'RF\s*:\s*([\-\d.]+)').Groups[1].Value
    "$sweep,$expert,$symbol,$period,$window,$setName,$pf,$tr,$dd,$net,$rf" | Add-Content $csv
    Write-Output "PARSED: PF=$pf Trades=$tr DD=$dd"
  } else {
    "$sweep,$expert,$symbol,$period,$window,$setName,NOREPORT,,,," | Add-Content $csv
    Write-Output "NO REPORT for $reportName"
  }
}

# ===== SWEEP 1: MacdDiv_Naked GBPUSD D1 =====
$names1 = Get-Content "D:\EA_LAB\_mt5_auto\sweeps\order117_gbp_confirm\_names.txt"
foreach ($n in $names1) {
  $setPath = "D:\EA_LAB\_mt5_auto\sweeps\order117_gbp_confirm\$n.set"
  Run-One "S1" "MacdDiv_Naked" "GBPUSD" "D1" "MAIN" "2023.01.01" "2025.12.31" $setPath $n
  Run-One "S1" "MacdDiv_Naked" "GBPUSD" "D1" "BWD"  "2020.01.01" "2022.12.31" $setPath $n
}

# ===== SWEEP 2: RsiMomentum_Naked XAU H4 + H1 =====
$names2 = Get-Content "D:\EA_LAB\_mt5_auto\sweeps\rsimom_xau_confirm\_names.txt"
foreach ($n in $names2) {
  $setPath = "D:\EA_LAB\_mt5_auto\sweeps\rsimom_xau_confirm\$n.set"
  foreach ($tf in "H4","H1") {
    Run-One "S2" "RsiMomentum_Naked" "XAUUSD" $tf "MAIN" "2023.01.01" "2025.12.31" $setPath $n
    Run-One "S2" "RsiMomentum_Naked" "XAUUSD" $tf "BWD"  "2020.01.01" "2022.12.31" $setPath $n
  }
}

Write-Output "ALL DONE"
