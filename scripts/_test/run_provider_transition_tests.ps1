$ErrorActionPreference='Stop'
try {
  $repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  $validatorPath=Join-Path $repoRoot 'tools\hermes_ea_lab_pilot\scripts\validate_profiles.ps1'
  $manifestPath=Join-Path $repoRoot 'tools\hermes_ea_lab_pilot\profile_manifest.json'
  $tokens=$null; $parseErrors=$null
  $ast=[System.Management.Automation.Language.Parser]::ParseFile($validatorPath,[ref]$tokens,[ref]$parseErrors)
  if($parseErrors.Count){throw "validate_profiles.ps1 parse errors: $($parseErrors -join '; ')"}
  $functions=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-HermesProfileProvider'},$true))
  if($functions.Count -ne 1){throw "Expected one Test-HermesProfileProvider; found $($functions.Count)"}
  . ([scriptblock]::Create($functions[0].Extent.Text))
  $cases=@(
    @{N='canonical anthropic';T="model:`n  default: anthropic/claude-sonnet-4.6`n  provider: anthropic`n";P='anthropic';W=$true},
    @{N='plain';T="model:`n  provider: openai-codex`n";P='openai-codex';W=$true},
    @{N='single quoted';T="model:`n  provider: 'openai-codex'`n";P='openai-codex';W=$true},
    @{N='double quoted';T="model:`n  provider: `"openai-codex`"`n";P='openai-codex';W=$true},
    @{N='CRLF comments';T="model: # comment`r`n`r`n# col0 comment`r`n  # child comment`r`n  default: gpt-5.6-sol # pin`r`n  provider: openai-codex # auth`r`nterminal:`r`n  cwd: .`r`n";P='openai-codex';W=$true},
    @{N='real top-level boundary';T="model:`n  provider: openai-codex`nterminal:`n  provider: anthropic`n";P='openai-codex';W=$true},
    @{N='wrong';T="model:`n  provider: anthropic`n";P='openai-codex';W=$false},
    @{N='missing';T="model:`n  default: gpt-5.6-sol`n";P='openai-codex';W=$false},
    @{N='prefix';T="model:`n  provider: x-openai-codex`n";P='openai-codex';W=$false},
    @{N='suffix';T="model:`n  provider: openai-codex-extra`n";P='openai-codex';W=$false},
    @{N='duplicate provider';T="model:`n  provider: openai-codex`n  provider: openai-codex`n";P='openai-codex';W=$false},
    @{N='duplicate across col0 comment';T="model:`n  provider: openai-codex`n# comment does not terminate model`n  provider: anthropic`n";P='openai-codex';W=$false},
    @{N='duplicate model';T="model:`n  provider: openai-codex`nmodel:`n  provider: openai-codex`n";P='openai-codex';W=$false},
    @{N='quoted model';T="'model':`n  provider: openai-codex`n";P='openai-codex';W=$false},
    @{N='quoted duplicate model';T="model:`n  provider: openai-codex`n`"model`":`n  provider: openai-codex`n";P='openai-codex';W=$false}
  )
  $cases += @(
    @{N='quoted provider key';T="model:`n  'provider': openai-codex`n";P='openai-codex';W=$false},
    @{N='spaced model key';T="model :`n  provider: openai-codex`n";P='openai-codex';W=$false},
    @{N='spaced provider key';T="model:`n  provider : openai-codex`n";P='openai-codex';W=$false},
    @{N='inline model';T="model: {provider: openai-codex}`n";P='openai-codex';W=$false},
    @{N='model alias';T="model: *chosen`n";P='openai-codex';W=$false},
    @{N='model anchor';T="model: &chosen`n  provider: openai-codex`n";P='openai-codex';W=$false},
    @{N='provider alias';T="model:`n  provider: *chosen`n";P='openai-codex';W=$false},
    @{N='merge';T="defaults: &d`n  provider: openai-codex`nmodel:`n  <<: *d`n";P='openai-codex';W=$false},
    @{N='nested';T="model:`n  options:`n    provider: openai-codex`n";P='openai-codex';W=$false},
    @{N='tab child';T="model:`n`tprovider: openai-codex`n";P='openai-codex';W=$false},
    @{N='outside provider';T="provider: openai-codex`nmodel:`n  default: gpt-5.6-sol`n";P='openai-codex';W=$false},
    @{N='unrelated provider';T="transport:`n  provider: openai-codex`nmodel:`n  default: gpt-5.6-sol`n";P='openai-codex';W=$false},
    @{N='empty expected';T="model:`n  provider: openai-codex`n";P='';W=$false},
    @{N='comment only provider';T="model:`n  # provider: openai-codex`n  default: gpt-5.6-sol`n";P='openai-codex';W=$false},
    @{N='provider after boundary cannot satisfy model';T="model:`n  default: gpt-5.6-sol`nterminal:`n  provider: openai-codex`n";P='openai-codex';W=$false}
  )
  foreach($c in $cases){
    $got=Test-HermesProfileProvider -ConfigText $c.T -ExpectedProvider $c.P
    if($got -isnot [bool]){throw "case $($c.N) returned non-bool"}
    if($got -ne $c.W){throw "case $($c.N) expected $($c.W) got $got"}
  }
  $m=Get-Content -Raw $manifestPath | ConvertFrom-Json
  if($m.hermes_version -cne '0.20.5' -or $m.hermes_tag -cne 'v2026.8.19' -or $m.hermes_commit -cne 'fcbd1076a93841fa88855acce810e342a5b78101'){throw 'Hermes pin changed'}
  if($m.default_model -cne 'anthropic/claude-sonnet-4.6' -or $m.default_provider -cne 'anthropic'){throw 'active Hermes defaults changed'}
  if($m.provider_transition.target_model -cne 'gpt-5.6-sol' -or $m.provider_transition.target_provider -cne 'openai-codex' -or $m.provider_transition.target_kind -cne 'INERT_METADATA_NOT_ACTIVE_DEFAULTS'){throw 'inert provider target changed'}
  if($m.provider_transition.persistent_profiles_applied -ne $false -or $m.provider_transition.runtime_live_pass -ne $false){throw 'persistent/runtime provider state changed'}
  Write-Host "PASS provider transition fixtures: $($cases.Count) cases; active Anthropic defaults + inert GPT target unchanged."
  exit 0
}catch{Write-Error $_; exit 1}
