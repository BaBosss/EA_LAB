param(
  [string]$OutputRoot = '',
  [string]$Terminal = 'D:\Meta 5\terminal64.exe',
  [string]$DataDir = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  [string]$Python = 'C:\Users\patip\.local\bin\python.exe',
  [int]$TimeoutSec = 300
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$source=Join-Path $repo 'tools\P4BMarketDataExporter\P4BMarketDataExporter.mq5'
$normalizer=Join-Path $repo 'tools\P4BMarketDataExporter\normalize_ohlc.py'
$runnerSha=(Get-FileHash $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
$sourceSha=(Get-FileHash $source -Algorithm SHA256).Hash.ToLowerInvariant()
$sourceText=[IO.File]::ReadAllText($source,[Text.Encoding]::UTF8).Replace("`r`n","`n")
$attMatch=[regex]::Match($sourceText,'const string SOURCE_ATTESTATION_SHA256 = "([0-9a-f]{64})";')
if(-not $attMatch.Success){throw 'P4B_REFUSE: source attestation constant missing'}
$normSource=$sourceText.Remove($attMatch.Groups[1].Index,64).Insert($attMatch.Groups[1].Index,('0'*64))
$sha=[Security.Cryptography.SHA256]::Create(); try{$sourceAttestation=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($normSource)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
if($sourceAttestation -ne $attMatch.Groups[1].Value){throw 'P4B_REFUSE: source attestation mismatch'}
$normalizerSha=(Get-FileHash $normalizer -Algorithm SHA256).Hash.ToLowerInvariant()
$metaEditor=Join-Path (Split-Path -Parent $Terminal) 'MetaEditor64.exe'
$common='C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files'
if(-not $OutputRoot){$OutputRoot='D:\EA_LAB_CONTROL\evidence\boss19_p4b_local_ohlc_'+(Get-Date -Format 'yyyyMMdd_HHmmss')}
if(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object {$_.Path -eq (Resolve-Path $Terminal).Path}){throw 'P4B_REFUSE: exact tester install is busy'}
foreach($p in $Terminal,$DataDir,$Python,$source,$normalizer,$metaEditor){if(-not(Test-Path $p)){throw "P4B_REFUSE: missing $p"}}
New-Item -ItemType Directory -Force $OutputRoot | Out-Null
$compileLog=Join-Path $OutputRoot 'compile.log'
$cp=Start-Process $metaEditor -ArgumentList @('/compile:'+('"'+$source+'"'),'/log:'+('"'+$compileLog+'"')) -PassThru -Wait
if((Get-Content $compileLog -Raw) -notmatch 'Result: 0 errors, 0 warnings'){throw 'P4B_REFUSE: exporter compile not clean'}
$ex5=[IO.Path]::ChangeExtension($source,'.ex5')
$expertDir=Join-Path $DataDir 'MQL5\Experts\P4BMarketDataExporter'; New-Item -ItemType Directory -Force $expertDir|Out-Null
$installed=Join-Path $expertDir 'P4BMarketDataExporter.ex5'; Copy-Item $ex5 $installed -Force
$expertSha=(Get-FileHash $installed -Algorithm SHA256).Hash.ToLowerInvariant()
$packageExpert=Join-Path $OutputRoot 'P4BMarketDataExporter.ex5'; Copy-Item $installed $packageExpert -Force
$packageExpertSha=(Get-FileHash $packageExpert -Algorithm SHA256).Hash.ToLowerInvariant(); if($packageExpertSha -ne $expertSha){throw 'P4B_REFUSE: packaged expert hash mismatch'}
$expectedTerminalPath=(Resolve-Path (Split-Path -Parent $Terminal)).Path.TrimEnd('\')
$terminalId=Split-Path $DataDir -Leaf
$metaQuotesRoot=Split-Path (Split-Path $DataDir -Parent) -Parent
$expectedTesterRoot=(Join-Path (Join-Path $metaQuotesRoot 'Tester') $terminalId).TrimEnd('\')
$expectedRuntimeRel='MQL5\Experts\P4BMarketDataExporter\P4BMarketDataExporter.ex5'
$symbols=@('XAUUSD','EURUSD','GBPUSD','AUDUSD','USDJPY','BTCUSD'); $tfs=@('M15','H1','H4')
$rows=@(); $iniDir=Join-Path $OutputRoot 'ini'; New-Item -ItemType Directory -Force $iniDir|Out-Null
foreach($symbol in $symbols){foreach($tf in $tfs){
  $stem="P4B_OHLC_${symbol}_${tf}"; $srcCsv=Join-Path $common ($stem+'.csv'); $done=Join-Path $common ($stem+'.done')
  Remove-Item $srcCsv,$done -Force -ErrorAction SilentlyContinue
  $ini=Join-Path $iniDir ($stem+'.ini')
  $lines=@('[Tester]','Expert=P4BMarketDataExporter\P4BMarketDataExporter',"Symbol=$symbol","Period=$tf",'Model=1','Optimization=0','FromDate=2019.03.01','ToDate=2025.12.31','ForwardMode=0','Deposit=10000','Currency=USD','Leverage=1:100','ExecutionMode=0','Visual=0','ShutdownTerminal=1')
  [IO.File]::WriteAllLines($ini,$lines,(New-Object Text.UTF8Encoding($false)))
  $started=Get-Date; $proc=Start-Process $Terminal -ArgumentList ('/config:"'+$ini+'"') -PassThru
  try{$proc.PriorityClass=[Diagnostics.ProcessPriorityClass]::BelowNormal}catch{}
  $sw=[Diagnostics.Stopwatch]::StartNew(); while($sw.Elapsed.TotalSeconds -lt $TimeoutSec){if((Test-Path $done)-and $proc.HasExited){break}; if($proc.HasExited -and $sw.Elapsed.TotalSeconds -gt 10){break}; Start-Sleep -Milliseconds 100}
  if(-not $proc.HasExited){try{$proc.Kill()}catch{}; throw "P4B_REFUSE: timeout $symbol/$tf"}
  if(-not(Test-Path $done) -or -not(Test-Path $srcCsv)){throw "P4B_REFUSE: no fresh export $symbol/$tf"}
  $raw=Join-Path $OutputRoot ($stem+'_server.csv'); Copy-Item $srcCsv $raw -Force
  $norm=Join-Path $OutputRoot ($stem+'_utc.csv'); $meta=Join-Path $OutputRoot ($stem+'.meta.json')
  & $Python $normalizer --src $raw --dst $norm --symbol $symbol --tf $tf --meta $meta
  if($LASTEXITCODE -ne 0){throw "P4B_REFUSE: normalize failed $symbol/$tf"}
  $m=Get-Content $meta -Raw|ConvertFrom-Json; $d=@{}; foreach($line in Get-Content $done){if($line -match '^([^=]+)=(.*)$'){$d[$matches[1]]=$matches[2]}}
  if($d['account_server'] -ne 'ThinkMarkets-Live'){throw "P4B_REFUSE: server identity $symbol/$tf = $($d['account_server'])"}
  if([string]::IsNullOrWhiteSpace($d['terminal_path']) -or -not [string]::Equals(([IO.Path]::GetFullPath($d['terminal_path'])).TrimEnd('\'),$expectedTerminalPath,[StringComparison]::OrdinalIgnoreCase)){throw "P4B_REFUSE: terminal path identity $symbol/$tf"}
  $runtimeData=if([string]::IsNullOrWhiteSpace($d['terminal_data_path'])){''}else{([IO.Path]::GetFullPath($d['terminal_data_path'])).TrimEnd('\')}
  $runtimeProgram=if([string]::IsNullOrWhiteSpace($d['program_path'])){''}else{[IO.Path]::GetFullPath($d['program_path'])}
  if(-not $runtimeData.StartsWith($expectedTesterRoot+'\Agent-',[StringComparison]::OrdinalIgnoreCase)){throw "P4B_REFUSE: tester agent identity $symbol/$tf = $runtimeData"}
  $expectedRuntimeProgram=Join-Path $runtimeData $expectedRuntimeRel
  if(-not [string]::Equals($runtimeProgram,$expectedRuntimeProgram,[StringComparison]::OrdinalIgnoreCase)){throw "P4B_REFUSE: expert program identity $symbol/$tf"}
  if($d['source_attestation_sha256'] -ne $sourceAttestation){throw "P4B_REFUSE: runtime source attestation $symbol/$tf"}
  $runtimeSourceAttestation=$d['source_attestation_sha256']
  $doneCopy=Join-Path $OutputRoot ($stem+'.done'); Copy-Item $done $doneCopy -Force
  $rows += [pscustomobject][ordered]@{symbol=$symbol;tf=$tf;rows=[int]$m.rows;first_utc=$m.first_utc;last_utc=$m.last_utc;timestamp_basis='OPEN_TIME_UTC';missing_bar_policy=$m.missing_bar_policy;raw_file=[IO.Path]::GetFileName($raw);raw_sha256=$m.raw_sha256;normalized_file=[IO.Path]::GetFileName($norm);normalized_sha256=$m.normalized_sha256;quarantined_rows=[int]$m.quarantined_rows;quarantine_file=$m.quarantine_file;quarantine_sha256=$m.quarantine_sha256;ini_file=[IO.Path]::GetFileName($ini);ini_sha256=(Get-FileHash $ini -Algorithm SHA256).Hash.ToLowerInvariant();done_file=[IO.Path]::GetFileName($doneCopy);done_sha256=(Get-FileHash $doneCopy -Algorithm SHA256).Hash.ToLowerInvariant();terminal_build=[int]$d['terminal_build'];terminal_path=$d['terminal_path'];terminal_data_path=$runtimeData;program_path=$runtimeProgram;runtime_source_attestation_sha256=$runtimeSourceAttestation;account_server=$d['account_server'];elapsed_seconds=[math]::Round($sw.Elapsed.TotalSeconds,2)}
}}
if($rows.Count -ne 18){throw "P4B_REFUSE: expected 18 cells got $($rows.Count)"}
$manifest=[ordered]@{schema_version='BOSS19_P4B_LOCAL_OHLC_MANIFEST_V2';created_utc=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ');source_terminal=$Terminal;data_dir=$DataDir;account_server='ThinkMarkets-Live';tester_model=1;optimization=0;tester_from='2019.03.01';tester_to='2025.12.31';holdout_included=$false;timestamp_field='open_time_utc';timestamp_basis='closed tester bar open timestamp normalized to UTC; classifier eligibility occurs at open_time_utc + TF duration';missing_bar_policy='DST transition server dates are quarantined as UNKNOWN_DST_TRANSITION; never imputed';timezone_rule='ThinkMarkets MT4/MT5 GMT+2 standard / GMT+3 during US DST; transition server dates quarantined rather than assigning an unverified switch instant';timezone_sources=@('https://support.thinkmarkets.com/hc/en-gb/articles/11613703690385-What-is-ThinkMarkets-server-time','https://www.thinkmarkets.com/za/announcements/2025-us-dst-trading-hours-update/');producer=[ordered]@{runner_path='scripts/research/boss19_p4b/export_local_ohlc.ps1';runner_sha256=$runnerSha;exporter_source_path='tools/P4BMarketDataExporter/P4BMarketDataExporter.mq5';exporter_source_sha256=$sourceSha;normalizer_path='tools/P4BMarketDataExporter/normalize_ohlc.py';normalizer_sha256=$normalizerSha;source_attestation_sha256=$sourceAttestation;installed_expert_sha256=$expertSha;package_expert_file=[IO.Path]::GetFileName($packageExpert);package_expert_sha256=$packageExpertSha;runtime_terminal_path_attested=$true;runtime_tester_agent_root_attested=$true;runtime_program_path_attested=$true;runtime_source_attestation_attested=$true;runtime_program_hash_attested=$false};cells=$rows}
$manifestPath=Join-Path $OutputRoot 'local_ohlc_manifest.json'; [IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
$manifestSha=(Get-FileHash $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant(); [IO.File]::WriteAllText((Join-Path $OutputRoot 'local_ohlc_manifest.sha256'),$manifestSha+"  local_ohlc_manifest.json`n",(New-Object Text.UTF8Encoding($false)))
Write-Output "P4B_LOCAL_OHLC_PASS output=$OutputRoot manifest_sha256=$manifestSha cells=$($rows.Count)"
$rows | Format-Table symbol,tf,rows,first_utc,last_utc,elapsed_seconds -AutoSize