$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$py='C:\Users\patip\.local\bin\python.exe'
$n=Join-Path $repo 'tools\P4BMarketDataExporter\normalize_ohlc.py'
$mq=Get-Content (Join-Path $repo 'tools\P4BMarketDataExporter\P4BMarketDataExporter.mq5') -Raw
$r=Get-Content (Join-Path $repo 'scripts\research\boss19_p4b\export_local_ohlc.ps1') -Raw
if($mq -match 'CTrade|OrderSend|Buy\(|Sell\('){throw 'exporter must never trade'}
if($mq -notmatch 'MQL_TESTER' -or $mq -notmatch 'FILE_COMMON'){throw 'tester/common-file guards missing'}
if($r -notmatch "ThinkMarkets-Live" -or $r -notmatch 'holdout_included=\$false'){throw 'identity/holdout guards missing'}
if($r -notmatch 'runner_sha256' -or $r -notmatch 'exporter_source_sha256' -or $r -notmatch 'normalizer_sha256'){throw 'producer provenance hashes missing'}
if($r -notmatch "timestamp_field='open_time_utc'" -or $r -notmatch 'missing_bar_policy'){throw 'timestamp/missing-bar manifest contract missing'}
$tmp=Join-Path $env:TEMP ('p4b_norm_test_'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $tmp|Out-Null
try{
 $src=Join-Path $tmp 'raw.csv'; @('time_server,open,high,low,close,tick_volume,spread,real_volume','2019.03.01 00:00:00,1,2,0.5,1.5,10,1,0','2025.03.09 12:00:00,1,2,0.5,1.5,10,1,0','2025.03.10 12:00:00,1,2,0.5,1.5,10,1,0','2025.11.03 12:00:00,1,2,0.5,1.5,10,1,0') | Set-Content -Encoding ASCII $src
 & $py $n --src $src --dst (Join-Path $tmp 'norm.csv') --symbol XAUUSD --tf H4 --meta (Join-Path $tmp 'meta.json'); if($LASTEXITCODE -ne 0){throw 'normalizer failed'}
 $rows=Import-Csv (Join-Path $tmp 'norm.csv'); if($rows[0].open_time_utc -ne '2019-02-28T22:00:00Z'){throw 'standard offset wrong'}; if($rows[1].open_time_utc -ne '2025-03-10T09:00:00Z'){throw 'DST offset wrong'}; if($rows[2].open_time_utc -ne '2025-11-03T10:00:00Z'){throw 'standard return wrong'}; $q=Import-Csv (Join-Path $tmp 'norm_quarantine.csv'); if(@($q).Count -ne 1 -or @($q)[0].reason -ne 'UNKNOWN_DST_TRANSITION'){throw 'DST transition quarantine missing'}
 $bad=Join-Path $tmp 'bad.csv'; @('time_server,open,high,low,close,tick_volume,spread,real_volume','2026.01.01 03:00:00,1,2,0.5,1.5,10,1,0')|Set-Content -Encoding ASCII $bad
 $oldEap=$ErrorActionPreference; $ErrorActionPreference='Continue'; & $py $n --src $bad --dst (Join-Path $tmp 'badnorm.csv') --symbol XAUUSD --tf H4 --meta (Join-Path $tmp 'badmeta.json') 2>$null; $badCode=$LASTEXITCODE; $ErrorActionPreference=$oldEap; if($badCode -eq 0){throw 'HOLDOUT guard did not fail'}
} finally {Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue}
Write-Output 'PASS P4B local OHLC exporter tests'