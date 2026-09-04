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
Need 'AGENTS.md' 'STOP_EXPANSION / PARK'
Need 'CLAUDE.md' 'mandatory for every EA'
Need 'CLAUDE.md' '`FROZEN FINALIST` is a workflow-gate label only'
Need 'docs\research\EA_RND_PROTOCOL.md' 'There is no routine Open-Prices Step 0'
Need 'docs\PIPELINE.md' 'mandatory Model-4 MAIN+BWD for every EA'
Need 'docs\MT5_AUTOMATION.md' 'Model-2/Open-Prices and Math Calculations are diagnostic-only'
Need 'docs\skills_mirror\skills\backtest-optimize-rigor\SKILL.md' 'mandatory for every EA before Candidate eligibility'
Need 'docs\skills_mirror\skills\backtest-optimize-rigor\SKILL.md' 'BWD is a falsification surface, not optimizer round two'
Need 'docs\skills_mirror\skills\signal-scanner\SKILL.md' 'Model 1 / 1 Minute OHLC (`M1_M1_OHLC_RESEARCH`)'
Need 'docs\skills_mirror\skills\signal-scanner\SKILL.md' 'STOP_EXPANSION / PARK'
Need 'docs\skills_mirror\skills\locked-ea-analyzer\SKILL.md' 'Model 2/Open Prices is **diagnostic-only**'
Forbid 'CLAUDE.md' 'Model-4 if fill-sensitive'
Forbid 'docs\PIPELINE.md' 'M4 (if due)'
Forbid 'AGENTS.md' 'Model 2 is only for filtering zero-trade cases'
Forbid 'docs\skills_mirror\skills\backtest-optimize-rigor\SKILL.md' 'for the cases in the Step-8 table'
Forbid 'docs\skills_mirror\skills\backtest-optimize-rigor\SKILL.md' 'ONE logged re-pick'
Forbid 'docs\skills_mirror\skills\signal-scanner\SKILL.md' '2023–2026 Model-2 smoke'
Forbid 'docs\skills_mirror\skills\signal-scanner\SKILL.md' 'PARKED-pending-optimize'
Forbid 'docs\skills_mirror\skills\locked-ea-analyzer\SKILL.md' 'Model 2 is fine for the first-pass broad'
Write-Output '[PASS] testing doctrine canonical-owner + live-skill-mirror checks'
