Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ModuleRoot = $PSScriptRoot
$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-DiagramModuleConfig {
    $path = Join-Path $script:ModuleRoot 'module.json'
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-DiagramWorkflowManifest {
    $path = Join-Path $script:ModuleRoot 'workflow_manifest.json'
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Resolve-HomePath {
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -eq '~') { return $env:USERPROFILE }
    if ($Path.StartsWith('~/')) { return Join-Path $env:USERPROFILE $Path.Substring(2) }
    return $Path
}

function Get-DiagramDesignStatus {
    $config = Get-DiagramModuleConfig
    $clone = Resolve-HomePath $config.install.clone_path
    $hub = Resolve-HomePath $config.install.hub_skill_path
    $consumers = @()
    $hubSkill = Join-Path $hub 'SKILL.md'
    $hubHash = if (Test-Path -LiteralPath $hubSkill) { (Get-FileHash -LiteralPath $hubSkill -Algorithm SHA256).Hash } else { $null }
    foreach ($raw in $config.install.consumer_skill_paths) {
        $path = Resolve-HomePath $raw
        $skill = Join-Path $path 'SKILL.md'
        $hash = if (Test-Path -LiteralPath $skill) { (Get-FileHash -LiteralPath $skill -Algorithm SHA256).Hash } else { $null }
        $consumers += [pscustomobject]@{ path=$path; present=(Test-Path -LiteralPath $path); skill_hash=$hash; hash_matches_hub=if ($null -ne $hubHash -and $null -ne $hash) { $hash -eq $hubHash } else { $null } }
    }
    $head = $null
    if (Test-Path -LiteralPath (Join-Path $clone '.git')) {
        $head = (& git -C $clone rev-parse HEAD 2>$null | Select-Object -First 1)
    }
    [pscustomobject]@{
        upstream_commit = $config.upstream.commit
        clone_path = $clone
        clone_present = (Test-Path -LiteralPath $clone)
        clone_head = $head
        clone_pinned = if ($null -ne $head) { $head -eq $config.upstream.commit } else { $null }
        hub_skill_path = $hub
        hub_present = (Test-Path -LiteralPath $hub)
        hub_skill_hash = $hubHash
        consumers = $consumers
        all_available_links_match = if ($null -ne $hubHash) { @($consumers | Where-Object { $null -ne $_.hash_matches_hub -and -not $_.hash_matches_hub }).Count -eq 0 } else { $null }
        authority = $config.authority.mode
    }
}

function Get-DiagramWorkflowProfile {
    param([Parameter(Mandatory)][string]$Name)
    $manifest = Get-DiagramWorkflowManifest
    $prop = $manifest.profiles.PSObject.Properties[$Name]
    if ($null -eq $prop) { throw "Unknown diagram profile: $Name" }
    return $prop.Value
}

function New-DiagramDesignPrompt {
    param([Parameter(Mandatory)][string]$Profile)
    $p = Get-DiagramWorkflowProfile -Name $Profile
    $payload = $p | ConvertTo-Json -Depth 8 -Compress
    return @"
Use the installed diagram-design skill plus the EA wrapper skill ea-workflow-diagrams.
Create/update profile '$Profile': $($p.title).
Target: $($p.output)
Manifest payload: $payload
Read current repository sources before drawing; do not infer missing state.
Output must be self-contained offline HTML and show VISUAL_ONLY_NO_AUTHORITY plus provenance.
"@
}
Export-ModuleMember -Function Get-DiagramModuleConfig,Get-DiagramWorkflowManifest,Get-DiagramDesignStatus,Get-DiagramWorkflowProfile,New-DiagramDesignPrompt
