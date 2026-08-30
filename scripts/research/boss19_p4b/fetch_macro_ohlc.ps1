[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$OutDir,
  [string]$RawInputDir = '',
  [datetime]$FetchFromUtc = [datetime]'2018-01-01T00:00:00Z',
  [datetime]$FetchToUtcExclusive = [datetime]'2026-01-01T00:00:00Z'
)
$ErrorActionPreference = 'Stop'
$ci = [Globalization.CultureInfo]::InvariantCulture
$requiredStart = [datetime]'2020-01-01T00:00:00Z'
$requiredEnd = [datetime]'2025-12-31T00:00:00Z'
$minWarmup = 260

$series = @(
  [ordered]@{ logical='AUDJPY';       ticker='AUDJPY=X';  mapping='P4A accepted Yahoo equivalent' },
  [ordered]@{ logical='USDJPY';       ticker='JPY=X';     mapping='P4A accepted Yahoo equivalent' },
  [ordered]@{ logical='VIX';          ticker='^VIX';      mapping='P4A accepted Yahoo equivalent' },
  [ordered]@{ logical='DXY';          ticker='DX-Y.NYB';  mapping='P4A accepted Yahoo equivalent' },
  [ordered]@{ logical='XAUUSD';       ticker='GC=F';      mapping='P4A accepted Yahoo equivalent' },
  [ordered]@{ logical='BTCUSD';       ticker='BTC-USD';   mapping='P4A accepted Yahoo equivalent' },
  [ordered]@{ logical='US10Y_JP10Y';  ticker='^TNX';      mapping='P4A accepted single-series proxy' },
  [ordered]@{ logical='COPPER';       ticker='HG=F';      mapping='P4A accepted Yahoo equivalent' }
)

function Get-Sha256([string]$Path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}
function To-Unix([datetime]$d) {
  return [DateTimeOffset]::new($d.ToUniversalTime()).ToUnixTimeSeconds()
}
function Write-Utf8NoBom([string]$Path,[string]$Text) {
  [IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))
}

$rawDir = Join-Path $OutDir 'raw'
$normDir = Join-Path $OutDir 'normalized'
New-Item -ItemType Directory -Force -Path $rawDir,$normDir | Out-Null
$entries = @()
$collectedAt = [DateTimeOffset]::UtcNow.ToString('o')

foreach($s in $series) {
  $logical = [string]$s.logical
  $ticker = [string]$s.ticker
  $rawPath = Join-Path $rawDir ($logical + '.json')
  $enc = [Uri]::EscapeDataString($ticker)
  $url = 'https://query1.finance.yahoo.com/v8/finance/chart/' + $enc + '?period1=' + (To-Unix $FetchFromUtc) + '&period2=' + (To-Unix $FetchToUtcExclusive) + '&interval=1d&events=history&includeAdjustedClose=false'
  if($RawInputDir) {
    $fixture = Join-Path $RawInputDir ($logical + '.json')
    if(!(Test-Path -LiteralPath $fixture -PathType Leaf)){ throw "raw input missing: $fixture" }
    Copy-Item -LiteralPath $fixture -Destination $rawPath -Force
    $sourceMode = 'PINNED_RAW_INPUT'
  } else {
    Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 60 -Headers @{ 'User-Agent'='Mozilla/5.0 EA_LAB-P4B' } -OutFile $rawPath
    $sourceMode = 'YAHOO_CHART_API_CAPTURED_RAW'
  }
  $doc = Get-Content -LiteralPath $rawPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if($null -eq $doc.chart -or $doc.chart.error){ throw "provider error for $logical/${ticker}: $($doc.chart.error | ConvertTo-Json -Compress)" }
  $res = @($doc.chart.result)[0]
  if($null -eq $res){ throw "provider returned no result for $logical/$ticker" }
  $ts = @($res.timestamp)
  $q = @($res.indicators.quote)[0]
  if($ts.Count -eq 0 -or $null -eq $q){ throw "provider returned no quote rows for $logical/$ticker" }
  $rows = New-Object Collections.Generic.List[object]
  for($i=0; $i -lt $ts.Count; $i++) {
    $o=$q.open[$i]; $h=$q.high[$i]; $l=$q.low[$i]; $c=$q.close[$i]
    if($null -eq $o -or $null -eq $h -or $null -eq $l -or $null -eq $c){ continue }
    $d=[DateTimeOffset]::FromUnixTimeSeconds([long]$ts[$i]).UtcDateTime.Date
    if($d -lt $FetchFromUtc.Date -or $d -ge $FetchToUtcExclusive.Date){ continue }
    $rows.Add([pscustomobject][ordered]@{
      utc_date=$d.ToString('yyyy-MM-dd',$ci)
      open=([double]$o).ToString('R',$ci)
      high=([double]$h).ToString('R',$ci)
      low=([double]$l).ToString('R',$ci)
      close=([double]$c).ToString('R',$ci)
    })
  }
  $rows = @($rows | Sort-Object utc_date -Unique)
  if($rows.Count -eq 0){ throw "normalized row set empty for $logical/$ticker" }
  $maxNormalized=[datetime]::ParseExact($rows[-1].utc_date,'yyyy-MM-dd',$ci)
  if($maxNormalized -gt $requiredEnd){ throw "$logical normalized data crosses HOLDOUT boundary: $($rows[-1].utc_date) > 2025-12-31" }
  $dates = @($rows | ForEach-Object { [datetime]::ParseExact($_.utc_date,'yyyy-MM-dd',$ci) })
  $pre = @($dates | Where-Object { $_ -lt $requiredStart }).Count
  $body = @($dates | Where-Object { $_ -ge $requiredStart -and $_ -le $requiredEnd })
  if($pre -lt $minWarmup){ throw "$logical warmup $pre < $minWarmup completed daily observations before 2020-01-01" }
  if($body.Count -eq 0){ throw "$logical has no observations in required 2020-01-01..2025-12-31 range" }
  if(($body | Select-Object -First 1) -gt [datetime]'2020-01-10'){ throw "$logical required-range coverage starts too late: $($body[0].ToString('yyyy-MM-dd'))" }
  if(($body | Select-Object -Last 1) -lt [datetime]'2025-12-20'){ throw "$logical required-range coverage ends too early: $($body[-1].ToString('yyyy-MM-dd'))" }
  $normPath = Join-Path $normDir ($logical + '.csv')
  $csv = $rows | ConvertTo-Csv -NoTypeInformation
  Write-Utf8NoBom $normPath (($csv -join "`n") + "`n")
  $entries += [pscustomobject][ordered]@{
    logical=$logical; provider='Yahoo Finance chart API'; provider_ticker=$ticker; mapping=[string]$s.mapping
    source_mode=$sourceMode; request_url=$url
    raw_file=('raw/' + $logical + '.json'); raw_sha256=(Get-Sha256 $rawPath)
    normalized_file=('normalized/' + $logical + '.csv'); normalized_sha256=(Get-Sha256 $normPath)
    normalized_rows=$rows.Count; warmup_rows_before_2020=$pre; required_range_rows=$body.Count
    first_utc_date=$rows[0].utc_date; last_utc_date=$rows[-1].utc_date
  }
}

$manifest = [pscustomobject][ordered]@{
  schema_version='BOSS19_P4B_MACRO_OHLC_PACKAGE_V1'
  collection_timestamp_utc=$collectedAt
  authority='RESEARCH_ONLY'
  classifier_contract='docs/research/BOSS19_P4_REGIME_CLASSIFIER_V1.md'
  required_range_utc='2020-01-01..2025-12-31 inclusive'
  warmup_requirement='>=260 completed daily observations strictly before 2020-01-01'
  required_fields=@('utc_date','open','high','low','close')
  fetch_from_utc=$FetchFromUtc.ToUniversalTime().ToString('o')
  fetch_to_utc_exclusive=$FetchToUtcExclusive.ToUniversalTime().ToString('o')
  input_mode=$(if($RawInputDir){'PINNED_RAW_INPUT'}else{'NETWORK_CAPTURE_THEN_HASH'})
  series=$entries
  prohibited_authority='No H3 outcome inspection, optimization, HOLDOUT, runtime, risk/default, deployment, or trading authority.'
  producer_script_sha256=(Get-Sha256 $PSCommandPath)
}
$manifestPath = Join-Path $OutDir 'macro_manifest.json'
Write-Utf8NoBom $manifestPath (($manifest | ConvertTo-Json -Depth 8) + "`n")
$manifestSha = Get-Sha256 $manifestPath
Write-Utf8NoBom (Join-Path $OutDir 'macro_manifest.sha256') ($manifestSha + "  macro_manifest.json`n")
Write-Output "STATUS=PASS"
Write-Output "SERIES_COUNT=$($entries.Count)"
Write-Output "MANIFEST=$manifestPath"
Write-Output "MANIFEST_SHA256=$manifestSha"
