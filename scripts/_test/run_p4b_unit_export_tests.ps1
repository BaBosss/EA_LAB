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
Assert ($source -match 'DEAL_TIME_MSC') 'source export preserves source deal time milliseconds'
Assert ($source -match 'FILE_COMMON') 'source export writes outside report HTML via Common Files'
Assert ($source -notmatch '\bExec_') 'diagnostic wrapper calls no execution helper'
Assert ($source -notmatch '\bg_trade\b') 'diagnostic wrapper calls no CTrade object'
Assert ($source -notmatch '\bRiskControl_') 'diagnostic wrapper calls no risk-control helper'
$parentDiff = @(git -C $RepoRoot diff $parentBase -- $parent)
Assert ($parentDiff.Count -eq 0) 'original Boss19 parent wrapper remains byte-untouched from contract base'
Assert ($runnerText -match 'H3_BROAD_MATRIX_MANIFEST\.csv') 'runner binds every cell to the frozen H3 manifest'
Assert ($runnerText -match 'source export is stale') 'runner refuses stale Common-Files source'
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
