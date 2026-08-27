$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $moduleRoot)
$invoke = Join-Path $moduleRoot 'Invoke-DiagramDesign.ps1'
$build = Join-Path $moduleRoot 'Build-BaselineDiagrams.ps1'
$manifest = Get-Content -LiteralPath (Join-Path $moduleRoot 'workflow_manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json

$status = (& powershell -NoProfile -ExecutionPolicy Bypass -File $invoke -Action Status | Out-String | ConvertFrom-Json)
if ([string]::IsNullOrWhiteSpace($status.upstream_commit) -or [string]::IsNullOrWhiteSpace($status.authority)) { throw 'Status did not return required JSON fields.' }

$listed = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $invoke -Action List | Out-String | ConvertFrom-Json)[0]
if ($listed.Count -ne @($manifest.profiles.PSObject.Properties).Count) { throw 'List did not return every manifest profile.' }

foreach ($property in $manifest.profiles.PSObject.Properties) {
    $name = $property.Name
    $brief = & powershell -NoProfile -ExecutionPolicy Bypass -File $invoke -Action Prompt -Profile $name | Out-String
    if ($brief -notmatch [regex]::Escape("profile '$name'")) { throw "Prompt did not identify profile: $name" }
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $build | Out-Null
foreach ($property in $manifest.profiles.PSObject.Properties) {
    $path = Join-Path $repoRoot $property.Value.output
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing generated diagram: $($property.Value.output)" }
    $html = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if ($html -notmatch 'VISUAL_ONLY_NO_AUTHORITY' -or $html -notmatch 'Provenance:') { throw "Missing safety/provenance marker: $($property.Value.output)" }
    if ($html -match '<(?:script|link)\b' -or $html -match '(?:src|href)=["'']https?://') { throw "External dependency found: $($property.Value.output)" }
}

Write-Output 'diagram_design_ea_lab tests: PASS'
