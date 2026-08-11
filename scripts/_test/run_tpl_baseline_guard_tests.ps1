<# Commit-message guard tests for the versioned baseline re-pin policy. #>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Continue'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('tpl_guard_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force (Join-Path $fixture '.githooks') | Out-Null
try {
    New-Item -ItemType Directory -Force (Join-Path $fixture 'ea_template') | Out-Null
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\regression_baseline*.json'), (Join-Path $RepoRoot 'ea_template\regression_baseline_build6090.csv') | Copy-Item -Destination (Join-Path $fixture 'ea_template') -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $RepoRoot 'ea_template\regression_baseline.csv') (Join-Path $fixture 'ea_template\regression_baseline.csv')
    Copy-Item (Join-Path $RepoRoot '.githooks\commit-msg') (Join-Path $fixture '.githooks\commit-msg')
    git -C $fixture init -q
    git -C $fixture config user.email test@example.invalid
    git -C $fixture config user.name TPLGuard
    git -C $fixture config core.hooksPath .githooks
    git -C $fixture add .
    git -C $fixture commit -q --no-verify -m 'fixture baseline'
    if ($LASTEXITCODE -ne 0) { throw 'fixture initial commit failed' }

    function New-Commit([string]$Message, [scriptblock]$Mutate, [int]$Expected) {
        & $Mutate
        git -C $fixture add .
        & git -C $fixture commit -q -m $Message 2>&1 | Out-Null
        $actual = $LASTEXITCODE
        if ($actual -ne $Expected) { throw "guard case '$Message': exit $actual expected $Expected" }
        if ($actual -eq 0) { git -C $fixture commit -q --allow-empty -m 'reset guard fixture' | Out-Null }
    }
    New-Commit 'ordinary re-pin omitted' { Add-Content (Join-Path $fixture 'ea_template\regression_baseline.active.json') ' ' } 1
    git -C $fixture restore --source HEAD -- ea_template/regression_baseline.active.json 2>$null
    Add-Content (Join-Path $fixture 'ea_template\regression_baseline.active.json') ' '
    git -C $fixture add .
    & git -C $fixture commit -q -m 're-pin baseline' 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { throw 'guard allowed Build-6090 change without migration marker' }
    git -C $fixture reset -q HEAD -- .; git -C $fixture checkout -q -- ea_template/regression_baseline.active.json
    Add-Content (Join-Path $fixture 'ea_template\regression_baseline.active.json') ' '
    git -C $fixture add .
    & git -C $fixture commit -q -m 're-pin BUILD-6090-PROVENANCE-MIGRATION' 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'guard rejected declared migration' }
    $old = Get-Content (Join-Path $fixture 'ea_template\regression_baseline.csv') -Raw
    [IO.File]::WriteAllText((Join-Path $fixture 'ea_template\regression_baseline.csv'), ($old + 'x'))
    git -C $fixture add .
    & git -C $fixture commit -q -m 're-pin BUILD-6090-PROVENANCE-MIGRATION historical' 2>&1 | Out-Null; if ($LASTEXITCODE -eq 0) { throw 'guard allowed historical CSV mutation' }
    Write-Host 'TPL BASELINE GUARD TESTS: 4/4 PASS' -ForegroundColor Green
    exit 0
} finally { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }
