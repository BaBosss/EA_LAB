[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OutputPath = '',
    [switch]$Check
)
$ErrorActionPreference='Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $Root 'docs\EA_LAB_KNOWLEDGE_MAP.md' }
function Add-Link {
    param([Collections.Generic.List[string]]$Lines,[string]$Path,[string]$Description)
    $full=Join-Path $Root ($Path -replace '/','\')
    if (Test-Path -LiteralPath $full) { $Lines.Add(('- [{0}](../{0}) - {1}' -f $Path,$Description)) }
}
$lines=New-Object Collections.Generic.List[string]
$lines.Add('# EA_LAB Knowledge Map')
$lines.Add('')
$lines.Add('> **GENERATED / READ-ONLY NAVIGATION.** This page owns no fact. Canonical ownership remains in `docs/memory_control/FACT_OWNER_MAP.md`.')
$lines.Add('> Regenerate with `scripts/make_knowledge_map.ps1`; use `-Check` to detect drift.')
$lines.Add('')
$lines.Add('## Current / Control Tower')
Add-Link $lines 'PROJECT_STATE.md' 'current status, binding decisions, forward plan'
Add-Link $lines 'AGENT_TASKBOARD.md' 'active order text, acceptance, execution state'
Add-Link $lines 'TASKBOARD_DIGEST.md' 'generated compact taskboard view'
Add-Link $lines 'STATUS.md' 'generated status view'
$lines.Add('')
$lines.Add('## Governance / Memory Control')
Add-Link $lines 'AGENTS.md' 'roles, permissions, hard stops, execution protocol'
Add-Link $lines 'VISION.md' 'owner big-picture and factory philosophy'
Add-Link $lines 'docs/memory_control/README.md' 'Memory-Controlled OS status and file map'
Add-Link $lines 'docs/memory_control/FACT_OWNER_MAP.md' 'fact-to-canonical-owner map'
Add-Link $lines 'docs/memory_control/B1_COHORT.md' 'context-friction observation protocol and MVP-2 gate evidence'
$lines.Add('')
$lines.Add('## Factory / EA Selection')
Add-Link $lines 'EA_SCORECARD_AND_REGISTRY.md' 'EA verdict authority'
Add-Link $lines 'EA_MASTER_INDEX.csv' 'registry mirror / legacy index surface where still consumed'
Add-Link $lines 'CLAUDE.md' 'current Factory verdict gate and canonical operator rules'
Add-Link $lines 'docs/PARAM_REGISTRY.csv' 'parameter semantics, activation and coupling metadata'
Add-Link $lines 'docs/skills_mirror/skills/backtest-optimize-rigor/SKILL.md' 'optimization and robustness procedure'
Add-Link $lines 'docs/research/FACTORY_VNEXT_DESIGN_DRAFT.md' 'design-frozen non-canonical source for Factory vNext sidecar implementation'
Add-Link $lines 'docs/research/FACTORY_VNEXT_MVP_PILOT_CONTRACT.md' 'frozen non-authoritative sidecar implementation contract for the first Factory vNext pilot'
$lines.Add('')
$lines.Add('## Template / Execution / Risk')
Add-Link $lines 'ea_template' 'EA template source and capabilities'
Add-Link $lines 'scripts/new_template_entry.ps1' 'new template entry scaffold'
Add-Link $lines 'portfolio/DEPLOYMENTS.csv' 'deployment truth'
$lines.Add('')
$lines.Add('## Research / Intake')
Add-Link $lines 'docs/research/RESEARCH_IDEA_INBOX.md' 'non-authoritative intake and triage queue for ideas, links, PDFs and observations'
Add-Link $lines 'docs/research/EA_LAB_QUANT_INTELLIGENCE_ARCHITECTURE_PLAN.md' 'quant-intelligence research architecture where present'
$lines.Add('')
$lines.Add('## History / Evidence')
Add-Link $lines 'PROJECT_HISTORY.md' 'historical project narrative and decision provenance'
Add-Link $lines 'docs/memory_control/experiment_events' 'append-only experiment event/evidence timeline'
Add-Link $lines 'docs/memory_control/ARCHIVE_INDEX.md' 'reviewed taskboard archive index'
$lines.Add('')
$lines.Add('## Retrieval Rule')
$lines.Add('- Start with `PROJECT_STATE.md` for current status.')
$lines.Add('- Use this map only to navigate; follow the canonical owner before editing or deciding.')
$lines.Add('- For a bounded machine context, generate a transient packet with `scripts/make_context_packet.ps1`.')
$lines.Add('- If two active sources disagree, run `scripts/check_knowledge_integrity.ps1` and treat the disagreement as drift, not as permission to choose one silently.')
$content=($lines -join "`n") + "`n"
if ($Check) {
    if (-not (Test-Path -LiteralPath $OutputPath)) { throw "knowledge map missing: $OutputPath" }
    $existing=[IO.File]::ReadAllText($OutputPath)
    if ($existing -cne $content) { throw 'EA_LAB_KNOWLEDGE_MAP.md is stale; regenerate it.' }
    Write-Output 'KNOWLEDGE_MAP CHECK PASS'
    exit 0
}
[IO.File]::WriteAllText($OutputPath,$content,$Utf8NoBom)
Write-Output ("KNOWLEDGE_MAP WROTE {0}" -f $OutputPath)
