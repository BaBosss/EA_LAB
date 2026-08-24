<#
    Deterministic regression for the DailyMonitor runtime-identity snapshot seam.

    This is intentionally narrower than the full DailyMonitor chain: it runs the real
    snapshot producer against the committed sensor files, writes only to a temporary
    output, and validates the transient builder contract directly.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
. (Join-Path $RepoRoot 'scripts\use_python.ps1')

$script:pass = 0
$script:fail = 0

function Assert-True([string]$What, $Condition) {
    if ([bool]$Condition) {
        $script:pass++
        Write-Host "   [PASS] $What" -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host "   [FAIL] $What" -ForegroundColor Red
    }
}

function Assert-Equal([string]$What, $Expected, $Actual) {
    Assert-True "$What (expected '$Expected', actual '$Actual')" ("$Expected" -eq "$Actual")
}

Write-Host ''
Write-Host '=== Monitoring snapshot schema repair ==='

$deals = Join-Path $RepoRoot 'portfolio\live_deals'
$identityLib = Join-Path $RepoRoot 'scripts\lib\runtime_identity.ps1'
$schemaPath = Join-Path $RepoRoot '_triage\factory_os\schemas.json'
$snapshotScript = Join-Path $RepoRoot 'scripts\control_room_snapshot.ps1'
$py = Join-Path $RepoRoot 'tools\python312\python.exe'

# The empty sidecar store is a supported legacy-unverified state, not a PowerShell binder error.
. $identityLib
$emptyDeals = Join-Path ([IO.Path]::GetTempPath()) ('empty_identity_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $emptyDeals -Force | Out-Null
try {
    $emptyRecords = @(Get-RuntimeIdentityRecords -DealsRoot $emptyDeals)
    $emptyForward = Get-RuntimeIdentityForwardStates -RepoRoot $RepoRoot -DealsRoot $emptyDeals -RuntimeRecords @()
    Assert-Equal 'empty runtime-identity list is accepted' 0 $emptyRecords.Count
    Assert-Equal 'empty runtime-identity list remains explicitly untrusted' 'NO_VALID_RUNTIME_IDENTITY' $emptyForward.state
} finally {
    Remove-Item -LiteralPath $emptyDeals -Recurse -Force -ErrorAction SilentlyContinue
}

# A singleton runtime-identity batch must cross the PowerShell -> Python bridge as a JSON ARRAY.
# PowerShell pipeline serialization unwraps one-element arrays, which made the validator iterate
# the record's field names instead of validating one record when the first real sidecar arrived.
$fakePy = Join-Path ([IO.Path]::GetTempPath()) ('runtime_identity_array_probe_' + [guid]::NewGuid().ToString('N') + '.ps1')
$fakePyBody = @(
    'param([string]$Validator,[string]$Mode,[string]$RecordsPath,[string]$ExpectedPath,[string]$RegistryPath)',
    '$raw = [IO.File]::ReadAllText($RecordsPath)',
    'if ($raw.TrimStart().StartsWith(''['')) {',
    '    Write-Output ''{"state":"PASS","identity":[],"reasons":[]}'' ',
    '} else {',
    '    Write-Output ''{"state":"FAIL","identity":[],"reasons":[{"code":"SINGLETON_NOT_ARRAY","detail":"records.json root is not an array"}]}'' ',
    '}'
) -join "`n"
[IO.File]::WriteAllText($fakePy, $fakePyBody, (New-Object Text.UTF8Encoding($false)))
try {
    $single = [pscustomobject]@{ account_login='463666728'; magic='990026' }
    $singleValidation = Get-RuntimeIdentityValidation -RepoRoot $RepoRoot -Records @($single) -PythonPath $fakePy
    Assert-Equal 'singleton runtime identity crosses validation bridge as JSON array' 'PASS' $singleValidation.state
} finally {
    Remove-Item -LiteralPath $fakePy -Force -ErrorAction SilentlyContinue
}

# The snapshot builder must preserve the validator's one-element identity array before counting it.
# Execute the exact assignment block from the production script so this regression cannot pass if
# the producer drifts back to the conditional-expression form that PowerShell unwraps.
$snapshotSource = [IO.File]::ReadAllText($snapshotScript)
$identityAssign = [regex]::Match($snapshotSource, '(?ms)^\$runtimeIdentity = @\(\)\r?\nif \(\$null -ne \$runtimeValidation\.identity\) \{\r?\n  \$runtimeIdentity = @\(\$runtimeValidation\.identity\)\r?\n\}')
Assert-True 'snapshot producer preserves singleton runtime identity as an array before counting' $identityAssign.Success
Assert-True 'snapshot producer emits runtime identity record count as an explicit integer' ($snapshotSource -match '(?m)^  records = \[int\]\$runtimeIdentity\.Count\r?$')
if ($identityAssign.Success) {
    $runtimeValidation = '{"state":"PASS","identity":[{"account_login":"463666728","magic":"990026"}],"reasons":[]}' | ConvertFrom-Json
    Invoke-Expression $identityAssign.Value
    Assert-Equal 'singleton snapshot runtime identity collection remains Object[]' 'System.Object[]' $runtimeIdentity.GetType().FullName
    $probeSummary = [ordered]@{ records = [int]$runtimeIdentity.Count }
    $probeRoundTrip = (($probeSummary | ConvertTo-Json -Compress) | ConvertFrom-Json)
    Assert-Equal 'singleton snapshot runtime identity record count round-trips as integer one' 1 $probeRoundTrip.records
    Remove-Variable runtimeValidation,runtimeIdentity -ErrorAction SilentlyContinue
}

# The producer and schema must agree on the policy flag and on the closed summary shape.
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
$meta = $schema.'$defs'.SnapshotMeta
$builder = $schema.'$defs'.SnapshotBuilderInput
Assert-Equal 'SnapshotBuilderInput accepts annotated RuntimeIdentityRecord from validation bridge' '#/$defs/RuntimeIdentityRecord' $builder.properties.runtime_identity.items.'$ref'
$builderSummary = $builder.properties.runtime_identity_summary
Assert-Equal 'runtime_identity_required is boolean snapshot metadata' 'boolean' $meta.properties.runtime_identity_required.type
Assert-True 'SnapshotBuilderInput accepts the runtime identity forward-test state' ($null -ne $builderSummary.properties.forward_test_state)
Assert-True 'SnapshotBuilderInput accepts first-trade findings' ($null -ne $builderSummary.properties.first_trade_findings)
$builderFinding = $builderSummary.properties.first_trade_findings.items
Assert-True 'builder first-trade finding uses transient identity_findings' ($null -ne $builderFinding.properties.identity_findings)
Assert-True 'builder first-trade finding cannot carry validator-owned reasons' ($null -eq $builderFinding.properties.reasons)
Assert-Equal 'runtime identity builder summary stays closed' $false $builderSummary.unevaluatedProperties
Assert-Equal 'snapshot metadata stays closed against unknown fields' $false $meta.unevaluatedProperties
Assert-True 'an unexpected field is not part of the accepted schema' ($null -eq $meta.properties.unexpected_field)

# Run the real producer/builder path. The output is temporary; the canonical snapshot is untouched.
$output = Join-Path ([IO.Path]::GetTempPath()) ('control_room_snapshot_repair_' + [guid]::NewGuid().ToString('N') + '.json')
$sensorFiles = @(Get-ChildItem -LiteralPath $deals -Filter '*.csv' -File)
$sensorTimes = @{}
foreach ($sensorFile in $sensorFiles) {
    $sensorTimes[$sensorFile.FullName] = $sensorFile.LastWriteTime
    $sensorFile.LastWriteTime = (Get-Date).AddMinutes(-1)
}
try {
    $expectedRuntimeRecords = @(Get-RuntimeIdentityRecords -DealsRoot $deals)
    $expectedRuntimeValidation = Get-RuntimeIdentityValidation -RepoRoot $RepoRoot -Records $expectedRuntimeRecords
    $expectedRuntimeIdentity = @()
    if ($null -ne $expectedRuntimeValidation.identity) { $expectedRuntimeIdentity = @($expectedRuntimeValidation.identity) }
    $expectedRuntimeForward = Get-RuntimeIdentityForwardStates -RepoRoot $RepoRoot -DealsRoot $deals -RuntimeRecords $expectedRuntimeIdentity
    & powershell -NoProfile -File $snapshotScript -Root $RepoRoot -OutFile $output 2>&1 | Out-Host
    $rc = $LASTEXITCODE
    Assert-Equal 'normal snapshot construction succeeds' 0 $rc
    if ($rc -eq 0 -and (Test-Path -LiteralPath $output)) {
        $doc = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json
        Assert-Equal 'constructed document is the persisted snapshot entity' 'ControlRoomSnapshotV5' $doc.entity
        Assert-Equal 'runtime identity policy flag is preserved' $true $doc.meta.runtime_identity_required
        Assert-Equal 'producer runtime identity state matches current sidecar store' "$($expectedRuntimeValidation.state)" "$($doc.runtime_identity_summary.state)"
        Assert-Equal 'producer runtime identity record count matches validated store' $expectedRuntimeIdentity.Count ([int]$doc.runtime_identity_summary.records)
        Assert-Equal 'producer forward-test state matches current sidecar/deal store' "$($expectedRuntimeForward.state)" "$($doc.runtime_identity_summary.forward_test_state)"

        $health141 = @($doc.system_health | Where-Object { "$($_.account)" -eq '141049900' })
        $health694 = @($doc.system_health | Where-Object { "$($_.account)" -eq '69424711' })
        Assert-Equal '141049900 fresh sensor reaches snapshot path' 'FRESH' $health141[0].state
        Assert-Equal '69424711 fresh sensor reaches snapshot path' 'FRESH' $health694[0].state

        $clevr = @($doc.deployments.rows | Where-Object {
            "$($_.account)" -eq '69424711' -and "$($_.ea_name)" -eq 'ClevrFX_EA'
        })
        Assert-Equal '69424711 incomplete authority remains UNVERIFIED' 'UNVERIFIED' $clevr[0].verification_state
        Assert-True '69424711 missing magic remains missing' ([string]::IsNullOrWhiteSpace("$($clevr[0].magic)"))
        Assert-Equal '69424711 incomplete authority remains blocked' 'BLOCKED' $clevr[0].attention
    }

    # Validate the same built document as builder input, then prove an unknown metadata key is refused.
    if (Test-Path -LiteralPath $output) {
        $pyCode = @'
import json
import sys
sys.path.insert(0, sys.argv[2])
from _triage.factory_os import snapshot_validator as sv

doc = json.load(open(sys.argv[1], encoding='utf-8'))
doc['entity'] = 'SnapshotBuilderInput'
doc.pop('verdict', None)
summary = doc['runtime_identity_summary']
summary['identity_findings'] = summary.pop('reasons')
summary['first_trade_findings'] = [{
    'account_login': '463666728',
    'magic': '990026',
    'state': 'AWAITING_FIRST_TRADE',
    'first_trade_epoch': None,
    'qualifying_deal': None,
    'identity_findings': [{'code': 'NO_FIRST_TRADE', 'detail': 'fixture'}],
}]
sv.ajv_schema_validator(doc, 'SnapshotBuilderInput')
built = sv.build_snapshot(json.loads(json.dumps(doc)), sv.ajv_schema_validator)
finding = built['runtime_identity_summary']['first_trade_findings'][0]
assert 'identity_findings' not in finding
assert finding['reasons'][0]['code'] == 'NO_FIRST_TRADE'
print('NESTED_FINDINGS_PUBLISHED')
doc['meta']['unexpected_field'] = True
try:
    sv.ajv_schema_validator(doc, 'SnapshotBuilderInput')
except Exception:
    print('UNKNOWN_REJECTED')
    raise SystemExit(0)
raise SystemExit('unknown schema field was accepted')
'@
        $schemaResult = & $py -c $pyCode $output $RepoRoot 2>&1
        Assert-Equal 'runtime identity builder input validates at the real schema gate' 0 $LASTEXITCODE
        Assert-True 'nested first-trade findings publish only after supplied-answer scan' (@($schemaResult) -match 'NESTED_FINDINGS_PUBLISHED')
        Assert-True 'unknown unexpected schema field is rejected' (@($schemaResult) -match 'UNKNOWN_REJECTED')
    }
} finally {
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue }
    foreach ($sensorFile in $sensorFiles) {
        if ($sensorTimes.ContainsKey($sensorFile.FullName) -and (Test-Path -LiteralPath $sensorFile.FullName)) {
            (Get-Item -LiteralPath $sensorFile.FullName).LastWriteTime = $sensorTimes[$sensorFile.FullName]
        }
    }
}

Write-Host ''
Write-Host ("PASS  {0}/{1}" -f $script:pass, ($script:pass + $script:fail))
if ($script:fail -gt 0) { exit 1 }
