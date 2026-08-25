[CmdletBinding()]
param([string]$PythonExe = $env:EA_LAB_PYTHON)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$ModuleRoot = Join-Path $RepoRoot 'tools\ea_lab_ziplime'

function Test-Python([string]$Candidate) {
    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $false }
    if (-not (Test-Path -LiteralPath $Candidate)) { return $false }
    & $Candidate -c "import sys; raise SystemExit(0 if (3,12) <= sys.version_info[:2] < (3,14) else 1)" 2>$null
    return ($LASTEXITCODE -eq 0)
}

$candidates = @(
    $PythonExe,
    (Join-Path $RepoRoot 'tools\python312\python.exe'),
    'D:\EA_LAB\tools\python312\python.exe'
)
$PythonExe = $null
foreach ($candidate in $candidates) {
    if (Test-Python $candidate) { $PythonExe = $candidate; break }
}
if (-not $PythonExe) { throw 'Ziplime module tests require a working Python >=3.12,<3.14 runtime.' }

Write-Host "[ziplime] python=$PythonExe"
& $PythonExe (Join-Path $ModuleRoot 'test_module.py') -v
if ($LASTEXITCODE -ne 0) { throw "Ziplime module unit tests failed: exit $LASTEXITCODE" }
Write-Host '[ziplime] focused tests PASS'
