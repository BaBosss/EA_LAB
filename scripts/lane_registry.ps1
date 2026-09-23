[CmdletBinding()]
param(
    [ValidateSet('Claim','Check','Transition','List','Get','Validate','Audit','AmendScope')][string]$Command = 'List',
    [string]$RegistryRoot = 'D:\EA_LAB_CONTROL\lanes\registry-v1',
    [string]$LaneId,
    [string]$OwnerChat,
    [string]$Worker,
    [string]$Objective,
    [string]$State = 'RUNNING',
    [string]$BaseSha,
    [string]$HeadSha,
    [string]$Worktree,
    [string]$Branch,
    [string[]]$AllowedPaths = @(),
    [string[]]$CriticalPaths = @(),
    [string]$RuntimeLane,
    [switch]$ReadOnly,
    [string[]]$Dependencies = @(),
    [string]$Reviewer,
    [string]$ReviewedHead,
    [string]$DirectConsumer,
    [string]$BlockerClass,
    [string]$SupersedeOwnLaneId = '',
    [string]$ExpectedState,
    [string]$ExpectedHead,
    [AllowEmptyCollection()][AllowEmptyString()][string[]]$AddPaths = @(),
    [string]$AuthorityRef,
    [string]$AuthoritySha256,
    [string]$NewState,
    [int]$LockTimeoutSeconds = 5,
    [string]$RepoRoot = 'D:\EA_LAB',
    [int]$StaleAfterHours = 24,
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$ValidStates = @('READY','RUNNING','WAITING','PAUSED','REVIEW','FROZEN','INTEGRATING','DONE','BLOCKED')
$ActiveWriterStates = @('RUNNING','REVIEW','FROZEN','INTEGRATING')
$Transitions = @{
    READY       = @('RUNNING','WAITING','BLOCKED')
    RUNNING     = @('PAUSED','WAITING','FROZEN','REVIEW','BLOCKED','DONE')
    WAITING     = @('READY','RUNNING','BLOCKED','DONE')
    PAUSED      = @('READY','RUNNING','WAITING','BLOCKED','DONE')
    FROZEN      = @('REVIEW','INTEGRATING','RUNNING','BLOCKED','DONE')
    REVIEW      = @('FROZEN','BLOCKED')
    INTEGRATING = @('DONE','BLOCKED')
    BLOCKED     = @('READY','WAITING','DONE')
    DONE        = @()
}
function Throw-LaneError {
    param([string]$Code,[string]$Message)
    throw "LANE_REGISTRY[$Code] $Message"
}
function Test-Sha {
    param([string]$Value)
    return (-not [string]::IsNullOrWhiteSpace($Value)) -and ($Value -cmatch '^[0-9a-f]{40}$')
}
function Normalize-CriticalPath {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { Throw-LaneError 'bad_path' 'critical path must not be empty' }
    if ($Value -match '[*?\[\]]') { Throw-LaneError 'ambiguous_path' "critical path must be a literal prefix, not a wildcard: $Value" }
    $v=$Value.Trim().Replace('\','/').Trim('/')
    if ([string]::IsNullOrWhiteSpace($v)) { Throw-LaneError 'bad_path' 'critical path normalizes to empty' }
    return $v.ToLowerInvariant()
}
function Test-PathOverlap {
    param([string]$A,[string]$B)
    # Validation is separate from identity: never trim literal Unicode whitespace
    # or use linguistic equality when comparing already-admitted scope paths.
    $a1=Get-AmendPathKey $A; $b1=Get-AmendPathKey $B
    if ([string]::Equals($a1,$b1,[System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($a1.StartsWith($b1 + '/',[System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($b1.StartsWith($a1 + '/',[System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $false
}
function Write-Result {
    param($Object)
    if ($Json) { $Object | ConvertTo-Json -Depth 10 -Compress }
    else { $Object | Format-List | Out-String | Write-Output }
}
function Enter-RegistryLock {
    if (-not (Test-Path -LiteralPath $RegistryRoot)) { New-Item -ItemType Directory -Force -Path $RegistryRoot | Out-Null }
    $lockPath=Join-Path $RegistryRoot '.lane-registry.lock'
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt $LockTimeoutSeconds) {
        try {
            $stream=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
            return [pscustomobject]@{Stream=$stream;Path=$lockPath}
        } catch [IO.IOException] { Start-Sleep -Milliseconds 60 }
    }
    Throw-LaneError 'lock_timeout' "registry lock timed out after $LockTimeoutSeconds seconds"
}
function Exit-RegistryLock {
    param($Lock)
    if ($null -ne $Lock -and $null -ne $Lock.Stream) { $Lock.Stream.Dispose() }
}
function Get-LaneFiles {
    if (-not (Test-Path -LiteralPath $RegistryRoot)) { return @() }
    return @(Get-ChildItem -LiteralPath $RegistryRoot -File -Filter '*.json' | Sort-Object Name)
}
function Test-LaneRecord {
    param($Record,[string]$Source)
    $required=@('lane_id','owner_chat','worker','objective','state','base_sha','head_sha','worktree','branch','allowed_paths','critical_paths','writer','dependencies','direct_consumer','updated_at')
    foreach($name in $required){
        if($Record.PSObject.Properties.Name -notcontains $name){ Throw-LaneError 'registry_malformed' "$Source missing field '$name'" }
    }
    if([string]$Record.lane_id -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'){ Throw-LaneError 'registry_malformed' "$Source has invalid lane_id" }
    if($ValidStates -notcontains [string]$Record.state){ Throw-LaneError 'registry_malformed' "$Source has invalid state '$($Record.state)'" }
    if(-not (Test-Sha ([string]$Record.base_sha))){ Throw-LaneError 'registry_malformed' "$Source has invalid base_sha" }
    if(-not (Test-Sha ([string]$Record.head_sha))){ Throw-LaneError 'registry_malformed' "$Source has invalid head_sha" }
    if(-not [IO.Path]::IsPathRooted([string]$Record.worktree)){ Throw-LaneError 'registry_malformed' "$Source worktree must be absolute" }
    if($Record.writer -isnot [bool]){ Throw-LaneError 'registry_malformed' "$Source writer must be boolean" }
    foreach($p in @($Record.critical_paths)){ [void](Normalize-CriticalPath ([string]$p)) }
    if([string]::IsNullOrWhiteSpace([string]$Record.direct_consumer)){ Throw-LaneError 'registry_malformed' "$Source direct_consumer is empty" }
}
function Read-LaneRecords {
    $records=New-Object Collections.Generic.List[object]
    foreach($file in @(Get-LaneFiles)){
        try { $obj=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { Throw-LaneError 'registry_malformed' "cannot parse $($file.FullName): $($_.Exception.Message)" }
        Test-LaneRecord $obj $file.FullName
        $records.Add($obj)
    }
    return $records.ToArray()
}
function Write-LaneRecordAtomic {
    param($Record)
    # Every full-record writer shares the serializer's supported ceiling. Inspect
    # first: ConvertTo-Json can otherwise silently replace deep objects by strings.
    Assert-RegistryJsonDepth $Record
    $text=(ConvertTo-Json -InputObject $Record -Depth 100 -WarningAction Stop) + "`n"
    $roundtrip=$text | ConvertFrom-Json
    if((ConvertTo-Json -InputObject $roundtrip -Depth 100 -WarningAction Stop) + "`n" -cne $text){
        Throw-LaneError 'preservation_failed' 'record JSON cannot round-trip losslessly'
    }
    if(-not (Test-Path -LiteralPath $RegistryRoot)){ New-Item -ItemType Directory -Force -Path $RegistryRoot | Out-Null }
    $target=Join-Path $RegistryRoot ($Record.lane_id + '.json')
    $tmp=Join-Path $RegistryRoot ('.lane-tmp-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup=Join-Path $RegistryRoot ('.lane-backup-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($tmp,$text,$Utf8NoBom)
        $fs=[IO.File]::Open($tmp,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try { $fs.Flush($true) } finally { $fs.Dispose() }
        if(Test-Path -LiteralPath $target){ [IO.File]::Replace($tmp,$target,$backup) }
        else { [IO.File]::Move($tmp,$target) }
    } finally {
        if(Test-Path -LiteralPath $tmp){ Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        if(Test-Path -LiteralPath $backup){ Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
    }
}
function Invoke-GitText {
    param([string]$Root,[string[]]$GitArgs)
    $out=& git -C $Root @GitArgs 2>$null
    if($LASTEXITCODE -ne 0){ Throw-LaneError 'git_state' "git command failed in ${Root}: git $($GitArgs -join ' ')" }
    return (($out | Out-String).Trim())
}
function Assert-WorktreeIdentity {
    param([string]$Path,[string]$ExpectedBranch,[string]$ExpectedHead,[bool]$RequireClean)
    if(-not (Test-Path -LiteralPath $Path)){ Throw-LaneError 'worktree_missing' "worktree not found: $Path" }
    if((Invoke-GitText -Root $Path -GitArgs @('rev-parse','--is-inside-work-tree')) -cne 'true'){ Throw-LaneError 'git_state' "$Path is not a git worktree" }
    $actualHead=Invoke-GitText -Root $Path -GitArgs @('rev-parse','HEAD')
    if($actualHead -cne $ExpectedHead){ Throw-LaneError 'stale_head' "worktree HEAD $actualHead != requested $ExpectedHead" }
    $actualBranch=Invoke-GitText -Root $Path -GitArgs @('rev-parse','--abbrev-ref','HEAD')
    if($actualBranch -cne $ExpectedBranch){ Throw-LaneError 'branch_mismatch' "worktree branch $actualBranch != requested $ExpectedBranch" }
    if($RequireClean){
        $dirty=Invoke-GitText -Root $Path -GitArgs @('status','--porcelain=v1','--untracked-files=no')
        if(-not [string]::IsNullOrWhiteSpace($dirty)){ Throw-LaneError 'worktree_dirty' "tracked worktree is dirty: $Path" }
    }
}
function New-ConflictList {
    param([object[]]$Records,[string]$RequestedLane,[string]$RequestedOwner,[bool]$RequestedWriter,[string[]]$RequestedCritical,[string]$RequestedRuntime)
    $conflicts=New-Object Collections.Generic.List[object]
    if(-not $RequestedWriter){ return $conflicts.ToArray() }
    foreach($r in @($Records)){
        if([string]$r.lane_id -ceq $RequestedLane){ continue }
        if(-not [bool]$r.writer -or $ActiveWriterStates -notcontains [string]$r.state){ continue }
        if([string]$r.owner_chat -ceq $RequestedOwner){
            $conflicts.Add([pscustomobject]@{lane_id=$r.lane_id;reason='owner_chat_active_writer';state=$r.state})
            continue
        }
        $hit=$false
        foreach($a in @($RequestedCritical)){
            foreach($b in @($r.critical_paths)){
                if(Test-PathOverlap $a $b){ $hit=$true; break }
            }
            if($hit){ break }
        }
        if($hit){ $conflicts.Add([pscustomobject]@{lane_id=$r.lane_id;reason='critical_path_overlap';state=$r.state}); continue }
        if(-not [string]::IsNullOrWhiteSpace($RequestedRuntime) -and $RequestedRuntime -ceq [string]$r.runtime_lane){
            $conflicts.Add([pscustomobject]@{lane_id=$r.lane_id;reason='runtime_lane_overlap';state=$r.state})
        }
    }
    return $conflicts.ToArray()
}
function Invoke-GitExitCode {
    param([string]$Root,[string[]]$GitArgs)
    $saved=$ErrorActionPreference
    try {
        $ErrorActionPreference='SilentlyContinue'
        & git -C $Root @GitArgs 2>$null | Out-Null
        return $LASTEXITCODE
    } finally { $ErrorActionPreference=$saved }
}

function Get-LaneAuditRecord {
    param($Record,[string]$CanonicalRepo,[int]$StaleHours)
    $now=[DateTimeOffset]::UtcNow
    $updated=$null; $ageHours=$null
    try { $updated=[DateTimeOffset]::Parse([string]$Record.updated_at); $ageHours=[math]::Round(($now-$updated).TotalHours,2) } catch {}
    $wtExists=Test-Path -LiteralPath ([string]$Record.worktree)
    $headMatch=$null; $branchMatch=$null
    if($wtExists){
        try {
            $headMatch=((Invoke-GitText -Root ([string]$Record.worktree) -GitArgs @('rev-parse','HEAD')) -ceq [string]$Record.head_sha)
            $branchMatch=((Invoke-GitText -Root ([string]$Record.worktree) -GitArgs @('rev-parse','--abbrev-ref','HEAD')) -ceq [string]$Record.branch)
        } catch { $headMatch=$false; $branchMatch=$false }
    }
    $canonicalRelation='UNKNOWN'
    if(Test-Path -LiteralPath $CanonicalRepo){
        $head=[string]$Record.head_sha
        if((Invoke-GitExitCode -Root $CanonicalRepo -GitArgs @('cat-file','-e',("$head^{commit}"))) -eq 0){
            if((Invoke-GitExitCode -Root $CanonicalRepo -GitArgs @('merge-base','--is-ancestor',$head,'origin/master')) -eq 0){$canonicalRelation='ANCESTOR_OF_ORIGIN_MASTER'}
            else {$canonicalRelation='NOT_ANCESTOR_OF_ORIGIN_MASTER'}
        }
    }
    $class='QUEUED_CURRENT'; $attention=$false
    if([string]$Record.state -ceq 'DONE'){ $class='CLOSED' }
    elseif($ActiveWriterStates -contains [string]$Record.state){
        if(-not $wtExists){$class='ACTIVE_MISSING_WORKTREE';$attention=$true}
        elseif($headMatch -eq $false -or $branchMatch -eq $false){$class='ACTIVE_IDENTITY_MISMATCH';$attention=$true}
        elseif($null -ne $ageHours -and $ageHours -gt $StaleHours){$class='ACTIVE_AGED';$attention=$true}
        else {$class='ACTIVE_CURRENT'}
    } elseif($null -eq $ageHours -or $ageHours -gt $StaleHours){$class='STALE_NONACTIVE';$attention=$true}
    return [pscustomobject][ordered]@{
        lane_id=[string]$Record.lane_id; state=[string]$Record.state; writer=[bool]$Record.writer
        owner_chat=[string]$Record.owner_chat; classification=$class; attention_required=$attention
        age_hours=$ageHours; worktree_exists=$wtExists; head_matches_record=$headMatch; branch_matches_record=$branchMatch
        canonical_relation=$canonicalRelation; head_sha=[string]$Record.head_sha; runtime_lane=[string]$Record.runtime_lane
        worker=[string]$Record.worker; branch=[string]$Record.branch; worktree=[string]$Record.worktree
        reviewer=[string]$Record.reviewer; reviewed_head=[string]$Record.reviewed_head
        dependencies=$Record.dependencies
        blocker_class=[string]$Record.blocker_class; direct_consumer=[string]$Record.direct_consumer; updated_at=[string]$Record.updated_at
    }
}

# Shared literal identity for conflict checks and AmendScope membership only.
function Get-AmendPathKey([string]$Value) {
    # Windows separators and a terminal directory separator are identity aliases;
    # Unicode whitespace/normalization forms are literal filename characters.
    return $Value.Replace('\','/').TrimEnd('/')
}
function Assert-RegistryJsonDepth($Value,[int]$Depth=0,[int]$Limit=100) {
    if($Depth -gt $Limit){ Throw-LaneError 'registry_malformed' 'record JSON exceeds safe lossless depth' }
    if($Value -is [Collections.IDictionary]){ foreach($key in $Value.Keys){ Assert-RegistryJsonDepth $Value[$key] ($Depth+1) $Limit } }
    elseif($Value -is [array]){ foreach($item in $Value){ Assert-RegistryJsonDepth $item ($Depth+1) $Limit } }
    elseif($Value -is [pscustomobject]){ foreach($prop in $Value.PSObject.Properties){ Assert-RegistryJsonDepth $prop.Value ($Depth+1) $Limit } }
}
function Assert-AmendJsonDepth($Value,[int]$Depth=0) {
    # Retain V1's admission bound; the common writer also supports deeper legacy
    # records up to the JSON serializer ceiling, never a smaller writer default.
    Assert-RegistryJsonDepth $Value $Depth 80
}
function Get-AmendJson($Value) {
    Assert-AmendJsonDepth $Value
    return (ConvertTo-Json -InputObject $Value -Depth 100 -Compress)
}
function Get-AmendDigest($Value) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Utf8NoBom.GetBytes((Get-AmendJson $Value))))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-PreservedFields($Record) {
    $fields=[ordered]@{}
    foreach($p in $Record.PSObject.Properties){
        if($p.Name -cnotin @('allowed_paths','critical_paths','scope_amendments')){ $fields[$p.Name]=$p.Value }
    }
    return $fields
}
function Assert-LiteralAncestor([string]$FullPath) {
    # Reject every reparse ancestor (including in-repo links) rather than guessing at
    # junction/symlink/provider-specific resolution. New suffixes need a real directory.
    $cursor=[IO.Path]::GetFullPath($FullPath); $missing=$false
    while($cursor){
        $item=$null
        try { $item=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop }
        catch [System.Management.Automation.ItemNotFoundException] {
            # Only the filesystem provider's explicit PathNotFound establishes
            # absence. Access, IO and other provider failures are not absence.
            if($_.CategoryInfo.Category -ne [Management.Automation.ErrorCategory]::ObjectNotFound -or
                ($_.FullyQualifiedErrorId -split ',')[0] -cne 'PathNotFound'){
                Throw-LaneError 'unsafe_path' "cannot inspect ancestor: $cursor"
            }
        }
        catch { Throw-LaneError 'unsafe_path' "cannot inspect ancestor: $cursor ($($_.Exception.Message))" }
        if($null -ne $item){
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){ Throw-LaneError 'unsafe_path' "reparse ancestor: $cursor" }
            if($missing -and -not $item.PSIsContainer){ Throw-LaneError 'unsafe_path' "new suffix below non-directory: $cursor" }
            $missing=$false
        } else { $missing=$true }
        $parent=[IO.Path]::GetDirectoryName($cursor)
        if(-not $parent){
            if($null -eq $item){ Throw-LaneError 'unsafe_path' "unverifiable path root: $cursor" }
            break
        }
        $cursor=$parent
    }
}
function Convert-AmendPath([string]$Value,[string]$Root) {
    if([string]::IsNullOrWhiteSpace($Value) -or $Value -match '[\p{Cc}:*?\[\]<>|"~]' -or $Value -match '^[/\\]'){
        Throw-LaneError 'unsafe_path' "not a literal repository-relative path: $Value"
    }
    $rel=$Value.Replace('\','/')
    foreach($part in $rel.Split('/')){
        if(-not $part -or $part -in @('.','..') -or $part -match '^[ .]|[ .]$' -or
            $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3]|CONIN\$|CONOUT\$)(\.|$)' -or $part -ieq '.git'){
            Throw-LaneError 'unsafe_path' "ambiguous Windows component: $Value"
        }
    }
    $full=[IO.Path]::GetFullPath((Join-Path $Root $rel))
    $prefix=[IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){ Throw-LaneError 'unsafe_path' "path escapes repository: $Value" }
    Assert-LiteralAncestor $full
    return $rel
}
function Resolve-AmendAuthority([string]$Value) {
    # IsPathRooted also accepts C:relative and UNC. V1 requires a drive-qualified
    # local filesystem path and excludes device namespaces and alternate streams.
    if($Value -notmatch '^[A-Za-z]:[/\\]' -or $Value.Substring(2) -match '[:\p{Cc}*?<>|\"]'){
        Throw-LaneError 'authority_reference' 'AuthorityRef must be a fully qualified local file path'
    }
    $full=[IO.Path]::GetFullPath($Value)
    $drive=New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($full))
    if($drive.DriveType -in @([IO.DriveType]::Network,[IO.DriveType]::Unknown,[IO.DriveType]::NoRootDirectory)){
        Throw-LaneError 'authority_reference' 'AuthorityRef must use a local filesystem drive'
    }
    Assert-LiteralAncestor $full
    if(-not (Test-Path -LiteralPath $full -PathType Leaf)){
        Throw-LaneError 'authority_reference' 'AuthorityRef must name an existing local file'
    }
    return (Get-Item -LiteralPath $full -Force -ErrorAction Stop).FullName
}
function Get-AmendNamespace([string]$Value,[string]$Root) {
    # Legacy absolute entries stay stored verbatim. Resolve only for this admission.
    if(-not (Test-Path -LiteralPath $Root -PathType Container)){ Throw-LaneError 'unsafe_namespace' "unverifiable worktree namespace: $Root" }
    Assert-LiteralAncestor $Root
    if([IO.Path]::IsPathRooted($Value)){
        if($Value -notmatch '^[A-Za-z]:[/\\]' -or $Value.Substring(2) -match '[:*?\[\]\x00-\x1f\x7f]' -or $Value -match '[/\\]\.\.?([/\\]|$)'){
            Throw-LaneError 'unsafe_namespace' "unresolved absolute scope: $Value"
        }
        $full=[IO.Path]::GetFullPath($Value)
        Assert-LiteralAncestor $full
        foreach($anchor in @($script:AmendNamespaceRoots)+@($Root)){
            $prefix=[IO.Path]::GetFullPath($anchor).TrimEnd('\','/')
            if($full -ieq $prefix){ return '.' }
            if($full.StartsWith($prefix+'\',[StringComparison]::OrdinalIgnoreCase)){
                return (Convert-AmendPath $full.Substring($prefix.Length+1) $anchor)
            }
        }
        # Check Windows components even for safely disjoint external namespaces.
        [void](Convert-AmendPath $full.Substring(3) $full.Substring(0,3))
        return $full.Replace('\','/')
    }
    return (Convert-AmendPath $Value $Root)
}
function Assert-AmendIdentity($Record) {
    Assert-LiteralAncestor ([string]$Record.worktree)
    Assert-WorktreeIdentity ([string]$Record.worktree) ([string]$Record.branch) $ExpectedHead $false
    $top=Invoke-GitText $Record.worktree @('rev-parse','--show-toplevel')
    if([IO.Path]::GetFullPath($top).TrimEnd('\','/') -ine [IO.Path]::GetFullPath($Record.worktree).TrimEnd('\','/')){
        Throw-LaneError 'repository_mismatch' 'lane worktree must be the repository top level'
    }
    $common=Invoke-GitText $Record.worktree @('rev-parse','--path-format=absolute','--git-common-dir')
    $expectedCommon=Invoke-GitText $RepoRoot @('rev-parse','--path-format=absolute','--git-common-dir')
    if([IO.Path]::GetFullPath($common) -ine [IO.Path]::GetFullPath($expectedCommon)){
        Throw-LaneError 'repository_mismatch' 'lane and RepoRoot are different repositories'
    }
}
function Invoke-AmendScope([object[]]$Records,$Bound) {
    $permitted=@('Command','RegistryRoot','RepoRoot','LaneId','ExpectedState','ExpectedHead','AddPaths','AuthorityRef','AuthoritySha256','LockTimeoutSeconds','Json')
    foreach($key in $Bound.Keys){ if($key -notin $permitted){ Throw-LaneError 'amend_parameter' "AmendScope does not accept $key" } }
    foreach($key in @('LaneId','ExpectedState','ExpectedHead','AuthorityRef','AuthoritySha256')){
        if(-not $Bound.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$Bound[$key])){ Throw-LaneError 'missing_argument' "AmendScope requires $key" }
    }
    if(-not (Test-Sha $ExpectedHead)){ Throw-LaneError 'bad_sha' 'ExpectedHead must be a full lowercase 40-hex SHA' }
    if($AuthoritySha256 -cnotmatch '^[0-9a-fA-F]{64}$'){ Throw-LaneError 'authority_hash' 'AuthoritySha256 must be 64 hex characters' }
    # Also refuse duplicate identity/file aliases before selecting a mutation target.
    $ids=@{}
    foreach($file in @(Get-LaneFiles)){
        $row=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if($ids.ContainsKey([string]$row.lane_id) -or $file.BaseName -cne [string]$row.lane_id){ Throw-LaneError 'registry_malformed' 'duplicate or misnamed lane record' }
        $ids[[string]$row.lane_id]=$true
    }
    $matches=@($Records | Where-Object { $_.lane_id -ceq $LaneId })
    if($matches.Count -ne 1){ Throw-LaneError 'lane_missing' "expected exactly one lane: $LaneId" }
    $r=$matches[0]
    if(-not $r.writer){ Throw-LaneError 'not_writer' 'AmendScope requires an existing writer lane' }
    if([string]$r.state -cne $ExpectedState){ Throw-LaneError 'stale_state' 'ExpectedState does not match' }
    if($ExpectedState -cnotin @('BLOCKED','WAITING','PAUSED','READY')){ Throw-LaneError 'amend_state' 'state does not permit scope amendment' }
    if([string]$r.head_sha -cne $ExpectedHead){ Throw-LaneError 'stale_head' 'ExpectedHead does not match' }
    if(-not [string]::IsNullOrEmpty([string]$r.reviewed_head)){ Throw-LaneError 'review_present' 'reviewed_head must be empty' }
    Assert-AmendIdentity $r
    # Absolute historical paths may name ANY linked checkout of this repository,
    # not only the competitor's own worktree. Longest prefix handles nested roots.
    $worktrees=Invoke-GitText $RepoRoot @('-c','core.quotePath=false','worktree','list','--porcelain')
    $script:AmendNamespaceRoots=@($worktrees -split "`n" | Where-Object { $_.StartsWith('worktree ') } | ForEach-Object { $_.Substring(9).TrimEnd("`r") } | Sort-Object Length -Descending)
    if(@($AddPaths).Count -eq 0){ Throw-LaneError 'missing_scope' 'AddPaths must not be empty' }
    $requested=@($AddPaths | ForEach-Object { Convert-AmendPath $_ ([string]$r.worktree) })
    $resolvedAuthority=Resolve-AmendAuthority $AuthorityRef
    if((Get-FileHash -LiteralPath $resolvedAuthority -Algorithm SHA256).Hash -ine $AuthoritySha256){ Throw-LaneError 'authority_hash' 'authority reference content hash mismatch' }
    foreach($field in @('allowed_paths','critical_paths')){
        if($r.$field -isnot [array]){ Throw-LaneError 'registry_malformed' "$field must be an array" }
    }
    if($r.PSObject.Properties.Name -contains 'scope_amendments' -and $r.scope_amendments -isnot [array]){
        Throw-LaneError 'registry_malformed' 'scope_amendments must be an array'
    }
    $before=[ordered]@{allowed_paths=@($r.allowed_paths);critical_paths=@($r.critical_paths)}
    $preservedDigest=Get-AmendDigest (Get-PreservedFields $r)
    $additions=[ordered]@{allowed_paths=@();critical_paths=@()}
    foreach($field in @('allowed_paths','critical_paths')){
        $existing=@($r.$field)
        $normalized=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach($path in $existing){ [void]$normalized.Add((Get-AmendPathKey $path)) }
        foreach($path in $requested){
            if($normalized.Add((Get-AmendPathKey $path))){ $existing+=@($path); $additions[$field]+= @($path) }
        }
        $r.$field=$existing
    }
    # Namespace resolution is scoped to this command. Use shared literal conflicts,
    # then check full resulting allowed AND critical scope against active competitors.
    $conflicts=@(New-ConflictList $Records $LaneId ([string]$r.owner_chat) $true @($r.critical_paths) ([string]$r.runtime_lane))
    if($conflicts.Count){ Throw-LaneError 'conflict' (Get-AmendJson $conflicts) }
    $targetScope=@(@($r.allowed_paths)+@($r.critical_paths) | ForEach-Object { Get-AmendNamespace $_ ([string]$r.worktree) })
    foreach($other in $Records){
        if($other.lane_id -ceq $LaneId -or -not $other.writer -or $other.state -notin $ActiveWriterStates){ continue }
        if($other.critical_paths -isnot [array] -or $other.critical_paths.Count -eq 0){ Throw-LaneError 'unsafe_namespace' "active writer has no resolvable critical scope: $($other.lane_id)" }
        foreach($path in @($other.critical_paths)){
            $competitor=Get-AmendNamespace $path ([string]$other.worktree)
            foreach($candidate in $targetScope){
                if($candidate -eq '.' -or $competitor -eq '.' -or (Test-PathOverlap $candidate $competitor)){
                    Throw-LaneError 'conflict' "critical_path_overlap: $($other.lane_id)"
                }
            }
        }
    }
    if($additions.allowed_paths.Count + $additions.critical_paths.Count -eq 0){
        Write-Result ([pscustomobject]@{result='NO_CHANGE';lane_id=$LaneId;state=$r.state;head_sha=$r.head_sha})
        return
    }
    $after=[ordered]@{allowed_paths=@($r.allowed_paths);critical_paths=@($r.critical_paths)}
    $receipt=[pscustomobject][ordered]@{
        authority_ref=$resolvedAuthority;authority_sha256=$AuthoritySha256.ToLowerInvariant()
        lane_identity=[ordered]@{lane_id=$r.lane_id;owner_chat=$r.owner_chat;worker=$r.worker;objective=$r.objective;base_sha=$r.base_sha;worktree=$r.worktree;branch=$r.branch}
        state=$r.state;head_sha=$r.head_sha;requested_paths=@($requested);actual_additions=$additions
        before_scope_sha256=(Get-AmendDigest $before);after_scope_sha256=(Get-AmendDigest $after)
        timestamp=[DateTimeOffset]::UtcNow.ToString('o');preserved_non_scope_sha256=$preservedDigest
    }
    $history=@(); if($r.PSObject.Properties.Name -contains 'scope_amendments'){ $history=@($r.scope_amendments) }
    $r | Add-Member -NotePropertyName scope_amendments -NotePropertyValue @($history+@($receipt)) -Force
    $serialized=Get-AmendJson $r
    $roundtrip=$serialized | ConvertFrom-Json
    if((Get-AmendDigest (Get-PreservedFields $roundtrip)) -cne $preservedDigest -or (Get-AmendJson $roundtrip) -cne $serialized){
        Throw-LaneError 'preservation_failed' 'candidate cannot preserve lane fields losslessly'
    }
    Test-LaneRecord $roundtrip '<scope amendment>'
    Write-LaneRecordAtomic $roundtrip
    $readback=Get-Content -LiteralPath (Join-Path $RegistryRoot ($LaneId+'.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
    if((Get-AmendJson $readback) -cne $serialized){ Throw-LaneError 'readback_failed' 'atomic amendment readback differs from candidate' }
    Write-Result ([pscustomobject]@{result='AMENDED';lane_id=$LaneId;state=$r.state;head_sha=$r.head_sha;receipt=$receipt})
}

function Assert-ClaimInput {
    $required=@{'LaneId'=$LaneId;'OwnerChat'=$OwnerChat;'Worker'=$Worker;'Objective'=$Objective;'BaseSha'=$BaseSha;'Worktree'=$Worktree;'Branch'=$Branch;'DirectConsumer'=$DirectConsumer}
    foreach($k in $required.Keys){ if([string]::IsNullOrWhiteSpace([string]$required[$k])){ Throw-LaneError 'missing_argument' "$k is required" } }
    if($LaneId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$'){ Throw-LaneError 'bad_lane_id' "invalid lane id: $LaneId" }
    if($ValidStates -notcontains $State){ Throw-LaneError 'bad_state' "invalid state: $State" }
    if(-not (Test-Sha $BaseSha)){ Throw-LaneError 'bad_sha' 'BaseSha must be a lowercase 40-hex SHA' }
    if([string]::IsNullOrWhiteSpace($HeadSha)){ $script:HeadSha=$BaseSha }
    if(-not (Test-Sha $HeadSha)){ Throw-LaneError 'bad_sha' 'HeadSha must be a lowercase 40-hex SHA' }
    if(-not $ReadOnly -and @($AllowedPaths).Count -eq 0){ Throw-LaneError 'missing_scope' 'writer claim requires AllowedPaths' }
    if(-not $ReadOnly -and @($CriticalPaths).Count -eq 0){ Throw-LaneError 'missing_scope' 'writer claim requires CriticalPaths' }
    foreach($p in @($CriticalPaths)){ [void](Normalize-CriticalPath $p) }
    $requireClean=(-not $ReadOnly) -and ($State -in @('READY','RUNNING','REVIEW','FROZEN','INTEGRATING'))
    Assert-WorktreeIdentity $Worktree $Branch $HeadSha $requireClean
}
function New-LaneRecord {
    return [pscustomobject][ordered]@{
        lane_id=$LaneId; owner_chat=$OwnerChat; worker=$Worker; objective=$Objective; state=$State
        base_sha=$BaseSha; head_sha=$HeadSha; worktree=[IO.Path]::GetFullPath($Worktree); branch=$Branch
        allowed_paths=@($AllowedPaths); critical_paths=@($CriticalPaths); runtime_lane=$RuntimeLane
        writer=(-not $ReadOnly); dependencies=@($Dependencies); reviewer=$Reviewer; reviewed_head=$ReviewedHead
        direct_consumer=$DirectConsumer; blocker_class=$BlockerClass
        updated_at=[DateTimeOffset]::UtcNow.ToString('o')
    }
}
$lock=$null
try {
    if($Command -ieq 'AmendScope'){
        $lock=Enter-RegistryLock
        $records=@(Read-LaneRecords)
        Invoke-AmendScope $records $PSBoundParameters
        exit 0
    }
    if($Command -in @('Claim','Check')){
        Assert-ClaimInput
        $lock=Enter-RegistryLock
        $records=@(Read-LaneRecords)
        if(@($records | Where-Object { $_.lane_id -ceq $LaneId }).Count -gt 0){ Throw-LaneError 'lane_exists' "lane already exists: $LaneId" }
        $superseded=$null
        if(-not [string]::IsNullOrWhiteSpace($SupersedeOwnLaneId)){
            if($Command -cne 'Claim'){ Throw-LaneError 'supersede_check_refused' 'SupersedeOwnLaneId is valid only for Claim' }
            if($SupersedeOwnLaneId -ceq $LaneId){ Throw-LaneError 'supersede_self' 'a lane cannot supersede itself' }
            $oldMatches=@($records | Where-Object { $_.lane_id -ceq $SupersedeOwnLaneId })
            if($oldMatches.Count -ne 1){ Throw-LaneError 'supersede_missing' "expected exactly one superseded lane: $SupersedeOwnLaneId" }
            $superseded=$oldMatches[0]
            if([string]$superseded.owner_chat -cne $OwnerChat){ Throw-LaneError 'supersede_foreign' 'superseded lane must belong to the same owner_chat' }
            if([string]$superseded.state -ceq 'DONE'){ Throw-LaneError 'supersede_done' 'superseded lane is already DONE' }
            if($ActiveWriterStates -contains [string]$superseded.state){ Throw-LaneError 'supersede_active' "refusing to supersede active lane state=$($superseded.state)" }
            $supersededState=[string]$superseded.state
            if($Transitions[$supersededState] -notcontains 'DONE'){ Throw-LaneError 'supersede_illegal_transition' "supersede requires a legal $supersededState -> DONE transition" }
        }
        $conflicts=@(New-ConflictList $records $LaneId $OwnerChat (-not $ReadOnly) $CriticalPaths $RuntimeLane)
        if($Command -ceq 'Check'){
            Write-Result ([pscustomobject]@{result=$(if($conflicts.Count -eq 0){'READY'}else{'WAITING_CONFLICT'});lane_id=$LaneId;conflicts=$conflicts})
            if($conflicts.Count -gt 0){ exit 2 } else { exit 0 }
        }
        if($conflicts.Count -gt 0){ Throw-LaneError 'conflict' (($conflicts | ConvertTo-Json -Compress) -replace "`r|`n",'') }
        $record=New-LaneRecord
        Test-LaneRecord $record '<new claim>'
        Write-LaneRecordAtomic $record
        if($null -ne $superseded){
            $superseded.state='DONE'
            $superseded | Add-Member -NotePropertyName superseded_by -NotePropertyValue $LaneId -Force
            $superseded.updated_at=[DateTimeOffset]::UtcNow.ToString('o')
            Test-LaneRecord $superseded '<superseded own lane>'
            Write-LaneRecordAtomic $superseded
        }
        Write-Result ([pscustomobject]@{result='CLAIMED';lane_id=$LaneId;state=$State;head_sha=$HeadSha;writer=(-not $ReadOnly);superseded_lane=$(if($null -ne $superseded){[string]$superseded.lane_id}else{''})})
        exit 0
    }
    if($Command -ceq 'Transition'){
        if([string]::IsNullOrWhiteSpace($LaneId) -or [string]::IsNullOrWhiteSpace($ExpectedState) -or [string]::IsNullOrWhiteSpace($NewState)){ Throw-LaneError 'missing_argument' 'Transition requires LaneId, ExpectedState, and NewState' }
        if($ValidStates -notcontains $ExpectedState -or $ValidStates -notcontains $NewState){ Throw-LaneError 'bad_state' 'Transition contains an invalid state' }
        $lock=Enter-RegistryLock
        $records=@(Read-LaneRecords)
        $matches=@($records | Where-Object { $_.lane_id -ceq $LaneId })
        if($matches.Count -ne 1){ Throw-LaneError 'lane_missing' "expected exactly one lane record: $LaneId" }
        $r=$matches[0]
        if([string]$r.state -cne $ExpectedState){ Throw-LaneError 'stale_state' "lane state is $($r.state), expected $ExpectedState" }
        if($Transitions[$ExpectedState] -notcontains $NewState){ Throw-LaneError 'bad_transition' "$ExpectedState -> $NewState is not allowed" }
        $nextHead=[string]$r.head_sha
        if(-not [string]::IsNullOrWhiteSpace($HeadSha)){
            if(-not (Test-Sha $HeadSha)){ Throw-LaneError 'bad_sha' 'HeadSha must be lowercase 40-hex' }
            if($ExpectedState -in @('REVIEW','INTEGRATING')){ if($HeadSha -cne [string]$r.head_sha){ Throw-LaneError 'review_head_moved' 'review/integration lineage cannot move HEAD' } }
            if($ExpectedState -ceq 'FROZEN' -and $NewState -cne 'RUNNING' -and $HeadSha -cne [string]$r.head_sha){ Throw-LaneError 'review_head_moved' 'frozen lineage cannot move HEAD except by returning to RUNNING' }
            $nextHead=$HeadSha
        }
        if($NewState -ceq 'REVIEW'){
            if([string]::IsNullOrWhiteSpace($Reviewer)){ Throw-LaneError 'reviewer_required' 'REVIEW requires Reviewer' }
            $r.reviewer=$Reviewer; $r.reviewed_head=$null
        }
        if($ExpectedState -ceq 'REVIEW' -and $NewState -ceq 'FROZEN'){
            if([string]::IsNullOrWhiteSpace($Reviewer) -or -not (Test-Sha $ReviewedHead)){ Throw-LaneError 'review_result_required' 'REVIEW -> FROZEN requires Reviewer and ReviewedHead' }
            if($ReviewedHead -cne [string]$r.head_sha){ Throw-LaneError 'review_head_mismatch' "reviewed head $ReviewedHead != frozen head $($r.head_sha)" }
            $r.reviewer=$Reviewer; $r.reviewed_head=$ReviewedHead
        }
        if($NewState -ceq 'INTEGRATING'){
            if([string]$r.reviewed_head -cne $nextHead -or [string]::IsNullOrWhiteSpace([string]$r.reviewer)){ Throw-LaneError 'review_not_valid' 'INTEGRATING requires a reviewer and reviewed_head equal to head_sha' }
        }
        if($NewState -ceq 'RUNNING'){
            $r.reviewer=$null; $r.reviewed_head=$null
        }
        $r.head_sha=$nextHead
        if($ActiveWriterStates -contains $NewState -and [bool]$r.writer){
            $conflicts=@(New-ConflictList $records ([string]$r.lane_id) ([string]$r.owner_chat) $true @($r.critical_paths) ([string]$r.runtime_lane))
            if($conflicts.Count -gt 0){ Throw-LaneError 'conflict' (($conflicts | ConvertTo-Json -Compress) -replace "`r|`n",'') }
            Assert-WorktreeIdentity ([string]$r.worktree) ([string]$r.branch) $nextHead $true
        }
        $r.state=$NewState
        if($PSBoundParameters.ContainsKey('BlockerClass')){ $r.blocker_class=$BlockerClass }
        $r.updated_at=[DateTimeOffset]::UtcNow.ToString('o')
        Test-LaneRecord $r '<transition>'
        Write-LaneRecordAtomic $r
        Write-Result ([pscustomobject]@{result='TRANSITIONED';lane_id=$LaneId;from=$ExpectedState;to=$NewState;head_sha=$nextHead;reviewed_head=$r.reviewed_head})
        exit 0
    }
    $lock=Enter-RegistryLock
    $records=@(Read-LaneRecords)
    if($Command -ceq 'Validate'){
        Write-Result ([pscustomobject]@{result='VALID';count=$records.Count;registry_root=[IO.Path]::GetFullPath($RegistryRoot)})
        exit 0
    }
    if($Command -ceq 'Audit'){
        if($StaleAfterHours -lt 1){ Throw-LaneError 'bad_stale_window' 'StaleAfterHours must be >= 1' }
        # Registry bytes are snapshotted under lock; slow observational Git checks run after release.
        Exit-RegistryLock $lock; $lock=$null
        $audit=@($records | ForEach-Object { Get-LaneAuditRecord $_ $RepoRoot $StaleAfterHours })
        $summary=[ordered]@{}
        foreach($g in @($audit | Group-Object classification)){ $summary[$g.Name]=$g.Count }
        $result=[pscustomobject][ordered]@{
            result='AUDIT'; generated_at=[DateTimeOffset]::UtcNow.ToString('o'); stale_after_hours=$StaleAfterHours
            registry_root=[IO.Path]::GetFullPath($RegistryRoot); repo_root=$RepoRoot; counts=[pscustomobject]$summary; records=$audit
        }
        if($Json){ $result | ConvertTo-Json -Depth 10 -Compress }
        else { $audit | Sort-Object -Property @{Expression='attention_required';Descending=$true},classification,lane_id | Format-Table lane_id,state,classification,attention_required,age_hours,canonical_relation -AutoSize }
        exit 0
    }
    if($Command -ceq 'Get'){
        if([string]::IsNullOrWhiteSpace($LaneId)){ Throw-LaneError 'missing_argument' 'Get requires LaneId' }
        $matches=@($records | Where-Object { $_.lane_id -ceq $LaneId })
        if($matches.Count -ne 1){ Throw-LaneError 'lane_missing' "expected exactly one lane record: $LaneId" }
        Write-Result $matches[0]
        exit 0
    }
    if($Command -ceq 'List'){
        if($Json){ @($records) | ConvertTo-Json -Depth 10 -Compress }
        else { @($records) | Select-Object lane_id,state,writer,owner_chat,worker,base_sha,head_sha,worktree,branch,runtime_lane,updated_at | Format-Table -AutoSize }
        exit 0
    }
} finally { Exit-RegistryLock $lock }
