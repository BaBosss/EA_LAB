<##
Production-path Runtime Identity acceptance tests. These fixtures exercise the PowerShell bridge,
the real collector, and the canonical Python validator without touching portfolio evidence.
##>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$PythonPath = ''
)
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
}
if ($PythonPath -eq '') { $PythonPath = Join-Path $RepoRoot 'tools\python312\python.exe' }
. (Join-Path $RepoRoot 'scripts\lib\runtime_identity.ps1')

$pass = 0
$fail = 0
function Check([string]$name, [bool]$condition, [string]$detail = '') {
    if ($condition) { $script:pass++; Write-Host "[PASS] $name" }
    else { $script:fail++; Write-Host "[FAIL] $name :: $detail" -ForegroundColor Red }
}
function Identity([string]$account, [string]$magic, [string]$receipt, [string]$epoch,
                  [string]$timestamp = '') {
    if ($timestamp -eq '') { $timestamp = (Get-Date).ToString('s') }
    return [ordered]@{
        schema = 'runtime_identity/1'; account_login = $account; magic = $magic
        ea_logical_identity = 'EA_X_TEST'; build_receipt = $receipt
        config_fingerprint = ('c' * 64); config_fingerprint_version = 'cfgfp-v1'
        symbol = 'EURUSDm'; timeframe = 'PERIOD_H1'; attach_epoch = $epoch
        first_trade_epoch = $null; evidence_timestamp = $timestamp
        evidence_source = 'EA_RUNTIME_COMMON_FILE'
    }
}
function AssertState($records, [string]$expectedPath, [string]$registryPath, [string]$state) {
    return Get-RuntimeIdentityValidation -RepoRoot $RepoRoot -Records @($records) `
        -ExpectedPath $expectedPath -RegistryPath $registryPath -PythonPath $PythonPath
}

$work = Join-Path ([IO.Path]::GetTempPath()) ('ri_prod_' + [guid]::NewGuid().ToString('N'))
$common = Join-Path $work 'common'
$dest = Join-Path $work 'dest'
New-Item -ItemType Directory -Path $common,$dest -Force | Out-Null
$expectedPath = Join-Path $work 'RUNTIME_IDENTITY_MAP.csv'
$registryPath = Join-Path $work 'build_receipts.jsonl'
$artifactPath = Join-Path $work 'EA_X_TEST.ex5'
try {
    [IO.File]::WriteAllText($artifactPath, 'artifact bytes', (New-Object Text.UTF8Encoding($false)))
    $artifactHash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLower()
    $receiptA = 'br-' + ('a' * 32)
    $receiptB = 'br-' + ('b' * 32)
    $sourceHash = 'd' * 64
    $csv = @"
account,magic,ea_logical_identity,build_receipt,config_fingerprint,config_fingerprint_version,symbol,timeframe,attach_epoch,source_sha256,artifact_sha256
100000001,900001,EA_X_TEST,$receiptA,$('c' * 64),cfgfp-v1,EURUSDm,PERIOD_H1,epoch-1,$sourceHash,$artifactHash
100000002,900002,EA_X_TEST,$receiptB,$('c' * 64),cfgfp-v1,EURUSDm,PERIOD_H1,epoch-1,$sourceHash,$artifactHash
"@
    [IO.File]::WriteAllText($expectedPath, $csv.TrimStart(), (New-Object Text.UTF8Encoding($false)))
    foreach ($receipt in @($receiptA,$receiptB)) {
        $record = [ordered]@{
            schema='build_receipt/1'; build_receipt=$receipt; ea_logical_identity='EA_X_TEST'
            artifact_path=$artifactPath; artifact_sha256=$artifactHash
            source_path=(Join-Path $work 'not-deployed-source.mq5'); source_sha256=$sourceHash
        }
        [IO.File]::AppendAllText($registryPath, (($record | ConvertTo-Json -Compress) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    }

    $a = Identity '100000001' '900001' $receiptA 'epoch-1'
    $b = Identity '100000002' '900002' $receiptB 'epoch-1'
    $full = AssertState @($a,$b) $expectedPath $registryPath 'PASS'
    Check 'L complete expected fleet -> PASS' ($full.state -eq 'PASS') ($full | ConvertTo-Json -Depth 8)

    $partial = AssertState @($a) $expectedPath $registryPath 'FAIL'
    Check 'A partial expected fleet -> NON-GREEN' ($partial.state -ne 'PASS') ($partial | ConvertTo-Json -Depth 8)

    $stale = Identity '100000001' '900001' $receiptA 'epoch-1' '2000-01-01T00:00:00Z'
    $staleResult = AssertState @($stale,$b) $expectedPath $registryPath 'FAIL'
    Check 'B stale syntactically valid timestamp -> NON-GREEN' ($staleResult.state -ne 'PASS' -and (@($staleResult.reasons.code) -contains 'EVIDENCE_TIMESTAMP_STALE')) ($staleResult | ConvertTo-Json -Depth 8)

    $wrongSource = (Get-Content -LiteralPath $registryPath -Raw) -replace $sourceHash, ('e' * 64)
    $wrongSourcePath = Join-Path $work 'wrong-source.jsonl'
    [IO.File]::WriteAllText($wrongSourcePath, $wrongSource, (New-Object Text.UTF8Encoding($false)))
    $sourceResult = AssertState @($a,$b) $expectedPath $wrongSourcePath 'FAIL'
    Check 'D wrong source SHA -> FAIL' ($sourceResult.state -ne 'PASS') ($sourceResult | ConvertTo-Json -Depth 8)

    $unboundPath = Join-Path $work 'unbound.csv'
    [IO.File]::WriteAllText($unboundPath, ($csv -replace $sourceHash, ''), (New-Object Text.UTF8Encoding($false)))
    $unbound = AssertState @($a,$b) $unboundPath $registryPath 'FAIL'
    Check 'E missing/unbound source lineage -> FAIL' ($unbound.state -ne 'PASS') ($unbound | ConvertTo-Json -Depth 8)

    $missingReceipt = AssertState @($a,$b) $expectedPath (Join-Path $work 'missing.jsonl') 'FAIL'
    Check 'F missing build receipt registry -> FAIL' ($missingReceipt.state -ne 'PASS') ($missingReceipt | ConvertTo-Json -Depth 8)

    $badArtifactPath = Join-Path $work 'bad-artifact.jsonl'
    $badArtifact = (Get-Content -LiteralPath $registryPath -Raw) -replace $artifactHash, ('f' * 64)
    [IO.File]::WriteAllText($badArtifactPath, $badArtifact, (New-Object Text.UTF8Encoding($false)))
    $artifactResult = AssertState @($a,$b) $expectedPath $badArtifactPath 'FAIL'
    Check 'G artifact SHA mismatch -> FAIL' ($artifactResult.state -ne 'PASS') ($artifactResult | ConvertTo-Json -Depth 8)

    $prior = Identity '100000001' '900001' $receiptA 'epoch-0'
    $priorResult = AssertState @($prior,$a,$b) $expectedPath $registryPath 'PASS'
    Check 'H sequential prior epoch is historical and current remains valid' ($priorResult.state -eq 'PASS' -and @($priorResult.historical).Count -eq 1) ($priorResult | ConvertTo-Json -Depth 8)

    $duplicate = AssertState @($a,$a,$b) $expectedPath $registryPath 'FAIL'
    Check 'I duplicate current evidence is ambiguous -> FAIL' ($duplicate.state -ne 'PASS') ($duplicate | ConvertTo-Json -Depth 8)

    $wrongFirst = Identity '100000001' '900001' $receiptA 'epoch-1'
    $wrongFirst.first_trade_epoch = 'epoch-2'
    $firstResult = AssertState @($wrongFirst,$b) $expectedPath $registryPath 'FAIL'
    Check 'K first trade epoch mismatch -> FAIL' ($firstResult.state -ne 'PASS') ($firstResult | ConvertTo-Json -Depth 8)

    $legacy = Get-RuntimeIdentityValidation -RepoRoot $RepoRoot -Records @() -ExpectedPath $expectedPath -RegistryPath $registryPath -PythonPath $PythonPath
    Check 'M missing identity remains LEGACY_UNVERIFIED' ($legacy.state -eq 'LEGACY_UNVERIFIED') ($legacy | ConvertTo-Json -Depth 8)

    $staleSidecar = Identity '100000001' '900001' $receiptA 'epoch-1' '2000-01-01T00:00:00'
    [IO.File]::WriteAllText((Join-Path $common 'EA_LAB_identity_100000001_900001.json'), ($staleSidecar | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $common 'EA_LAB_deals_100000001.csv'), "ticket,entry`n1,1`n", (New-Object Text.UTF8Encoding($false)))
    & powershell.exe -NoProfile -File (Join-Path $RepoRoot 'scripts\collect_live_deals.ps1') -CommonFiles $common -DestDir $dest | Out-Null
    $copied = @(Get-ChildItem -LiteralPath $dest -Filter 'EA_LAB_identity_*.json' -File -ErrorAction SilentlyContinue)
    Check 'C collector does not restamp stale producer evidence' ($copied.Count -eq 0) (($copied | Select-Object -ExpandProperty FullName) -join ',')
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
if ($fail -gt 0) { Write-Host "FAIL $fail/$($pass + $fail)"; exit 1 }
Write-Host "PASS $pass/$pass"
