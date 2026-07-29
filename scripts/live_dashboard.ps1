<#
live_dashboard.ps1 - ORDER-058: per-EA live-monitor dashboard (ต่อยอด DealsExporter/ORDER-039+042)

Reads the newest EA_LAB_deals_*.csv snapshot in portfolio\live_deals\ (collected by
collect_live_deals.ps1 from DealsExporter.mq5), groups deals by magic number, joins EA
name/symbol/kill-switch DD% from the cohort map generated from portfolio\DEPLOYMENTS.csv
(single inventory owner, ORDER-093; generation replaced the hardcoded table per CR-001
2026-07-19), and writes a single self-contained HTML file: portfolio\LIVE_DASHBOARD.html

  powershell -File scripts\live_dashboard.ps1
  powershell -File scripts\live_dashboard.ps1 -LiveDealsDir <dir> -OutFile <path>   (testing)

Columns per EA row: name, magic, symbol, trades, net P&L, profit factor, max drawdown %
(computed from the cumulative per-magic P&L curve against THAT ACCOUNT'S base equity from
portfolio\ACCOUNTS.csv), days since last trade, and a status flag:
  red    = maxDD% >= that EA's kill-switch DD%
  yellow = maxDD% >= declared warn level (MT4 25% / MT5 15%; EA-specific kill: 80% of kill)
  green  = below that
  white  = 0 trades for this magic yet (no data)
  grey ? = magic present in the CSV but not in the cohort table (unmapped, no criteria)
  blue ? = the account has no base_equity recorded, so DD% is not computable and is
           SUPPRESSED rather than guessed (see the base-equity note below)

BASE EQUITY (2026-07-30, Stage 0B D3). This script used to apply one hardcoded
$BaseEquity = 10000 to every account, on the strength of a comment saying "both
treasure-hunt demo accounts are documented as $10k". There are six accounts, they are not
all demo, they are not all in the same currency, and portfolio\ACCOUNTS.csv - the owner of
that field - records a base_equity for exactly ONE of them (463666728 = 100000). Every
DD% and every kill-DD-equivalent on the other five was therefore a real-looking number
divided by a denominator nobody had ever recorded, and 463666728's were out by 10x in the
direction that makes risk look larger than it is. Base equity is now resolved PER ACCOUNT
from ACCOUNTS.csv, and an account with no recorded value renders UNKNOWN with its derived
numbers suppressed. Expect most accounts to read UNKNOWN today: that is the honest state
of the owner file, and it is the point - a suppressed number asks to be fixed, a wrong one
does not.

ACCOUNT UNIVERSE (Stage 0B D4). The account list comes from portfolio\ACCOUNTS.csv. A
login that appears in collected data but is not registered there - e.g. 146237, a Strategy
Tester login that monitor_rotation.ps1 authenticates - is rendered as UNREGISTERED with the
file it came from, never silently dropped and never counted as a lab account. Hiding it is
how work disappears; classifying it is the requirement.
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
  # Owner of governance_scope and base_equity. There is deliberately NO -BaseEquity
  # parameter and no global default any more: a single number applied to six accounts is
  # the defect (see the header). If a value is missing here, the answer is UNKNOWN.
  [string]$AccountsCsv  = ""
)
$ErrorActionPreference = "Stop"
if (-not $AccountsCsv) { $AccountsCsv = Join-Path (Split-Path $LiveDealsDir -Parent) 'ACCOUNTS.csv' }

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
# 3. cohort map: magic -> EA meta + declared kill-switch DD%
#    CR-001 (ROADMAP Phase 4.5, 2026-07-19): GENERATED from portfolio\DEPLOYMENTS.csv
#    (the single deployment inventory owner, ORDER-093) - the old hardcoded table is
#    gone, so a new CSV row is monitored automatically and a removed row can never
#    linger as a ghost. check_state.ps1 checks 4/5 now verify this generation link
#    instead of literal map entries.
#    KillDD: parsed from kill_rule ("closedDD N%" / "DD N%"). Rules that are not a
#            closed-DD number (e.g. "manual kill floating DD 40%") and empty rules
#            fall back to the platform default (MT4 35% / MT4 warn 25% · MT5 25% /
#            warn 15%) and keep the raw rule text in the display name.
#    WarnDD: platform warn for platform-default kills; else uniformly 80% of kill.
#            NOTE this changed a few advisory warn thresholds vs the old hand table
#            (old table was ad-hoc: e.g. kill15 -> warn10; now kill15 -> warn12).
#            Kill thresholds (the red flag + DEPLOYMENTS.csv) are unchanged.
#    Rows with non-numeric magic (UNVERIFIED) are skipped; non-ACTIVE rows are kept
#    (their closed-deal history still renders) with the status tagged in the name.
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# 2b. account registry: portfolio\ACCOUNTS.csv is the owner of governance_scope
#     and base_equity (Stage 0B D3/D4).
#
#     Two lookups come out of it and they answer two different questions:
#       $acctRegistered  is this login a lab account at all?  (D4)
#       $acctBase        what do we divide by to get a DD%?   (D3)
#
#     $acctBase[$a] is $null - NOT a fallback number - whenever base_equity is
#     blank, non-numeric, or <= 0. Every consumer below must branch on that null
#     and render UNKNOWN. The one thing it must never do is substitute a value:
#     the whole defect was a plausible number standing in for a missing one.
# ---------------------------------------------------------------------------
$acctRegistered = @{}
$acctBase = @{}
$acctScope = @{}
$acctCsvName = @{}
$acctCcy = @{}
if (Test-Path $AccountsCsv) {
  foreach ($ar in @(Import-Csv $AccountsCsv)) {
    $a = "$($ar.account)".Trim()
    if (-not $a) { continue }
    $acctRegistered[$a] = $true
    $acctScope[$a] = "$($ar.governance_scope)".Trim()
    $acctCsvName[$a] = "$($ar.account_name)".Trim()
    $acctCcy[$a] = "$($ar.currency)".Trim()
    $be = 0.0
    if ("$($ar.base_equity)".Trim() -and [double]::TryParse("$($ar.base_equity)".Trim(),
          [System.Globalization.NumberStyles]::Any,
          [System.Globalization.CultureInfo]::InvariantCulture, [ref]$be) -and $be -gt 0) {
      $acctBase[$a] = $be
    } else {
      $acctBase[$a] = $null
    }
  }
} else {
  # No registry = no account is registered and no base equity is known. Rendering the
  # whole board as UNKNOWN/UNREGISTERED is the correct answer to "the owner file is
  # gone"; quietly reverting to a hardcoded 10000 is the behaviour being removed.
  Write-Host "WARNING: no ACCOUNTS.csv at $AccountsCsv - every account will render UNREGISTERED and every DD% UNKNOWN"
}
function Get-AcctBase([string]$acct) {
  if ($acctBase.ContainsKey($acct)) { return $acctBase[$acct] }
  return $null
}
# Plain text (callers HtmlEnc it). Every account header on the page goes through this, so
# an unregistered login is labelled as one everywhere it appears rather than in one place.
function Get-AcctLabel([string]$acct) {
  $label = "account $acct"
  if ($acctMeta.Contains($acct)) { $label = $acctMeta[$acct].Label }
  elseif ($acctCsvName.ContainsKey($acct) -and $acctCsvName[$acct]) { $label = $acctCsvName[$acct] }
  if (-not $acctRegistered.ContainsKey($acct)) {
    return "$label [UNREGISTERED / not a lab account - no row in ACCOUNTS.csv]"
  }
  $scope = $acctScope[$acct]
  if ($scope) { $label += " [$scope]" }
  return $label
}
# Plain text. Says either the number or, loudly, that there is not one.
function Get-AcctBaseText([string]$acct) {
  $b = Get-AcctBase $acct
  $ccy = ''
  if ($acctCcy.ContainsKey($acct) -and $acctCcy[$acct]) { $ccy = ' ' + $acctCcy[$acct] }
  if ($null -eq $b) { return "base equity UNKNOWN - no base_equity for $acct in ACCOUNTS.csv; DD% and kill-DD equivalents are SUPPRESSED, not estimated" }
  return ("base equity {0:N0}{1} (ACCOUNTS.csv)" -f [double]$b, $ccy)
}

$deploymentsCsv = Join-Path (Split-Path $LiveDealsDir -Parent) 'DEPLOYMENTS.csv'
$cohort = [ordered]@{}
foreach ($dep in @(Import-Csv $deploymentsCsv)) {
  if ($dep.magic -notmatch '^\d+$') { continue }
  $key = "$($dep.account)|$($dep.magic)"
  if ($cohort.Contains($key)) { continue }   # checker guards duplicates; first row wins
  $plat = 'MT5'; if ($dep.platform -match 'MT4') { $plat = 'MT4' }
  $defKill = 25.0; $defWarn = 15.0
  if ($plat -eq 'MT4') { $defKill = 35.0; $defWarn = 25.0 }
  $killDD = $null
  $rule = "$($dep.kill_rule)".Trim()
  if ($rule -notmatch 'floating' -and $rule -match '(?:closedDD|DD)\s*([0-9]+(?:\.[0-9]+)?)\s*%') {
    $killDD = [double]$Matches[1]
  }
  $name = $dep.ea_name
  if ($null -eq $killDD) {
    $killDD = $defKill; $warnDD = $defWarn
    if ($rule) { $name += " (kill: $rule)" }   # non-closedDD rule stays visible
  } elseif ($killDD -eq $defKill) {
    $warnDD = $defWarn
  } else {
    $warnDD = [math]::Round($killDD * 0.8, 1)
  }
  if ($dep.status -ne 'ACTIVE') { $name += " [$($dep.status)]" }
  # deals CSV symbol (broker-suffixed) overrides this; strip common m/c suffix for the fallback
  $sym = "$($dep.symbol)" -replace '[mc]$',''
  $cohort[$key] = @{ Name = $name; Symbol = $sym; Platform = $plat; KillDD = $killDD; WarnDD = $warnDD }
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
  # $baseEquity is deliberately UNTYPED so it can be $null. A [double] parameter would
  # coerce $null to 0.0 and hand every account a divide-by-zero-shaped denominator, which
  # is the same class of silent wrongness this change exists to remove. When it is $null
  # the returned MaxDDPct is $null too: not 0, which reads as "no drawdown".
  param($deals, $baseEquity)

  $haveBase = ($null -ne $baseEquity -and [double]$baseEquity -gt 0)
  $sorted = $deals | Sort-Object Time

  $trades = 0
  $grossProfit = 0.0
  $grossLoss = 0.0
  $netPL = 0.0
  $lastTradeTime = $null
  $symbol = ""

  $running = 0.0; $peak = 0.0
  if ($haveBase) { $running = [double]$baseEquity; $peak = [double]$baseEquity }
  $maxDDPct = $null
  if ($haveBase) { $maxDDPct = 0.0 }

  foreach ($row in $sorted) {
    if ([string]::IsNullOrWhiteSpace($symbol)) { $symbol = $row.Symbol }
    $netPL += $row.RowNet
    if ($haveBase) {
      $running += $row.RowNet
      if ($running -gt $peak) { $peak = $running }
      if ($peak -gt 0) {
        $ddPct = (($peak - $running) / $peak) * 100.0
        if ($ddPct -gt $maxDDPct) { $maxDDPct = $ddPct }
      }
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

  $m = Compute-MagicMetrics -deals $deals -baseEquity (Get-AcctBase $acc)

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
    $statusIcon = "white"; $statusLabel = "no data yet"; $rank = 4
  } elseif (-not $inCohort) {
    $statusIcon = "grey"; $statusLabel = "unmapped magic - no declared criteria"; $rank = 5
  } elseif ($null -eq $m.MaxDDPct) {
    # D3: the account has traded and has declared criteria, but base_equity is not
    # recorded, so there is nothing to express the drawdown as a percentage OF. This
    # is its own status, ranked above green on purpose - an unmeasurable EA is a more
    # urgent thing to look at than a measured healthy one, and burying it in green is
    # how it stays unfixed. The DD and kill columns render UNKNOWN, not a number.
    $statusIcon = "nobase"
    $statusLabel = "DD% NOT COMPUTABLE - account $acc has no base_equity in ACCOUNTS.csv (kill $($meta.KillDD)% cannot be evaluated)"
    $rank = 1
  } else {
    $killDD = $meta.KillDD
    $warnDD = $meta.WarnDD
    if ($m.MaxDDPct -ge $killDD) {
      $statusIcon = "red"; $statusLabel = "DD $([Math]::Round($m.MaxDDPct,1))% >= kill $killDD%"; $rank = 0
    } elseif ($m.MaxDDPct -ge $warnDD) {
      $statusIcon = "yellow"; $statusLabel = "DD $([Math]::Round($m.MaxDDPct,1))% >= warn $warnDD% (kill $killDD%)"; $rank = 2
    } else {
      $statusIcon = "green"; $statusLabel = "DD $([Math]::Round($m.MaxDDPct,1))% normal (kill $killDD%)"; $rank = 3
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
    $label = Get-AcctLabel $login

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

    [void]$fh.AppendLine("<div class=`"acct-head`"><b>$(HtmlEnc $login)</b> &middot; $(HtmlEnc $label) &middot; snapshot $(HtmlEnc $acctRow.server_time) &middot; $(HtmlEnc (Get-AcctBaseText $login))</div>")
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
          # D3: the kill-DD equivalent is a CURRENCY amount, so it needs this account's
          # base equity. With none recorded there is no equivalent to compute, and the
          # old code computed one anyway from a global 10000 - producing a red flag, or
          # the absence of one, on an account whose real base was never known.
          $panelBase = Get-AcctBase $login
          if ($null -eq $panelBase) {
            $flag = "kill $($cohort[$key].KillDD)% ref &mdash; <b>UNKNOWN</b>: no base_equity for account $(HtmlEnc $login) in ACCOUNTS.csv, so no currency equivalent can be computed"
            $rowCls = ' class="st-nobase"'
          } else {
            $killAbs = $cohort[$key].KillDD / 100.0 * [double]$panelBase
            if ((ToDbl $mr.float_pl) -le (-1.0 * $killAbs)) {
              $flag = "float loss &ge; kill-DD equivalent ($($cohort[$key].KillDD)% of $('{0:N0}' -f [double]$panelBase))"
              $rowCls = ' class="st-red"'
            } else {
              $flag = "kill $($cohort[$key].KillDD)% ref ($('{0:N0}' -f $killAbs))"
            }
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
  nobase = "&#128309;"  # blue circle - measurable-in-principle, not measurable today
}
$rowClassMap = @{
  red    = "st-red"
  yellow = "st-yellow"
  green  = "st-green"
  white  = "st-white"
  grey   = "st-grey"
  nobase = "st-nobase"
}
# D3: a DD cell with no base equity behind it prints the word, never a number. "0.0%"
# would be indistinguishable from a real, healthy measurement.
function Fmt-DD {
  param($ddPct)
  if ($null -eq $ddPct) { return "UNKNOWN" }
  return "$([Math]::Round([double]$ddPct,1))%"
}

# --- one <section> per account: header (label + window + subtotal) + its own table ---
$theadHtml = "<tr><th>Status</th><th>EA</th><th>Magic</th><th>Symbol</th><th>Trades</th><th>Net P&amp;L</th><th>PF</th><th>Max DD%</th><th>Kill DD%</th><th>Days idle</th><th>Detail</th></tr>"

$accOrder = @{}
foreach ($k in $acctMeta.Keys) { $accOrder[$k] = $acctMeta[$k].Order }

$sectionsHtml = New-Object System.Text.StringBuilder
$accGroups = $rowsSorted | Group-Object Acc | Sort-Object { if ($accOrder.ContainsKey($_.Name)) { $accOrder[$_.Name] } else { 99 } }, Name
foreach ($ag in $accGroups) {
  $accId = $ag.Name
  $label = Get-AcctLabel $accId
  $winTxt = "all history"
  if ($acctStart.ContainsKey($accId)) { $winTxt = "from $($acctStart[$accId].ToString('yyyy-MM-dd'))" }
  $subNet = ($ag.Group | Measure-Object NetPL -Sum).Sum
  $subTrades = ($ag.Group | Measure-Object Trades -Sum).Sum
  $subClass = "neu"; if ($subNet -gt 0) { $subClass = "pos" }; if ($subNet -lt 0) { $subClass = "neg" }

  [void]$sectionsHtml.AppendLine("<div class=`"card acct-card`">")
  [void]$sectionsHtml.AppendLine("<div class=`"acct-head`"><b>$(HtmlEnc $accId)</b> &middot; $(HtmlEnc $label) &middot; window: $winTxt &middot; net <span class=`"$subClass`">$(Fmt-Money $subNet)</span> &middot; $subTrades trades &middot; $(HtmlEnc (Get-AcctBaseText $accId))</div>")
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
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$(Fmt-DD $r.MaxDDPct)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$(HtmlEnc $r.KillDD)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"num-cell`">$(Fmt-Days $r.DaysSince)</td>")
    [void]$sectionsHtml.AppendLine("<td class=`"label-cell`">$(HtmlEnc $r.StatusLabel)</td>")
    [void]$sectionsHtml.AppendLine("</tr>")
  }
  [void]$sectionsHtml.AppendLine("</table>")
  [void]$sectionsHtml.AppendLine("</div>")
}

# ---------------------------------------------------------------------------
# 6c. Stage 0B D4: account-universe banner.
#
#     The canonical account universe is portfolio\ACCOUNTS.csv. The dashboard, however,
#     reads whatever CSVs happen to be sitting in live_deals\, and monitor_rotation.ps1
#     authenticates logins that are not lab accounts at all - 146237 is a Strategy Tester
#     login, stale since 2026-07-06, and it has been appearing in the "Accounts:" line of
#     this page ever since, indistinguishable from a real one.
#
#     The fix is NOT to filter it out. A login that showed up in collected data is a fact
#     about the machine, and a filter would delete the fact while leaving the cause. It is
#     classified instead: named, with the file it came from, under a heading that says it
#     is not a lab account. Two accounts are also called out the other way - registered in
#     ACCOUNTS.csv but with no collected data at all - because a missing sensor is exactly
#     as interesting as an unexpected one, and only one of the two was ever visible.
# ---------------------------------------------------------------------------
$seenLogins = @{}
foreach ($f in $selected) {
  if ($f.BaseName -match '^(?:EA_LAB_deals|EA_LAB_mt4_orders)_(\d+)') {
    $lg = $Matches[1]
    if (-not $seenLogins.ContainsKey($lg)) { $seenLogins[$lg] = New-Object System.Collections.Generic.List[string] }
    $seenLogins[$lg].Add($f.Name)
  }
}
foreach ($lg in $snapByLogin.Keys) {
  if (-not $seenLogins.ContainsKey($lg)) { $seenLogins[$lg] = New-Object System.Collections.Generic.List[string] }
  $seenLogins[$lg].Add($snapByLogin[$lg].Name)
}
$unregLogins = @($seenLogins.Keys | Where-Object { -not $acctRegistered.ContainsKey($_) } | Sort-Object)
$noDataLogins = @($acctRegistered.Keys | Where-Object { -not $seenLogins.ContainsKey($_) } | Sort-Object)

$universeHtml = ""
if ($unregLogins.Count -gt 0 -or $noDataLogins.Count -gt 0) {
  $ub = New-Object System.Text.StringBuilder
  [void]$ub.AppendLine('<div class="card">')
  [void]$ub.AppendLine('<h2 style="font-size:16px;margin:0 0 8px 0;">&#9888;&#65039; ACCOUNT UNIVERSE &mdash; collected data vs portfolio\ACCOUNTS.csv</h2>')
  [void]$ub.AppendLine('<table>')
  [void]$ub.AppendLine('<tr><th>Login</th><th>Classification</th><th>Provenance</th></tr>')
  foreach ($lg in $unregLogins) {
    [void]$ub.AppendLine("<tr class=`"st-grey`"><td class=`"num-cell`"><b>$(HtmlEnc $lg)</b></td><td class=`"label-cell`">UNREGISTERED &mdash; not a lab account (no row in ACCOUNTS.csv). Its rows below, if any, are shown but must not be read as lab evidence.</td><td class=`"label-cell`">$(HtmlEnc (($seenLogins[$lg] | Sort-Object) -join ', '))</td></tr>")
  }
  foreach ($lg in $noDataLogins) {
    $sc = $acctScope[$lg]; if (-not $sc) { $sc = 'unknown scope' }
    [void]$ub.AppendLine("<tr class=`"st-white`"><td class=`"num-cell`"><b>$(HtmlEnc $lg)</b></td><td class=`"label-cell`">REGISTERED ($(HtmlEnc $sc)) but NO collected data in this run &mdash; the sensor produced nothing to render.</td><td class=`"label-cell`">$(HtmlEnc (Get-AcctLabel $lg))</td></tr>")
  }
  [void]$ub.AppendLine('</table>')
  [void]$ub.AppendLine('</div>')
  $universeHtml = $ub.ToString()
}

$acctWindowsDisplay = HtmlEnc (($acctStart.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key) from $($_.Value.ToString('yyyy-MM-dd'))" }) -join ' | ')
# high-impact news fragment (written by scripts\news_calendar.ps1 in the daily chain)
$newsHtml = ""
$newsFrag = Join-Path (Split-Path $OutFile) "news_today.html"
if (Test-Path $newsFrag) { $newsHtml = [System.IO.File]::ReadAllText($newsFrag, [System.Text.Encoding]::UTF8) }
# MRIS macro "market whisper" fragment (written by scripts\mris\mris_run.ps1 in the daily
# chain). Wrapped in a .card so it inherits the dashboard's light/dark box styling.
$mrisHtml = ""
$mrisFrag = Join-Path (Split-Path $OutFile) "mris\whisper_brief.html"
if (Test-Path $mrisFrag) {
  $mrisInner = [System.IO.File]::ReadAllText($mrisFrag, [System.Text.Encoding]::UTF8)
  if ($mrisInner.Trim()) { $mrisHtml = "<div class=`"card`">$mrisInner</div>" }
}
$grandTotalDisplay = Fmt-Money $grandTotalNet
$generatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss")
$srcCsvName = HtmlEnc (($selected | ForEach-Object { $_.Name }) -join ', ')
# D3: one line per account, so the reader can see WHICH denominator produced the DD%
# column next to it - and how many of them do not exist.
$baseEquityStr = HtmlEnc ((@($acctRegistered.Keys | Sort-Object | ForEach-Object {
    $b = Get-AcctBase $_
    if ($null -eq $b) { "$_ = UNKNOWN" } else { ("{0} = {1:N0}" -f $_, [double]$b) }
  })) -join ' | ')
$unknownBaseCount = @($acctRegistered.Keys | Where-Object { $null -eq (Get-AcctBase $_) }).Count

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
    tr.st-nobase { background: #14243a !important; }
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
  tr.st-nobase { background: #e8f0fb; }
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
  <span>&#128309; base equity UNKNOWN &mdash; DD% suppressed, not estimated</span>
  <br><br>
  Colors are flags against the declared kill-switch DD% from <code>portfolio\DEPLOYMENTS.csv</code>
  only - not a keep/kill verdict. Max DD% is computed from the cumulative per-magic P&amp;L curve
  (profit+swap+commission per deal, time-ordered) against <b>that account's own base equity</b>
  from <code>portfolio\ACCOUNTS.csv</code>:
  <code>$baseEquityStr</code>.
  <b>$unknownBaseCount registered account(s) have no base_equity recorded</b>; their DD% and
  kill-DD-equivalent cells read UNKNOWN and no number is computed for them. Until 2026-07-30 this
  page divided every account by a hardcoded 10,000 instead, which is why those cells used to show
  a number - fill the <code>base_equity</code> column in ACCOUNTS.csv to get them back honestly.
  Sorted red &rarr; unknown-base &rarr; yellow &rarr; green &rarr; white &rarr; unmapped.
</div>

$mrisHtml
$newsHtml
$universeHtml
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
