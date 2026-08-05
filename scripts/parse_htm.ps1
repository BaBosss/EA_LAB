# parse_htm.ps1 — extract key MT5 backtest stats from a report .htm (UTF-16) using regex.
#
# BUGFIX 2026-07-23 (ORDER-142): MT5 formats large numbers with a SPACE thousands-separator
# (e.g. "1 182.12" for PF=1182.12), which the old regex `[-\d.,]+` did not include - it silently
# stopped at the space and returned "1". This under-reported ANY field >= 1000 (Profit Factor,
# Total Net Profit, Recovery Factor, Sharpe) as a truncated small number with NO error - a caught
# case: ETH M4 profit factor 1182.12 was returned as "1", which reads as a sane number rather than
# an obvious parse failure. Fixed by absorbing a space-then-digit run into the captured number and
# stripping spaces same as commas. If this parser has been trusted before today on ANY report with
# Net Profit or PF >= 1000, that number should be treated as unverified until re-parsed.
param([Parameter(Mandatory)][string]$Path)
$raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::Unicode)
$txt = ($raw -replace '<[^>]+>', ' ') -replace '&nbsp;', ' '
function Grab($label) {
  $m = [regex]::Match($txt, [regex]::Escape($label) + '\s*(-?[\d]{1,3}(?:[ ,]\d{3})*(?:\.\d+)?)')
  if ($m.Success) { return ($m.Groups[1].Value -replace '[ ,]', '') }
  return $null
}
$pf    = Grab 'Profit Factor:'
$np    = Grab 'Total Net Profit:'
$tr    = Grab 'Total Trades:'
$rf    = Grab 'Recovery Factor:'
$sh    = Grab 'Sharpe Ratio:'
$mddm  = [regex]::Match($txt, 'Equity Drawdown Maximal:\s*([\d.,]+)\s*\(([\d.,]+)%\)')
$ddpct = if ($mddm.Success) { $mddm.Groups[2].Value } else { $null }
$pt    = [regex]::Match($txt, 'Profit Trades \(% of total\):\s*(\d+)\s*\(([\d.,]+)%\)')
$winp  = if ($pt.Success) { $pt.Groups[2].Value } else { $null }
[PSCustomObject]@{
  Report = [IO.Path]::GetFileNameWithoutExtension($Path)
  PF=$pf; Net=$np; Trades=$tr; DDpct=$ddpct; Win=$winp; RF=$rf; Sharpe=$sh
} | Format-List
