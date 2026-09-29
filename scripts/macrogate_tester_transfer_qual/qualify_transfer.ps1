<#
Fail-closed MacroGate tester-transfer engineering qualification.

Offline validates exact committed source, the complete compile include closure,
the frozen full .set identity and feed bytes. Preflight additionally requires a
current runtime lease and an idle selected installation. Native compiles and
runs four no-order probes only. It never interprets performance, writes Common,
injects an Agent sandbox, kills a process, or uses legacy identity bypasses.
#>
[CmdletBinding()]
param(
  [ValidateSet('Offline','Preflight','Native')][string]$Mode = 'Offline',
  [string]$RepoRoot = '',
  [string]$EvidenceRoot = '',
  [Parameter(Mandatory)][string]$SourceCommit,
  [string]$ExpectedParent = '9147e4545ff6d4568a5d9d3d4b883ed832fc2cdd',
  [string]$LaneId = 'ct-news-macro-mgtt-runner-handle-retention-v3-20260928',
  [string]$RuntimeLeaseLaneId = 'ct-mgtt-runner-handle-retention-v3-native-runtime-20260928',
  [string]$RuntimeLeaseRecordId = '',
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
if (!$RuntimeLeaseRecordId) { $RuntimeLeaseRecordId = $RuntimeLeaseLaneId }
. (Join-Path $RepoRoot 'scripts\lib\evidence.ps1')
. (Join-Path $RepoRoot 'scripts\lib\setfile_surface.ps1')
. (Join-Path $RepoRoot 'scripts\lib\build_receipt.ps1')
. (Join-Path $RepoRoot 'scripts\lib\report_freshness.ps1')

$frozenControl = 'b586d4d32c04fa33a30517ab3a1a8469b238d2ac'
$admissionBaseTree = '1b0a45c014a25969679dd59c0c88218e47a7ac33'
$historicalPrefix = 'D:\EA_LAB_CONTROL\evidence\mg-tester-transfer-impl-v1-20260927'
$a1EvidencePrefix = 'D:\EA_LAB_CONTROL\evidence\mgtt-shortlived-tester-identity-v1-20260928'
$predecessorEvidencePrefix = 'D:\EA_LAB_CONTROL\evidence\mgtt-capture-normalization-v2-20260928'
$externalPrefix = 'D:\EA_LAB_CONTROL\evidence\mgtt-runner-handle-retention-v3-20260928'
$handleRcaPath = 'D:\EA_LAB_CONTROL\evidence\mgtt-runner-exit-handle-rca-20260928\CT_RUNNER_EXIT_HANDLE_RCA.json'
$currentOwnerAuthoritySha256 = 'f7f556d073d0d8aceaea6f4e2ee15d71c6670e839541c48226aa6f5a131168e4'
if (!$EvidenceRoot) { $EvidenceRoot = Join-Path $externalPrefix ('requal-' + $SourceCommit.Substring(0,12) + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$evidenceFull = [IO.Path]::GetFullPath($EvidenceRoot)
$externalFull = [IO.Path]::GetFullPath($externalPrefix).TrimEnd('\') + '\'
if (!$evidenceFull.StartsWith($externalFull,[StringComparison]::OrdinalIgnoreCase)) { throw "REFUSE: EvidenceRoot must remain below $externalPrefix" }
New-Item -ItemType Directory -Force -Path $evidenceFull | Out-Null

$contractRoot = Join-Path $RepoRoot 'factory\runs\news_macro_macrogate_tester_transfer_qual_v1_20260926'
$contractPath = Join-Path $contractRoot 'PROSPECTIVE_IMPLEMENTATION_CONTRACT.json'
$expectationPath = Join-Path $contractRoot 'FEED_RUNTIME_EXPECTATIONS.json'
$sourceBindingPath = Join-Path $contractRoot 'SOURCE_BINDING.json'
$originalAuthPath = Join-Path $historicalPrefix 'OWNER_AUTHORIZATION.json'
$repairAuthPath = Join-Path $historicalPrefix 'PRECOMMIT_EXACT_TREE_OWNER_AUTH_20260927.json'
$originalAuthSha256 = '6b7057b94d5720daec7f39d800fe589d888fe3df1d44111e2ace11213cd8eea7'
$repairAuthSha256 = '6eb92e95f51f74e4827640b9d0946e62d30bc77c07e23519d075293b5c02146a'
$setRelative = 'ea_template/sets/regression/Boss_15_ST03_defaults.set'
$probeRelative = 'scripts/_test/macrogate_tester_transfer_probe.mq5'
$bossRelative = 'ea_template/Boss_15_ST03.mq5'
$vendorRoot = Join-Path $DataDir 'MQL5\Include'
$tradeHeader = Join-Path $vendorRoot 'Trade\Trade.mqh'
$allowedRepairPaths = @(
  'scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1',
  'scripts/_test/test_macrogate_tester_transfer_contract.py'
)
$behavioralPaths = @('ea_template/Boss_15_ST03.mq5','ea_template/core/LabCore.mqh','ea_template/core/MacroGate_Core.mqh','ea_template/core/Execution.mqh')

function Get-Sha256([string]$Path) {
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "MISSING_FILE $Path" }
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}
function Get-BytesSha256([byte[]]$Bytes) {
  $sha=[Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
}
function Write-Receipt([string]$Name,[object]$Value) {
  $path=Join-Path $evidenceFull $Name
  $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $path -Encoding UTF8
  return $path
}
function Get-GitBytes([string]$Commit,[string]$Relative) {
  if ($Relative -notmatch '^[A-Za-z0-9_. /-]+$' -or $Relative.Contains('..')) { throw "REFUSE: unsafe Git path $Relative" }
  $result=Invoke-EvidenceGitBytes -RepoRoot $RepoRoot -Arguments ('show "{0}:{1}"' -f $Commit,$Relative)
  if ($result.ExitCode -ne 0) { throw "REFUSE: exact Git bytes unavailable $Commit`:$Relative" }
  return [byte[]]$result.Bytes
}
function Get-ExecutableIdentity([string]$Path,[object]$Process=$null) {
  $item=Get-Item -LiteralPath $Path -Force
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "REFUSE: executable is a reparse path $Path" }
  $row=[ordered]@{path=$item.FullName;sha256=(Get-Sha256 $item.FullName);length=$item.Length;file_version=$item.VersionInfo.FileVersion;product_version=$item.VersionInfo.ProductVersion}
  if ($null -ne $Process) { $row.pid=$Process.Id; try { $row.creation_time_utc=$Process.StartTime.ToUniversalTime().ToString('o') } catch { $row.creation_time_utc='UNAVAILABLE' } }
  return $row
}
function Assert-CurrentContractIdentity(
  [string]$AdmissionBase,
  [string]$SourceLane,
  [string]$RuntimeLogicalLane,
  [string]$RuntimeRecordLane,
  [string]$PredecessorEvidenceRoot,
  [string]$CurrentEvidenceRoot
) {
  $requiredBase='9147e4545ff6d4568a5d9d3d4b883ed832fc2cdd'
  $requiredLane='ct-news-macro-mgtt-runner-handle-retention-v3-20260928'
  $requiredRuntime='ct-mgtt-runner-handle-retention-v3-native-runtime-20260928'
  $requiredPredecessor='D:\EA_LAB_CONTROL\evidence\mgtt-capture-normalization-v2-20260928'
  $requiredCurrent='D:\EA_LAB_CONTROL\evidence\mgtt-runner-handle-retention-v3-20260928'
  if(
    $AdmissionBase -cne $requiredBase -or
    $SourceLane -cne $requiredLane -or
    $RuntimeLogicalLane -cne $requiredRuntime -or
    $RuntimeRecordLane -cne $requiredRuntime -or
    [IO.Path]::GetFullPath($PredecessorEvidenceRoot) -ine [IO.Path]::GetFullPath($requiredPredecessor) -or
    [IO.Path]::GetFullPath($CurrentEvidenceRoot) -ine [IO.Path]::GetFullPath($requiredCurrent)
  ) { throw 'REFUSE: current frozen contract identity mismatch' }
  return [ordered]@{
    admission_base=$AdmissionBase
    source_lane=$SourceLane
    runtime_logical_lane=$RuntimeLogicalLane
    runtime_record_lane=$RuntimeRecordLane
    predecessor_evidence_root=[IO.Path]::GetFullPath($PredecessorEvidenceRoot)
    current_evidence_root=[IO.Path]::GetFullPath($CurrentEvidenceRoot)
  }
}
function Assert-ExactSourceCommit {
  if ($SourceCommit -cnotmatch '^[0-9a-f]{40}$' -or $ExpectedParent -cnotmatch '^[0-9a-f]{40}$') { throw 'REFUSE: SourceCommit/ExpectedParent must be lowercase 40-hex IDs' }
  $type=(& git -C $RepoRoot cat-file -t $SourceCommit 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $type -cne 'commit') { throw 'REFUSE: SourceCommit is not a commit object' }
  $head=(& git -C $RepoRoot rev-parse HEAD 2>$null).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -cne $SourceCommit) { throw "REFUSE: HEAD must equal SourceCommit $SourceCommit" }
  $parents=@((& git -C $RepoRoot rev-list --parents -n 1 $SourceCommit 2>$null) -split ' ')
  if ($LASTEXITCODE -ne 0 -or $parents.Count -ne 2 -or $parents[1] -cne $ExpectedParent) { throw 'REFUSE: SourceCommit must be the single immediate child of the owner-frozen admission base' }
  if ($ExpectedParent -cne '9147e4545ff6d4568a5d9d3d4b883ed832fc2cdd') { throw 'REFUSE: wrong owner-frozen admission base' }
  if ((& git -C $RepoRoot rev-parse ($ExpectedParent+'^{tree}')).Trim() -cne $admissionBaseTree) { throw 'REFUSE: admission base tree mismatch' }
  & git -C $RepoRoot merge-base --is-ancestor $frozenControl $ExpectedParent 2>$null
  if ($LASTEXITCODE -ne 0) { throw 'REFUSE: frozen control is not an ancestor of the admission base' }
  $dirty=@(& git -C $RepoRoot status --porcelain=v1 --untracked-files=all 2>$null)
  if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) { throw 'REFUSE: exact-source qualification requires a completely clean SourceCommit worktree' }
  $changed=@(& git -C $RepoRoot diff --name-only ($ExpectedParent+'..'+$SourceCommit) 2>$null)
  if ($LASTEXITCODE -ne 0 -or $changed.Count -ne $allowedRepairPaths.Count) { throw 'REFUSE: V3 lineage delta must contain exactly the two declared paths' }
  foreach($path in $changed) { if ($allowedRepairPaths -cnotcontains $path) { throw "REFUSE: final commit changes an undeclared path $path" } }
  foreach($path in $allowedRepairPaths) { if ($changed -cnotcontains $path) { throw "REFUSE: final commit is missing declared path $path" } }
  $behavioral=@(& git -C $RepoRoot diff --name-only ($frozenControl+'..'+$SourceCommit) -- ea_template 2>$null | Where-Object { $_ -match '^(ea_template/(core|modules|generated)/|ea_template/Boss_.*\.mq5$|ea_template/EA_LabTemplate\.mq5$)' })
  if ($behavioral.Count -ne 4) { throw 'REFUSE: final source has other than four behavioral deltas from frozen control' }
  foreach($path in $behavioralPaths) { if ($behavioral -cnotcontains $path) { throw "REFUSE: missing owner-frozen behavioral delta $path" } }
  return [ordered]@{head=$head;admission_base=$ExpectedParent;admission_base_tree=$admissionBaseTree;control=$frozenControl;changed_paths=$changed;behavioral_paths=$behavioral}
}
function Get-RepoTree {
  $raw=Invoke-EvidenceGitBytes -RepoRoot $RepoRoot -Arguments "ls-tree -r -z $SourceCommit"
  if ($raw.ExitCode -ne 0) { throw 'REFUSE: SourceCommit tree unavailable' }
  $map=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
  $folded=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  foreach($row in ([Text.UTF8Encoding]::new($false,$true)).GetString($raw.Bytes).Split([char]0)) {
    if(!$row){continue}; if($row -notmatch '^(100644|100755) blob ([0-9a-f]{40})\t(.+)$'){throw 'REFUSE: SourceCommit contains a nonregular entry'}
    $path=$Matches[3]; if(!$folded.Add($path)){throw "REFUSE: case-ambiguous SourceCommit path $path"}; $map.Add($path,[pscustomobject]@{mode=$Matches[1];blob=$Matches[2]})
  }
  return ,$map
}
function Resolve-RepoInclude([string]$From,[string]$Include,[object]$Tree) {
  $base=Split-Path ($From -replace '/','\') -Parent
  $full=[IO.Path]::GetFullPath((Join-Path $RepoRoot (Join-Path $base ($Include -replace '/','\'))))
  $prefix=[IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')+'\'
  if(!$full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "REFUSE: include escapes Git source $From -> $Include"}
  $rel=$full.Substring($prefix.Length).Replace('\','/')
  if(!$Tree.ContainsKey($rel)){throw "REFUSE: include missing or case-aliased in SourceCommit $From -> $Include"}
  return $rel
}
function Resolve-VendorInclude([string]$From,[string]$Include) {
  $base=if($From){Split-Path $From -Parent}else{$vendorRoot}
  $full=[IO.Path]::GetFullPath((Join-Path $base ($Include -replace '/','\')))
  $prefix=[IO.Path]::GetFullPath($vendorRoot).TrimEnd('\')+'\'
  if(!$full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or !(Test-Path -LiteralPath $full -PathType Leaf)){throw "REFUSE: vendor include unavailable $Include"}
  $cursor=$vendorRoot
  foreach($part in $full.Substring($prefix.Length).Split('\')) { $cursor=Join-Path $cursor $part; $item=Get-Item -LiteralPath $cursor -Force; if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $item.Name -cne $part){throw "REFUSE: vendor include reparse/case alias $full"} }
  return $full
}
function Get-CompileClosure {
  $tree=Get-RepoTree; $queue=New-Object Collections.Generic.Queue[object]
  $queue.Enqueue([pscustomobject]@{kind='repo';path=$bossRelative}); $queue.Enqueue([pscustomobject]@{kind='repo';path=$probeRelative})
  $seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal); $repoEntries=New-Object Collections.Generic.List[object]; $vendorEntries=New-Object Collections.Generic.List[object]
  while($queue.Count -gt 0) {
    $item=$queue.Dequeue(); $key=$item.kind+'|'+$item.path; if(!$seen.Add($key)){continue}
    if($item.kind -eq 'repo') {
      if(!$tree.ContainsKey($item.path)){throw "REFUSE: closure source missing $($item.path)"}; $bytes=Get-GitBytes $SourceCommit $item.path
      $repoEntries.Add([pscustomobject]@{kind='repo';path=$item.path;git_blob=$tree[$item.path].blob;sha256=(Get-BytesSha256 $bytes);bytes=$bytes.Length}); $text=[Text.Encoding]::UTF8.GetString($bytes)
      foreach($m in [regex]::Matches($text,'(?m)^\s*#include\s*([<"])([^>"]+)[>"]')) { if($m.Groups[1].Value -eq '<'){$queue.Enqueue([pscustomobject]@{kind='vendor';path=(Resolve-VendorInclude '' $m.Groups[2].Value)})}else{$queue.Enqueue([pscustomobject]@{kind='repo';path=(Resolve-RepoInclude $item.path $m.Groups[2].Value $tree)})} }
    } else {
      $bytes=[IO.File]::ReadAllBytes($item.path); $vendorEntries.Add([pscustomobject]@{kind='vendor';path=$item.path;sha256=(Get-BytesSha256 $bytes);bytes=$bytes.Length}); $text=[Text.Encoding]::UTF8.GetString($bytes)
      foreach($m in [regex]::Matches($text,'(?m)^\s*#include\s*([<"])([^>"]+)[>"]')) { $next=if($m.Groups[1].Value -eq '<'){Resolve-VendorInclude '' $m.Groups[2].Value}else{Resolve-VendorInclude $item.path $m.Groups[2].Value}; $queue.Enqueue([pscustomobject]@{kind='vendor';path=$next}) }
    }
  }
  return [pscustomobject]@{repo=$repoEntries.ToArray();vendor=$vendorEntries.ToArray();tree=$tree}
}
function Get-FeedFacts([string]$Path) {
  $bytes=[IO.File]::ReadAllBytes($Path); $text=[Text.Encoding]::UTF8.GetString($bytes); if($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF){$text=$text.Substring(1)}; $valid=New-Object Collections.Generic.List[string]
  foreach($line in @($text -split "`r?`n" | Select-Object -Skip 1)) { $f=$line.Split(','); if($f.Count -lt 2){continue}; $when=[datetime]::MinValue; if([datetime]::TryParseExact($f[0].Trim(),'yyyy.MM.dd HH:mm',[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$when) -and @('RISK_ON','NEUTRAL','RISK_OFF','STRESS','UNKNOWN') -contains $f[1].Trim().ToUpperInvariant()){$valid.Add($f[0].Trim())} }
  return [ordered]@{bytes=$bytes.Length;sha256=(Get-BytesSha256 $bytes);rows=$valid.Count;first=$valid[0];last=$valid[$valid.Count-1]}
}
function Get-FullSetIdentity {
  $bytes=Get-GitBytes $SourceCommit $setRelative; $stage=Join-Path $evidenceFull 'FROZEN_Boss_15_ST03_defaults.set'; [IO.File]::WriteAllBytes($stage,$bytes)
  if((Get-Sha256 $stage) -ne (Get-BytesSha256 $bytes)){throw 'REFUSE: staged full set mismatch'}; $surface=Get-SetSurfaceState -Path $stage; $identity=Get-SetConfigIdentity -Path $stage -Surface $surface
  if($surface.State -ne 'FULL' -or !$identity.Valid -or $surface.BuildTag -ne 'LAB_ENTRY_15' -or [int]$surface.Declared -ne [int]$surface.Assignments){throw 'REFUSE: Boss15 qualification set is not a full declared surface'}
  # The historical header is evidence only. Generate a successor-only set with
  # the same physical assignments and a prospectively computed current closure.
  $computed=Get-ProspectiveConfigIdentity $stage
  $diagnostic=Join-Path $evidenceFull 'SUCCESSOR_Boss_15_ST03_diagnostic.set'
  $text=[Text.Encoding]::UTF8.GetString($bytes)
  $text=[regex]::Replace($text,'effective_config_hash=[0-9a-f]{64}',('effective_config_hash='+$computed.fingerprint))
  [IO.File]::WriteAllText($diagnostic,$text,[Text.UTF8Encoding]::new($false))
  $verified=Get-ProspectiveConfigIdentity $diagnostic $computed.fingerprint
  $proof=[ordered]@{source_commit=$SourceCommit;historical_path=$stage;historical_sha256=(Get-Sha256 $stage);historical_header=$identity.ConfigFingerprint;historical_header_matches_current=($identity.ConfigFingerprint -ceq $computed.fingerprint);computed=$computed;diagnostic_path=$diagnostic;diagnostic_sha256=(Get-Sha256 $diagnostic);timestamp_utc=[DateTime]::UtcNow.ToString('o')}
  Write-Receipt 'PROSPECTIVE_CONFIG.json' $proof | Out-Null
  return [pscustomobject]@{path=$diagnostic;sha256=(Get-Sha256 $diagnostic);fingerprint=$verified.fingerprint;scope='surface+constants';build='LAB_ENTRY_15';keys=$verified.keys}
}
function Get-ProspectiveConfigIdentity([string]$SetPath,[string]$Expected='') {
  $configCalculator = @'
import sys, json, subprocess, hashlib, re
from collections import OrderedDict
from pathlib import Path

def mgtt_identity(read, set_text, expected=None):
    import preset, gen_locked_constants
    surface = preset.parse_surface(read('ea_template/core/Inputs.mqh'), 'LAB_ENTRY_15')
    values = {}
    for line in set_text.splitlines():
        if not line or line.startswith(';'):
            continue
        if '=' not in line or '||' in line:
            raise ValueError('REFUSE: non-literal full set')
        key, value = line.split('=', 1)
        if key in values:
            raise ValueError('REFUSE: duplicate input')
        values[key] = value
    if len(surface.inputs) != 157 or set(values) != set(surface.by_name):
        raise ValueError('REFUSE: expected exact current 157 input surface')
    ordered = OrderedDict((d.name, values[d.name]) for d in surface.inputs)
    constants = gen_locked_constants.constants_for(read, 'LAB_ENTRY_15', 'ea_template/Boss_15_ST03.mq5')
    if constants.get('CFG_FP_SCOPE') != 'surface+constants' or 'MG_ST_INVALID' not in constants:
        raise ValueError('REFUSE: incomplete locked constant closure')
    fingerprint = preset._fingerprint(surface, ordered, constants, 'surface+constants')
    if expected and fingerprint != expected:
        raise ValueError('CONFIG_MISMATCH expected=' + expected + ' computed=' + fingerprint)
    return dict(keys=len(ordered), inputs=ordered, constants=constants, fingerprint=fingerprint)

if __name__ == '__main__':
    root, commit, set_path, expected = sys.argv[1:5]
    sys.path.insert(0, str(Path(root) / '_triage/factory_os'))
    read = lambda path: subprocess.check_output(['git', '-C', root, 'show', commit + ':' + path]).decode('utf-8-sig')
    # No runtime marker, historical log or header supplies the computed digest.
    print(json.dumps(mgtt_identity(read, Path(set_path).read_text(encoding='utf-8-sig'), None if expected == '-' else expected)))
'@
  $calculatorPath=Join-Path $evidenceFull 'prospective_config.py'
  [IO.File]::WriteAllText($calculatorPath,$configCalculator,[Text.UTF8Encoding]::new($false))
  . (Join-Path $RepoRoot 'scripts\use_python.ps1')
  # Use the already-installed portable runtime without altering the source tree.
  $common=(& git -C $RepoRoot rev-parse --path-format=absolute --git-common-dir).Trim()
  $python=Assert-PortablePython -Root (Split-Path $common -Parent)
  $expectedArgument=if($Expected){$Expected}else{'-'}
  $json=& $python -B $calculatorPath $RepoRoot $SourceCommit $SetPath $expectedArgument
  if($LASTEXITCODE -ne 0){throw 'REFUSE: prospective config calculation failed'}
  return ($json | ConvertFrom-Json)
}
function Invoke-OfflineValidation {
  $contractIdentity=Assert-CurrentContractIdentity -AdmissionBase $ExpectedParent -SourceLane $LaneId -RuntimeLogicalLane $RuntimeLeaseLaneId -RuntimeRecordLane $RuntimeLeaseRecordId -PredecessorEvidenceRoot $predecessorEvidencePrefix -CurrentEvidenceRoot $externalPrefix
  $currentOwnerAuthorityPath=Join-Path $externalPrefix 'OWNER_AUTHORITY_20260928.json'
  $a1Pins=@(
    @('a1-closeout\A1_DURABLE_CHECKPOINT.json','c75d153511a529884141a542a5ba433ad90128065719d4e24b6439a29c94ed19'),
    @('a1-closeout\A1_FINAL_RECONCILIATION.json','5e8e4e55614bf642aca3fc8312b8df07dfe5122a616e19ab90f732ee41b00268'),
    @('a1-native-campaign\POSITIVE_GOLDEN_REAL.PROCESS_OBSERVATIONS.json','e9b0cec4c20bf8064cc8905f64ea62bf2b4c5968275d37cf66eef3ea7baf5ffe'),
    @('a1-native-campaign\POSITIVE_GOLDEN_REAL\POSITIVE_GOLDEN_REAL.RUNNER_EXIT.json','e7b0ed1c89b688e3c45750540b0c3c43d820c79a600eb48709958c8fe4ad58c6')
  )
  $v2Pins=@(
    @('CNV2_DURABLE_CHECKPOINT.json','52dffb679a96c7a7a61d132cadef716f6b2025946e1d40ecc79777b2a8d77d7f'),
    @('CNV2_FINAL_RECONCILIATION.json','a00fa655a3b2864352fc849f9c7b2b9b8dba1e1342795ed30fe4a65e6a0ea736'),
    @('CNV2_EVIDENCE_MANIFEST.json','30bf20119b4a258cae90903b09837e271f49e98a0429d1ffb2a9aed4a6d55f7f')
  )
  foreach($path in @($contractPath,$expectationPath,$sourceBindingPath,$originalAuthPath,$repairAuthPath,$tradeHeader,$currentOwnerAuthorityPath,$handleRcaPath)){if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw "REFUSE: required input missing $path"}}
  if((Get-Sha256 $originalAuthPath) -cne $originalAuthSha256 -or (Get-Sha256 $repairAuthPath) -cne $repairAuthSha256){throw 'REFUSE: owner authority bytes changed'}
  $source=Assert-ExactSourceCommit; $contract=Get-Content -Raw $contractPath|ConvertFrom-Json; $expectations=Get-Content -Raw $expectationPath|ConvertFrom-Json; $binding=Get-Content -Raw $sourceBindingPath|ConvertFrom-Json; $auth=Get-Content -Raw $originalAuthPath|ConvertFrom-Json; $repair=Get-Content -Raw $repairAuthPath|ConvertFrom-Json
  if($contract.schema -ne 'macrogate_tester_transfer_prospective_implementation_contract/2' -or !$auth.authorized_implementation -or $auth.authorized_performance){throw 'REFUSE: original implementation authority mismatch'}
  if($repair.schema -ne 'mgtt_precommit_exact_tree_owner_authority/1' -or $repair.repair_parent -ne '5845c4e039a3d9ef57e6997af42655a3d854d34e' -or $repair.current_control -ne $frozenControl -or $repair.performance_authorized){throw 'REFUSE: historical Repair1 owner authority mismatch'}
  foreach($pin in $a1Pins) {
    if((Get-Sha256 (Join-Path $a1EvidencePrefix $pin[0])) -cne $pin[1]){throw "REFUSE: predecessor A1 evidence drift $($pin[0])"}
  }
  foreach($pin in $v2Pins) {
    $path=Join-Path $predecessorEvidencePrefix $pin[0]
    if(!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -cne $pin[1]){throw "REFUSE: predecessor V2 evidence drift $($pin[0])"}
  }
  if((Get-Sha256 $handleRcaPath) -cne 'c4c26ac8b37ac30e69b7957f80baaf016efca5355ddac23ae826024fc739abe7'){throw 'REFUSE: accepted Process.Handle RCA bytes changed'}
  if((Get-Sha256 $currentOwnerAuthorityPath) -cne $currentOwnerAuthoritySha256){throw 'REFUSE: current V3 authority bytes changed'}
  $currentAuthority=Get-Content -Raw $currentOwnerAuthorityPath|ConvertFrom-Json
  $v2Checkpoint=Get-Content -Raw (Join-Path $predecessorEvidencePrefix 'CNV2_DURABLE_CHECKPOINT.json')|ConvertFrom-Json
  $allowedMutations=@($currentAuthority.allowlisted_source_paths)
  $authorizedCases=@($currentAuthority.native_budget.cases)
  if(
    $currentAuthority.schema -cne 'mgtt_runner_process_handle_retention_v3_owner_authority/1' -or
    $currentAuthority.contract_id -cne 'MGTT-RUNNER-PROCESS-HANDLE-RETENTION-V3-20260928' -or
    $currentAuthority.fresh_canonical_at_receipt -cne $frozenControl -or
    $currentAuthority.exact_base_commit -cne $ExpectedParent -or
    $currentAuthority.exact_base_tree -cne $admissionBaseTree -or
    $currentAuthority.predecessor_lane -cne 'ct-news-macro-mgtt-capture-normalization-v2-20260928' -or
    $currentAuthority.predecessor_native_budget -cne 'SPENT_NO_RETRY' -or
    [int]$currentAuthority.author_budget.final_author_commits -ne 1 -or
    [int]$currentAuthority.native_budget.campaigns -ne 1 -or
    [int]$currentAuthority.native_budget.retry_campaigns -ne 0 -or
    $currentAuthority.native_budget.runtime_lane -cne 'MT5-lane1' -or
    $currentAuthority.authority_ceiling.self_review -ne $false -or
    $currentAuthority.authority_ceiling.worker_push -ne $false -or
    $currentAuthority.authority_ceiling.performance -cne 'NOT_AUTHORIZED' -or
    $currentAuthority.authority_ceiling.bwd -cne 'NOT_AUTHORIZED' -or
    $currentAuthority.authority_ceiling.holdout -cne 'LOCKED_UNSPENT' -or
    $currentAuthority.authority_ceiling.live_or_trading -cne 'NOT_AUTHORIZED' -or
    $allowedMutations.Count -ne $allowedRepairPaths.Count -or
    $authorizedCases.Count -ne 4
  ){throw 'REFUSE: current V3 owner authority mismatch'}
  foreach($path in $allowedRepairPaths){if($allowedMutations -cnotcontains $path){throw "REFUSE: V3 authority missing allowed path $path"}}
  foreach($case in @('POSITIVE_GOLDEN_REAL','MISSING','WRONG_SAME_METADATA','STALE_TRUNCATED_COPY')){if($authorizedCases -cnotcontains $case){throw "REFUSE: V3 authority missing native case $case"}}
  if($v2Checkpoint.contract_id -cne 'MGTT-CAPTURE-NORMALIZATION-V2-20260928' -or $v2Checkpoint.lane_id -cne $currentAuthority.predecessor_lane -or $v2Checkpoint.author_head -cne $ExpectedParent -or $v2Checkpoint.author_tree -cne $admissionBaseTree -or $v2Checkpoint.native_budget_state -cne 'SPENT_NO_RETRY'){throw 'REFUSE: predecessor V2 checkpoint identity mismatch'}
  foreach($immutable in @('ea_template/core/Inputs.mqh','ea_template/core/ConfigFingerprint.mqh')) { $expected=@($binding.source_files|Where-Object path -eq $immutable); $bytes=Get-GitBytes $SourceCommit $immutable; if($expected.Count -ne 1 -or (Get-BytesSha256 $bytes) -ne $expected[0].sha256){throw "REFUSE: immutable source drift $immutable"} }
  $feeds=@(); foreach($entry in $expectations.entries){$facts=Get-FeedFacts (Join-Path $RepoRoot $entry.source_path);if($facts.sha256 -ne $entry.sha256 -or $facts.bytes -ne [int64]$entry.bytes -or $facts.rows -ne [int]$entry.rows -or $facts.first -ne $entry.first -or $facts.last -ne $entry.last){throw "REFUSE: feed identity mismatch $($entry.filename)"};$feeds+=[ordered]@{filename=$entry.filename;facts=$facts}}
  $closure=Get-CompileClosure; if(@($closure.vendor|Where-Object path -eq $tradeHeader).Count -ne 1 -or (Get-Sha256 $tradeHeader) -ne '96e6781624534377fe7971cba52cca3d62d1b030bc10d5e4ebf3ed8c541399ed'){throw 'REFUSE: vendor Trade.mqh identity changed'}; $set=Get-FullSetIdentity
  $result=[ordered]@{schema='mgtt_orchestrator_offline/4';mode='Offline';status='PASS_HOST_ONLY';contract_identity=$contractIdentity;source=$source;source_commit=$SourceCommit;source_tree=(& git -C $RepoRoot rev-parse ($SourceCommit+'^{tree}')).Trim();closure=[ordered]@{repo=$closure.repo;vendor=$closure.vendor};full_set=$set;feeds=$feeds;native_coverage='NOT_RUN';performance='NOT_RUN_NOT_AUTHORIZED';holdout='LOCKED_UNSPENT';timestamp_utc=(Get-Date).ToUniversalTime().ToString('o')}
  Write-Receipt 'OFFLINE_RECEIPT.json' $result|Out-Null; return $result
}
function Get-ProcessInventory { $rows=@(); foreach($name in @('terminal64','metatester64','metaeditor64')){foreach($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)){try{$path=$process.Path}catch{$path='UNRESOLVED'};$rows+=[ordered]@{name=$name;process_id=$process.Id;path=$path}}}; return $rows }
function Get-OwnershipMap {
  $map=@{}; if(!$DependencyOwnershipReceipt){return $map}; if(!(Test-Path -LiteralPath $DependencyOwnershipReceipt -PathType Leaf)){throw 'REFUSE: dependency ownership receipt missing'}
  $receipt=Get-Content -Raw $DependencyOwnershipReceipt|ConvertFrom-Json; if($receipt.lane_id -ne $LaneId){throw 'REFUSE: dependency ownership receipt lane identity mismatch'}; foreach($entry in $receipt.entries){$map[[IO.Path]::GetFullPath($entry.path)]=$entry.sha256}; return $map
}
function Invoke-PreflightValidation {
  if($Terminal -ine 'D:\Meta 5\terminal64.exe' -or $MetaEditor -ine 'D:\Meta 5\metaeditor64.exe' -or $DataDir -ine 'D:\MetaTraderData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355'){throw 'REFUSE: successor is restricted to the frozen MT5-lane1 installation'}
  $offline=Invoke-OfflineValidation; $lanePath=Join-Path $RegistryRoot ($LaneId+'.json'); $runtimePath=Join-Path $RegistryRoot ($RuntimeLeaseRecordId+'.json')
  if(!(Test-Path $lanePath) -or !(Test-Path $runtimePath)){throw 'REFUSE: Registry source/runtime lane missing'}; $lane=Get-Content -Raw $lanePath|ConvertFrom-Json; $runtime=Get-Content -Raw $runtimePath|ConvertFrom-Json
  if($lane.lane_id -ne $LaneId -or !$lane.writer -or $lane.state -notin @('RUNNING','FROZEN') -or $lane.base_sha -ne $ExpectedParent -or $lane.head_sha -ne $SourceCommit -or [IO.Path]::GetFullPath($lane.worktree) -ne [IO.Path]::GetFullPath($RepoRoot)){throw 'REFUSE: Registry source owner/state/worktree/head mismatch'}
  if($runtime.lane_id -ne $RuntimeLeaseRecordId -or !$runtime.writer -or $runtime.state -ne 'RUNNING' -or $runtime.runtime_lane -ne 'MT5-lane1' -or $runtime.base_sha -ne $SourceCommit -or $runtime.head_sha -ne $SourceCommit -or @($runtime.dependencies) -notcontains $LaneId){throw 'REFUSE: runtime lease owner/state/source mismatch'}
  $processes=@(Get-ProcessInventory); if($processes.Count){Write-Receipt 'PREFLIGHT_PROCESS_CONFLICT.json' ([ordered]@{status='REFUSE_PROCESS_CONFLICT';processes=$processes})|Out-Null;throw 'REFUSE: competing or unresolved terminal/tester/editor process exists; do not start, stop, attach, or kill it'}
  foreach($path in @($Terminal,$MetaEditor,(Join-Path $RepoRoot 'scripts\mt5_run.ps1'))){if(!(Test-Path $path -PathType Leaf)){throw "REFUSE: native prerequisite missing $path"}}
  $ownership=Get-OwnershipMap; $expectations=Get-Content -Raw $expectationPath|ConvertFrom-Json; $terminalFiles=Join-Path $DataDir 'MQL5\Files'
  foreach($entry in $expectations.entries){$path=[IO.Path]::GetFullPath((Join-Path $terminalFiles $entry.filename));if(Test-Path $path){if(!$ownership.ContainsKey($path) -or $ownership[$path] -ne $entry.sha256 -or (Get-Sha256 $path) -ne $entry.sha256){throw "REFUSE: existing dependency is unowned or changed $path"}}}; $missing=Join-Path $terminalFiles 'EA_LAB_MGTT_Q1_missing.csv'; if(Test-Path $missing){throw 'REFUSE: missing-case alias residue exists'}
  $result=[ordered]@{schema='mgtt_orchestrator_preflight/3';mode='Preflight';status='PASS_NATIVE_READY_NO_PROCESS_STARTED';source_commit=$SourceCommit;lane_id=$LaneId;runtime_logical_lease=$RuntimeLeaseLaneId;runtime_lease_record=$RuntimeLeaseRecordId;terminal=(Get-ExecutableIdentity $Terminal);metaeditor=(Get-ExecutableIdentity $MetaEditor);process_inventory=$processes;timestamp_utc=(Get-Date).ToUniversalTime().ToString('o')}; Write-Receipt 'PREFLIGHT_RECEIPT.json' $result|Out-Null; return $result
}
function Open-ReadShareOnly([string[]]$Paths){$handles=New-Object Collections.Generic.List[IO.FileStream];foreach($path in $Paths){$handles.Add([IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read))};return $handles}
function Copy-ExactClosure([object]$Closure,[string]$NativeRoot) {
  $rows=@(); foreach($entry in $Closure.repo){$bytes=Get-GitBytes $SourceCommit $entry.path;$target=Join-Path $NativeRoot ($entry.path -replace '/','\');New-Item -ItemType Directory -Force (Split-Path $target -Parent)|Out-Null;[IO.File]::WriteAllBytes($target,$bytes);if((Get-Sha256 $target) -ne $entry.sha256){throw "REFUSE: creation-time staging mismatch $($entry.path)"};$rows+=[ordered]@{path=$entry.path;target=$target;sha256=$entry.sha256;git_blob=$entry.git_blob;bytes=$entry.bytes}}; return $rows
}
function Assert-StagedClosure([object[]]$Rows,[hashtable]$Overrides,[object[]]$Vendor){foreach($row in $Rows){$expected=if($Overrides.ContainsKey($row.path)){$Overrides[$row.path]}else{$row.sha256};if((Get-Sha256 $row.target) -ne $expected){throw "REFUSE: staged closure changed $($row.path)"}};foreach($row in $Vendor){if((Get-Sha256 $row.path) -ne $row.sha256){throw "REFUSE: vendor closure changed $($row.path)"}}}
function Assert-CompileResult([string]$Source,[string]$Log) {
  $compileArgs=@('/compile:"'+$Source+'"','/log:"'+$Log+'"');$process=Start-Process -FilePath $MetaEditor -ArgumentList $compileArgs -WindowStyle Hidden -PassThru;$identity=Get-ExecutableIdentity $MetaEditor $process
  if(!$process.WaitForExit(120000)){throw "REFUSE: compile still running process=$($process.Id); process was not killed"};if(!(Test-Path $Log)){throw 'COMPILE_FAIL no log'};$text=Get-Content -Raw $Log
  if($text -notmatch 'Result:\s*0\s+errors?,\s*0\s+warnings?'){throw "COMPILE_FAIL $Log"};$ex5=[IO.Path]::ChangeExtension($Source,'.ex5');if(!(Test-Path $ex5)){throw 'COMPILE_FAIL missing EX5'}; return [pscustomobject]@{ex5=$ex5;process=$identity;log=$Log;log_sha256=(Get-Sha256 $Log)}
}
function New-ProbeCaseSource([string]$Template,[hashtable]$Case,[string]$Build,[string]$Config,[string]$Session) {
  $block=@"
#property tester_file "$($Case.filename)"
#define MGTT_PROBE_FILENAME "$($Case.filename)"
#define MGTT_PROBE_EXPECTED_FILENAME "$($Case.filename)"
#define MGTT_PROBE_EXPECTED_SHA256 "$($Case.expected_sha256)"
#define MGTT_PROBE_EXPECTED_BYTES $($Case.expected_bytes)
#define MGTT_PROBE_EXPECTED_ROWS $($Case.expected_rows)
#define MGTT_PROBE_EXPECTED_FIRST "$($Case.expected_first)"
#define MGTT_PROBE_EXPECTED_LAST "$($Case.expected_last)"
#define MGTT_PROBE_BUILD_RECEIPT "$Build"
#define MGTT_PROBE_CONFIG_FINGERPRINT "$Config"
#define MGTT_PROBE_SESSION_ID "$Session"
"@
  return [regex]::Replace($Template,'(?s)(?<=// MGTT_PROBE_CASE_BEGIN).*?(?=// MGTT_PROBE_CASE_END)',"`r`n$block")
}
function Expand-MgttGitArchive([string]$Archive,[string]$Destination,[string]$Python) {
  $extractor=Join-Path (Split-Path $Destination -Parent) 'extract_runner_tree.py'
  $code=@'
import os
import pathlib
import sys
import zipfile

archive, destination = sys.argv[1:3]
root = "\\\\?\\" + os.path.abspath(destination)
with zipfile.ZipFile(archive) as source:
    for entry in source.infolist():
        name = entry.filename
        pure = pathlib.PurePosixPath(name)
        if (pure.is_absolute() or not pure.parts or "\\" in name or ":" in name
                or any(part in ("", ".", "..") for part in name.rstrip("/").split("/"))):
            raise SystemExit("unsafe archive member: " + name)
        target = os.path.join(root, *pure.parts)
        if entry.is_dir():
            os.makedirs(target, exist_ok=True)
            continue
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with source.open(entry) as reader, open(target, "wb") as writer:
            while True:
                block = reader.read(1024 * 1024)
                if not block:
                    break
                writer.write(block)
'@
  [IO.File]::WriteAllText($extractor,$code,[Text.UTF8Encoding]::new($false))
  & $Python $extractor $Archive $Destination
  if($LASTEXITCODE -ne 0){throw 'REFUSE: exact runner tree extraction failed'}
}
function New-RunnerTree {
  $root=Join-Path $evidenceFull 'runner_tree';$zip=Join-Path $evidenceFull 'runner_tree.zip';if((Test-Path $root) -or (Test-Path $zip)){throw 'REFUSE: runner tree evidence target exists'}
  & git -C $RepoRoot archive --format=zip --output=$zip $SourceCommit;if($LASTEXITCODE -ne 0){throw 'REFUSE: exact runner tree export failed'}
  . (Join-Path $RepoRoot 'scripts\use_python.ps1')
  $python=Assert-PortablePython -Root $RepoRoot -Provision
  try{Expand-MgttGitArchive $zip $root $python}finally{Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue}
  foreach($rel in @('scripts/mt5_run.ps1','scripts/lib/build_receipt.ps1','scripts/lib/setfile_surface.ps1','scripts/lib/binary_staleness.ps1','scripts/lib/symbol_preflight.ps1')){$bytes=Get-GitBytes $SourceCommit $rel;$path=Join-Path $root ($rel -replace '/','\');if((Get-Sha256 $path) -ne (Get-BytesSha256 $bytes)){throw "REFUSE: isolated runner byte mismatch $rel"}}; return $root
}
function Get-BoundedLogPaths {
  $paths=New-Object Collections.Generic.List[string];$dirs=New-Object Collections.Generic.List[string];$dirs.Add((Join-Path $DataDir 'logs'));$testerRoot=Join-Path (Split-Path (Split-Path $DataDir -Parent) -Parent) ('Tester\'+(Split-Path $DataDir -Leaf))
  foreach($agent in @(Get-ChildItem -LiteralPath $testerRoot -Directory -Filter 'Agent-*' -ErrorAction SilentlyContinue)){ $dirs.Add((Join-Path $agent.FullName 'logs')) }
  # These are the complete, fixed terminal/agent log directories for the
  # selected installation. Snapshot every log name; do not guess a date or
  # trust whichever generic log happened to be newest.
  foreach($dir in $dirs){if(!(Test-Path $dir)){continue};foreach($file in @(Get-ChildItem -LiteralPath $dir -File -Filter '*.log' -ErrorAction SilentlyContinue)){if(!$paths.Contains($file.FullName)){$paths.Add($file.FullName)}}};return $paths.ToArray()
}
function Get-LogSnapshot { $map=@{};foreach($path in @(Get-BoundedLogPaths)){if(Test-Path $path){$map[$path]=[ordered]@{length=(Get-Item $path).Length;sha256=(Get-Sha256 $path)}}};return $map }
function Get-PrefixSha256([string]$Path,[int64]$Length) {
  $sha=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
  try{$remaining=$Length;$buffer=New-Object byte[] 1048576;while($remaining -gt 0){$want=[int][Math]::Min($buffer.Length,$remaining);$read=$stream.Read($buffer,0,$want);if($read -le 0){throw 'REFUSE: incomplete log prefix read'};[void]$sha.TransformBlock($buffer,0,$read,$buffer,0);$remaining-=$read};[void]$sha.TransformFinalBlock((New-Object byte[] 0),0,0);return ([BitConverter]::ToString($sha.Hash)).Replace('-','').ToLowerInvariant()}finally{$stream.Dispose();$sha.Dispose()}
}
function Get-ChangedLogSlices([hashtable]$Before,[string]$CaseRoot) {
  $rows=@();$index=0;foreach($path in @(Get-BoundedLogPaths)){if(!(Test-Path $path)){continue};$item=Get-Item $path;$offset=0;if($Before.ContainsKey($path)){$offset=[int64]$Before[$path].length;if($item.Length -lt $offset){throw "REFUSE: relevant log truncated during run $path"};if((Get-PrefixSha256 $path $offset) -ne $Before[$path].sha256){throw "REFUSE: relevant log prefix changed during run $path"}};if($item.Length -eq $offset){continue};$stream=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);try{$stream.Position=$offset;$slice=New-Object byte[] ($item.Length-$offset);$read=$stream.Read($slice,0,$slice.Length);if($read -ne $slice.Length){throw 'REFUSE: incomplete log slice read'};$stream.Position=0;$bom=New-Object byte[] 2;[void]$stream.Read($bom,0,2)}finally{$stream.Dispose()};$slicePath=Join-Path $CaseRoot ('log_slice_'+$index+'.bin');[IO.File]::WriteAllBytes($slicePath,$slice);$encoding=if(($slice.Length -ge 2 -and $slice[0]-eq 255 -and $slice[1]-eq 254) -or ($bom[0]-eq 255 -and $bom[1]-eq 254)){[Text.Encoding]::Unicode}else{[Text.Encoding]::UTF8};$rows+=[ordered]@{source_path=$path;offset=$offset;bytes=$slice.Length;sha256=(Get-BytesSha256 $slice);evidence_path=$slicePath;text=$encoding.GetString($slice)};$index++};return $rows
}
function Write-RunnerInvocation([string]$RunnerRoot,[hashtable]$Arguments,[string]$CaseRoot) {
  # Hashtable splatting binds named script parameters. An array of '-Name',
  # 'value' strings is positional when invoking a .ps1 from PowerShell.
  $commandPath=Join-Path $CaseRoot 'invoke_mt5_runner.ps1'
  $argumentPath=Join-Path $CaseRoot 'runner_arguments.clixml'
  $Arguments | Export-Clixml -LiteralPath $argumentPath -Depth 5
  $body="`$ErrorActionPreference='Stop'`r`n`$runnerArgs=Import-Clixml -LiteralPath '"+$argumentPath.Replace("'","''")+"'`r`n& '"+(Join-Path $RunnerRoot 'scripts\mt5_run.ps1').Replace("'","''")+"' @runnerArgs`r`nexit `$LASTEXITCODE"
  [IO.File]::WriteAllText($commandPath,$body,[Text.UTF8Encoding]::new($false))
  return $commandPath
}
function Add-ProcessObservation([string]$Path,[object]$Observation) {
  # Append and physically flush the raw observation BEFORE enrichment can fail.
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Observation|ConvertTo-Json -Depth 20 -Compress)+"`n")
  $stream=[IO.File]::Open($Path,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
  try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}
function Get-IdentityField([object]$Identity,[string]$Name) {
  if($null -eq $Identity){throw "expected identity is null ($Name)"}
  if($Identity -is [Collections.IDictionary]) {
    if(!$Identity.Contains($Name)){throw "expected identity field is missing ($Name)"}
    return $Identity[$Name]
  }
  $property=$Identity.PSObject.Properties[$Name]
  if($null -eq $property){throw "expected identity field is missing ($Name)"}
  return $property.Value
}
function Resolve-ExpectedProcessIdentity([object]$ExpectedTerminal,[object]$ExpectedTester,[string]$ObservedPath) {
  # Do not let PowerShell's pipeline enumerate an OrderedDictionary into scalar
  # values. Retain each candidate as one identity object and index the List.
  $matches=New-Object Collections.Generic.List[object]
  foreach($candidate in @($ExpectedTerminal,$ExpectedTester)) {
    $candidatePath=[string](Get-IdentityField $candidate 'path')
    if($candidatePath -ieq $ObservedPath){$matches.Add($candidate)}
  }
  if($matches.Count -ne 1){throw 'extra or unselected process executable identity'}
  $match=$matches[0]
  return [pscustomobject]@{
    path=[string](Get-IdentityField $match 'path')
    sha256=[string](Get-IdentityField $match 'sha256')
    file_version=[string](Get-IdentityField $match 'file_version')
  }
}
function Get-EarlyProcessSnapshot([object]$ExpectedTerminal,[object]$ExpectedTester,[datetime]$LaunchUtc,[string]$JournalPath) {
  # Win32_Process supplies PID, creation time, executable path and parent in one
  # provider snapshot. Preserve those fields before doing any validation: the
  # selected metatester may have exited by the time a second lookup could run.
  $snapshot=@(Get-CimInstance Win32_Process -ErrorAction Stop)
  $byPid=@{}
  foreach($entry in $snapshot){
    $pidProperty=$entry.PSObject.Properties['ProcessId']
    if($null -ne $pidProperty -and $null -ne $pidProperty.Value){$byPid[[string][int64]$pidProperty.Value]=$entry}
  }
  $rows=@()
  foreach($entry in $snapshot){
    $nameProperty=$entry.PSObject.Properties['Name']
    $name=if($null -ne $nameProperty){[string]$nameProperty.Value}else{''}
    if($name -ine 'terminal64.exe' -and $name -ine 'metatester64.exe'){continue}
    $row=[ordered]@{kind='SELECTED_CANDIDATE';observed_utc=[datetime]::UtcNow.ToString('o');process_name=$name;pid=$null;creation_time_utc=$null;identity_key=$null;path=$null;sha256=$null;parent_pid=$null;ancestry=@();observation_status='RAW'}
    try {
      $row.pid=[int64]$entry.ProcessId
      if($row.pid -le 0 -or $null -eq $entry.CreationDate -or [string]::IsNullOrWhiteSpace([string]$entry.ExecutablePath)){throw 'snapshot missing PID, creation time, or executable path'}
      $created=([datetime]$entry.CreationDate).ToUniversalTime();$row.creation_time_utc=$created.ToString('o')
      $row.identity_key=[string]$row.pid+'|'+$row.creation_time_utc
      $row.path=[IO.Path]::GetFullPath([string]$entry.ExecutablePath)
      $row.parent_pid=[int64]$entry.ParentProcessId;$row.command_line=[string]$entry.CommandLine
      # The raw, already self-contained selected-process identity is durable at
      # the earliest observation boundary, before exact-path/ancestry checks.
      Add-ProcessObservation $JournalPath $row
      $expected=Resolve-ExpectedProcessIdentity $ExpectedTerminal $ExpectedTester $row.path
      if($created -lt $LaunchUtc.ToUniversalTime()){throw 'historical selected process identity'}
      $parentId=$row.parent_pid;$descendantCreated=$created;$observedAncestors=0
      for($depth=0;$depth -lt 12 -and $parentId;$depth++){
        $parent=$byPid[[string]$parentId]
        if($null -eq $parent){$row.ancestry+=@{pid=$parentId;status='UNOBSERVABLE'};break}
        if($null -eq $parent.CreationDate){throw 'ancestor creation time unavailable'}
        $parentCreated=([datetime]$parent.CreationDate).ToUniversalTime()
        if($parentCreated -gt $descendantCreated){throw 'ancestor PID reuse or creation-time mismatch'}
        $row.ancestry+=@{pid=[int64]$parent.ProcessId;parent_pid=[int64]$parent.ParentProcessId;creation_time_utc=$parentCreated.ToString('o');path=[string]$parent.ExecutablePath;status='OBSERVED'}
        $observedAncestors++;$parentId=[int64]$parent.ParentProcessId;$descendantCreated=$parentCreated
      }
      if($row.parent_pid -le 0 -or $observedAncestors -lt 1){throw 'selected parent/ancestry was not observable in the early snapshot'}
      $row.sha256=$expected.sha256;$row.file_version=$expected.file_version;$row.hash_basis='PRELAUNCH_READ_LOCK_HELD';$row.observation_status='COMPLETE'
    }catch{$row.observation_status='INCOMPLETE';$row.error=$_.Exception.Message}
    Add-ProcessObservation $JournalPath $row
    $rows+=$row
  }
  return $rows
}
function Complete-ProcessCapture([object[]]$Rows,[object]$ExpectedTerminal,[object]$ExpectedTester,[datetime]$LaunchUtc,[string]$CaseId) {
  $receipt=[ordered]@{schema='mgtt_process_observations/1';launch_utc=$LaunchUtc.ToUniversalTime().ToString('o');observations=@($Rows);historical_identity='NOT_RECONSTRUCTED';status='UNVALIDATED'}
  Write-Receipt ($CaseId+'.PROCESS_OBSERVATIONS.json') $receipt | Out-Null
  $terminalRows=@($Rows|Where-Object path -ieq $ExpectedTerminal.path)
  $testerRows=@($Rows|Where-Object path -ieq $ExpectedTester.path)
  if($terminalRows.Count -ne 1 -or $testerRows.Count -ne 1 -or $Rows.Count -ne 2){throw 'REFUSE: selected terminal/metatester process identity was not captured exactly once'}
  foreach($pair in @(@($terminalRows[0],$ExpectedTerminal),@($testerRows[0],$ExpectedTester))) {
    $row=$pair[0];$expected=$pair[1]
    $created=if($row.creation_time_utc){([datetime]$row.creation_time_utc).ToUniversalTime()}else{$null};$identityKey=if($null -ne $created){[string]$row.pid+'|'+$created.ToString('o')}else{$null};$ancestry=@($row.ancestry)
    if($row.observation_status -ne 'COMPLETE' -or !$row.pid -or $null -eq $created -or $row.identity_key -cne $identityKey -or !$row.parent_pid -or $ancestry.Count -lt 1 -or $ancestry[0].pid -ne $row.parent_pid -or $ancestry[0].status -cne 'OBSERVED' -or $row.sha256 -cne $expected.sha256 -or $created -lt $LaunchUtc.ToUniversalTime()){throw 'REFUSE: incomplete, historical, reused, or mismatched selected process observation'}
  }
  $receipt.status='PASS_CURRENT_INVOCATION_ONLY'
  Write-Receipt ($CaseId+'.PROCESS_VALIDATION.json') $receipt | Out-Null
  return [pscustomobject]@{terminal_processes=$terminalRows;metatester_processes=$testerRows}
}
function Write-DurableRunnerGateJson([string]$Path,[object]$Value) {
  if(Test-Path -LiteralPath $Path){throw "REFUSE: runner gate receipt already exists $Path"}
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes(($Value|ConvertTo-Json -Depth 30))
  $stream=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
  try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
  return (Get-Content -Raw -LiteralPath $Path|ConvertFrom-Json)
}
function Write-RunnerExitReceipt([string]$CaseRoot,[string]$CaseId,[object]$RunnerPid,[object]$RunnerCreation,[object]$ExitCode,[string]$StdoutPath,[string]$StderrPath,[object]$HandleState=$null) {
  $handleStatus=if($null -ne $HandleState){[string]$HandleState.status}else{'UNAVAILABLE'}
  $handleBasis=if($null -ne $HandleState){[string]$HandleState.evidence_basis}else{'UNAVAILABLE'}
  $handleType=if($null -ne $HandleState){[string]$HandleState.value_type}else{$null}
  $handleNonzero=[bool]($null -ne $HandleState -and $HandleState.nonzero)
  $handleError=if($null -ne $HandleState){$HandleState.error}else{'handle state was not supplied'}
  $handleAcquired=[bool]($handleStatus -ceq 'ACQUIRED' -and $handleBasis -ceq 'PROCESS_HANDLE_PROPERTY_IMMEDIATE_AFTER_START_PROCESS' -and $handleType -ceq 'System.IntPtr' -and $handleNonzero)
  $exitAvailable=[bool]($handleAcquired -and ($ExitCode -is [int]));$source=if($exitAvailable){'OWNED_RUNNER_PROCESS_AFTER_WAITFOREXIT'}else{'UNAVAILABLE_FAIL_CLOSED'}
  $stdoutPresent=[bool]($StdoutPath -and (Test-Path -LiteralPath $StdoutPath -PathType Leaf));$stderrPresent=[bool]($StderrPath -and (Test-Path -LiteralPath $StderrPath -PathType Leaf))
  $receipt=[ordered]@{
    schema='mgtt_runner_exit/2';case=$CaseId;recorded_utc=[datetime]::UtcNow.ToString('o')
    runner=[ordered]@{
      pid=$RunnerPid;creation_time_utc=$RunnerCreation
      owned_process_identity='SAME_START_PROCESS_OBJECT_PID_CREATION_HANDLE_EXIT'
      handle_acquisition_status=$handleStatus;handle_acquired=$handleAcquired;handle_evidence_basis=$handleBasis
      handle_value_type=$handleType;handle_nonzero=$handleNonzero;handle_value_persisted=$false;handle_acquisition_error=$handleError
      exit_code=$ExitCode;exit_code_available=$exitAvailable;exit_code_type=if($exitAvailable){$ExitCode.GetType().FullName}else{$null};exit_code_source=$source
    }
    stdout=[ordered]@{path=$StdoutPath;present=$stdoutPresent;sha256=if($stdoutPresent){Get-Sha256 $StdoutPath}else{$null}}
    stderr=[ordered]@{path=$StderrPath;present=$stderrPresent;sha256=if($stderrPresent){Get-Sha256 $StderrPath}else{$null}}
    evidence_policy=[ordered]@{stdout_text_used_for_exit_code=$false;report_presence_used_for_exit_code=$false;current_process_snapshot_used_for_exit_code=$false;unrelated_last_exit_code_used=$false}
  }
  return Write-DurableRunnerGateJson (Join-Path $CaseRoot ($CaseId+'.RUNNER_EXIT.json')) $receipt
}
function Write-RunnerGateReceipt([string]$CaseRoot,[string]$SourceCommit,[string]$SourceTree,[string]$CaseId,[object]$Runner,[string]$ReportPath,[bool]$ReportFresh) {
  $exitProperty=$Runner.PSObject.Properties['exit_code'];$exitCode=if($null -ne $exitProperty){$exitProperty.Value}else{$null}
  $sourceProperty=$Runner.PSObject.Properties['exit_code_source'];$exitSource=if($null -ne $sourceProperty){[string]$sourceProperty.Value}else{'UNAVAILABLE_FAIL_CLOSED'}
  $pidProperty=$Runner.PSObject.Properties['runner_pid'];$runnerPid=if($null -ne $pidProperty){$pidProperty.Value}else{$null}
  $creationProperty=$Runner.PSObject.Properties['runner_creation_time_utc'];$runnerCreation=if($null -ne $creationProperty){$creationProperty.Value}else{$null}
  $stdoutProperty=$Runner.PSObject.Properties['stdout'];$stdoutPath=if($null -ne $stdoutProperty){[string]$stdoutProperty.Value}else{$null}
  $stderrProperty=$Runner.PSObject.Properties['stderr'];$stderrPath=if($null -ne $stderrProperty){[string]$stderrProperty.Value}else{$null}
  $handleStatusProperty=$Runner.PSObject.Properties['handle_acquisition_status'];$handleStatus=if($null -ne $handleStatusProperty){[string]$handleStatusProperty.Value}else{'UNAVAILABLE'}
  $handleBasisProperty=$Runner.PSObject.Properties['handle_evidence_basis'];$handleBasis=if($null -ne $handleBasisProperty){[string]$handleBasisProperty.Value}else{'UNAVAILABLE'}
  $handleTypeProperty=$Runner.PSObject.Properties['handle_value_type'];$handleType=if($null -ne $handleTypeProperty){[string]$handleTypeProperty.Value}else{$null}
  $handleNonzeroProperty=$Runner.PSObject.Properties['handle_nonzero'];$handleNonzero=[bool]($null -ne $handleNonzeroProperty -and $handleNonzeroProperty.Value)
  $stdoutPresent=[bool]($stdoutPath -and (Test-Path -LiteralPath $stdoutPath -PathType Leaf));$stderrPresent=[bool]($stderrPath -and (Test-Path -LiteralPath $stderrPath -PathType Leaf));$reportPresent=[bool](Test-Path -LiteralPath $ReportPath -PathType Leaf)
  $handleRetained=[bool]($handleStatus -ceq 'ACQUIRED' -and $handleBasis -ceq 'PROCESS_HANDLE_PROPERTY_IMMEDIATE_AFTER_START_PROCESS' -and $handleType -ceq 'System.IntPtr' -and $handleNonzero)
  $exitAvailable=[bool]($handleRetained -and ($exitCode -is [int]) -and $exitSource -ceq 'OWNED_RUNNER_PROCESS_AFTER_WAITFOREXIT')
  $exitZero=[bool]($exitAvailable -and $exitCode -eq 0);$predicatePass=[bool]($exitZero -and $reportPresent -and $ReportFresh)
  $receiptPath=Join-Path $CaseRoot ($CaseId+'.RUNNER_GATE.json')
  $receipt=[ordered]@{
    schema='mgtt_runner_gate/2';source_commit=$SourceCommit;source_tree=$SourceTree;case=$CaseId;recorded_utc=[datetime]::UtcNow.ToString('o');receipt_path=$receiptPath
    runner=[ordered]@{pid=$runnerPid;creation_time_utc=$runnerCreation;handle_acquisition_status=$handleStatus;handle_evidence_basis=$handleBasis;handle_value_type=$handleType;handle_nonzero=$handleNonzero;exit_code=$exitCode;exit_code_available=$exitAvailable;exit_code_type=if($exitAvailable){$exitCode.GetType().FullName}else{$null};exit_code_source=$exitSource}
    stdout=[ordered]@{path=$stdoutPath;present=$stdoutPresent;sha256=if($stdoutPresent){Get-Sha256 $stdoutPath}else{$null}}
    stderr=[ordered]@{path=$stderrPath;present=$stderrPresent;sha256=if($stderrPresent){Get-Sha256 $stderrPath}else{$null}}
    report=[ordered]@{expected_path=$ReportPath;present=$reportPresent;sha256=if($reportPresent){Get-Sha256 $ReportPath}else{$null};fresh_for_exact_runner_exit=[bool]$ReportFresh}
    predicate=[ordered]@{runner_handle_retained=$handleRetained;runner_exit_available=$exitAvailable;runner_exit_zero=$exitZero;report_present=$reportPresent;report_fresh=[bool]$ReportFresh;pass=$predicatePass}
    guard_outcome=if($predicatePass){'PASS'}else{'FAIL_CLOSED'}
    evidence_policy=[ordered]@{stdout_text_used_for_exit_code=$false;current_process_snapshot_used_for_exit_code=$false;report_presence_substituted_for_exit_zero=$false;unrelated_last_exit_code_used=$false}
  }
  $readback=Write-DurableRunnerGateJson $receiptPath $receipt
  if($readback.schema -cne 'mgtt_runner_gate/2' -or $readback.source_commit -cne $SourceCommit -or $readback.source_tree -cne $SourceTree -or $readback.case -cne $CaseId){throw 'REFUSE: runner gate receipt durable read-back mismatch'}
  return $readback
}
function Assert-PositiveRunnerReportGate([object]$Receipt) {
  if($Receipt.schema -cne 'mgtt_runner_gate/2' -or !$Receipt.predicate.runner_handle_retained -or !$Receipt.predicate.runner_exit_available -or !$Receipt.predicate.runner_exit_zero -or !$Receipt.predicate.report_present -or !$Receipt.predicate.report_fresh -or !$Receipt.predicate.pass -or $Receipt.guard_outcome -cne 'PASS'){throw 'PROBE_FAIL positive runner/report'}
}
function Invoke-RunnerCaptured([string]$RunnerRoot,[hashtable]$Arguments,[string]$CaseRoot) {
  $commandPath=Write-RunnerInvocation $RunnerRoot $Arguments $CaseRoot;$stdout=Join-Path $CaseRoot 'runner.stdout.log';$stderr=Join-Path $CaseRoot 'runner.stderr.log'
  $expectedTerminal=Get-ExecutableIdentity $Terminal
  $expectedTester=Get-ExecutableIdentity (Join-Path (Split-Path $Terminal -Parent) 'metatester64.exe')
  Write-Receipt ((Split-Path $CaseRoot -Leaf)+'.PROCESS_EXPECTATIONS.json') ([ordered]@{terminal=$expectedTerminal;metatester=$expectedTester;command_sha256=(Get-Sha256 $commandPath);arguments_sha256=(Get-Sha256 (Join-Path $CaseRoot 'runner_arguments.clixml'))})|Out-Null
  $journal=Join-Path $CaseRoot 'PROCESS_OBSERVATIONS.jsonl';$seen=@{};$launchUtc=[datetime]::UtcNow;$process=$null;$runnerHandle=$null;$captureError=$null;$runnerPid=$null;$runnerCreation=$null;$runnerExitCode=$null;$runnerExitReceipt=$null;$runnerHandleReleaseReceipt=$null;$captured=$null;$runnerResult=$null
  $handleState=[pscustomobject][ordered]@{status='NOT_ATTEMPTED';evidence_basis='PROCESS_HANDLE_PROPERTY_IMMEDIATE_AFTER_START_PROCESS';value_type=$null;nonzero=$false;error=$null}
  # Lock the selected executables for the entire observation interval. Hash once
  # before launch; never spend a short tester lifetime hashing its executable.
  $binaryLocks=Open-ReadShareOnly @($expectedTerminal.path,$expectedTester.path)
  try {
    foreach($expected in @($expectedTerminal,$expectedTester)){if((Get-Sha256 $expected.path) -cne $expected.sha256){throw 'REFUSE: executable changed before launch'}}
    $process=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoLogo','-NoProfile','-File',$commandPath) -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
    # Windows PowerShell 5.1 can lose ExitCode after a redirected, non-Wait
    # Start-Process unless the exact owned Process opens and retains its Handle.
    # Acquire it before any polling while keeping the same Process object alive.
    try {
      $runnerHandle=$process.Handle
      if($null -eq $runnerHandle -or !($runnerHandle -is [IntPtr]) -or $runnerHandle -eq [IntPtr]::Zero){throw 'Process.Handle was null, non-IntPtr, or zero'}
      $handleState.status='ACQUIRED';$handleState.value_type=$runnerHandle.GetType().FullName;$handleState.nonzero=$true
    } catch {
      $handleState.status='FAILED';$handleState.error=$_.Exception.Message
      $captureError='runner handle acquisition failed: '+$handleState.error
    }
    $runnerPid=$process.Id;$runnerCreation=$process.StartTime.ToUniversalTime().ToString('o')
    Add-ProcessObservation $journal ([ordered]@{kind='RUNNER';pid=$runnerPid;creation_time_utc=$runnerCreation;launch_utc=$launchUtc.ToString('o');handle_acquisition_status=$handleState.status;handle_evidence_basis=$handleState.evidence_basis})
    do {
      foreach($row in @(Get-EarlyProcessSnapshot $expectedTerminal $expectedTester $launchUtc $journal)){
        $key=[string]$row.identity_key
        # Raw/incomplete observations remain durably journaled, but a missing
        # identity key can never participate in exact-once selected identity.
        if([string]::IsNullOrWhiteSpace($key)){continue}
        if(!$seen.ContainsKey($key)){$seen[$key]=$row}
      }
      if(!$process.HasExited){Start-Sleep -Milliseconds 5}
    }while(!$process.HasExited)
    $process.WaitForExit()
    if($handleState.status -ceq 'ACQUIRED'){
      $candidateExitCode=$process.ExitCode
      if($candidateExitCode -is [int]){$runnerExitCode=$candidateExitCode}else{
        $message='runner ExitCode unavailable or non-numeric after retained owned handle'
        $captureError=if($captureError){$captureError+'; '+$message}else{$message}
      }
    }
  }catch{
    $message=$_.Exception.Message;$captureError=if($captureError){$captureError+'; '+$message}else{$message}
    if($null -ne $process){try{$process.WaitForExit()}catch{$captureError+='; WaitForExit failed: '+$_.Exception.Message}}
  }finally {
    foreach($handle in $binaryLocks){$handle.Dispose()}
  }
  $caseId=Split-Path $CaseRoot -Leaf
  # Exit provenance is independent of selected-process acceptance. Flush it
  # before Complete-ProcessCapture can refuse a missing/ambiguous identity.
  try {
    $runnerExitReceipt=Write-RunnerExitReceipt $CaseRoot $caseId $runnerPid $runnerCreation $runnerExitCode $stdout $stderr $handleState
    try{$captured=Complete-ProcessCapture @($seen.Values) $expectedTerminal $expectedTester $launchUtc $caseId}catch{$message=$_.Exception.Message;$captureError=if($captureError){$captureError+'; '+$message}else{$message}}
    if($captureError){throw ('REFUSE: capture failed '+$captureError)}
    $runnerResult=[pscustomobject][ordered]@{
      runner_pid=$runnerPid;runner_creation_time_utc=$runnerCreation
      handle_acquisition_status=$handleState.status;handle_evidence_basis=$handleState.evidence_basis;handle_value_type=$handleState.value_type;handle_nonzero=$handleState.nonzero
      exit_code=$runnerExitCode;exit_code_source=if($runnerExitCode -is [int]){'OWNED_RUNNER_PROCESS_AFTER_WAITFOREXIT'}else{'UNAVAILABLE_FAIL_CLOSED'}
      runner_exit_receipt=$runnerExitReceipt;runner_handle_release_receipt=$null
      stdout=$stdout;stderr=$stderr;stdout_sha256=(Get-Sha256 $stdout);stderr_sha256=(Get-Sha256 $stderr);command_path=$commandPath;command_sha256=(Get-Sha256 $commandPath)
      terminal_processes=$captured.terminal_processes;metatester_processes=$captured.metatester_processes
    }
  } finally {
    if($null -ne $process){
      $releaseStatus='NOT_DISPOSABLE_TEST_DOUBLE';$releaseError=$null
      try {
        if($process -is [IDisposable]){$process.Dispose();$releaseStatus='DISPOSED_AFTER_DURABLE_EXIT_EVIDENCE'}
        elseif($null -ne $process.PSObject.Methods['Dispose']){$process.Dispose();$releaseStatus='DISPOSED_AFTER_DURABLE_EXIT_EVIDENCE'}
      } catch {$releaseStatus='DISPOSE_FAILED';$releaseError=$_.Exception.Message}
      $runnerHandle=$null
      $release=[ordered]@{schema='mgtt_runner_handle_release/1';case=$caseId;runner_pid=$runnerPid;runner_creation_time_utc=$runnerCreation;status=$releaseStatus;error=$releaseError;exit_receipt_path=(Join-Path $CaseRoot ($caseId+'.RUNNER_EXIT.json'));recorded_utc=[datetime]::UtcNow.ToString('o')}
      $runnerHandleReleaseReceipt=Write-DurableRunnerGateJson (Join-Path $CaseRoot ($caseId+'.RUNNER_HANDLE_RELEASE.json')) $release
      if($releaseStatus -eq 'DISPOSE_FAILED' -and $null -ne $runnerResult){throw ('REFUSE: owned runner Process disposal failed '+$releaseError)}
    }
  }
  $runnerResult.runner_handle_release_receipt=$runnerHandleReleaseReceipt
  return $runnerResult
}
function Assert-EventStream([string]$Text,[string]$Session,[bool]$Positive) {
  $events=@();$seen=@{};foreach($line in $Text -split "`r?`n"){if($line -match '\[MGTT\] event=(\S+) session=(\S+) seq=(\d+) (.*)$'){$event=[pscustomobject]@{event=$Matches[1];session=$Matches[2];seq=[int64]$Matches[3];fields=$Matches[4]};$key=$event.session+'|'+$event.seq;$signature=$event.event+'|'+$event.fields;if($seen.ContainsKey($key)){if($seen[$key] -cne $signature){throw "PROBE_FAIL conflicting mirrored event $key"};continue};$seen[$key]=$signature;$events+=$event}};if($events.Count -eq 0){throw 'PROBE_FAIL no MGTT event stream in exact log slices'}
  foreach($event in $events){if(!$event.session.StartsWith($Session,[StringComparison]::Ordinal)){throw "PROBE_FAIL mixed session $($event.session)"}};foreach($group in @($events|Group-Object session)){$ordered=@($group.Group|Sort-Object seq);for($i=0;$i -lt $ordered.Count;$i++){if($ordered[$i].seq -ne $i+1){throw "PROBE_FAIL sequence gap/duplicate session $($group.Name)"}};if(@($ordered|Where-Object event -eq 'RUN_BEGIN').Count -ne 1 -or @($ordered|Where-Object event -eq 'RUN_END').Count -ne 1){throw "PROBE_FAIL incomplete session terminals $($group.Name)"}}
  $primary=@($events|Where-Object session -eq $Session);if(@($primary|Where-Object event -eq 'RUN_BEGIN').Count -ne 1){throw 'PROBE_FAIL primary RUN_BEGIN count'}
  if($Positive){$footer=@($primary|Where-Object event -eq 'RUN_END');if($footer.Count -ne 1 -or $footer[0].fields -notmatch 'fill_coverage_finalized=1.*availability=CERTIFIED' -or $footer[0].fields -notmatch 'evidence_error_count=0'){throw 'PROBE_FAIL primary certified footer'};foreach($name in @('DUPLICATE_EXECUTION_END','DUPLICATE_SUBMIT_RETURN','DUPLICATE_NATIVE_SEND_RESULT','CONTRADICTORY_DEAL')){if($Text -notmatch $name){throw "PROBE_FAIL missing adversarial marker $name"}}}
}
function Save-CaseEvidence([string]$CaseRoot,[object]$Before,[string]$RunnerRoot,[string]$ReportName,[string]$Outcome) {
  $saved=[ordered]@{case=(Split-Path $CaseRoot -Leaf);outcome=$Outcome;observed_utc=[datetime]::UtcNow.ToString('o');process_cleanup_action='NO_KILL';processes=@(Get-ProcessInventory);logs=@();errors=@();ini=$null}
  if($null -ne $Before){try{$saved.logs=@(Get-ChangedLogSlices $Before $CaseRoot | ForEach-Object{[ordered]@{source_path=$_.source_path;offset=$_.offset;bytes=$_.bytes;sha256=$_.sha256;evidence_path=$_.evidence_path}})}catch{$saved.errors+=$_.Exception.Message}}
  if($ReportName){$ini=Join-Path $RunnerRoot ('_mt5_auto\ini\'+$ReportName+'.ini');if(Test-Path -LiteralPath $ini){$target=Join-Path $CaseRoot 'EXACT_TESTER.ini';[IO.File]::WriteAllBytes($target,[IO.File]::ReadAllBytes($ini));$saved.ini=[ordered]@{source=$ini;evidence=$target;sha256=(Get-Sha256 $target)}}}
  $saved.files=@(Get-ChildItem -LiteralPath $CaseRoot -File | ForEach-Object{[ordered]@{path=$_.FullName;sha256=(Get-Sha256 $_.FullName);bytes=$_.Length}})
  Write-Receipt ($saved.case+'.FINAL_EVIDENCE.json') $saved | Out-Null
  if($saved.errors.Count){throw ('REFUSE: case evidence capture failed '+($saved.errors -join '; '))}
}
function Invoke-NativeQualification {
  if(!$ConfirmNativeNoPerformance){throw 'REFUSE: Native requires -ConfirmNativeNoPerformance'};$preflight=Invoke-PreflightValidation;$closure=Get-CompileClosure;$set=Get-FullSetIdentity;$sourceTree=(& git -C $RepoRoot rev-parse ($SourceCommit+'^{tree}')).Trim();$runId='ORDER-MGTT-QUAL-'+$SourceCommit.Substring(0,12)+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss');$nativeRoot=Join-Path $DataDir ('MQL5\Experts\EA_LAB_TEST\'+$runId)
  if(Test-Path $nativeRoot){throw 'REFUSE: order-owned native root exists'};New-Item -ItemType Directory -Path $nativeRoot|Out-Null;$staged=@(Copy-ExactClosure $closure $nativeRoot);$overrides=@{};$bossBuild=New-BuildReceiptToken;$headerRel='ea_template/core/BuildReceipt_gen.mqh';$headerRow=@($staged|Where-Object path -eq $headerRel);if($headerRow.Count -ne 1){throw 'REFUSE: BuildReceipt header absent from closure'};Write-BuildReceiptHeader -HeaderPath $headerRow[0].target -Receipt $bossBuild;$overrides[$headerRel]=Get-Sha256 $headerRow[0].target
  $bossControl=Join-Path $nativeRoot ($bossRelative -replace '/','\');$bossQual=[IO.Path]::ChangeExtension($bossControl,$null)+'_QUAL.mq5';$bossBytes=Get-GitBytes $SourceCommit $bossRelative;$qualBytes=[Text.UTF8Encoding]::new($false).GetBytes("#define LAB_MG_TESTER_EVIDENCE_QUAL`r`n"+[Text.Encoding]::UTF8.GetString($bossBytes));[IO.File]::WriteAllBytes($bossQual,$qualBytes);Assert-StagedClosure $staged $overrides $closure.vendor
  $handles=Open-ReadShareOnly (@($staged.target)+@($closure.vendor.path));try{$controlCompile=Assert-CompileResult $bossControl (Join-Path $evidenceFull 'Boss15_CONTROL.compile.log');$qualCompile=Assert-CompileResult $bossQual (Join-Path $evidenceFull 'Boss15_QUAL.compile.log')}finally{foreach($handle in $handles){$handle.Dispose()}}
  $compileReceipt=[ordered]@{schema='mgtt_compile_receipt/2';source_commit=$SourceCommit;source_tree=(& git -C $RepoRoot rev-parse ($SourceCommit+'^{tree}')).Trim();closure=[ordered]@{repo=$closure.repo;vendor=$closure.vendor};staged_closure=$staged;derivatives=@([ordered]@{path=$headerRel;input_sha256=$headerRow[0].sha256;derivation='Write-BuildReceiptHeader';build_receipt=$bossBuild;output_sha256=$overrides[$headerRel]},[ordered]@{path=$bossQual;input_path=$bossRelative;input_sha256=(Get-BytesSha256 $bossBytes);derivation='prepend LAB_MG_TESTER_EVIDENCE_QUAL';output_sha256=(Get-Sha256 $bossQual)});control=$controlCompile;qualification=$qualCompile;terminal=(Get-ExecutableIdentity $Terminal);metaeditor=(Get-ExecutableIdentity $MetaEditor)};Write-Receipt 'COMPILE_RECEIPT.json' $compileReceipt|Out-Null
  $runnerRoot=New-RunnerTree;$expectations=Get-Content -Raw $expectationPath|ConvertFrom-Json;$terminalFiles=Join-Path $DataDir 'MQL5\Files';New-Item -ItemType Directory -Force $terminalFiles|Out-Null;$owned=@();foreach($entry in $expectations.entries){$source=Join-Path $RepoRoot $entry.source_path;$target=Join-Path $terminalFiles $entry.filename;if(!(Test-Path $target)){Copy-Item -LiteralPath $source -Destination $target};if((Get-Sha256 $target)-ne $entry.sha256){throw "REFUSE: dependency staging mismatch $target"};$owned+=[ordered]@{path=$target;sha256=$entry.sha256}};$ownershipPath=Write-Receipt 'NATIVE_DEPENDENCY_OWNERSHIP.json' ([ordered]@{schema='mgtt_dependency_ownership/2';lane_id=$LaneId;source_commit=$SourceCommit;entries=$owned})
  $real=$expectations.entries[0];$cases=@(@{id='POSITIVE_GOLDEN_REAL';filename=$real.filename;expected_sha256=$real.sha256;expected_bytes=$real.bytes;expected_rows=$real.rows;expected_first=$real.first;expected_last=$real.last;failure='';fixture='GOLDEN'},@{id='MISSING';filename='EA_LAB_MGTT_Q1_missing.csv';expected_sha256=$real.sha256;expected_bytes=$real.bytes;expected_rows=$real.rows;expected_first=$real.first;expected_last=$real.last;failure='MISSING';fixture='MISSING'},@{id='WRONG_SAME_METADATA';filename=$real.filename;expected_sha256=$real.sha256;expected_bytes=$real.bytes;expected_rows=$real.rows;expected_first=$real.first;expected_last=$real.last;failure='HASH_MISMATCH';fixture='WRONG'},@{id='STALE_TRUNCATED_COPY';filename=$real.filename;expected_sha256=$real.sha256;expected_bytes=$real.bytes;expected_rows=$real.rows;expected_first=$real.first;expected_last=$real.last;failure='SIZE_MISMATCH';fixture='TRUNCATED'})
  $template=[Text.Encoding]::UTF8.GetString((Get-GitBytes $SourceCommit $probeRelative));$realBytes=[IO.File]::ReadAllBytes((Join-Path $RepoRoot $real.source_path));$results=@()
  foreach($case in $cases){$caseRoot=Join-Path $evidenceFull $case.id;New-Item -ItemType Directory -Path $caseRoot|Out-Null;$dependency=Join-Path $terminalFiles $case.filename;$restore=($case.filename -eq $real.filename);$before=$null;$reportName=$null;$caseOutcome='FAILED_BEFORE_POSTCONDITION';try{
    if($case.fixture -eq 'MISSING'){if(Test-Path $dependency){throw 'REFUSE: missing alias exists'}}elseif($case.fixture -eq 'GOLDEN'){[IO.File]::WriteAllBytes($dependency,$realBytes)}elseif($case.fixture -eq 'WRONG'){$fixture=[byte[]]$realBytes.Clone();$needle=[Text.Encoding]::ASCII.GetBytes(' 02:');$hits=0;for($i=0;$i -le $fixture.Length-$needle.Length;$i++){$match=$true;for($j=0;$j -lt $needle.Length;$j++){if($fixture[$i+$j]-ne $needle[$j]){$match=$false;break}};if($match){$hits++;if($hits -eq 2){$fixture[$i+1]=[byte][char]'0';$fixture[$i+2]=[byte][char]'3';break}}};if((Get-BytesSha256 $fixture)-ne '7e1dbd8e3850c5d14858c7183d9f842767bbe0e33d16ed148be4fbd9dc84f5e4'){throw 'REFUSE: WRONG derivation mismatch'};[IO.File]::WriteAllBytes($dependency,$fixture)}else{$lastLf=[Array]::LastIndexOf($realBytes,[byte]10,$realBytes.Length-2);$fixture=New-Object byte[] ($lastLf+1);[Array]::Copy($realBytes,$fixture,$fixture.Length);if((Get-BytesSha256 $fixture)-ne '70271717ee95f618a2d76b2b0a8d1ca2d8da9edf2cc9a079b74d4ea90e484e19'){throw 'REFUSE: TRUNCATED derivation mismatch'};[IO.File]::WriteAllBytes($dependency,$fixture)}
    $build=New-BuildReceiptToken;$session='MGTT-'+$case.id+'-'+([guid]::NewGuid().ToString('N'));$caseSource=Join-Path $nativeRoot ('scripts\_test\MGTT_'+$case.id+'.mq5');[IO.File]::WriteAllText($caseSource,(New-ProbeCaseSource $template $case $build $set.fingerprint $session),[Text.UTF8Encoding]::new($false));$sourceSha=Get-Sha256 $caseSource;Assert-StagedClosure $staged $overrides $closure.vendor;$caseCompile=Assert-CompileResult $caseSource (Join-Path $caseRoot 'compile.log');$registry=Join-Path $caseRoot 'build_receipts.jsonl';Write-BuildReceiptRecord -RegistryPath $registry -Receipt $build -ArtifactPath $caseCompile.ex5 -SourcePath $caseSource -EaLogicalIdentity ('MGTT_'+$case.id)
    $reportName='MGTT_'+$case.id+'_'+$session.Substring($session.Length-12);$reportPath=Join-Path $runnerRoot ('_mt5_auto\reports\'+$reportName+'.htm');if(Test-Path $reportPath){throw 'REFUSE: unique report path already exists'};$prelaunch=[ordered]@{schema='mgtt_prelaunch_identity/2';source_commit=$SourceCommit;case=$case.id;runtime_session=$session;build_receipt=$build;probe_source=$caseSource;probe_source_sha256=$sourceSha;ex5=$caseCompile.ex5;ex5_sha256=(Get-Sha256 $caseCompile.ex5);full_set=$set;dependency=$dependency;dependency_sha256=if(Test-Path $dependency){Get-Sha256 $dependency}else{$null};report_name=$reportName;report_path=$reportPath;terminal=(Get-ExecutableIdentity $Terminal);metaeditor=(Get-ExecutableIdentity $MetaEditor);model='M1_M1_OHLC_ENGINEERING_NO_PERFORMANCE';symbol='GBPUSD';timeframe='H4';from='2020.01.02';to='2020.01.03'};Write-Receipt ($case.id+'.PRELAUNCH.json') $prelaunch|Out-Null
    $before=Get-LogSnapshot;$holdPaths=@($caseSource,$caseCompile.ex5,$set.path)+@($closure.vendor.path);if(Test-Path $dependency){$holdPaths+=$dependency};$handles=Open-ReadShareOnly $holdPaths;try{$relative=$caseCompile.ex5.Substring((Join-Path $DataDir 'MQL5\Experts').Length+1).Replace('/','\');$relative=$relative.Substring(0,$relative.Length-4);$runArgs=[ordered]@{Expert=$relative;Symbol='GBPUSD';Period='H4';FromDate='2020.01.02';ToDate='2020.01.03';Model=1;ReportName=$reportName;SetFile=$set.path;Terminal=$Terminal;DataDir=$DataDir;TimeoutSec=180;BuildReceiptRegistry=$registry};$runStart=Get-Date;$run=Invoke-RunnerCaptured $runnerRoot $runArgs $caseRoot}finally{foreach($handle in $handles){$handle.Dispose()}}
    # Persist the exact owned runner exit and report state before any positive
    # acceptance gate can throw. Null/unavailable exits never reach the typed
    # freshness helper and are recorded as a fail-closed predicate component.
    $reportFresh=$false;if($run.exit_code -is [int]){$reportFresh=[bool](Test-ReportIsFresh -Htm $reportPath -RunStart $runStart -RunnerExit $run.exit_code -Label $case.id -Quiet)}
    $runnerGate=Write-RunnerGateReceipt -CaseRoot $caseRoot -SourceCommit $SourceCommit -SourceTree $sourceTree -CaseId $case.id -Runner $run -ReportPath $reportPath -ReportFresh $reportFresh
    if($case.id -eq 'POSITIVE_GOLDEN_REAL'){Assert-PositiveRunnerReportGate -Receipt $runnerGate}elseif((Test-Path $reportPath) -and !$reportFresh){throw 'PROBE_FAIL stale or untrusted native report'}
    $slices=@(Get-ChangedLogSlices $before $caseRoot);$relevant=@($slices|Where-Object {$_.text -match [regex]::Escape($session)});if($relevant.Count -eq 0){throw "PROBE_FAIL no exact-session log slice $($case.id)"};$text=($relevant.text -join "`n");Assert-EventStream $text $session ($case.id -eq 'POSITIVE_GOLDEN_REAL')
    if($text -notmatch ('runtime_session='+[regex]::Escape($session)+'.*build_receipt='+[regex]::Escape($build)+'.*effective_config_fingerprint='+$set.fingerprint)){throw 'PROBE_FAIL runtime build/config/session marker mismatch'}
    if($case.failure){if($text -notmatch ('failure='+$case.failure) -or $text -match 'LOAD_PASS_NO_TRADES'){throw "PROBE_FAIL $($case.id)"}}else{foreach($marker in @('load_status=PASS','LOAD_PASS_NO_TRADES','CERTIFIED_COUNTS_PASS','IDEMPOTENT_DEAL_PASS','DUPLICATE_TERMINALS_FAIL_CLOSED_PASS','MISSING_PARTIAL_PENDING_FILL_FAIL_CLOSED_PASS','CONTRADICTORY_DEAL_FAIL_CLOSED_PASS','CLASSIFICATION_FAIL_CLOSED_PASS','ADVERSARIAL_FAIL_CLOSED_PASS')){if($text -notmatch $marker){throw "PROBE_FAIL missing $marker"}}}
    $report=[ordered]@{status=if(Test-Path $reportPath){'PRESENT'}else{'ABSENT_EXPECTED_INIT_FAILED'};path=$reportPath;sha256=if(Test-Path $reportPath){Get-Sha256 $reportPath}else{$null}};$logManifest=[ordered]@{schema='mgtt_log_slice_manifest/1';runtime_session=$session;slices=@($slices|ForEach-Object{[ordered]@{source_path=$_.source_path;offset=$_.offset;bytes=$_.bytes;sha256=$_.sha256;evidence_path=$_.evidence_path}})};Write-Receipt ($case.id+'.LOG_MANIFEST.json') $logManifest|Out-Null;$results+=[ordered]@{case=$case.id;status='PASS_ENGINEERING';runtime_session=$session;build_receipt=$build;config_fingerprint=$set.fingerprint;runner=$run;runner_gate=$runnerGate;report=$report;relevant_log_slices=$relevant.Count}
    $caseOutcome='PASS_ENGINEERING';Write-Receipt 'CAMPAIGN_PROGRESS.json' ([ordered]@{source_commit=$SourceCommit;completed=$results;next_case_not_authorized_on_failure=$true})|Out-Null
  }catch{$caseOutcome=$_.Exception.Message;throw}finally{try{Save-CaseEvidence $caseRoot $before $runnerRoot $reportName $caseOutcome}finally{if($restore -and (Test-Path $dependency)){if(@($real.sha256,'7e1dbd8e3850c5d14858c7183d9f842767bbe0e33d16ed148be4fbd9dc84f5e4','70271717ee95f618a2d76b2b0a8d1ca2d8da9edf2cc9a079b74d4ea90e484e19') -notcontains (Get-Sha256 $dependency)){throw 'REFUSE: dependency ownership changed; not restoring'};[IO.File]::WriteAllBytes($dependency,$realBytes)}}}}
  $result=[ordered]@{schema='mgtt_native_qualification/2';status='PASS_NO_PERFORMANCE';source_commit=$SourceCommit;source_tree=(& git -C $RepoRoot rev-parse ($SourceCommit+'^{tree}')).Trim();compile_receipt=$compileReceipt;probe_results=$results;native_root=$nativeRoot;runner_root=$runnerRoot;dependency_ownership_receipt=$ownershipPath;performance='NOT_RUN';holdout='LOCKED_UNSPENT'};Write-Receipt 'NATIVE_RESULT.json' $result|Out-Null;return $result
}

try{if($Mode -eq 'Offline'){$result=Invoke-OfflineValidation}elseif($Mode -eq 'Preflight'){$result=Invoke-PreflightValidation}else{$result=Invoke-NativeQualification};$result|ConvertTo-Json -Depth 30;exit 0}catch{$failure=[ordered]@{schema='mgtt_orchestrator_failure/2';mode=$Mode;status='REFUSE';source_commit=$SourceCommit;error=$_.Exception.Message;native_process_action='NO_KILL_NO_FORCE';performance='NOT_RUN';holdout='LOCKED_UNSPENT'};Write-Receipt ($Mode.ToUpperInvariant()+'_FAILURE.json') $failure|Out-Null;$failure|ConvertTo-Json -Depth 10;exit 1}
