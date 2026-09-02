[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$CellId,
  [Parameter(Mandatory)][string]$CanonicalHead,
  [Parameter(Mandatory)][string]$BuildReceiptRegistry,
  [Parameter(Mandatory)][string]$EvidenceRoot,
  [string]$Terminal = 'D:\Meta 5\terminal64.exe',
  [string]$DataDir = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  [string]$CommonFiles = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
. (Join-Path $RepoRoot 'scripts\lib\report_freshness.ps1')
$ExpectedSetSha='671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2'
$ExpectedManifestSha='56e7b996a9c6836e5d7cedcbe3c9a212620b9fcc10c4fe3a750f44c8226cfefd'
$ExpectedSourceSha='dd61c78ca6680fcec64260ea200e04c2faa4824abbbeac218100a2db997f33cf'
$ExpectedEx5Sha='8f68ee1cf726f27de0ec5da0f1ad4b5f88f129435f9b2bf9b27d5ba378a9abd2'
$ExpectedBuildReceipt='br-6c63129e01ac4458a62d420c5594560f'
$ExpectedReceiptRegistrySha='4aac0ace64c5ddc5c05adbcde394705e365d1b8b50322649da2251d49aa92818'
$Expert='EALabTpl\Probe_19_AdaptiveTrendGrid_P4BUnitExport'
$Manifest=Join-Path $RepoRoot 'tools\hermes_ea_lab_pilot\H3_BROAD_MATRIX_MANIFEST.csv'
$PeriodCode=@{M15=15;H1=16385;H4=16388}

function Refuse([string]$Message){ throw "P4B_REFUSE: $Message" }
function FileSha([string]$Path){ return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

$head=(git -C $RepoRoot rev-parse HEAD).Trim()
if($head -ne $CanonicalHead){Refuse "HEAD $head != reviewed canonical $CanonicalHead"}
if((git -C $RepoRoot status --porcelain).Count -ne 0){Refuse 'worktree is dirty before runtime'}
if(-not(Test-Path $BuildReceiptRegistry)){Refuse 'build receipt registry missing'}
if(-not(Test-Path $Manifest)){Refuse 'H3 manifest missing'}
$manifestSha=FileSha $Manifest
if($manifestSha -ne $ExpectedManifestSha){Refuse "H3 manifest SHA drift $manifestSha"}
$sourcePath=Join-Path $RepoRoot 'ea_template\Probe_19_AdaptiveTrendGrid_P4BUnitExport.mq5'
$sourceSha=FileSha $sourcePath
if($sourceSha -ne $ExpectedSourceSha){Refuse "diagnostic source SHA drift $sourceSha"}
$receiptRegistrySha=FileSha $BuildReceiptRegistry
if($receiptRegistrySha -ne $ExpectedReceiptRegistrySha){Refuse "build receipt registry SHA drift $receiptRegistrySha"}
$receiptRecords=@(Get-Content -LiteralPath $BuildReceiptRegistry | ForEach-Object { try { $_ | ConvertFrom-Json } catch { Refuse 'build receipt registry malformed' } })
$receiptMatches=@($receiptRecords | Where-Object { $_.build_receipt -eq $ExpectedBuildReceipt })
if($receiptMatches.Count -ne 1){Refuse "accepted build receipt $ExpectedBuildReceipt is not unique in registry"}
$receipt=$receiptMatches[0]
if($receipt.source_sha256 -ne $ExpectedSourceSha -or $receipt.artifact_sha256 -ne $ExpectedEx5Sha){Refuse 'accepted build receipt source/EX5 identity drift'}
$expertRel=($Expert -replace '\.ex5$','')+'.ex5'
$artifact=Join-Path (Join-Path $DataDir 'MQL5\Experts') $expertRel
if(-not(Test-Path $artifact)){Refuse 'installed diagnostic EX5 missing before run'}
$artifactSha=FileSha $artifact
if($artifactSha -ne $ExpectedEx5Sha){Refuse "diagnostic EX5 SHA drift $artifactSha"}
$rows=Import-Csv $Manifest
$row=@($rows|Where-Object cell_id -eq $CellId)
if($row.Count -ne 1){Refuse "cell_id $CellId not unique in H3 manifest"}
$row=$row[0]
if($row.model -ne '1' -or $row.holdout -ne 'NO' -or $row.optimization -ne 'NO'){Refuse 'cell is outside fixed Model-1 no-HOLDOUT/no-optimization contract'}
if($row.window -notin @('MAIN','BWD')){Refuse "unsupported window $($row.window)"}
if($row.tf -notin $PeriodCode.Keys){Refuse "unsupported tf $($row.tf)"}
$expectedDates=if($row.window -eq 'MAIN'){@('2023.01.01','2025.12.31')}else{@('2020.01.01','2022.12.31')}
if($row.from_date -ne $expectedDates[0] -or $row.to_date -ne $expectedDates[1]){Refuse 'manifest window dates drifted'}
if([datetime]::ParseExact($row.to_date,'yyyy.MM.dd',$null) -gt [datetime]'2025-12-31'){Refuse 'HOLDOUT date crossing'}

$set=Join-Path $RepoRoot ($row.set_path -replace '/','\')
if(-not(Test-Path $set)){Refuse "set missing: $set"}
$setSha=FileSha $set
if($setSha -ne $ExpectedSetSha){Refuse "set SHA drift $setSha"}
$runDir=Join-Path ([IO.Path]::GetFullPath($EvidenceRoot)) $CellId
if(Test-Path $runDir){Refuse "evidence directory already exists: $runDir"}
New-Item -ItemType Directory -Force $runDir|Out-Null

$period=[int]$PeriodCode[$row.tf]
$sourceName="P4B_B19_UNIT_$($row.symbol)_${period}_990001.csv"
$sourceCommon=Join-Path $CommonFiles $sourceName
if(Test-Path $sourceCommon){
  Copy-Item $sourceCommon (Join-Path $runDir 'preexisting_source.csv') -Force
  Remove-Item $sourceCommon -Force
}
$reportName="P4B_$($CellId)_UNIT"
$startedLocal=Get-Date
$startedUtc=[DateTime]::UtcNow
$runner=Join-Path $RepoRoot 'scripts\mt5_run.ps1'
$runOutput=& $runner -Expert $Expert -Symbol $row.symbol -Period $row.tf `
  -FromDate $row.from_date -ToDate $row.to_date -SetFile $set -Model 1 `
  -Deposit 10000 -Leverage 100 -ReportName $reportName -Terminal $Terminal `
  -DataDir $DataDir -TimeoutSec 900 -BuildReceiptRegistry $BuildReceiptRegistry 2>&1
$runExit=$LASTEXITCODE
[IO.File]::WriteAllLines((Join-Path $runDir 'runner.log'),@($runOutput),[Text.Encoding]::UTF8)
if($runExit -ne 0){Refuse "mt5_run exit=$runExit"}

$report=Join-Path $RepoRoot "_mt5_auto\reports\$reportName.htm"
$trunc=Join-Path $RepoRoot "_mt5_auto\reports\$reportName.truncation_check.json"
$lev=Join-Path $RepoRoot "_mt5_auto\reports\$reportName.leverage_check.json"
if(-not (Test-ReportIsFresh -Htm $report -RunStart $startedLocal -RunnerExit $runExit -Label $reportName -Quiet)){Refuse 'report freshness/runner-exit gate failed'}
if(-not(Test-Path $trunc)){Refuse 'truncation sidecar missing'}
$t=Get-Content $trunc -Raw|ConvertFrom-Json
if([bool]$t.truncated){Refuse 'report is truncated'}
if(-not(Test-Path $sourceCommon)){Refuse "final source export missing: $sourceName"}
$srcInfo=Get-Item $sourceCommon
if($srcInfo.LastWriteTimeUtc -lt $startedUtc){Refuse 'source export is stale'}

$raw=Join-Path $runDir 'source.csv'
Copy-Item $sourceCommon $raw -Force
Copy-Item $report (Join-Path $runDir 'report.htm') -Force
Copy-Item $trunc (Join-Path $runDir 'truncation_check.json') -Force
if(Test-Path $lev){Copy-Item $lev (Join-Path $runDir 'leverage_check.json') -Force}
$sourceRows=Import-Csv $raw
if($sourceRows.Count -eq 0){Refuse 'source export is empty'}
$ident=@($sourceRows|Select-Object -Unique symbol,period,period_name,configured_run_magic,account_margin_mode)
if($ident.Count -ne 1){Refuse 'source export mixed configured runtime identity'}
if($ident[0].symbol -ne $row.symbol -or [int]$ident[0].period -ne $period -or $ident[0].period_name -ne "PERIOD_$($row.tf)" -or $ident[0].configured_run_magic -ne '990001'){
  Refuse 'source export identity does not match manifest cell'
}

. (Join-Path $RepoRoot 'scripts\use_python.ps1')
$py=Assert-PortablePython -Root $RepoRoot -Provision
$parser=Join-Path $RepoRoot 'docs\skills_mirror\skills\backtest-report-analyzer\scripts\parse_mt5_report.py'
$reportJson=Join-Path $runDir 'report.json'
& $py $parser (Join-Path $runDir 'report.htm') -o $reportJson | Out-Null
if($LASTEXITCODE -ne 0){Refuse 'report parser failed'}
$units=Join-Path $runDir 'units.csv'
$unitManifest=Join-Path $runDir 'unit_manifest.json'
& $py (Join-Path $RepoRoot 'tools\p4b_unit_attribution\build_source_bound_units.py') `
  --source $raw --run-id $CellId --output $units --manifest $unitManifest | Out-Null
if($LASTEXITCODE -ne 0){Refuse 'source-bound unit builder refused'}

$metrics=Get-Content $reportJson -Raw|ConvertFrom-Json
$um=Get-Content $unitManifest -Raw|ConvertFrom-Json
if([int]$um.source_out_count -ne [int]$metrics.total_trades){Refuse "source OUT $($um.source_out_count) != tester trades $($metrics.total_trades)"}
if([int]$um.realized_unit_count -ne [int]$metrics.total_trades){Refuse "realized units $($um.realized_unit_count) != tester trades $($metrics.total_trades)"}
if([int]$um.open_position_count -ne 0){Refuse "source has $($um.open_position_count) unrealized positions after tester finalization"}
if([int]$um.unknown_time_unit_count -ne 0){Refuse "source has $($um.unknown_time_unit_count) unknown-time realized units"}
if([int]$um.configured_run_magic -ne 990001){Refuse "builder configured run magic $($um.configured_run_magic) != 990001"}
if($um.source_magic_provenance -ne 'PER_DEAL_HISTORY_DEAL_MAGIC'){Refuse "source magic provenance missing"}
if([int]$um.source_owned_position_count -ne [int]$um.source_position_count){Refuse "source magic ownership parity failed"}
if(-not(Test-Path $artifact)){Refuse 'installed diagnostic EX5 missing after run'}
$postArtifactSha=FileSha $artifact
if($postArtifactSha -ne $ExpectedEx5Sha){Refuse "diagnostic EX5 SHA drift after run $postArtifactSha"}
$manifestOut=[ordered]@{
  schema='BOSS19_P4B_UNIT_EXPORT_RUN_V2'; status='PASS_SOURCE_BOUND_UNIT_RUN';
  canonical_head=$CanonicalHead; cell_id=$CellId; symbol=$row.symbol; tf=$row.tf; window=$row.window;
  from_date=$row.from_date; to_date=$row.to_date; model=1; holdout='UNSPENT'; optimization='NONE';
  set_sha256=$setSha; h3_manifest_sha256=$manifestSha; build_receipt=$ExpectedBuildReceipt; build_receipt_registry_sha256=$receiptRegistrySha;
  diagnostic_ex5_sha256=$postArtifactSha; diagnostic_source_sha256=$sourceSha;
  report_sha256=FileSha (Join-Path $runDir 'report.htm'); source_sha256=FileSha $raw; unit_sha256=FileSha $units;
  report_trades=[int]$metrics.total_trades; source_in_count=[int]$um.source_in_count; source_out_count=[int]$um.source_out_count;
  source_position_count=[int]$um.source_position_count; source_owned_position_count=[int]$um.source_owned_position_count;
  realized_unit_count=[int]$um.realized_unit_count; open_position_count=[int]$um.open_position_count;
  unknown_time_unit_count=[int]$um.unknown_time_unit_count; linkage_basis=$um.linkage_basis;
  configured_run_magic=[int]$um.configured_run_magic; source_magic_values=@($um.source_magic_values);
  source_magic_match_count=[int]$um.source_magic_match_count; source_magic_nonmatch_count=[int]$um.source_magic_nonmatch_count;
  source_magic_provenance=$um.source_magic_provenance;
  source_file=$sourceName; started_utc=$startedUtc.ToString('o'); completed_utc=[DateTime]::UtcNow.ToString('o')
}
$out=Join-Path $runDir 'run_manifest.json'
[IO.File]::WriteAllText($out,(($manifestOut|ConvertTo-Json -Depth 7)+"`n"),(New-Object Text.UTF8Encoding($false)))
Write-Output "P4B_UNIT_EXPORT_RUN PASS cell=$CellId trades=$($metrics.total_trades) source_sha=$($manifestOut.source_sha256)"
Write-Output $out
exit 0
