param(
  [string]$Batch = "01",
  [string]$WorklistCsv = "D:\EA_LAB\_triage\mass_smoke_mt4_batches.csv",
  [string]$RootDir = "D:\Forex\10_EA_PROJECTS\2. wait for test",
  [string]$OutCsv = "D:\EA_LAB\_mt5_auto\mass_smoke_mt4.csv",
  [string]$SmokeDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0\MQL4\Experts\_smoke",
  [string]$Terminal = "D:\Meta4\terminal.exe",
  [string]$InstallDir = "D:\Meta4",
  [string]$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0",
  [int]$TimeoutSec = 180,
  [int]$MaxEas = 0
)

$ErrorActionPreference = "Stop"

. "D:\EA_LAB\scripts\use_python.ps1"

$runScript = "D:\EA_LAB\scripts\mt4_run.ps1"
$parseScript = "D:\EA_LAB\scripts\parse_mt4_report.py"
$reportsDir = "D:\EA_LAB\_mt4_auto\reports"
$targetSymbols = @("XAUUSD", "EURUSD", "USDJPY", "AUDNZD")
$m2From = "2026.04.01"
$m2To = "2026.07.01"
$m1From = "2026.03.01"
$m1To = "2026.07.01"

function New-Row {
  param(
    [string]$BatchId,
    [int]$Index,
    [string]$EaName,
    [string]$RelPath,
    [string]$Symbol,
    [double]$M2Trades = 0,
    [string]$M2Report = "",
    [bool]$M1Ran = $false,
    [string]$M1Report = "",
    [object]$M1Pf = $null,
    [object]$M1Trades = $null,
    [object]$M1Net = $null,
    [object]$M1EqDd = $null,
    [string]$Tier = "",
    [string]$Note = ""
  )
  [PSCustomObject]@{
    batch = $BatchId
    ea = $EaName
    path = $RelPath
    symbol = $Symbol
    m2_trades = $M2Trades
    m2_report = $M2Report
    m1_ran = $M1Ran
    m1_report = $M1Report
    m1_pf = $M1Pf
    m1_trades = $M1Trades
    m1_net = $M1Net
    m1_eqdd = $M1EqDd
    tier = $Tier
    note = $Note
    ea_index = $Index
  }
}

function Get-Tier {
  param([double]$Pf, [double]$Trades, [double]$EqDd)
  if ($Pf -le 1.0 -or $Trades -lt 20) { return "Reject" }
  if ($EqDd -lt 40.0) { return "Tier A" }
  return "Tier B"
}

function Parse-ReportJson {
  param([string]$ReportPath)
  if (-not (Test-Path $ReportPath)) { return $null }
  $json = & python $parseScript $ReportPath
  if (-not $json) { return $null }
  return $json | ConvertFrom-Json
}

function Get-AvailableSymbols {
  param([string]$HistoryDir)
  $bases = Get-ChildItem $HistoryDir -Filter "*.hst" -File -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty BaseName
  $clean = foreach ($b in $bases) {
    if ($b -match "^(.+?)(\d+)$") { $matches[1] } else { $b }
  }
  $clean | Sort-Object -Unique
}

function Resolve-SymbolName {
  param(
    [string]$Wanted,
    [string[]]$Available
  )
  if ($Available -contains $Wanted) { return $Wanted }
  $starts = $Available | Where-Object { $_ -like "$Wanted*" }
  if ($starts.Count -ge 1) { return $starts[0] }
  return $null
}

function Invoke-TestRun {
  param(
    [string]$Expert,
    [string]$Symbol,
    [string]$FromDate,
    [string]$ToDate,
    [int]$Model,
    [string]$ReportName
  )

  & powershell -File $runScript `
    -Expert $Expert `
    -Symbol $Symbol `
    -Period "H1" `
    -FromDate $FromDate `
    -ToDate $ToDate `
    -Model $Model `
    -ReportName $ReportName `
    -Terminal $Terminal `
    -InstallDir $InstallDir `
    -DataDir $DataDir `
    -TimeoutSec $TimeoutSec | Out-Host

  $reportPath = Join-Path $reportsDir "$ReportName.htm"
  if (-not (Test-Path $reportPath)) { return $null }
  return $reportPath
}

New-Item -ItemType Directory -Force $SmokeDir | Out-Null
New-Item -ItemType Directory -Force (Split-Path $OutCsv -Parent) | Out-Null

$availableSymbols = @(Get-AvailableSymbols -HistoryDir (Join-Path $DataDir "history\default"))
$worklist = Import-Csv $WorklistCsv | Where-Object { $_.batch -eq $Batch }
if ($MaxEas -gt 0) {
  $worklist = $worklist | Select-Object -First $MaxEas
}

$results = New-Object System.Collections.Generic.List[object]
$eaCounter = 0

foreach ($row in $worklist) {
  $eaCounter++
  $relativePath = $row.path
  $sourcePath = Join-Path $RootDir $relativePath
  $fileName = [IO.Path]::GetFileName($sourcePath)
  $expertName = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
  $expertPath = "_smoke\$expertName"

  if ($eaCounter % 10 -eq 1) {
    Write-Output ("[mass-smoke-mt4] batch {0} EA {1}/{2}: {3}" -f $Batch, $eaCounter, $worklist.Count, $relativePath)
  }

  if (-not (Test-Path $sourcePath)) {
    foreach ($symbol in $targetSymbols) {
      $results.Add((New-Row -BatchId $Batch -Index $eaCounter -EaName $expertName -RelPath $relativePath -Symbol $symbol -Note "source-missing"))
    }
    continue
  }

  Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $SmokeDir $fileName) -Force

  $m2Rows = @()
  $m2TradeHits = 0
  foreach ($symbolWanted in $targetSymbols) {
    $symbolActual = Resolve-SymbolName -Wanted $symbolWanted -Available $availableSymbols
    if (-not $symbolActual) {
      $m2Rows += New-Row -BatchId $Batch -Index $eaCounter -EaName $expertName -RelPath $relativePath -Symbol $symbolWanted -Note "symbol-unavailable"
      continue
    }

    $reportName = "MS4_{0}_{1:D4}_M2_{2}" -f $Batch, $eaCounter, $symbolWanted
    try {
      $reportPath = Invoke-TestRun -Expert $expertPath -Symbol $symbolActual -FromDate $m2From -ToDate $m2To -Model 2 -ReportName $reportName
      if (-not $reportPath) {
        $rowObj = New-Row -BatchId $Batch -Index $eaCounter -EaName $expertName -RelPath $relativePath -Symbol $symbolWanted -Note "m2-no-report"
      } else {
        $parsed = Parse-ReportJson -ReportPath $reportPath
        $m2Trades = if ($parsed) { [double]$parsed.total_trades } else { 0 }
        if ($m2Trades -gt 0) { $m2TradeHits++ }
        $note = @()
        if ($symbolActual -ne $symbolWanted) { $note += "symbol-mapped:$symbolActual" }
        if (-not $parsed) { $note += "m2-parse-failed" }
        $rowObj = New-Row -BatchId $Batch -Index $eaCounter -EaName $expertName -RelPath $relativePath -Symbol $symbolWanted -M2Trades $m2Trades -M2Report ([IO.Path]::GetFileName($reportPath)) -Note ($note -join ";")
      }
    } catch {
      $rowObj = New-Row -BatchId $Batch -Index $eaCounter -EaName $expertName -RelPath $relativePath -Symbol $symbolWanted -Note ("m2-error: " + $_.Exception.Message)
    }
    $m2Rows += $rowObj
  }

  if ($m2TradeHits -eq 0) {
    foreach ($m2Row in $m2Rows) {
      if (-not $m2Row.note) { $m2Row.note = "skip-all-zero-m2" }
      $results.Add($m2Row)
    }
    continue
  }

  foreach ($m2Row in $m2Rows) {
    if ([double]$m2Row.m2_trades -ge 10) {
      $symbolActual = Resolve-SymbolName -Wanted $m2Row.symbol -Available $availableSymbols
      if (-not $symbolActual) {
        $m2Row.note = if ($m2Row.note) { $m2Row.note + ";m1-symbol-unavailable" } else { "m1-symbol-unavailable" }
      } else {
        $reportName = "MS4_{0}_{1:D4}_M1_{2}" -f $Batch, $eaCounter, $m2Row.symbol
        try {
          $reportPath = Invoke-TestRun -Expert $expertPath -Symbol $symbolActual -FromDate $m1From -ToDate $m1To -Model 1 -ReportName $reportName
          if (-not $reportPath) {
            $m2Row.m1_ran = $true
            $m2Row.note = if ($m2Row.note) { $m2Row.note + ";m1-no-report" } else { "m1-no-report" }
          } else {
            $parsed = Parse-ReportJson -ReportPath $reportPath
            $m2Row.m1_ran = $true
            $m2Row.m1_report = [IO.Path]::GetFileName($reportPath)
            if ($parsed) {
              $m2Row.m1_pf = [double]$parsed.profit_factor
              $m2Row.m1_trades = [double]$parsed.total_trades
              $m2Row.m1_net = [double]$parsed.net_profit
              $m2Row.m1_eqdd = [double]$parsed.max_drawdown_pct
              $m2Row.tier = Get-Tier -Pf $m2Row.m1_pf -Trades $m2Row.m1_trades -EqDd $m2Row.m1_eqdd
            } else {
              $m2Row.note = if ($m2Row.note) { $m2Row.note + ";m1-parse-failed" } else { "m1-parse-failed" }
            }
          }
        } catch {
          $m2Row.m1_ran = $true
          $m2Row.note = if ($m2Row.note) { $m2Row.note + ";m1-error: " + $_.Exception.Message } else { "m1-error: " + $_.Exception.Message }
        }
      }
    } elseif (-not $m2Row.note) {
      $m2Row.note = "m2-trades-below-10"
    }
    $results.Add($m2Row)
  }
}

$existing = @()
if (Test-Path $OutCsv) {
  $existing = @(Import-Csv $OutCsv | Where-Object { $_.batch -ne $Batch })
}
@($existing + $results) | Export-Csv $OutCsv -NoTypeInformation -Encoding UTF8

$survivors = $results | Where-Object { $_.tier -in @("Tier A", "Tier B") }
$tierA = @($survivors | Where-Object tier -eq "Tier A")
$tierB = @($survivors | Where-Object tier -eq "Tier B")
$reject = @($results | Where-Object tier -eq "Reject")
$skip = @($results | Where-Object { -not $_.tier })

Write-Output ""
Write-Output ("Saved CSV: {0}" -f $OutCsv)
Write-Output ("Batch: {0} | Rows: {1}" -f $Batch, $results.Count)
Write-Output ("Tier A: {0}" -f $tierA.Count)
Write-Output ("Tier B: {0}" -f $tierB.Count)
Write-Output ("Reject: {0}" -f $reject.Count)
Write-Output ("Skip/no-tier: {0}" -f $skip.Count)
Write-Output ""
$survivors | Sort-Object tier, ea, symbol | Format-Table ea, symbol, m2_trades, m1_pf, m1_trades, m1_net, m1_eqdd, tier -AutoSize
