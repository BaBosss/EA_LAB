<#
.SYNOPSIS
    ORDER-105 staged-snapshot guard for experiment event logs, evidence manifest,
    and immutable v1 schemas.

.DESCRIPTION
    Reads candidate bytes from the Git index, never from the working tree. It is
    a fast no-op unless an experiment-event path is staged. Established monthly
    files are immutable once a newer month exists; the latest month and manifest
    may only receive raw-byte prefix extensions. A non-prefix monthly replacement
    is accepted only as a schema-valid, authorized physical-recovery transaction
    that preserves every independently valid event line from a corrupt HEAD blob.
#>
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = 'Stop'
. (Join-Path $RepoRoot 'scripts\experiment_event_log.ps1') -RepoRoot $RepoRoot

$EventRoot = 'docs/memory_control/experiment_events'
$ManifestRel = "$EventRoot/evidence-manifest.jsonl"
$EventSchemaRel = "$EventRoot/schema/event-v1.schema.json"
$EvidenceSchemaRel = "$EventRoot/schema/evidence-v1.schema.json"

function Test-ProtectedEventPath {
    param([string]$Path)
    return ($Path -ceq $ManifestRel -or $Path -ceq $EventSchemaRel -or $Path -ceq $EvidenceSchemaRel -or $Path -cmatch ('^' + [regex]::Escape($EventRoot) + '/events-.*\.jsonl$') -or $Path -cmatch ('^' + [regex]::Escape($EventRoot) + '/schema/'))
}

function Test-AllowedEventPath {
    param([string]$Path)
    return ($Path -ceq $ManifestRel -or $Path -ceq $EventSchemaRel -or $Path -ceq $EvidenceSchemaRel -or $Path -cmatch ('^' + [regex]::Escape($EventRoot) + '/events-[0-9]{4}-(0[1-9]|1[0-2])\.jsonl$'))
}

function Get-NameStatusRows {
    param([string]$Root)
    # snapshot: index -- what this commit stages. The trigger and the candidate bytes must come
    # from one vintage, or the guard decides WHETHER to run from one moment and WHAT to judge
    # from another (GUARD_SHAPES A2).
    $r=Invoke-GitText -Root $Root -Arguments @('diff','--cached','--name-status','--no-renames')
    $rows=New-Object System.Collections.Generic.List[object]
    foreach($line in ($r.Text -split "`n")){
        if(-not $line.Trim()){continue}
        $parts=$line -split "`t"
        if($parts.Count -lt 2){continue}
        $rows.Add([pscustomobject]@{Status=$parts[0];Path=($parts[1] -replace '\\','/')})
    }
    return $rows.ToArray()
}

function Get-IndexPathList {
    param([string]$Root)
    # snapshot: index -- ENUMERATION IS A JUDGED READ. Get-ChildItem would pick the population
    # from the disk, so a monthly file staged with its worktree copy deleted would be absent
    # from the very list that decides "is any established month missing". This is already the
    # right call; the declaration is what makes that deliberate rather than lucky.
    $r=Invoke-GitText -Root $Root -Arguments @('ls-files','--cached','--',$EventRoot)
    return @(($r.Text -split "`n")|Where-Object{$_}|ForEach-Object{$_ -replace '\\','/'})
}

function Get-HeadPathList {
    param([string]$Root)
    # snapshot: HEAD -- deliberately, and this one is NOT the index. It is the BASELINE half of
    # an append-only rule: "the candidate must extend what is already committed". Reading the
    # index here would compare the staged bytes to themselves and the immutability rule would
    # hold vacuously -- the shape 3 failure, arrived at by fixing the wrong read.
    $r=Invoke-GitText -Root $Root -Arguments @('ls-tree','-r','--name-only','HEAD','--',$EventRoot) -AllowFailure
    if($r.ExitCode -cne 0){return @()}
    return @(($r.Text -split "`n")|Where-Object{$_}|ForEach-Object{$_ -replace '\\','/'})
}

function Get-IndexBytes {
    param([string]$Root,[string]$Path)
    # snapshot: index -- the CANDIDATE. `cat-file blob` below takes the oid this line resolved,
    # so the vintage is chosen here and nowhere else; that is why only this line declares.
    $oid=Invoke-GitText -Root $Root -Arguments @('rev-parse',(':{0}' -f $Path)) -AllowFailure
    if($oid.ExitCode -cne 0 -or -not $oid.Text){throw "index has no blob for '$Path'"}
    $bytes = Invoke-GitRawBytes -Root $Root -Arguments @('cat-file','blob',$oid.Text)
    Write-Output -NoEnumerate $bytes
}

function Get-HeadBytes {
    param([string]$Root,[string]$Path)
    # snapshot: HEAD -- the BASELINE, the pair of the line above. Every use of it is a
    # comparison ("is the candidate a raw-byte prefix extension of this", "is this established
    # schema unchanged"), never a verdict on its own. The two vintages are DIFFERENT ON PURPOSE
    # here, which is the one case where a mixed pair is correct and therefore the one case that
    # most needs saying out loud.
    $oid=Invoke-GitText -Root $Root -Arguments @('rev-parse',('HEAD:{0}' -f $Path)) -AllowFailure
    if($oid.ExitCode -cne 0 -or -not $oid.Text){return $null}
    $bytes = Invoke-GitRawBytes -Root $Root -Arguments @('cat-file','blob',$oid.Text)
    Write-Output -NoEnumerate $bytes
}

function Test-RawPrefix {
    param([byte[]]$Prefix,[byte[]]$Candidate)
    if($null -ceq $Prefix -or $null -ceq $Candidate -or $Candidate.Length -lt $Prefix.Length){return $false}
    if($Prefix.Length -ceq 0){return $true}
    for($i=0;$i -lt $Prefix.Length;$i++){if($Prefix[$i] -cne $Candidate[$i]){return $false}}
    return $true
}

function Get-EventMonth {
    param([string]$Path)
    if($Path -cmatch '/events-([0-9]{4}-[0-9]{2})\.jsonl$'){return $Matches[1]}
    return $null
}

function Test-RecoveryReplacement {
    param(
        [string]$TargetPath,
        [string]$LatestCandidatePath,
        [hashtable]$HeadEventMap,
        [hashtable]$CandidateEventMap,
        $HeadValidation,
        $CandidateValidation,
        $EventSchema,
        [string]$Root
    )
    if($HeadValidation.IsValid){return [pscustomobject]@{Allowed=$false;Reason='HEAD snapshot is valid, so recovery rewrite is not applicable'}}
    $targetMonth=Get-EventMonth $TargetPath
    $targetCandidateRecords=@($CandidateValidation.Events|Where-Object{$_.Path -ceq $TargetPath})
    $latestCandidateRecords=@($CandidateValidation.Events|Where-Object{$_.Path -ceq $LatestCandidatePath})
    if($latestCandidateRecords.Count -ceq 0){return [pscustomobject]@{Allowed=$false;Reason='current latest month has no recovery event'}}
    $lastRecord=$latestCandidateRecords[$latestCandidateRecords.Count-1]
    $last=$lastRecord.Object
    if($last.event_type -cnotin @('AMENDMENT_ADDED','TOMBSTONE_ADDED') -or $last.reason_code -cne 'physical_recovery'){
        return [pscustomobject]@{Allowed=$false;Reason='last event is not a physical_recovery amendment/tombstone'}
    }
    if($last.recovery_target_month -cne $targetMonth){return [pscustomobject]@{Allowed=$false;Reason='recovery event target month does not match the rewritten month'}}
    if(-not @($last.owner_refs|Where-Object{$_.owner_type -ceq 'recovery_authorization'}).Count){return [pscustomobject]@{Allowed=$false;Reason='recovery event lacks recovery_authorization owner reference'}}
    if(-not @($last.evidence_ids).Count){return [pscustomobject]@{Allowed=$false;Reason='recovery event lacks quarantined-byte evidence'}}
    $headBytes=$HeadEventMap[$TargetPath]
    $headHash=Get-Sha256Hex $headBytes
    $quarantineMatches=@($CandidateValidation.Evidence|Where-Object{
        (@($last.evidence_ids) -ccontains $_.Object.evidence_id) -and
        $_.Object.raw_sha256 -ceq $headHash -and
        [long]$_.Object.byte_length -ceq [long]$headBytes.Length
    })
    if($quarantineMatches.Count -cne 1){return [pscustomobject]@{Allowed=$false;Reason='recovery evidence does not identify the exact corrupt HEAD month bytes'}}

    $headLatestRecords=@()
    if($HeadEventMap.ContainsKey($LatestCandidatePath)){
        $headLatestRead=Read-JsonlRecords -Bytes $HeadEventMap[$LatestCandidatePath] -Path $LatestCandidatePath -Schema $EventSchema -Kind Event -Root $Root -RequireCanonical
        $headLatestRecords=@($headLatestRead.Records)
    }
    $expectedLatestCount=$headLatestRecords.Count+1
    if($TargetPath -ceq $LatestCandidatePath){
        $headTargetRead=Read-JsonlRecords -Bytes $headBytes -Path $TargetPath -Schema $EventSchema -Kind Event -Root $Root -RequireCanonical
        $expectedLatestCount=@($headTargetRead.Records).Count+1
    }
    if($latestCandidateRecords.Count -cne $expectedLatestCount){return [pscustomobject]@{Allowed=$false;Reason='recovery transaction must append exactly one recovery event to the current latest month'}}

    # Preserve each line that was independently parseable and schema-valid in
    # the corrupt HEAD blob, byte-for-byte and in the same order. Invalid bytes
    # themselves are represented by the quarantine evidence reference.
    $headRead=Read-JsonlRecords -Bytes $headBytes -Path $TargetPath -Schema $EventSchema -Kind Event -Root $Root -RequireCanonical
    $cursor=0
    foreach($verified in $headRead.Records){
        $found=$false
        while($cursor -lt $targetCandidateRecords.Count){
            if(Test-ByteArrayEqual $verified.Bytes $targetCandidateRecords[$cursor].Bytes){$found=$true;$cursor++;break}
            $cursor++
        }
        if(-not $found){return [pscustomobject]@{Allowed=$false;Reason="verified HEAD event '$($verified.Object.event_id)' was not preserved byte-for-byte"}}
    }
    return [pscustomobject]@{Allowed=$true;Reason='authorized recovery replacement preserves verified bytes'}
}

Write-Host '[experiment-events] ORDER-105 staged-snapshot check'

try{
    $root=Resolve-RepositoryRoot -RequestedRoot $RepoRoot
    $staged=@(Get-NameStatusRows -Root $root)
    $protected=@($staged|Where-Object{Test-ProtectedEventPath $_.Path})
    if($protected.Count -ceq 0){Write-Host '[experiment-events] no event-log/manifest/schema path staged -- pass (ordinary commit)';exit 0}
    Write-Host ('[experiment-events] protected path(s) staged: '+(($protected|ForEach-Object{$_.Path}) -join ', '))

    foreach($row in $protected){
        if(-not (Test-AllowedEventPath $row.Path)){Write-Host "[experiment-events] BLOCK: unexpected protected path '$($row.Path)'";exit 1}
        if($row.Status -cmatch '^D'){Write-Host "[experiment-events] BLOCK: protected path '$($row.Path)' is deleted or renamed";exit 1}
    }

    $indexPaths=@(Get-IndexPathList -Root $root)
    foreach($required in @($ManifestRel,$EventSchemaRel,$EvidenceSchemaRel)){if(-not ($indexPaths -ccontains $required)){Write-Host "[experiment-events] BLOCK: required tracked path '$required' is absent from index";exit 1}}
    $eventPaths=@($indexPaths|Where-Object{$_ -cmatch ('^'+[regex]::Escape($EventRoot)+'/events-[0-9]{4}-(0[1-9]|1[0-2])\.jsonl$')}|Sort-Object)

    try{
        $eventSchema=ConvertFrom-StrictJsonBytes -Bytes (Get-IndexBytes -Root $root -Path $EventSchemaRel) -Context 'staged event-v1.schema.json'
        $evidenceSchema=ConvertFrom-StrictJsonBytes -Bytes (Get-IndexBytes -Root $root -Path $EvidenceSchemaRel) -Context 'staged evidence-v1.schema.json'
        if($null -ceq $eventSchema.'x-ea-lab-rules' -or $null -ceq $evidenceSchema.'x-ea-lab-rules'){throw 'staged schema lacks x-ea-lab-rules'}
    }catch{Write-Host "[experiment-events] INTEGRITY: staged schema cannot be loaded: $($_.Exception.Message)";exit 2}

    $candidateEvents=@{}
    foreach($path in $eventPaths){$candidateEvents[$path]=Get-IndexBytes -Root $root -Path $path}
    $candidateManifest=Get-IndexBytes -Root $root -Path $ManifestRel
    $candidateValidation=Invoke-ValidateEventSnapshot -EventFiles $candidateEvents -ManifestBytes $candidateManifest -EventSchema $eventSchema -EvidenceSchema $evidenceSchema -Root $root -ResolveReferences
    if(-not $candidateValidation.IsValid){
        Write-Host '[experiment-events] BLOCK: staged candidate is invalid:'
        foreach($e in $candidateValidation.Errors){Write-Host ("  $($e.Path):$($e.Line) [$($e.Code)] $($e.Detail)")}
        exit 1
    }

    $headPaths=@(Get-HeadPathList -Root $root)
    foreach($schemaPath in @($EventSchemaRel,$EvidenceSchemaRel)){
        if($headPaths -ccontains $schemaPath){
            $headBytes=Get-HeadBytes -Root $root -Path $schemaPath;$candidateBytes=Get-IndexBytes -Root $root -Path $schemaPath
            if(-not (Test-ByteArrayEqual $headBytes $candidateBytes)){Write-Host "[experiment-events] BLOCK: established v1 schema '$schemaPath' is immutable; add a new schema version instead";exit 1}
        }
    }

    if($headPaths -ccontains $ManifestRel){
        $headManifest=Get-HeadBytes -Root $root -Path $ManifestRel
        if(-not (Test-RawPrefix -Prefix $headManifest -Candidate $candidateManifest)){Write-Host '[experiment-events] BLOCK: evidence manifest is not a raw-byte prefix extension of HEAD';exit 1}
    }

    $headEventPaths=@($headPaths|Where-Object{$_ -cmatch ('^'+[regex]::Escape($EventRoot)+'/events-[0-9]{4}-(0[1-9]|1[0-2])\.jsonl$')}|Sort-Object)
    foreach($headPath in $headEventPaths){if(-not ($eventPaths -ccontains $headPath)){Write-Host "[experiment-events] BLOCK: established monthly file '$headPath' is deleted or renamed";exit 1}}
    $latestCandidateMonth=if($eventPaths.Count){@($eventPaths|ForEach-Object{Get-EventMonth $_}|Sort-Object -Descending)[0]}else{$null}
    $latestHeadMonth=if($headEventPaths.Count){@($headEventPaths|ForEach-Object{Get-EventMonth $_}|Sort-Object -Descending)[0]}else{$null}
    $latestCandidatePath=if($latestCandidateMonth){"$EventRoot/events-$latestCandidateMonth.jsonl"}else{$null}
    $newEventPaths=New-Object System.Collections.Generic.List[string]
    $prefixChangedPaths=New-Object System.Collections.Generic.List[string]
    $nonPrefixChangedPaths=New-Object System.Collections.Generic.List[string]
    foreach($path in $eventPaths){
        $month=Get-EventMonth $path
        if(-not ($headEventPaths -ccontains $path)){
            if($latestHeadMonth -and $month -lt $latestHeadMonth){Write-Host "[experiment-events] BLOCK: new monthly file '$path' backdates before latest HEAD month '$latestHeadMonth'";exit 1}
            $newEventPaths.Add($path)
            continue
        }
        $headBytes=Get-HeadBytes -Root $root -Path $path;$candidateBytes=$candidateEvents[$path]
        if(Test-ByteArrayEqual $headBytes $candidateBytes){continue}
        if(Test-RawPrefix -Prefix $headBytes -Candidate $candidateBytes){$prefixChangedPaths.Add($path);continue}
        $nonPrefixChangedPaths.Add($path)
    }

    if($nonPrefixChangedPaths.Count -ceq 0){
        foreach($path in $prefixChangedPaths){if((Get-EventMonth $path) -cne $latestCandidateMonth){Write-Host "[experiment-events] BLOCK: closed month '$path' is immutable";exit 1}}
    } else {
        if($nonPrefixChangedPaths.Count -cne 1){Write-Host '[experiment-events] BLOCK: recovery transaction rewrites more than one monthly file';exit 1}
        $targetPath=$nonPrefixChangedPaths[0]
        $otherChanged=@($prefixChangedPaths)+@($newEventPaths)
        if((Get-EventMonth $targetPath) -cne $latestCandidateMonth){
            if($otherChanged.Count -cne 1 -or $otherChanged[0] -cne $latestCandidatePath){Write-Host '[experiment-events] BLOCK: closed-month recovery must append exactly one recovery event to the current latest month';exit 1}
        } elseif($otherChanged.Count -cne 0){
            Write-Host '[experiment-events] BLOCK: latest-month recovery touches an additional monthly file';exit 1
        }
        $headEventMap=@{}
        foreach($hp in $headEventPaths){$headEventMap[$hp]=Get-HeadBytes -Root $root -Path $hp}
        $headManifestBytes=if($headPaths -ccontains $ManifestRel){Get-HeadBytes -Root $root -Path $ManifestRel}else{New-Object byte[] 0}
        $headValidation=Invoke-ValidateEventSnapshot -EventFiles $headEventMap -ManifestBytes $headManifestBytes -EventSchema $eventSchema -EvidenceSchema $evidenceSchema -Root $root -ResolveReferences
        $recovery=Test-RecoveryReplacement -TargetPath $targetPath -LatestCandidatePath $latestCandidatePath -HeadEventMap $headEventMap -CandidateEventMap $candidateEvents -HeadValidation $headValidation -CandidateValidation $candidateValidation -EventSchema $eventSchema -Root $root
        if(-not $recovery.Allowed){Write-Host "[experiment-events] BLOCK: monthly file '$targetPath' is not a prefix extension and recovery recognition failed: $($recovery.Reason)";exit 1}
        Write-Host "[experiment-events] recognized authorized recovery transaction for '$targetPath'"
    }

    Write-Host '[experiment-events] PASS -- staged event snapshot is valid and append-consistent'
    exit 0
}catch{
    Write-Host "[experiment-events] INTEGRITY: checker failed closed: $($_.Exception.Message)"
    exit 2
}
