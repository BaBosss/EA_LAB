param([Parameter(Mandatory)][string]$EvidencePath)
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'TraycerPilot.psm1') -Force
$result=Test-TraycerAuthenticatedA2AEvidence -EvidencePath $EvidencePath
$result | ConvertTo-Json -Depth 4
if($result.status -ne 'CAGE_READY'){ exit 1 }
