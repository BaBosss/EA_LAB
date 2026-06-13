param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [ValidateSet("baseline", "risk_cap_validation", "optimization", "oos")]
    [string]$RunType,

    [string]$SourceFolder = "",
    [string]$ReportPath = "",
    [string]$SetPath = "",
    [string]$Symbol = "",
    [string]$Timeframe = "",
    [string]$Notes = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function ConvertTo-YamlScalar {
    param([object]$Value)

    if ($null -eq $Value) {
        return '""'
    }
    if ($Value -is [bool]) {
        return $Value.ToString().ToLowerInvariant()
    }

    $text = [string]$Value
    $escaped = $text.Replace('\', '\\').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function Write-SimpleYaml {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Data,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($key in $Data.Keys) {
        $lines.Add("$key`: $(ConvertTo-YamlScalar $Data[$key])")
    }
    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Read-SimpleConfig {
    param([string]$Path)

    $config = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $config
    }

    $currentKey = ""
    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.TrimEnd()
        if (-not $line.Trim() -or $line.TrimStart().StartsWith("#")) {
            continue
        }

        if ($line -match '^([A-Za-z0-9_]+):\s*(.*)$') {
            $currentKey = $matches[1]
            $value = $matches[2].Trim()
            if ($value -eq "") {
                $config[$currentKey] = New-Object System.Collections.Generic.List[string]
            }
            else {
                $config[$currentKey] = $value.Trim('"')
            }
            continue
        }

        if ($currentKey -and $line.TrimStart() -match '^-\s*(.*)$') {
            if (-not ($config[$currentKey] -is [System.Collections.Generic.List[string]])) {
                $config[$currentKey] = New-Object System.Collections.Generic.List[string]
            }
            $config[$currentKey].Add($matches[1].Trim().Trim('"'))
        }
    }

    return $config
}

function Add-ExistingFolder {
    param(
        [System.Collections.Generic.List[string]]$Folders,
        [string]$Path
    )

    if ($Path -and (Test-Path -LiteralPath $Path -PathType Container)) {
        $resolved = (Resolve-Path -LiteralPath $Path).Path
        if (-not $Folders.Contains($resolved)) {
            $Folders.Add($resolved)
        }
    }
}

function Get-UniqueDestinationPath {
    param(
        [string]$DestinationFolder,
        [string]$FileName
    )

    $target = Join-Path $DestinationFolder $FileName
    if (-not (Test-Path -LiteralPath $target)) {
        return $target
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext = [System.IO.Path]::GetExtension($FileName)
    $candidate = Join-Path $DestinationFolder "$base`_$stamp$ext"
    $i = 2
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $DestinationFolder "$base`_$stamp`_$i$ext"
        $i++
    }
    return $candidate
}

function Copy-CollectedFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder
    )

    $name = Split-Path -Leaf $Source
    $dest = Get-UniqueDestinationPath -DestinationFolder $DestinationFolder -FileName $name
    Copy-Item -LiteralPath $Source -Destination $dest
    return $dest
}

$Root = Split-Path -Parent $PSScriptRoot
$ConfigPath = Join-Path $PSScriptRoot "config.yaml"
$Config = Read-SimpleConfig -Path $ConfigPath

$ProjectPath = Join-Path $Root "ea_projects\$Project"
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    throw "Project not found: $ProjectPath"
}

switch ($RunType) {
    { $_ -in @("baseline", "risk_cap_validation") } {
        $DestinationRoot = Join-Path $ProjectPath "backtest\manual_runs"
        break
    }
    "optimization" {
        $DestinationRoot = Join-Path $ProjectPath "optimization\raw_results"
        break
    }
    "oos" {
        $DestinationRoot = Join-Path $ProjectPath "optimization\oos"
        break
    }
}

$RunFolder = Join-Path $DestinationRoot $RunId
if ((Test-Path -LiteralPath $RunFolder) -and -not $Force) {
    throw "Run folder already exists. Re-run with -Force to add files safely: $RunFolder"
}
New-Item -ItemType Directory -Force -Path $RunFolder | Out-Null

$CandidateFolders = New-Object System.Collections.Generic.List[string]
Add-ExistingFolder -Folders $CandidateFolders -Path $SourceFolder
if ($ReportPath) {
    Add-ExistingFolder -Folders $CandidateFolders -Path (Split-Path -Parent $ReportPath)
}
if ($SetPath) {
    Add-ExistingFolder -Folders $CandidateFolders -Path (Split-Path -Parent $SetPath)
}
Add-ExistingFolder -Folders $CandidateFolders -Path (Join-Path $ProjectPath "reports\latest")

if ($Config.ContainsKey("mt5_roaming_data_path")) {
    $mt5Data = [string]$Config["mt5_roaming_data_path"]
    Add-ExistingFolder -Folders $CandidateFolders -Path (Join-Path $mt5Data "Tester")
    Add-ExistingFolder -Folders $CandidateFolders -Path (Join-Path $mt5Data "Tester\Reports")
    Add-ExistingFolder -Folders $CandidateFolders -Path (Join-Path $mt5Data "Tester\Agent-127.0.0.1-3000\logs")
    Add-ExistingFolder -Folders $CandidateFolders -Path (Join-Path $mt5Data "logs")
}
if ($Config.ContainsKey("mt5_tester_report_paths")) {
    foreach ($path in @($Config["mt5_tester_report_paths"])) {
        Add-ExistingFolder -Folders $CandidateFolders -Path $path
    }
}
if ($Config.ContainsKey("mt5_common_files_path")) {
    Add-ExistingFolder -Folders $CandidateFolders -Path ([string]$Config["mt5_common_files_path"])
}

$Patterns = @(
    "*.html",
    "*.htm",
    "*.xml",
    "*.csv",
    "*.png",
    "*.gif",
    "*.set",
    "*.log",
    "risk_cap_summary.txt",
    "risk_cap_diagnostics.csv",
    "testergraph*.csv",
    "ReportTester*.html"
)

$CandidatesByPath = @{}
foreach ($folder in $CandidateFolders) {
    foreach ($pattern in $Patterns) {
        foreach ($file in Get-ChildItem -LiteralPath $folder -Filter $pattern -File -ErrorAction SilentlyContinue) {
            $CandidatesByPath[$file.FullName] = $file
        }
    }
}

if ($ReportPath -and (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    $CandidatesByPath[(Resolve-Path -LiteralPath $ReportPath).Path] = Get-Item -LiteralPath $ReportPath
}
if ($SetPath -and (Test-Path -LiteralPath $SetPath -PathType Leaf)) {
    $CandidatesByPath[(Resolve-Path -LiteralPath $SetPath).Path] = Get-Item -LiteralPath $SetPath
}

$Candidates = @($CandidatesByPath.Values | Sort-Object LastWriteTime -Descending)
$Copied = New-Object System.Collections.Generic.List[string]
$Missing = New-Object System.Collections.Generic.List[string]
foreach ($candidate in $Candidates) {
    try {
        $dest = Copy-CollectedFile -Source $candidate.FullName -DestinationFolder $RunFolder
        $Copied.Add("$($candidate.FullName) -> $dest")
    }
    catch {
        $Missing.Add("$($candidate.FullName): $($_.Exception.Message)")
    }
}

$MainReport = $Candidates |
    Where-Object { $_.Extension -match '^\.html?$' -and $_.Name -match 'ReportTester|report|tester' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $MainReport) {
    $MainReport = $Candidates | Where-Object { $_.Extension -match '^\.html?$' } | Select-Object -First 1
}

$TesterGraph = $Candidates |
    Where-Object { $_.Name -like "testergraph*.csv" -or $_.Name -match 'testergraph|graph' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$SetFile = $Candidates |
    Where-Object { $_.Extension -eq ".set" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$Diagnostics = $Candidates |
    Where-Object { $_.Name -in @("risk_cap_summary.txt", "risk_cap_diagnostics.csv") } |
    Sort-Object Name

$RunContext = [ordered]@{
    project = $Project
    run_id = $RunId
    run_type = $RunType
    symbol = $Symbol
    timeframe = $Timeframe
    source_mode = "manual_mt5_import"
    tester_profit_valid = "unknown"
    notes = $Notes
}
Write-SimpleYaml -Data $RunContext -Path (Join-Path $RunFolder "run_context.yaml")

$Summary = New-Object System.Collections.Generic.List[string]
$Summary.Add("AUTO_MT5_REPORT_COLLECTOR")
$Summary.Add("timestamp: $((Get-Date).ToString('o'))")
$Summary.Add("project: $Project")
$Summary.Add("run_id: $RunId")
$Summary.Add("run_type: $RunType")
$Summary.Add("run_folder: $RunFolder")
$Summary.Add("")
$Summary.Add("source_folders_scanned:")
foreach ($folder in $CandidateFolders) {
    $Summary.Add("  - $folder")
}
$Summary.Add("")
$Summary.Add("files_copied:")
if ($Copied.Count -gt 0) {
    foreach ($line in $Copied) { $Summary.Add("  - $line") }
}
else {
    $Summary.Add("  - NONE")
}
$Summary.Add("")
$Summary.Add("files_missing_or_failed:")
if ($Missing.Count -gt 0) {
    foreach ($line in $Missing) { $Summary.Add("  - $line") }
}
else {
    $Summary.Add("  - NONE")
}
$Summary.Add("")
$Summary.Add("suspected_main_report: $(if ($MainReport) { $MainReport.FullName } else { 'MISSING' })")
$Summary.Add("suspected_testergraph: $(if ($TesterGraph) { $TesterGraph.FullName } else { 'MISSING' })")
$Summary.Add("suspected_set_file: $(if ($SetFile) { $SetFile.FullName } else { 'MISSING' })")
$Summary.Add("diagnostics_found: $(if ($Diagnostics.Count -gt 0) { ($Diagnostics.Name -join ', ') } else { 'NONE' })")
if (-not $MainReport) {
    $Summary.Add("warning: no report file was found; import folder was created for traceability.")
}
$Summary.Add("")
$Summary.Add("next_suggested_command:")
if ($RunType -eq "optimization") {
    $Summary.Add("  Analyze optimization raw results under: $RunFolder")
}
elseif ($RunType -eq "oos") {
    $Summary.Add("  Run OOS analyzer on: $RunFolder")
}
else {
    $Summary.Add("  Run backtest-report-analyzer on: $RunFolder")
}
$Summary | Set-Content -LiteralPath (Join-Path $RunFolder "import_summary.txt") -Encoding UTF8

Write-Host "MT5 report collection complete."
Write-Host "Run folder: $RunFolder"
Write-Host "Files copied: $($Copied.Count)"
Write-Host "Main report: $(if ($MainReport) { $MainReport.FullName } else { 'MISSING' })"
Write-Host "Summary: $(Join-Path $RunFolder 'import_summary.txt')"
