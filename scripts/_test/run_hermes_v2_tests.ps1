param(
    [string]$PythonExe = "$env:LOCALAPPDATA\hermes\hermes-agent\venv\Scripts\python.exe"
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts\use_python.ps1')
# The checkout's portable stdlib may be absent, and MCP requires Hermes dependencies.
# Use the already installed interpreter read-only; never provision or activate profiles.
if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
    throw "Existing MCP-capable Python required: $PythonExe"
}
foreach ($suite in @('test_batch_executor.py', 'test_verified_learning.py', 'test_safe_tester_executor.py', 'test_safe_workspace_reader.py')) {
    & $PythonExe -B -m unittest discover -s (Join-Path $repoRoot 'tools\hermes_ea_lab_pilot\tests') -p $suite -v
    if ($LASTEXITCODE -ne 0) { throw "Hermes V2-A suite $suite failed: $LASTEXITCODE" }
}
