<#
FB-A01 deterministic source/fixture cage.
No Strategy Tester, backtest, optimizer, runtime attachment, deploy, or push.
With -Compile, MetaEditor compiles isolated temporary copies only.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [switch]$Compile,
    [string]$MetaEditor = 'D:\Meta 5\metaeditor64.exe'
)
$ErrorActionPreference = 'Stop'
if (!$RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$entryPath = Join-Path $RepoRoot 'ea_template/core/entries/Entry_AdaptiveDonchianFlip.mqh'
$testPath = Join-Path $RepoRoot 'ea_template/tests/AdaptiveDonchianFlip_Test.mq5'
$corePath = Join-Path $RepoRoot 'ea_template/core/LabCore.mqh'
$inputPath = Join-Path $RepoRoot 'ea_template/core/Inputs.mqh'
$wrapperPath = Join-Path $RepoRoot 'ea_template/Boss_24_AdaptiveDonchianFlip.mq5'
foreach ($path in @($entryPath,$testPath,$corePath,$inputPath,$wrapperPath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing FB-A01 source: $path" }
}
$entry = [IO.File]::ReadAllText($entryPath)
$tests = [IO.File]::ReadAllText($testPath)
$core = [IO.File]::ReadAllText($corePath)
$inputs = [IO.File]::ReadAllText($inputPath)
$wrapper = [IO.File]::ReadAllText($wrapperPath)

$requiredEntry = @(
    'value <= current',
    'decision_close > upper + buffer',
    'decision_close < lower - buffer',
    'basic_upper < prev_upper || prev_close > prev_upper',
    'basic_lower > prev_lower || prev_close < prev_lower',
    'closes[i] > prev_upper',
    'closes[i] < prev_lower',
    'i+2',
    'ACCOUNT_MARGIN_MODE_RETAIL_HEDGING',
    'RiskControl_AllowNewOrder()',
    'Exec_CloseAll()',
    'pending_direction',
    'reverse_attempted',
    'ADF_TrailTightens',
    'request'
)
foreach ($needle in $requiredEntry) {
    if (!$entry.Contains($needle)) { throw "Missing FB-A01 implementation seam: $needle" }
}
$requiredCases = @(
    'decision bar excluded','equality is not a BUY','equality is not a SELL',
    'ties count','missing/nonpositive','bounds map LOW/NORMAL/HIGH/EXTREME',
    'warmup seed','transitions DOWN then UP','50-sample warmup',
    'median averages middle pair','median ceiling blocks','ATR cap blocks',
    'initial SL distance','never loosens','same-direction',
    'partial close','broker close error','stale ownership',
    'exact flat verification','one open attempt','bar change cancels',
    'netting','ownership is isolated','shared-risk halt'
)
foreach ($needle in $requiredCases) {
    if (($tests + $entry) -notmatch [regex]::Escape($needle)) {
        throw "Missing FB-A01 test/guard coverage: $needle"
    }
}
if ($core -notmatch '(?s)#ifdef LAB_ENTRY_24.*?RiskControl_CheckDD\(\).*?AdaptiveDonchianFlip_OnTick\(\).*?return;') {
    throw 'LAB_ENTRY_24 does not short-circuit behind shared hard RiskControl'
}
if ($wrapper -notmatch '#define LAB_ENTRY_24' -or
    $wrapper -notmatch '#define LAB_ENTRY_TAG "24_AdaptiveDonchianFlip"') {
    throw 'Boss_24 wrapper identity mismatch'
}
foreach ($name in @('_24_DonchianBars','_24_ST_ATRPeriod','_24_ST_Mult',
    '_24_ATRPeriod','_24_ATRPctLookback','_24_ATRPctLow','_24_ATRPctHigh',
    '_24_ATRPctExtreme','_24_BufferATR_Normal','_24_BufferATR_High',
    '_24_SL_ATR_Normal','_24_SL_ATR_High','_24_FixedLot',
    '_24_SpreadSamples','_24_SpreadMedianMult','_24_SpreadATRCap')) {
    if ($inputs -notmatch ('input\s+\w+\s+' + [regex]::Escape($name) + '\s*=') -or
        $inputs -notmatch ('LAB_CONST_' + [regex]::Escape($name))) {
        throw "Input/constant guard pair missing: $name"
    }
}
Write-Host '[PASS] FB-A01 deterministic source/state coverage present'

if ($Compile) {
    if (!(Test-Path -LiteralPath $MetaEditor -PathType Leaf)) {
        throw "COMPILE_UNAVAILABLE: $MetaEditor"
    }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('fb_a01_compile_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_template') -Destination $tempRoot -Recurse
    foreach ($rel in @('Boss_24_AdaptiveDonchianFlip.mq5','tests/AdaptiveDonchianFlip_Test.mq5')) {
        $src = Join-Path (Join-Path $tempRoot 'ea_template') $rel
        $log = [IO.Path]::ChangeExtension($src,'.compile.log')
        $p = Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$src`"","/log:`"$log`"" -WindowStyle Hidden -PassThru
        if (!$p.WaitForExit(60000)) { throw "Compile still running; process not killed. PID=$($p.Id)" }
        $content = [IO.File]::ReadAllText($log)
        if ($content -notmatch 'Result: 0 errors, 0 warnings') { throw "Compile failed: $log" }
        Write-Host "[PASS] compile 0/0: $rel"
    }
}
