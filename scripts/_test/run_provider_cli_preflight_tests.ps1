$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script=Join-Path $repo 'scripts\execution_reliability\provider_cli_preflight.ps1'
$fixture=Join-Path $PSScriptRoot 'fixtures\codex_exec_help_0_144_2.txt'
$badFixture=Join-Path $PSScriptRoot 'fixtures\codex_exec_help_incompatible.txt'
function Assert([bool]$Value,[string]$Message){if(-not $Value){throw "ASSERT: $Message"}}

$codex=& $script -Provider Codex -HelpFile $fixture -ProviderVersion 'codex-cli 0.144.2 fixture' -Json|ConvertFrom-Json
Assert ($codex.compatibility -eq 'COMPATIBLE') 'installed-shape Codex help fixture must qualify the argument surface'
Assert ($codex.argument_contract -eq 'CODEX_EXEC_TRANSIENT_APPROVAL_CONFIG_V1') 'Codex argument contract must be explicit'
Assert ($codex.legacy_approval_flag -eq 'ABSENT') 'removed --ask-for-approval flag must not be required'
Assert ($codex.provider_readiness -eq 'UNKNOWN_NOT_EXECUTED') 'CLI help compatibility must not claim provider readiness'

$badRefused=$false
try{& $script -Provider Codex -HelpFile $badFixture -ProviderVersion 'legacy-fixture' -FailOnIncompatible|Out-Null}catch{$badRefused=$_.Exception.Message -match 'PROVIDER_CLI_INCOMPATIBLE'}
Assert $badRefused 'incompatible Codex help must fail closed'

$gemini=& $script -Provider Gemini -Json|ConvertFrom-Json
Assert ($gemini.compatibility -eq 'UNKNOWN_PREREQUISITES' -and $gemini.provider_readiness -eq 'UNKNOWN_NOT_EXECUTED') 'Gemini install/login must not imply reviewer qualification'
Assert (($gemini.prerequisites -join '|') -match 'billing_or_free_tier_authority' -and ($gemini.prerequisites -join '|') -match 'seeded_review_competence') 'Gemini prerequisites must include authority and competence'

$hermes=& $script -Provider Hermes -Json|ConvertFrom-Json
Assert ($hermes.compatibility -eq 'UNKNOWN_PREREQUISITES' -and $hermes.provider_readiness -eq 'UNKNOWN_NOT_EXECUTED') 'Hermes must remain unqualified without pinned-client proof'
Assert (($hermes.prerequisites -join '|') -match 'pinned_0.20.5_provider_compatibility') 'Hermes pinned-version compatibility must be explicit'

$source=Get-Content -LiteralPath $script -Raw
Assert ($source -notmatch 'api[_-]?key|token\s*=|Invoke-RestMethod|Invoke-WebRequest') 'preflight must not read secrets or use network clients'
Write-Output 'PASS provider CLI preflight offline tests cases=4'
