$ErrorActionPreference = "Continue"
$sets = Get-ChildItem "D:\EA_LAB\_mt5_auto\ab_sets\rsimom_gbp\*.set" | Sort-Object Name
$tfs = @("H4","H1")
$windows = @(
  @{Tag="MAIN"; From="2023.01.01"; To="2025.12.31"},
  @{Tag="BWD";  From="2020.01.01"; To="2022.12.31"}
)
$csv = "D:\EA_LAB\_mt5_auto\RSIMOM_GBP_SWEEPS.csv"
"Combo,TF,Window,PF,Net,Trades,DDpct,Win,RF,Sharpe,Status" | Out-File -FilePath $csv -Encoding utf8

foreach ($tf in $tfs) {
  foreach ($set in $sets) {
    $combo = $set.BaseName
    foreach ($w in $windows) {
      $report = "RSIMOMGBP_${combo}_${tf}_$($w.Tag)"
      Write-Output "=== RUN $report ==="
      Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 2
      $out = & D:\EA_LAB\scripts\mt5_run.ps1 -Expert "RsiMomentum_Naked" -Symbol GBPUSD -Period $tf `
        -FromDate $w.From -ToDate $w.To -Model 1 -SetFile $set.FullName -ReportName $report `
        -TimeoutSec 150 -Force
      Write-Output $out
      $htm = "D:\EA_LAB\_mt5_auto\reports\$report.htm"
      if (Test-Path $htm) {
        $p = & D:\EA_LAB\scripts\parse_htm.ps1 -Path $htm
        $text = $p | Out-String
        function Get1($label) {
          $m = [regex]::Match($text, "$label\s*:\s*(\S+)")
          if ($m.Success) { return $m.Groups[1].Value } else { return "" }
        }
        $pf = Get1 "PF"; $net = Get1 "Net"; $tr = Get1 "Trades"; $dd = Get1 "DDpct"
        $win = Get1 "Win"; $rf = Get1 "RF"; $sh = Get1 "Sharpe"
        "$combo,$tf,$($w.Tag),$pf,$net,$tr,$dd,$win,$rf,$sh,OK" | Out-File -FilePath $csv -Append -Encoding utf8
      } else {
        Get-Process terminal64 -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        "$combo,$tf,$($w.Tag),,,,,,,,NO_REPORT" | Out-File -FilePath $csv -Append -Encoding utf8
      }
    }
  }
}
Write-Output "DONE. CSV: $csv"
