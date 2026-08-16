<#
Shared MT5 tester symbol preflight.

The tester's [Tester] Symbol value is a broker/lane value, not a research
identity.  Callers pass the logical symbol they intend to test; this module
resolves it to an actual tester symbol only when the lane capability metadata
proves that the value exists or an explicit LogicalSymbol broker_map names a
supported value for this lane.

This module deliberately does not strip suffixes or try a "close enough"
symbol.  A different spelling can carry different contract size, point,
swap, margin, or trading hours.  An explicit mapping is therefore recorded as
NOT_COMPARABLE_UNTIL_ECONOMICS_CHECK rather than being presented as comparable evidence.
#>

function Normalize-SymbolPreflightKey {
  param([Parameter(Mandatory)][string]$Value)
  return (($Value.Trim() -replace '/', '\') -replace '\\+$', '').ToLowerInvariant()
}

function Get-SelectedSymbolsMetadataPath {
  param(
    [Parameter(Mandatory)][string]$DataDir,
    [string]$Server = 'ThinkMarkets-Live'
  )

  $roots = @(
    (Join-Path $DataDir ("Bases\$Server\symbols")),
    (Join-Path $DataDir ("bases\$Server\symbols"))
  )
  $candidates = @(
    foreach ($root in $roots) {
      if (Test-Path -LiteralPath $root -PathType Container) {
        Get-ChildItem -LiteralPath $root -Filter 'selected-*.dat' -File -ErrorAction SilentlyContinue
      }
    }
  )
  if ($candidates.Count -eq 0) {
    throw "SYMBOL_PREFLIGHT: no selected-symbol capability metadata for server '$Server' under DataDir '$DataDir'"
  }
  return ($candidates | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).FullName
}

function Read-TesterCapabilitySymbols {
  param(
    [string]$CapabilityFile,
    [Parameter(Mandatory)][string]$DataDir,
    [string]$Server = 'ThinkMarkets-Live'
  )

  if ($CapabilityFile) {
    if (-not (Test-Path -LiteralPath $CapabilityFile -PathType Leaf)) {
      throw "SYMBOL_PREFLIGHT: capability fixture does not exist: $CapabilityFile"
    }
    try {
      $doc = Get-Content -LiteralPath $CapabilityFile -Raw | ConvertFrom-Json
    }
    catch {
      throw "SYMBOL_PREFLIGHT: capability metadata is not valid JSON: $CapabilityFile ($($_.Exception.Message))"
    }
    $symbols = @($doc.symbols | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() })
    if ($symbols.Count -eq 0) {
      throw "SYMBOL_PREFLIGHT: capability metadata contains no symbols: $CapabilityFile"
    }
    return [pscustomobject]@{
      symbols = @($symbols | ForEach-Object { $_.Trim() } | Sort-Object -Unique)
      source = (Resolve-Path -LiteralPath $CapabilityFile).Path
      format = 'json-fixture'
    }
  }

  $metadataPath = Get-SelectedSymbolsMetadataPath -DataDir $DataDir -Server $Server
  try {
    # MT5 selected-*.dat is a UTF-16LE metadata store.  The symbol names are
    # encoded as standalone uppercase tokens; descriptions are mixed case.
    $text = [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($metadataPath))
  }
  catch {
    throw "SYMBOL_PREFLIGHT: unable to read selected-symbol metadata '$metadataPath' ($($_.Exception.Message))"
  }
  $symbols = @(
    [regex]::Matches($text, '(?<![A-Za-z0-9])([A-Z][A-Z0-9._-]{3,})(?![A-Za-z0-9])') |
      ForEach-Object { $_.Groups[1].Value } |
      Sort-Object -Unique
  )
  if ($symbols.Count -eq 0) {
    throw "SYMBOL_PREFLIGHT: selected-symbol metadata contained no recognizable symbols: $metadataPath"
  }
  # A symbol can be present in the broker capability store without being in
  # the current Market Watch selection.  Existing local history/tick folders
  # are also terminal-owned metadata and are sufficient to prove that the
  # tester has seen the symbol.  Union them; never infer a symbol by removing
  # a suffix from another symbol.
  $dataRoot = Split-Path -Parent (Split-Path -Parent $metadataPath)
  $dataSymbols = @(
    foreach ($kind in @('history', 'ticks')) {
      $folder = Join-Path $dataRoot $kind
      if (Test-Path -LiteralPath $folder -PathType Container) {
        Get-ChildItem -LiteralPath $folder -Directory -ErrorAction SilentlyContinue |
          ForEach-Object { $_.Name }
      }
    }
  )
  $symbols = @($symbols + $dataSymbols | Where-Object { $_.Trim() } | Sort-Object -Unique)
  return [pscustomobject]@{
    symbols = $symbols
    source = if ($dataSymbols.Count -gt 0) { "$metadataPath; history/ticks metadata under '$dataRoot'" } else { $metadataPath }
    format = 'mt5-selected-symbols'
  }
}

function Get-LogicalSymbolMappingRecord {
  param(
    [Parameter(Mandatory)][string]$LogicalSymbol,
    [Parameter(Mandatory)][string]$TerminalPath,
    [string]$LaneId,
    [string]$UniversePath
  )

  if (-not $UniversePath) { return $null }
  if (-not (Test-Path -LiteralPath $UniversePath -PathType Leaf)) {
    throw "SYMBOL_PREFLIGHT: explicit universe mapping file does not exist: $UniversePath"
  }

  $record = $null
  foreach ($line in (Get-Content -LiteralPath $UniversePath)) {
    if (-not $line.Trim()) { continue }
    try { $candidate = $line | ConvertFrom-Json }
    catch { throw "SYMBOL_PREFLIGHT: invalid JSONL in universe mapping file '$UniversePath' ($($_.Exception.Message))" }
    if ($candidate.entity -eq 'LogicalSymbol' -and [string]$candidate.logical -eq $LogicalSymbol) {
      if ($record) { throw "SYMBOL_PREFLIGHT: duplicate LogicalSymbol '$LogicalSymbol' in '$UniversePath'" }
      $record = $candidate
    }
  }
  if (-not $record) { return $null }
  if (-not $record.broker_map) {
    throw "SYMBOL_PREFLIGHT: LogicalSymbol '$LogicalSymbol' has no broker_map"
  }

  $keys = @()
  if ($LaneId) { $keys += $LaneId }
  $keys += $TerminalPath
  $mapEntry = $null
  foreach ($key in $keys) {
    $wanted = Normalize-SymbolPreflightKey $key
    $property = @($record.broker_map.PSObject.Properties |
      Where-Object { (Normalize-SymbolPreflightKey $_.Name) -eq $wanted }) | Select-Object -First 1
    if ($property) {
      $mapEntry = [pscustomobject]@{ key = $property.Name; tester_symbol = [string]$property.Value }
      break
    }
  }
  if (-not $mapEntry) {
    $laneLabel = if ($LaneId) { $LaneId } else { $TerminalPath }
    throw "SYMBOL_PREFLIGHT: LogicalSymbol '$LogicalSymbol' has no mapping for lane '$laneLabel'"
  }
  if (-not $mapEntry.tester_symbol.Trim()) {
    throw "SYMBOL_PREFLIGHT: LogicalSymbol '$LogicalSymbol' has an empty mapping for lane '$($mapEntry.key)'"
  }
  return [pscustomobject]@{
    logical_symbol = $LogicalSymbol
    tester_symbol = $mapEntry.tester_symbol.Trim()
    mapping_key = $mapEntry.key
    source = (Resolve-Path -LiteralPath $UniversePath).Path
  }
}

function Resolve-TesterSymbol {
  param(
    [Parameter(Mandatory)][string]$LogicalSymbol,
    [Parameter(Mandatory)][string]$TerminalPath,
    [Parameter(Mandatory)][string]$DataDir,
    [string]$LaneId,
    [string]$Server = 'ThinkMarkets-Live',
    [string]$UniversePath,
    [string]$CapabilityFile
  )

  if (-not (Test-Path -LiteralPath $TerminalPath -PathType Leaf)) {
    throw "SYMBOL_PREFLIGHT: terminal executable is unavailable: $TerminalPath"
  }
  $capability = Read-TesterCapabilitySymbols -CapabilityFile $CapabilityFile -DataDir $DataDir -Server $Server
  $available = @($capability.symbols)
  $availableKeys = @($available | ForEach-Object { Normalize-SymbolPreflightKey $_ })
  $mapping = Get-LogicalSymbolMappingRecord -LogicalSymbol $LogicalSymbol -TerminalPath $TerminalPath -LaneId $LaneId -UniversePath $UniversePath

  if ($mapping) {
    $testerSymbol = $mapping.tester_symbol
    $source = "explicit LogicalSymbol broker_map ($($mapping.mapping_key))"
    $substituted = ($testerSymbol -cne $LogicalSymbol)
  }
  else {
    $testerSymbol = $LogicalSymbol
    $source = 'exact logical symbol'
    $substituted = $false
  }

  if ($availableKeys -notcontains (Normalize-SymbolPreflightKey $testerSymbol)) {
    if ($mapping) {
      throw "SYMBOL_PREFLIGHT: mapped tester symbol '$testerSymbol' for logical '$LogicalSymbol' is unavailable on lane '$TerminalPath' (capability source '$($capability.source)')"
    }
    throw "SYMBOL_PREFLIGHT: logical symbol '$LogicalSymbol' is unavailable on lane '$TerminalPath'; no supported mapping exists (capability source '$($capability.source)')"
  }

  [pscustomobject]@{
    logical_symbol = $LogicalSymbol
    tester_symbol = $testerSymbol
    terminal = $TerminalPath
    data_dir = $DataDir
    lane_id = if ($LaneId) { $LaneId } else { Split-Path -Parent $TerminalPath }
    server = $Server
    substituted = $substituted
    resolution_source = $source
    capability_source = $capability.source
    comparison_status = if ($substituted) { 'NOT_COMPARABLE_UNTIL_ECONOMICS_CHECK' } else { 'COMPARABLE_EXACT_SYMBOL' }
    economics_check = if ($substituted) { 'NOT_PERFORMED' } else { 'EXACT_SYMBOL_IDENTITY' }
  }
}
