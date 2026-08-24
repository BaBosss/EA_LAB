[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Ref = 'origin/master',
    [string]$OrderId = '',
    [string]$OutputPath = '',
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
function Get-RefFile {
    param([string]$Path)
    return Invoke-GitText @('show',("{0}:{1}" -f $Ref,$Path))
}
function Get-BoundedLines {
    param([string]$Text,[int]$MaxLines = 40)
    $lines = @($Text -split "`r?`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    return @($lines | Select-Object -First $MaxLines)
}
function Get-MatchingLines {
    param([string]$Text,[string]$Pattern,[int]$MaxLines = 30)
    return @((@($Text -split "`r?`n") | Where-Object { $_ -match $Pattern }) | Select-Object -First $MaxLines)
}
function Get-OrderExcerpt {
    param([string]$Text,[string]$ExactOrderId,[int]$MaxLines = 90)
    if ([string]::IsNullOrWhiteSpace($ExactOrderId)) { return @() }
    $lines = @($Text -split "`r?`n")
    $start = -1
    for ($i=0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match [regex]::Escape($ExactOrderId)) { $start=$i; break }
    }
    if ($start -lt 0) { return @() }
    return @($lines[$start..([Math]::Min($lines.Count-1,$start+$MaxLines-1))])
}
$sourceCommit = Invoke-GitText @('rev-parse',($Ref + '^{commit}'))
$originMaster = Invoke-GitText @('rev-parse','origin/master')
$generatedAt = Invoke-GitText @('show','-s','--format=%cI',$sourceCommit)

$sourceRoles = [ordered]@{
    'PROJECT_STATE.md' = 'current project status / binding decisions / forward plan'
    'AGENTS.md' = 'roles / permissions / hard stops / execution protocol'
    'AGENT_TASKBOARD.md' = 'active order text / acceptance / execution state'
    'EA_SCORECARD_AND_REGISTRY.md' = 'EA verdict authority'
    'portfolio/DEPLOYMENTS.csv' = 'deployment truth'
    'VISION.md' = 'owner big-picture / factory philosophy'
    'docs/memory_control/FACT_OWNER_MAP.md' = 'fact to canonical-owner map'
}
$sourceText = [ordered]@{}
$sourceMeta = New-Object Collections.Generic.List[object]
foreach ($path in $sourceRoles.Keys) {
    $text = Get-RefFile $path
    $sourceText[$path] = $text
    $sourceMeta.Add([pscustomobject][ordered]@{
        path=$path; role=$sourceRoles[$path]; sha256=(Get-Sha256Text $text); authoritative=$true
    })
}
$projectLines = Get-BoundedLines $sourceText['PROJECT_STATE.md'] 8
$hardStops = Get-MatchingLines $sourceText['AGENTS.md'] '(?i)hard stop|owner approval|LIVE|risk/default|force push|history rewrite' 36
$activeHeaders = Get-MatchingLines $sourceText['AGENT_TASKBOARD.md'] '(?i)ORDER-[A-Za-z0-9._-]+.*(OPEN|CLAIMED|IN-PROGRESS|WAITING|BLOCKED|PARTIAL|READY)' 24
$orderExcerpt = Get-OrderExcerpt $sourceText['AGENT_TASKBOARD.md'] $OrderId 90

$core = [ordered]@{
    schema_version = 1
    source_commit = $sourceCommit
    current_status_excerpt = $projectLines
    kernel = [ordered]@{
        authority_excerpt = $hardStops
        mandatory_docs_for_money_or_verdict = @('AGENTS.md','PROJECT_STATE.md','AGENT_TASKBOARD.md','EA_SCORECARD_AND_REGISTRY.md','portfolio/DEPLOYMENTS.csv')
        rule = 'This packet is a generated read-only aid. It never owns a fact, verdict, deployment, or risk decision.'
    }
    task = [ordered]@{
        order_id = $(if([string]::IsNullOrWhiteSpace($OrderId)){$null}else{$OrderId})
        active_headers = $activeHeaders
        order_excerpt = $orderExcerpt
    }
    sources = $sourceMeta.ToArray()
    omissions = @('Full canonical documents are not copied into the packet.','Only bounded active-order/header excerpts are included.','Historical evidence bodies are referenced through canonical owners, not duplicated.')
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
    generated_at = $generatedAt
    packet_hash = $packetHash
    core = $core
}
$json = ($packet | ConvertTo-Json -Depth 14) + "`n"
if ($Stdout) { Write-Output $json; exit 0 }
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path 'D:\EA_LAB_CONTROL\context-packets' ($sourceCommit + '.json')
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
