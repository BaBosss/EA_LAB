[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$fixture = Join-Path $PSScriptRoot 'fixtures'
if (-not (Test-Path -LiteralPath $fixture -PathType Container)) {
    throw 'lnwjud acceptance fixture is missing'
}

Write-Output '[PASS] lnwjud bounded process fixture'
