[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
$tests = 0
function Assert-True([bool]$Condition,[string]$Message) {
    $script:tests++
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Output "ok $($script:tests) - $Message"
}
function Invoke-Check([string]$CheckRoot,[switch]$KnowledgeOnly) {
    $check = Join-Path $Root 'scripts\check_second_brain.ps1'
    $argv = @('-NoProfile','-File',$check,'-Root',$CheckRoot)
    if ($KnowledgeOnly) { $argv += '-KnowledgeOnly' }
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & powershell.exe @argv 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = $oldEap
    return [pscustomobject]@{ ExitCode = $code; Output = $out }
}

$positive = Invoke-Check $Root
Assert-True ($positive.ExitCode -eq 0 -and $positive.Output -match 'SECOND_BRAIN_CHECK PASS') 'canonical Second Brain foundation passes integrity check'

$registry = Get-Content -LiteralPath (Join-Path $Root 'knowledge\01_sources\source_registry.jsonl') -Encoding UTF8
Assert-True ($registry.Count -ge 3) 'seed source registry contains migrated research sources'
$ids = @($registry | ForEach-Object { ($_ | ConvertFrom-Json).source_id })
Assert-True (($ids | Select-Object -Unique).Count -eq $ids.Count) 'source IDs are unique'

$temp = Join-Path ([IO.Path]::GetTempPath()) ('ea_lab_second_brain_' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'knowledge') -Destination (Join-Path $temp 'knowledge') -Recurse
    foreach ($rel in @('_triage\SSRN_151strategies_PBX_ebook_2026-07-13.md','_triage\SSRN_151_catalog_mechanisms.md','_triage\FINDYOUR8_STRATEGY_PDF_CATALOG.md')) {
        $dest = Join-Path $temp $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath (Join-Path $Root $rel) -Destination $dest
    }
    $copyPass = Invoke-Check $temp -KnowledgeOnly
    Assert-True ($copyPass.ExitCode -eq 0) 'portable knowledge-only copy validates with identical source bytes'
    $regPath = Join-Path $temp 'knowledge\01_sources\source_registry.jsonl'
    $raw = Get-Content -LiteralPath $regPath -Raw -Encoding UTF8
    $tampered = [regex]::Replace($raw, '"sha256":"[0-9a-f]{64}"', '"sha256":"0000000000000000000000000000000000000000000000000000000000000000"', 1)
    [IO.File]::WriteAllText($regPath,$tampered,(New-Object Text.UTF8Encoding($false)))
    $badHash = Invoke-Check $temp -KnowledgeOnly
    Assert-True ($badHash.ExitCode -ne 0 -and $badHash.Output -match 'source\s+hash\s+mismatch') 'tampered registered source hash fails closed'

    Copy-Item -LiteralPath (Join-Path $Root 'knowledge\01_sources\source_registry.jsonl') -Destination $regPath -Force
    $shadow = Join-Path $temp 'knowledge\08_experiments\shadow_registry.jsonl'
    [IO.File]::WriteAllText($shadow,'{"forbidden":true}',(New-Object Text.UTF8Encoding($false)))
    $badShadow = Invoke-Check $temp -KnowledgeOnly
    Assert-True ($badShadow.ExitCode -ne 0 -and $badShadow.Output -match 'shadow\s+registry/data\s+file\s+forbidden') 'second experiment registry is rejected'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}

$expReadme = Get-Content -LiteralPath (Join-Path $Root 'knowledge\08_experiments\README.md') -Raw -Encoding UTF8
$stratReadme = Get-Content -LiteralPath (Join-Path $Root 'knowledge\09_strategy_blueprints\README.md') -Raw -Encoding UTF8
Assert-True ($expReadme -match 'must not become a second experiment registry') 'experiment pointer layer states no-second-registry boundary'
Assert-True ($stratReadme -match 'must not become a second strategy registry') 'strategy pointer layer states no-second-registry boundary'

Write-Output ("SECOND_BRAIN_TESTS PASS tests={0}" -f $tests)
exit 0
