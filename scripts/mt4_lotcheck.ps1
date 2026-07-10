# mt4_lotcheck.ps1 — TRUE lot-escalation check on an MT4 tester report.
#
# Parses the Size column (5th td) of entry rows (type buy/sell) ONLY.
# DO NOT use the old quick-grep `class=mspt>(\d+\.\d\d)` — that regex also
# matches Profit and Balance cells, which inflated max-lot readings by 100-1000x
# and caused ~15 false AUTO-REJECTs across ORDER-036 batches 10-19
# (discovered 2026-07-07: "max 18532.33" on UnNomGuai was the final BALANCE).
#
# 2026-07-10 fix: MT4 stripes the trade table — alternate rows have NO bgcolor
# attribute. The old `<tr bgcolor` row regex therefore sampled only ~half the
# trades (KANGAROO_XAU_H1_3Y: saw 1,789 of 6,242 entries). Now parses ALL <tr>
# rows and keeps rows whose first cell is the trade # (integer) and whose type
# is EXACTLY buy/sell (market entries). Pending placements (buy stop / sell
# limit / ...) are deliberately excluded from the main count; if a report has
# ZERO market entries but has pending placements (pending-entry EA), sizes are
# taken from the placement rows instead and the output says so.
#
# Output: one line per report: base(mode) / max / ratio / entries.
# Auto-flag rule unchanged: ratio >= 10x => REJECT (uncapped grid/martingale).
#
# Usage:
#   .\mt4_lotcheck.ps1 -Report D:\EA_LAB\_mt4_auto\reports\FOO.htm
#   Get-ChildItem ...\reports\BWD4B*.htm | .\mt4_lotcheck.ps1
param(
  [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
  [Alias('FullName')]
  [string]$Report
)
process {
  if (-not (Test-Path -LiteralPath $Report)) { Write-Output "$Report : MISSING"; return }
  $c = Get-Content -LiteralPath $Report -Raw
  $trRows = [regex]::Matches($c, '<tr[^>]*>(.*?)</tr>', 'Singleline')
  $sizes = New-Object System.Collections.Generic.List[double]
  $pendSizes = New-Object System.Collections.Generic.List[double]
  foreach ($tr in $trRows) {
    $tds = [regex]::Matches($tr.Groups[1].Value, '<td[^>]*>(.*?)</td>', 'Singleline') |
      ForEach-Object { $_.Groups[1].Value.Trim() }
    if ($tds.Count -lt 6 -or $tds[0] -notmatch '^\d+$') { continue }
    $s = 0
    if (-not ([double]::TryParse($tds[4], [ref]$s) -and $s -gt 0)) { continue }
    if ($tds[2] -match '^(buy|sell)$') { $sizes.Add($s) }
    elseif ($tds[2] -match '^(buy|sell) (stop|limit)$') { $pendSizes.Add($s) }
  }
  $name = Split-Path $Report -Leaf
  $srcNote = ''
  if ($sizes.Count -eq 0 -and $pendSizes.Count -gt 0) {
    $sizes = $pendSizes
    $srcNote = ' [pending-entry EA: sizes from placement rows]'
  }
  if ($sizes.Count -eq 0) { Write-Output "$name : NO_ENTRIES (0-trade window, or non-standard report rows - inspect manually)"; return }
  $mode = [double](($sizes | Group-Object | Sort-Object Count -Descending)[0].Name)
  $max = ($sizes | Measure-Object -Maximum).Maximum
  $ratio = [math]::Round($max / $mode, 1)
  $flag = if ($ratio -ge 10) { ' <<< AUTO-REJECT (>=10x)' } else { '' }
  Write-Output "$name : base=$mode max=$max ratio=x$ratio entries=$($sizes.Count)$flag$srcNote"
}
