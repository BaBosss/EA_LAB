$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$modulePath = Join-Path $repoRoot 'tools\lnwjud_upgrade\LnwjudUpgrade.psm1'
Import-Module $modulePath -Force

$script:passed = 0
$script:failed = 0
function Pass([string]$Name) { $script:passed++; Write-Host "PASS $Name" }
function Fail([string]$Name, [string]$Message) { $script:failed++; Write-Host "FAIL $Name :: $Message" }
function Assert-True([string]$Name, [bool]$Value) { if ($Value) { Pass $Name } else { Fail $Name 'expected true' } }
function Assert-Throws([string]$Name, [scriptblock]$Body, [string]$Pattern) {
    try { & $Body; Fail $Name 'expected exception' }
    catch { if ($_.Exception.Message -match $Pattern) { Pass $Name } else { Fail $Name $_.Exception.Message } }
}

$upgradeModule = Get-Module | Where-Object { $_.Path -eq $modulePath } | Select-Object -First 1
Assert-True 'module imported for private parser regression' ($null -ne $upgradeModule)
$parsedStatus = & $upgradeModule { ConvertFrom-LnwjudPorcelainPaths -StatusLines @(' M apps/desktop/build/windows-capability-bridge.sha256',' M packages/capabilities/src/windows-capability-integrity.generated.ts') }
Assert-True 'porcelain parser preserves first leading-space path' ($parsedStatus[0] -eq 'apps/desktop/build/windows-capability-bridge.sha256')
Assert-True 'porcelain parser preserves multiline status' ($parsedStatus.Count -eq 2)

$testRoot = Join-Path $env:TEMP ("ea_lab_lnwjud_upgrade_tests_{0}" -f $PID)
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
function New-FakeSourceRepo([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    git -C $Path init -q
    git -C $Path config user.email 'test@example.invalid'
    git -C $Path config user.name 'EA_LAB test'
    '{"name":"lnwjud-fixture","version":"4.0.0","type":"module","scripts":{"build":"node -e \"process.exit(0)\""}}' | Set-Content -LiteralPath (Join-Path $Path 'package.json') -Encoding UTF8
    git -C $Path add package.json
    git -C $Path commit -q -m 'v4 fixture'
    $currentSha = (git -C $Path rev-parse HEAD).Trim()

    Set-Content -LiteralPath (Join-Path $Path 'package.json') -Encoding UTF8 -Value '{"name":"lnwjud-fixture","version":"4.10.0","type":"module","scripts":{"build":"node -e \"process.exit(0)\""}}'
    $files = @{
        'packages/mcp-server/dist/tool-registry.js' = 'export class ToolRegistry {}'
        'apps/cli/dist/runtime/stdio-mcp-runtime.js' = 'export function createStdioMcpRuntime() {}'
        'packages/storage/dist/index.js' = 'export class SqliteDatabase {}; export class SqliteWorkspaceRepository {}'
        'packages/workspace/dist/index.js' = 'export class WorkspaceService {}'
        'packages/permissions/dist/index.js' = 'export const permissionProfiles = { full: { name: "full" } }'
    }
    foreach ($rel in $files.Keys) {
        $full = Join-Path $Path $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $full -Parent) | Out-Null
        Set-Content -LiteralPath $full -Value $files[$rel] -Encoding UTF8
    }
    git -C $Path add .
    git -C $Path commit -q -m 'v4.10 fixture'
    git -C $Path tag v4.10.0
    $targetSha = (git -C $Path rev-parse HEAD).Trim()
    git -C $Path checkout -q --detach $currentSha
    return [pscustomobject]@{ CurrentSha = $currentSha; TargetSha = $targetSha }
}

function New-FakeEaRepo([string]$Path, [string]$ExpectedSha) {
    $dir = Join-Path $Path 'tools\lnwjud'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $json = [ordered]@{
        schema_version = 1
        lnwjud = [ordered]@{ expected_version = 'v4.0.0'; expected_sha = $ExpectedSha; source_path = 'fixture' }
    } | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath (Join-Path $dir 'status-contract.json') -Value $json -Encoding UTF8
}

try {
    $source = Join-Path $testRoot 'source'
    $fixture = New-FakeSourceRepo $source
    $ea = Join-Path $testRoot 'ea'
    New-FakeEaRepo $ea $fixture.CurrentSha
    $staging = Join-Path $testRoot 'staging'
    $candidate = Join-Path $staging 'v4.10.0\source'

    $plan = Get-LnwjudUpgradePlan -RepoRoot $ea -SourceRoot $source -TargetRef 'v4.10.0' -CandidateRoot $candidate -StagingRoot $staging
    Assert-True 'plan binds current source SHA' ($plan.current_sha -eq $fixture.CurrentSha)
    Assert-True 'plan resolves exact target SHA' ($plan.target_sha -eq $fixture.TargetSha)
    Assert-True 'plan remains side-by-side' ($plan.candidate_root -ne $plan.source_root)
    $wrapper = Join-Path $repoRoot 'tools\lnwjud_upgrade\Invoke-LnwjudUpgrade.ps1'
    $wrapperJson = & $wrapper -Command Plan -RepoRoot $ea -SourceRoot $source -TargetRef 'v4.10.0' -CandidateRoot $candidate -StagingRoot $staging
    $wrapperPlan = (@($wrapperJson) -join "`n") | ConvertFrom-Json
    Assert-True 'wrapper resolves its module path during direct invocation' ($wrapperPlan.target_sha -eq $fixture.TargetSha)
    Assert-Throws 'reject candidate at trusted source path' {
        Get-LnwjudUpgradePlan -RepoRoot $ea -SourceRoot $source -TargetRef 'v4.10.0' -CandidateRoot $source -StagingRoot $staging | Out-Null
    } 'side-by-side'
    Assert-Throws 'reject candidate outside staging root' {
        Get-LnwjudUpgradePlan -RepoRoot $ea -SourceRoot $source -TargetRef 'v4.10.0' -CandidateRoot (Join-Path $testRoot 'escape') -StagingRoot $staging | Out-Null
    } 'staging root'

    $badEa = Join-Path $testRoot 'ea-bad-pin'
    New-FakeEaRepo $badEa ('0' * 40)
    Assert-Throws 'reject current pin drift' {
        Get-LnwjudUpgradePlan -RepoRoot $badEa -SourceRoot $source -TargetRef 'v4.10.0' -CandidateRoot $candidate -StagingRoot $staging | Out-Null
    } 'expected SHA'

    Set-Content -LiteralPath (Join-Path $source 'package.json') -Value '{"dirty":true}' -Encoding UTF8
    Assert-Throws 'reject tracked dirty trusted source' {
        Get-LnwjudUpgradePlan -RepoRoot $ea -SourceRoot $source -TargetRef 'v4.10.0' -CandidateRoot $candidate -StagingRoot $staging | Out-Null
    } 'tracked changes'
    git -C $source checkout -q -- package.json

    $stageResult = New-LnwjudUpgradeCandidate -RepoRoot $ea -SourceRoot $source -TargetRef 'v4.10.0' -CandidateRoot $candidate -StagingRoot $staging
    Assert-True 'stage creates candidate' (Test-Path $candidate)
    Assert-True 'stage pins candidate HEAD' (((git -C $candidate rev-parse HEAD).Trim()) -eq $fixture.TargetSha)
    $stageAgain = New-LnwjudUpgradeCandidate -RepoRoot $ea -SourceRoot $source -TargetRef 'v4.10.0' -CandidateRoot $candidate -StagingRoot $staging
    Assert-True 'stage is idempotent for exact clean candidate' ($stageAgain.status -eq 'EXISTING_EXACT')
    $compat = Test-LnwjudCandidateCompatibility -CandidateRoot $candidate -ExpectedVersion '4.10.0' -ExpectedSha $fixture.TargetSha -ProbePath (Join-Path $repoRoot 'tools\lnwjud_upgrade\node_probe.mjs')
    Assert-True 'compatibility probe passes required exports' ($compat.ok -eq $true)
    Assert-True 'compatibility probe checks five seams' ($compat.required_modules -eq 5)

    $wrong = Join-Path $staging 'wrong\source'
    git -C $source worktree add -q --detach $wrong $fixture.TargetSha
    Set-Content -LiteralPath (Join-Path $wrong 'package.json') -Value '{"name":"fixture","version":"9.9.9","type":"module"}' -Encoding UTF8
    Assert-Throws 'reject wrong candidate version' {
        Test-LnwjudCandidateCompatibility -CandidateRoot $wrong -ExpectedVersion '4.10.0' -ExpectedSha $fixture.TargetSha -ProbePath (Join-Path $repoRoot 'tools\lnwjud_upgrade\node_probe.mjs') | Out-Null
    } 'version'

    $manifest = Write-LnwjudUpgradeManifest -Plan $plan -Compatibility $compat -OutputPath (Join-Path $staging 'upgrade-manifest.json')
    Assert-True 'manifest written' (Test-Path $manifest)
    $manifestObj = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
    Assert-True 'manifest forbids cutover' ($manifestObj.authority.cutover_performed -eq $false)
    Assert-True 'manifest forbids merge' ($manifestObj.authority.merge_performed -eq $false)
}
finally {
    if (Test-Path $testRoot) {
        Get-ChildItem -LiteralPath $testRoot -Directory -Recurse -Filter '.git' -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "RESULT passed=$script:passed failed=$script:failed"
if ($script:failed -ne 0) { exit 1 }
