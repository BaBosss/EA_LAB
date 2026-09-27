<#
Fail-closed MacroGate tester-transfer engineering orchestrator.

Offline validates repository/contract/feed identities without touching MT5.
Preflight additionally requires a current Registry runtime reservation, an idle
machine, and owned-or-absent terminal dependency paths. Native performs only
compile/no-order diagnostic probes. It never interprets PF/net/DD, runs an
optimizer, writes Common\Files, injects Agent sandboxes, kills a process, or
overwrites an unowned terminal file.
#>
[CmdletBinding()]
param(
  [ValidateSet('Offline','Preflight','Native')]
  [string]$Mode = 'Offline',
  [string]$RepoRoot = '',
  [string]$EvidenceRoot = '',
  [string]$LaneId = 'ct-news-macro-mg-tester-transfer-impl-v1-20260927',
  [string]$RuntimeLeaseLaneId = 'ct-news-macro-mg-tester-transfer-runtime-lease-v1-20260927',
  [string]$RegistryRoot = 'D:\EA_LAB_CONTROL\lanes\registry-v1',
  [string]$Terminal = 'D:\Meta 5\terminal64.exe',
  [string]$MetaEditor = 'D:\Meta 5\metaeditor64.exe',
  [string]$DataDir = 'D:\MetaTraderData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  [string]$DependencyOwnershipReceipt = '',
  [switch]$ConfirmNativeNoPerformance
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (!$RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$implPrefix = Join-Path $RepoRoot 'factory\runs\news_macro_macrogate_tester_transfer_impl_v1_20260927'
if (!$EvidenceRoot) {
  $EvidenceRoot = Join-Path $implPrefix ('orchestrator-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$evidenceFull = [IO.Path]::GetFullPath($EvidenceRoot)
$prefixFull = [IO.Path]::GetFullPath($implPrefix).TrimEnd('\') + '\'
if (!$evidenceFull.StartsWith($prefixFull,[StringComparison]::OrdinalIgnoreCase)) {
  throw "REFUSE: EvidenceRoot must remain below $implPrefix"
}
New-Item -ItemType Directory -Force -Path $evidenceFull | Out-Null

$authorBaseHead = '4aa459566c4e5eedc2477938fa5d3f4f86d00e8e'
$requiredWorktreeHead = 'b586d4d32c04fa33a30517ab3a1a8469b238d2ac'
$contractRoot = Join-Path $RepoRoot 'factory\runs\news_macro_macrogate_tester_transfer_qual_v1_20260926'
$contractPath = Join-Path $contractRoot 'PROSPECTIVE_IMPLEMENTATION_CONTRACT.json'
$expectationPath = Join-Path $contractRoot 'FEED_RUNTIME_EXPECTATIONS.json'
$sourceBindingPath = Join-Path $contractRoot 'SOURCE_BINDING.json'
$ownerAuthPath = 'D:\EA_LAB_CONTROL\evidence\mg-tester-transfer-impl-v1-20260927\OWNER_AUTHORIZATION.json'
$tradeHeader = 'D:\MetaTraderData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Include\Trade\Trade.mqh'
$allowed = @(
  'ea_template/Boss_15_ST03.mq5',
  'ea_template/core/LabCore.mqh',
  'ea_template/core/MacroGate_Core.mqh',
  'ea_template/core/Execution.mqh',
  'scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1',
  'scripts/_test/macrogate_tester_transfer_probe.mq5',
  'scripts/_test/test_macrogate_tester_transfer_contract.py'
)
$allowedPrefix = 'factory/runs/news_macro_macrogate_tester_transfer_impl_v1_20260927/'

function Get-Sha256([string]$Path) {
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "MISSING_FILE $Path" }
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Write-Receipt([string]$Name,[object]$Value) {
  $path = Join-Path $evidenceFull $Name
  $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding UTF8
  return $path
}

function Assert-AllowedWorktreeChanges {
  $lines = @(& git -C $RepoRoot status --porcelain=v1 --untracked-files=all)
  if ($LASTEXITCODE -ne 0) { throw 'REFUSE: git status failed' }
  foreach ($line in $lines) {
    if ($line.Length -lt 4) { continue }
    $path = $line.Substring(3).Replace('\','/')
    if ($path.Contains(' -> ')) { $path = $path.Split(@(' -> '),2,[StringSplitOptions]::None)[1] }
    if (($allowed -notcontains $path) -and !$path.StartsWith($allowedPrefix,[StringComparison]::Ordinal)) {
      throw "REFUSE: out-of-allowlist worktree change $path"
    }
  }
}

function Get-FeedFacts([string]$Path) {
  $bytes = [IO.File]::ReadAllBytes($Path)
  $text = [Text.Encoding]::UTF8.GetString($bytes)
  if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
  $lines = $text -split "`r?`n"
  $valid = New-Object Collections.Generic.List[string]
  for ($i=1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Length -lt 8) { continue }
    $fields = $line.Split(',')
    if ($fields.Count -lt 2) { continue }
    $stamp = $fields[0].Trim()
    $state = $fields[1].Trim().ToUpperInvariant()
    $when = [datetime]::MinValue
    if (![datetime]::TryParseExact($stamp,'yyyy.MM.dd HH:mm',[Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::None,[ref]$when)) { continue }
    if (@('RISK_ON','NEUTRAL','RISK_OFF','STRESS','UNKNOWN') -notcontains $state) { continue }
    $valid.Add($stamp)
  }
  return [ordered]@{
    bytes = $bytes.Length
    sha256 = (Get-Sha256 $Path)
    rows = $valid.Count
    first = if ($valid.Count) { $valid[0] } else { $null }
    last = if ($valid.Count) { $valid[$valid.Count-1] } else { $null }
  }
}

function Invoke-OfflineValidation {
  foreach ($path in @($contractPath,$expectationPath,$sourceBindingPath,$ownerAuthPath,$tradeHeader)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "REFUSE: required input missing $path" }
  }
  $head = (& git -C $RepoRoot rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -ne $requiredWorktreeHead) {
    throw "REFUSE: author worktree HEAD must equal reanchored canonical $requiredWorktreeHead; observed $head"
  }
  Assert-AllowedWorktreeChanges
  $contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
  $expectations = Get-Content -Raw -LiteralPath $expectationPath | ConvertFrom-Json
  $binding = Get-Content -Raw -LiteralPath $sourceBindingPath | ConvertFrom-Json
  $auth = Get-Content -Raw -LiteralPath $ownerAuthPath | ConvertFrom-Json
  if ($contract.schema -ne 'macrogate_tester_transfer_prospective_implementation_contract/2') { throw 'REFUSE: wrong contract schema' }
  if (!$auth.authorized_implementation -or $auth.authorized_performance) { throw 'REFUSE: owner authority mismatch' }
  if ($auth.base -ne $authorBaseHead -or $auth.holdout -ne 'LOCKED_UNSPENT') { throw 'REFUSE: owner base/HOLDOUT mismatch' }
  if ($expectations.entries.Count -ne 11) { throw 'REFUSE: expected exactly eleven golden inputs' }
  if ((Get-Sha256 $tradeHeader) -ne '96e6781624534377fe7971cba52cca3d62d1b030bc10d5e4ebf3ed8c541399ed') {
    throw 'REFUSE: installed Trade.mqh identity changed'
  }
  foreach ($immutable in @('ea_template/core/Inputs.mqh','ea_template/core/ConfigFingerprint.mqh')) {
    $expected = @($binding.source_files | Where-Object path -eq $immutable)
    if ($expected.Count -ne 1 -or (Get-Sha256 (Join-Path $RepoRoot $immutable)) -ne $expected[0].sha256) {
      throw "REFUSE: immutable source drift $immutable"
    }
  }
  $feedFacts = @()
  foreach ($entry in $expectations.entries) {
    $path = Join-Path $RepoRoot $entry.source_path
    $facts = Get-FeedFacts $path
    if ($facts.sha256 -ne $entry.sha256 -or $facts.bytes -ne [int64]$entry.bytes -or
        $facts.rows -ne [int]$entry.rows -or $facts.first -ne $entry.first -or $facts.last -ne $entry.last) {
      throw "REFUSE: golden feed identity/metadata mismatch $($entry.filename)"
    }
    $feedFacts += [ordered]@{ filename=$entry.filename; path=$path; facts=$facts }
  }
  $result = [ordered]@{
    schema='mgtt_orchestrator_offline/1'
    mode='Offline'
    status='PASS_HOST_ONLY'
    coverage=@('repository_identity','owner_authority','immutable_source','eleven_feed_bytes_and_metadata','vendor_trade_header')
    native_coverage='NOT_RUN'
    performance='NOT_RUN_NOT_AUTHORIZED'
    head=$head
    contract_sha256=(Get-Sha256 $contractPath)
    trade_mqh_sha256=(Get-Sha256 $tradeHeader)
    feeds=$feedFacts
    timestamp_utc=(Get-Date).ToUniversalTime().ToString('o')
  }
  Write-Receipt 'OFFLINE_RECEIPT.json' $result | Out-Null
  return $result
}

function Get-ProcessInventory {
  $names = @('terminal64','metatester64','metaeditor64')
  $rows = @()
  foreach ($name in $names) {
    foreach ($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
      $path = $null
      try { $path = $process.Path } catch { $path = 'UNRESOLVED' }
      $rows += [ordered]@{ name=$name; pid=$process.Id; path=$path }
    }
  }
  return $rows
}

function Get-OwnershipMap {
  $map = @{}
  if (!$DependencyOwnershipReceipt) { return $map }
  if (!(Test-Path -LiteralPath $DependencyOwnershipReceipt -PathType Leaf)) {
    throw "REFUSE: dependency ownership receipt missing $DependencyOwnershipReceipt"
  }
  $receipt = Get-Content -Raw -LiteralPath $DependencyOwnershipReceipt | ConvertFrom-Json
  if ($receipt.lane_id -ne $LaneId) { throw 'REFUSE: dependency ownership receipt lane mismatch' }
  foreach ($entry in $receipt.entries) { $map[[IO.Path]::GetFullPath($entry.path)] = $entry.sha256 }
  return $map
}

function Invoke-PreflightValidation {
  $offline = Invoke-OfflineValidation
  $lanePath = Join-Path $RegistryRoot ($LaneId + '.json')
  if (!(Test-Path -LiteralPath $lanePath -PathType Leaf)) { throw "REFUSE: Registry lane missing $lanePath" }
  $lane = Get-Content -Raw -LiteralPath $lanePath | ConvertFrom-Json
  if ($lane.lane_id -ne $LaneId -or !$lane.writer -or $lane.state -notin @('BLOCKED','RUNNING')) { throw 'REFUSE: Registry source owner/state mismatch' }
  if ([IO.Path]::GetFullPath($lane.worktree) -ne [IO.Path]::GetFullPath($RepoRoot)) { throw 'REFUSE: Registry source worktree mismatch' }
  if ($lane.base_sha -ne $authorBaseHead) { throw 'REFUSE: Registry source base mismatch' }

  $runtimeLanePath = Join-Path $RegistryRoot ($RuntimeLeaseLaneId + '.json')
  if (!(Test-Path -LiteralPath $runtimeLanePath -PathType Leaf)) { throw "REFUSE: runtime lease missing $runtimeLanePath" }
  $runtimeLease = Get-Content -Raw -LiteralPath $runtimeLanePath | ConvertFrom-Json
  if ($runtimeLease.lane_id -ne $RuntimeLeaseLaneId -or !$runtimeLease.writer -or $runtimeLease.state -ne 'RUNNING') { throw 'REFUSE: runtime lease owner/state mismatch' }
  if ($runtimeLease.runtime_lane -ne 'MT5-lane1') { throw 'REFUSE: MT5-lane1 runtime reservation is absent' }
  if ($runtimeLease.head_sha -ne $requiredWorktreeHead) { throw 'REFUSE: runtime lease head mismatch' }
  if (@($runtimeLease.dependencies) -notcontains $LaneId) { throw 'REFUSE: runtime lease dependency mismatch' }

  $processes = @(Get-ProcessInventory)
  if ($processes.Count -ne 0) {
    Write-Receipt 'PREFLIGHT_PROCESS_CONFLICT.json' ([ordered]@{ status='REFUSE_PROCESS_CONFLICT'; processes=$processes }) | Out-Null
    throw 'REFUSE: competing or unresolved terminal/tester/editor process exists; do not start, stop, attach, or kill it'
  }
  foreach ($path in @($Terminal,$MetaEditor,(Join-Path $RepoRoot 'scripts\mt5_run.ps1'))) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "REFUSE: native prerequisite missing $path" }
  }

  $ownership = Get-OwnershipMap
  $expectations = Get-Content -Raw -LiteralPath $expectationPath | ConvertFrom-Json
  $terminalFiles = Join-Path $DataDir 'MQL5\Files'
  foreach ($entry in $expectations.entries) {
    $path = [IO.Path]::GetFullPath((Join-Path $terminalFiles $entry.filename))
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      if (!$ownership.ContainsKey($path)) { throw "REFUSE: existing dependency is unowned $path" }
      if ($ownership[$path] -ne $entry.sha256 -or (Get-Sha256 $path) -ne $entry.sha256) {
        throw "REFUSE: owned dependency identity conflict $path"
      }
    }
  }
  $missingAlias = Join-Path $terminalFiles 'EA_LAB_MGTT_Q1_missing.csv'
  if (Test-Path -LiteralPath $missingAlias) { throw "REFUSE: missing-case alias residue exists $missingAlias" }
  $testerRoot = Join-Path (Split-Path (Split-Path $DataDir -Parent) -Parent) ('Tester\' + (Split-Path $DataDir -Leaf))
  $agentResidue = @(Get-ChildItem -LiteralPath $testerRoot -Recurse -Filter 'EA_LAB_MGTT_Q1_missing.csv' -ErrorAction SilentlyContinue)
  if ($agentResidue.Count -ne 0) { throw 'REFUSE: missing-case alias exists in a selected-agent sandbox; do not inject/delete it' }

  $result = [ordered]@{
    schema='mgtt_orchestrator_preflight/1'
    mode='Preflight'
    status='PASS_NATIVE_READY_NO_PROCESS_STARTED'
    lane_id=$LaneId
    owner_chat=$runtimeLease.owner_chat
    runtime_lane=$runtimeLease.runtime_lane
    process_inventory=$processes
    terminal_sha256=(Get-Sha256 $Terminal)
    metaeditor_sha256=(Get-Sha256 $MetaEditor)
    dependency_ownership_receipt=$DependencyOwnershipReceipt
    timestamp_utc=(Get-Date).ToUniversalTime().ToString('o')
  }
  Write-Receipt 'PREFLIGHT_RECEIPT.json' $result | Out-Null
  return $result
}

function New-ProbeCaseSource([string]$Template,[hashtable]$Case) {
  $block = @"
#property tester_file "$($Case.filename)"
#define MGTT_PROBE_FILENAME "$($Case.filename)"
#define MGTT_PROBE_EXPECTED_FILENAME "$($Case.filename)"
#define MGTT_PROBE_EXPECTED_SHA256 "$($Case.expected_sha256)"
#define MGTT_PROBE_EXPECTED_BYTES $($Case.expected_bytes)
#define MGTT_PROBE_EXPECTED_ROWS $($Case.expected_rows)
#define MGTT_PROBE_EXPECTED_FIRST "$($Case.expected_first)"
#define MGTT_PROBE_EXPECTED_LAST "$($Case.expected_last)"
"@
  $pattern = '(?s)(?<=// MGTT_PROBE_CASE_BEGIN).*?(?=// MGTT_PROBE_CASE_END)'
  return [regex]::Replace($Template,$pattern,"`r`n$block")
}

function Assert-CompileResult([string]$Source,[string]$Log) {
  $args = @('/compile:"' + $Source + '"','/log:"' + $Log + '"')
  $process = Start-Process -FilePath $MetaEditor -ArgumentList $args -WindowStyle Hidden -PassThru
  if (!$process.WaitForExit(120000)) { throw "REFUSE: compile still running PID=$($process.Id); process was not killed" }
  if (!(Test-Path -LiteralPath $Log -PathType Leaf)) { throw "COMPILE_FAIL no log $Log" }
  $text = Get-Content -Raw -LiteralPath $Log
  if ($text -notmatch 'Result:\s*0\s+errors?,\s*0\s+warnings?') { throw "COMPILE_FAIL $Log" }
  $ex5 = [IO.Path]::ChangeExtension($Source,'.ex5')
  if (!(Test-Path -LiteralPath $ex5 -PathType Leaf)) { throw "COMPILE_FAIL missing EX5 $ex5" }
  return $ex5
}

function Open-ReadShareOnly([string[]]$Paths) {
  $handles = New-Object Collections.Generic.List[IO.FileStream]
  foreach ($path in $Paths) {
    $handles.Add([IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read))
  }
  return $handles
}

function Invoke-NativeQualification {
  if (!$ConfirmNativeNoPerformance) { throw 'REFUSE: Native requires -ConfirmNativeNoPerformance' }
  $preflight = Invoke-PreflightValidation
  $runId = 'ORDER-MGTT-QUAL-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
  $nativeRoot = Join-Path $DataDir ('MQL5\Experts\EA_LAB_TEST\' + $runId)
  if (Test-Path -LiteralPath $nativeRoot) { throw "REFUSE: order-owned native root already exists $nativeRoot" }
  New-Item -ItemType Directory -Path $nativeRoot | Out-Null
  Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_template') -Destination $nativeRoot -Recurse
  New-Item -ItemType Directory -Path (Join-Path $nativeRoot 'scripts\_test') -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\_test\macrogate_tester_transfer_probe.mq5') -Destination (Join-Path $nativeRoot 'scripts\_test\macrogate_tester_transfer_probe.mq5')

  $bossControl = Join-Path $nativeRoot 'ea_template\Boss_15_ST03.mq5'
  $bossQual = Join-Path $nativeRoot 'ea_template\Boss_15_ST03_QUAL.mq5'
  $bossText = Get-Content -Raw -LiteralPath $bossControl
  [IO.File]::WriteAllText($bossQual,"#define LAB_MG_TESTER_EVIDENCE_QUAL`r`n" + $bossText,[Text.UTF8Encoding]::new($false))

  $expectations = Get-Content -Raw -LiteralPath $expectationPath | ConvertFrom-Json
  $terminalFiles = Join-Path $DataDir 'MQL5\Files'
  New-Item -ItemType Directory -Force -Path $terminalFiles | Out-Null
  $ownedEntries = @()
  foreach ($entry in $expectations.entries) {
    $source = Join-Path $RepoRoot $entry.source_path
    $target = Join-Path $terminalFiles $entry.filename
    if (!(Test-Path -LiteralPath $target)) {
      Copy-Item -LiteralPath $source -Destination $target
    }
    if ((Get-Sha256 $target) -ne $entry.sha256) { throw "REFUSE: dependency changed before compile $target" }
    $ownedEntries += [ordered]@{ path=$target; sha256=$entry.sha256 }
  }
  Write-Receipt 'NATIVE_DEPENDENCY_OWNERSHIP.json' ([ordered]@{ schema='mgtt_dependency_ownership/1'; lane_id=$LaneId; entries=$ownedEntries }) | Out-Null

  $controlEx5 = Assert-CompileResult $bossControl (Join-Path $evidenceFull 'Boss15_CONTROL.compile.log')
  $qualEx5 = Assert-CompileResult $bossQual (Join-Path $evidenceFull 'Boss15_QUAL.compile.log')
  $compileReceipt = [ordered]@{
    schema='mgtt_compile_receipt/1'; control_source=$bossControl; control_source_sha256=(Get-Sha256 $bossControl)
    control_ex5=$controlEx5; control_ex5_sha256=(Get-Sha256 $controlEx5)
    qualification_source=$bossQual; qualification_source_sha256=(Get-Sha256 $bossQual)
    qualification_ex5=$qualEx5; qualification_ex5_sha256=(Get-Sha256 $qualEx5)
    trade_mqh_sha256=(Get-Sha256 $tradeHeader); terminal_sha256=(Get-Sha256 $Terminal)
    metaeditor_sha256=(Get-Sha256 $MetaEditor); dependencies=$ownedEntries
  }
  Write-Receipt 'COMPILE_RECEIPT.json' $compileReceipt | Out-Null

  $real = $expectations.entries[0]
  $cases = @(
    @{ id='POSITIVE_GOLDEN_REAL'; filename=$real.filename; expected_sha256=$real.sha256; expected_bytes=$real.bytes; expected_rows=$real.rows; expected_first=$real.first; expected_last=$real.last; expected_failure=''; fixture='GOLDEN' },
    @{ id='MISSING'; filename='EA_LAB_MGTT_Q1_missing.csv'; expected_sha256=$real.sha256; expected_bytes=$real.bytes; expected_rows=$real.rows; expected_first=$real.first; expected_last=$real.last; expected_failure='MISSING'; fixture='MISSING' },
    @{ id='WRONG_SAME_METADATA'; filename=$real.filename; expected_sha256=$real.sha256; expected_bytes=$real.bytes; expected_rows=$real.rows; expected_first=$real.first; expected_last=$real.last; expected_failure='HASH_MISMATCH'; fixture='WRONG' },
    @{ id='STALE_TRUNCATED_COPY'; filename=$real.filename; expected_sha256=$real.sha256; expected_bytes=$real.bytes; expected_rows=$real.rows; expected_first=$real.first; expected_last=$real.last; expected_failure='SIZE_MISMATCH'; fixture='TRUNCATED' }
  )
  $probeTemplate = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'scripts\_test\macrogate_tester_transfer_probe.mq5')
  $realBytes = [IO.File]::ReadAllBytes((Join-Path $RepoRoot $real.source_path))
  $results = @()
  foreach ($case in $cases) {
    if (@(Get-ProcessInventory).Count -ne 0) { throw 'REFUSE: process appeared before probe; no process killed' }
    $dependency = Join-Path $terminalFiles $case.filename
    $restoreGolden = ($case.filename -eq $real.filename)
    try {
    if ($case.fixture -eq 'MISSING') {
      if (Test-Path -LiteralPath $dependency) { throw "REFUSE: missing fixture path exists $dependency" }
    } elseif ($case.fixture -eq 'GOLDEN') {
      [IO.File]::WriteAllBytes($dependency,$realBytes)
    } elseif ($case.fixture -eq 'WRONG') {
      $fixture = [byte[]]$realBytes.Clone()
      $needle = [Text.Encoding]::ASCII.GetBytes(' 02:')
      $hits = 0
      for ($i=0; $i -le $fixture.Length-$needle.Length; $i++) {
        $match=$true; for ($j=0;$j -lt $needle.Length;$j++) { if ($fixture[$i+$j] -ne $needle[$j]) { $match=$false; break } }
        if ($match) { $hits++; if ($hits -eq 2) { $fixture[$i+1]=[byte][char]'0'; $fixture[$i+2]=[byte][char]'3'; break } }
      }
      if (([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($fixture))).Replace('-','').ToLowerInvariant() -ne '7e1dbd8e3850c5d14858c7183d9f842767bbe0e33d16ed148be4fbd9dc84f5e4') { throw 'REFUSE: WRONG derivation mismatch' }
      [IO.File]::WriteAllBytes($dependency,$fixture)
    } else {
      $lastLf=[Array]::LastIndexOf($realBytes,[byte]10,$realBytes.Length-2)
      if ($lastLf -lt 0) { throw 'REFUSE: cannot derive truncated fixture' }
      $fixture=New-Object byte[] ($lastLf+1)
      [Array]::Copy($realBytes,$fixture,$fixture.Length)
      if (([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($fixture))).Replace('-','').ToLowerInvariant() -ne '70271717ee95f618a2d76b2b0a8d1ca2d8da9edf2cc9a079b74d4ea90e484e19') { throw 'REFUSE: TRUNCATED derivation mismatch' }
      [IO.File]::WriteAllBytes($dependency,$fixture)
    }

    $caseSource = Join-Path $nativeRoot ('scripts\_test\MGTT_' + $case.id + '.mq5')
    [IO.File]::WriteAllText($caseSource,(New-ProbeCaseSource $probeTemplate $case),[Text.UTF8Encoding]::new($false))
    $caseLog = Join-Path $evidenceFull ($case.id + '.compile.log')
    $caseEx5 = Assert-CompileResult $caseSource $caseLog
    $prelaunch = [ordered]@{
      case=$case.id; source=$caseSource; source_sha256=(Get-Sha256 $caseSource)
      ex5=$caseEx5; ex5_sha256=(Get-Sha256 $caseEx5); dependency=$dependency
      dependency_sha256=if (Test-Path -LiteralPath $dependency) { Get-Sha256 $dependency } else { $null }
      expected_failure=$case.expected_failure; model='M1_M1_OHLC_ENGINEERING_NO_PERFORMANCE'
      symbol='GBPUSD'; timeframe='H4'; from='2020.01.02'; to='2020.01.03'
    }
    Write-Receipt ($case.id + '.PRELAUNCH.json') $prelaunch | Out-Null
    $holdPaths=@($caseSource,$caseEx5)
    if (Test-Path -LiteralPath $dependency) { $holdPaths += $dependency }
    $handles=Open-ReadShareOnly $holdPaths
    try {
      $relative = $caseEx5.Substring((Join-Path $DataDir 'MQL5\Experts').Length+1).Replace('\','/')
      if(!$relative.EndsWith('.ex5',[StringComparison]::OrdinalIgnoreCase)) { throw "REFUSE: probe EX5 suffix missing $relative" }
      $relative = $relative.Substring(0,$relative.Length-4).Replace('/','\')
      $started=Get-Date
      $output=(& (Join-Path $RepoRoot 'scripts\mt5_run.ps1') -Expert $relative -Symbol GBPUSD -Period H4 -FromDate 2020.01.02 -ToDate 2020.01.03 -Model 1 -ReportName ('MGTT_'+$case.id) -Terminal $Terminal -DataDir $DataDir -TimeoutSec 180 -AllowLegacyIdentity 2>&1 | Out-String)
      $exitCode=$LASTEXITCODE
      $testerRoot = Join-Path (Split-Path (Split-Path $DataDir -Parent) -Parent) ('Tester\' + (Split-Path $DataDir -Leaf))
      $logs=@(Get-ChildItem -LiteralPath $testerRoot -Recurse -Filter '*.log' -ErrorAction SilentlyContinue | Where-Object LastWriteTime -ge $started)
      $logText=($logs | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
      $caseTag='MGTT_' + $case.id
      $caseLogText=(($logText -split "`r?`n") | Where-Object { $_ -match [regex]::Escape($caseTag) }) -join "`n"
      if ($case.expected_failure) {
        if ($caseLogText -notmatch ('failure=' + [regex]::Escape($case.expected_failure)) -or $caseLogText -match 'LOAD_PASS_NO_TRADES') { throw "PROBE_FAIL $($case.id)" }
      } else {
        if ($exitCode -ne 0 -or
            $caseLogText -notmatch 'load_status=PASS' -or
            $caseLogText -notmatch 'LOAD_PASS_NO_TRADES' -or
            $caseLogText -notmatch 'CERTIFIED_COUNTS_PASS self_gate=0 no_order_send=1' -or
            $caseLogText -notmatch 'ADVERSARIAL_FAIL_CLOSED_PASS' -or
            $caseLogText -notmatch 'event=RUN_BEGIN.*MG_SelfGate=0') { throw "PROBE_FAIL $($case.id)" }
      }
      $results += [ordered]@{ case=$case.id; status='PASS_ENGINEERING'; exit_code=$exitCode; output=$output.Trim(); logs=@($logs.FullName) }
    } finally {
      foreach ($handle in $handles) { $handle.Dispose() }
    }
    } finally {
      # Every deliberate mutation is restored even if derivation, compile,
      # launch, log collection or marker validation fails midway.
      if ($restoreGolden -and (Test-Path -LiteralPath $dependency)) {
        $currentDependencySha = Get-Sha256 $dependency
        $ownedCaseHashes = @(
          $real.sha256,
          '7e1dbd8e3850c5d14858c7183d9f842767bbe0e33d16ed148be4fbd9dc84f5e4',
          '70271717ee95f618a2d76b2b0a8d1ca2d8da9edf2cc9a079b74d4ea90e484e19'
        )
        if ($ownedCaseHashes -notcontains $currentDependencySha) {
          throw "REFUSE: dependency ownership changed during case; not restoring/overwriting $dependency"
        }
        if ($currentDependencySha -ne $real.sha256) {
          [IO.File]::WriteAllBytes($dependency,$realBytes)
        }
      }
    }
  }
  $result=[ordered]@{ schema='mgtt_native_qualification/1'; status='PASS_NO_PERFORMANCE'; compile_receipt=$compileReceipt; probe_results=$results; native_root=$nativeRoot }
  Write-Receipt 'NATIVE_RESULT.json' $result | Out-Null
  return $result
}

try {
  if ($Mode -eq 'Offline') { $result = Invoke-OfflineValidation }
  elseif ($Mode -eq 'Preflight') { $result = Invoke-PreflightValidation }
  else { $result = Invoke-NativeQualification }
  $result | ConvertTo-Json -Depth 20
  exit 0
} catch {
  $failure=[ordered]@{ schema='mgtt_orchestrator_failure/1'; mode=$Mode; status='REFUSE'; error=$_.Exception.Message; native_process_action='NO_KILL_NO_FORCE'; performance='NOT_RUN' }
  Write-Receipt ($Mode.ToUpperInvariant() + '_FAILURE.json') $failure | Out-Null
  $failure | ConvertTo-Json -Depth 10
  exit 1
}
