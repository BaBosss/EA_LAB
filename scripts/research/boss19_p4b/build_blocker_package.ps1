[CmdletBinding()]
param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$H3Worktree = 'D:\EA_LAB_CONTROL\worktrees\hermes-h3-exec-47c77320',
  [string]$H3Package = 'D:\EA_LAB_CONTROL\jobs\hermes-h3-run-20260829\H3_RESULT_PACKAGE.json',
  [string]$MarketInputManifest = '',
  [string]$OutDir = (Join-Path (Get-Location).Path '_mt5_auto\p4b_boss19_regime')
)

$ErrorActionPreference = 'Stop'
$ExpectedPackageSha = '3d62d6d358831dc3897357d3d2008e9c0f1c9211716844112f8af96f79c7eeb2'
$ExpectedManifestSha = '56e7b996a9c6836e5d7cedcbe3c9a212620b9fcc10c4fe3a750f44c8226cfefd'
$ExpectedH3Head = '47c7732048406277096c1ccc31734b4122ae7285'

function Get-Sha256([string]$Path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Write-Utf8Json([string]$Path, $Value) {
  $json = $Value | ConvertTo-Json -Depth 12
  [System.IO.File]::WriteAllText($Path, $json + "`n", [System.Text.UTF8Encoding]::new($false))
}

$h3Manifest = Join-Path $H3Worktree 'tools\hermes_ea_lab_pilot\H3_BROAD_MATRIX_MANIFEST.csv'
$reportsDir = Join-Path $H3Worktree '_mt5_auto\reports'
if (!(Test-Path -LiteralPath $H3Package)) { throw "accepted H3 package missing: $H3Package" }
if (!(Test-Path -LiteralPath $h3Manifest)) { throw "H3 manifest missing: $h3Manifest" }
if (!(Test-Path -LiteralPath $reportsDir)) { throw "H3 reports directory missing: $reportsDir" }
$packageSha = Get-Sha256 $H3Package
if ($packageSha -ne $ExpectedPackageSha) {
  throw "accepted H3 package SHA mismatch: $packageSha != $ExpectedPackageSha"
}
$manifestSha = Get-Sha256 $h3Manifest
if ($manifestSha -ne $ExpectedManifestSha) {
  throw "H3 manifest SHA mismatch: $manifestSha != $ExpectedManifestSha"
}

$rows = @(Import-Csv -LiteralPath $h3Manifest)
if ($rows.Count -ne 36) { throw "H3 manifest row count $($rows.Count) != 36" }
if (@($rows.cell_id | Sort-Object -Unique).Count -ne 36) { throw 'H3 manifest cell_id values are not unique' }
if (@($rows.report_name | Sort-Object -Unique).Count -ne 36) { throw 'H3 manifest report_name values are not unique' }
if (@($rows | Where-Object { $_.model -ne '1' -or $_.holdout -ne 'NO' -or $_.optimization -ne 'NO' }).Count -ne 0) {
  throw 'H3 manifest contains non-Model1, HOLDOUT, or optimization rows'
}

$expectedGrid = foreach ($symbol in @('XAUUSD','EURUSD','GBPUSD','AUDUSD','USDJPY','BTCUSD')) {
  foreach ($tf in @('M15','H1','H4')) {
    foreach ($window in @('MAIN','BWD')) { "$symbol|$tf|$window" }
  }
}
$actualGrid = @($rows | ForEach-Object { "$($_.symbol)|$($_.tf)|$($_.window)" } | Sort-Object)
if ((Compare-Object ($expectedGrid | Sort-Object) $actualGrid).Count -ne 0) {
  throw 'H3 manifest grid differs from frozen 6x3x2 contract'
}
$reportInventory = foreach ($row in $rows) {
  $path = Join-Path $reportsDir ($row.report_name + '.htm')
  $exists = Test-Path -LiteralPath $path
  [ordered]@{
    cell_id = $row.cell_id
    report_name = $row.report_name
    exists = $exists
    sha256 = if ($exists) { Get-Sha256 $path } else { $null }
  }
}
if (@($reportInventory | Where-Object { -not $_.exists }).Count -ne 0) {
  throw 'one or more frozen H3 report files are missing'
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$identity = [ordered]@{
  schema_version = 'BOSS19_P4B_H3_IDENTITY_GATE_V2'
  accepted_h3_contract_head = $ExpectedH3Head
  accepted_h3_package = [ordered]@{ path = $H3Package; expected_sha256 = $ExpectedPackageSha; actual_sha256 = $packageSha; hash_match = $true }
  manifest = [ordered]@{ path = $h3Manifest; expected_sha256 = $ExpectedManifestSha; actual_sha256 = $manifestSha; row_count = 36; unique_cell_count = 36; exact_grid_match = $true }
  reports = [ordered]@{ expected_count = 36; existing_count = @($reportInventory).Count; inventory = @($reportInventory) }
  outcome_content_opened = $false
  deal_content_opened = $false
  note = 'Only package bytes were hash-checked; package/report outcome content was not parsed before the immutable timeline gate.'
}
$identityPath = Join-Path $OutDir 'h3_identity_gate.json'
Write-Utf8Json $identityPath $identity

# Immutable-market-input gate comes before any H3 outcome/deal inspection.
$marketInputProvided = -not [string]::IsNullOrWhiteSpace($MarketInputManifest)
if ($marketInputProvided -and !(Test-Path -LiteralPath $MarketInputManifest)) {
  throw "market input manifest path supplied but missing: $MarketInputManifest"
}
if ($marketInputProvided) {
  throw 'immutable market input manifest is present; blocker builder must stop. Use the separately reviewed P4B timeline builder from the market-input hashing step.'
}

$macroInstruments = @('AUDJPY','USDJPY','VIX','DXY','XAUUSD','BTCUSD','US10Y_JP10Y','COPPER')
$h3Cells = @(
  'XAUUSD:M15','XAUUSD:H1','XAUUSD:H4','EURUSD:M15','EURUSD:H1','EURUSD:H4',
  'GBPUSD:M15','GBPUSD:H1','GBPUSD:H4','AUDUSD:M15','AUDUSD:H1','AUDUSD:H4',
  'USDJPY:M15','USDJPY:H1','USDJPY:H4','BTCUSD:M15','BTCUSD:H1','BTCUSD:H4'
)
$snapshot = Join-Path $RepoRoot 'portfolio\mris\barometer_snapshot.csv'
$snapshotMacro = Join-Path $RepoRoot 'portfolio\mris\barometer_snapshot_macro.csv'
$state = Join-Path $RepoRoot 'portfolio\mris\regime_state.json'
$replay = Join-Path $RepoRoot 'scripts\mris\mris_backtest_timeline.ps1'
$legacyUnitInventory = Join-Path $OutDir 'h3_unit_evidence_inventory.json'
if (Test-Path -LiteralPath $legacyUnitInventory) { Remove-Item -LiteralPath $legacyUnitInventory -Force }
$marketGap = [ordered]@{
  schema_version = 'BOSS19_P4B_MARKET_INPUT_GAP_V2'
  status = 'BLOCKED(DATA_ENVIRONMENT_MISSING_IMMUTABLE_HISTORICAL_MARKET_INPUTS)'
  timeline_sha256 = $null
  market_input_manifest_provided = $false
  required_macro_daily_ohlc = [ordered]@{
    instruments = $macroInstruments
    classification_range_utc = '2020-01-01..2025-12-31 inclusive'
    warmup_requirement = '>=260 completed daily observations strictly before 2020-01-01'
    required_fields = @('utc_date','open','high','low','close')
  }
  required_local_ohlc = [ordered]@{
    cells = $h3Cells
    classification_range_utc = '2020-01-01..2025-12-31 inclusive'
    warmup_requirement = '>=252 calendar days plus 50 closed execution-TF bars strictly before 2020-01-01'
    identity = 'same named tester-data identity as the H3 cell'
    required_fields = @('open_time_utc','open','high','low','close')
  }
  inspected_bounded_candidates = @(
    [ordered]@{ path = 'portfolio/mris/barometer_snapshot.csv'; exists = (Test-Path -LiteralPath $snapshot); sha256 = if (Test-Path -LiteralPath $snapshot) { Get-Sha256 $snapshot } else { $null }; classification = 'CURRENT_DERIVED_SNAPSHOT_NOT_RAW_HISTORICAL_OHLC' },
    [ordered]@{ path = 'portfolio/mris/barometer_snapshot_macro.csv'; exists = (Test-Path -LiteralPath $snapshotMacro); sha256 = if (Test-Path -LiteralPath $snapshotMacro) { Get-Sha256 $snapshotMacro } else { $null }; classification = 'CURRENT_DERIVED_SNAPSHOT_NOT_RAW_HISTORICAL_OHLC' },
    [ordered]@{ path = 'portfolio/mris/regime_state.json'; exists = (Test-Path -LiteralPath $state); sha256 = if (Test-Path -LiteralPath $state) { Get-Sha256 $state } else { $null }; classification = 'CURRENT_DERIVED_STATE_NOT_RAW_HISTORICAL_OHLC' },
    [ordered]@{ path = 'scripts/mris/mris_backtest_timeline.ps1'; exists = (Test-Path -LiteralPath $replay); sha256 = if (Test-Path -LiteralPath $replay) { Get-Sha256 $replay } else { $null }; classification = 'NETWORK_REPLAY_CODE_NOT_IMMUTABLE_INPUT' }
  )
  prohibited_substitutions = @(
    'unpinned live web response',
    'current MRIS derived snapshot/state',
    'cross-install terminal history',
    'H3 outcome-derived reconstruction'
  )
  next_safe_action = 'Provide a versioned immutable raw-market-input manifest satisfying the frozen classifier, then restart at market-input hashing and timeline creation before opening H3 outcome/trade records.'
}
$marketPath = Join-Path $OutDir 'market_input_gap_manifest.json'
Write-Utf8Json $marketPath $marketGap

$blockerPackage = [ordered]@{
  schema_version = 'BOSS19_P4B_BLOCKER_PACKAGE_V2'
  status = 'BLOCKED(DATA_ENVIRONMENT_MISSING_IMMUTABLE_HISTORICAL_MARKET_INPUTS)'
  base = '2998339a3b3a76a63723563a849926ee115d4855'
  timeline_sha256 = $null
  h3_identity_gate = [ordered]@{ path = '_mt5_auto/p4b_boss19_regime/h3_identity_gate.json'; sha256 = Get-Sha256 $identityPath }
  market_input_gap_manifest = [ordered]@{ path = '_mt5_auto/p4b_boss19_regime/market_input_gap_manifest.json'; sha256 = Get-Sha256 $marketPath }
  builder = [ordered]@{ path = 'scripts/research/boss19_p4b/build_blocker_package.ps1'; sha256 = Get-Sha256 $PSCommandPath }
  h3_outcome_or_deal_content_opened = $false
  next_safe_action = $marketGap.next_safe_action
  authority_used = 'research-only; HOLDOUT/optimization/runtime/risk/deploy = NONE'
}
$packagePath = Join-Path $OutDir 'p4b_blocker_package.json'
Write-Utf8Json $packagePath $blockerPackage
$packageHash = Get-Sha256 $packagePath
[System.IO.File]::WriteAllText(
  (Join-Path $OutDir 'p4b_blocker_package.sha256'),
  "$packageHash  p4b_blocker_package.json`n",
  [System.Text.UTF8Encoding]::new($false)
)

Write-Output "STATUS=$($blockerPackage.status)"
Write-Output "H3_PACKAGE_SHA256=$packageSha"
Write-Output "H3_MANIFEST_SHA256=$manifestSha"
Write-Output "H3_REPORT_COUNT=$(@($reportInventory).Count)"
Write-Output "TIMELINE_SHA256=NONE"
Write-Output "BLOCKER_PACKAGE_SHA256=$packageHash"