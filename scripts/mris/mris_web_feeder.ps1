# mris_web_feeder.ps1 - MRIS web barometer feeder (ORDER-073 Phase-2 macro layer)
# Refreshes ALL 8 barometers by pulling free, no-key daily OHLC from the Yahoo Finance
# chart API, computing the snapshot schema the classifier reads (spot / sma200 / atr20 /
# chg5d_pct) plus an `asof` stamp, and MERGING in-place into barometer_snapshot.csv.
#
# Owning all 8 (not just the 4 the broker lacks) is deliberate: a macro-regime warning
# layer must never read half its scale off a hand-seeded snapshot that silently ages
# (scrutinize finding 2026-07-17). Broker feed Export_Barometers.mq5 stays an OPTIONAL
# refinement - if wired later it can overwrite the 4 FX/metal/crypto rows with exact
# broker prices, but the daily macro read does not need that precision.
#
# Zero LLM tokens - pure script. Same resilience pattern as scripts\news_calendar.ps1:
# per-symbol raw-JSON cache, fall back to a fresh cache on fetch failure, and if there
# is neither fresh data nor cache, tag the row STALE so the classifier excludes it
# (weights renormalise) instead of crashing. `asof` lets the classifier age-gate too.
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

# all 8 barometers: snapshot symbol -> Yahoo ticker (+ how to note the source).
# The first 4 are broker-priceable (Export_Barometers.mq5 may later refine them);
# the last 4 the broker cannot price at all.
$FEEDS = @(
  @{ Symbol="AUDJPY";       Yahoo="AUDJPY=X"; Note="Yahoo AUDJPY=X (spot; broker exporter may refine)" },
  @{ Symbol="USDJPY";       Yahoo="JPY=X";    Note="Yahoo JPY=X USD/JPY (spot; broker exporter may refine)" },
  @{ Symbol="XAUUSD";       Yahoo="GC=F";     Note="Yahoo GC=F (COMEX gold front future ~ spot; broker exporter may refine)" },
  @{ Symbol="BTCUSD";       Yahoo="BTC-USD";  Note="Yahoo BTC-USD (spot; broker exporter may refine)" },
  @{ Symbol="VIX";          Yahoo="^VIX";     Note="Yahoo ^VIX (CBOE Volatility Index)" },
  @{ Symbol="DXY";          Yahoo="DX-Y.NYB"; Note="Yahoo DX-Y.NYB (ICE US Dollar Index)" },
  @{ Symbol="COPPER";       Yahoo="HG=F";     Note="Yahoo HG=F (COMEX copper front future)" },
  @{ Symbol="US10Y_JP10Y";  Yahoo="^TNX";     Note="Yahoo ^TNX US10Y as spread proxy (JP10Y BOJ-pinned ~1%; 5d move = US leg)" }
)

if (!(Test-Path $CacheDir)) { New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null }

function Get-CachePath { param([string]$Yahoo) Join-Path $CacheDir (($Yahoo -replace '[^A-Za-z0-9]', '_') + ".json") }

function Fetch-Web {
  param([string]$Yahoo)
  # web fetch ONLY - does NOT touch the cache (the caller caches a payload only after
  # Compute-Row validates it, so a HTTP-200 error body cannot poison the good cache; Codex QA 2026-07-17)
  $enc = [Uri]::EscapeDataString($Yahoo)
  $url = "https://query1.finance.yahoo.com/v8/finance/chart/$enc" + "?range=1y&interval=1d"
  $raw = (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec $TimeoutSec -Headers @{ 'User-Agent' = 'Mozilla/5.0' }).Content
  if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty body" }
  return $raw
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
    asof        = $stamp
    source_note = "$Note$smaNote"
  }
}

# ---- fetch + compute each web feed ----
# Order: try fresh web -> validate via Compute-Row -> only THEN write cache. If the web
# leg fails OR its payload is invalid, fall back to a fresh (<CacheMaxHours) cache. This
# guarantees the cache only ever holds a payload we successfully parsed.
$newRows = @{}
$okCount = 0; $staleCount = 0; $failCount = 0
foreach ($f in $FEEDS) {
  $cache = Get-CachePath -Yahoo $f.Yahoo
  $row = $null; $why = ""

  # 1. fresh web
  try {
    $webRaw = Fetch-Web -Yahoo $f.Yahoo
    $row = Compute-Row -Symbol $f.Symbol -Note $f.Note -RawJson $webRaw -FromCache $false
    [System.IO.File]::WriteAllText($cache, $webRaw, (New-Object System.Text.UTF8Encoding($false)))  # validated-good only
  } catch {
    $why = "$($_.Exception.Message)"; $row = $null
  }

  # 2. fall back to a fresh cache (covers both HTTP failure and invalid live payload)
  if ($null -eq $row -and (Test-Path $cache) -and (((Get-Date) - (Get-Item $cache).LastWriteTime).TotalHours -lt $CacheMaxHours)) {
    try {
      $cacheRaw = [System.IO.File]::ReadAllText($cache)
      $row = Compute-Row -Symbol $f.Symbol -Note $f.Note -RawJson $cacheRaw -FromCache $true
      Write-Host "  $($f.Symbol) web failed ($why) - using cache"
    } catch { $why = "$why; cache: $($_.Exception.Message)"; $row = $null }
  }

  if ($null -ne $row) {
    $newRows[$f.Symbol] = $row
    if ($row.data_status -eq "OK") { $okCount++; Write-Host "  OK    $($f.Symbol) spot=$($row.spot) sma200=$($row.sma200) chg5d=$($row.chg5d_pct)% (atr=$($row.atr20))" }
    else { $staleCount++; Write-Host "  STALE $($f.Symbol) spot=$($row.spot) (from cache)" }
  } else {
    $failCount++
    Write-Host "  FAIL  $($f.Symbol) [$($f.Yahoo)]: $why"
  }
}

# ---- merge-in-place into snapshot (preserve any non-fed rows + row order) ----
$cols = @('symbol','spot','sma200','atr20','chg5d_pct','data_status','asof','source_note')
$existing = @()
if (Test-Path $Snapshot) { $existing = @(Import-Csv $Snapshot) }

# for a failed web feed with an existing row: keep the old values + old asof (so the
# classifier's age-gate can still see it is stale) but downgrade status to STALE. Strip
# any prior '| feed-fail ...' marker first so the note cannot grow without bound.
foreach ($f in $FEEDS) {
  if (-not $newRows.ContainsKey($f.Symbol)) {
    $prev = $existing | Where-Object { $_.symbol -eq $f.Symbol } | Select-Object -First 1
    if ($prev) {
      $prevNote = ("$($prev.source_note)" -replace '\s*\|\s*feed-fail.*$', '')
      $newRows[$f.Symbol] = [pscustomobject]@{
        symbol      = $prev.symbol
        spot        = $prev.spot
        sma200      = $prev.sma200
        atr20       = $prev.atr20
        chg5d_pct   = $prev.chg5d_pct
        data_status = "STALE"
        asof        = $prev.asof
        source_note = "$prevNote | feed-fail $((Get-Date).ToString('yyyy-MM-dd HH:mm'))"
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
  # numeric values are serialised with InvariantCulture so the snapshot uses '.' as the
  # decimal separator regardless of host locale (matches the classifier's invariant read).
  if ($v -is [double] -or $v -is [single] -or $v -is [decimal]) {
    $s = ([double]$v).ToString([Globalization.CultureInfo]::InvariantCulture)
  } else {
    $s = if ($null -eq $v) { "" } else { "$v" }
  }
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
# atomic write: stage to a same-dir temp, then replace, so an interrupted write can never
# truncate the live snapshot (Codex QA 2026-07-17).
$tmpOut = "$Snapshot.tmp"
[System.IO.File]::WriteAllText($tmpOut, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmpOut -Destination $Snapshot -Force

Write-Host "web feeder: $okCount OK, $staleCount stale, $failCount fail -> $Snapshot"
if ($failCount -gt 0 -and $okCount -eq 0 -and $staleCount -eq 0) { exit 1 }
