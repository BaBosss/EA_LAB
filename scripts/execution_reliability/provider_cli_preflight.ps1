<#
Offline provider CLI surface check. It parses supplied help text only and never
tests authentication, makes a model request, or establishes reviewer competence.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Codex','Gemini','Hermes')][string]$Provider,
    [string]$HelpFile='',
    [string]$HelpText='',
    [string]$ProviderVersion='UNKNOWN',
    [switch]$FailOnIncompatible,
    [switch]$Json
)
$ErrorActionPreference='Stop'

if($HelpFile -and $HelpText){throw 'PROVIDER_PREFLIGHT_REFUSE: choose HelpFile or HelpText, not both'}
if($HelpFile){
    if(-not [IO.Path]::IsPathRooted($HelpFile)){throw 'PROVIDER_PREFLIGHT_REFUSE: HelpFile must be absolute'}
    $resolved=[IO.Path]::GetFullPath($HelpFile)
    if(-not(Test-Path -LiteralPath $resolved -PathType Leaf)){throw "PROVIDER_PREFLIGHT_REFUSE: HelpFile missing: $resolved"}
    $HelpText=Get-Content -LiteralPath $resolved -Raw -Encoding UTF8
}

$result=[ordered]@{
    schema_version='EA_LAB_PROVIDER_CLI_PREFLIGHT_V1'
    provider=$Provider
    provider_version=$ProviderVersion
    compatibility='UNKNOWN_PREREQUISITES'
    provider_readiness='UNKNOWN_NOT_EXECUTED'
    argument_contract='NONE'
    legacy_approval_flag='NOT_APPLICABLE'
    missing_help_tokens=@()
    prerequisites=@()
    limits=@('OFFLINE_HELP_SURFACE_ONLY','NO_AUTH_INFERENCE','NO_MODEL_REQUEST','NO_REVIEWER_COMPETENCE_CLAIM')
}

if($Provider -eq 'Codex'){
    if([string]::IsNullOrWhiteSpace($HelpText)){throw 'PROVIDER_PREFLIGHT_REFUSE: Codex help text is required'}
    $checks=[ordered]@{
        usage='(?m)Usage:\s+codex\s+exec'
        config='--config\s+<key=value>'
        sandbox='--sandbox\s+<SANDBOX_MODE>'
        read_only='\bread-only\b'
        workspace_write='\bworkspace-write\b'
        cd='--cd\s+<DIR>'
        model='--model\s+<MODEL>'
    }
    $missing=@($checks.GetEnumerator()|Where-Object{$HelpText -notmatch $_.Value}|ForEach-Object{$_.Key})
    $result.missing_help_tokens=$missing
    $result.legacy_approval_flag=if($HelpText -match '--ask-for-approval'){'PRESENT'}else{'ABSENT'}
    $result.argument_contract='CODEX_EXEC_TRANSIENT_APPROVAL_CONFIG_V1'
    $result.prerequisites=@('authenticated_client_surface','task_scoped_model_resolution','bounded_no_mutation_smoke','requested_and_resolved_model_capture')
    if($missing.Count -eq 0){$result.compatibility='COMPATIBLE'}else{$result.compatibility='INCOMPATIBLE'}
}elseif($Provider -eq 'Gemini'){
    $result.prerequisites=@('billing_or_free_tier_authority','exact_head_read_only_fixture','seeded_review_competence','write_and_scope_refusal','independent_grader','requested_and_resolved_model_capture')
}else{
    $result.prerequisites=@('pinned_0.20.5_provider_compatibility','task_scoped_override_only','preserved_SOUL_and_MCP_manifests','accepted_no_MT5_boundary_replay','tool_refusal_and_provenance_capture')
}

if($FailOnIncompatible -and $result.compatibility -ne 'COMPATIBLE'){
    throw ('PROVIDER_CLI_INCOMPATIBLE: provider='+$Provider+' compatibility='+$result.compatibility+' missing='+($result.missing_help_tokens -join ','))
}
$object=[pscustomobject]$result
if($Json){$object|ConvertTo-Json -Depth 6}else{$object}
