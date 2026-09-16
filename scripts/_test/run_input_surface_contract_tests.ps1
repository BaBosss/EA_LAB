# Real input-surface mutations plus acceptance of the worktree source contract.
# Under -Hook the FAST runner supplies an immutable staged-snapshot worktree.
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

$savedEncoding = $env:PYTHONIOENCODING
$savedBytecode = $env:PYTHONDONTWRITEBYTECODE
$savedPath = $env:Path
try {
    $env:PYTHONIOENCODING = 'utf-8'
    $env:PYTHONDONTWRITEBYTECODE = '1'
    $bootstrap = Join-Path $RepoRoot 'scripts/use_python.ps1'
    $suite = Join-Path $RepoRoot '_triage/factory_os/run_input_surface_tests.py'
    $checker = Join-Path $RepoRoot '_triage/factory_os/check_input_surface_gen.py'
    foreach ($path in @($bootstrap, $suite, $checker)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "required tool missing: $path"
        }
    }
    . $bootstrap
    $python = Assert-PortablePython -Root $RepoRoot -Provision
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $output = @(& $python $suite --mutate 2>&1)
    $code = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($code -ne 0) {
        Write-Host "[input-surface-contract] FAIL: mutation suite exited $code"
        exit $code
    }
    $headers = @($output | Select-String '^=== ORDER-710 input-surface enumeration: ([1-9][0-9]*) criteria, attack \+ specificity ===$')
    $mutants = @($output | Select-String '^  \[OK \] (\S+)\s+mutant\s+.+\s+DETECTED$')
    $ids = @($mutants | ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique)
    if ($headers.Count -ne 1 -or $mutants.Count -eq 0 -or
        $mutants.Count -ne [int]$headers[0].Matches[0].Groups[1].Value -or
        $ids.Count -ne $mutants.Count) {
        throw 'mutation evidence missing, incomplete, or duplicated'
    }
    $output = @(& $python $checker --worktree 2>&1)
    $code = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($code -ne 0) {
        Write-Host "[input-surface-contract] FAIL: worktree checker exited $code"
        exit $code
    }
    $markers = @($output | Select-String '^##EVIDENCE-MODE## check_input_surface_gen worktree(?:\s|$)')
    $accepted = @($output | Select-String '^=== ACCEPTED: the enumeration matches the surface, and it is wired in ===$')
    if ($markers.Count -ne 1 -or $accepted.Count -ne 1) {
        throw 'real worktree acceptance evidence missing or duplicated'
    }
    Write-Host ('[input-surface-contract] PASS: {0} mutants detected; real worktree accepted ({1:N2}s)' -f $mutants.Count, $clock.Elapsed.TotalSeconds)
} catch {
    Write-Host ('[input-surface-contract] FAIL / TOOL FAILURE: {0}' -f $_.Exception.Message)
    exit 2
} finally {
    $env:PYTHONIOENCODING = $savedEncoding
    $env:PYTHONDONTWRITEBYTECODE = $savedBytecode
    $env:Path = $savedPath
}
exit 0
