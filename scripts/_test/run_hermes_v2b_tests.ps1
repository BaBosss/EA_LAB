param(
    [string]$PythonExe = "$env:LOCALAPPDATA\hermes\hermes-agent\venv\Scripts\python.exe"
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repoRoot 'scripts\use_python.ps1')
# Qualification only: existing interpreter, synthetic evidence, injected seams.
# The test suite forbids process launch and runs the year splitter in-process.
if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
    throw "Existing MCP-capable Python required: $PythonExe"
}
& $PythonExe -B -m unittest discover -s (Join-Path $repoRoot 'tools\hermes_ea_lab_pilot\tests') -p 'test_real_adapter.py' -v
if ($LASTEXITCODE -ne 0) { throw "Hermes V2-B NO-MT5 tests failed: $LASTEXITCODE" }
