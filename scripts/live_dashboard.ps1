<#
live_dashboard.ps1 - ORDER-058: per-EA live-monitor dashboard (ต่อยอด DealsExporter/ORDER-039+042)

Reads the newest EA_LAB_deals_*.csv snapshot in portfolio\live_deals\ (collected by
collect_live_deals.ps1 from DealsExporter.mq5), groups deals by magic number, joins EA
name/symbol/kill-switch DD% from the cohort table below (source: DEMO_DEPLOYMENT_PLAN.md
"treasure-hunt survivors" + _demo_deploy\README_DEPLOY.md kill-switch section), and
writes a single self-contained HTML file: portfolio\LIVE_DASHBOARD.html

  powershell -File scripts\live_dashboard.ps1
  powershell -File scripts\live_dashboard.ps1 -LiveDealsDir <dir> -OutFile <path>   (testing)

Columns per EA row: name, magic, symbol, trades, net P&L, profit factor, max drawdown %
(computed from the cumulative per-magic P&L curve vs a fixed $10,000 starting-equity
assumption - both treasure-hunt demo accounts are documented as $10k), days since last
trade, and a status flag:
  red    = maxDD% >= that EA's kill-switch DD%
  yellow = maxDD% >= declared warn level (MT4 25% / MT5 15%; EA-specific kill: 80% of kill)
  green  = below that
  white  = 0 trades for this magic yet (no data)
  grey ? = magic present in the CSV but not in the cohort table (unmapped, no criteria)
Colors are flags against the DECLARED kill-switch numbers only - no keep/kill verdict
logic here (that judgment stays with Claude/user per ORDER-058 "ห้าม").
#>
[CmdletBinding()]
param(
  [string]$LiveDealsDir = "D:\EA_LAB\portfolio\live_deals",
  [string]$OutFile      = "D:\EA_LAB\portfolio\LIVE_DASHBOARD.html",
  [double]$BaseEquity   = 10000.0   # documented starting balance, both treasure-hunt demo accounts ($10k)
)
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# 1. locate newest CSV per account (MT5 deals + MT4 orders formats)
#    EA_LAB_deals_<login>[_<yyyyMMdd>].csv       (DealsExporter.mq5, deal rows)
#    EA_LAB_mt4_orders_<login>[_<yyyyMMdd>].csv  (OrdersExporterMT4.mq4, closed orders)
# ---------------------------------------------------------------------------
$csvFiles = @()
$csvFiles += Get-ChildItem (Join-Path $LiveDealsDir "EA_LAB_deals_*.csv") -ErrorAction SilentlyContinue
$csvFiles += Get-ChildItem (Join-Path $LiveDealsDir "EA_LAB_mt4_orders_*.csv") -ErrorAction SilentlyContinue
if (-not $csvFiles) {
  Write-Host "no EA_LAB_deals_*/EA_LAB_mt4_orders_*.csv in $LiveDealsDir"
  exit 1
}
# group by (format, login) -> newest snapshot of each account
$selected = @()
$acctLabels = @()
foreach ($grp in ($csvFiles | Group-Object {
    if ($_.BaseName -match '^(EA_LAB_deals|EA_LAB_mt4_orders)_(\d+)') { "$($Matches[1])|$($Matches[2])" } else { $_.BaseName } })) {
  $newestOfAcct = $grp.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $selected += $newestOfAcct
  Write-Host "using $($newestOfAcct.FullName)"
}
foreach ($f in $selected) {
  $login = "?"; $stamp = ""
  if ($f.BaseName -match '_(\d+)_(\d{8})$') { $login = $Matches[1]; $stamp = $Matches[2] }
  elseif ($f.BaseName -match '_(\d+)$') { $login = $Matches[1] }
  $plat = "MT5"; if ($f.BaseName -like 'EA_LAB_mt4_orders_*') { $plat = "MT4" }
  if ($stamp -match '^(\d{4})(\d{2})(\d{2})$') { $stamp = "$($Matches[1])-$($Matches[2])-$($Matches[3])" }
  $acctLabels += "$plat $login ($stamp)"
}
$acctLogin = ($acctLabels -join ' + ')
$fileDateDisplay = ""   # folded into acctLabels per file

# ---------------------------------------------------------------------------
# 3. cohort static map: magic -> EA meta + declared kill-switch DD%
#    Source: DEMO_DEPLOYMENT_PLAN.md (treasure-hunt table) +
#            _demo_deploy\README_DEPLOY.md "Kill-switch" section
#    KillDD: EA-specific number where README states one, else platform
#            default (MT4 kill 35% / MT5 kill 25%, per README general rule).
#    WarnDD: README's declared เตือน level (MT4 25% / MT5 15%) for platform-
#            default rows; EA-specific kills have no declared warn -> 80% of kill.
# ---------------------------------------------------------------------------
$cohort = [ordered]@{
  "1"      = @{ Name = "UnNomGuaiV1.132";                                 Symbol = "EURUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "2"      = @{ Name = "UnNomGuaiV1.132";                                 Symbol = "EURUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "5888"   = @{ Name = "RSI from pips_EA (RSI-orig)";                     Symbol = "EURUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "990"    = @{ Name = "swb grid 4.1.0.3_h";                              Symbol = "AUDCAD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "990103" = @{ Name = "(Boss)_RSI_MR_GridLog (RSI-MR)";                  Symbol = "EURUSD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "990101" = @{ Name = "(Boss)_ZeusInspired_GridLog (Zeus)";              Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 15.0; WarnDD = 12.0 }
  "991001" = @{ Name = "EA_BREAKOUT_XAU (BRK-XAU)";                       Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 10.0; WarnDD = 8.0 }
  "991004" = @{ Name = "(BRK)_SqueezeBreakout (SqueezeBRK)";              Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 10.0; WarnDD = 8.0 }
  "991002" = @{ Name = "(BRK)_TrendlineBreakout (Trendline, EXPERIMENTAL)"; Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 8.0;  WarnDD = 6.4 }
}

# ---------------------------------------------------------------------------
# 4. load rows from every selected file, normalize both formats, group by magic
# ---------------------------------------------------------------------------
function Parse-TimeSafe([string]$s) {
  try { return [datetime]::ParseExact($s, "yyyy.MM.dd HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) }
  catch { try { return [datetime]$s } catch { return (Get-Date "1970-01-01") } }
}

$grandTotalNet = 0.0
$grandTotalRows = 0

# magic (string) -> array of parsed deal objects
$byMagic = @{}

foreach ($file in $selected) {
  $isMT4 = $file.BaseName -like 'EA_LAB_mt4_orders_*'
  foreach ($d in @(Import-Csv -Path $file.FullName)) {
    $magic = "$($d.magic)"
    $profit = 0.0; $swap = 0.0; $commission = 0.0; $volume = 0.0
    [void][double]::TryParse($d.profit, [ref]$profit)
    [void][double]::TryParse($d.swap, [ref]$swap)
    [void][double]::TryParse($d.commission, [ref]$commission)

    if ($isMT4) {
      # MT4 closed-order row: one row = one whole closed trade. type>=2 = pending/balance -> skip.
      # NOTE: use TryParse's return value - on failure it writes 0 to the ref (would fake a "buy").
      $typeVal = -1
      if (-not [int]::TryParse($d.type, [ref]$typeVal)) { continue }
      if ($typeVal -lt 0 -or $typeVal -gt 1) { continue }
      [void][double]::TryParse($d.lots, [ref]$volume)
      $dt = Parse-TimeSafe $d.close_time
      $entryVal = 1   # a closed order counts as a close (same as DEAL_ENTRY OUT)
      $ticket = $d.ticket
      $symbol = $d.symbol
    } else {
      # MT5 deal row (existing format)
      [void][double]::TryParse($d.volume, [ref]$volume)
      $entryVal = -1
      [void][int]::TryParse($d.entry, [ref]$entryVal)
      $dt = Parse-TimeSafe $d.time
      $ticket = $d.ticket
      $symbol = $d.symbol
    }

    $rowNet = $profit + $swap + $commission

    $obj = [pscustomobject]@{
      Ticket  = $ticket
      Time    = $dt
      Symbol  = $symbol
      Magic   = $magic
      Entry   = $entryVal
      Volume  = $volume
      RowNet  = $rowNet
      Profit  = $profit
    }

    if (-not $byMagic.ContainsKey($magic)) { $byMagic[$magic] = New-Object System.Collections.Generic.List[object] }
    $byMagic[$magic].Add($obj)

    $grandTotalNet += $rowNet
    $grandTotalRows++
  }
}

# ---------------------------------------------------------------------------
# 5. per-magic metrics
# ---------------------------------------------------------------------------
function Compute-MagicMetrics {
  param($deals, [double]$baseEquity)

  $sorted = $deals | Sort-Object Time

  $trades = 0
  $grossProfit = 0.0
  $grossLoss = 0.0
  $netPL = 0.0
  $lastTradeTime = $null
  $symbol = ""

  $running = $baseEquity
  $peak = $baseEquity
  $maxDDPct = 0.0

  foreach ($row in $sorted) {
    if ([string]::IsNullOrWhiteSpace($symbol)) { $symbol = $row.Symbol }
    $netPL += $row.RowNet
    $running += $row.RowNet
    if ($running -gt $peak) { $peak = $running }
    if ($peak -gt 0) {
      $ddPct = (($peak - $running) / $peak) * 100.0
      if ($ddPct -gt $maxDDPct) { $maxDDPct = $ddPct }
    }
    # DEAL_ENTRY: 0=IN 1=OUT 2=INOUT 3=OUT_BY -> count closes as "a trade"
    if ($row.Entry -eq 1 -or $row.Entry -eq 2 -or $row.Entry -eq 3) {
      $trades++
      if ($row.RowNet -ge 0) { $grossProfit += $row.RowNet } else { $grossLoss += $row.RowNet }
      if (-not $lastTradeTime -or $row.Time -gt $lastTradeTime) { $lastTradeTime = $row.Time }
    }
  }

  $pf = $null   # $null = N/A (no closed trades)
  if ($trades -gt 0) {
    if ($grossLoss -eq 0) {
      if ($grossProfit -gt 0) { $pf = [double]::PositiveInfinity } else { $pf = $null }
    } else {
      $pf = $grossProfit / [Math]::Abs($grossLoss)
    }
  }

  [pscustomobject]@{
    Trades       = $trades
    NetPL        = $netPL
    ProfitFactor = $pf
    MaxDDPct     = $maxDDPct
    LastTradeAt  = $lastTradeTime
    CsvSymbol    = $symbol
  }
}

# ---------------------------------------------------------------------------
# 6. build unified row list: every cohort magic (even 0-trade) + any unmapped
#    magic actually present in the CSV
# ---------------------------------------------------------------------------
$now = Get-Date
$rows = New-Object System.Collections.Generic.List[object]

$allMagics = New-Object System.Collections.Generic.List[string]
foreach ($k in $cohort.Keys) { $allMagics.Add($k) }
foreach ($k in $byMagic.Keys) { if (-not $allMagics.Contains($k)) { $allMagics.Add($k) } }

foreach ($magic in $allMagics) {
  $inCohort = $cohort.Contains($magic)
  $meta = $null
  if ($inCohort) { $meta = $cohort[$magic] }

  $deals = New-Object System.Collections.Generic.List[object]
  if ($byMagic.ContainsKey($magic)) { $deals = $byMagic[$magic] }

  $m = Compute-MagicMetrics -deals $deals -baseEquity $BaseEquity

  $symbol = $m.CsvSymbol
  if ([string]::IsNullOrWhiteSpace($symbol) -and $inCohort) { $symbol = $meta.Symbol }
  if ([string]::IsNullOrWhiteSpace($symbol)) { $symbol = "?" }

  $name = "(unmapped magic $magic)"
  if ($inCohort) { $name = $meta.Name }

  $daysSince = $null
  if ($m.LastTradeAt) { $daysSince = [Math]::Floor(($now - $m.LastTradeAt).TotalDays) }

  $statusIcon = "white"
  $statusLabel = "no data yet"
  $rank = 3

  if ($m.Trades -eq 0) {
    $statusIcon = "white"; $statusLabel = "no data yet"; $rank = 3
  } elseif (-not $inCohort) {
    $statusIcon = "grey"; $statusLabel = "unmapped magic - no declared criteria"; $rank = 4
  } else {
    $killDD = $meta.KillDD
    $warnDD = $meta.WarnDD
    if ($m.MaxDDPct -ge $killDD) {
      $statusIcon = "red"; $statusLabel = "DD $([Math]::Round($m.MaxDDPct,1))% >= kill $killDD%"; $rank = 0
    } elseif ($m.MaxDDPct -ge $warnDD) {
      $statusIcon = "yellow"; $statusLabel = "DD $([Math]::Round($m.MaxDDPct,1))% >= warn $warnDD% (kill $killDD%)"; $rank = 1
    } else {
      $statusIcon = "green"; $statusLabel = "DD $([Math]::Round($m.MaxDDPct,1))% normal (kill $killDD%)"; $rank = 2
    }
  }

  $killDDDisplay = "n/a"
  if ($inCohort) { $killDDDisplay = "$($meta.KillDD)%" }

  $rows.Add([pscustomobject]@{
    Rank       = $rank
    Name       = $name
    Magic      = $magic
    Symbol     = $symbol
    Trades     = $m.Trades
    NetPL      = $m.NetPL
    PF         = $m.ProfitFactor
    MaxDDPct   = $m.MaxDDPct
    KillDD     = $killDDDisplay
    DaysSince  = $daysSince
    StatusIcon = $statusIcon
    StatusLabel= $statusLabel
    InCohort   = $inCohort
  })
}

$rowsSorted = $rows | Sort-Object Rank, Name, Magic

# ---------------------------------------------------------------------------
# 7. render HTML
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

function HtmlEnc {
  param([string]$s)
  if ($null -eq $s) { return "" }
  try { return [System.Web.HttpUtility]::HtmlEncode($s) } catch { return $s }
}

function Fmt-Money {
  param([double]$v)
  return "{0:N2}" -f $v
}

function Fmt-PF {
  param($pf)
  if ($null -eq $pf) { return "N/A" }
  if ([double]::IsPositiveInfinity($pf)) { return "&#8734;" }
  return "{0:N2}" -f $pf
}

function Fmt-Days {
  param($d)
  if ($null -eq $d) { return "-" }
  return "$d"
}

$iconMap = @{
  red    = "&#128308;"  # red circle
  yellow = "&#128993;"  # yellow circle
  green  = "&#128994;"  # green circle
  white  = "&#9898;"    # white circle
  grey   = "&#10067;"   # question mark
}
$rowClassMap = @{
  red    = "st-red"
  yellow = "st-yellow"
  green  = "st-green"
  white  = "st-white"
  grey   = "st-grey"
}

$tableRowsHtml = New-Object System.Text.StringBuilder
foreach ($r in $rowsSorted) {
  $icon = $iconMap[$r.StatusIcon]
  $rowClass = $rowClassMap[$r.StatusIcon]
  $netClass = "neu"
  if ($r.NetPL -gt 0) { $netClass = "pos" }
  if ($r.NetPL -lt 0) { $netClass = "neg" }

  [void]$tableRowsHtml.AppendLine("<tr class=`"$rowClass`">")
  [void]$tableRowsHtml.AppendLine("<td class=`"status-cell`" title=`"$(HtmlEnc $r.StatusLabel)`">$icon</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"name-cell`">$(HtmlEnc $r.Name)</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"num-cell`">$(HtmlEnc $r.Magic)</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"num-cell`">$(HtmlEnc $r.Symbol)</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"num-cell`">$($r.Trades)</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"num-cell $netClass`">$(Fmt-Money $r.NetPL)</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"num-cell`">$(Fmt-PF $r.PF)</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"num-cell`">$([Math]::Round($r.MaxDDPct,1))%</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"num-cell`">$(HtmlEnc $r.KillDD)</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"num-cell`">$(Fmt-Days $r.DaysSince)</td>")
  [void]$tableRowsHtml.AppendLine("<td class=`"label-cell`">$(HtmlEnc $r.StatusLabel)</td>")
  [void]$tableRowsHtml.AppendLine("</tr>")
}

$grandTotalDisplay = Fmt-Money $grandTotalNet
$generatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss")
$srcCsvName = HtmlEnc (($selected | ForEach-Object { $_.Name }) -join ', ')
$baseEquityStr = "{0:N0}" -f $BaseEquity

$html = @"
<!doctype html>
<html lang="th">
<head>
<meta charset="utf-8">
<title>EA_LAB Live Dashboard</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif;
    margin: 24px;
    background: #f5f6f8;
    color: #1b1e24;
  }
  @media (prefers-color-scheme: dark) {
    body { background: #14161a; color: #e6e8eb; }
    .card { background: #1d2026 !important; border-color: #33373f !important; }
    table { background: #1d2026 !important; }
    th { background: #262a31 !important; color: #cfd3d9 !important; }
    td { border-color: #2c3038 !important; }
    tr.st-red    { background: #3a1414 !important; }
    tr.st-yellow { background: #3a3212 !important; }
    tr.st-green  { background: #123a1a !important; }
    tr.st-white  { background: #22252b !important; }
    tr.st-grey   { background: #24242a !important; }
    .pos { color: #6fe08a !important; }
    .neg { color: #ff8a80 !important; }
    .legend { background: #1d2026 !important; border-color: #33373f !important; }
  }
  h1 { font-size: 20px; margin-bottom: 4px; }
  .meta { color: #666; font-size: 13px; margin-bottom: 16px; }
  .card {
    background: #fff;
    border: 1px solid #dfe2e6;
    border-radius: 8px;
    padding: 12px 16px;
    margin-bottom: 16px;
  }
  .legend { font-size: 13px; }
  .legend span { margin-right: 18px; white-space: nowrap; }
  table {
    border-collapse: collapse;
    width: 100%;
    background: #fff;
    font-size: 13px;
  }
  th, td {
    border: 1px solid #e2e5e9;
    padding: 6px 10px;
    text-align: right;
  }
  th { background: #eef0f3; text-align: center; }
  .name-cell, .label-cell { text-align: left; }
  .status-cell { text-align: center; font-size: 16px; }
  .pos { color: #17792f; font-weight: 600; }
  .neg { color: #b3261e; font-weight: 600; }
  .neu { color: #666; }
  tr.st-red    { background: #fdeceb; }
  tr.st-yellow { background: #fdf6e3; }
  tr.st-green  { background: #eaf7ee; }
  tr.st-white  { background: #fafafa; }
  tr.st-grey   { background: #f1f1f1; }
  .footer { color: #888; font-size: 12px; margin-top: 16px; }
</style>
</head>
<body>
<h1>EA_LAB Live Dashboard</h1>
<div class="meta">
  Generated: $generatedAt &middot; Source CSV: <code>$srcCsvName</code> &middot;
  Accounts: <code>$acctLogin</code>
</div>

<div class="card legend">
  <b>Legend:</b>
  <span>&#128308; red = max DD hit/breached the EA's kill-switch DD%</span>
  <span>&#128993; yellow = max DD hit the declared warn level (MT4 25% / MT5 15%; EA-specific: 80% of kill)</span>
  <span>&#128994; green = normal, below warn band</span>
  <span>&#9898; white = 0 trades yet (no data)</span>
  <span>&#10067; unmapped magic (present in CSV, not in the declared cohort table)</span>
  <br><br>
  Colors are flags against the declared kill-switch DD% from <code>_demo_deploy\README_DEPLOY.md</code>
  only - not a keep/kill verdict. Max DD% is computed from the cumulative per-magic P&amp;L curve
  (profit+swap+commission per deal, time-ordered) against an assumed $baseEquityStr USD starting equity
  (both treasure-hunt demo accounts are documented at 10,000 USD). Sorted red &rarr; yellow &rarr; green &rarr; white &rarr; unmapped.
</div>

<table>
<tr>
  <th>Status</th><th>EA</th><th>Magic</th><th>Symbol</th><th>Trades</th>
  <th>Net P&amp;L</th><th>PF</th><th>Max DD%</th><th>Kill DD%</th><th>Days idle</th><th>Detail</th>
</tr>
$($tableRowsHtml.ToString())
</table>

<div class="footer">
  Grand total net P&amp;L across all magics in this CSV (incl. unmapped/balance rows): $grandTotalDisplay &middot;
  total deal rows: $grandTotalRows &middot; generated by scripts\live_dashboard.ps1 (ORDER-058)
</div>
</body>
</html>
"@

$html | Out-File -FilePath $OutFile -Encoding utf8 -Force
Write-Host "wrote $OutFile"
Write-Host "grand total net P&L (all magics): $grandTotalDisplay  ($grandTotalRows deal rows)"
