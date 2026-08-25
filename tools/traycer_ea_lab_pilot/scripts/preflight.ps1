param([string]$Worktree=(Get-Location).Path,[string]$ExpectedHead)
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'TraycerPilot.psm1') -Force
$repo=Get-TraycerPilotRepoIdentity -Path $Worktree
if(-not $repo.clean){ throw 'Pilot worktree must be clean for preflight' }
if($ExpectedHead -and $repo.head -ne $ExpectedHead){ throw "HEAD mismatch expected=$ExpectedHead actual=$($repo.head)" }
$p=Get-TraycerPilotPreflight
[pscustomobject]@{repo=$repo;environment=$p} | ConvertTo-Json -Depth 8
