# ORDER-091C-D1g A/B v2 — robust sequential runner for Meta5b portable.
# Fixes the mt5_run early-give-up: polls for the report FILE (up to 900s) instead of
# watching the launcher process, and waits for each run to finish before the next (no overlap).
$ErrorActionPreference = 'Stop'
$dd    = 'D:\Meta 5b'
$term  = "$dd\terminal64.exe"
$sets  = 'D:\EA_LAB\_mt5_auto\ab_sets\jumstoch_d1g'
$rep   = 'D:\EA_LAB\_mt5_auto\reports'
$inid  = 'D:\EA_LAB\_mt5_auto\ini'

function Idle { while (Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*Meta 5b*' }) { Start-Sleep 3 } }
function Run-One($name, $set, $from, $to) {
  Idle
  $src = "$dd\$name.htm"; $dest = "$rep\$name.htm"
  Remove-Item $src,$dest -Force -ErrorAction SilentlyContinue
  Get-ChildItem $dd -Filter "$name*" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  $inputs = Get-Content $set | Where-Object { $t=$_.Trim(); $t -and -not $t.StartsWith(';') -and $t.Contains('=') } | ForEach-Object { $_.Trim() }
  $lines = @("[Tester]","Expert=c091c\(EXP)_JUMSTOCH_Pending","Symbol=EURGBP","Period=H1","Model=4",
    "Optimization=0","FromDate=$from","ToDate=$to","ForwardMode=0","Deposit=10000","Currency=USD",
    "Leverage=100","ExecutionMode=0","Visual=0","Report=$name","ReplaceReport=1","ShutdownTerminal=1","[TesterInputs]") + $inputs
  $ini = "$inid\$name.ini"; [IO.File]::WriteAllLines($ini, $lines)
  Write-Output ("launch {0} | {1}..{2} | {3}" -f $name, $from, $to, [IO.Path]::GetFileName($set))
  $p = Start-Process -FilePath $term -ArgumentList "/config:`"$ini`" /portable" -PassThru
  try { Start-Sleep -Milliseconds 800; if (-not $p.HasExited) { $p.PriorityClass='BelowNormal' } } catch {}
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt 900) { if (Test-Path $src) { Start-Sleep 3; break }; Start-Sleep 5 }
  if (Test-Path $src) { Move-Item $src $dest -Force; Write-Output "  OK $name ($([int]$sw.Elapsed.TotalSeconds)s)" }
  else { Write-Output "  FAIL $name (timeout ${name})" }
  Start-Sleep 2
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*Meta 5b*' } | Stop-Process -Force -ErrorAction SilentlyContinue
}

Run-One 'D1G_MKT_EURGBP_H1_REC'  "$sets\D1G_market_cage.set" '2023.01.01' '2026.07.01'
Run-One 'D1G_MKT_EURGBP_H1_BWD'  "$sets\D1G_market_cage.set" '2020.01.01' '2022.12.31'
Run-One 'D1G_PEND_EURGBP_H1_REC' "$sets\D1G_pending.set"     '2023.01.01' '2026.07.01'
Run-One 'D1G_PEND_EURGBP_H1_BWD' "$sets\D1G_pending.set"     '2020.01.01' '2022.12.31'
Write-Output "=== D1G EURGBP A/B v2 DONE ==="
