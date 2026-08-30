$ErrorActionPreference = 'Stop'
$wt = 'D:\EA_LAB_CONTROL\worktrees\bt3-b16-xau-m15-pe-port01'
$dir = Join-Path $wt 'factory\runs\bt3_20260830\b16_xau_m15_pe_port01'
$set = Join-Path $dir 'B16_XAU_M15_PE_PORT_01.set'
$log = Join-Path $dir 'execution_console.log'
$receiptRegistry = 'D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPT_REGISTRY_cf32ba8d.jsonl'
'' | Set-Content -LiteralPath $log -Encoding UTF8
$lanePath = 'D:\EA_LAB_CONTROL\lanes\registry-v1\bt3-b16-xau-m15-pe-port01-20260830.json'
$lane = Get-Content $lanePath -Raw | ConvertFrom-Json
if ($lane.state -ne 'RUNNING' -or $lane.runtime_lane -ne 'MT5-lane2') { throw 'runtime lane claim invalid' }
$owned = Get-CimInstance Win32_Process | Where-Object {
  $_.Name -ieq 'terminal64.exe' -and $_.ExecutablePath -ieq 'D:\Meta 5b\terminal64.exe'
}
if ($owned) { throw 'Meta5b terminal already running' }
$cells = @(
  @{ w='MAIN'; f='2023.01.01'; t='2025.12.31' },
  @{ w='BWD';  f='2020.01.01'; t='2022.12.31' }
)
Push-Location $wt
try {
  foreach ($x in $cells) {
    $name = 'BT3_B16_XAU_M15_PE_PORT01_XAUUSD_M15_' + $x.w + '_M1'
    ('RUN_START ' + $name + ' ' + [DateTimeOffset]::UtcNow.ToString('o')) | Tee-Object -FilePath $log -Append
    & .\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_16_KangarooGrid' -Symbol 'XAUUSD' -Period 'M15' `
      -FromDate $x.f -ToDate $x.t -SetFile $set -Model 1 -Deposit 10000 -Leverage 100 `
      -ReportName $name -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable `
      -BuildReceiptRegistry $receiptRegistry -LaneId 'bt3-b16-xau-m15-pe-port01-20260830' 2>&1 | Tee-Object -FilePath $log -Append
    $code = $LASTEXITCODE
    ('RUN_END ' + $name + ' code=' + $code + ' ' + [DateTimeOffset]::UtcNow.ToString('o')) | Tee-Object -FilePath $log -Append
    if ($code -ne 0) { throw ('MT5 cell failed mechanically: ' + $name + ' exit=' + $code) }
  }
} finally { Pop-Location }
Write-Output 'BT3_SEQUENCE_COMPLETE'
