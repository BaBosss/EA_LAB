param(
    [Parameter(Mandatory = $true)]
    [string]$Project
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ProjectPath = Join-Path $Root "ea_projects\$Project"
$LatestFolder = Join-Path $ProjectPath "reports\latest"
$HandoffFile = Join-Path $LatestFolder "handoff_package.txt"

New-Item -ItemType Directory -Force -Path $LatestFolder | Out-Null

$SearchFolders = @(
    (Join-Path $ProjectPath "backtest"),
    (Join-Path $ProjectPath "optimization"),
    (Join-Path $ProjectPath "reports"),
    (Join-Path $ProjectPath "set")
) | Where-Object { Test-Path $_ }

$Patterns = @("*.html", "*.htm", "*.csv", "*.set", "*.png", "*.jpg", "*.jpeg", "*.txt")
$Copied = New-Object System.Collections.Generic.List[string]

foreach ($Folder in $SearchFolders) {
    foreach ($Pattern in $Patterns) {
        Get-ChildItem -Path $Folder -Filter $Pattern -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                $Destination = Join-Path $LatestFolder $_.Name
                Copy-Item -Path $_.FullName -Destination $Destination -Force
                $Copied.Add($Destination)
            }
    }
}

$ExpectedFiles = @(
    "MT5 HTML report",
    "optimization CSV",
    "forward report if available",
    "equity curve CSV or screenshot",
    "final .set file",
    "run context"
)

$Lines = @()
$Lines += "EA LAB handoff package"
$Lines += "Project: $Project"
$Lines += "Created at: $((Get-Date).ToString('o'))"
$Lines += ""
$Lines += "Expected files:"
$ExpectedFiles | ForEach-Object { $Lines += "- $_" }
$Lines += ""
$Lines += "Copied files:"
if ($Copied.Count -eq 0) {
    $Lines += "- None found"
} else {
    $Copied | ForEach-Object { $Lines += "- $_" }
}
$Lines += ""
$Lines += "Safety: export only. No live trading, deployment, or account changes."

$Lines | Set-Content -Path $HandoffFile -Encoding UTF8

Write-Host "Reports exported to: $LatestFolder"
Write-Host "Handoff package: $HandoffFile"
