<#
.SYNOPSIS
Build a non-authoritative context packet from one immutable canonical Git commit.

.DESCRIPTION
OrderId selects the complete canonical order block, through the line before the
next level-two peer heading. When a task is governed by an owner-local contract,
pass TaskContractPath, ExpectedTaskContractSha256, and TaskContractId together.
That optional trio records identity metadata only: external content is neither
included nor interpreted and cannot grant repository authority.
#>
[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Ref = 'origin/master',
    [string]$OrderId = '',
    [string]$OutputPath = '',
    [string]$ControlRoot = '',
    [string]$ExpectedRemoteSha = '',
    [string]$TaskContractPath = '',
    [string]$ExpectedTaskContractSha256 = '',
    [string]$TaskContractId = '',
    [switch]$Stdout
)
$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Invoke-GitText {
    param([string[]]$GitArgs)
    $out = & git -C $Root @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git failed: git $($GitArgs -join ' ')" }
    return (($out | Out-String).TrimEnd())
}
function Get-Sha256Text {
    param([string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
function Get-Sha256File {
    param([string]$Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()
    } finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}
function Get-RefFile {
    param([string]$Path)
    # Resolve once. A branch moving during generation must not mix source bytes.
    return Invoke-GitText @('show',("{0}:{1}" -f $sourceCommit,$Path))
}function Get-BoundedLines {
    param([string]$Text,[int]$MaxLines = 40)
    return @((@($Text -split "`r?`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) | Select-Object -First $MaxLines)
}
function Get-MatchingLines {
    param([string]$Text,[string]$Pattern,[int]$MaxLines = 30)
    return @((@($Text -split "`r?`n") | Where-Object { $_ -match $Pattern }) | Select-Object -First $MaxLines)
}
function Get-ExactOrderBlock {
    param([Collections.IDictionary]$Texts,[string[]]$Paths,[string]$ExactOrderId)
    if ([string]::IsNullOrWhiteSpace($ExactOrderId)) {
        return [pscustomobject][ordered]@{
            requested=$false; lookup_state='NOT_REQUESTED'; found=$null; complete=$null
            source_path=$null; line_count=0; lines=@()
        }
    }
    $headerPattern = '^##\s+' + [regex]::Escape($ExactOrderId) + '(?:\s|$)'
    $found = New-Object Collections.Generic.List[object]
    foreach ($path in $Paths) {
        $lines = @(([string]$Texts[$path]) -split "`r?`n")
        for ($i=0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -notmatch $headerPattern) { continue }
            $end = $lines.Count - 1
            for ($j=$i+1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^##(?:\s+|$)') { $end=$j-1; break }
            }
            $found.Add([pscustomobject][ordered]@{
                source_path=$path; lines=@($lines[$i..$end]); line_count=($end-$i+1)
            })
        }
    }
    if ($found.Count -gt 1) {
        throw "Context packet refused: duplicate canonical order identity $ExactOrderId"
    }
    if ($found.Count -eq 0) {
        return [pscustomobject][ordered]@{
            requested=$true; lookup_state='MISSING'; found=$false; complete=$false
            source_path=$null; line_count=0; lines=@()
        }
    }
    return [pscustomobject][ordered]@{
        requested=$true; lookup_state='FOUND_COMPLETE'; found=$true; complete=$true
        source_path=$found[0].source_path; line_count=$found[0].line_count; lines=@($found[0].lines)
    }
}
function Get-ActiveHeaders {
    param([string]$Text,[int]$MaxLines = 24)
    return @((@($Text -split "`r?`n") | Where-Object {
        $_ -match '^##\s+ORDER-' -and $_ -match '(?i)`[^`]*(OPEN|CLAIMED|IN-PROGRESS|WAITING|BLOCKED|PARTIAL|READY)[^`]*`'
    }) | Select-Object -First $MaxLines)
}$sourceCommit = Invoke-GitText @('rev-parse',($Ref + '^{commit}'))
$originMaster = Invoke-GitText @('rev-parse','origin/master')
if ($ExpectedRemoteSha -and $ExpectedRemoteSha -cnotmatch '^[0-9a-f]{40}$') { throw 'ExpectedRemoteSha must be an exact Git SHA' }
if ($ExpectedRemoteSha -and $sourceCommit -cne $ExpectedRemoteSha) { throw 'Source ref differs from caller-verified remote SHA; reconcile before generating current context.' }
$sourceCommitTime = Invoke-GitText @('show','-s','--format=%cI',$sourceCommit)

# Optional owner-local contract binding. Its bytes are hash-bound but never copied,
# interpreted, or promoted into canonical authority by this packet.
$contractArgs = @($TaskContractPath,$ExpectedTaskContractSha256,$TaskContractId)
$contractArgCount = @($contractArgs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
$taskContract = $null
if ($contractArgCount -gt 0) {
    if ($contractArgCount -ne 3) { throw 'Context packet refused: TaskContractPath, ExpectedTaskContractSha256, and TaskContractId are required together' }
    if (-not [IO.Path]::IsPathRooted($TaskContractPath)) { throw 'Context packet refused: TaskContractPath must be absolute' }
    if ($ExpectedTaskContractSha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Context packet refused: ExpectedTaskContractSha256 must be exact lowercase SHA-256' }
    if ($TaskContractId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._:-]{2,127}$') { throw 'Context packet refused: invalid TaskContractId' }
    if ($OrderId -and $OrderId -cne $TaskContractId) { throw 'Context packet refused: OrderId conflicts with TaskContractId' }
    $contractFull = [IO.Path]::GetFullPath($TaskContractPath)
    if (-not (Test-Path -LiteralPath $contractFull -PathType Leaf)) { throw 'Context packet refused: owner-local task contract is missing' }
    $repoPrefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    if ($contractFull.StartsWith($repoPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Context packet refused: TaskContractPath must be external to the repository' }
    $actualContractSha = Get-Sha256File $contractFull
    if ($actualContractSha -cne $ExpectedTaskContractSha256) { throw 'Context packet refused: owner-local task contract SHA-256 mismatch' }
    $taskContract = [pscustomobject][ordered]@{
        contract_id=$TaskContractId
        absolute_path=$contractFull
        sha256=$actualContractSha
        source_classification='OWNER_LOCAL_NONCANONICAL_EVIDENCE'
        identity_basis='caller-supplied contract id plus absolute path plus raw-byte SHA-256'
        canonical=$false
        content_included=$false
        content_interpreted=$false
        authority_granted=$false
    }
}

$sourceRoles = [ordered]@{
    'START_HERE.md' = 'canonical startup router / provider routing / evidence hierarchy'
    'PROJECT_STATE.md' = 'current project status / binding decisions / forward plan'
    'AGENTS.md' = 'roles / permissions / hard stops / execution protocol'
    'AGENT_TASKBOARD.md' = 'active taskboard root manifest'
    'EA_SCORECARD_AND_REGISTRY.md' = 'EA verdict authority'
    'portfolio/DEPLOYMENTS.csv' = 'deployment truth'
    'VISION.md' = 'owner big-picture / factory philosophy'
    'docs/memory_control/FACT_OWNER_MAP.md' = 'fact to canonical-owner map'
}
$taskboardRootText = Get-RefFile 'AGENT_TASKBOARD.md'
$taskboardPartPaths = @(
    @($taskboardRootText -split "`r?`n") |
        Where-Object { $_ -match '^taskboards/active/[^\s]+\.md$' } |
        ForEach-Object { $_.Trim() }
)
foreach ($partPath in $taskboardPartPaths) {
    $sourceRoles[$partPath] = 'active taskboard part / order text / acceptance / execution state'
}
$sourceText = [ordered]@{}
$sourceMeta = New-Object Collections.Generic.List[object]
foreach ($path in $sourceRoles.Keys) {
    $text = $(if ($path -ceq 'AGENT_TASKBOARD.md') { $taskboardRootText } else { Get-RefFile $path })
    $sourceText[$path] = $text
    $sourceMeta.Add([pscustomobject][ordered]@{
        path=$path; role=$sourceRoles[$path]; sha256=(Get-Sha256Text $text); authoritative=$true
        sha256_basis='normalized UTF-8 text, trailing newline trimmed'
        git_blob=(Invoke-GitText @('rev-parse',("{0}:{1}" -f $sourceCommit,$path)))
    })
}$taskboardText = $sourceText['AGENT_TASKBOARD.md']
foreach ($partPath in $taskboardPartPaths) { $taskboardText += "`n" + $sourceText[$partPath] }
$stateLines = @($sourceText['PROJECT_STATE.md'] -split "`r?`n")
$programStart = -1
for ($i=0; $i -lt $stateLines.Count; $i++) {
    if ($stateLines[$i] -match '^## 1\. CURRENT PROGRAM STATUS') { $programStart=$i; break }
}
$projectLines = if ($programStart -ge 0) {
    Get-BoundedLines ($stateLines[$programStart..([Math]::Min($programStart+35,$stateLines.Count-1))] -join "`n") 24
} else { Get-BoundedLines $sourceText['PROJECT_STATE.md'] 8 }
$hardStops = Get-MatchingLines $sourceText['AGENTS.md'] '(?i)hard stop|owner approval|LIVE|risk/default|force push|history rewrite' 36
$activeHeaders = @(Get-ActiveHeaders $taskboardText 24)
$orderBlock = Get-ExactOrderBlock -Texts $sourceText -Paths (@('AGENT_TASKBOARD.md') + $taskboardPartPaths) -ExactOrderId $OrderId
$taskSelection = if ($orderBlock.requested -and $null -ne $taskContract) {'CANONICAL_ORDER_PLUS_OWNER_LOCAL_CONTRACT'} elseif ($orderBlock.requested) {'CANONICAL_ORDER'} elseif ($null -ne $taskContract) {'OWNER_LOCAL_CONTRACT'} else {'NONE'}

$core = [ordered]@{
    schema_version = 1
    source_commit = $sourceCommit
    current_status_excerpt = @($projectLines)
    kernel = [ordered]@{
        authority_excerpt = @($hardStops)
        mandatory_docs_for_money_or_verdict = @('AGENTS.md','PROJECT_STATE.md','AGENT_TASKBOARD.md','EA_SCORECARD_AND_REGISTRY.md','portfolio/DEPLOYMENTS.csv')
        rule = 'This packet is a generated read-only aid. It never owns a fact, verdict, deployment, or risk decision.'
    }
    task = [ordered]@{
        selection_mode = $taskSelection
        order_id = $(if($orderBlock.requested){$OrderId}else{$null})
        order_lookup_state = $orderBlock.lookup_state
        order_found = $orderBlock.found
        order_complete = $orderBlock.complete
        order_source_path = $orderBlock.source_path
        order_line_count = $orderBlock.line_count
        active_headers = @($activeHeaders)
        order_excerpt = @($orderBlock.lines)
        taskboard_parts = @($taskboardPartPaths)
        owner_local_contract = $taskContract
    }
    sources = $sourceMeta.ToArray()
    omissions = @(
        'Full canonical documents are not copied into the packet.',
        'Active-order headers are bounded; a specifically requested canonical order is included as one complete peer-heading block.',
        'Owner-local contract content is never copied or interpreted; only its caller-bound identity, path, and raw-byte SHA-256 are recorded.',
        'Historical evidence bodies are referenced through canonical owners, not duplicated.'
    )
}
$coreJson = $core | ConvertTo-Json -Depth 12 -Compress
$packetHash = Get-Sha256Text $coreJson
$packet = [ordered]@{
    schema_version = 1
    non_authoritative = $true
    source_ref = $Ref
    source_commit = $sourceCommit
    origin_master_at_generation = $originMaster
    freshness = $(if($sourceCommit -ceq $originMaster){'FRESH'}else{'STALE'})
    freshness_basis = 'comparison with local origin/master tracking ref; not a remote network check'
    caller_verified_remote_sha = $(if($ExpectedRemoteSha){$ExpectedRemoteSha}else{$null})
    remote_verification = $(if($ExpectedRemoteSha){'CALLER_SUPPLIED_MATCH'}else{'NOT_PERFORMED'})
    source_commit_time = $sourceCommitTime
    packet_hash = $packetHash
    core = $core
}
$json = ($packet | ConvertTo-Json -Depth 14) + "`n"
if ($Stdout) { Write-Output $json; exit 0 }
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    if ([string]::IsNullOrWhiteSpace($ControlRoot)) {
        $ControlRoot = $env:EA_LAB_CONTROL_ROOT
    }
    if ([string]::IsNullOrWhiteSpace($ControlRoot)) {
        $driveRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Root))
        $ControlRoot = Join-Path $driveRoot 'EA_LAB_CONTROL'
    }
    $OutputPath = Join-Path (Join-Path $ControlRoot 'context-packets') ($sourceCommit + '.json')
}
$rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
$outFull = [IO.Path]::GetFullPath($OutputPath)
if ($outFull.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Context packets are transient and must not be written inside the repository.'
}
$parent = Split-Path -Parent $outFull
if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
[IO.File]::WriteAllText($outFull,$json,$Utf8NoBom)
Write-Output ("CONTEXT_PACKET {0} {1} {2}" -f $packet.freshness,$packet.packet_hash,$outFull)
