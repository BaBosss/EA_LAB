# mris_web_feeder.ps1 - MRIS web barometer feeder (ORDER-073 Phase-2 macro layer)
# Fills the barometers the broker does NOT price (VIX, DXY, COPPER, US10Y proxy) by
# pulling free, no-key daily OHLC from the Yahoo Finance chart API, computing the
# same snapshot schema the classifier reads (spot / sma200 / atr20 / chg5d_pct), and
# MERGING them in-place into barometer_snapshot.csv WITHOUT clobbering the broker rows
# (AUDJPY / USDJPY / XAUUSD / BTCUSD written by Export_Barometers.mq5).
#
# Zero LLM tokens - pure script. Same resilience pattern as scripts\news_calendar.ps1:
# per-symbol raw-JSON cache, fall back to a fresh cache on fetch failure, and if there
# is neither fresh data nor cache, tag the row STALE so the classifier excludes it
# (weights renormalise) instead of crashing.
#
# NOTE on US10Y_JP10Y: JP10Y has no free headless daily source (BOJ-pinned ~1%, near
# static). Per user decision 2026-07-17 we feed US10Y (^TNX) as the spread proxy - the
# 5d move of the spread is ~entirely the US leg. source_note flags it as a proxy. The
# classifier's carry_fuel/narrowing branch reads the 5d bps move to score it.
[CmdletBinding()]
param(
  [string]$Snapshot = "D:\EA_LAB\portfolio\mris\barometer_snapshot.csv",
  [string]$CacheDir = "D:\EA_LAB\portfolio\mris\webfeed_cache",
  [int]$CacheMaxHours = 20,
  [int]$TimeoutSec = 25
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# web-owned barometers: snapshot symbol -> Yahoo ticker (+ how to note the source)
$FEEDS = @(
  @{ Symbol="VIX";          Yahoo="^VIX";     Note="Yahoo ^VIX (CBOE Volatility Index)" },
  @{ Symbol="DXY";          Yahoo="DX-Y.NYB"; Note="Yahoo DX-Y.NYB (ICE US Dollar Index)" },
  @{ Symbol="COPPER";       Yahoo="HG=F";     Note="Yahoo HG=F (COMEX copper front future)" },
  @{ Symbol="US10Y_JP10Y";  Yahoo="^TNX";     Note="Yahoo ^TNX US10Y as spread proxy (JP10Y BOJ-pinned ~1%; 5d move = US leg)" }
)

if (!(Test-Path $CacheDir)) { New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null }

function Get-YahooChart {
  param([string]$Yahoo)
  # returns raw JSON string, from web or fresh cache; throws if neither available
  $enc = [Uri]::EscapeDataString($Yahoo)
  $url = "https://query1.finance.yahoo.com/v8/finance/chart/$enc" + "?range=1y&interval=1d"
  $safe = ($Yahoo -replace '[^A-Za-z0-9]', '_')
  $cache = Join-Path $CacheDir "$safe.json"
  try {
    $raw = (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec $TimeoutSec -Headers @{ 'User-Agent' = 'Mozilla/5.0' }).Content
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty body" }
    [System.IO.File]::WriteAllText($cache, $raw, (New-Object System.Text.UTF8Encoding($false)))
    return @{ Raw = $raw; FromCache = $false }
  } catch {
    if ((Test-Path $cache) -and (((Get-Date) - (Get-Item $cache).LastWriteTime).TotalHours -lt $CacheMaxHours)) {
      Write-Host "  $Yahoo fetch failed ($($_.Exception.Message)) - using cache"
      return @{ Raw = [System.IO.File]::ReadAllText($cache); FromCache = $true }
    }
    throw
  }
}

function Compute-Row {
  param([string]$Symbol, [string]$Note, [string]$RawJson, [bool]$FromCache)
  $j = $RawJson | ConvertFrom-Json
  $res = $j.chart.result[0]
  if ($null -eq $res) { throw "no chart result" }
  $q = $res.indicators.quote[0]
  # NOTE: array accumulators are named distinctly from the scalar temps below.
  # PowerShell variables are CASE-INSENSITIVE, so $Closes/$c would be fine but
  # $C/$c would be the SAME variable - do not reintroduce single-letter clashes.
  $closesRaw = $q.close
  $highsRaw  = $q.high
  $lowsRaw   = $q.low
  # keep only bars where close/high/low are all present (holidays give nulls)
  $Closes = @(); $Highs = @(); $Lows = @()
  for ($i = 0; $i -lt $closesRaw.Count; $i++) {
    $c = $closesRaw[$i]; $h = $highsRaw[$i]; $l = $lowsRaw[$i]
    if ($null -ne $c -and $null -ne $h -and $null -ne $l) { $Closes += [double]$c; $Highs += [double]$h; $Lows += [double]$l }
  }
  $n = $Closes.Count
  if ($n -lt 6) { throw "too few bars ($n)" }

  $spot = [math]::Round($Closes[$n - 1], 4)

  # SMA200 over available closes (>=200 ideal; else over what we have, flagged in note)
  $lookback = [math]::Min(200, $n)
  $smaSlice = $Closes[($n - $lookback)..($n - 1)]
  $sma200 = [math]::Round((($smaSlice | Measure-Object -Average).Average), 4)
  $smaNote = if ($lookback -lt 200) { " (sma over $lookback bars)" } else { "" }

  # ATR20: mean true range over last 20 bars
  $atrN = [math]::Min(20, $n - 1)
  $trs = @()
  for ($i = $n - $atrN; $i -lt $n; $i++) {
    $tr1 = $Highs[$i] - $Lows[$i]
    $tr2 = [math]::Abs($Highs[$i] - $Closes[$i - 1])
    $tr3 = [math]::Abs($Lows[$i] - $Closes[$i - 1])
    $trs += [math]::Max($tr1, [math]::Max($tr2, $tr3))
  }
  $atr20 = [math]::Round((($trs | Measure-Object -Average).Average), 4)

  # 5d % change (close[-1] vs close[-6])
  $c5 = $Closes[$n - 6]
  $chg5d = if ($c5 -ne 0) { [math]::Round((($Closes[$n - 1] / $c5) - 1.0) * 100.0, 3) } else { 0 }

  $status = if ($FromCache) { "STALE" } else { "OK" }
  $stamp  = (Get-Date).ToString('yyyy-MM-dd HH:mm')
  return [pscustomobject]@{
    symbol      = $Symbol
    spot        = $spot
    sma200      = $sma200
    atr20       = $atr20
    chg5d_pct   = $chg5d
    data_status = $status
    source_note = "$Note$smaNote [$stamp]"
  }
}

# ---- fetch + compute each web feed ----
$newRows = @{}
$okCount = 0; $staleCount = 0; $failCount = 0
foreach ($f in $FEEDS) {
  try {
    $g = Get-YahooChart -Yahoo $f.Yahoo
    $row = Compute-Row -Symbol $f.Symbol -Note $f.Note -RawJson $g.Raw -FromCache $g.FromCache
    $newRows[$f.Symbol] = $row
    if ($row.data_status -eq "OK") { $okCount++; Write-Host "  OK    $($f.Symbol) spot=$($row.spot) sma200=$($row.sma200) chg5d=$($row.chg5d_pct)% (atr=$($row.atr20))" }
    else { $staleCount++; Write-Host "  STALE $($f.Symbol) spot=$($row.spot) (from cache)" }
  } catch {
    $failCount++
    Write-Host "  FAIL  $($f.Symbol) [$($f.Yahoo)]: $($_.Exception.Message)"
  }
}

# ---- merge-in-place into snapshot (preserve broker rows + row order) ----
$cols = @('symbol','spot','sma200','atr20','chg5d_pct','data_status','source_note')
$existing = @()
if (Test-Path $Snapshot) { $existing = @(Import-Csv $Snapshot) }

# for a failed web feed with an existing row: keep the old values but downgrade to STALE
foreach ($f in $FEEDS) {
  if (-not $newRows.ContainsKey($f.Symbol)) {
    $prev = $existing | Where-Object { $_.symbol -eq $f.Symbol } | Select-Object -First 1
    if ($prev) {
      $newRows[$f.Symbol] = [pscustomobject]@{
        symbol      = $prev.symbol
        spot        = $prev.spot
        sma200      = $prev.sma200
        atr20       = $prev.atr20
        chg5d_pct   = $prev.chg5d_pct
        data_status = "STALE"
        source_note = "$($prev.source_note) | feed-fail $((Get-Date).ToString('yyyy-MM-dd HH:mm'))"
      }
    }
  }
}

$out = @()
$seen = @{}
foreach ($r in $existing) {
  if ($newRows.ContainsKey($r.symbol)) { $out += $newRows[$r.symbol]; $seen[$r.symbol] = $true }
  else { $out += $r }
}
# append any web symbols that were not already in the snapshot
foreach ($f in $FEEDS) {
  if ($newRows.ContainsKey($f.Symbol) -and -not $seen.ContainsKey($f.Symbol)) { $out += $newRows[$f.Symbol] }
}

# ---- write CSV manually (minimal quoting; keeps broker rows byte-stable-ish) ----
function CsvField($v) {
  $s = if ($null -eq $v) { "" } else { "$v" }
  if ($s -match '[",\r\n]' -or $s -match '^\s' -or $s -match '\s$') { '"' + ($s -replace '"', '""') + '"' } else { $s }
}
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine(($cols -join ','))
foreach ($r in $out) {
  $line = ($cols | ForEach-Object { CsvField $r.$_ }) -join ','
  [void]$sb.AppendLine($line)
}
$dir = Split-Path $Snapshot -Parent
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[System.IO.File]::WriteAllText($Snapshot, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Host "web feeder: $okCount OK, $staleCount stale, $failCount fail -> $Snapshot"
if ($failCount -gt 0 -and $okCount -eq 0 -and $staleCount -eq 0) { exit 1 }
