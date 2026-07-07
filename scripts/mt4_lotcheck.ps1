# mt4_lotcheck.ps1 — TRUE lot-escalation check on an MT4 tester report.
#
# Parses the Size column (5th td) of entry rows (type buy/sell*) ONLY.
# DO NOT use the old quick-grep `class=mspt>(\d+\.\d\d)` — that regex also
# matches Profit and Balance cells, which inflated max-lot readings by 100-1000x
# and caused ~15 false AUTO-REJECTs across ORDER-036 batches 10-19
# (discovered 2026-07-07: "max 18532.33" on UnNomGuai was the final BALANCE).
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
  $trRows = [regex]::Matches($c, '<tr bgcolor[^>]*>(.*?)</tr>', 'Singleline')
  $sizes = New-Object System.Collections.Generic.List[double]
  foreach ($tr in $trRows) {
    $tds = [regex]::Matches($tr.Groups[1].Value, '<td[^>]*>(.*?)</td>', 'Singleline') |
      ForEach-Object { $_.Groups[1].Value.Trim() }
    if ($tds.Count -ge 6 -and $tds[2] -match '^(buy|sell)') {
      $s = 0
      if ([double]::TryParse($tds[4], [ref]$s) -and $s -gt 0) { $sizes.Add($s) }
    }
  }
  $name = Split-Path $Report -Leaf
  if ($sizes.Count -eq 0) { Write-Output "$name : NO_ENTRIES (0-trade window, or non-standard report rows - inspect manually)"; return }
  $mode = [double](($sizes | Group-Object | Sort-Object Count -Descending)[0].Name)
  $max = ($sizes | Measure-Object -Maximum).Maximum
  $ratio = [math]::Round($max / $mode, 1)
  $flag = if ($ratio -ge 10) { ' <<< AUTO-REJECT (>=10x)' } else { '' }
  Write-Output "$name : base=$mode max=$max ratio=x$ratio entries=$($sizes.Count)$flag"
}
