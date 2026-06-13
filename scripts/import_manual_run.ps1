param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [string]$TradeListPath = "",
    [string]$SetPath = "",

    [Parameter(Mandatory = $true)]
    [string]$Symbol,

    [Parameter(Mandatory = $true)]
    [string]$Timeframe,

    [Parameter(Mandatory = $true)]
    [string]$StartDate,

    [Parameter(Mandatory = $true)]
    [string]$EndDate,

    [string]$BrokerServer = "",
    [string]$AccountCurrency = "",
    [string]$Notes = ""
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

    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return [string]$Value
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

function Get-Number {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $text = ([string]$Value).Trim()
    if (-not $text) {
        return $null
    }

    $clean = $text -replace '[,\s]', ''
    $clean = $clean -replace '[^\d\.\-\+]', ''
    $number = 0.0
    if ([double]::TryParse($clean, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return $number
    }

    return $null
}

function Find-Column {
    param(
        [string[]]$Columns,
        [string[]]$Names
    )

    foreach ($wanted in $Names) {
        foreach ($column in $Columns) {
            $normalized = ($column -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
            $wantedNormalized = ($wanted -replace '[^A-Za-z0-9]', '').ToLowerInvariant()
            if ($normalized -eq $wantedNormalized) {
                return $column
            }
        }
    }

    return $null
}

function Test-TradeListAccounting {
    param([string]$Path)

    $result = [ordered]@{
        trade_list_present = $false
        rows = 0
        profit_column = ""
        balance_column = ""
        nonzero_profit_rows = 0
        balance_changed = $false
        closed_trade_pl_exists = $false
        reliable = $false
        note = ""
    }

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        $result.note = "No trade_list.csv supplied."
        return $result
    }

    $result.trade_list_present = $true
    try {
        $rows = @(Import-Csv -LiteralPath $Path)
    }
    catch {
        $result.note = "Could not parse trade list as CSV: $($_.Exception.Message)"
        return $result
    }

    $result.rows = $rows.Count
    if ($rows.Count -eq 0) {
        $result.note = "Trade list parsed but contains no data rows."
        return $result
    }

    $columns = @($rows[0].PSObject.Properties.Name)
    $profitColumn = Find-Column -Columns $columns -Names @(
        "profit", "deal_profit", "net_profit", "netprofit", "p/l", "pl", "pnl", "profit_loss", "profitloss"
    )
    $balanceColumn = Find-Column -Columns $columns -Names @(
        "balance", "balance_after", "balance_after_if_available", "account_balance"
    )

    $result.profit_column = if ($profitColumn) { $profitColumn } else { "" }
    $result.balance_column = if ($balanceColumn) { $balanceColumn } else { "" }

    if ($profitColumn) {
        $nonzero = 0
        foreach ($row in $rows) {
            $value = Get-Number $row.$profitColumn
            if ($null -ne $value -and [math]::Abs($value) -gt 0.0000001) {
                $nonzero++
            }
        }
        $result.nonzero_profit_rows = $nonzero
        $result.closed_trade_pl_exists = ($nonzero -gt 0)
    }

    if ($balanceColumn) {
        $balances = New-Object System.Collections.Generic.List[double]
        foreach ($row in $rows) {
            $value = Get-Number $row.$balanceColumn
            if ($null -ne $value) {
                $balances.Add($value)
            }
        }
        if ($balances.Count -gt 1) {
            $first = $balances[0]
            $result.balance_changed = (($balances | Where-Object { [math]::Abs($_ - $first) -gt 0.0000001 } | Measure-Object).Count -gt 0)
        }
    }

    $result.reliable = ($result.closed_trade_pl_exists -and $result.balance_changed)
    if ($result.reliable) {
        $result.note = "Trade list shows non-zero closed P/L and changing balance."
    }
    else {
        $result.note = "Trade list did not prove both non-zero closed P/L and changing balance."
    }

    return $result
}

function Test-ReportAccounting {
    param([string]$Path)

    $result = [ordered]@{
        report_present = $false
        nonzero_net_profit_hint = $false
        balance_changed_hint = $false
        note = ""
    }

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        $result.note = "No report supplied."
        return $result
    }

    $result.report_present = $true
    $text = Get-Content -Raw -LiteralPath $Path
    $plain = ($text -replace '<[^>]+>', ' ') -replace '&nbsp;', ' '

    $netProfitMatches = [regex]::Matches($plain, '(?i)(total\s+net\s+profit|net\s+profit|profit)\s*[:=]?\s*(-?[0-9][0-9,\.\s]*)')
    foreach ($match in $netProfitMatches) {
        $value = Get-Number $match.Groups[2].Value
        if ($null -ne $value -and [math]::Abs($value) -gt 0.0000001) {
            $result.nonzero_net_profit_hint = $true
            break
        }
    }

    $balanceNumbers = New-Object System.Collections.Generic.List[double]
    $balanceMatches = [regex]::Matches($plain, '(?i)(initial\s+deposit|balance|final\s+balance)\s*[:=]?\s*(-?[0-9][0-9,\.\s]*)')
    foreach ($match in $balanceMatches) {
        $value = Get-Number $match.Groups[2].Value
        if ($null -ne $value) {
            $balanceNumbers.Add($value)
        }
    }
    if ($balanceNumbers.Count -gt 1) {
        $first = $balanceNumbers[0]
        $result.balance_changed_hint = (($balanceNumbers | Where-Object { [math]::Abs($_ - $first) -gt 0.0000001 } | Measure-Object).Count -gt 0)
    }

    if ($result.nonzero_net_profit_hint -or $result.balance_changed_hint) {
        $result.note = "Report contains accounting hints, but CSV trade list remains preferred for validation."
    }
    else {
        $result.note = "Report text did not prove non-zero P/L and changing balance."
    }

    return $result
}

if (-not (Test-Path -LiteralPath $ReportPath)) {
    throw "ReportPath not found: $ReportPath"
}
if ($TradeListPath -and -not (Test-Path -LiteralPath $TradeListPath)) {
    throw "TradeListPath not found: $TradeListPath"
}
if ($SetPath -and -not (Test-Path -LiteralPath $SetPath)) {
    throw "SetPath not found: $SetPath"
}

$Root = Split-Path -Parent $PSScriptRoot
$ProjectPath = Join-Path $Root "ea_projects\$Project"
if (-not (Test-Path -LiteralPath $ProjectPath)) {
    throw "Project not found: $ProjectPath"
}

$ManualRunsRoot = Join-Path $ProjectPath "backtest\manual_runs"
$RunFolder = Join-Path $ManualRunsRoot $RunId
New-Item -ItemType Directory -Force -Path $RunFolder | Out-Null

$ImportedReport = Join-Path $RunFolder "report.html"
$ImportedTradeList = Join-Path $RunFolder "trade_list.csv"
$ImportedSet = Join-Path $RunFolder "set_used.set"
$RunContextPath = Join-Path $RunFolder "run_context.yaml"
$NotesPath = Join-Path $RunFolder "notes.txt"
$SummaryPath = Join-Path $RunFolder "import_summary.txt"

Copy-Item -LiteralPath $ReportPath -Destination $ImportedReport -Force
if ($TradeListPath) {
    Copy-Item -LiteralPath $TradeListPath -Destination $ImportedTradeList -Force
}
if ($SetPath) {
    Copy-Item -LiteralPath $SetPath -Destination $ImportedSet -Force
}

$tradeValidation = Test-TradeListAccounting -Path $(if ($TradeListPath) { $ImportedTradeList } else { "" })
$reportValidation = Test-ReportAccounting -Path $ImportedReport
$testerProfitValid = [bool]$tradeValidation.reliable
$validationSource = if ($tradeValidation.reliable) { "trade_list.csv" } else { "insufficient_or_unproven" }

$context = [ordered]@{
    mode = "MANUAL_MT5_RUN_IMPORT"
    project = $Project
    run_id = $RunId
    symbol = $Symbol
    timeframe = $Timeframe
    start_date = $StartDate
    end_date = $EndDate
    broker_server = $BrokerServer
    account_currency = $AccountCurrency
    report_path = "report.html"
    trade_list_path = if ($TradeListPath) { "trade_list.csv" } else { "" }
    set_used_path = if ($SetPath) { "set_used.set" } else { "" }
    imported_at = (Get-Date).ToString("o")
    tester_profit_valid = $testerProfitValid
    tester_profit_validation_source = $validationSource
    notes = $Notes
}
Write-SimpleYaml -Data $context -Path $RunContextPath

if ($Notes) {
    $Notes | Set-Content -LiteralPath $NotesPath -Encoding UTF8
}
elseif (-not (Test-Path -LiteralPath $NotesPath)) {
    "Manual MT5 run imported into EA_LAB. Add operator notes here." | Set-Content -LiteralPath $NotesPath -Encoding UTF8
}

$summary = New-Object System.Collections.Generic.List[string]
$summary.Add("MANUAL_MT5_RUN_IMPORT")
$summary.Add("project: $Project")
$summary.Add("run_id: $RunId")
$summary.Add("run_folder: $RunFolder")
$summary.Add("report_imported: $ImportedReport")
$summary.Add("trade_list_imported: $(if ($TradeListPath) { $ImportedTradeList } else { 'MISSING' })")
$summary.Add("set_imported: $(if ($SetPath) { $ImportedSet } else { 'MISSING' })")
$summary.Add("symbol: $Symbol")
$summary.Add("timeframe: $Timeframe")
$summary.Add("start_date: $StartDate")
$summary.Add("end_date: $EndDate")
$summary.Add("broker_server: $BrokerServer")
$summary.Add("account_currency: $AccountCurrency")
$summary.Add("")
$summary.Add("validation:")
$summary.Add("  tester_profit_valid: $($testerProfitValid.ToString().ToLowerInvariant())")
$summary.Add("  source: $validationSource")
$summary.Add("  trade_list_rows: $($tradeValidation.rows)")
$summary.Add("  trade_list_profit_column: $($tradeValidation.profit_column)")
$summary.Add("  trade_list_balance_column: $($tradeValidation.balance_column)")
$summary.Add("  nonzero_profit_rows: $($tradeValidation.nonzero_profit_rows)")
$summary.Add("  balance_changed: $($tradeValidation.balance_changed.ToString().ToLowerInvariant())")
$summary.Add("  trade_list_note: $($tradeValidation.note)")
$summary.Add("  report_nonzero_profit_hint: $($reportValidation.nonzero_net_profit_hint.ToString().ToLowerInvariant())")
$summary.Add("  report_balance_changed_hint: $($reportValidation.balance_changed_hint.ToString().ToLowerInvariant())")
$summary.Add("  report_note: $($reportValidation.note)")
$summary.Add("")
$summary.Add("next_analyzer_input:")
$summary.Add("  report: $ImportedReport")
$summary.Add("  trade_list: $(if ($TradeListPath) { $ImportedTradeList } else { 'MISSING' })")
$summary.Add("  run_context: $RunContextPath")
$summary | Set-Content -LiteralPath $SummaryPath -Encoding UTF8

Write-Host "Manual MT5 run imported."
Write-Host "Run folder: $RunFolder"
Write-Host "tester_profit_valid: $($testerProfitValid.ToString().ToLowerInvariant())"
Write-Host "Summary: $SummaryPath"
