[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('build', 'test', 'check')]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$cwd = (Get-Location).Path
if ($cwd -ne $root) { throw "REFUSE: expected worktree cwd '$root', got '$cwd'" }

$runtime = Join-Path $PSScriptRoot 'runtime'
$artifact = Join-Path $runtime 'build-artifact.txt'
switch ($Profile) {
    'build' {
        New-Item -ItemType Directory -Force -Path $runtime | Out-Null
        Set-Content -LiteralPath $artifact -Value "m2-build cwd=$cwd" -NoNewline
        Write-Output "[PASS] M2 BUILD cwd=$cwd artifact=tools/lnwjud/fixtures/m2-exec/runtime/build-artifact.txt"
    }
    'test' {
        if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) { throw 'REFUSE: BUILD artifact is missing' }
        if ((Get-Content -LiteralPath $artifact -Raw) -ne "m2-build cwd=$cwd") { throw 'REFUSE: BUILD artifact content differs' }
        Write-Output "[PASS] M2 TEST cwd=$cwd assertions=passed"
    }
    'check' {
        if (-not (Test-Path -LiteralPath $PSScriptRoot -PathType Container)) { throw 'REFUSE: fixture is missing' }
        Write-Output "[PASS] M2 CHECK cwd=$cwd fixture=present"
    }
}
