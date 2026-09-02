param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
$tests = 0
function Pass([string]$m){ $script:tests++; Write-Output "ok $tests - $m" }
function Assert([bool]$c,[string]$m){ if(-not $c){ throw "FAIL: $m" }; Pass $m }

$wrapper = Join-Path $RepoRoot 'ea_template\Probe_19_AdaptiveTrendGrid_P4BUnitExport.mq5'
$parent = 'ea_template/Probe_19_AdaptiveTrendGrid.mq5'
$parentBase = '3207b4372a296e1fe6fc60f0b8c1ce3f0e18e4f1'
$builder = Join-Path $RepoRoot 'tools\p4b_unit_attribution\build_source_bound_units.py'
$runner = Join-Path $RepoRoot 'scripts\research\boss19_p4b\run_unit_export_cell.ps1'
$source = Get-Content -LiteralPath $wrapper -Raw -Encoding UTF8
$runnerText = Get-Content -LiteralPath $runner -Raw -Encoding UTF8

Assert ($source -match '#define LAB_ENTRY_19') 'diagnostic child compiles the same Boss19 entry family'
Assert ($source -match '#include "core/LabCore.mqh"') 'diagnostic child uses unchanged LabCore mechanics'
Assert ($source -match 'void OnTradeTransaction') 'diagnostic child keeps trade-transaction observation hook'
Assert ($source -match 'double OnTester\(\)') 'diagnostic child finalizes source after tester completion'
Assert ($source -match 'HistorySelect\(0, TimeCurrent\(\)\)') 'final snapshot reads terminal-owned history after test'
Assert ($source -match 'DEAL_POSITION_ID') 'source export reads MT5 source-emitted DEAL_POSITION_ID'
Assert ($source -match '#define P4B_UNIT_SCHEMA "BOSS19_P4B_UNIT_SOURCE_V2"') 'source export uses Repair03 source schema V2'
Assert ($source -match '"configured_run_magic","source_deal_magic"') 'source schema separates configured run magic from per-deal source magic'
$writeStart=$source.IndexOf('void P4B_WriteSelectedDeal'); $writeEnd=$source.IndexOf('void P4B_WriteDeal',$writeStart); Assert ($writeStart -ge 0 -and $writeEnd -gt $writeStart) 'selected-deal writer is statically isolatable'
$writeText=$source.Substring($writeStart,$writeEnd-$writeStart)
Assert ($writeText -match 'sourceDealMagic = HistoryDealGetInteger\(deal, DEAL_MAGIC\)') 'per-deal source magic comes from HistoryDealGetInteger DEAL_MAGIC'
Assert ($writeText -match 'IntegerToString\(\(int\)_0_Magic\)[\s\S]*StringFormat\("%I64d", sourceDealMagic\)') 'configured run magic and source deal magic are emitted as distinct fields'
Assert ($source -match 'DEAL_TIME_MSC') 'source export preserves source deal time milliseconds'
Assert ($source -match 'FILE_COMMON') 'source export writes outside report HTML via Common Files'
Assert ($source -notmatch '\bExec_') 'diagnostic wrapper calls no execution helper'
Assert ($source -notmatch '\bg_trade\b') 'diagnostic wrapper calls no CTrade object'
Assert ($source -notmatch '\bRiskControl_') 'diagnostic wrapper calls no risk-control helper'
$finalStart=$source.IndexOf('bool P4B_WriteFinalHistorySnapshot()')
$finalEnd=$source.IndexOf('void OnTradeTransaction',$finalStart)
Assert ($finalStart -ge 0 -and $finalEnd -gt $finalStart) 'final snapshot function is statically isolatable'
$finalText=$source.Substring($finalStart,$finalEnd-$finalStart)
Assert ($finalText -match 'long ownedPositionIds\[\]') 'final snapshot builds an explicit owned-position set'
Assert ($finalText -match 'P4B_SelectedDealIsEligible\(deal\)') 'first pass derives ownership only from strict-magic source deals'
Assert ($finalText -match 'P4B_PositionSetAdd\(ownedPositionIds, positionId\)') 'first pass adds exact DEAL_POSITION_ID ownership'
Assert ($finalText -match 'P4B_PositionSetContains\(ownedPositionIds, positionId\)') 'second pass admits deals only through exact owned position identity'
Assert ($finalText -notmatch 'DEAL_ORDER|DEAL_VOLUME|DEAL_PROFIT') 'final admission does not use order, volume, or P&L heuristics'
Assert ($finalText.IndexOf('P4B_PositionSetAdd(ownedPositionIds, positionId)') -lt $finalText.IndexOf('P4B_PositionSetContains(ownedPositionIds, positionId)')) 'ownership pass precedes emission pass'
$parentDiff = @(git -C $RepoRoot diff $parentBase -- $parent)
Assert ($parentDiff.Count -eq 0) 'original Boss19 parent wrapper remains byte-untouched from contract base'
Assert ($runnerText -match 'H3_BROAD_MATRIX_MANIFEST\.csv') 'runner binds every cell to the frozen H3 manifest'
Assert ($runnerText -match '\$ExpectedManifestSha=.*56e7b996a9c6836e5d7cedcbe3c9a212620b9fcc10c4fe3a750f44c8226cfefd' -and $runnerText -match 'manifestSha -ne \$ExpectedManifestSha') 'runner pins frozen H3 manifest SHA before runtime'
Assert ($runnerText -match '\$ExpectedSourceSha=.*dd61c78ca6680fcec64260ea200e04c2faa4824abbbeac218100a2db997f33cf' -and $runnerText -match 'sourceSha -ne \$ExpectedSourceSha') 'runner pins accepted diagnostic source SHA before runtime'
Assert ($runnerText -match '\$ExpectedEx5Sha=.*8f68ee1cf726f27de0ec5da0f1ad4b5f88f129435f9b2bf9b27d5ba378a9abd2' -and $runnerText -match 'artifactSha -ne \$ExpectedEx5Sha') 'runner pins accepted diagnostic EX5 SHA before runtime'
Assert ($runnerText -match '\$ExpectedBuildReceipt=.*br-6c63129e01ac4458a62d420c5594560f' -and $runnerText -match 'receiptMatches.Count -ne 1') 'runner requires exact accepted Repair03 build receipt'
Assert ($runnerText -match '\$ExpectedReceiptRegistrySha=.*4aac0ace64c5ddc5c05adbcde394705e365d1b8b50322649da2251d49aa92818' -and $runnerText -match 'receiptRegistrySha -ne \$ExpectedReceiptRegistrySha') 'runner pins Repair03 receipt registry SHA'
Assert ($runnerText -match 'unknown_time_unit_count -ne 0.*unknown-time realized units') 'runner refuses unknown-time units before PASS'
Assert ($runnerText -match 'h3_manifest_sha256=\$manifestSha.*build_receipt=\$ExpectedBuildReceipt') 'run manifest records pinned H3 manifest and build receipt identity'
Assert ($runnerText -match 'Select-Object -Unique symbol,period,period_name,configured_run_magic,account_margin_mode') 'runner identity uses configured run magic, not per-deal source magic'
Assert ($runnerText -match 'source_magic_provenance') 'runner carries source magic provenance into run evidence'
Assert ($runnerText -match 'source_owned_position_count.*source_position_count') 'runner enforces exact source-magic ownership parity'
Assert ($runnerText -match 'source export is stale') 'runner refuses stale Common-Files source'
Assert ($runnerText -match '\$startedLocal=Get-Date') 'report freshness keeps a local wall-clock start'
Assert ($runnerText -match '\$startedUtc=\[DateTime\]::UtcNow') 'source freshness captures an explicit UTC start'
Assert ($runnerText -match '-RunStart \$startedLocal') 'report freshness compares local-to-local'
Assert ($runnerText -match 'LastWriteTimeUtc -lt \$startedUtc') 'source freshness compares UTC-to-UTC'
Assert ($runnerText -notmatch 'LastWriteTimeUtc -lt \$startedLocal') 'source freshness never compares UTC file time with local start'
Assert ($runnerText -match 'started_utc=\$startedUtc\.ToString\(''o''\)') 'run manifest records the captured UTC start directly'
Assert ($runnerText -match 'source_out_count.*total_trades') 'runner reconciles source OUT count to tester report trades'
Assert ($runnerText -match 'HOLDOUT date crossing') 'runner refuses dates beyond the pre-HOLDOUT ceiling'
Assert ($runnerText -notmatch 'AllowLegacyIdentity') 'runner has no legacy identity bypass'
$launchStart=$runnerText.IndexOf('$runOutput=& $runner'); $launchEnd=$runnerText.IndexOf('$runExit=',$launchStart); $launchText=$runnerText.Substring($launchStart,$launchEnd-$launchStart); Assert ($launchText -notmatch '-Force') 'runner has no forced MT5 ownership bypass'

. (Join-Path $RepoRoot 'scripts\use_python.ps1')
$py = Assert-PortablePython -Root $RepoRoot -Provision
$oldEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$out = & $py -m unittest discover -s (Join-Path $RepoRoot 'tools\p4b_unit_attribution\tests') -p 'test_source_bound_units.py' 2>&1 | Out-String
$code1 = $LASTEXITCODE
$out2 = & $py -m unittest discover -s (Join-Path $RepoRoot 'tools\p4b_unit_attribution\tests') -p 'test_h3_unit_suitability.py' 2>&1 | Out-String
$code2 = $LASTEXITCODE
$ErrorActionPreference = $oldEap
Assert ($code1 -eq 0) 'source-bound unit builder tests pass'
Assert ($code2 -eq 0) 'existing H3 fail-closed suitability tests still pass'

$builderText = Get-Content -LiteralPath $builder -Raw -Encoding UTF8
foreach($forbidden in @('FIFO','TEMPORAL_PROXIMITY','VOLUME_MATCH','ORDER_SEQUENCE','P_AND_L_MATCH')){
  Assert ($builderText -notmatch [regex]::Escape($forbidden)) "unit builder does not implement forbidden inference $forbidden"
}
Write-Output "P4B_UNIT_EXPORT_TESTS PASS tests=$tests"
