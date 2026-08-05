param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$Symbol,

    [Parameter(Mandatory = $true)]
    [string]$Timeframe,

    [string]$SetFilePath = "",
    [string]$ExpertName = "",
    [string]$FromDate = "2025.01.01",
    # ORDER-238: was 2026.05.29, i.e. five months inside the 2026H1 holdout. As a
    # DEFAULT it spent the holdout for anyone who invoked this without dates, and
    # nothing said so. Pinned to the MAIN end instead; check_state.ps1 section 9
    # now covers this file and will fail loudly if it drifts past MAIN again.
    [string]$ToDate = "2025.12.31",
    [double]$Deposit = 10000,
    [switch]$DebugVisible,
    [switch]$Portable,
    [switch]$NoPortable,
    [switch]$NoShutdown
)

$ErrorActionPreference = "Stop"

function Read-SimpleYaml {
    param([string]$Path)

    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $values
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*#' -or $line -notmatch '^\s*([A-Za-z0-9_]+)\s*:\s*(.*)\s*$') {
            continue
        }

        $key = $Matches[1]
        $value = $Matches[2].Trim()
        $commentIndex = $value.IndexOf(" #")
        if ($commentIndex -ge 0) {
            $value = $value.Substring(0, $commentIndex).Trim()
        }
        $value = $value.Trim('"').Trim("'")
        $values[$key] = $value
    }

    return $values
}

function Convert-Timeframe {
    param([string]$Value)

    $normalized = $Value.Trim().ToUpperInvariant()
    switch ($normalized) {
        "M1" { return "M1" }
        "M5" { return "M5" }
        "M15" { return "M15" }
        "M30" { return "M30" }
        "H1" { return "H1" }
        "H4" { return "H4" }
        "D1" { return "D1" }
        default { throw "Unsupported timeframe '$Value'." }
    }
}

function Resolve-TerminalPath {
    param([hashtable]$Config)

    if ($Config.ContainsKey("mt5_terminal_path") -and $Config["mt5_terminal_path"]) {
        return $Config["mt5_terminal_path"]
    }

    $localDefault = "D:\Meta 5\terminal64.exe"
    if (Test-Path -LiteralPath $localDefault) {
        return $localDefault
    }

    return "C:\Program Files\MetaTrader 5\terminal64.exe"
}

function Get-SetInputs {
    param([string]$Path)

    $inputLines = New-Object System.Collections.Generic.List[string]
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return $inputLines
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith(";") -or $trimmed.StartsWith("#")) {
            continue
        }
        $inputLines.Add($trimmed)
    }

    return $inputLines
}

$Root = Split-Path -Parent $PSScriptRoot
$ProjectPath = Join-Path $Root "ea_projects\$Project"
if (-not (Test-Path -LiteralPath $ProjectPath)) {
    throw "Project not found: $ProjectPath"
}

$ConfigPath = Join-Path $PSScriptRoot "config.yaml"
$Config = Read-SimpleYaml -Path $ConfigPath
$TerminalPath = Resolve-TerminalPath -Config $Config
$ConfiguredDataPath = if ($Config.ContainsKey("mt5_data_path")) { $Config["mt5_data_path"] } else { "" }
$UsePortable = $Portable.IsPresent -and -not $NoPortable.IsPresent

if (-not (Test-Path -LiteralPath $TerminalPath)) {
    throw "MT5 terminal not found: $TerminalPath"
}

$ExistingTerminals = @(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {
    try {
        [string]::Equals($_.Path, $TerminalPath, [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        $false
    }
})

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputFolder = Join-Path $ProjectPath "backtest\$Timestamp"
$LogFolder = Join-Path $ProjectPath "logs"
New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null
New-Item -ItemType Directory -Force -Path $LogFolder | Out-Null

$ResolvedTimeframe = Convert-Timeframe -Value $Timeframe
if (-not $ExpertName) {
    $ExpertName = "$Project.ex5"
}

$ReportPath = Join-Path $OutputFolder "${Project}_${Symbol}_${ResolvedTimeframe}_report.html"
$TesterConfigPath = Join-Path $OutputFolder "tester_config.ini"
$LogFile = Join-Path $LogFolder "backtest_$Timestamp.log"
$ShutdownValue = if ($NoShutdown.IsPresent -or $DebugVisible.IsPresent) { "0" } else { "1" }
$VisualValue = if ($DebugVisible.IsPresent) { "1" } else { "0" }
# ORDER-1268: the THIRD launcher, found while wiring the other two, and the worst of the three.
# `Get-SetInputs` above returns an EMPTY LIST when the path is missing or unreadable and says
# nothing at all -- so a typo in -SetFilePath produced a run configured entirely from the
# per-terminal tester cache, with no warning anywhere in the output. Same library, same policy:
# REFUSE what can be shown false, RECORD what merely cannot be verified.
. (Join-Path $PSScriptRoot 'lib\setfile_surface.ps1')
$surface = Get-SetSurfaceState -Path $SetFilePath
if ($surface.Refuse) {
    Write-Host "ABORT: $($surface.Message)" -ForegroundColor Red
    exit 2
}
Write-Host "surface: $($surface.State) -- $($surface.Message)"
$SetInputs = Get-SetInputs -Path $SetFilePath

$ini = New-Object System.Collections.Generic.List[string]
$ini.Add("; Generated by EA_LAB scripts/run_backtest.ps1")
$ini.Add("; Broker/server/account fields are informational only and are not pass/fail criteria.")
$ini.Add("; No Currency, DepositCurrency, AccountCurrency, or Leverage override is emitted.")
$ini.Add("[Tester]")
$ini.Add("Expert=$ExpertName")
$ini.Add("Symbol=$Symbol")
$ini.Add("Period=$ResolvedTimeframe")
$ini.Add("Optimization=0")
$ini.Add("OptimizationCriterion=0")
$ini.Add("Model=1")
$ini.Add("ExecutionMode=1")
$ini.Add("FromDate=$FromDate")
$ini.Add("ToDate=$ToDate")
$ini.Add("ForwardMode=0")
$ini.Add("Deposit=$Deposit")
$ini.Add("ProfitInPips=0")
$ini.Add("Visual=$VisualValue")
$ini.Add("Report=$ReportPath")
$ini.Add("ReplaceReport=1")
if ($ShutdownValue -eq "1") {
    $ini.Add("ShutdownTerminal=1")
}

if ($SetInputs.Count -gt 0) {
    $ini.Add("")
    $ini.Add("[TesterInputs]")
    foreach ($inputLine in $SetInputs) {
        $ini.Add($inputLine)
    }
}

$ini | Set-Content -LiteralPath $TesterConfigPath -Encoding ASCII

$argsList = New-Object System.Collections.Generic.List[string]
if ($UsePortable) {
    $argsList.Add("/portable")
}
$argsList.Add("/config:$TesterConfigPath")

$CommandLine = '"' + $TerminalPath + '" ' + (($argsList | ForEach-Object {
    if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
}) -join " ")

$Metadata = [ordered]@{
    job_type = "backtest"
    project = $Project
    symbol = $Symbol
    timeframe = $ResolvedTimeframe
    expert_name = $ExpertName
    set_file_path = $SetFilePath
    output_folder = $OutputFolder
    tester_config_path = $TesterConfigPath
    mt5_terminal_path = $TerminalPath
    mt5_data_path_configured = $ConfiguredDataPath
    portable_mode = $UsePortable
    debug_visible = $DebugVisible.IsPresent
    no_shutdown = ($NoShutdown.IsPresent -or $DebugVisible.IsPresent)
    existing_terminal_processes = (($ExistingTerminals | ForEach-Object { "$($_.Id):$($_.Path)" }) -join "; ")
    exact_command = $CommandLine
    created_at = (Get-Date).ToString("o")
    environment_policy = "broker-agnostic; broker/server/account are context only"
    fail_condition = "ENVIRONMENT_ACCOUNTING_FAIL only when closed deals exist, open/close prices differ, DEAL_PROFIT is zero for all or nearly all closed deals, and final balance/equity does not change"
}

$Metadata.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" } | Set-Content -Path $LogFile -Encoding UTF8
"--- tester_config.ini ---" | Add-Content -Path $LogFile -Encoding UTF8
Get-Content -LiteralPath $TesterConfigPath | Add-Content -Path $LogFile -Encoding UTF8

Write-Host "EA_LAB backtest launch prepared."
Write-Host "mt5_terminal_path: $TerminalPath"
Write-Host "mt5_data_path_configured: $ConfiguredDataPath"
Write-Host "portable_mode: $UsePortable"
Write-Host "debug_visible: $($DebugVisible.IsPresent)"
Write-Host "no_shutdown: $($NoShutdown.IsPresent -or $DebugVisible.IsPresent)"
if ($ExistingTerminals.Count -gt 0) {
    Write-Host "existing_terminal_processes: $($ExistingTerminals.Count)"
    $ExistingTerminals | ForEach-Object { Write-Host "  PID $($_.Id): $($_.Path)" }
    Write-Host "warning: MT5 may ignore /config when the same terminal context is already running."
}
Write-Host "tester_config: $TesterConfigPath"
Write-Host "exact_command: $CommandLine"
Write-Host ""
Write-Host "Final tester config:"
Get-Content -LiteralPath $TesterConfigPath | ForEach-Object { Write-Host $_ }

if ($DebugVisible.IsPresent) {
    $process = Start-Process -FilePath $TerminalPath -ArgumentList $argsList -PassThru -WindowStyle Normal
    "started_process_id: $($process.Id)" | Add-Content -Path $LogFile -Encoding UTF8
    Start-Sleep -Seconds 2
    $hasExited = $false
    try {
        $process.Refresh()
        $hasExited = $process.HasExited
    }
    catch {
        $hasExited = $true
    }
    "started_process_exited_after_2s: $hasExited" | Add-Content -Path $LogFile -Encoding UTF8
    Write-Host ""
    if ($hasExited) {
        Write-Host "DebugVisible launch process exited quickly. If an MT5 window was already open, /config was likely handed off or ignored by that existing instance."
    }
    else {
        Write-Host "DebugVisible mode started MT5 and left it open. Compare this window/profile with your normal manual tester environment."
    }
    Write-Host "process_id: $($process.Id)"
    Write-Host "log_file: $LogFile"
    exit 0
}

$process = Start-Process -FilePath $TerminalPath -ArgumentList $argsList -PassThru -Wait -WindowStyle Hidden
"exit_code: $($process.ExitCode)" | Add-Content -Path $LogFile -Encoding UTF8
Write-Host "MT5 process finished."
Write-Host "exit_code: $($process.ExitCode)"
Write-Host "log_file: $LogFile"
