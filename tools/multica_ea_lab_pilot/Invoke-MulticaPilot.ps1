[CmdletBinding()]
param(
    [ValidateSet('Status','Preflight','ValidateResource')][string]$Action='Status',
    [ValidateSet('github_repo','local_directory')][string]$ResourceType='github_repo',
    [string]$Location='https://github.com/BaBosss/EA_LAB',
    [string]$Ref=''
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'MulticaPilot.psm1') -Force
switch($Action){
    'Status' {
        [pscustomobject]@{
            policy=Get-MulticaPilotPolicy
            installation=Get-MulticaInstallation
            daemon=Get-MulticaDaemonState
        } | ConvertTo-Json -Depth 8
    }
    'Preflight' { Get-MulticaPilotPreflight | ConvertTo-Json -Depth 8 }
    'ValidateResource' { Assert-MulticaPilotResource -ResourceType $ResourceType -Location $Location -Ref $Ref | ConvertTo-Json -Depth 5 }
}
