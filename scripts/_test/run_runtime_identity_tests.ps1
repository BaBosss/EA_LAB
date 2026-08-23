<#
run_runtime_identity_tests.ps1 - bounded runtime identity acceptance suite.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
. (Join-Path $RepoRoot 'scripts\use_python.ps1')
$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$test = Join-Path $RepoRoot '_triage\factory_os\run_runtime_identity_tests.py'
& $py $test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$bridgeSource = Get-Content -LiteralPath (Join-Path $RepoRoot 'scripts\lib\runtime_identity.ps1') -Raw
if ($bridgeSource -notmatch '(?m)^\s+type = "\$\(\$row\.type\)"\r?$') { throw 'runtime identity deal bridge must preserve MT5 deal type' }
Write-Output '[PASS] PowerShell deal bridge preserves MT5 deal type'
