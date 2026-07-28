<#
Rebuild _triage/ORDER222_probe_stage2_ld125000.csv from the actual reports.

Every probe results CSV written before the ORDER-372 fix contains a "Length" column of string byte
counts instead of metrics, because the output-leak bug filled $results with the runner's console
text and Export-Csv serialises a string's .Length. ORDER-372 is the one experiment whose .htm
reports are still on disk, so its artifact can be rebuilt from source rather than left as garbage.
The other five pre-fix CSVs are NOT reconstructed here - their reports are gone, and inventing
numbers for them would be worse than leaving them visibly broken.
#>
$ErrorActionPreference = "Stop"
$reports = "D:\EA_LAB\_mt5_auto\reports"

function Read-Result([string]$reportName) {
  $htm = Join-Path $reports "$reportName.htm"
  if (-not (Test-Path $htm)) { return $null }
  $flat  = (Get-Content $htm -Raw) -replace '<[^>]+>', '|'
  $parts = ($flat -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  function Field($label) {
    for ($i = 0; $i -lt $parts.Count - 1; $i++) { if ($parts[$i] -eq $label) { return $parts[$i+1] } }
    return $null
  }
  $eqdd = $null
  $raw = Field 'Equity Drawdown Maximal:'
  if ($raw) { $m = [regex]::Match($raw, '\((\d+(?:\.\d+)?)%\)'); if ($m.Success) { $eqdd = [double]$m.Groups[1].Value } }
  $lev = $null
  $lm = [regex]::Match(($flat -replace '\|', ' '), 'Leverage:\s*1:(\d+)'); if ($lm.Success) { $lev = [int]$lm.Groups[1].Value }
  $trunc = $null
  $ts = Join-Path $reports "$reportName.truncation_check.json"
  if (Test-Path $ts) { $trunc = (Get-Content $ts -Raw | ConvertFrom-Json) }
  return [PSCustomObject]@{
    report = $reportName; pf = (Field 'Profit Factor:'); trades = (Field 'Total Trades:')
    net = (Field 'Total Net Profit:'); eqdd_pct = $eqdd; leverage = $lev
    truncated = $(if ($trunc) { $trunc.truncated } else { $null })
  }
}

$rows = @()
foreach ($cut in @(30, 100)) {
  $r = Read-Result ("O222_S2_ld125000_cut{0}" -f $cut)
  if (-not $r) { throw "missing report for cut$cut - refusing to write a partial CSV" }
  $r | Add-Member -NotePropertyName cutloss -NotePropertyValue $cut
  $rows += $r
}

$csv = "D:\EA_LAB\_triage\ORDER222_probe_stage2_ld125000.csv"
$rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
Write-Output "rebuilt -> $csv"
$rows | Format-Table report, cutloss, pf, trades, net, eqdd_pct, leverage, truncated -AutoSize | Out-String -Width 200 | Write-Output
