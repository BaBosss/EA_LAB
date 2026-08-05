. D:\EA_LAB\scripts\use_python.ps1

$dists = @('1.5','2.0','2.5')
$tps = @('150','250','400')
$windows = @(
  @{name='MAIN'; from='2023.01.01'; to='2026.01.01'},
  @{name='BWD';  from='2020.01.01'; to='2023.01.01'}
)

$results = @()

foreach ($w in $windows) {
  foreach ($d in $dists) {
    foreach ($tp in $tps) {
      # skip the one already run
      if ($w.name -eq 'MAIN' -and $d -eq '1.5' -and $tp -eq '150') {
        $reportPath = "D:\EA_LAB\_mt5_auto\reports\O106f_d1.5_tp150_H4_MAIN.htm"
        $status = "OK"
      } else {
        $setFile = "D:\EA_LAB\_mt5_auto\ab_sets\order106_fine\GJf_d${d}_tp${tp}.set"
        $reportName = "O106f_d${d}_tp${tp}_H4_$($w.name)"
        $reportPath = "D:\EA_LAB\_mt5_auto\reports\$reportName.htm"
        $status = "OK"
        $attempt = 0
        $success = $false
        while ($attempt -lt 2 -and -not $success) {
          $attempt++
          try {
            $out = & D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol GBPJPY -Period H4 -FromDate $w.from -ToDate $w.to -Model 1 -Deposit 10000 -Leverage 100 -SetFile $setFile -ReportName $reportName 2>&1
            Write-Output "=== $reportName (attempt $attempt) ==="
            Write-Output $out
            if (Test-Path $reportPath) {
              $success = $true
            } else {
              Write-Output "NO REPORT for $reportName, attempt $attempt"
              Start-Sleep -Seconds 30
            }
          } catch {
            Write-Output "ERROR running $reportName : $_"
            Start-Sleep -Seconds 30
          }
        }
        if (-not $success) { $status = "BUSY_FAIL" }
      }

      if ($status -eq "OK" -and (Test-Path $reportPath)) {
        $parsed = python D:\EA_LAB\scripts\parse_mt5_report.py $reportPath 2>&1
        $pf = ($parsed | Select-String '^\s*profit_factor:\s*(.+)$').Matches.Groups[1].Value
        $net = ($parsed | Select-String '^\s*net_profit:\s*(.+)$').Matches.Groups[1].Value
        $trades = ($parsed | Select-String '^\s*total_trades:\s*(.+)$').Matches.Groups[1].Value
        $dd = ($parsed | Select-String '^\s*equity_drawdown_relative_pct:\s*(.+)$').Matches.Groups[1].Value
        $wpct = ($parsed | Select-String '^\s*profit_trades_pct:\s*(.+)$').Matches.Groups[1].Value
        $results += [PSCustomObject]@{
          dist=$d; basketTP=$tp; window=$w.name; PF=$pf; Net=$net; Trades=$trades; DDpct=$dd; WinPct=$wpct; status="OK"
        }
      } else {
        $results += [PSCustomObject]@{
          dist=$d; basketTP=$tp; window=$w.name; PF=""; Net=""; Trades=""; DDpct=""; WinPct=""; status=$status
        }
      }
    }
  }
}

$results | Export-Csv -Path D:\EA_LAB\_mt5_auto\order106_fine_sweep.csv -NoTypeInformation -Encoding ASCII
Write-Output "=== DONE ==="
Get-Content D:\EA_LAB\_mt5_auto\order106_fine_sweep.csv
