Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Invoke-LnwjudGit {
    param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string[]]$GitArgs)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & git -C $Root @GitArgs 2>&1; $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) {
        throw "git failed in '$Root': git $($GitArgs -join ' ') :: $(@($output) -join ' ')"
    }
    return ((@($output) -join "`n").Trim())
}

function Get-LnwjudFullPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    return [IO.Path]::GetFullPath($Path).TrimEnd([char[]]'\/')
}

function Test-LnwjudPathWithin {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Root)
    $p = Get-LnwjudFullPath $Path
    $r = Get-LnwjudFullPath $Root
    if ($p.Equals($r,[StringComparison]::OrdinalIgnoreCase)) { return $true }
    $prefix = $r + [IO.Path]::DirectorySeparatorChar
    return $p.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)
}

function Get-LnwjudStatusContract {
    param([Parameter(Mandatory=$true)][string]$RepoRoot)
    $path = Join-Path (Get-LnwjudFullPath $RepoRoot) 'tools\lnwjud\status-contract.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "status contract not found: $path" }
    $value = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $value.lnwjud -or [string]::IsNullOrWhiteSpace([string]$value.lnwjud.expected_sha)) {
        throw 'status contract does not contain lnwjud.expected_sha'
    }
    return $value
}
function Get-LnwjudTrustedSourceState {
    param([Parameter(Mandatory=$true)][string]$RepoRoot,[Parameter(Mandatory=$true)][string]$SourceRoot)
    $source = Get-LnwjudFullPath $SourceRoot
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "trusted source not found: $source" }
    $contract = Get-LnwjudStatusContract $RepoRoot
    $head = Invoke-LnwjudGit -Root $source -GitArgs @('rev-parse','HEAD')
    $expected = ([string]$contract.lnwjud.expected_sha).Trim().ToLowerInvariant()
    if ($head.ToLowerInvariant() -ne $expected) { throw "trusted source HEAD $head does not match expected SHA $expected" }
    $dirty = Invoke-LnwjudGit -Root $source -GitArgs @('status','--porcelain=v1','--untracked-files=no')
    if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw 'trusted source has tracked changes; refuse upgrade staging' }
    return [pscustomobject]@{ source_root=$source; current_sha=$head; expected_version=[string]$contract.lnwjud.expected_version; expected_sha=$expected }
}

function Assert-LnwjudCandidatePath {
    param([string]$SourceRoot,[string]$CandidateRoot,[string]$StagingRoot)
    $source = Get-LnwjudFullPath $SourceRoot
    $candidate = Get-LnwjudFullPath $CandidateRoot
    $staging = Get-LnwjudFullPath $StagingRoot
    if ($candidate.Equals($source,[StringComparison]::OrdinalIgnoreCase)) { throw 'candidate must be side-by-side; trusted source path cannot be reused' }
    if (-not (Test-LnwjudPathWithin -Path $candidate -Root $staging)) { throw "candidate path must stay under staging root '$staging'" }
}
function Get-LnwjudUpgradePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$SourceRoot,
        [Parameter(Mandatory=$true)][ValidatePattern('^v\d+\.\d+\.\d+$')][string]$TargetRef,
        [Parameter(Mandatory=$true)][string]$CandidateRoot,
        [Parameter(Mandatory=$true)][string]$StagingRoot
    )
    $state = Get-LnwjudTrustedSourceState -RepoRoot $RepoRoot -SourceRoot $SourceRoot
    Assert-LnwjudCandidatePath -SourceRoot $state.source_root -CandidateRoot $CandidateRoot -StagingRoot $StagingRoot
    $targetSha = Invoke-LnwjudGit -Root $state.source_root -GitArgs @('rev-parse',"$TargetRef`^{commit}")
    return [pscustomobject][ordered]@{
        source_root=$state.source_root; current_version=$state.expected_version; current_sha=$state.current_sha
        target_ref=$TargetRef; target_sha=$targetSha; candidate_root=(Get-LnwjudFullPath $CandidateRoot)
        staging_root=(Get-LnwjudFullPath $StagingRoot); cutover='NOT_PERFORMED'
    }
}

function New-LnwjudUpgradeCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,[Parameter(Mandatory=$true)][string]$SourceRoot,
        [Parameter(Mandatory=$true)][ValidatePattern('^v\d+\.\d+\.\d+$')][string]$TargetRef,
        [Parameter(Mandatory=$true)][string]$CandidateRoot,[Parameter(Mandatory=$true)][string]$StagingRoot,[switch]$Fetch
    )
    $state = Get-LnwjudTrustedSourceState -RepoRoot $RepoRoot -SourceRoot $SourceRoot
    Assert-LnwjudCandidatePath -SourceRoot $state.source_root -CandidateRoot $CandidateRoot -StagingRoot $StagingRoot
    if ($Fetch) {
        [void](Invoke-LnwjudGit -Root $state.source_root -GitArgs @('fetch','origin',"refs/tags/$TargetRef`:refs/tags/$TargetRef"))
    }
    $plan = Get-LnwjudUpgradePlan -RepoRoot $RepoRoot -SourceRoot $state.source_root -TargetRef $TargetRef -CandidateRoot $CandidateRoot -StagingRoot $StagingRoot
    $candidate = $plan.candidate_root
    if (Test-Path -LiteralPath $candidate) {
        $head = Invoke-LnwjudGit -Root $candidate -GitArgs @('rev-parse','HEAD')
        if ($head -ne $plan.target_sha) { throw "existing candidate HEAD $head does not match target SHA $($plan.target_sha)" }
        $dirty = Invoke-LnwjudGit -Root $candidate -GitArgs @('status','--porcelain=v1','--untracked-files=no')
        if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw 'existing candidate has tracked changes' }
        return [pscustomobject]@{ status='EXISTING_EXACT'; candidate_root=$candidate; target_sha=$head }
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $candidate -Parent) | Out-Null
    [void](Invoke-LnwjudGit -Root $state.source_root -GitArgs @('worktree','add','--detach',$candidate,$plan.target_sha))
    $actual = Invoke-LnwjudGit -Root $candidate -GitArgs @('rev-parse','HEAD')
    if ($actual -ne $plan.target_sha) { throw "candidate staging verification failed: $actual" }
    return [pscustomobject]@{ status='STAGED'; candidate_root=$candidate; target_sha=$actual }
}

function Invoke-LnwjudCheckedProcess {
    param([string]$WorkingDirectory,[string]$Executable,[string[]]$Arguments)
    Push-Location $WorkingDirectory
    try {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try { $output = & $Executable @Arguments 2>&1; $code = $LASTEXITCODE }
        finally { $ErrorActionPreference = $previous }
        if ($code -ne 0) { throw "$Executable $($Arguments -join ' ') failed :: $(@($output) -join ' ')" }
        return @($output)
    } finally { Pop-Location }
}
function ConvertFrom-LnwjudPorcelainPaths {
    param([Parameter(Mandatory=$true)][string[]]$StatusLines)
    $paths = New-Object Collections.Generic.List[string]
    foreach ($line in $StatusLines) {
        if ([string]::IsNullOrWhiteSpace([string]$line)) { continue }
        if ($line.Length -lt 4) { throw "unexpected candidate status entry after build: $line" }
        $rel = $line.Substring(3).Trim()
        if ([string]::IsNullOrWhiteSpace($rel)) { throw "empty candidate status path after build: $line" }
        $paths.Add($rel)
    }
    return $paths.ToArray()
}

function Repair-LnwjudStatOnlyBuildChanges {
    param([Parameter(Mandatory=$true)][string]$CandidateRoot)
    $candidate = Get-LnwjudFullPath $CandidateRoot
    $allowed = @('apps/desktop/build/windows-capability-bridge.sha256','packages/capabilities/src/windows-capability-integrity.generated.ts')
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $status = @(& git -C $candidate status --porcelain=v1 --untracked-files=no 2>&1); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { throw "git status failed in candidate: $(@($status) -join ' ')" }
    if ($status.Count -eq 0) { return @() }
    $parsedPaths = @(ConvertFrom-LnwjudPorcelainPaths -StatusLines $status)
    $paths = New-Object Collections.Generic.List[string]
    foreach ($rel in $parsedPaths) {
        if ($allowed -notcontains $rel) { throw "build changed unexpected tracked source: $rel" }
        $indexHash = Invoke-LnwjudGit -Root $candidate -GitArgs @('rev-parse',":$rel")
        $worktreeHash = Invoke-LnwjudCheckedProcess -WorkingDirectory $candidate -Executable 'git' -Arguments @('hash-object',"--path=$rel",(Join-Path $candidate $rel))
        if ((@($worktreeHash) -join "`n").Trim() -ne $indexHash) { throw "build changed tracked source content: $rel" }
        $paths.Add($rel)
    }
    if ($paths.Count -gt 0) {
        [void](Invoke-LnwjudGit -Root $candidate -GitArgs (@('checkout-index','-f','--') + $paths.ToArray()))
    }
    $remaining = Invoke-LnwjudGit -Root $candidate -GitArgs @('status','--porcelain=v1','--untracked-files=no')
    if (-not [string]::IsNullOrWhiteSpace($remaining)) { throw 'candidate remains tracked-dirty after normalization-only repair' }
    return $paths.ToArray()
}
function Invoke-LnwjudCandidateBuild {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$CandidateRoot,[switch]$SkipInstall)
    $candidate = Get-LnwjudFullPath $CandidateRoot
    if (-not (Test-Path -LiteralPath (Join-Path $candidate 'package.json') -PathType Leaf)) { throw 'candidate package.json not found' }
    $dirty = Invoke-LnwjudGit -Root $candidate -GitArgs @('status','--porcelain=v1','--untracked-files=no')
    if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw 'candidate has tracked changes before build' }
    $started = Get-Date
    if (-not $SkipInstall) { [void](Invoke-LnwjudCheckedProcess -WorkingDirectory $candidate -Executable 'corepack' -Arguments @('pnpm','install','--frozen-lockfile')) }
    [void](Invoke-LnwjudCheckedProcess -WorkingDirectory $candidate -Executable 'corepack' -Arguments @('pnpm','build'))
    $normalized = @(Repair-LnwjudStatOnlyBuildChanges -CandidateRoot $candidate)
    $elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds,3)
    return [pscustomobject]@{ status='BUILT'; candidate_root=$candidate; elapsed_seconds=$elapsed; install_skipped=[bool]$SkipInstall; normalization_only_restored=@($normalized) }
}

function Test-LnwjudCandidateCompatibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CandidateRoot,
        [Parameter(Mandatory=$true)][string]$ExpectedVersion,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{40}$')][string]$ExpectedSha,
        [Parameter(Mandatory=$true)][string]$ProbePath
    )
    $candidate = Get-LnwjudFullPath $CandidateRoot
    $packagePath = Join-Path $candidate 'package.json'
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { throw 'candidate package.json not found' }
    $pkg = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$pkg.version -ne $ExpectedVersion) { throw "candidate version '$($pkg.version)' does not match expected version '$ExpectedVersion'" }
    $head = Invoke-LnwjudGit -Root $candidate -GitArgs @('rev-parse','HEAD')
    if ($head -ne $ExpectedSha) { throw "candidate SHA $head does not match expected SHA $ExpectedSha" }
    $dirty = Invoke-LnwjudGit -Root $candidate -GitArgs @('status','--porcelain=v1','--untracked-files=no')
    if (-not [string]::IsNullOrWhiteSpace($dirty)) { throw 'candidate has tracked changes; compatibility evidence would not bind exact source' }
    if (-not (Test-Path -LiteralPath $ProbePath -PathType Leaf)) { throw "node probe not found: $ProbePath" }
    $raw = Invoke-LnwjudCheckedProcess -WorkingDirectory $candidate -Executable 'node' -Arguments @($ProbePath,$candidate)
    $text = (@($raw) -join "`n").Trim()
    $probe = $text | ConvertFrom-Json
    if ($probe.ok -ne $true) { throw "candidate compatibility probe failed: $text" }
    return [pscustomobject][ordered]@{ ok=$true; candidate_root=$candidate; version=[string]$pkg.version; sha=$head; required_modules=[int]$probe.required_modules; probe=$probe }
}
function Write-LnwjudUpgradeManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Plan,
        [Parameter(Mandatory=$true)]$Compatibility,
        [Parameter(Mandatory=$true)][string]$OutputPath
    )
    $target = Get-LnwjudFullPath $OutputPath
    $parent = Split-Path $target -Parent
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $manifest = [ordered]@{
        schema_version = 1
        generated_at = [DateTimeOffset]::UtcNow.ToString('o')
        plan = $Plan
        compatibility = $Compatibility
        authority = [ordered]@{
            cutover_performed = $false
            merge_performed = $false
            push_performed = $false
            runtime_attachment_changed = $false
            deployment_authority_granted = $false
        }
    }
    $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $target -Encoding UTF8
    return $target
}

Export-ModuleMember -Function @(
    'Get-LnwjudUpgradePlan',
    'New-LnwjudUpgradeCandidate',
    'Invoke-LnwjudCandidateBuild',
    'Test-LnwjudCandidateCompatibility',
    'Write-LnwjudUpgradeManifest'
)
