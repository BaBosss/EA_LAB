# mris_macro_feeder.ps1 - MRIS macro barometer feeder (ORDER-200 A1)
# Standalone daily feeder that pulls 6 NEW macro axes (bond/credit/oil/equity) and
# writes them to a SEPARATE snapshot barometer_snapshot_macro.csv. Does NOT touch the
# existing 8-barometer barometer_snapshot.csv or mris_web_feeder.ps1 - zero blast
# radius on the validated live MacroGate path (ORDER-200 doctrine #1).
#
# 4 feeds (US2Y/WTI/SP500/MOVE) are Yahoo OHLC, fetched + computed exactly like
# mris_web_feeder.ps1's Fetch-Web/Compute-Row. 2 feeds (HY_OAS/YCURVE) are FRED
# single-value daily series - Invoke-WebRequest to fred.stlouisfed.org TIMES OUT on
# this box (TLS MITM proxy), so those two go through curl.exe instead. Same
# resilience pattern as mris_web_feeder.ps1: per-symbol raw cache in webfeed_cache\,
# validated-good-only cache writes, fresh-cache fallback on fetch failure, STALE tag
# + preserved old row when neither fresh fetch nor fresh cache is available, atomic
# CSV write.
[CmdletBinding()]
param(
  [string]$Snapshot = "D:\EA_LAB\portfolio\mris\barometer_snapshot_macro.csv",
  [string]$CacheDir = "D:\EA_LAB\portfolio\mris\webfeed_cache",
  [int]$CacheMaxHours = 20,
  [int]$TimeoutSec = 25
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 6 macro barometers: snapshot symbol -> source ticker/id + fetch kind ("yahoo"|"fred").
$FEEDS = @(
  @{ Symbol="US2Y";   Kind="yahoo"; Ticker="2YY=F";            Note="Yahoo 2YY=F (2Y UST yield future)" },
  @{ Symbol="WTI";    Kind="yahoo"; Ticker="CL=F";             Note="Yahoo CL=F (WTI crude front future)" },
  @{ Symbol="SP500";  Kind="yahoo"; Ticker="^GSPC";            Note="Yahoo ^GSPC (S&P 500 index)" },
  @{ Symbol="MOVE";   Kind="yahoo"; Ticker="^MOVE";            Note="Yahoo ^MOVE (ICE BofA MOVE bond-vol index)" },
  @{ Symbol="HY_OAS"; Kind="fred";  Ticker="BAMLH0A0HYM2";     Note="FRED BAMLH0A0HYM2 (ICE BofA US High Yield OAS, %)" },
  @{ Symbol="YCURVE"; Kind="fred";  Ticker="T10Y2Y";           Note="FRED T10Y2Y (10Y-2Y UST spread, %)" }
)

if (!(Test-Path $CacheDir)) { New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null }

function Get-CachePath { param([string]$Ticker, [string]$Ext) Join-Path $CacheDir (($Ticker -replace '[^A-Za-z0-9]', '_') + $Ext) }

function Fetch-Yahoo {
  param([string]$Ticker)
  # web fetch ONLY - does NOT touch the cache (caller caches a payload only after
  # Compute-RowYahoo validates it, so an HTTP-200 error body cannot poison the cache)
  $enc = [Uri]::EscapeDataString($Ticker)
  $url = "https://query1.finance.yahoo.com/v8/finance/chart/$enc" + "?range=1y&interval=1d"
  $raw = (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec $TimeoutSec -Headers @{ 'User-Agent' = 'Mozilla/5.0' }).Content
  if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty body" }
  return $raw
}

function Fetch-Fred {
  param([string]$SeriesId)
  # GOTCHA: Invoke-WebRequest to fred.stlouisfed.org TIMES OUT on this box (TLS proxy).
  # Must use curl.exe instead. Yahoo works fine via Invoke-WebRequest above.
  $url = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=$SeriesId"
  $raw = & curl.exe -s -m $TimeoutSec $url
  if ($LASTEXITCODE -ne 0) { throw "curl.exe exit $LASTEXITCODE" }
  $rawText = ($raw -join "`n")
  if ([string]::IsNullOrWhiteSpace($rawText)) { throw "empty body" }
  return $rawText
}

function Compute-RowYahoo {
  param([string]$Symbol, [string]$Note, [string]$RawJson, [bool]$FromCache)
  $j = $RawJson | ConvertFrom-Json
  $res = $j.chart.result[0]
  if ($null -eq $res) { throw "no chart result" }
  $q = $res.indicators.quote[0]
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

function Compute-RowFred {
  param([string]$Symbol, [string]$Note, [string]$RawCsv, [bool]$FromCache)
  $lines = $RawCsv -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 }
  if ($lines.Count -lt 2) { throw "no data rows" }
  # header line is e.g. "observation_date,BAMLH0A0HYM2" or "DATE,BAMLH0A0HYM2" - skip it
  $Values = @()
  for ($i = 1; $i -lt $lines.Count; $i++) {
    $parts = $lines[$i] -split ','
    if ($parts.Count -lt 2) { continue }
    $v = $parts[1].Trim()
    if ($v -eq '.' -or [string]::IsNullOrWhiteSpace($v)) { continue }  # missing obs - skip
    $Values += [double]::Parse($v, [Globalization.CultureInfo]::InvariantCulture)
  }
  $n = $Values.Count
  if ($n -lt 6) { throw "too few observations ($n)" }

  $spot = [math]::Round($Values[$n - 1], 4)

  $lookback = [math]::Min(200, $n)
  $smaSlice = $Values[($n - $lookback)..($n - 1)]
  $sma200 = [math]::Round((($smaSlice | Measure-Object -Average).Average), 4)
  $smaNote = if ($lookback -lt 200) { " (sma over $lookback bars)" } else { "" }

  # ATR proxy: mean absolute day-over-day change over last 20 observations (no H/L for a single-value series)
  $atrN = [math]::Min(20, $n - 1)
  $trs = @()
  for ($i = $n - $atrN; $i -lt $n; $i++) {
    $trs += [math]::Abs($Values[$i] - $Values[$i - 1])
  }
  $atr20 = [math]::Round((($trs | Measure-Object -Average).Average), 4)

  # 5-observation % change (value[-1] vs value[-6])
  $v5 = $Values[$n - 6]
  $chg5d = if ($v5 -ne 0) { [math]::Round((($Values[$n - 1] / $v5) - 1.0) * 100.0, 3) } else { 0 }

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

# ---- fetch + compute each macro feed ----
# Order: try fresh fetch -> validate via Compute-Row* -> only THEN write cache. If the
# fetch leg fails OR its payload is invalid, fall back to a fresh (<CacheMaxHours) cache.
# This guarantees the cache only ever holds a payload we successfully parsed.
$newRows = @{}
$okCount = 0; $staleCount = 0; $failCount = 0
foreach ($f in $FEEDS) {
  $isFred = ($f.Kind -eq "fred")
  $cacheExt = if ($isFred) { ".csv" } else { ".json" }
  $cache = Get-CachePath -Ticker $f.Ticker -Ext $cacheExt
  $row = $null; $why = ""

  # 1. fresh fetch
  try {
    if ($isFred) {
      $raw = Fetch-Fred -SeriesId $f.Ticker
      $row = Compute-RowFred -Symbol $f.Symbol -Note $f.Note -RawCsv $raw -FromCache $false
    } else {
      $raw = Fetch-Yahoo -Ticker $f.Ticker
      $row = Compute-RowYahoo -Symbol $f.Symbol -Note $f.Note -RawJson $raw -FromCache $false
    }
    [System.IO.File]::WriteAllText($cache, $raw, (New-Object System.Text.UTF8Encoding($false)))  # validated-good only
  } catch {
    $why = "$($_.Exception.Message)"; $row = $null
  }

  # 2. fall back to a fresh cache (covers both fetch failure and invalid live payload)
  if ($null -eq $row -and (Test-Path $cache) -and (((Get-Date) - (Get-Item $cache).LastWriteTime).TotalHours -lt $CacheMaxHours)) {
    try {
      $cacheRaw = [System.IO.File]::ReadAllText($cache)
      if ($isFred) {
        $row = Compute-RowFred -Symbol $f.Symbol -Note $f.Note -RawCsv $cacheRaw -FromCache $true
      } else {
        $row = Compute-RowYahoo -Symbol $f.Symbol -Note $f.Note -RawJson $cacheRaw -FromCache $true
      }
      Write-Host "  $($f.Symbol) fetch failed ($why) - using cache"
    } catch { $why = "$why; cache: $($_.Exception.Message)"; $row = $null }
  }

  if ($null -ne $row) {
    $newRows[$f.Symbol] = $row
    if ($row.data_status -eq "OK") { $okCount++; Write-Host "  OK    $($f.Symbol) spot=$($row.spot) sma200=$($row.sma200) chg5d=$($row.chg5d_pct)% (atr=$($row.atr20))" }
    else { $staleCount++; Write-Host "  STALE $($f.Symbol) spot=$($row.spot) (from cache)" }
  } else {
    $failCount++
    Write-Host "  FAIL  $($f.Symbol) [$($f.Ticker)]: $why"
  }
}

# ---- merge-in-place into snapshot (preserve any non-fed rows + row order) ----
$cols = @('symbol','spot','sma200','atr20','chg5d_pct','data_status','asof','source_note')
$existing = @()
if (Test-Path $Snapshot) { $existing = @(Import-Csv $Snapshot) }

# for a failed fetch with an existing row: keep the old values + old asof (so a
# downstream reader's age-gate can still see it is stale) but downgrade status to
# STALE. Strip any prior '| feed-fail ...' marker first so the note cannot grow
# without bound.
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
# append any macro symbols that were not already in the snapshot
foreach ($f in $FEEDS) {
  if ($newRows.ContainsKey($f.Symbol) -and -not $seen.ContainsKey($f.Symbol)) { $out += $newRows[$f.Symbol] }
}

# ---- write CSV manually (minimal quoting; keeps rows byte-stable-ish) ----
function CsvField($v) {
  # numeric values are serialised with InvariantCulture so the snapshot uses '.' as the
  # decimal separator regardless of host locale (matches downstream invariant reads).
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
# truncate the live snapshot.
$tmpOut = "$Snapshot.tmp"
[System.IO.File]::WriteAllText($tmpOut, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Move-Item -LiteralPath $tmpOut -Destination $Snapshot -Force

Write-Host "macro feeder: $okCount OK, $staleCount stale, $failCount fail -> $Snapshot"
if ($failCount -gt 0 -and $okCount -eq 0 -and $staleCount -eq 0) { exit 1 }
