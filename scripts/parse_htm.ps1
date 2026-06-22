# parse_htm.ps1 — extract key MT5 backtest stats from a report .htm (UTF-16) using regex.
param([Parameter(Mandatory)][string]$Path)
$raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::Unicode)
$txt = ($raw -replace '<[^>]+>', ' ') -replace '&nbsp;', ' '
function Grab($label) {
  $m = [regex]::Match($txt, [regex]::Escape($label) + '\s*([-\d.,]+)')
  if ($m.Success) { return $m.Groups[1].Value -replace ',', '' }
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
