param([string]$Root='D:\EA_LAB_CONTROL\traycer-pilot\cages',[string]$Name=('cage-'+(Get-Date -Format yyyyMMdd-HHmmss)))
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'TraycerPilot.psm1') -Force
New-TraycerPilotCage -Root $Root -Name $Name | ConvertTo-Json -Depth 5
