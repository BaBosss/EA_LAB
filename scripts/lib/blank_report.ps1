# blank_report.ps1 - recognise a BLANK Strategy Tester report.
#
# Seen 2026-11-05 in the R11 smoke matrix (4 of 90 single runs): the tester wrote a report whose Settings
# are empty - "Expert:" with no name, "Period: M0 (1970.01.01 - 1970.01.01)", "Leverage: 1:0", Bars 0 -
# while the same cell re-run minutes later produced a normal report. mt5_run.ps1 read the 1:0 as
# "leverage not recorded", printed OK REPORT and exited 0, so a caller that trusts the exit code took
# an empty file for a result. A zero-TRADE report is different and legitimate: it names the expert,
# the symbol and the real window, and only its trade statistics are zero.
#
# Dot-source only. Defines functions, sets no state in the caller.

function Get-TesterReportText {
  param([Parameter(Mandatory)][string]$Path)
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
    $text = [Text.Encoding]::Unicode.GetString($bytes)
  } else {
    $text = [Text.Encoding]::UTF8.GetString($bytes)
  }
  return (($text -replace '<[^>]+>', ' ') -replace '\s+', ' ')
}

# Returns $null for a usable report, or a one-line reason when the report is blank.
function Test-BlankTesterReport {
  param([Parameter(Mandatory)][string]$Path)
  $t = Get-TesterReportText -Path $Path
  # Only the FIRST Expert:/Period: fields are read: they are the Settings block, which precedes Inputs.
  # An input value (e.g. a comment string) may contain the same words and must not count.
  $reasons = @()
  $e = [regex]::Match($t, 'Expert:\s*(.*?)\s*Symbol:')
  if (-not $e.Success -or [string]::IsNullOrWhiteSpace($e.Groups[1].Value)) { $reasons += 'Expert is empty' }
  $p = [regex]::Match($t, 'Period:\s*(\S+)\s*\(\s*(\d{4}\.\d\d\.\d\d)\s*-\s*(\d{4}\.\d\d\.\d\d)\s*\)')
  if ($p.Success) {
    if ($p.Groups[1].Value -eq 'M0') { $reasons += 'Period is M0' }
    if ($p.Groups[2].Value -eq '1970.01.01' -and $p.Groups[3].Value -eq '1970.01.01') { $reasons += 'window is 1970.01.01-1970.01.01' }
  } else { $reasons += 'no readable Period field' }
  if ($reasons.Count -eq 0) { return $null }
  return ($reasons -join '; ')
}
