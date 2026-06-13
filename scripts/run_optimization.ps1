param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [ValidateSet("macro", "micro", "robustness")]
    [string]$Mode
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ProjectPath = Join-Path $Root "ea_projects\$Project"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFolder = Join-Path $ProjectPath "optimization\$Mode`_$Timestamp"
$LogFolder = Join-Path $ProjectPath "logs"

New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
New-Item -ItemType Directory -Force -Path $LogFolder | Out-Null

$MetadataFile = Join-Path $OutputFolder "job_metadata.txt"
$LogFile = Join-Path $LogFolder "optimization_$Mode`_$Timestamp.log"
$Metadata = [ordered]@{
    job_type = "optimization"
    project = $Project
    mode = $Mode
    output_folder = $OutputFolder
    created_at = (Get-Date).ToString("o")
    safety = "tester-only placeholder; no live trading execution"
}

$Lines = $Metadata.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }
$Lines | Set-Content -Path $MetadataFile -Encoding UTF8
$Lines | Set-Content -Path $LogFile -Encoding UTF8
"MT5 optimization command placeholder. No live trading executed." | Add-Content -Path $LogFile -Encoding UTF8

Write-Host "Optimization placeholder prepared."
Write-Host "Output folder: $OutputFolder"
Write-Host "Metadata file: $MetadataFile"
