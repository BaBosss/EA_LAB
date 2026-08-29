[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$KnowledgeOnly
)
$ErrorActionPreference = 'Stop'
$errors = New-Object Collections.Generic.List[string]
function Add-Err([string]$Message) { $script:errors.Add($Message) }

$knowledge = Join-Path $Root 'knowledge'
$required = @(
    'README.md',
    '00_indexes/SECOND_BRAIN_INDEX.md',
    '00_indexes/TOOLING_PROVENANCE.md',
    '01_sources/README.md',
    '01_sources/source_registry.jsonl',
    '01_sources/drive_intake_20260829.csv',
    '02_research_cards',
    '03_strategy_mechanisms',
    '04_components',
    '05_regimes',
    '06_validation',
    '07_risk_execution',
    '08_experiments/README.md',
    '09_strategy_blueprints/README.md',
    '10_synthesis',
    '90_negative_knowledge/README.md',
    '99_templates/RESEARCH_CARD.md',
    '99_templates/MECHANISM_CARD.md',
    '99_templates/SOURCE_RECORD.schema.json'
)
foreach ($rel in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $knowledge ($rel -replace '/','\')))) {
        Add-Err "missing Second Brain path: knowledge/$rel"
    }
}
if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }
$registryPath = Join-Path $knowledge '01_sources\source_registry.jsonl'
$records = New-Object Collections.Generic.List[object]
$ids = @{}
$lineNo = 0
foreach ($line in Get-Content -LiteralPath $registryPath -Encoding UTF8) {
    $lineNo++
    if (-not $line.Trim()) { continue }
    try { $r = $line | ConvertFrom-Json }
    catch { Add-Err "source registry invalid JSON at line $lineNo"; continue }
    foreach ($field in @('source_id','source_type','title','locator','sha256','status','authority')) {
        if (-not $r.PSObject.Properties.Name.Contains($field) -or [string]::IsNullOrWhiteSpace([string]$r.$field)) {
            Add-Err "source registry line $lineNo missing field: $field"
        }
    }
    if ([string]$r.source_id -notmatch '^SRC-[A-Z0-9-]+$') { Add-Err "invalid source_id: $($r.source_id)" }
    if ($ids.ContainsKey([string]$r.source_id)) { Add-Err "duplicate source_id: $($r.source_id)" }
    else { $ids[[string]$r.source_id] = $true }
    if ([string]$r.sha256 -cnotmatch '^[0-9a-f]{64}$') { Add-Err "invalid lowercase sha256: $($r.source_id)" }
    if ([string]$r.authority -cne 'RESEARCH_ONLY') { Add-Err "source authority must be RESEARCH_ONLY: $($r.source_id)" }
    $records.Add($r)
}

foreach ($r in $records) {
    if ([string]$r.locator -match '^(https?://|gdrive:|drive:)') { continue }
    $target = Join-Path $Root ([string]$r.locator -replace '/','\')
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        Add-Err "registered local source missing: $($r.source_id) -> $($r.locator)"
        continue
    }
    $actual = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne [string]$r.sha256) { Add-Err "source hash mismatch: $($r.source_id)" }
}

$driveIntake = @(Import-Csv -LiteralPath (Join-Path $knowledge '01_sources\drive_intake_20260829.csv'))
if ($driveIntake.Count -ne 26) { Add-Err "Drive intake snapshot expected 26 direct files; found $($driveIntake.Count)" }
$driveIds = @($driveIntake | ForEach-Object { [string]$_.drive_file_id })
if (($driveIds | Select-Object -Unique).Count -ne $driveIds.Count) { Add-Err 'Drive intake contains duplicate file IDs' }
if (@($driveIntake | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.triage) }).Count -gt 0) { Add-Err 'Drive intake contains blank triage values' }

$cards = @(Get-ChildItem -LiteralPath (Join-Path $knowledge '02_research_cards') -Filter '*.md' -File)
foreach ($card in $cards) {
    $raw = Get-Content -LiteralPath $card.FullName -Raw -Encoding UTF8
    $m = [regex]::Match($raw, '(?m)^source_id:\s*(SRC-[A-Z0-9-]+)\s*$')
    if (-not $m.Success) { Add-Err "research card missing single registered source_id: $($card.Name)"; continue }
    if (-not $ids.ContainsKey($m.Groups[1].Value)) { Add-Err "research card source_id not registered: $($card.Name) -> $($m.Groups[1].Value)" }
    if ($raw -notmatch '## SOURCE_CLAIM') { Add-Err "research card missing SOURCE_CLAIM section: $($card.Name)" }
    if ($raw -notmatch '## EA_LAB_INFERENCE') { Add-Err "research card missing EA_LAB_INFERENCE section: $($card.Name)" }
    if ($raw -notmatch '(?m)^authority:\s*RESEARCH_ONLY\s*$') { Add-Err "research card lacks RESEARCH_ONLY authority: $($card.Name)" }
}

foreach ($shadowDir in @('08_experiments','09_strategy_blueprints')) {
    $bad = @(Get-ChildItem -LiteralPath (Join-Path $knowledge $shadowDir) -Recurse -File | Where-Object { $_.Extension -match '^\.(json|jsonl|ya?ml|csv)$' })
    foreach ($f in $bad) { Add-Err "shadow registry/data file forbidden under knowledge/${shadowDir}: $($f.Name)" }
}

if (-not $KnowledgeOnly) {
    $skillNames = @('research-papers','compare-research-methods','map-literature-contradictions','locate-review-research-gap','ea-research-intake','ea-evidence-critic','ea-knowledge-query','ea-strategy-synthesizer','ea-negative-memory')
    foreach ($surface in @('.agents\skills','.claude\skills')) {
        foreach ($name in $skillNames) {
            $skillPath = Join-Path $Root "$surface\$name\SKILL.md"
            if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) { Add-Err "missing project-local skill: $surface/$name/SKILL.md" }
        }
    }
    foreach ($name in @('ea-research-intake','ea-evidence-critic','ea-knowledge-query','ea-strategy-synthesizer','ea-negative-memory')) {
        $raw = Get-Content -LiteralPath (Join-Path $Root ".agents\skills\$name\SKILL.md") -Raw -Encoding UTF8
        if ($raw -notmatch 'RESEARCH_ONLY' -or $raw -notmatch 'QI-2\+') { Add-Err "custom skill boundary incomplete: $name" }
    }
    foreach ($name in $skillNames) {
        $aRoot = Join-Path $Root ".agents\skills\$name"
        $cRoot = Join-Path $Root ".claude\skills\$name"
        $aFiles = @(Get-ChildItem -LiteralPath $aRoot -Recurse -File | Where-Object { $_.FullName -notmatch '\\.venv(-win)?\\' })
        $cFiles = @(Get-ChildItem -LiteralPath $cRoot -Recurse -File | Where-Object { $_.FullName -notmatch '\\.venv(-win)?\\' })
        $aMap = @{}; $cMap = @{}
        foreach ($f in $aFiles) { $aMap[$f.FullName.Substring($aRoot.Length + 1)] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash }
        foreach ($f in $cFiles) { $cMap[$f.FullName.Substring($cRoot.Length + 1)] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash }
        foreach ($rel in @($aMap.Keys + $cMap.Keys | Select-Object -Unique)) {
            if (-not $aMap.ContainsKey($rel) -or -not $cMap.ContainsKey($rel) -or $aMap[$rel] -cne $cMap[$rel]) { Add-Err "skill surface drift: $name/$rel" }
        }
    }
    $prov = Get-Content -LiteralPath (Join-Path $knowledge '00_indexes\TOOLING_PROVENANCE.md') -Raw -Encoding UTF8
    foreach ($pin in @('97131ba7007f62374cc689cf7a85fa8fead8bb2b','84de3ba1f3853334d565fbbe6ac4f321cba6bd6b')) {
        if ($prov -notmatch [regex]::Escape($pin)) { Add-Err "tooling provenance missing pinned commit: $pin" }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    Write-Output ("SECOND_BRAIN_CHECK FAIL errors={0}" -f $errors.Count)
    exit 1
}
Write-Output ("SECOND_BRAIN_CHECK PASS sources={0} cards={1}" -f $records.Count,$cards.Count)
exit 0
