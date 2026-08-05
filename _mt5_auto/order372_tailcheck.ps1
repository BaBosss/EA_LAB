<#
ORDER-372 tail check: is the winning arm being decided by the calendar again?

ORDER-222's whole limitation was that its CutLoss=100 arm carried a single
-15,300 loss cluster in the final minute of the window - a basket the tester
force-closed at the window edge rather than the market resolving. This script
asks whether the 18-month re-run reproduces that shape at its own new edge.

Reads with UTF-16LE explicitly: MT5 writes these reports in Unicode, and a
byte-oriented read returns zero matches for tokens that are certainly present -
which reads as "no such deals" when it actually means "could not see the file".
#>
$ErrorActionPreference = "Stop"
$reports = "D:\EA_LAB\_mt5_auto\reports"

foreach ($n in @("O222_S2_ld125000_cut30", "O222_S2_ld125000_cut100")) {
  $htm = Join-Path $reports "$n.htm"
  if (-not (Test-Path $htm)) { Write-Output "MISSING: $htm"; continue }
  $raw = [IO.File]::ReadAllText($htm, [Text.Encoding]::Unicode)

  # Prove the instrument can see the file before trusting any count it reports.
  $sanity = ([regex]::Matches($raw, '2022\.')).Count
  Write-Output "=== $n ==="
  Write-Output "  sanity: occurrences of '2022.' = $sanity  (0 here would mean the READ is wrong, not the data)"

  $finalDay = ([regex]::Matches($raw, '2023\.06\.30')).Count
  Write-Output "  occurrences of final day '2023.06.30' = $finalDay"

  # Pull table rows, keep those on the final day, and show their numeric cells.
  $rows = $raw -split '<tr'
  $lastRows = @($rows | Where-Object { $_ -match '2023\.06\.30' })
  Write-Output "  table rows mentioning the final day = $($lastRows.Count)"

  $tail = $lastRows | Select-Object -Last 15
  foreach ($r in $tail) {
    $cells = ($r -replace '<[^>]+>', '|') -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($cells.Count -gt 0) { Write-Output ("    " + ($cells -join " ~ ")) }
  }
  Write-Output ""
}
