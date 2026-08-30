$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$python = (Get-Command python -ErrorAction Stop).Source

Write-Output '[external-capability] Research Pod tests'
Push-Location (Join-Path $repo 'tools\ea_research_pod')
& $python 'test_pod.py'
if ($LASTEXITCODE -ne 0) { throw 'Research Pod tests failed' }
Pop-Location

Write-Output '[external-capability] Capability Scout tests'
Push-Location (Join-Path $repo 'tools\external_capability_scout')
& $python 'test_scout.py'
if ($LASTEXITCODE -ne 0) { throw 'Capability Scout tests failed' }
Pop-Location

$skillPairs = @(
    @('.agents\skills\ea-research-pod\SKILL.md', '.claude\skills\ea-research-pod\SKILL.md'),
    @('.agents\skills\ea-capability-scout\SKILL.md', '.claude\skills\ea-capability-scout\SKILL.md')
)
foreach ($pair in $skillPairs) {
    $a = Join-Path $repo $pair[0]
    $b = Join-Path $repo $pair[1]
    $ha = (Get-FileHash $a -Algorithm SHA256).Hash
    $hb = (Get-FileHash $b -Algorithm SHA256).Hash
    if ($ha -ne $hb) { throw "Skill mirror mismatch: $($pair[0])" }
}

$toolFiles = @(
    (Join-Path $repo 'tools\ea_research_pod\pod.py'),
    (Join-Path $repo 'tools\external_capability_scout\scout.py')
)
$forbiddenImports = 'smolagents|litellm|phoenix|mcp|requests|alpaca|kraken|okx|MetaTrader5'
foreach ($file in $toolFiles) {
    if (Select-String -Path $file -Pattern $forbiddenImports -Quiet) {
        throw "Forbidden runtime dependency/import in $file"
    }
    & $python -m py_compile $file
    if ($LASTEXITCODE -ne 0) { throw "py_compile failed: $file" }
}

Write-Output 'PASS: external capability integration deterministic cage'
