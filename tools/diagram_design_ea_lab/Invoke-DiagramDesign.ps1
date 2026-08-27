param(
    [ValidateSet('Status','List','Prompt')][string]$Action = 'Status',
    [string]$Profile
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DiagramDesign.psm1') -Force

switch ($Action) {
    'Status' {
        Get-DiagramDesignStatus | ConvertTo-Json -Depth 8
    }
    'List' {
        $m = Get-DiagramWorkflowManifest
        $profiles = foreach ($p in $m.profiles.PSObject.Properties) {
            [pscustomobject]@{ profile=$p.Name; title=$p.Value.title; output=$p.Value.output; type=$p.Value.type }
        }
        $profiles | ConvertTo-Json -Depth 4
    }
    'Prompt' {
        if ([string]::IsNullOrWhiteSpace($Profile)) { throw '-Profile is required for Prompt' }
        New-DiagramDesignPrompt -Profile $Profile
    }
}
