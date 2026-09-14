$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts/use_python.ps1')
$pythonExe = Assert-PortablePython -Root $repoRoot -Provision
$oldBytecode = $env:PYTHONDONTWRITEBYTECODE
try {
    $env:PYTHONDONTWRITEBYTECODE = '1'
    Push-Location $repoRoot
    try {
        & $pythonExe -B (Join-Path $repoRoot 'tools/control_center/forward_alpha/run_tests.py')
        exit $LASTEXITCODE
    } finally { Pop-Location }
} finally { $env:PYTHONDONTWRITEBYTECODE = $oldBytecode }
