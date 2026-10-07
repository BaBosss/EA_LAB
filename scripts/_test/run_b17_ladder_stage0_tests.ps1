<#
Deterministic/adversarial source cage for the frozen B17 Stage-0 contract.
No terminal, Strategy Tester, performance run, optimizer, or runtime attach.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [switch]$Compile,
    [string]$MetaEditor = 'D:\Meta 5\MetaEditor64.exe'
)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$allowed = @(
    'ea_template/core/entries/Entry_Wave5.mqh',
    'ea_template/core/entries/Wave5Swings.mqh',
    'ea_template/core/Inputs.mqh',
    'ea_template/core/LabCore.mqh',
    'ea_template/core/ExitManager.mqh',
    'ea_template/core/MoneyManagement.mqh',
    'ea_template/core/Execution.mqh',
    'ea_template/core/Persist.mqh',
    'ea_template/core/Basket.mqh',
    'ea_template/core/RuntimeIdentity.mqh',
    'ea_template/core/InputSurface_gen.mqh',
    'ea_template/core/LockedConstants_gen.mqh',
    'docs/PARAM_REGISTRY.csv',
    'ea_template/tests/B17_LadderStage0_Test.mq5',
    'scripts/_test/run_b17_ladder_stage0_tests.ps1',
    '_triage/factory_os/activation.py',
    '_triage/factory_os/hypothesis_b17.py',
    'factory/hypotheses.jsonl',
    'factory/parameter_bindings.jsonl',
    '_triage/factory_os/run_activation_tests.py',
    '_triage/factory_os/run_param_surface_tests.py'
)

$changed = @(& git -C $RepoRoot diff --name-only --diff-filter=ACMRTUXB)
if ($LASTEXITCODE -ne 0) { throw 'git diff inventory failed' }
$outside = @($changed | Where-Object { $_ -notin $allowed })
if ($outside.Count -gt 0) { throw "B17 Stage-0 path escape: $($outside -join ', ')" }
Write-Host '[PASS] B17 Stage-0 changed-path boundary'

$entry = [IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/core/entries/Entry_Wave5.mqh'))
$persist = [IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/core/Persist.mqh'))
$execution = [IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/core/Execution.mqh'))
$core = [IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/core/LabCore.mqh'))
$fixture = [IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/tests/B17_LadderStage0_Test.mq5'))

function Require([string]$Text,[string]$Needle,[string]$Label) {
    if (-not $Text.Contains($Needle)) { throw "missing ${Label}: $Needle" }
    Write-Host "[PASS] $Label"
}

foreach ($item in @(
    @($entry,'B17_LEVEL_EXPIRED_BLOCKED','EXPIRED_BLOCKED state'),
    @($entry,'B17_LEVEL_PARTIAL_FILLED_CONSUMED','partial-fill consumed state'),
    @($entry,'B17_BAR_INVALIDATE','same-bar invalidation decision'),
    @($entry,'B17_RISK_LINEAR_DEPTH_WEIGHTED','linear-depth risk mode'),
    @($entry,'B17_LIFECYCLE_CLOSE_INTENT','durable close-intent lifecycle'),
    @($entry,'AMBIGUOUS_NO_DUPLICATE_RETRY','ambiguous no-retry evidence'),
    @($persist,'Persist_StructKey','explicit per-structure persistence seam'),
    @($persist,'Persist_StructSet','checked per-structure persistence write'),
    @($execution,'Exec_OpenForMagic','per-structure Magic execution seam'),
    @($execution,'Exec_CloseMagic','per-Magic close seam'),
    @($core,'B17_OnTick','B17-only lifecycle routing'),
    @($fixture,'multi-level crossed bar','deepest-level adversarial fixture'),
    @($fixture,'failed close released close intent','failed-close fixture'),
    @($fixture,'restart replay lost structure state','restart fixture'),
    @($fixture,'cross-Magic ownership predicate leaked','cross-Magic fixture')
)) { Require $item[0] $item[1] $item[2] }

# Static prohibition: Stage-0 contains no pending entry or optimizer/tester launch.
if ($entry -match '\bExec_PlacePending\s*\(') { throw 'B17 Stage-0 added a pending-entry path' }
if ($fixture -match '(?i)\b(OrderSend|\.Buy\s*\(|\.Sell\s*\(|Exec_Open\s*\()') {
    throw 'deterministic fixture contains an order-opening call'
}
Write-Host '[PASS] no pending entry and fixture has no order call'

if ($Compile) {
    if (-not (Test-Path -LiteralPath $MetaEditor -PathType Leaf)) {
        throw "COMPILE_UNAVAILABLE: $MetaEditor"
    }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('b17_stage0_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    try {
        Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_template') -Destination $tempRoot -Recurse
        foreach ($relative in @('Boss_17_Wave5.mq5','tests\B17_LadderStage0_Test.mq5')) {
            $source = Join-Path (Join-Path $tempRoot 'ea_template') $relative
            $log = "$source.compile.log"
            $process = Start-Process -FilePath $MetaEditor `
                -ArgumentList "/compile:`"$source`"", "/log:`"$log`"" `
                -WindowStyle Hidden -PassThru
            if (-not $process.WaitForExit(60000)) {
                throw "compile still running; no process killed. PID=$($process.Id)"
            }
            $content = [IO.File]::ReadAllText($log)
            if ($content -notmatch 'Result: 0 errors, 0 warnings') {
                throw "compile acceptance failed: $log`n$content"
            }
            Write-Host "[PASS] compile 0 errors / 0 warnings: $relative"
        }
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}

Write-Host '[PASS] B17 Stage-0 deterministic/adversarial source cage'
