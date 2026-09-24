<#
ZCAG Phase A deterministic source/compile cage. It never starts a terminal,
Strategy Tester, deployment, optimization, or performance run.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [switch]$Compile,
    [string]$MetaEditor = 'D:\Meta 5\metaeditor64.exe'
)
$ErrorActionPreference = 'Stop'
if (!$RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

$entryPath = Join-Path $RepoRoot 'ea_template/core/entries/Entry_ZoneCompressedGrid.mqh'
$testPath = Join-Path $RepoRoot 'ea_template/tests/ZoneCompressedGrid_Transactional_Test.mq5'
$contractPath = Join-Path $RepoRoot 'docs/research/ZCAG_BOSS23_SHARED_EXECUTION_CONTRACT_20260922.md'
foreach ($path in @($entryPath,$testPath,$contractPath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing Phase A artifact: $path"
    }
}

$entry = [IO.File]::ReadAllText($entryPath)
$tests = [IO.File]::ReadAllText($testPath)
$contract = [IO.File]::ReadAllText($contractPath)

$requiredEntry = @(
    'ZCAG_INVALID_HISTORY',
    'ZCAG_VALID_NON_PIVOT',
    'ZCAG_ValidateRegimeSnapshot',
    'ZCAG_ApplyRegimeSnapshot',
    'ZCAG_ValidateDecisionSnapshot',
    'ZCAG_ApplyDecisionSnapshot',
    'decision_bar_ordinal',
    'elapsed_decision_bars',
    'ZCAG_FindTwoPivotsContiguous',
    'ZCAG_SupportQualified',
    'ZCAG_Target',
    'ZCAG_Stop',
    'reached >= config.min_levels',
    'config.zone_atr_width',
    'state.regime_bar_time=snapshot.bar_time',
    'state.decision_bar_time=snapshot.bar_time'
)
foreach ($needle in $requiredEntry) {
    if (!$entry.Contains($needle)) { throw "Missing transactional seam: $needle" }
}

$requiredTests = @(
    'regime.upper_read=false',
    'decision.high_read=false',
    'decision.low_read=false',
    'decision.close1_read=false',
    'decision.close2_read=false',
    'decision.step_atr_read=false',
    'decision.structure_atr_read=false',
    'decision.z_history_read=false',
    'decision.structure_lows[4]=0.0',
    'ZCAG_APPLY_ALREADY_CONSUMED',
    'ZCAG_RuntimeStateEqual',
    'state.reached=1',
    'narrow_zone.zone_atr_width=4.0',
    'state.bars_since_touch != 4 || !ready',
    'newer_bear.bar_time=12',
    'decision_t3.decision_bar_ordinal=23',
    'after_gap.decision_bar_ordinal=23',
    'invalid_elapsed.decision_bar_ordinal=2147483668',
    'state.bars_since_touch != 6',
    'ZCAG_Target(100.0,10.0,3)',
    'ZCAG_Stop(100.0,4.0,1.5)'
)
foreach ($needle in $requiredTests) {
    if (!$tests.Contains($needle)) { throw "Missing negative/retry case: $needle" }
}

$forbidden = @('LAB_ENTRY_23','Entry_Evaluate','ZoneCompressedGrid_OnTick',
               'Exec_Open(','Exec_SubmitPreparedOpen(','input ')
foreach ($needle in $forbidden) {
    if ($entry.Contains($needle)) {
        throw "Phase A authority ceiling violated by: $needle"
    }
}
if (!$contract.Contains('Phase A remains UNWIRED') -or
    !$contract.Contains('PARAM_LINKAGE')) {
    throw 'Contract is missing Phase A/PARAM_LINKAGE authority language'
}
Write-Host '[PASS] ZCAG transactional source and negative-case guards'

if ($Compile) {
    if (!(Test-Path -LiteralPath $MetaEditor -PathType Leaf)) {
        throw "COMPILE_UNAVAILABLE: $MetaEditor"
    }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('zcag_tx_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_template') -Destination $tempRoot -Recurse
    $source = Join-Path $tempRoot 'ea_template/tests/ZoneCompressedGrid_Transactional_Test.mq5'
    $log = [IO.Path]::ChangeExtension($source,'.compile.log')
    $process = Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$source`"", "/log:`"$log`"" -WindowStyle Hidden -PassThru
    if (!$process.WaitForExit(60000)) {
        throw "Compile still running; no process killed. PID=$($process.Id)"
    }
    $content = [IO.File]::ReadAllText($log)
    if ($content -notmatch 'Result: 0 errors, 0 warnings') {
        throw "Compile acceptance failed: $log"
    }
    Write-Host "[PASS] compile only: $source"
}
Write-Host '[PASS] no tester or performance run performed'
