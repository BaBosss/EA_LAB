<#
Prepared-open checked-lot source/compile cage. It proves the legacy Exec_Open
function is byte-for-byte unchanged from the contracted base and that no old
caller is routed through the additive API. It never starts a terminal/tester.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$BaseSha = 'e789bbbfa55bebefa2433cfd25695ce10b64a223',
    [switch]$Compile,
    [switch]$InjectCallerInventoryFailure,
    [string]$MetaEditor = 'D:\Meta 5\metaeditor64.exe'
)
$ErrorActionPreference = 'Stop'
if (!$RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

$executionPath = Join-Path $RepoRoot 'ea_template/core/Execution.mqh'
$testPath = Join-Path $RepoRoot 'ea_template/tests/Execution_CheckedLot_Test.mq5'
foreach ($path in @($executionPath,$testPath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing checked-lot artifact: $path"
    }
}
$execution = [IO.File]::ReadAllText($executionPath)
$tests = [IO.File]::ReadAllText($testPath)

function Get-FunctionText([string]$Text,[string]$Signature) {
    $start = $Text.IndexOf($Signature,[StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Missing function signature: $Signature" }
    $brace = $Text.IndexOf('{',$start)
    if ($brace -lt 0) { throw "Missing function body: $Signature" }
    $depth = 0
    for ($i=$brace; $i -lt $Text.Length; $i++) {
        if ($Text[$i] -eq '{') { $depth++ }
        elseif ($Text[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) { return $Text.Substring($start,$i-$start+1) }
        }
    }
    throw "Unterminated function: $Signature"
}

$signature = 'bool Exec_Open(const int direction, double lot, const double sl, const double tp, const string comment)'
$baseText = (& git -C $RepoRoot show "$BaseSha`:ea_template/core/Execution.mqh" | Out-String)
if ($LASTEXITCODE) { throw "Unable to read contracted base $BaseSha" }
$legacyBase = (Get-FunctionText $baseText $signature) -replace "`r`n","`n"
$legacyNow = (Get-FunctionText $execution $signature) -replace "`r`n","`n"
if ($legacyBase -cne $legacyNow) {
    throw 'Legacy Exec_Open signature/body changed'
}
Write-Host '[PASS] legacy Exec_Open signature/body unchanged'

$required = @(
    'struct Exec_MacroSnapshot',
    'struct Exec_PreparedOpen',
    'Exec_CheckedNormalizeLot',
    'Exec_CheckedLotIdentity',
    'Exec_PrepareOpen',
    'Exec_SubmitPreparedOpen',
    'Exec_AssessPreparedOpenResult',
    'EXEC_PREPARED_INTENT_ONLY',
    'EXEC_PREPARED_MARKET_DONE',
    'retcode != TRADE_RETCODE_DONE',
    'g_trade.ResultDeal()',
    'g_trade.ResultVolume()',
    'Exec_MacroIdentityEqual',
    'left.effective_block == right.effective_block',
    'left.effective_mult  == right.effective_mult',
    'submission_lot=prepared.final_checked_lot'
)
foreach ($needle in $required) {
    if (!$execution.Contains($needle)) { throw "Missing prepared-open seam: $needle" }
}
if (([regex]::Matches((Get-FunctionText $execution 'bool Exec_SubmitPreparedOpen('),
                      'Exec_(MacroLotMult|NormalizeLot)\s*\(')).Count -ne 0) {
    throw 'Prepared submit reapplies multiplier or normalization'
}
$submitText = Get-FunctionText $execution 'bool Exec_SubmitPreparedOpen('
if (([regex]::Matches($submitText,'g_trade\.Buy\s*\(')).Count -ne 1 -or
    ([regex]::Matches($submitText,'g_trade\.Sell\s*\(')).Count -ne 1) {
    throw 'Prepared submit must contain exactly one Buy and one Sell call site'
}

function Get-CallerInventory([switch]$InjectFailure) {
    if ($InjectFailure) {
        $tracked = @()
        $gitExitCode = 86
    } else {
        $tracked = @(& git -C $RepoRoot ls-files 'ea_template/*.mq5' 'ea_template/core/*.mqh' 'ea_template/core/**/*.mqh')
        $gitExitCode = $LASTEXITCODE
    }
    if ($gitExitCode -ne 0) {
        throw "Caller inventory git ls-files failed: exit=$gitExitCode"
    }
    return $tracked
}

# Fault injection executes the same fail-closed exit check as the real scan.
# In injection mode the whole runner must terminate before preservation PASS.
if ($InjectCallerInventoryFailure) {
    Get-CallerInventory -InjectFailure | Out-Null
    throw 'Caller inventory failure injection unexpectedly returned'
}

$savedErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$probeOutput = (& powershell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath `
    -RepoRoot $RepoRoot -BaseSha $BaseSha -InjectCallerInventoryFailure 2>&1 | Out-String)
$probeExitCode = $LASTEXITCODE
$ErrorActionPreference = $savedErrorActionPreference
if ($probeExitCode -eq 0) {
    throw 'Caller inventory failure injection did not fail the runner'
}
if ($probeOutput.Contains('[PASS] old callers remain on legacy API')) {
    throw 'Caller inventory failure printed caller-preservation PASS'
}
Write-Host '[PASS] injected caller inventory failure terminates before preservation PASS'

$tracked = Get-CallerInventory
foreach ($relative in $tracked) {
    if ($relative -eq 'ea_template/core/Execution.mqh' -or
        $relative -eq 'ea_template/core/entries/Entry_ZoneCompressedGrid.mqh' -or
        $relative -eq 'ea_template/tests/Execution_CheckedLot_Test.mq5') { continue }
    $text = [IO.File]::ReadAllText((Join-Path $RepoRoot $relative))
    if ($text -match '\bExec_(PrepareOpen|SubmitPreparedOpen)\s*\(') {
        throw "Existing caller routed through new API: $relative"
    }
}
Write-Host '[PASS] old callers remain on legacy API'

foreach ($needle in @('No multiplier','Valid reduce','Changed multiplier identity',
                       'Changed block identity','submission-facing seam',
                       'Same raw identity but changed effective multiplier',
                       'Same raw identity but changed effective block',
                       'DryRun remains true as intent only',
                       'DONE + deal + exact positive volume',
                       'TRADE_RETCODE_DONE_PARTIAL','TRADE_RETCODE_PLACED',
                       'TRADE_RETCODE_REJECT','TRADE_RETCODE_TIMEOUT',
                       'TRADE_RETCODE_REQUOTE','MathSqrt(-1.0)')) {
    if (!$tests.Contains($needle)) { throw "Missing checked-lot case: $needle" }
}

if ($Compile) {
    if (!(Test-Path -LiteralPath $MetaEditor -PathType Leaf)) {
        throw "COMPILE_UNAVAILABLE: $MetaEditor"
    }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('exec_checked_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_template') -Destination $tempRoot -Recurse
    $source = Join-Path $tempRoot 'ea_template/tests/Execution_CheckedLot_Test.mq5'
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
Write-Host '[PASS] checked-lot source guards complete; tpl_regression remains required'
