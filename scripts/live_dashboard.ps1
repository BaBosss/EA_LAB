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

ORDER-092 (2026-07-11): a FLOATING RISK panel renders ABOVE the closed-deals sections
from the newest EA_LAB_snapshot_<login>*.csv per account (AccountSnapshotExporter,
collected into the same $LiveDealsDir): equity vs balance, floating total, margin level
(green >500% / yellow 200-500% / red <200%), distance to stop-out, per-magic floating
baskets joined against the cohort map (unmapped magics tagged UNMAPPED), plus cross-
account aggregates (total XAU exposure, total floating). Snapshots older than 26h are
greyed with a STALE banner and excluded from aggregates - never rendered as current.
Shows "no snapshot data yet" when no snapshot CSVs exist; all prior behavior unchanged.
#>
[CmdletBinding()]
param(
  [string]$LiveDealsDir = "D:\EA_LAB\portfolio\live_deals",
  [string]$OutFile      = "D:\EA_LAB\portfolio\LIVE_DASHBOARD.html",
  [double]$BaseEquity   = 10000.0   # documented starting balance, both treasure-hunt demo accounts ($10k)
)
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# 0. per-account analysis window (user directive 2026-07-10): deals BEFORE the
#    account's start date are the user's earlier hand experiments - exclude them
#    from every metric or they poison PF/DD of the current cohort.
#    159503454: old bot closes Mar-May 2026, current cohort attached 2026-07-09
#    415573666: natural gap 2026-05-21..26 (old experiment ended 05-20, new set from 05-27)
# ---------------------------------------------------------------------------
$acctStart = @{
  '141049900' = [datetime]'2026-05-26'
  '159475669' = [datetime]'2026-05-26'
  '415573666' = [datetime]'2026-07-06'   # was 05-26; user confirmed 2026-07-10 the magic-12345 XAU run (05-27..07-03, -3.5k) was an abandoned experiment -> window starts at Boss_14 attach
  '159503454' = [datetime]'2026-07-01'
}

# display meta per account (DEMO_DEPLOYMENT_PLAN "DEPLOYMENT REALITY 2026-07-09") - Order controls section order
$acctMeta = [ordered]@{
  '159503454' = @{ Label = "Blazing Arrow — REAL cent · MT5 cohort 5 EA (validated)";            Order = 1 }
  '159475669' = @{ Label = "Boss - Trend Swing — REAL cent · user mix (lab ไม่รับรองบางตัว)";      Order = 2 }
  '141049900' = @{ Label = "Celestial Woodfire — REAL cent · MT4 gold fleet (user experiment)";  Order = 3 }
  '415573666' = @{ Label = "Demo Mt5-2 — DEMO · Boss_14_GridLog bench x7 symbols";               Order = 4 }
  '69424711'  = @{ Label = "Demo EA3 — DEMO MT4 cohort (monitor deferred)";                      Order = 5 }
}

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
  "69424711|1"      = @{ Name = "UnNomGuaiV1.132";                                 Symbol = "EURUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "69424711|2"      = @{ Name = "UnNomGuaiV1.132";                                 Symbol = "EURUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "69424711|5888"   = @{ Name = "RSI from pips_EA (RSI-orig)";                     Symbol = "EURUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "69424711|990"    = @{ Name = "swb grid 4.1.0.3_h";                              Symbol = "AUDCAD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "159503454|990103" = @{ Name = "(Boss)_RSI_MR_GridLog (RSI-MR)";                  Symbol = "EURUSD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "159503454|990101" = @{ Name = "(Boss)_ZeusInspired_GridLog (Zeus)";              Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 15.0; WarnDD = 12.0 }
  "159503454|991001" = @{ Name = "EA_BREAKOUT_XAU (BRK-XAU)";                       Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 10.0; WarnDD = 8.0 }
  "159503454|991004" = @{ Name = "(BRK)_SqueezeBreakout (SqueezeBRK)";              Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 10.0; WarnDD = 8.0 }
  "159503454|991002" = @{ Name = "(BRK)_TrendlineBreakout (Trendline, EXPERIMENTAL)"; Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 8.0;  WarnDD = 6.4 }
  # Boss_14 GridLog demo bench on 415573666 (DEMO_DEPLOYMENT_PLAN cohort-1 table; MT5 platform default kill/warn)
  "415573666|990201" = @{ Name = "Boss_14_GridLog USDJPY";                           Symbol = "USDJPY"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "415573666|990202" = @{ Name = "Boss_14_GridLog AUDNZD";                           Symbol = "AUDNZD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "415573666|990203" = @{ Name = "Boss_14_GridLog EURJPY (size-light)";              Symbol = "EURJPY"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "415573666|990204" = @{ Name = "Boss_14_GridLog AUDCAD";                           Symbol = "AUDCAD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "415573666|990205" = @{ Name = "Boss_14_GridLog CADJPY (size-light, thin)";        Symbol = "CADJPY"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "415573666|990206" = @{ Name = "Boss_14_GridLog EURUSD SELL";                      Symbol = "EURUSD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "415573666|990207" = @{ Name = "Boss_14_GridLog XAUUSD";                           Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  # SuperTrend demo bench (user approved 2026-07-11, attach pending) - mapped BEFORE attach per audit A5 lesson
  "415573666|990020" = @{ Name = "EA_SUPERTREND XAU H4 (demo tracking, criterion-7)";  Symbol = "XAUUSD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  # 141049900 REAL MT4 user-experiment cohort (CODEX-AUDIT A5 2026-07-11: was unmapped = the
  # highest-risk no-SL magics had no dashboard row at all). MT4 platform default kill/warn.
  # NOTE: closed-deal DD only - Zeus/Kangaroo real risk is FLOATING basket loss (Zeus floating
  # kill guidance = 40% MANUAL per DEMO_DEPLOYMENT_PLAN); dashboard cannot see it until the
  # floating-telemetry exporter (ORDER-092) ships.
  "141049900|7777"   = @{ Name = "Zeus Gold Hedge V1.2 EURUSDc (no-SL grid ⚠️ manual kill float 40%)"; Symbol = "EURUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "141049900|1112"   = @{ Name = "Gold_Kangaroo XAUUSDc L1 (capped-mart, not validated)";              Symbol = "XAUUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "141049900|1113"   = @{ Name = "Gold_Kangaroo XAUUSDc L2 (capped-mart, not validated)";              Symbol = "XAUUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "141049900|1114"   = @{ Name = "Gold_Kangaroo XAUUSDc L3 (capped-mart, not validated)";              Symbol = "XAUUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  "141049900|1115"   = @{ Name = "Gold_Kangaroo XAUUSDc L4 (capped-mart, not validated)";              Symbol = "XAUUSD"; Platform = "MT4"; KillDD = 35.0; WarnDD = 25.0 }
  # 159475669 user-mix magics we can name (no lab-declared kill for this account -> MT5 platform defaults)
  "159475669|1524"   = @{ Name = "NuiIndy Dynamic RSI+ADX";                          Symbol = "EURUSD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "159475669|9398"   = @{ Name = "ST_EA03 Count-MACD USDCAD (lab live)";             Symbol = "USDCAD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "159475669|939721" = @{ Name = "ST_EA03 Count-MACD GBP (user config, recovery-lot ⚠️)"; Symbol = "GBPUSD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "159475669|990005" = @{ Name = "CB_GBP ConsoBreakout";                             Symbol = "GBPUSD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
  "159475669|990010" = @{ Name = "ST03 replica (WATCH: OOS 0.86)";                   Symbol = "GBPUSD"; Platform = "MT5"; KillDD = 25.0; WarnDD = 15.0 }
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

# "login|magic" (string) -> array of parsed deal objects
$byMagic = @{}

$filteredOld = 0
foreach ($file in $selected) {
  $isMT4 = $file.BaseName -like 'EA_LAB_mt4_orders_*'
  $fileLogin = ""; if ($file.BaseName -match '^(?:EA_LAB_deals|EA_LAB_mt4_orders)_(\d+)') { $fileLogin = $Matches[1] }
  $startCut = $null; if ($fileLogin -and $acctStart.ContainsKey($fileLogin)) { $startCut = $acctStart[$fileLogin] }
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

    if ($startCut -and $dt -lt $startCut) { $filteredOld++; continue }   # pre-window hand experiments

    $rowNet = $profit + $swap + $commission

    if (-not $isMT4) {
      # MT5 deal type > 1 = balance/credit/correction op, not a trade: keep it out of every
      # EA row and account subtotal (a 10k deposit is not P&L) - count in grand total only
      $t5 = -1
      if (-not [int]::TryParse($d.type, [ref]$t5) -or $t5 -lt 0 -or $t5 -gt 1) {
        $grandTotalNet += $rowNet; $grandTotalRows++
        continue
      }
    }

    $obj = [pscustomobject]@{
      Ticket  = $ticket
      Time    = $dt
      Symbol  = $symbol
      Magic   = $magic
      Acc     = $fileLogin
      Entry   = $entryVal
      Volume  = $volume
      RowNet  = $rowNet
      Profit  = $profit
    }

    $key = "$fileLogin|$magic"
    if (-not $byMagic.ContainsKey($key)) { $byMagic[$key] = New-Object System.Collections.Generic.List[object] }
    $byMagic[$key].Add($obj)

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

$allKeys = New-Object System.Collections.Generic.List[string]
foreach ($k in $cohort.Keys) { $allKeys.Add($k) }
foreach ($k in $byMagic.Keys) { if (-not $allKeys.Contains($k)) { $allKeys.Add($k) } }

foreach ($key in $allKeys) {
  $acc = "?"; $magic = $key
  if ($key -match '^(\d+)\|(.*)$') { $acc = $Matches[1]; $magic = $Matches[2] }
  $inCohort = $cohort.Contains($key)
  $meta = $null
  if ($inCohort) { $meta = $cohort[$key] }

  $deals = New-Object System.Collections.Generic.List[object]
  if ($byMagic.ContainsKey($key)) { $deals = $byMagic[$key] }

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
    Acc        = $acc
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
# 6b. ORDER-092 FLOATING RISK panel - parse the newest EA_LAB_snapshot_<login>
#     CSV per account (written by AccountSnapshotExporter every 60s, collected
#     by collect_live_deals.ps1). This is the ONLY part of the dashboard that
#     can see open baskets / margin pressure; everything below it is closed
#     history. Snapshots older than 26h render GREYED with a STALE banner -
#     never as current data.
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

function HtmlEnc {
  param([string]$s)
  if ($null -eq $s) { return "" }
  try { return [System.Web.HttpUtility]::HtmlEncode($s) } catch { return $s }
}

function ToDbl([string]$s) {
  $v = 0.0
  [void][double]::TryParse($s, [System.Globalization.NumberStyles]::Any,
                           [System.Globalization.CultureInfo]::InvariantCulture, [ref]$v)
  return $v
}

$accOrder = @{}
foreach ($k in $acctMeta.Keys) { $accOrder[$k] = $acctMeta[$k].Order }

$snapStaleHours = 26
$snapFiles = @(Get-ChildItem (Join-Path $LiveDealsDir "EA_LAB_snapshot_*.csv") -ErrorAction SilentlyContinue |
               Where-Object { $_.BaseName -match '^EA_LAB_snapshot_(\d+)' })
$snapByLogin = @{}
foreach ($grp in ($snapFiles | Group-Object { if ($_.BaseName -match '^EA_LAB_snapshot_(\d+)') { $Matches[1] } else { '' } })) {
  if (-not $grp.Name) { continue }
  $snapByLogin[$grp.Name] = $grp.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$fh = New-Object System.Text.StringBuilder
[void]$fh.AppendLine('<div class="card">')
[void]$fh.AppendLine('<h2 style="font-size:16px;margin:0 0 8px 0;">&#9888;&#65039; FLOATING RISK &mdash; open baskets / margin (snapshot exporter, ORDER-092)</h2>')

if ($snapByLogin.Count -eq 0) {
  [void]$fh.AppendLine('<div class="meta" style="margin:0;">no snapshot data yet &mdash; AccountSnapshotExporter not attached / not collected. Closed-deal tables below CANNOT see floating basket loss on no-SL grid EAs.</div>')
} else {
  # aggregates are computed from FRESH snapshots only; stale accounts are listed as excluded
  $aggFloat = 0.0; $aggXauLots = 0.0; $aggXauFloat = 0.0
  $aggFreshAccts = @(); $aggStaleAccts = @()

  $snapLoginsOrdered = $snapByLogin.Keys | Sort-Object { if ($accOrder.ContainsKey($_)) { $accOrder[$_] } else { 99 } }, { $_ }
  foreach ($login in $snapLoginsOrdered) {
    $sf = $snapByLogin[$login]
    $ageH = ((Get-Date) - $sf.LastWriteTime).TotalHours
    $isStale = ($ageH -gt $snapStaleHours)

    $acctRow = $null; $magicRows = @(); $symbolRows = @()
    foreach ($r in @(Import-Csv -Path $sf.FullName)) {
      switch ($r.row_type) {
        'ACCOUNT' { $acctRow = $r }
        'MAGIC'   { $magicRows += $r }
        'SYMBOL'  { $symbolRows += $r }
      }
    }
    $label = "account $login"
    if ($acctMeta.Contains($login)) { $label = $acctMeta[$login].Label }

    $cardClass = 'card acct-card'
    if ($isStale) { $cardClass = 'card acct-card snap-stale' }
    [void]$fh.AppendLine("<div class=`"$cardClass`">")

    if ($isStale) {
      $tsTxt = $sf.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
      if ($acctRow -and $acctRow.server_time) { $tsTxt = "$($acctRow.server_time) server time (file $tsTxt)" }
      [void]$fh.AppendLine("<div class=`"stale-banner`">STALE &mdash; snapshot from $(HtmlEnc $tsTxt) ($([math]::Round($ageH,1)) h old &gt; $snapStaleHours h) &mdash; NOT current data</div>")
      $aggStaleAccts += $login
    } else {
      $aggFreshAccts += $login
    }

    if (-not $acctRow) {
      [void]$fh.AppendLine("<div class=`"acct-head`"><b>$(HtmlEnc $login)</b> &middot; $(HtmlEnc $label) &middot; snapshot file has no ACCOUNT row (corrupt?)</div>")
      [void]$fh.AppendLine('</div>')
      continue
    }

    $eq   = ToDbl $acctRow.equity
    $bal  = ToDbl $acctRow.balance
    $mgn  = ToDbl $acctRow.margin
    $ml   = ToDbl $acctRow.margin_level_pct
    $so   = ToDbl $acctRow.stopout_level
    $ccy  = $acctRow.currency
    $floatTotal = $eq - $bal

    # margin level color: green >500%, yellow 200-500%, red <200% (ORDER-092 spec)
    $mlClass = 'neu'; $mlTxt = 'no margin used'
    $distTxt = '-'
    if ($mgn -gt 0) {
      $mlTxt = ('{0:N1}%' -f $ml)
      if ($ml -lt 200) { $mlClass = 'ml-red' } elseif ($ml -le 500) { $mlClass = 'ml-yellow' } else { $mlClass = 'ml-green' }
      if ($acctRow.stopout_mode -eq 'PERCENT') {
        $distTxt = ('{0:N1} pp above stop-out ({1:N1}%)' -f ($ml - $so), $so)
      } else {
        $fm = ToDbl $acctRow.free_margin
        $distTxt = ('{0:N2} {1} free margin above stop-out ({2:N2} {1})' -f ($fm - $so), $ccy, $so)
      }
    }
    $floatClass = 'neu'; if ($floatTotal -gt 0) { $floatClass = 'pos' }; if ($floatTotal -lt 0) { $floatClass = 'neg' }

    if (-not $isStale) {
      $aggFloat += $floatTotal
      foreach ($sr in $symbolRows) {
        if ($sr.symbols -match 'XAU') { $aggXauLots += (ToDbl $sr.open_lots); $aggXauFloat += (ToDbl $sr.float_pl) }
      }
    }

    [void]$fh.AppendLine("<div class=`"acct-head`"><b>$(HtmlEnc $login)</b> &middot; $(HtmlEnc $label) &middot; snapshot $(HtmlEnc $acctRow.server_time)</div>")
    [void]$fh.AppendLine("<div class=`"acct-head`">equity <b>$('{0:N2}' -f $eq)</b> vs balance <b>$('{0:N2}' -f $bal)</b> $(HtmlEnc $ccy) &middot; floating <span class=`"$floatClass`">$('{0:N2}' -f $floatTotal)</span> &middot; margin level <span class=`"$mlClass`">$mlTxt</span> &middot; distance to stop-out: $distTxt</div>")

    if ($magicRows.Count -eq 0) {
      [void]$fh.AppendLine('<div class="meta" style="margin:0;">no open positions / pending orders at snapshot time</div>')
    } else {
      [void]$fh.AppendLine('<table>')
      [void]$fh.AppendLine('<tr><th>EA (cohort map)</th><th>Magic</th><th>Symbols</th><th>Float P&amp;L</th><th>Lots</th><th>Basket depth (pos)</th><th>Oldest pos (h)</th><th>Pending</th><th>Flag</th></tr>')
      foreach ($mr in ($magicRows | Sort-Object { ToDbl $_.float_pl })) {
        $magic = "$($mr.magic)"
        $key = "$login|$magic"
        $name = ''
        $flag = ''
        $rowCls = ''
        if ($cohort.Contains($key)) {
          $name = HtmlEnc $cohort[$key].Name
          $killAbs = $cohort[$key].KillDD / 100.0 * $BaseEquity
          if ((ToDbl $mr.float_pl) -le (-1.0 * $killAbs)) {
            $flag = "float loss &ge; kill-DD equivalent ($($cohort[$key].KillDD)% of $('{0:N0}' -f $BaseEquity))"
            $rowCls = ' class="st-red"'
          } else {
            $flag = "kill $($cohort[$key].KillDD)% ref"
          }
        } elseif ($magic -eq '0') {
          $name = 'manual trades (magic 0)'
          $flag = 'no declared criteria'
        } else {
          $name = "&#9888;&#65039; UNMAPPED (magic $magic)"
          $flag = '&#9888;&#65039; UNMAPPED - not in cohort map'
          $rowCls = ' class="st-grey"'
        }
        $fpl = ToDbl $mr.float_pl
        $fplClass = 'neu'; if ($fpl -gt 0) { $fplClass = 'pos' }; if ($fpl -lt 0) { $fplClass = 'neg' }
        [void]$fh.AppendLine("<tr$rowCls><td class=`"name-cell`">$name</td><td class=`"num-cell`">$(HtmlEnc $magic)</td><td class=`"num-cell`">$(HtmlEnc $mr.symbols)</td><td class=`"num-cell $fplClass`">$('{0:N2}' -f $fpl)</td><td class=`"num-cell`">$(HtmlEnc $mr.open_lots)</td><td class=`"num-cell`">$(HtmlEnc $mr.open_positions)</td><td class=`"num-cell`">$(HtmlEnc $mr.oldest_open_hours)</td><td class=`"num-cell`">$(HtmlEnc $mr.pending_orders)</td><td class=`"label-cell`">$flag</td></tr>")
      }
      [void]$fh.AppendLine('</table>')
    }
    [void]$fh.AppendLine('</div>')
  }

  # aggregate rows (fresh snapshots only - stale accounts are never summed as current)
  $aggFloatClass = 'neu'; if ($aggFloat -gt 0) { $aggFloatClass = 'pos' }; if ($aggFloat -lt 0) { $aggFloatClass = 'neg' }
  $aggXauClass = 'neu'; if ($aggXauFloat -gt 0) { $aggXauClass = 'pos' }; if ($aggXauFloat -lt 0) { $aggXauClass = 'neg' }
  [void]$fh.AppendLine('<table>')
  [void]$fh.AppendLine('<tr><th>Aggregate (across all accounts with a FRESH snapshot)</th><th>Value</th></tr>')
  [void]$fh.AppendLine("<tr><td class=`"name-cell`">Total XAU-symbol exposure (all accounts)</td><td class=`"num-cell`">$('{0:N2}' -f $aggXauLots) lots &middot; floating <span class=`"$aggXauClass`">$('{0:N2}' -f $aggXauFloat)</span></td></tr>")
  [void]$fh.AppendLine("<tr><td class=`"name-cell`">Total floating P&amp;L (all accounts)</td><td class=`"num-cell`"><span class=`"$aggFloatClass`">$('{0:N2}' -f $aggFloat)</span></td></tr>")
  $cover = "fresh: $($aggFreshAccts -join ', ')"
  if ($aggStaleAccts.Count -gt 0) { $cover += " &middot; EXCLUDED stale: $($aggStaleAccts -join ', ')" }
  [void]$fh.AppendLine("<tr><td class=`"name-cell`">Coverage</td><td class=`"num-cell`">$cover</td></tr>")
  [void]$fh.AppendLine('</table>')
}
[void]$fh.AppendLine('</div>')
$floatingRiskHtml = $fh.ToString()

# ---------------------------------------------------------------------------
# 7. render HTML (Add-Type + HtmlEnc already loaded in section 6b)
# ---------------------------------------------------------------------------

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

# --- one <section> per account: header (label + window + subtotal) + its own table ---
$theadHtml = "<tr><th>Status</th><th>EA</th><th>Magic</th><th>Symbol</th><th>Trades</th><th>Net P&amp;L</th><th>PF</th><th>Max DD%</th><th>Kill DD%</th><th>Days idle</th><th>Detail</th></tr>"

$accOrder = @{}
foreach ($k in $acctMeta.Keys) { $accOrder[$k] = $acctMeta[$k].Order }

$sectionsHtml = New-Object System.Text.StringBuilder
$accGroups = $rowsSorted | Group-Object Acc | Sort-Object { if ($accOrder.ContainsKey($_.Name)) { $accOrder[$_.Name] } else { 99 } }, Name
foreach ($ag in $accGroups) {
  $accId = $ag.Name
  $label = "account $accId"
  if ($acctMeta.Contains($accId)) { $label = $acctMeta[$accId].Label }
  $winTxt = "all history"
  if ($acctStart.ContainsKey($accId)) { $winTxt = "from $($acctStart[$accId].ToString('yyyy-MM-dd'))" }
  $subNet = ($ag.Group | Measure-Object NetPL -Sum).Sum
  $subTrades = ($ag.Group | Measure-Object Trades -Sum).Sum
  $subClass = "neu"; if ($subNet -gt 0) { $subClass = "pos" }; if ($subNet -lt 0) { $subClass = "neg" }

  [void]$sectionsHtml.AppendLine("<div class=`"card acct-card`">")
  [void]$sectionsHtml.AppendLine("<div class=`"acct-head`"><b>$(HtmlEnc $accId)</b> &middot; $(HtmlEnc $label) &middot; window: $winTxt &middot; net <span class=`"$subClass`">$(Fmt-Money $subNet)</span> USC &middot; $subTrades trades</div>")
  [void]$sectionsHtml.AppendLine("<table>")
  [void]$sectionsHtml.AppendLine($theadHtml)
  foreach ($r in $ag.Group) {
    $icon = $iconMap[$r.StatusIcon]
    $rowClass = $rowClassMap[$r.StatusIcon]
    $netClass = "neu"
    if ($r.NetPL -gt 0) { $netClass = "pos" }
    if ($r.NetPL -lt 0) { $netClass = "neg" }

    [void]$sectionsHtml.AppendLine("<tr class=`"$rowClass`">")
    [void]$sectionsHtml.AppendLine("<td class=`"status-cell`" title=`"$(HtmlEnc $r.StatusLabel)`">$icon</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"name-cell`">$(HtmlEnc $r.Name)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$(HtmlEnc $r.Magic)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$(HtmlEnc $r.Symbol)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$($r.Trades)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell $netClass`">$(Fmt-Money $r.NetPL)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$(Fmt-PF $r.PF)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$([Math]::Round($r.MaxDDPct,1))%</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$(HtmlEnc $r.KillDD)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$(Fmt-Days $r.DaysSince)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"label-cell`">$(HtmlEnc $r.StatusLabel)</td>")
    [void]$sectionsHtml.AppendLine("</tr>")
  }
  [void]$sectionsHtml.AppendLine("</table>")
  [void]$sectionsHtml.AppendLine("</div>")
}

$acctWindowsDisplay = HtmlEnc (($acctStart.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key) from $($_.Value.ToString('yyyy-MM-dd'))" }) -join ' | ')
# high-impact news fragment (written by scripts\news_calendar.ps1 in the daily chain)
$newsHtml = ""
$newsFrag = Join-Path (Split-Path $OutFile) "news_today.html"
if (Test-Path $newsFrag) { $newsHtml = [System.IO.File]::ReadAllText($newsFrag, [System.Text.Encoding]::UTF8) }
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
    .ml-green  { color: #6fe08a !important; }
    .ml-yellow { color: #ffd54f !important; }
    .ml-red    { color: #ff8a80 !important; }
    .snap-stale { background: #202226 !important; }
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
  /* ORDER-092 floating-risk panel */
  .ml-green  { color: #17792f; font-weight: 700; }
  .ml-yellow { color: #9a7b00; font-weight: 700; }
  .ml-red    { color: #b3261e; font-weight: 700; }
  .snap-stale { opacity: 0.55; filter: grayscale(0.8); background: #ececec; }
  .stale-banner {
    background: #6d6d6d; color: #fff; font-weight: 700; font-size: 13px;
    padding: 6px 10px; border-radius: 6px; margin-bottom: 8px;
  }
  .acct-card { padding: 10px 12px; }
  .acct-head { font-size: 14px; margin-bottom: 8px; }
  .acct-card table { overflow-x: auto; display: block; }
  @media (max-width: 640px) {
    body { margin: 8px; }
    th, td { padding: 4px 6px; font-size: 12px; }
  }
</style>
</head>
<body>
<h1>EA_LAB Live Dashboard</h1>
<div class="meta">
  Generated: $generatedAt &middot; Source CSV: <code>$srcCsvName</code> &middot;
  Accounts: <code>$acctLogin</code><br>
  Analysis windows (deals before these dates = earlier hand experiments, excluded):
  <code>$acctWindowsDisplay</code> &middot; excluded rows: $filteredOld
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

$newsHtml
$floatingRiskHtml
$($sectionsHtml.ToString())

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
