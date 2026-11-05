# Cage for scripts/lib/blank_report.ps1 and its call in mt5_run.ps1 (blank tester report = no report).
param([string]$RealZeroTradeReport = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'scripts\lib\blank_report.ps1')
$pass = 0; $fail = 0
function Check([string]$name, [bool]$ok, [string]$detail = '') {
  if ($ok) { $script:pass++; Write-Output "PASS $name" } else { $script:fail++; Write-Output "FAIL $name -- $detail" }
}
function New-Report([string]$settings) {
  $p = Join-Path ([IO.Path]::GetTempPath()) ("blankrep_" + [guid]::NewGuid().ToString('N') + '.htm')
  $html = "<html><body><table><tr><td>Expert:</td><td>$($settings.Split('|')[0])</td></tr>" +
          "<tr><td>Symbol:</td><td>$($settings.Split('|')[1])</td></tr>" +
          "<tr><td>Period:</td><td>$($settings.Split('|')[2])</td></tr>" +
          "<tr><td>Leverage:</td><td>$($settings.Split('|')[3])</td></tr>" +
          "<tr><td>Total Trades:</td><td>0</td></tr></table></body></html>"
  [IO.File]::WriteAllBytes($p, [byte[]](0xFF,0xFE) + [Text.Encoding]::Unicode.GetBytes($html))  # UTF-16LE like MT5
  return $p
}
$blank = New-Report '||M0 (1970.01.01 - 1970.01.01)|1:0'
$why = Test-BlankTesterReport -Path $blank
Check 'blank report (empty Expert, M0, 1970) is recognised' ($null -ne $why -and $why -match 'Expert is empty' -and $why -match 'M0') "$why"
$zero = New-Report 'Boss_17_Wave5|EURUSD|M15 (2023.01.01 - 2025.12.31)|1:0'
Check 'zero-trade report with a named expert and real window is NOT blank' ($null -eq (Test-BlankTesterReport -Path $zero))
$normal = New-Report 'Boss_15_ST03|GBPUSD|H1 (2023.01.01 - 2025.12.31)|1:100'
Check 'normal report is NOT blank' ($null -eq (Test-BlankTesterReport -Path $normal))
$utf8 = Join-Path ([IO.Path]::GetTempPath()) ("blankrep_" + [guid]::NewGuid().ToString('N') + '.htm')
[IO.File]::WriteAllText($utf8, '<td>Expert:</td><td></td><td>Symbol:</td><td></td><td>Period:</td><td>M0 (1970.01.01 - 1970.01.01)</td>')
Check 'blank report in UTF-8 is recognised too' ($null -ne (Test-BlankTesterReport -Path $utf8))
if ($RealZeroTradeReport -and (Test-Path $RealZeroTradeReport)) {
  Check 'a real zero-trade MT5 report is NOT blank' ($null -eq (Test-BlankTesterReport -Path $RealZeroTradeReport))
} else { Write-Output 'NOTE real zero-trade report not supplied; that specificity case did not run' }
# the runner really calls it, before any OK REPORT line, and exits 1 on a blank report
$src = Get-Content (Join-Path $root 'scripts\mt5_run.ps1') -Raw
$iCall = $src.IndexOf('Test-BlankTesterReport -Path $destHtm')
$iOk = $src.IndexOf('OK REPORT')
Check 'mt5_run calls the blank check before any OK REPORT' ($iCall -gt 0 -and $iCall -lt $iOk) "call=$iCall ok=$iOk"
Check 'mt5_run exits 1 after ABORT BLANK REPORT' ($src -match 'ABORT BLANK REPORT[^\n]*\r?\n\s*exit 1')
Remove-Item $blank, $zero, $normal, $utf8 -ErrorAction SilentlyContinue
Write-Output "TOTAL PASS=$pass FAIL=$fail"
if ($fail) { exit 1 } else { exit 0 }
