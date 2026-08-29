[CmdletBinding()]
param(
    [ValidateSet('Claim','Check','Transition','List','Get','Validate','Audit')][string]$Command = 'List',
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
    [string]$ExpectedState,
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
    $a1=Normalize-CriticalPath $A; $b1=Normalize-CriticalPath $B
    if ($a1 -ceq $b1) { return $true }
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
    if(-not (Test-Path -LiteralPath $RegistryRoot)){ New-Item -ItemType Directory -Force -Path $RegistryRoot | Out-Null }
    $target=Join-Path $RegistryRoot ($Record.lane_id + '.json')
    $tmp=Join-Path $RegistryRoot ('.lane-tmp-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup=Join-Path $RegistryRoot ('.lane-backup-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $text=($Record | ConvertTo-Json -Depth 10) + "`n"
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
        foreach($a in @($RequestedCritical)){ foreach($b in @($r.critical_paths)){ if(Test-PathOverlap $a $b){ $hit=$true; break } }; if($hit){ break } }
        if($hit){ $conflicts.Add([pscustomobject]@{lane_id=$r.lane_id;reason='critical_path_overlap';state=$r.state}); continue }
        if(-not [string]::IsNullOrWhiteSpace($RequestedRuntime) -and $RequestedRuntime -ceq [string]$r.runtime_lane){
            $conflicts.Add([pscustomobject]@{lane_id=$r.lane_id;reason='runtime_lane_overlap';state=$r.state})
        }
    }
    return $conflicts.ToArray()
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
        $quotedRepo='"' + $CanonicalRepo.Replace('"','\"') + '"'
        $head=[string]$Record.head_sha
        & cmd.exe /d /s /c ("git -C $quotedRepo cat-file -e $head^{commit} >nul 2>nul") | Out-Null
        if($LASTEXITCODE -eq 0){
            & cmd.exe /d /s /c ("git -C $quotedRepo merge-base --is-ancestor $head origin/master >nul 2>nul") | Out-Null
            if($LASTEXITCODE -eq 0){$canonicalRelation='ANCESTOR_OF_ORIGIN_MASTER'}else{$canonicalRelation='NOT_ANCESTOR_OF_ORIGIN_MASTER'}
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
        blocker_class=[string]$Record.blocker_class; direct_consumer=[string]$Record.direct_consumer; updated_at=[string]$Record.updated_at
    }
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
    if($Command -in @('Claim','Check')){
        Assert-ClaimInput
        $lock=Enter-RegistryLock
        $records=@(Read-LaneRecords)
        if(@($records | Where-Object { $_.lane_id -ceq $LaneId }).Count -gt 0){ Throw-LaneError 'lane_exists' "lane already exists: $LaneId" }
        $conflicts=@(New-ConflictList $records $LaneId $OwnerChat (-not $ReadOnly) $CriticalPaths $RuntimeLane)
        if($Command -ceq 'Check'){
            Write-Result ([pscustomobject]@{result=$(if($conflicts.Count -eq 0){'READY'}else{'WAITING_CONFLICT'});lane_id=$LaneId;conflicts=$conflicts})
            if($conflicts.Count -gt 0){ exit 2 } else { exit 0 }
        }
        if($conflicts.Count -gt 0){ Throw-LaneError 'conflict' (($conflicts | ConvertTo-Json -Compress) -replace "`r|`n",'') }
        $record=New-LaneRecord
        Test-LaneRecord $record '<new claim>'
        Write-LaneRecordAtomic $record
        Write-Result ([pscustomobject]@{result='CLAIMED';lane_id=$LaneId;state=$State;head_sha=$HeadSha;writer=(-not $ReadOnly)})
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
