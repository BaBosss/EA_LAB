$ErrorActionPreference='Stop'
$script = Join-Path (Split-Path $PSScriptRoot -Parent) 'research\boss19_p4b\fetch_macro_ohlc.ps1'
$tmp = Join-Path $env:TEMP ('p4b_macro_test_' + [guid]::NewGuid().ToString('N'))
$raw = Join-Path $tmp 'fixture_raw'; $out = Join-Path $tmp 'out'
New-Item -ItemType Directory -Force -Path $raw,$out | Out-Null
try {
  $names=@('AUDJPY','USDJPY','VIX','DXY','XAUUSD','BTCUSD','US10Y_JP10Y','COPPER')
  $start=[datetime]'2019-01-01T00:00:00Z'; $end=[datetime]'2025-12-31T00:00:00Z'
  $timestamps=New-Object Collections.Generic.List[long]
  $opens=New-Object Collections.Generic.List[double]; $highs=New-Object Collections.Generic.List[double]
  $lows=New-Object Collections.Generic.List[double]; $closes=New-Object Collections.Generic.List[double]
  $d=$start; $i=0
  while($d -le $end){
    $timestamps.Add([DateTimeOffset]::new($d).ToUnixTimeSeconds()); $v=100.0+$i/1000.0
    $opens.Add($v); $highs.Add($v+1); $lows.Add($v-1); $closes.Add($v+0.25); $d=$d.AddDays(1); $i++
  }
  foreach($n in $names){
    $doc=[pscustomobject]@{chart=[pscustomobject]@{result=@([pscustomobject]@{timestamp=$timestamps;indicators=[pscustomobject]@{quote=@([pscustomobject]@{open=$opens;high=$highs;low=$lows;close=$closes})}});error=$null}}
    [IO.File]::WriteAllText((Join-Path $raw ($n+'.json')),($doc|ConvertTo-Json -Depth 8 -Compress),[Text.UTF8Encoding]::new($false))
  }
  $output=& $script -OutDir $out -RawInputDir $raw -FetchFromUtc ([datetime]'2019-01-01T00:00:00Z') -FetchToUtcExclusive ([datetime]'2026-01-01T00:00:00Z')
  $m=Get-Content -LiteralPath (Join-Path $out 'macro_manifest.json') -Raw|ConvertFrom-Json
  if(@($m.series).Count -ne 8){ throw 'manifest series count != 8' }
  foreach($e in @($m.series)){
    if([int]$e.warmup_rows_before_2020 -lt 260){ throw "warmup underflow for $($e.logical)" }
    if([datetime]$e.last_utc_date -gt [datetime]'2025-12-31'){ throw "HOLDOUT boundary crossed for $($e.logical): $($e.last_utc_date)" }
    if(!(Test-Path -LiteralPath (Join-Path $out $e.raw_file))){ throw "raw missing $($e.logical)" }
    if(!(Test-Path -LiteralPath (Join-Path $out $e.normalized_file))){ throw "normalized missing $($e.logical)" }
    if((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $out $e.raw_file)).Hash.ToLowerInvariant() -ne $e.raw_sha256){ throw "raw hash mismatch $($e.logical)" }
    if((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $out $e.normalized_file)).Hash.ToLowerInvariant() -ne $e.normalized_sha256){ throw "normalized hash mismatch $($e.logical)" }
  }
  Write-Output 'PASS: P4B macro OHLC deterministic fixture/hash/coverage test'
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
