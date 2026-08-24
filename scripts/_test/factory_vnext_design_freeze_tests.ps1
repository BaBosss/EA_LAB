[CmdletBinding()]
param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference='Stop'
$tests=0
function Assert-Match([string]$Text,[string]$Pattern,[string]$Name){
  $script:tests++
  if($Text -notmatch $Pattern){ throw "FAIL: $Name" }
  Write-Output "ok $($script:tests) - $Name"
}
function Assert-True([bool]$Value,[string]$Name){
  $script:tests++
  if(-not $Value){ throw "FAIL: $Name" }
  Write-Output "ok $($script:tests) - $Name"
}
$design=Get-Content -Raw -Encoding UTF8 (Join-Path $Root 'docs\research\FACTORY_VNEXT_DESIGN_DRAFT.md')
$pilot=Get-Content -Raw -Encoding UTF8 (Join-Path $Root 'docs\research\FACTORY_VNEXT_MVP_PILOT_CONTRACT.md')
$map=Get-Content -Raw -Encoding UTF8 (Join-Path $Root 'docs\EA_LAB_KNOWLEDGE_MAP.md')
Assert-Match $design 'DESIGN-FROZEN FOR MVP PILOT IMPLEMENTATION.*NON-CANONICAL' 'design freeze boundary is explicit'
Assert-Match $design 'HomeContract = Concept/Strategy x LogicalSymbol x ExecutionTF' 'home identity binds strategy symbol and execution TF'
Assert-Match $design 'DISCOVERY.*compute-normalized' 'discovery window is compute-normalized'
Assert-Match $design 'COMMON_VALIDATION.*calendar-normalized' 'common validation is calendar-normalized'
Assert-Match $design 'KINT-001.*operationally OPEN' 'KINT-001 stays open until policy migration'
Assert-Match $design 'Step size is not an intrinsic property' 'range resolution is stage-adaptive'
Assert-Match $design 'wide GridSpacingATR hypothesis may legitimately span' 'wide grid-spacing example is preserved'
Assert-Match $design 'Five pages are frozen for MVP design' 'five-page visual report architecture is frozen'
Assert-Match $design 'Telemetry / Evidence Schema' 'telemetry design is frozen'
Assert-Match $design 'MEASURED \| DERIVED \| SIMULATED \| INFERRED \| UNTESTED \| UNAVAILABLE' 'evidence quality labels are explicit'
Assert-Match $design 'No big-bang rewrite' 'migration is sidecar-first'
Assert-Match $design 'OWNER-RESERVED.*risk-capacity' 'risk-capacity values remain owner-reserved'
Assert-Match $pilot 'FROZEN IMPLEMENTATION CONTRACT.*NON-CANONICAL SIDECAR' 'pilot is frozen and non-authoritative'
Assert-Match $pilot 'LogicalSymbol`: BTCUSD' 'pilot logical symbol is BTCUSD'
Assert-Match $pilot 'ExecutionTF`: H4' 'pilot execution timeframe is H4'
Assert-Match $pilot 'offline Strategy Tester / artifact processing only' 'pilot is offline only'
Assert-Match $pilot 'OUTSIDE_VALIDATED_CONTRACT' 'wrong Home identity fails visibly'
Assert-Match $pilot 'Current pushed canonical Factory remains authoritative' 'pilot cannot override current Factory authority'
Assert-Match $pilot 'risk/default changes' 'risk/default mutation remains forbidden'
Assert-Match $map 'FACTORY_VNEXT_DESIGN_DRAFT.md' 'knowledge map links the frozen design'
Assert-Match $map 'FACTORY_VNEXT_MVP_PILOT_CONTRACT.md' 'knowledge map links the pilot contract'
$ki=& (Join-Path $Root 'scripts\check_knowledge_integrity.ps1') -Root $Root 3>&1 | Out-String
Assert-True ($LASTEXITCODE -eq 0 -and $ki -match 'KNOWLEDGE_INTEGRITY PASS') 'knowledge integrity accepts the frozen design boundary'
Write-Output ("FACTORY_VNEXT_DESIGN_FREEZE_TESTS PASS tests={0}" -f $tests)
exit 0
