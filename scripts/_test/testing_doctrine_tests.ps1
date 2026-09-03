$ErrorActionPreference='Stop'
$Root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Need([string]$Rel,[string]$Text){
  $raw=[IO.File]::ReadAllText((Join-Path $Root $Rel))
  if(-not $raw.Contains($Text)){throw "DOCTRINE missing '$Text' in $Rel"}
}
function Forbid([string]$Rel,[string]$Text){
  $raw=[IO.File]::ReadAllText((Join-Path $Root $Rel))
  if($raw.Contains($Text)){throw "DOCTRINE stale '$Text' in $Rel"}
}
Need 'AGENTS.md' 'M2_OPEN_PRICE_DIAGNOSTIC_ONLY'
Need 'AGENTS.md' 'Every EA must pass frozen-config Model 4 MAIN+BWD'
Need 'CLAUDE.md' 'mandatory for every EA'
Need 'CLAUDE.md' 'Model-4 MAIN+BWD'
Need 'docs\research\EA_RND_PROTOCOL.md' 'There is no routine Open-Prices Step 0'
Need 'docs\research\EA_RND_PROTOCOL.md' 'M4_REAL_TICK_FIDELITY'
Need 'docs\PIPELINE.md' 'mandatory Model-4 MAIN+BWD for every EA'
Need 'docs\MT5_AUTOMATION.md' 'Model-2/Open-Prices and Math Calculations are diagnostic-only'
Forbid 'CLAUDE.md' 'Model-4 if fill-sensitive'
Forbid 'docs\PIPELINE.md' 'M4 (if due)'
Forbid 'AGENTS.md' 'Model 2 is only for filtering zero-trade cases'
Write-Output '[PASS] testing doctrine canonical-owner checks'