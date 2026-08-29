[CmdletBinding()]
param(
    [Parameter(Mandatory=$true,Position=0)][string]$Identifier,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvDir = Join-Path $scriptDir '.venv-win'
$venvPython = Join-Path $venvDir 'Scripts\python.exe'
$pythonScript = Join-Path $scriptDir 'fetch_and_parse.py'
$requirements = Join-Path $scriptDir 'requirements.txt'

if (-not (Test-Path -LiteralPath $venvPython)) {
    $python = (Get-Command python -ErrorAction Stop).Source
    & $python -m venv $venvDir
    if ($LASTEXITCODE -ne 0) { throw 'research-papers Windows venv bootstrap failed' }
    & $venvPython -m pip install --quiet --upgrade pip
    & $venvPython -m pip install --quiet -r $requirements
    if ($LASTEXITCODE -ne 0) { throw 'research-papers dependency install failed' }
}

$args = @($pythonScript,$Identifier)
if ($Force) { $args += '--force' }
& $venvPython @args
exit $LASTEXITCODE
