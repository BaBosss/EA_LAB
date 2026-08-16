<#
Deterministic/local cage for scripts/lib/symbol_preflight.ps1.
No MT5 process, terminal, tester, or lane is started by this suite.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $root 'scripts\lib\symbol_preflight.ps1')

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('symbol_preflight_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$terminal = Join-Path $tmp 'terminal64.exe'
$capability = Join-Path $tmp 'capability.json'
$universe = Join-Path $tmp 'universe.jsonl'
$missingMappedCapability = Join-Path $tmp 'capability-without-xau.json'
Set-Content -LiteralPath $terminal -Value 'fixture terminal' -Encoding ASCII
Set-Content -LiteralPath $capability -Value (@{ symbols = @('AUDCAD','EURUSD','XAUUSD','XAGUSD') } | ConvertTo-Json) -Encoding UTF8
Set-Content -LiteralPath $missingMappedCapability -Value (@{ symbols = @('EURUSD') } | ConvertTo-Json) -Encoding UTF8
Set-Content -LiteralPath $universe -Value (@(
  (@{ entity='LogicalSymbol'; logical='EURUSDm'; asset_class='FX_MAJOR'; broker_map=@{ 'lane-1'='EURUSD' } } | ConvertTo-Json -Compress),
  (@{ entity='LogicalSymbol'; logical='XAUUSDm'; asset_class='GOLD'; broker_map=@{ 'lane-1'='XAUUSD' } } | ConvertTo-Json -Compress)
)) -Encoding UTF8
$selectedRoot = Join-Path $tmp 'Bases\ThinkMarkets-Live\symbols'
New-Item -ItemType Directory -Path $selectedRoot -Force | Out-Null
$selectedDat = Join-Path $selectedRoot 'selected-1.dat'
[IO.File]::WriteAllText($selectedDat, 'Selected EURUSD XAUUSD XAGUSD', [Text.Encoding]::Unicode)

$pass = 0; $fail = 0
function Check {
  param([string]$Name, [bool]$Condition, [string]$Detail = '')
  if ($Condition) { Write-Host "[PASS] $Name" -ForegroundColor Green; $script:pass++ }
  else { Write-Host "[FAIL] $Name $Detail" -ForegroundColor Red; $script:fail++ }
}
function Refuses {
  param([scriptblock]$Body)
  try { & $Body; return $false } catch { return ($_.Exception.Message -match 'SYMBOL_PREFLIGHT:') }
}

try {
  $r = Resolve-TesterSymbol -LogicalSymbol 'EURUSD' -TerminalPath $terminal -DataDir $tmp -CapabilityFile $capability
  Check 'exact symbol resolves' ($r.logical_symbol -eq 'EURUSD' -and $r.tester_symbol -eq 'EURUSD')
  Check 'exact symbol is marked comparable' ($r.comparison_status -eq 'COMPARABLE_EXACT_SYMBOL')
  Check 'capability source is retained' ($r.capability_source -eq (Resolve-Path $capability).Path)

  $r = Resolve-TesterSymbol -LogicalSymbol 'XAUUSD' -TerminalPath $terminal -DataDir $tmp
  Check 'MT5 selected-symbol metadata is parsed locally' ($r.tester_symbol -eq 'XAUUSD' -and $r.capability_source -eq $selectedDat)

  Check 'symbol spelling is not normalized by suffix guessing' (Refuses { Resolve-TesterSymbol -LogicalSymbol 'EURUSD+' -TerminalPath $terminal -DataDir $tmp -CapabilityFile $capability })

  $r = Resolve-TesterSymbol -LogicalSymbol 'EURUSDm' -TerminalPath $terminal -DataDir $tmp -LaneId 'lane-1' -UniversePath $universe -CapabilityFile $capability
  Check 'explicit mapping resolves' ($r.logical_symbol -eq 'EURUSDm' -and $r.tester_symbol -eq 'EURUSD')
  Check 'logical and tester symbols remain distinct' ($r.logical_symbol -ne $r.tester_symbol)
  Check 'substitution is explicitly non-comparable' ($r.comparison_status -eq 'NOT_COMPARABLE_UNTIL_ECONOMICS_CHECK' -and $r.economics_check -eq 'NOT_PERFORMED')
  Check 'mapping lane is recorded' ($r.lane_id -eq 'lane-1')

  Check 'unavailable suffixed symbol refuses' (Refuses { Resolve-TesterSymbol -LogicalSymbol 'AUDCADm' -TerminalPath $terminal -DataDir $tmp -CapabilityFile $capability })
  Check 'missing mapping lane refuses' (Refuses { Resolve-TesterSymbol -LogicalSymbol 'XAUUSDm' -TerminalPath $terminal -DataDir $tmp -LaneId 'lane-2' -UniversePath $universe -CapabilityFile $capability })
  Check 'mapped actual symbol must exist' (Refuses { Resolve-TesterSymbol -LogicalSymbol 'XAUUSDm' -TerminalPath $terminal -DataDir $tmp -LaneId 'lane-1' -UniversePath $universe -CapabilityFile $missingMappedCapability })
  Check 'missing terminal refuses before capability resolution' (Refuses { Resolve-TesterSymbol -LogicalSymbol 'EURUSD' -TerminalPath (Join-Path $tmp 'missing.exe') -DataDir $tmp -CapabilityFile $capability })

  $runText = Get-Content -LiteralPath (Join-Path $root 'scripts\mt5_run.ps1') -Raw
  $optText = Get-Content -LiteralPath (Join-Path $root 'scripts\mt5_optimize.ps1') -Raw
  $backText = Get-Content -LiteralPath (Join-Path $root 'scripts\run_backtest.ps1') -Raw
  Check 'single runner wires shared resolver' ($runText -match 'Resolve-TesterSymbol' -and $runText -match 'tester_symbol')
  Check 'optimizer wires shared resolver' ($optText -match 'Resolve-TesterSymbol' -and $optText -match 'tester_symbol')
  Check 'backtest runner wires shared resolver' ($backText -match 'Resolve-TesterSymbol' -and $backText -match 'tester_symbol')
  Check 'single runner writes resolved tester symbol' ($runText -match 'Symbol=\$TesterSymbol')
  Check 'optimizer writes resolved tester symbol' ($optText -match 'Symbol=\$TesterSymbol')
  Check 'backtest runner writes resolved tester symbol' ($backText -match 'Symbol=\$TesterSymbol')
  Check 'single runner records economics gate' ($runText -match 'economics_check=')
  Check 'optimizer records economics gate' ($optText -match 'economics_check=')
  Check 'backtest runner records economics gate' ($backText -match 'economics_check=')
}
finally {
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "symbol preflight tests: $pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }
exit 0
