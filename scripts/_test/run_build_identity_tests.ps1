<#
Build/config launch-identity cage.

The fixture is deliberately below the MT5 process boundary. It proves the preflight binds the
exact EX5 bytes to a stamped receipt and refuses missing/stale identity, while the existing
runtime-identity Python cage proves the emitted config fingerprint mismatch is fail-visible.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $RepoRoot 'scripts\lib\build_receipt.ps1')
. (Join-Path $RepoRoot 'scripts\lib\setfile_surface.ps1')

$pass = 0
$fail = 0
function Check([string]$name, [bool]$condition, [string]$detail = '') {
    if ($condition) { $script:pass++; Write-Host "[PASS] $name" }
    else { $script:fail++; Write-Host "[FAIL] $name :: $detail" -ForegroundColor Red }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('build_identity_' + [guid]::NewGuid().ToString('N'))
$experts = Join-Path $tmp 'Experts'
$registry = Join-Path $tmp 'build_receipts.jsonl'
$source = Join-Path $tmp 'EA_X_TEST.mq5'
$artifact = Join-Path $experts 'EA_X_TEST.ex5'
$set = Join-Path $tmp 'EA_X_TEST.set'
New-Item -ItemType Directory -Path $experts -Force | Out-Null
try {
    [IO.File]::WriteAllText($source, 'source-v1', (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($artifact, 'artifact-v1', (New-Object Text.UTF8Encoding($false)))
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    $artifactHash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
    $receipt = 'br-' + ('a' * 32)
    $record = [ordered]@{
        schema='build_receipt/1'; build_receipt=$receipt; ea_logical_identity='EA_X_TEST'
        artifact_path=$artifact; artifact_sha256=$artifactHash; source_path=$source; source_sha256=$sourceHash
    }
    [IO.File]::WriteAllText($registry, (($record | ConvertTo-Json -Compress) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))

    $good = Get-BuildReceiptStatus -Expert 'EA_X_TEST' -ExpertsDir $experts -RegistryPath $registry
    Check 'valid EX5 obtains stamped receipt identity' ($good.State -eq 'PASS' -and $good.BuildReceipt -eq $receipt) ($good | ConvertTo-Json -Depth 5)

    [IO.File]::WriteAllText($artifact, 'wrong-artifact', (New-Object Text.UTF8Encoding($false)))
    $wrong = Get-BuildReceiptStatus -Expert 'EA_X_TEST' -ExpertsDir $experts -RegistryPath $registry
    Check 'wrong EX5 bytes are detected' ($wrong.State -eq 'MISMATCH') ($wrong | ConvertTo-Json -Depth 5)

    [IO.File]::WriteAllText($artifact, 'artifact-v1', (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($source, 'source-v2', (New-Object Text.UTF8Encoding($false)))
    $stale = Get-BuildReceiptStatus -Expert 'EA_X_TEST' -ExpertsDir $experts -RegistryPath $registry
    Check 'EX5 whose recorded source is stale is detected' ($stale.State -eq 'STALE') ($stale | ConvertTo-Json -Depth 5)

    Remove-Item -LiteralPath $registry -Force
    $missing = Get-BuildReceiptStatus -Expert 'EA_X_TEST' -ExpertsDir $experts -RegistryPath $registry
    Check 'missing required build identity is not silently accepted' (-not $missing.Valid -and $missing.State -eq 'UNVERIFIABLE') ($missing | ConvertTo-Json -Depth 5)

    [IO.File]::WriteAllText($registry, (($record | ConvertTo-Json -Compress) + [Environment]::NewLine).Replace($receipt, 'UNSTAMPED'), (New-Object Text.UTF8Encoding($false)))
    $unstamped = Get-BuildReceiptStatus -Expert 'EA_X_TEST' -ExpertsDir $experts -RegistryPath $registry
    Check 'explicit UNSTAMPED receipt is not silently accepted' (-not $unstamped.Valid -and $unstamped.State -eq 'UNSTAMPED') ($unstamped | ConvertTo-Json -Depth 5)

    # ORDER-1461 executable policy fixture. The canonical artifact is receipt-bound; the root
    # spelling is only a managed byte-for-byte compatibility output and is never independently
    # recorded or compiled.
    $canonicalDir = Join-Path $experts 'EALabTpl'
    $canonicalSource = Join-Path $canonicalDir 'Boss_14_GridLog.mq5'
    $canonicalArtifact = Join-Path $canonicalDir 'Boss_14_GridLog.ex5'
    $compatArtifact = Join-Path $experts 'Boss_14_GridLog.ex5'
    $compatRegistry = Join-Path $tmp 'compat_build_receipts.jsonl'
    New-Item -ItemType Directory -Path $canonicalDir -Force | Out-Null
    [IO.File]::WriteAllText($canonicalSource, 'canonical-source-v1', (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($canonicalArtifact, 'canonical-artifact-v1', (New-Object Text.UTF8Encoding($false)))
    $canonicalSourceHash = (Get-FileHash -LiteralPath $canonicalSource -Algorithm SHA256).Hash.ToLowerInvariant()
    $canonicalArtifactHash = (Get-FileHash -LiteralPath $canonicalArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
    $canonicalReceipt = 'br-' + ('b' * 32)
    $canonicalRecord = [ordered]@{
        schema='build_receipt/1'; build_receipt=$canonicalReceipt; ea_logical_identity='14_GridLog'
        artifact_path=$canonicalArtifact; artifact_sha256=$canonicalArtifactHash
        source_path=$canonicalSource; source_sha256=$canonicalSourceHash
    }
    [IO.File]::WriteAllText($compatRegistry, (($canonicalRecord | ConvertTo-Json -Compress) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))

    $canonicalGood = Get-BuildReceiptStatus -Expert 'EALabTpl\Boss_14_GridLog' -ExpertsDir $experts -RegistryPath $compatRegistry
    Check 'canonical invocation obtains the expected stamped identity' ($canonicalGood.State -eq 'PASS' -and $canonicalGood.BuildReceipt -eq $canonicalReceipt) ($canonicalGood | ConvertTo-Json -Depth 5)

    $compatMissing = Get-ManagedCompatibilityStatus -ExpertsDir $experts -RegistryPath $compatRegistry
    Check 'missing managed root compatibility output is refused' (-not $compatMissing.Valid -and $compatMissing.State -eq 'MISSING') ($compatMissing | ConvertTo-Json -Depth 5)

    Sync-ManagedCompatibilityArtifact -CanonicalArtifactPath $canonicalArtifact -CompatibilityArtifactPath $compatArtifact | Out-Null
    $compatGood = Get-ManagedCompatibilityStatus -ExpertsDir $experts -RegistryPath $compatRegistry
    Check 'canonical EX5 plus managed root copy passes as one identity' ($compatGood.State -eq 'PASS' -and $compatGood.BuildReceipt -eq $canonicalReceipt -and $compatGood.ArtifactSha256 -eq $canonicalArtifactHash) ($compatGood | ConvertTo-Json -Depth 5)

    [IO.File]::WriteAllText($compatArtifact, 'stale-root-compatibility', (New-Object Text.UTF8Encoding($false)))
    $compatWrong = Get-ManagedCompatibilityStatus -ExpertsDir $experts -RegistryPath $compatRegistry
    Check 'wrong or stale root EX5 is detected' (-not $compatWrong.Valid -and $compatWrong.State -eq 'MISMATCH') ($compatWrong | ConvertTo-Json -Depth 5)

    Sync-ManagedCompatibilityArtifact -CanonicalArtifactPath $canonicalArtifact -CompatibilityArtifactPath $compatArtifact | Out-Null
    [IO.File]::WriteAllText($canonicalSource, 'canonical-source-v2', (New-Object Text.UTF8Encoding($false)))
    $compatSourceStale = Get-ManagedCompatibilityStatus -ExpertsDir $experts -RegistryPath $compatRegistry
    Check 'root copy with canonical source or receipt mismatch is refused' (-not $compatSourceStale.Valid -and $compatSourceStale.State -eq 'STALE') ($compatSourceStale | ConvertTo-Json -Depth 5)

    Remove-Item -LiteralPath $compatRegistry -Force
    $compatReceiptMissing = Get-ManagedCompatibilityStatus -ExpertsDir $experts -RegistryPath $compatRegistry
    Check 'root copy with missing canonical build receipt is refused' (-not $compatReceiptMissing.Valid -and $compatReceiptMissing.State -eq 'UNVERIFIABLE') ($compatReceiptMissing | ConvertTo-Json -Depth 5)

    $legacy = Get-BuildReceiptStatus -Expert 'Boss_14_GridLog_OLD2' -ExpertsDir $experts -RegistryPath $compatRegistry
    Check 'legacy _OLD executable spelling is refused' (-not $legacy.Valid -and $legacy.State -eq 'LEGACY_REFUSED') ($legacy | ConvertTo-Json -Depth 5)

    $legacyWriterFiles = @(
        (Join-Path $RepoRoot '_mt5_auto\agoil_addgate_ab.ps1'),
        (Join-Path $RepoRoot '_mt5_auto\pa_grid_step2_ab.ps1')
    )
    foreach ($writer in $legacyWriterFiles) {
        $writerText = Get-Content -LiteralPath $writer -Raw
        $bareActive = [regex]::Matches($writerText, 'ex\s*=\s*["'']Boss_14_GridLog["'']').Count
        Check "active writer uses canonical spelling ($([IO.Path]::GetFileName($writer)))" ($bareActive -eq 0 -and $writerText.Contains('EALabTpl\Boss_14_GridLog') -and $writerText.Contains('REFUSE: legacy executable identity')) $writer
    }

    $deployText = Get-Content -LiteralPath (Join-Path $RepoRoot 'ea_template\deploy.ps1') -Raw
    Check 'deployment refreshes root compatibility only from canonical Boss_14 output' ($deployText.Contains('Sync-ManagedCompatibilityArtifact') -and $deployText.Contains("`$t -ieq 'Boss_14_GridLog.mq5'")) 'ea_template/deploy.ps1'

    $header = '; build=LAB_ENTRY_TEST surface=3 effective_config_hash=' + ('c' * 64) + ' (surface+constants)'
    [IO.File]::WriteAllLines($set, @($header, 'A=1', 'B=2', 'C=3'))
    $surface = Get-SetSurfaceState -Path $set
    $config = Get-SetConfigIdentity -Path $set -Surface $surface
    $line = Format-LaunchIdentityLine -Build $good -Config $config
    Check 'valid full config obtains deterministic fingerprint identity' ($config.Valid -and $line -match 'build_receipt=br-[0-9a-f]{32}' -and $line -match ('config_fingerprint=' + ('c' * 64))) $line

    [IO.File]::WriteAllLines($set, @('; build=LAB_ENTRY_TEST surface=4 effective_config_hash=' + ('c' * 64) + ' (surface+constants)', 'A=1', 'B=2', 'C=3'))
    $mismatchedSurface = Get-SetSurfaceState -Path $set
    $mismatchedConfig = Get-SetConfigIdentity -Path $set -Surface $mismatchedSurface
    Check 'config surface mismatch is fail-visible' ($mismatchedSurface.State -eq 'MISMATCH' -and -not $mismatchedConfig.Valid) ($mismatchedConfig | ConvertTo-Json -Depth 5)

    $missingConfig = Get-SetConfigIdentity -Path '' -Surface $null
    Check 'missing config identity is not silently accepted' (-not $missingConfig.Valid -and $missingConfig.State -eq 'MISSING') ($missingConfig | ConvertTo-Json -Depth 5)

    foreach ($runner in @('scripts\mt5_run.ps1', 'scripts\mt5_optimize.ps1', 'scripts\run_backtest.ps1')) {
        $text = Get-Content -LiteralPath (Join-Path $RepoRoot $runner) -Raw
        Check "$runner has the identity preflight" ($text.Contains('Get-BuildReceiptStatus') -and $text.Contains('Get-SetConfigIdentity') -and $text.Contains('ABORT: identity refusal')) $runner
    }
    $mt5Run = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\mt5_run.ps1') -Raw
    Check 'mt5_run supports a caller-supplied exact build-receipt registry' `
        ($mt5Run.Contains('[string]$BuildReceiptRegistry') -and $mt5Run.Contains('-RegistryPath $receiptRegistry')) 'scripts\mt5_run.ps1'
    $baseline = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\generate_tpl_baseline.ps1') -Raw
    Check 'baseline generator stamps binaries and passes its temporary receipt registry to mt5_run' `
        ($baseline.Contains('New-BuildReceiptToken') -and $baseline.Contains('Write-BuildReceiptRecord') -and $baseline.Contains('BuildReceiptRegistry = $receiptRegistry')) 'scripts\generate_tpl_baseline.ps1'
}
finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "[build-identity] $pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }
exit 0
