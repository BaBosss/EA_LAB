[CmdletBinding()]
param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$H3Worktree = 'D:\EA_LAB_CONTROL\worktrees\hermes-h3-exec-47c77320',
  [string]$OutDir = (Join-Path (Get-Location).Path '_mt5_auto\p4b_boss19_regime')
)

$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) {
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Write-Utf8Json([string]$Path, $Value) {
  $json = $Value | ConvertTo-Json -Depth 12
  [System.IO.File]::WriteAllText(
    $Path,
    $json + "`n",
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Get-TableHeaders([string]$Html, [string]$TableName) {
  $table = [regex]::Match(
    $Html,
    "(?s)<th[^>]*>.*?<b>$([regex]::Escape($TableName))</b>.*?</tr>\s*<tr[^>]*>(.*?)</tr>"
  )
  if (!$table.Success) { return @() }
  return @([regex]::Matches($table.Groups[1].Value, '(?s)<b>(.*?)</b>') | ForEach-Object {
    [System.Net.WebUtility]::HtmlDecode($_.Groups[1].Value).Trim()
  })
}

$h3Manifest = Join-Path $H3Worktree 'tools\hermes_ea_lab_pilot\H3_BROAD_MATRIX_MANIFEST.csv'
$reportsDir = Join-Path $H3Worktree '_mt5_auto\reports'
if (!(Test-Path -LiteralPath $h3Manifest)) { throw "H3 manifest not found: $h3Manifest" }
if (!(Test-Path -LiteralPath $reportsDir)) { throw "H3 reports directory not found: $reportsDir" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$reports = @(Get-ChildItem -LiteralPath $reportsDir -File -Filter 'H3_B19_*_M1.htm' | Sort-Object Name)
$reportInventory = foreach ($report in $reports) {
  $html = Get-Content -Raw -LiteralPath $report.FullName
  $dealHeaders = @(Get-TableHeaders $html 'Deals')
  $orderHeaders = @(Get-TableHeaders $html 'Orders')
  [ordered]@{
    report_name = $report.Name
    sha256 = Get-Sha256 $report.FullName
    deal_headers = $dealHeaders
    order_headers = $orderHeaders
    opening_in_deal_row_count = ([regex]::Matches($html, '<td>in</td>')).Count
    realized_out_deal_row_count = ([regex]::Matches($html, '<td>out</td>')).Count
    durable_deal_id_column = ($dealHeaders -contains 'Deal')
    durable_deal_timestamp_column = ($dealHeaders -contains 'Time')
    durable_entry_timestamp_for_realized_out = $false
    source_position_id_column = ($dealHeaders -contains 'Position ID')
    source_entry_deal_link_column = ($dealHeaders -contains 'Entry Deal')
    source_basket_id_column = ($dealHeaders -contains 'Basket ID')
  }
}

$h3Inventory = [ordered]@{
  schema_version = 'BOSS19_P4B_H3_UNIT_INVENTORY_V1'
  created_utc = [DateTime]::UtcNow.ToString('o')
  source = [ordered]@{
    h3_worktree = $H3Worktree
    accepted_h3_contract_head = '47c7732048406277096c1ccc31734b4122ae7285'
    accepted_evidence_package_sha256 = '3d62d6d358831dc3897357d3d2008e9c0f1c9211716844112f8af96f79c7eeb2'
    h3_broad_matrix_manifest = $h3Manifest
    h3_broad_matrix_manifest_sha256 = Get-Sha256 $h3Manifest
  }
  report_count = $reportInventory.Count
  expected_report_count = 36
  report_inventory = $reportInventory
  unit_availability = [ordered]@{
    durable_source_deal_ids = 'AVAILABLE'
    durable_deal_timestamps = 'AVAILABLE'
    entry_timestamps = 'AVAILABLE_ON_IN_DEALS_ONLY'
    realized_out_to_entry_link = 'UNAVAILABLE_NO_SOURCE_POSITION_OR_ENTRY_DEAL_LINK'
    basket_ids = 'UNAVAILABLE_NO_SOURCE_BASKET_ID'
    basket_status = 'UNAVAILABLE_NO_SOURCE_BASKET_ID'
    attribution_unit_status = 'BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION)'
  }
  rationale = @(
    'The H3 HTML Deals table has Deal and Time fields and separate in/out rows.',
    'A realized out row has no source Position ID or Entry Deal field linking it to an opening in row.',
    'The reports expose no source Basket ID field. Order comments such as B19 L1 are not a complete source-emitted basket identity and are not used as one.',
    'The frozen attribution contract requires a durable opening timestamp for each realized DEAL/position and forbids inferred baskets or temporal matching.'
  )
}

$snapshot = Join-Path $RepoRoot 'portfolio\mris\barometer_snapshot.csv'
$snapshotMacro = Join-Path $RepoRoot 'portfolio\mris\barometer_snapshot_macro.csv'
$state = Join-Path $RepoRoot 'portfolio\mris\regime_state.json'
$replay = Join-Path $RepoRoot 'scripts\mris\mris_backtest_timeline.ps1'
$classifier = Join-Path $RepoRoot 'docs\research\BOSS19_P4_REGIME_CLASSIFIER_V1.md'
$attribution = Join-Path $RepoRoot 'docs\research\BOSS19_P4_REGIME_ATTRIBUTION_CONTRACT.md'
$macroInstruments = @('AUDJPY','USDJPY','VIX','DXY','XAUUSD','BTCUSD','US10Y_JP10Y','COPPER')
$h3Cells = @('XAUUSD:M15','XAUUSD:H1','XAUUSD:H4','EURUSD:M15','EURUSD:H1','EURUSD:H4','GBPUSD:M15','GBPUSD:H1','GBPUSD:H4','AUDUSD:M15','AUDUSD:H1','AUDUSD:H4','USDJPY:M15','USDJPY:H1','USDJPY:H4','BTCUSD:M15','BTCUSD:H1','BTCUSD:H4')

$marketGap = [ordered]@{
  schema_version = 'BOSS19_P4B_MARKET_INPUT_GAP_V1'
  created_utc = [DateTime]::UtcNow.ToString('o')
  status = 'BLOCKED(DATA_ENVIRONMENT_MISSING_IMMUTABLE_HISTORICAL_MARKET_INPUTS)'
  required_by = [ordered]@{
    classifier_id = 'BOSS19_P4_REGIME_CLASSIFIER_V1'
    classifier_version = '1.0.0'
    classifier_contract_sha256 = Get-Sha256 $classifier
    attribution_contract_sha256 = Get-Sha256 $attribution
  }
  required_raw_inputs = [ordered]@{
    macro_daily_ohlc = [ordered]@{
      instruments = $macroInstruments
      per_instrument_requirements = @($macroInstruments | ForEach-Object { [ordered]@{ instrument = $_; classification_range_utc = '2020-01-01..2025-12-31 inclusive'; warmup_requirement = '>=260 completed daily observations strictly before 2020-01-01' } })
      required_coverage = 'At least 260 completed daily observations before 2020-01-01, plus daily coverage through 2025-12-31.'
      required_fields = @('utc_date','open','high','low','close')
    }
    local_execution_tf_ohlc = [ordered]@{
      cells = $h3Cells
      per_cell_requirements = @($h3Cells | ForEach-Object { $p = $_.Split(':'); [ordered]@{ symbol = $p[0]; tf = $p[1]; classification_range_utc = '2020-01-01..2025-12-31 inclusive'; warmup_requirement = '>=252 calendar days plus 50 closed execution-TF bars strictly before 2020-01-01' } })
      required_coverage = 'At least 252 calendar days plus 50 closed execution-TF bars before 2020-01-01, plus closed-bar coverage through 2025-12-31.'
      required_identity = 'Exported from the same named tester-data identity as the H3 cell; no cross-install substitution.'
      required_fields = @('open_time_utc','open','high','low','close')
    }
  }
  inspected_local_candidates = @(
    [ordered]@{ path = $snapshot; exists = (Test-Path -LiteralPath $snapshot); sha256 = if (Test-Path -LiteralPath $snapshot) { Get-Sha256 $snapshot } else { $null }; result = 'CURRENT_DERIVED_SNAPSHOT_ONLY: aggregate indicator values, not historical daily OHLC.' },
    [ordered]@{ path = $snapshotMacro; exists = (Test-Path -LiteralPath $snapshotMacro); sha256 = if (Test-Path -LiteralPath $snapshotMacro) { Get-Sha256 $snapshotMacro } else { $null }; result = 'CURRENT_DERIVED_SNAPSHOT_ONLY: aggregate indicator values, not the required eight-barometer historical OHLC.' },
    [ordered]@{ path = $state; exists = (Test-Path -LiteralPath $state); sha256 = if (Test-Path -LiteralPath $state) { Get-Sha256 $state } else { $null }; result = 'DERIVED_CURRENT_REGIME_STATE_ONLY: no raw historical OHLC.' },
    [ordered]@{ path = $replay; exists = (Test-Path -LiteralPath $replay); sha256 = if (Test-Path -LiteralPath $replay) { Get-Sha256 $replay } else { $null }; result = 'NETWORK_FETCH_REPLAY_CODE_ONLY: contract explicitly excludes an unpinned live fetch as immutable P4 input.' }
  )
  unavailable_inputs = @(
    'Pinned raw historical daily OHLC snapshot for all eight macro barometers with provider/instrument mapping, UTC normalization, retrieval timestamp, hashes, and missing-bar policy.',
    'Pinned raw closed OHLC exports for all eighteen H3 Symbol x TF cells from the same tester-data identity as each H3 cell.'
  )
  prohibited_substitutions = @('unpinned live web response','current MRIS snapshot','derived historical regime CSV','cross-install terminal history','H3 outcome-derived reconstruction')
  next_safe_action = 'Provide a versioned, immutable historical-market snapshot and exact tester-data-identity OHLC exports; rerun P4B from input hashing before any H3 outcome join.'
}

$h3Path = Join-Path $OutDir 'h3_unit_evidence_inventory.json'
$marketPath = Join-Path $OutDir 'market_input_gap_manifest.json'
Write-Utf8Json $h3Path $h3Inventory
Write-Utf8Json $marketPath $marketGap

$package = [ordered]@{
  schema_version = 'BOSS19_P4B_BLOCKER_PACKAGE_V1'
  created_utc = [DateTime]::UtcNow.ToString('o')
  status = 'BLOCKED(EVIDENCE_UNSUITABLE_FOR_UNIT_ATTRIBUTION;DATA_ENVIRONMENT_MISSING_IMMUTABLE_HISTORICAL_MARKET_INPUTS)'
  base = '2998339a3b3a76a63723563a849926ee115d4855'
  timeline_sha256 = $null
  builder = [ordered]@{ path = 'scripts/research/boss19_p4b/build_blocker_package.ps1'; sha256 = Get-Sha256 $PSCommandPath }
  h3_unit_inventory = [ordered]@{ path = 'h3_unit_evidence_inventory.json'; sha256 = Get-Sha256 $h3Path }
  market_input_gap_manifest = [ordered]@{ path = 'market_input_gap_manifest.json'; sha256 = Get-Sha256 $marketPath }
  next_safe_action = 'Resolve both recorded prerequisites, then restart at market-input hashing and timeline creation before opening H3 outcome records.'
  authority_used = 'research-only; HOLDOUT/optimization/runtime/risk/deploy = NONE'
}

$packagePath = Join-Path $OutDir 'p4b_blocker_package.json'
Write-Utf8Json $packagePath $package
$packageHash = Get-Sha256 $packagePath
[System.IO.File]::WriteAllText(
  (Join-Path $OutDir 'p4b_blocker_package.sha256'),
  "$packageHash  p4b_blocker_package.json`n",
  [System.Text.UTF8Encoding]::new($false)
)

Write-Output "BLOCKER_PACKAGE=$packagePath"
Write-Output "BLOCKER_PACKAGE_SHA256=$packageHash"
