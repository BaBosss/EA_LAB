<#
    run_skills_mirror_tests.ps1 -- focused skills-mirror metadata cage.

    This test drives the production walker against an isolated temporary fixture.
    It never refreshes D:\EA_LAB\docs\skills_mirror; the only -Update invocation
    writes a temporary mirror outside the repository. The final case runs the
    production canonical manifest check in read-only mode.
#>
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}

function Invoke-Sync {
    param(
        [string]$SyncScript,
        [string]$TargetRepo,
        [string]$TargetSkills,
        [switch]$Update
    )

    $ps = (Get-Command powershell.exe -ErrorAction Stop).Source
    $args = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $SyncScript,
        '-RepoRoot', $TargetRepo,
        '-SkillsRoot', $TargetSkills
    )
    if ($Update) { $args += '-Update' } else { $args += '-Check' }

    $output = @(& $ps @args 2>&1)
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = $output
    }
}

$syncScript = Join-Path $RepoRoot 'scripts\sync_skills_mirror.ps1'
if (-not (Test-Path -LiteralPath $syncScript -PathType Leaf)) {
    throw "FAIL: sync script not found: $syncScript"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ea_lab_skills_mirror_' + [guid]::NewGuid().ToString('N'))
$tempRepo = Join-Path $tempRoot 'repo'
$tempSkills = Join-Path $tempRoot 'skills'

try {
    New-Item -ItemType Directory -Force -Path $tempRepo, $tempSkills | Out-Null
    New-Item -ItemType Directory -Force -Path `
        (Join-Path $tempSkills 'keep'),
        (Join-Path $tempSkills 'keep\.git'),
        (Join-Path $tempSkills 'keep\node_modules'),
        (Join-Path $tempSkills 'keep\__pycache__') | Out-Null

    Set-Content -LiteralPath (Join-Path $tempSkills 'keep\SKILL.md') -Encoding UTF8 -Value '# durable skill content'
    Set-Content -LiteralPath (Join-Path $tempSkills 'keep\.skill_id') -Encoding ASCII -Value 'keep__imp_deadbeef'
    Set-Content -LiteralPath (Join-Path $tempSkills 'keep\foo.skill_id') -Encoding ASCII -Value 'ordinary sidecar-like filename'
    Set-Content -LiteralPath (Join-Path $tempSkills 'keep\.git\ignored.txt') -Encoding ASCII -Value 'ignored'
    Set-Content -LiteralPath (Join-Path $tempSkills 'keep\node_modules\ignored.js') -Encoding ASCII -Value 'ignored'
    Set-Content -LiteralPath (Join-Path $tempSkills 'keep\__pycache__\ignored.pyc') -Encoding ASCII -Value 'ignored'

    $updated = Invoke-Sync -SyncScript $syncScript -TargetRepo $tempRepo -TargetSkills $tempSkills -Update
    Assert-True ($updated.ExitCode -eq 0) 'isolated fixture update succeeds'

    $manifestPath = Join-Path $tempRepo 'docs\skills_mirror\MANIFEST.sha256'
    Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'isolated manifest exists'
    $manifestRows = @(Get-Content -LiteralPath $manifestPath -Encoding UTF8 | Where-Object { $_ -and -not $_.StartsWith('#') })
    $manifestPaths = @($manifestRows | ForEach-Object { ($_ -split '\s+', 3)[2] })

    Assert-True ($manifestPaths -contains 'keep/SKILL.md') 'SKILL.md is retained'
    Assert-True ($manifestPaths -contains 'keep/foo.skill_id') 'foo.skill_id is retained'
    Assert-True (-not ($manifestPaths -contains 'keep/.skill_id')) '.skill_id exact basename is excluded'
    Assert-True (-not ($manifestPaths -match '(^|/)\.git/')) '.git contents remain excluded'
    Assert-True (-not ($manifestPaths -match '(^|/)node_modules/')) 'node_modules contents remain excluded'
    Assert-True (-not ($manifestPaths -match '(^|/)__pycache__/')) '__pycache__ contents remain excluded'

    $skillHash = (Get-FileHash -LiteralPath (Join-Path $tempSkills 'keep\SKILL.md') -Algorithm SHA256).Hash.ToLowerInvariant()
    $skillRow = @($manifestRows | Where-Object { ($_ -split '\s+', 3)[2] -eq 'keep/SKILL.md' })
    Assert-True ($skillRow.Count -eq 1) 'SKILL.md has one manifest row'
    Assert-True ((($skillRow[0] -split '\s+', 3)[0]) -eq $skillHash) 'SKILL.md is hashed in the manifest'

    $checked = Invoke-Sync -SyncScript $syncScript -TargetRepo $tempRepo -TargetSkills $tempSkills
    Assert-True ($checked.ExitCode -eq 0) 'isolated fixture check reports no drift'

    $canonical = Invoke-Sync -SyncScript $syncScript -TargetRepo $RepoRoot -TargetSkills (Join-Path $env:USERPROFILE '.claude\skills')
    Assert-True ($canonical.ExitCode -eq 0) 'canonical manifest check reports 0 changed/0 added/0 removed'

    Write-Host 'FOCUSED_TESTS: PASS'
}
finally {
    $tempFull = [System.IO.Path]::GetFullPath($tempRoot).TrimEnd('\')
    $tempBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($tempFull.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $tempFull)) {
        Remove-Item -LiteralPath $tempFull -Recurse -Force -ErrorAction SilentlyContinue
    }
}
