param([string]$Release='1.2.0')
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'TraycerPilot.psm1') -Force
$i=Get-TraycerInstallation
if(-not $i.found -or -not (Test-Path $i.cli_path)){ throw 'Traycer CLI not installed' }
$statusRaw=& $i.cli_path --json --no-bootstrap host status
if($LASTEXITCODE -ne 0){ throw 'host status failed' }
$status=$statusRaw | Select-Object -Last 1 | ConvertFrom-Json
if($status.data.running -and $status.data.pidMetadata.version -eq $Release){ $statusRaw; exit 0 }
& $i.cli_path --json --no-bootstrap host install --release $Release
if($LASTEXITCODE -ne 0){ throw "host install failed exit=$LASTEXITCODE" }
& $i.cli_path --json --no-bootstrap host status
