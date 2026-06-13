param(
    [string]$Project = "",
    [ValidateSet("menu", "single", "optimization", "both")]
    [string]$Mode = "menu",
    [string]$SourceFolder = ""
)

$ErrorActionPreference = "Stop"

function Select-EaLabProject {
    param([string]$Root)

    $projectsRoot = Join-Path $Root "ea_projects"
    $projects = @(Get-ChildItem -LiteralPath $projectsRoot -Directory |
        Where-Object { $_.Name -ne "_template" } |
        Sort-Object Name)

    if ($projects.Count -eq 0) {
        throw "No EA projects found under: $projectsRoot"
    }
    if ($projects.Count -eq 1) {
        return $projects[0].Name
    }

    Write-Host ""
    Write-Host "Select EA project:"
    for ($i = 0; $i -lt $projects.Count; $i++) {
        Write-Host ("{0}) {1}" -f ($i + 1), $projects[$i].Name)
    }
    $choice = Read-Host "Project number"
    $index = 0
    if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $projects.Count) {
        throw "Invalid project selection."
    }
    return $projects[$index - 1].Name
}

function Get-SafeName {
    param([string]$Text)
    if (-not $Text) { return "unknown" }
    $safe = $Text -replace '[\\/:*?"<>|,\s]+', '_'
    $safe = $safe.Trim('_')
    if ($safe.Length -gt 80) { $safe = $safe.Substring(0, 80).Trim('_') }
    return $safe
}

function Get-NumberText {
    param([string]$Text)
    if (-not $Text) { return "" }
    $match = [regex]::Match($Text, '-?\d[\d\s,]*(\.\d+)?')
    if ($match.Success) {
        return (($match.Value -replace '[\s,]', ''))
    }
    return ""
}

function Get-PlainHtml {
    param([string]$Path)
    $raw = Get-Content -Raw -LiteralPath $Path
    $plain = $raw -replace '<[^>]+>', ' '
    $plain = $plain -replace '&nbsp;', ' '
    $plain = $plain -replace '&amp;', '&'
    $plain = $plain -replace '\s+', ' '
    return $plain.Trim()
}

function Get-HtmlCells {
    param([string]$Path)
    $raw = Get-Content -Raw -LiteralPath $Path
    $matches = [regex]::Matches($raw, '<t[dh][^>]*>(.*?)</t[dh]>', 'Singleline,IgnoreCase')
    $cells = New-Object System.Collections.Generic.List[string]
    foreach ($match in $matches) {
        $cell = $match.Groups[1].Value
        $cell = $cell -replace '<[^>]+>', ' '
        $cell = $cell -replace '&nbsp;', ' '
        $cell = $cell -replace '&amp;', '&'
        $cell = $cell -replace '\s+', ' '
        $cell = $cell.Trim()
        if ($cell) { $cells.Add($cell) }
    }
    return $cells
}

function Get-CellMetric {
    param(
        [System.Collections.Generic.List[string]]$Cells,
        [string]$Label
    )
    for ($i = 0; $i -lt $Cells.Count - 1; $i++) {
        if ($Cells[$i] -eq $Label) {
            return $Cells[$i + 1]
        }
    }
    return ""
}

function Find-LatestSingleReport {
    param([string]$ProjectPath, [string]$SourceFolder)
    $searchRoots = New-Object System.Collections.Generic.List[string]
    if ($SourceFolder -and (Test-Path -LiteralPath $SourceFolder -PathType Container)) {
        $searchRoots.Add((Resolve-Path -LiteralPath $SourceFolder).Path)
    }
    foreach ($path in @(
        (Join-Path $ProjectPath "backtest\manual_runs"),
        (Join-Path $ProjectPath "reports\latest")
    )) {
        if (Test-Path -LiteralPath $path -PathType Container) {
            $searchRoots.Add($path)
        }
    }

    $files = foreach ($root in $searchRoots) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Include "ReportTester*.html", "report.html", "*single*.html" -ErrorAction SilentlyContinue
    }
    $files = @($files | Where-Object { $_.Extension -in @(".html", ".htm") })
    return @($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1)[0]
}

function Find-LatestOptimizationSource {
    param([string]$ProjectPath, [string]$SourceFolder)
    $analyzed = Join-Path $ProjectPath "optimization\analyzed"
    $raw = Join-Path $ProjectPath "optimization\raw_results"
    $roots = New-Object System.Collections.Generic.List[string]
    if ($SourceFolder -and (Test-Path -LiteralPath $SourceFolder -PathType Container)) {
        $roots.Add((Resolve-Path -LiteralPath $SourceFolder).Path)
    }
    foreach ($path in @($analyzed, $raw)) {
        if (Test-Path -LiteralPath $path -PathType Container) { $roots.Add($path) }
    }

    $allCsv = foreach ($root in $roots) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.csv" -ErrorAction SilentlyContinue
    }
    $allXml = foreach ($root in $roots) {
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.xml" -ErrorAction SilentlyContinue
    }

    $allCsv = @($allCsv | Where-Object { $_.FullName -notmatch '\\reports\\collected\\' })
    $allXml = @($allXml | Where-Object { $_.FullName -notmatch '\\reports\\collected\\' })
    $validCsv = @($allCsv | Where-Object { $_.Name -like "*valid_candidates*.csv" -or $_.Name -like "*compliant_candidates*.csv" })
    $parsedCsv = @($allCsv | Where-Object { $_.Name -like "*optimizer_parsed*.csv" })
    $xml = @($allXml | Where-Object { $_.Name -like "ReportOptimizer*.xml" -or $_.Name -like "*optimizer*.xml" })

    return [ordered]@{
        valid_csv = @($validCsv | Sort-Object LastWriteTime -Descending | Select-Object -First 1)[0]
        parsed_csv = @($parsedCsv | Sort-Object LastWriteTime -Descending | Select-Object -First 1)[0]
        xml = @($xml | Sort-Object LastWriteTime -Descending | Select-Object -First 1)[0]
    }
}

function Get-OptimizationTitle {
    param([System.IO.FileInfo]$XmlFile, [string]$Project)
    if ($XmlFile -and (Test-Path -LiteralPath $XmlFile.FullName)) {
        $text = Get-Content -Raw -LiteralPath $XmlFile.FullName
        $match = [regex]::Match($text, '<Title>(.*?)</Title>')
        if ($match.Success) {
            return ($match.Groups[1].Value -replace '\s+XAUUSD.*$', '').Trim()
        }
    }
    return $Project
}

function Export-SingleSummary {
    param([string]$Project, [string]$ProjectPath, [string]$SourceFolder)

    $report = Find-LatestSingleReport -ProjectPath $ProjectPath -SourceFolder $SourceFolder
    $outRoot = Join-Path $ProjectPath "reports\collected\single"
    New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
    if (-not $report) {
        $warn = Join-Path $outRoot ("SINGLE_NO_REPORT_FOUND_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
        "No single-test report found." | Set-Content -LiteralPath $warn -Encoding UTF8
        return $warn
    }

    $cells = Get-HtmlCells -Path $report.FullName
    $expert = Get-CellMetric -Cells $cells -Label "Expert:"
    $symbol = Get-CellMetric -Cells $cells -Label "Symbol:"
    $period = Get-CellMetric -Cells $cells -Label "Period:"
    $profit = Get-CellMetric -Cells $cells -Label "Total Net Profit:"
    $trades = Get-CellMetric -Cells $cells -Label "Total Trades:"
    $dd = Get-CellMetric -Cells $cells -Label "Balance Drawdown Maximal:"
    $equityDd = Get-CellMetric -Cells $cells -Label "Equity Drawdown Maximal:"
    $pf = Get-CellMetric -Cells $cells -Label "Profit Factor:"
    $sharpe = Get-CellMetric -Cells $cells -Label "Sharpe Ratio:"

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fileBase = "SINGLE_{0}_tr{1}_profit{2}_dd{3}_sharpe{4}_{5}" -f `
        (Get-SafeName $expert), (Get-NumberText $trades), (Get-NumberText $profit), (Get-NumberText $dd), (Get-NumberText $sharpe), $stamp
    $summaryPath = Join-Path $outRoot "$fileBase.md"
    $csvPath = Join-Path $outRoot "$fileBase.csv"
    $reportCopy = Join-Path $outRoot "$fileBase.html"

    Copy-Item -LiteralPath $report.FullName -Destination $reportCopy -Force

    $rows = @(
        [pscustomobject]@{
            project = $Project
            report_type = "single"
            ea_name = $expert
            symbol = $symbol
            period = $period
            total_trades = $trades
            total_net_profit = $profit
            profit_factor = $pf
            balance_dd = $dd
            equity_dd = $equityDd
            sharpe_ratio = $sharpe
            source_report = $report.FullName
            copied_report = $reportCopy
        }
    )
    $rows | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    @"
# Latest Single Test Summary

- project: $Project
- ea_name: $expert
- symbol: $symbol
- period: $period
- total_trades: $trades
- total_net_profit: $profit
- profit_factor: $pf
- balance_dd: $dd
- equity_dd: $equityDd
- sharpe_ratio: $sharpe
- source_report: $($report.FullName)
- copied_report: $reportCopy
- csv_summary: $csvPath
"@ | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    return $summaryPath
}

function Export-OptimizationSummary {
    param([string]$Project, [string]$ProjectPath, [string]$SourceFolder)

    $sources = Find-LatestOptimizationSource -ProjectPath $ProjectPath -SourceFolder $SourceFolder
    $outRoot = Join-Path $ProjectPath "reports\collected\optimization"
    New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

    $sourceCsv = if ($sources.valid_csv) { $sources.valid_csv } else { $sources.parsed_csv }
    if (-not $sourceCsv) {
        $warn = Join-Path $outRoot ("OPT_NO_TABLE_FOUND_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
        "No optimization CSV table found. Export or analyze optimizer results first." | Set-Content -LiteralPath $warn -Encoding UTF8
        return $warn
    }

    $allRows = @()
    if ($sources.parsed_csv) {
        $allRows = @(Import-Csv -LiteralPath $sources.parsed_csv.FullName)
    }
    $rows = @(Import-Csv -LiteralPath $sourceCsv.FullName)
    $tests = if ($allRows.Count -gt 0) { $allRows.Count } else { $rows.Count }
    $profitCol = if ($rows[0].PSObject.Properties.Name -contains "Profit") { "Profit" } else { "Result" }
    $sharpeCol = if ($rows[0].PSObject.Properties.Name -contains "Sharpe Ratio") { "Sharpe Ratio" } else { "Sharpe" }
    $best = $rows | Sort-Object { [double](($_.$profitCol -replace '[,\s]', '')) } -Descending | Select-Object -First 1
    $ea = Get-OptimizationTitle -XmlFile $sources.xml -Project $Project
    $maxProfit = $best.$profitCol
    $bestSharpe = if ($sharpeCol -and ($best.PSObject.Properties.Name -contains $sharpeCol)) { $best.$sharpeCol } else { "" }
    $bestPf = if ($best.PSObject.Properties.Name -contains "Profit Factor") { $best."Profit Factor" } else { "" }
    $bestTrades = if ($best.PSObject.Properties.Name -contains "Trades") { $best.Trades } else { "" }
    $bestDd = if ($best.PSObject.Properties.Name -contains "Equity DD %") { $best."Equity DD %" } else { "" }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fileBase = "OPT_{0}_tests{1}_maxprofit{2}_sharpe{3}_{4}" -f `
        (Get-SafeName $ea), $tests, (Get-NumberText $maxProfit), (Get-NumberText $bestSharpe), $stamp
    $summaryPath = Join-Path $outRoot "$fileBase.md"
    $csvPath = Join-Path $outRoot "$fileBase.csv"

    $rows | Select-Object -First 50 | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

    @"
# Latest Optimization Summary

- project: $Project
- ea_name: $ea
- optimization_table: $($sourceCsv.FullName)
- parsed_all_table: $(if ($sources.parsed_csv) { $sources.parsed_csv.FullName } else { "" })
- raw_xml: $(if ($sources.xml) { $sources.xml.FullName } else { "" })
- total_tests: $tests
- table_rows_exported: $($rows.Count)
- max_profit: $maxProfit
- best_profit_sharpe_ratio: $bestSharpe
- best_profit_profit_factor: $bestPf
- best_profit_trades: $bestTrades
- best_profit_equity_dd_percent: $bestDd
- top50_csv: $csvPath

## Best Profit Row

$(($best | ConvertTo-Csv -NoTypeInformation) -join "`n")
"@ | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    return $summaryPath
}

$Root = Split-Path -Parent $PSScriptRoot
if (-not $Project) {
    $Project = Select-EaLabProject -Root $Root
}
$ProjectPath = Join-Path $Root "ea_projects\$Project"
if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    throw "Project not found: $ProjectPath"
}

if ($Mode -eq "menu") {
    Write-Host ""
    Write-Host "EA_LAB Quick Report Collector"
    Write-Host "Project: $Project"
    Write-Host ""
    Write-Host "1) Collect latest single-test summary"
    Write-Host "2) Collect latest optimization summary"
    Write-Host "3) Collect both"
    Write-Host "Q) Quit"
    $choice = Read-Host "Select"
    switch ($choice.ToUpperInvariant()) {
        "1" { $Mode = "single" }
        "2" { $Mode = "optimization" }
        "3" { $Mode = "both" }
        default { Write-Host "Cancelled."; exit 0 }
    }
}

$outputs = New-Object System.Collections.Generic.List[string]
if ($Mode -eq "single" -or $Mode -eq "both") {
    $outputs.Add((Export-SingleSummary -Project $Project -ProjectPath $ProjectPath -SourceFolder $SourceFolder))
}
if ($Mode -eq "optimization" -or $Mode -eq "both") {
    $outputs.Add((Export-OptimizationSummary -Project $Project -ProjectPath $ProjectPath -SourceFolder $SourceFolder))
}

Write-Host ""
Write-Host "Done. Created:"
foreach ($out in $outputs) {
    Write-Host " - $out"
}
