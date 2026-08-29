[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
$ErrorActionPreference='Stop'
$errors=New-Object Collections.Generic.List[string]
$warnings=New-Object Collections.Generic.List[string]
function Add-Error([string]$m){$errors.Add($m)}
function Add-Warn([string]$m){$warnings.Add($m)}

$required=@(
 'PROJECT_STATE.md','AGENTS.md','AGENT_TASKBOARD.md','EA_SCORECARD_AND_REGISTRY.md','VISION.md',
 'portfolio/DEPLOYMENTS.csv','docs/memory_control/FACT_OWNER_MAP.md','docs/memory_control/README.md',
 'docs/memory_control/B1_COHORT.md','docs/research/RESEARCH_IDEA_INBOX.md',
 'docs/research/FACTORY_VNEXT_DESIGN_DRAFT.md','docs/research/FACTORY_VNEXT_MVP_PILOT_CONTRACT.md',
 'docs/research/EA_LAB_SECOND_BRAIN_FOUNDATION.md','knowledge/README.md','knowledge/00_indexes/SECOND_BRAIN_INDEX.md',
 'knowledge/01_sources/source_registry.jsonl','scripts/check_second_brain.ps1',
 'docs/EA_LAB_KNOWLEDGE_MAP.md','CLAUDE.md',
 'docs/skills_mirror/skills/backtest-optimize-rigor/SKILL.md',
 'scripts/make_context_packet.ps1','scripts/make_knowledge_map.ps1'
)
foreach($p in $required){ if(-not (Test-Path -LiteralPath (Join-Path $Root ($p -replace '/','\')))){ Add-Error "missing required knowledge path: $p" } }
if($errors.Count -gt 0){ $errors | ForEach-Object { Write-Error $_ }; exit 1 }

$ownerMap=Get-Content -LiteralPath (Join-Path $Root 'docs\memory_control\FACT_OWNER_MAP.md') -Raw -Encoding UTF8
foreach($needle in @('AGENT_TASKBOARD.md','PROJECT_STATE.md','EA_SCORECARD_AND_REGISTRY.md','portfolio/DEPLOYMENTS.csv','VISION.md','AGENTS.md')){
 if($ownerMap -notmatch [regex]::Escape($needle)){ Add-Error "FACT_OWNER_MAP missing canonical owner reference: $needle" }
}
$memoryReadme=Get-Content -LiteralPath (Join-Path $Root 'docs\memory_control\README.md') -Raw -Encoding UTF8
if($memoryReadme -match 'MVP-2 Context Packet generator.*NOT BUILT'){ Add-Error 'memory-control README still claims MVP-2 Context Packet is not built' }
if($memoryReadme -match 'Stops when 20 rows collected|MVP-2 stays unbuilt'){ Add-Error 'memory-control README contains superseded B1/MVP-2 standing-duty wording' }
try {
    $packetRaw1=& (Join-Path $Root 'scripts\make_context_packet.ps1') -Root $Root -Ref 'origin/master' -Stdout
    $packetRaw2=& (Join-Path $Root 'scripts\make_context_packet.ps1') -Root $Root -Ref 'origin/master' -Stdout
    $packet1=$packetRaw1 | ConvertFrom-Json
    $packet2=$packetRaw2 | ConvertFrom-Json
    $origin=((& git -C $Root rev-parse origin/master) | Out-String).Trim()
    if(-not [bool]$packet1.non_authoritative){ Add-Error 'Context Packet is not marked non_authoritative' }
    if([string]$packet1.freshness -cne 'FRESH' -or [string]$packet1.source_commit -cne $origin){ Add-Error 'Context Packet is not pinned FRESH to local origin/master' }
    if(@($packet1.core.task.taskboard_parts).Count -lt 1){ Add-Error 'Context Packet did not resolve split active taskboard parts' }
    if([string]$packet1.packet_hash -cne [string]$packet2.packet_hash){ Add-Error 'Context Packet hash is not deterministic for identical source commit' }
} catch { Add-Error ('Context Packet integrity smoke failed: ' + $_.Exception.Message) }
$inbox=Get-Content -LiteralPath (Join-Path $Root 'docs\research\RESEARCH_IDEA_INBOX.md') -Raw -Encoding UTF8
if($inbox -notmatch 'NON-AUTHORITATIVE INTAKE ONLY'){ Add-Error 'research inbox lacks non-authoritative boundary' }
$draft=Get-Content -LiteralPath (Join-Path $Root 'docs\research\FACTORY_VNEXT_DESIGN_DRAFT.md') -Raw -Encoding UTF8
if($draft -notmatch 'NON-CANONICAL FOR CURRENT FACTORY POLICY'){ Add-Error 'Factory vNext draft lacks design-frozen non-canonical boundary' }
$pilot=Get-Content -LiteralPath (Join-Path $Root 'docs\research\FACTORY_VNEXT_MVP_PILOT_CONTRACT.md') -Raw -Encoding UTF8
if($pilot -notmatch 'FROZEN IMPLEMENTATION CONTRACT.*NON-CANONICAL SIDECAR'){ Add-Error 'Factory vNext pilot contract lacks frozen non-canonical sidecar boundary' }

$claude=Get-Content -LiteralPath (Join-Path $Root 'CLAUDE.md') -Raw -Encoding UTF8
$optSkill=Get-Content -LiteralPath (Join-Path $Root 'docs\skills_mirror\skills\backtest-optimize-rigor\SKILL.md') -Raw -Encoding UTF8
$flatRule=($claude -match '(?i)100 closed trades|>=\s*100|≥\s*100')
$typeRelative=($optSkill -match '(?i)replaces a flat|trade-count expectation by type|H4/D1.*60|H1/M30.*100')
if($flatRule -and $typeRelative){
    if($draft -match 'KINT-001\s+—\s+OPEN|KINT-001.*OPEN'){ Add-Warn 'KINT-001 known sample-floor contradiction remains OPEN and explicitly documented.' }
    else { Add-Error 'sample-floor contradiction detected but KINT-001 is not documented OPEN in Factory vNext draft' }
}

try { & (Join-Path $Root 'scripts\check_second_brain.ps1') -Root $Root | Write-Output }
catch { Add-Error ("Second Brain integrity failed: " + $_.Exception.Message) }
try { & (Join-Path $Root 'scripts\make_knowledge_map.ps1') -Root $Root -Check | Write-Output }
catch { Add-Error ("knowledge-map drift: " + $_.Exception.Message) }
foreach($w in $warnings){ Write-Warning $w }
if($errors.Count -gt 0){
    $errors | ForEach-Object { Write-Error $_ }
    Write-Output ("KNOWLEDGE_INTEGRITY FAIL errors={0} warnings={1}" -f $errors.Count,$warnings.Count)
    exit 1
}
Write-Output ("KNOWLEDGE_INTEGRITY PASS warnings={0}" -f $warnings.Count)
exit 0
