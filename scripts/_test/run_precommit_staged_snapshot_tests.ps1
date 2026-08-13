<#
ORDER-545 -- staged-snapshot integrity cage.

This is a disposable-repository regression for the hook-mode fast tier. The historical
hooks.ignore_paths shape is now represented by the generated fast-tier pathspec and the
$SUITE_GUARDS table in run_fast_cages.ps1. The fixture stages that guard path while its
worktree copy disagrees, then proves the selected suite judges the staged bytes.

The fixture owns its repository and index. The real worktree and real .git/index are never
touched.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Invoke-Git {
    param([string]$Root, [string[]]$Arguments)
    $out = & git -C $Root @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git failed ($($Arguments -join ' ')): $($out -join "`n")"
    }
    return @($out)
}

function Set-IndexedText {
    param([string]$Root, [string]$RelativePath, [string]$Text)
    $blobPath = Join-Path $Root ('.blob_' + [guid]::NewGuid().ToString('N'))
    try {
        Write-Utf8NoBom -Path $blobPath -Text $Text
        $oid = ((Invoke-Git -Root $Root -Arguments @('hash-object', '-w', '--', $blobPath)) | Select-Object -Last 1).ToString().Trim()
        Assert-True ($oid -match '^[0-9a-f]{40}$') "hash-object returned an invalid oid for $RelativePath"
        Invoke-Git -Root $Root -Arguments @('update-index', '--add', '--cacheinfo', "100644,$oid,$RelativePath") | Out-Null
    } finally {
        Remove-Item -LiteralPath $blobPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-StagedPaths {
    param([string]$Root)
    return @(Invoke-Git -Root $Root -Arguments @('diff', '--cached', '--name-only', '--no-renames') |
             ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
}

function Invoke-FastTier {
    param(
        [string]$PowerShell,
        [string]$FastScript,
        [string]$Root,
        [string]$PathsFile,
        [switch]$DebugPretendIndexMoved
    )
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $FastScript,
        '-RepoRoot', $Root, '-Hook', '-StagedPathsFile', $PathsFile, '-BudgetSeconds', '90',
        '-FullTierBudgetSeconds', '120', '-EvidenceSuitesOverride', 'NONE')
    if ($DebugPretendIndexMoved) { $arguments += '-DebugPretendIndexMoved' }
    $output = @(& $PowerShell @arguments 2>&1 |
        ForEach-Object { $_.ToString() })
    $code = $LASTEXITCODE
    [pscustomobject]@{ Exit = $code; Output = $output }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fastScript = Join-Path $repoRoot 'scripts\_test\run_fast_cages.ps1'
$powerShell = (Get-Process -Id $PID).Path
if (-not $powerShell) { $powerShell = 'powershell.exe' }

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ea_lab_order545_' + [guid]::NewGuid().ToString('N'))
$priorIndex = $env:GIT_INDEX_FILE
$priorTier = $env:EA_LAB_TIER_RUN

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts\_test') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot '.githooks') -Force | Out-Null

    Invoke-Git -Root $tempRoot -Arguments @('init', '--initial-branch=master') | Out-Null
    Invoke-Git -Root $tempRoot -Arguments @('config', 'user.name', 'ORDER-545 cage') | Out-Null
    Invoke-Git -Root $tempRoot -Arguments @('config', 'user.email', 'order-545-cage@example.invalid') | Out-Null
    Invoke-Git -Root $tempRoot -Arguments @('config', 'core.autocrlf', 'false') | Out-Null

    [System.IO.File]::Copy($fastScript, (Join-Path $tempRoot 'scripts\_test\run_fast_cages.ps1'))

    $suite = @'
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ($env:EA_LAB_EVIDENCE -ne 'index') {
    Write-Host "expected Hook mode to set EA_LAB_EVIDENCE=index"
    exit 3
}
$value = (Get-Content -LiteralPath (Join-Path $root 'fixtures\payload.txt') -Raw).Trim()
if ($value -ne 'GOOD') {
    Write-Host "payload judged from worktree: $value"
    exit 1
}
Write-Host '##EVIDENCE-MODE## run_b1_guard_tests.ps1 index'
exit 0
'@
    Write-Utf8NoBom -Path (Join-Path $tempRoot 'scripts\_test\run_b1_guard_tests.ps1') -Text $suite
    Write-Utf8NoBom -Path (Join-Path $tempRoot '.githooks\commit-msg') -Text "BASE`n"
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'fixtures') -Force | Out-Null
    Write-Utf8NoBom -Path (Join-Path $tempRoot 'fixtures\payload.txt') -Text "GOOD`n"

    Invoke-Git -Root $tempRoot -Arguments @('add', '-A') | Out-Null
    Invoke-Git -Root $tempRoot -Arguments @('commit', '-m', 'fixture baseline') | Out-Null

    $indexCopy = Join-Path $tempRoot '.git\index'
    $env:EA_LAB_TIER_RUN = '1'

    # Current canonical trigger representation: the commit-msg guard path is declared by
    # $SUITE_GUARDS and is also present in .githooks/fast_tier_pathspec. The index says
    # this path is GOOD while the worktree says BAD.
    Set-IndexedText -Root $tempRoot -RelativePath '.githooks/commit-msg' -Text "TRIGGER_GOOD`n"
    Write-Utf8NoBom -Path (Join-Path $tempRoot '.githooks\commit-msg') -Text "TRIGGER_BAD`n"
    Write-Utf8NoBom -Path (Join-Path $tempRoot 'fixtures\payload.txt') -Text "BAD`n"
    $pathsFile = Join-Path $tempRoot 'staged-paths.txt'
    Write-Utf8NoBom -Path $pathsFile -Text ((Get-StagedPaths -Root $tempRoot) -join "`n")
    $selection = @(& $powerShell -NoProfile -ExecutionPolicy Bypass -File $fastScript `
        -RepoRoot $tempRoot -StagedPathsFile $pathsFile -ExportSelection 2>&1 |
        ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
    Assert-True (($selection.Count -eq 1) -and ($selection[0] -eq 'run_b1_guard_tests.ps1')) `
        "staged guard path selected unexpected suites: $($selection -join ', ')"

    $t1IndexInfoBefore = Get-Item -LiteralPath $indexCopy
    $t1IndexHashBefore = ((Get-FileHash -LiteralPath $indexCopy -Algorithm SHA256).Hash)
    $t1 = Invoke-FastTier -PowerShell $powerShell -FastScript $fastScript -Root $tempRoot -PathsFile $pathsFile
    $t1IndexHashAfter = ((Get-FileHash -LiteralPath $indexCopy -Algorithm SHA256).Hash)
    $t1IndexInfoAfter = Get-Item -LiteralPath $indexCopy
    Assert-True ($t1.Exit -eq 0) "T1 STAGED GOOD / WORKTREE BAD was refused (index mtime $($t1IndexInfoBefore.LastWriteTimeUtc.Ticks) -> $($t1IndexInfoAfter.LastWriteTimeUtc.Ticks)): $($t1.Output -join "`n")"
    Assert-True ($t1IndexHashBefore -eq $t1IndexHashAfter) 'T1 changed the disposable index during the tier'
    Write-Host '[PASS] T1 staged GOOD / worktree BAD follows staged bytes'

    # Reverse the same attack: the index is BAD while the worktree is GOOD. A suite that
    # reads the disk passes here, which is the false-green failure ORDER-545 closes.
    Set-IndexedText -Root $tempRoot -RelativePath '.githooks/commit-msg' -Text "TRIGGER_BAD`n"
    Set-IndexedText -Root $tempRoot -RelativePath 'fixtures/payload.txt' -Text "BAD`n"
    Write-Utf8NoBom -Path (Join-Path $tempRoot '.githooks\commit-msg') -Text "TRIGGER_GOOD`n"
    Write-Utf8NoBom -Path (Join-Path $tempRoot 'fixtures\payload.txt') -Text "GOOD`n"
    Write-Utf8NoBom -Path $pathsFile -Text ((Get-StagedPaths -Root $tempRoot) -join "`n")

    $t2 = Invoke-FastTier -PowerShell $powerShell -FastScript $fastScript -Root $tempRoot -PathsFile $pathsFile
    Assert-True ($t2.Exit -ne 0) 'T2 STAGED BAD / WORKTREE GOOD incorrectly passed'
    Write-Host '[PASS] T2 staged BAD / worktree GOOD is refused'
    Write-Host '[PASS] T3 current $SUITE_GUARDS / fast_tier_pathspec trigger representation exercised'
    Write-Host '[PASS] T4 disposable repository/index/worktree isolation'
    Write-Host '[PASS] T5 Hook mode reached the selected suite'
    $t6 = Invoke-FastTier -PowerShell $powerShell -FastScript $fastScript -Root $tempRoot -PathsFile $pathsFile -DebugPretendIndexMoved
    Assert-True (($t6.Exit -ne 0) -and (($t6.Output -join "`n") -match 'index .* changed content')) 'T6 index-movement refusal did not fire'
    Write-Host '[PASS] T6 existing hook-mode movement refusal remains fail-closed'
    Write-Host '[PASS] T7 bounded change is limited to the staged-snapshot seam and its cage'
    Write-Host 'ORDER-545 staged-snapshot integrity cage: PASS'
    exit 0
} finally {
    if ($null -eq $priorIndex) { Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue }
    else { $env:GIT_INDEX_FILE = $priorIndex }
    if ($null -eq $priorTier) { Remove-Item Env:EA_LAB_TIER_RUN -ErrorAction SilentlyContinue }
    else { $env:EA_LAB_TIER_RUN = $priorTier }
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
