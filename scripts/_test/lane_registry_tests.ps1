$ErrorActionPreference='Stop'
$scriptPath=Join-Path (Split-Path -Parent $PSScriptRoot) 'lane_registry.ps1'
$tempRoot=Join-Path $env:TEMP ('ea-lab-lane-registry-' + [guid]::NewGuid().ToString('N'))
$pass=0; $fail=0
function Pass([string]$Name){ $script:pass++; Write-Host "PASS $Name" }
function Fail([string]$Name,[string]$Why){ $script:fail++; Write-Host "FAIL $Name :: $Why" }
function Assert-True([string]$Name,[bool]$Condition,[string]$Why){ if($Condition){Pass $Name}else{Fail $Name $Why} }
function Invoke-Tool {
    param([string[]]$Arguments)
    $oldPreference=$ErrorActionPreference
    $ErrorActionPreference='Continue'
    $out=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
    $rc=$LASTEXITCODE
    $ErrorActionPreference=$oldPreference
    return [pscustomobject]@{ExitCode=$rc;Text=(($out|Out-String).Trim())}
}
function New-ClaimArgs {
    param([string]$Root,[string]$Id,[string]$Owner,[string]$Wt,[string]$Branch,[string]$Head,[string]$Path,[string]$State='RUNNING',[string]$Runtime='',[switch]$ReadOnly)
    $a=@('-Command','Claim','-RegistryRoot',$Root,'-LaneId',$Id,'-OwnerChat',$Owner,'-Worker','test-worker','-Objective','test-objective','-State',$State,'-BaseSha',$Head,'-HeadSha',$Head,'-Worktree',$Wt,'-Branch',$Branch,'-AllowedPaths',$Path,'-CriticalPaths',$Path,'-DirectConsumer','test-consumer','-Json')
    if($Runtime){$a+=@('-RuntimeLane',$Runtime)}
    if($ReadOnly){$a+='-ReadOnly'}
    return $a
}
function New-Reg([string]$Name){$p=Join-Path $tempRoot $Name;New-Item -ItemType Directory -Force -Path $p|Out-Null;return $p}
try {
    New-Item -ItemType Directory -Force -Path $tempRoot|Out-Null
    $repo=Join-Path $tempRoot 'repo'; New-Item -ItemType Directory -Force -Path $repo|Out-Null
    & git -C $repo init --quiet
    & git -C $repo config user.email 'lane-tests@example.invalid'
    & git -C $repo config user.name 'Lane Tests'
    [IO.File]::WriteAllText((Join-Path $repo 'seed.txt'),'seed')
    & git -C $repo add seed.txt; & git -C $repo commit -m seed --quiet
    $head=(& git -C $repo rev-parse HEAD).Trim(); $branchA=(& git -C $repo rev-parse --abbrev-ref HEAD).Trim()
    & git -C $repo branch lane-b; & git -C $repo branch lane-c
    $wtB=Join-Path $tempRoot 'wt-b'; $wtC=Join-Path $tempRoot 'wt-c'
    & git -C $repo worktree add --quiet $wtB lane-b
    & git -C $repo worktree add --quiet $wtC lane-c

    $r1=New-Reg 'r1'; $x=Invoke-Tool (New-ClaimArgs $r1 'lane-a' 'chat-a' $repo $branchA $head 'scripts/lane_registry.ps1')
    Assert-True 'basic claim succeeds' ($x.ExitCode -eq 0) $x.Text
    $obj=Get-Content -Raw (Join-Path $r1 'lane-a.json')|ConvertFrom-Json
    Assert-True 'basic claim persists exact fields' ($obj.state -ceq 'RUNNING' -and $obj.head_sha -ceq $head -and $obj.writer -eq $true) ($obj|ConvertTo-Json -Compress)

    $r2=New-Reg 'r2'; [void](Invoke-Tool (New-ClaimArgs $r2 'w1' 'chat-1' $repo $branchA $head 'ea_template'))
    $x=Invoke-Tool (New-ClaimArgs $r2 'w2' 'chat-2' $wtB 'lane-b' $head 'ea_template/core')
    Assert-True 'critical prefix overlap refuses second writer' ($x.ExitCode -ne 0 -and $x.Text -match 'critical_path_overlap') $x.Text

    $r3=New-Reg 'r3'; [void](Invoke-Tool (New-ClaimArgs $r3 'w1' 'same-chat' $repo $branchA $head 'alpha'))
    $x=Invoke-Tool (New-ClaimArgs $r3 'w2' 'same-chat' $wtB 'lane-b' $head 'beta')
    Assert-True 'same chat cannot own two active writers' ($x.ExitCode -ne 0 -and $x.Text -match 'owner_chat_active_writer') $x.Text

    $r4=New-Reg 'r4'; [void](Invoke-Tool (New-ClaimArgs $r4 'w1' 'chat-1' $repo $branchA $head 'alpha' 'RUNNING' 'MT5-DEMO-A'))
    $x=Invoke-Tool (New-ClaimArgs $r4 'w2' 'chat-2' $wtB 'lane-b' $head 'beta' 'RUNNING' 'MT5-DEMO-A')
    Assert-True 'runtime lane overlap refuses second writer' ($x.ExitCode -ne 0 -and $x.Text -match 'runtime_lane_overlap') $x.Text

    $r5=New-Reg 'r5'; [void](Invoke-Tool (New-ClaimArgs $r5 'w1' 'chat-1' $repo $branchA $head 'same/path'))
    $x=Invoke-Tool (New-ClaimArgs $r5 'reader' 'chat-2' $wtB 'lane-b' $head 'same/path' 'RUNNING' '' -ReadOnly)
    Assert-True 'read-only overlap is allowed' ($x.ExitCode -eq 0) $x.Text

    $r6=New-Reg 'r6'; [IO.File]::WriteAllText((Join-Path $r6 'broken.json'),'{broken')
    $x=Invoke-Tool (New-ClaimArgs $r6 'w1' 'chat-1' $repo $branchA $head 'alpha')
    Assert-True 'malformed registry fails closed' ($x.ExitCode -ne 0 -and $x.Text -match 'registry_malformed') $x.Text

    $r7=New-Reg 'r7'; $x=Invoke-Tool (New-ClaimArgs $r7 'w1' 'chat-1' $repo $branchA $head 'ea_template/*')
    Assert-True 'wildcard critical path is refused' ($x.ExitCode -ne 0 -and $x.Text -match 'ambiguous_path') $x.Text

    $r8=New-Reg 'r8'; [void](Invoke-Tool (New-ClaimArgs $r8 'paused' 'chat-1' $repo $branchA $head 'shared' 'PAUSED'))
    $x=Invoke-Tool (New-ClaimArgs $r8 'running' 'chat-2' $wtB 'lane-b' $head 'shared')
    Assert-True 'paused writer does not block another writer' ($x.ExitCode -eq 0) $x.Text

    $r8s=New-Reg 'r8-supersede'; [void](Invoke-Tool (New-ClaimArgs $r8s 'old' 'chat-s' $repo $branchA $head 'old/path' 'PAUSED'))
    $supArgs=New-ClaimArgs $r8s 'new' 'chat-s' $wtB 'lane-b' $head 'new/path'; $supArgs+=@('-SupersedeOwnLaneId','old')
    $x=Invoke-Tool $supArgs; $oldRec=Get-Content -Raw (Join-Path $r8s 'old.json')|ConvertFrom-Json
    Assert-True 'claim can close one explicit nonactive own lane' ($x.ExitCode -eq 0 -and $oldRec.state -eq 'DONE' -and $oldRec.superseded_by -eq 'new') ($x.Text+' / '+($oldRec|ConvertTo-Json -Compress))

    $r8a=New-Reg 'r8-active'; [void](Invoke-Tool (New-ClaimArgs $r8a 'old' 'chat-s' $repo $branchA $head 'old/path'))
    $supArgs=New-ClaimArgs $r8a 'new' 'chat-s' $wtB 'lane-b' $head 'new/path'; $supArgs+=@('-SupersedeOwnLaneId','old')
    $x=Invoke-Tool $supArgs
    Assert-True 'claim refuses to supersede an active own lane' ($x.ExitCode -ne 0 -and $x.Text -match 'supersede_active') $x.Text

    $r8f=New-Reg 'r8-foreign'; [void](Invoke-Tool (New-ClaimArgs $r8f 'old' 'chat-a' $repo $branchA $head 'old/path' 'PAUSED'))
    $supArgs=New-ClaimArgs $r8f 'new' 'chat-b' $wtB 'lane-b' $head 'new/path'; $supArgs+=@('-SupersedeOwnLaneId','old')
    $x=Invoke-Tool $supArgs
    Assert-True 'claim cannot supersede a foreign owner lane' ($x.ExitCode -ne 0 -and $x.Text -match 'supersede_foreign') $x.Text

    $r8r=New-Reg 'r8-ready'; [void](Invoke-Tool (New-ClaimArgs $r8r 'old' 'chat-s' $repo $branchA $head 'old/path' 'READY'))
    $supArgs=New-ClaimArgs $r8r 'new' 'chat-s' $wtB 'lane-b' $head 'new/path'; $supArgs+=@('-SupersedeOwnLaneId','old')
    $x=Invoke-Tool $supArgs
    Assert-True 'claim refuses supersede when READY to DONE is not a legal transition' ($x.ExitCode -ne 0 -and $x.Text -match 'supersede_illegal_transition') $x.Text

    $r9=New-Reg 'r9'; [void](Invoke-Tool (New-ClaimArgs $r9 'lane' 'chat-1' $repo $branchA $head 'alpha'))
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$r9,'-LaneId','lane','-ExpectedState','PAUSED','-NewState','FROZEN','-Json')
    Assert-True 'stale expected state is refused' ($x.ExitCode -ne 0 -and $x.Text -match 'stale_state') $x.Text

    $r10=New-Reg 'r10'; [void](Invoke-Tool (New-ClaimArgs $r10 'lane' 'chat-1' $repo $branchA $head 'alpha'))
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$r10,'-LaneId','lane','-ExpectedState','RUNNING','-NewState','FROZEN','-Json')
    Assert-True 'running can freeze on clean exact head' ($x.ExitCode -eq 0) $x.Text
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$r10,'-LaneId','lane','-ExpectedState','FROZEN','-NewState','REVIEW','-Reviewer','claude','-Json')
    Assert-True 'frozen lane can enter review with reviewer' ($x.ExitCode -eq 0) $x.Text
    $wrong='0000000000000000000000000000000000000000'
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$r10,'-LaneId','lane','-ExpectedState','REVIEW','-NewState','FROZEN','-Reviewer','claude','-ReviewedHead',$wrong,'-Json')
    Assert-True 'wrong reviewed head is refused' ($x.ExitCode -ne 0 -and $x.Text -match 'review_head_mismatch') $x.Text
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$r10,'-LaneId','lane','-ExpectedState','REVIEW','-NewState','FROZEN','-Reviewer','claude','-ReviewedHead',$head,'-Json')
    Assert-True 'exact reviewed head closes review' ($x.ExitCode -eq 0) $x.Text
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$r10,'-LaneId','lane','-ExpectedState','FROZEN','-NewState','INTEGRATING','-Json')
    Assert-True 'integration requires and accepts exact reviewed head' ($x.ExitCode -eq 0) $x.Text

    $r11=New-Reg 'r11'; [void](Invoke-Tool (New-ClaimArgs $r11 'lane' 'chat-1' $repo $branchA $head 'alpha'))
    [void](Invoke-Tool @('-Command','Transition','-RegistryRoot',$r11,'-LaneId','lane','-ExpectedState','RUNNING','-NewState','FROZEN','-Json'))
    [void](Invoke-Tool @('-Command','Transition','-RegistryRoot',$r11,'-LaneId','lane','-ExpectedState','FROZEN','-NewState','REVIEW','-Reviewer','claude','-Json'))
    [void](Invoke-Tool @('-Command','Transition','-RegistryRoot',$r11,'-LaneId','lane','-ExpectedState','REVIEW','-NewState','FROZEN','-Reviewer','claude','-ReviewedHead',$head,'-Json'))
    [IO.File]::WriteAllText((Join-Path $repo 'move.txt'),'move'); & git -C $repo add move.txt; & git -C $repo commit -m move --quiet
    $moved=(& git -C $repo rev-parse HEAD).Trim()
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$r11,'-LaneId','lane','-ExpectedState','FROZEN','-NewState','RUNNING','-HeadSha',$moved,'-Json')
    Assert-True 'moving frozen head requires return to running' ($x.ExitCode -eq 0) $x.Text
    $rec=Get-Content -Raw (Join-Path $r11 'lane.json')|ConvertFrom-Json
    Assert-True 'return to running invalidates old review' ($null -eq $rec.reviewed_head -and $null -eq $rec.reviewer) ($rec|ConvertTo-Json -Compress)
    [void](Invoke-Tool @('-Command','Transition','-RegistryRoot',$r11,'-LaneId','lane','-ExpectedState','RUNNING','-NewState','FROZEN','-Json'))
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$r11,'-LaneId','lane','-ExpectedState','FROZEN','-NewState','INTEGRATING','-Json')
    Assert-True 'moved head cannot integrate on stale review' ($x.ExitCode -ne 0 -and $x.Text -match 'review_not_valid') $x.Text

    $r12=New-Reg 'r12'; $args1=New-ClaimArgs $r12 'race-a' 'chat-a' $wtB 'lane-b' $head 'race/path'; $args2=New-ClaimArgs $r12 'race-b' 'chat-b' $wtC 'lane-c' $head 'race/path'
    $argLine1=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath)+$args1
    $argLine2=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath)+$args2
    $p1=Start-Process powershell.exe -ArgumentList $argLine1 -PassThru -WindowStyle Hidden
    $p2=Start-Process powershell.exe -ArgumentList $argLine2 -PassThru -WindowStyle Hidden
    $p1.WaitForExit(); $p2.WaitForExit(); $codes=@($p1.ExitCode,$p2.ExitCode)
    Assert-True 'concurrent overlapping claims have exactly one winner' ((@($codes|Where-Object{$_ -eq 0}).Count -eq 1) -and (@($codes|Where-Object{$_ -ne 0}).Count -eq 1)) ($codes -join ',')

    $r13=New-Reg 'r13'; [void](Invoke-Tool (New-ClaimArgs $r13 'w1' 'chat-a' $wtB 'lane-b' $head 'alpha'))
    $x=Invoke-Tool @('-Command','Check','-RegistryRoot',$r13,'-LaneId','probe','-OwnerChat','chat-b','-Worker','test-worker','-Objective','probe','-State','RUNNING','-BaseSha',$head,'-HeadSha',$head,'-Worktree',$wtC,'-Branch','lane-c','-AllowedPaths','alpha/sub','-CriticalPaths','alpha/sub','-DirectConsumer','test-consumer','-Json')
    Assert-True 'check reports conflict without creating a lane' ($x.ExitCode -eq 2 -and $x.Text -match 'WAITING_CONFLICT' -and -not (Test-Path (Join-Path $r13 'probe.json'))) $x.Text
    $x=Invoke-Tool @('-Command','Validate','-RegistryRoot',$r13,'-Json')
    Assert-True 'validate accepts a well-formed registry' ($x.ExitCode -eq 0 -and $x.Text -match '"result":"VALID"') $x.Text
    $x=Invoke-Tool (New-ClaimArgs $r13 'w1' 'chat-z' $wtC 'lane-c' $head 'zeta')
    Assert-True 'duplicate lane id is refused' ($x.ExitCode -ne 0 -and $x.Text -match 'lane_exists') $x.Text

    $r14=New-Reg 'r14'
    [void](Invoke-Tool (New-ClaimArgs $r14 'audit-active' 'audit-a' $wtB 'lane-b' $head 'audit/a' 'RUNNING' '' -ReadOnly))
    [void](Invoke-Tool (New-ClaimArgs $r14 'audit-wait' 'audit-b' $wtC 'lane-c' $head 'audit/b' 'WAITING' '' -ReadOnly))
    [void](Invoke-Tool (New-ClaimArgs $r14 'audit-done' 'audit-c' $wtB 'lane-b' $head 'audit/c' 'RUNNING' '' -ReadOnly))
    [void](Invoke-Tool (New-ClaimArgs $r14 'audit-aged' 'audit-d' $wtC 'lane-c' $head 'audit/d' 'RUNNING' '' -ReadOnly))
    [void](Invoke-Tool (New-ClaimArgs $r14 'audit-mismatch' 'audit-e' $wtB 'lane-b' $head 'audit/e' 'RUNNING' '' -ReadOnly))
    [void](Invoke-Tool (New-ClaimArgs $r14 'audit-missing' 'audit-f' $wtC 'lane-c' $head 'audit/f' 'RUNNING' '' -ReadOnly))
    [void](Invoke-Tool (New-ClaimArgs $r14 'audit-queued' 'audit-g' $wtB 'lane-b' $head 'audit/g' 'WAITING' '' -ReadOnly))
    [void](Invoke-Tool @('-Command','Transition','-RegistryRoot',$r14,'-LaneId','audit-done','-ExpectedState','RUNNING','-NewState','DONE','-Json'))
    $waitPath=Join-Path $r14 'audit-wait.json'; $waitRec=Get-Content -Raw $waitPath|ConvertFrom-Json
    $waitRec.updated_at=[DateTimeOffset]::UtcNow.AddHours(-48).ToString('o')
    [IO.File]::WriteAllText($waitPath,(($waitRec|ConvertTo-Json -Depth 10)+"`n"),(New-Object Text.UTF8Encoding($false)))
    $agedPath=Join-Path $r14 'audit-aged.json'; $agedRec=Get-Content -Raw $agedPath|ConvertFrom-Json; $agedRec.updated_at=[DateTimeOffset]::UtcNow.AddHours(-48).ToString('o'); [IO.File]::WriteAllText($agedPath,(($agedRec|ConvertTo-Json -Depth 10)+"`n"),(New-Object Text.UTF8Encoding($false)))
    $mismatchPath=Join-Path $r14 'audit-mismatch.json'; $mismatchRec=Get-Content -Raw $mismatchPath|ConvertFrom-Json; $mismatchRec.branch='definitely-not-lane-b'; [IO.File]::WriteAllText($mismatchPath,(($mismatchRec|ConvertTo-Json -Depth 10)+"`n"),(New-Object Text.UTF8Encoding($false)))
    $missingPath=Join-Path $r14 'audit-missing.json'; $missingRec=Get-Content -Raw $missingPath|ConvertFrom-Json; $missingRec.worktree=Join-Path $tempRoot 'does-not-exist'; [IO.File]::WriteAllText($missingPath,(($missingRec|ConvertTo-Json -Depth 10)+"`n"),(New-Object Text.UTF8Encoding($false)))
    $before=@{}; Get-ChildItem $r14 -Filter '*.json' | ForEach-Object {$before[$_.Name]=(Get-FileHash -Algorithm SHA256 $_.FullName).Hash}
    $x=Invoke-Tool @('-Command','Audit','-RegistryRoot',$r14,'-RepoRoot',$repo,'-StaleAfterHours','24','-Json')
    $audit=$x.Text|ConvertFrom-Json
    $a=@($audit.records|Where-Object lane_id -eq 'audit-active')[0]; $w=@($audit.records|Where-Object lane_id -eq 'audit-wait')[0]; $d=@($audit.records|Where-Object lane_id -eq 'audit-done')[0]
    $aged=@($audit.records|Where-Object lane_id -eq 'audit-aged')[0]; $mm=@($audit.records|Where-Object lane_id -eq 'audit-mismatch')[0]; $miss=@($audit.records|Where-Object lane_id -eq 'audit-missing')[0]; $q=@($audit.records|Where-Object lane_id -eq 'audit-queued')[0]
    Assert-True 'audit classifies live exact lane as ACTIVE_CURRENT' ($x.ExitCode -eq 0 -and $a.classification -eq 'ACTIVE_CURRENT' -and $a.head_matches_record -eq $true) $x.Text
    Assert-True 'audit carries exact structured record metadata' ($a.worker -ceq 'test-worker' -and $a.branch -ceq 'lane-b' -and $a.worktree -ceq $wtB -and $a.reviewer -ceq '' -and $a.reviewed_head -ceq '') ($a|ConvertTo-Json -Compress)
    Assert-True 'audit classifies aged nonactive lane as STALE_NONACTIVE' ($w.classification -eq 'STALE_NONACTIVE' -and $w.attention_required -eq $true) ($w|ConvertTo-Json -Compress)
    Assert-True 'audit classifies done lane as CLOSED' ($d.classification -eq 'CLOSED' -and $d.attention_required -eq $false) ($d|ConvertTo-Json -Compress)
    Assert-True 'audit classifies aged active lane as ACTIVE_AGED' ($aged.classification -eq 'ACTIVE_AGED' -and $aged.attention_required -eq $true) ($aged|ConvertTo-Json -Compress)
    Assert-True 'audit classifies branch mismatch as ACTIVE_IDENTITY_MISMATCH' ($mm.classification -eq 'ACTIVE_IDENTITY_MISMATCH' -and $mm.attention_required -eq $true) ($mm|ConvertTo-Json -Compress)
    Assert-True 'audit classifies missing worktree as ACTIVE_MISSING_WORKTREE' ($miss.classification -eq 'ACTIVE_MISSING_WORKTREE' -and $miss.attention_required -eq $true) ($miss|ConvertTo-Json -Compress)
    Assert-True 'audit keeps recent waiting lane QUEUED_CURRENT' ($q.classification -eq 'QUEUED_CURRENT' -and $q.attention_required -eq $false) ($q|ConvertTo-Json -Compress)
    $after=@{}; Get-ChildItem $r14 -Filter '*.json' | ForEach-Object {$after[$_.Name]=(Get-FileHash -Algorithm SHA256 $_.FullName).Hash}
    Assert-True 'audit is read-only over registry bytes' (-not @($before.Keys|Where-Object {$before[$_] -ne $after[$_]}).Count) (($before|ConvertTo-Json -Compress)+' / '+($after|ConvertTo-Json -Compress))

    $scriptText=[IO.File]::ReadAllText($scriptPath)
    Assert-True 'default registry root isolates legacy dashboard JSON' ($scriptText -match [regex]::Escape("D:\EA_LAB_CONTROL\lanes\registry-v1")) 'default registry root is not registry-v1'
    $legacyParent=Join-Path $tempRoot 'legacy-parent'; New-Item -ItemType Directory -Force -Path $legacyParent|Out-Null
    [IO.File]::WriteAllText((Join-Path $legacyParent 'control.json'),'{"lane":"control","status":"DONE"}',(New-Object Text.UTF8Encoding($false)))
    $isolatedRoot=Join-Path $legacyParent 'registry-v1'
    $x=Invoke-Tool (New-ClaimArgs $isolatedRoot 'isolated' 'chat-i' $wtB 'lane-b' $head 'isolated/path')
    $v=Invoke-Tool @('-Command','Validate','-RegistryRoot',$isolatedRoot,'-Json')
    Assert-True 'legacy parent JSON does not poison registry-v1' ($x.ExitCode -eq 0 -and $v.ExitCode -eq 0 -and $v.Text -match '"result":"VALID"') (($x.Text+' | '+$v.Text))
    $oldPass=$pass
    Write-Host "OLD_REGISTRY_SUITE PASS=$oldPass FAIL=$fail"
    # Splat from CLIXML in a child process: -File string[] binding cannot faithfully
    # express empty elements / multiple paths. Exercise the actual public script.
    $driver=Join-Path $tempRoot 'amend-driver.ps1'
    [IO.File]::WriteAllText($driver,'param($Tool,$InputFile) $ErrorActionPreference="Stop"; $p=Import-Clixml -LiteralPath $InputFile; & $Tool @p')
    $authority=Join-Path $tempRoot 'authority.txt'; [IO.File]::WriteAllText($authority,'fixture-approved mechanical additive amendment')
    $authorityHash=(Get-FileHash $authority -Algorithm SHA256).Hash
    $amendRoot=New-Reg 'amend'
    $seed=Invoke-Tool (New-ClaimArgs $amendRoot 'amend-lane' 'amend-owner' $wtB 'lane-b' $head 'old/scope' 'BLOCKED')
    if($seed.ExitCode){ throw $seed.Text }
    $laneFile=Join-Path $amendRoot 'amend-lane.json'
    $template=Get-Content -Raw $laneFile | ConvertFrom-Json
    $template | Add-Member repair_budget ([pscustomobject]@{used=0;limit=1})
    $template | Add-Member future_extension ([pscustomobject]@{keep=@('x','y');nested=@{value=17}})
    $baseline=$template | ConvertTo-Json -Depth 100
    function Reset-Amend {
        param([string]$State='BLOCKED')
        Get-ChildItem -LiteralPath $amendRoot -Filter '*.json' | ForEach-Object { Remove-Item -LiteralPath $_.FullName }
        $obj=$baseline|ConvertFrom-Json; $obj.state=$State
        [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100))
    }
    function Amend-Params {
        return @{Command='AmendScope';RegistryRoot=$amendRoot;RepoRoot=$repo;LaneId='amend-lane';ExpectedState='BLOCKED';ExpectedHead=$head;AddPaths=@('new/path.ps1');AuthorityRef=$authority;AuthoritySha256=$authorityHash;Json=$true}
    }
    function Invoke-Amend($Parameters) {
        $inputFile=Join-Path $tempRoot 'amend-args.xml'; $Parameters | Export-Clixml -LiteralPath $inputFile
        $saved=$ErrorActionPreference; $ErrorActionPreference='Continue'
        try { $out=& powershell.exe -NoProfile -File $driver $scriptPath $inputFile 2>&1; $code=$LASTEXITCODE }
        finally { $ErrorActionPreference=$saved }
        return [pscustomobject]@{ExitCode=$code;Text=($out|Out-String).Trim()}
    }
    function Registry-Fingerprint {
        return ((Get-ChildItem -LiteralPath $amendRoot -Filter '*.json' | Sort-Object Name | ForEach-Object { $_.Name+':'+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join '|')
    }
    function Refuse-Amend([string]$Name,$Parameters,[string]$ErrorCode) {
        $beforeBytes=Registry-Fingerprint
        $result=Invoke-Amend $Parameters
        Assert-True $Name ($result.ExitCode -ne 0 -and $result.Text -match $ErrorCode -and (Registry-Fingerprint) -ceq $beforeBytes) $result.Text
    }
    # Dirty tracked and untracked files are deliberately preserved, as is index content.
    [IO.File]::WriteAllText((Join-Path $wtB 'seed.txt'),'dirty tracked fixture')
    [IO.File]::WriteAllText((Join-Path $wtB 'untracked.txt'),'untracked fixture')
    $indexPath=(& git -C $wtB rev-parse --path-format=absolute --git-path index).Trim()
    $indexBefore=(Get-FileHash $indexPath).Hash
    foreach($state in @('BLOCKED','WAITING','PAUSED','READY')){
        Reset-Amend $state; $p=Amend-Params; $p.ExpectedState=$state
        $x=Invoke-Amend $p
        Assert-True "AmendScope succeeds dirty $state" ($x.ExitCode -eq 0 -and $x.Text -match 'AMENDED') $x.Text
    }
    $amended=Get-Content -Raw $laneFile | ConvertFrom-Json
    $rct=$amended.scope_amendments[0]
    Assert-True 'scope additive and old entries preserved' (($amended.allowed_paths -join ',') -ceq 'old/scope,new/path.ps1' -and ($amended.critical_paths -join ',') -ceq 'old/scope,new/path.ps1') ($amended|ConvertTo-Json -Depth 20)
    $nonScopeOk=$true
    foreach($prop in $template.PSObject.Properties){
        if($prop.Name -in @('allowed_paths','critical_paths','state')){continue}
        if((ConvertTo-Json -InputObject $prop.Value -Depth 100 -Compress) -cne (ConvertTo-Json -InputObject $amended.($prop.Name) -Depth 100 -Compress)){ $nonScopeOk=$false }
    }
    Assert-True 'every non-scope field including timestamp budget extensions preserved' $nonScopeOk 'non-scope field changed'
    $receiptOk=$rct.authority_ref -ceq $authority -and $rct.authority_sha256 -ieq $authorityHash -and $rct.lane_identity.lane_id -ceq 'amend-lane' -and $rct.state -ceq 'READY' -and $rct.head_sha -ceq $head -and $rct.requested_paths[0] -ceq 'new/path.ps1' -and $rct.actual_additions.allowed_paths[0] -ceq 'new/path.ps1' -and $rct.actual_additions.critical_paths[0] -ceq 'new/path.ps1' -and $rct.before_scope_sha256 -match '^[a-f0-9]{64}$' -and $rct.after_scope_sha256 -match '^[a-f0-9]{64}$' -and $rct.before_scope_sha256 -cne $rct.after_scope_sha256 -and $rct.preserved_non_scope_sha256 -match '^[a-f0-9]{64}$' -and $rct.timestamp
    Assert-True 'atomic receipt binds authority identity scope and preserved fields' $receiptOk ($rct|ConvertTo-Json -Depth 10)
    function Expected-Digest($Value) {
        $sha=[Security.Cryptography.SHA256]::Create()
        try {return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Value -Depth 100 -Compress))))).Replace('-','').ToLowerInvariant()} finally {$sha.Dispose()}
    }
    $scopeBefore=[ordered]@{allowed_paths=@('old/scope');critical_paths=@('old/scope')}
    $scopeAfter=[ordered]@{allowed_paths=@('old/scope','new/path.ps1');critical_paths=@('old/scope','new/path.ps1')}
    Assert-True 'receipt scope digests match exact before and after scope' ($rct.before_scope_sha256 -ceq (Expected-Digest $scopeBefore) -and $rct.after_scope_sha256 -ceq (Expected-Digest $scopeAfter)) 'scope digest mismatch'
    $preserved=[ordered]@{}; foreach($prop in $amended.PSObject.Properties){if($prop.Name -notin @('allowed_paths','critical_paths','scope_amendments')){$preserved[$prop.Name]=$prop.Value}}
    Assert-True 'receipt preserved digest matches unchanged fields' ($rct.preserved_non_scope_sha256 -ceq (Expected-Digest $preserved)) 'preserved digest mismatch'
    $fingerprint=Registry-Fingerprint; $mtime=(Get-Item $laneFile).LastWriteTimeUtc.Ticks
    $retry1=Invoke-Amend $p; $retry2=Invoke-Amend $p
    Assert-True 'lost-response duplicate replay deterministic NO_CHANGE no write no receipt' ($retry1.ExitCode -eq 0 -and $retry1.Text -cmatch 'NO_CHANGE' -and $retry1.Text -ceq $retry2.Text -and (Registry-Fingerprint) -ceq $fingerprint -and (Get-Item $laneFile).LastWriteTimeUtc.Ticks -eq $mtime -and @((Get-Content -Raw $laneFile|ConvertFrom-Json).scope_amendments).Count -eq 1) ($retry1.Text+' / '+$retry2.Text)
    $p.Command='amendscope'; $lower=Invoke-Amend $p
    Assert-True 'case-insensitive command binding cannot silently skip amendment' ($lower.ExitCode -eq 0 -and $lower.Text -ceq $retry1.Text) $lower.Text
    foreach($cmd in @('Validate','Get','Audit')){
        $x=Invoke-Tool @('-Command',$cmd,'-RegistryRoot',$amendRoot,'-LaneId','amend-lane','-RepoRoot',$repo,'-Json')
        Assert-True "$cmd works after amendment" ($x.ExitCode -eq 0) $x.Text
    }
    Assert-True 'lane count and ID unchanged' (@(Get-ChildItem $amendRoot -Filter '*.json').Count -eq 1 -and (Get-Content -Raw $laneFile|ConvertFrom-Json).lane_id -ceq 'amend-lane') 'lane identities changed'
    Reset-Amend; $p=Amend-Params; $p.LaneId='missing'; Refuse-Amend 'missing lane refuses' $p 'lane_missing'
    Reset-Amend; $p=Amend-Params; $p.ExpectedState='WAITING'; Refuse-Amend 'stale state refuses' $p 'stale_state'
    $p=Amend-Params; $p.ExpectedHead=('0'*40); Refuse-Amend 'stale HEAD refuses' $p 'stale_head'
    $p=Amend-Params; $p.ExpectedHead=$head.Substring(0,8); Refuse-Amend 'abbreviated HEAD refuses' $p 'bad_sha'
    foreach($state in @('RUNNING','FROZEN','REVIEW','INTEGRATING','DONE')){
        Reset-Amend $state; $p=Amend-Params; $p.ExpectedState=$state; Refuse-Amend "$state refuses amendment" $p 'amend_state'
    }
    Reset-Amend
    foreach($path in @('x/*','x/?','x/[a]','../x','x/../y','x/./y','','x//y','x/','/root','\root','C:\outside','C:relative','\\host\share\x','\\?\C:\device','\\.\device','x:stream','x/NUL.txt','x/COM1','x/trailing.','x/trailing ','x/ leading','x/SHORT~1',("x/a"+[char]1+'b'),'.git/config')){
        $p=Amend-Params; $p.AddPaths=@($path); Refuse-Amend "unsafe path refuses [$path]" $p 'unsafe_path'
    }
    $p=Amend-Params; $p.AddPaths=@(); Refuse-Amend 'empty AddPaths collection refuses' $p 'missing_scope'
    $p=Amend-Params; $p.AddPaths=@(('x/'+[char]0x85+'file')); Refuse-Amend 'Unicode C1 control refuses' $p 'unsafe_path'
    foreach($key in @('AllowedPaths','CriticalPaths','OwnerChat','Worker','Objective','Reviewer','ReviewedHead','NewState','State','HeadSha','BaseSha','Branch','Worktree','ReadOnly','Dependencies','RuntimeLane','DirectConsumer','BlockerClass','SupersedeOwnLaneId','StaleAfterHours','RemovePaths','RepairBudget')){
        $p=Amend-Params; $p[$key]=if($key -eq 'ReadOnly'){$true}elseif($key -eq 'StaleAfterHours'){1}else{'injected'}
        Refuse-Amend "additional parameter $key refuses" $p 'amend_parameter|NamedParameterNotFound'
    }
    $p=Amend-Params; $p.AuthoritySha256=('0'*64); Refuse-Amend 'authority hash mismatch refuses' $p 'authority_hash'
    $p=Amend-Params; $p.AuthorityRef=Join-Path $tempRoot 'absent-authority'; Refuse-Amend 'missing authority refuses' $p 'authority_reference'
    $obj=$baseline|ConvertFrom-Json; $obj.reviewed_head=$head; [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100)); Refuse-Amend 'reviewed_head presence refuses' (Amend-Params) 'review_present'
    Reset-Amend; $obj=$baseline|ConvertFrom-Json; $obj.writer=$false; [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100)); Refuse-Amend 'reader lane refuses' (Amend-Params) 'not_writer'
    Reset-Amend; $obj=$baseline|ConvertFrom-Json; $obj.branch='wrong'; [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100)); Refuse-Amend 'branch identity mismatch refuses' (Amend-Params) 'branch_mismatch'
    Reset-Amend; $obj=$baseline|ConvertFrom-Json; $obj.head_sha=$moved; [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100)); $p=Amend-Params; $p.ExpectedHead=$moved; Refuse-Amend 'actual worktree HEAD mismatch refuses' $p 'stale_head'
    Reset-Amend; $otherRepo=Join-Path $tempRoot 'other-repo'; New-Item -ItemType Directory $otherRepo|Out-Null; & git -C $otherRepo init --quiet
    $p=Amend-Params; $p.RepoRoot=$otherRepo; Refuse-Amend 'foreign repository refuses' $p 'repository_mismatch'
    [IO.File]::WriteAllText((Join-Path $amendRoot 'broken.json'),'{broken'); Refuse-Amend 'malformed registry refuses' (Amend-Params) 'registry_malformed'
    Reset-Amend; Copy-Item $laneFile (Join-Path $amendRoot 'duplicate.json'); Refuse-Amend 'duplicate lane record refuses' (Amend-Params) 'registry_malformed'
    Reset-Amend; $obj=$baseline|ConvertFrom-Json; $deep='leaf'; 1..85|ForEach-Object {$deep=@{child=$deep}}; $obj|Add-Member deep_extension $deep; [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100)); Refuse-Amend 'unsafe serialization depth refuses instead of losing fields' (Amend-Params) 'registry_malformed'
    Reset-Amend; $lockStream=[IO.File]::Open((Join-Path $amendRoot '.lane-registry.lock'),'OpenOrCreate','ReadWrite','None')
    try { $p=Amend-Params; $p.LockTimeoutSeconds=1; Refuse-Amend 'lock timeout leaves bytes intact' $p 'lock_timeout' } finally {$lockStream.Dispose()}
    function Add-Competitor([string]$Path,[string]$Owner='competitor-owner',[string]$Runtime='') {
        $obj=$baseline|ConvertFrom-Json; $obj.lane_id='competitor'; $obj.owner_chat=$Owner; $obj.state='RUNNING'; $obj.critical_paths=@($Path); $obj.allowed_paths=@($Path); $obj.worktree=$wtC; $obj.branch='lane-c'; $obj.runtime_lane=$Runtime
        [IO.File]::WriteAllText((Join-Path $amendRoot 'competitor.json'),($obj|ConvertTo-Json -Depth 100))
    }
    foreach($path in @('new/path.ps1','new','new/path.ps1/child','old/scope','old')){
        Reset-Amend; Add-Competitor $path; Refuse-Amend "complete resulting scope conflict [$path]" (Amend-Params) 'conflict'
    }
    Reset-Amend; Add-Competitor (Join-Path $wtC 'new\path.ps1'); Refuse-Amend 'absolute competitor repo alias conflicts' (Amend-Params) 'conflict'
    Reset-Amend; Add-Competitor (Join-Path $wtB 'new\path.ps1'); Refuse-Amend 'absolute competitor alias into target checkout conflicts' (Amend-Params) 'conflict'
    Reset-Amend; Add-Competitor (Join-Path $repo 'new\path.ps1'); Refuse-Amend 'absolute competitor alias into third checkout conflicts' (Amend-Params) 'conflict'
    Reset-Amend; Add-Competitor '../ambiguous'; Refuse-Amend 'unresolvable active competitor fails closed' (Amend-Params) 'unsafe_path|unsafe_namespace'
    Reset-Amend; Add-Competitor 'separate'; $otherFile=Join-Path $amendRoot 'competitor.json'; $obj=Get-Content -Raw $otherFile|ConvertFrom-Json; $obj.worktree=Join-Path $tempRoot 'missing-worktree'; [IO.File]::WriteAllText($otherFile,($obj|ConvertTo-Json -Depth 100)); Refuse-Amend 'missing active competitor namespace fails closed' (Amend-Params) 'unsafe_namespace'
    Reset-Amend; Add-Competitor 'separate'; $obj=Get-Content -Raw $otherFile|ConvertFrom-Json; $obj.critical_paths=@(); [IO.File]::WriteAllText($otherFile,($obj|ConvertTo-Json -Depth 100)); Refuse-Amend 'empty active competitor scope fails closed' (Amend-Params) 'unsafe_namespace'
    Reset-Amend; Add-Competitor 'separate' 'amend-owner'; Refuse-Amend 'same owner active writer rule preserved' (Amend-Params) 'owner_chat_active_writer'
    Reset-Amend; $obj=$baseline|ConvertFrom-Json; $obj.runtime_lane='runtime-A'; [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100)); Add-Competitor 'separate' 'competitor-owner' 'runtime-A'; Refuse-Amend 'runtime conflict preserved' (Amend-Params) 'runtime_lane_overlap'
    Reset-Amend
    $junction=Join-Path $wtB 'escape'; New-Item -ItemType Junction -Path $junction -Target $otherRepo | Out-Null
    try { $p=Amend-Params; $p.AddPaths=@('escape/new.ps1'); Refuse-Amend 'escaping junction refuses' $p 'unsafe_path' }
    finally { [IO.Directory]::Delete($junction) }
    $p=Amend-Params; $p.AddPaths=@('seed.txt/new'); Refuse-Amend 'new file below file ancestor refuses' $p 'unsafe_path'
    $external=Join-Path $tempRoot 'legacy-external'; New-Item -ItemType Directory $external|Out-Null
    $obj=$baseline|ConvertFrom-Json; $obj.allowed_paths+=@($external); $obj.critical_paths+=@($external); [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100))
    $x=Invoke-Amend (Amend-Params)
    Assert-True 'historical external absolute scope preserved' ($x.ExitCode -eq 0 -and (Get-Content -Raw $laneFile|ConvertFrom-Json).allowed_paths -ccontains $external) $x.Text
    Reset-Amend; $p=Amend-Params; $p.AddPaths=@('new/one','new/two','NEW/ONE')
    $x=Invoke-Amend $p; $obj=Get-Content -Raw $laneFile|ConvertFrom-Json
    Assert-True 'multiple additions deduplicate case without changing existing spelling' ($x.ExitCode -eq 0 -and $obj.allowed_paths.Count -eq 3 -and $obj.scope_amendments.Count -eq 1) $x.Text
    $firstReceipt=$obj.scope_amendments[0]|ConvertTo-Json -Depth 100 -Compress
    $p=Amend-Params; $p.AddPaths=@('new/three'); $x=Invoke-Amend $p; $obj=Get-Content -Raw $laneFile|ConvertFrom-Json
    Assert-True 'second amendment appends history preserves first receipt' ($x.ExitCode -eq 0 -and $obj.scope_amendments.Count -eq 2 -and ($obj.scope_amendments[0]|ConvertTo-Json -Depth 100 -Compress) -ceq $firstReceipt) $x.Text
    Reset-Amend; [void](Invoke-Amend (Amend-Params)); Add-Competitor 'new'
    Refuse-Amend 'duplicate replay still performs admission conflict check' (Amend-Params) 'conflict'
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$amendRoot,'-LaneId','amend-lane','-ExpectedState','BLOCKED','-NewState','READY','-Json')
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$amendRoot,'-LaneId','amend-lane','-ExpectedState','READY','-NewState','RUNNING','-Json')
    Assert-True 'activation conflict check covers amended scope' ($x.ExitCode -ne 0 -and $x.Text -match 'conflict') $x.Text
    # Observe readers during the real writer; every successful read must be exactly
    # the old or final JSON byte sequence, never scope without its receipt.
    Reset-Amend; $oldBytes=[IO.File]::ReadAllText($laneFile); $p=Amend-Params
    $inputFile=Join-Path $tempRoot 'atomic-args.xml'; $p | Export-Clixml $inputFile
    $atomicOut=Join-Path $tempRoot 'atomic.out'; $atomicErr=Join-Path $tempRoot 'atomic.err'
    $proc=Start-Process powershell.exe -ArgumentList @('-NoProfile','-File',('"'+$driver+'"'),('"'+$scriptPath+'"'),('"'+$inputFile+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput $atomicOut -RedirectStandardError $atomicErr
    $processHandle=$proc.Handle # retain native exit status before HasExited closes its temporary handle
    $observed=New-Object Collections.Generic.HashSet[string]; $readErrors=0
    do {
        try {
            $fs=[IO.File]::Open($laneFile,'Open','Read',([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            $sr=New-Object IO.StreamReader($fs); try { [void]$observed.Add($sr.ReadToEnd()) } finally { $sr.Dispose() }
        } catch { $readErrors++ }
        Start-Sleep -Milliseconds 2
    } while(-not $proc.HasExited)
    $proc.WaitForExit(); $newBytes=[IO.File]::ReadAllText($laneFile); [void]$observed.Add($newBytes)
    Assert-True 'atomic reader sees old or new complete JSON only' ($proc.ExitCode -eq 0 -and $readErrors -eq 0 -and $oldBytes -cne $newBytes -and $observed.Contains($oldBytes) -and @($observed|Where-Object {$_ -cne $oldBytes -and $_ -cne $newBytes}).Count -eq 0 -and (Get-Content -Raw $laneFile|ConvertFrom-Json).scope_amendments.Count -eq 1) ((Get-Content -Raw $atomicErr)+' observations='+$observed.Count+' errors='+$readErrors+' exit='+$proc.ExitCode+' old='+$observed.Contains($oldBytes))
    Assert-True 'worktree and index bytes unchanged by amendment tests' ((Get-FileHash $indexPath).Hash -ceq $indexBefore -and [IO.File]::ReadAllText((Join-Path $wtB 'seed.txt')) -ceq 'dirty tracked fixture' -and [IO.File]::ReadAllText((Join-Path $wtB 'untracked.txt')) -ceq 'untracked fixture') 'worktree or index changed'
    # Repair1 regression fixtures. Everything below operates on disposable records.
    $repairStart=$pass; $repairFailStart=$fail
    foreach($character in @([char]0xA0,[char]0x2003,[char]0xE01)){
        Reset-Amend
        $literal=([string]$character)+'identity.ps1'
        [IO.File]::WriteAllText((Join-Path $wtB $literal),'unicode file')
        [IO.File]::WriteAllText((Join-Path $wtB 'identity.ps1'),'plain file')
        $obj=$baseline|ConvertFrom-Json; $obj.allowed_paths=@($literal); $obj.critical_paths=@($literal)
        [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100))
        $p=Amend-Params; $p.AddPaths=@('identity.ps1')
        $x=Invoke-Amend $p; $obj=Get-Content -Raw -Encoding UTF8 $laneFile|ConvertFrom-Json
        Assert-True "repair1 distinct Unicode U+$('{0:X4}' -f [int]$character) path is added" ($x.ExitCode -eq 0 -and $x.Text -match 'AMENDED' -and $obj.allowed_paths.Count -eq 2 -and $obj.allowed_paths[0] -ceq $literal -and $obj.allowed_paths[1] -ceq 'identity.ps1' -and $obj.critical_paths.Count -eq 2) $x.Text
        $fp=Registry-Fingerprint; $p.AddPaths=@($literal,'IDENTITY.PS1')
        $a=Invoke-Amend $p; $b=Invoke-Amend $p
        Assert-True "repair1 Unicode U+$('{0:X4}' -f [int]$character) replay is exact NO_CHANGE" ($a.ExitCode -eq 0 -and $a.Text -match 'NO_CHANGE' -and $a.Text -ceq $b.Text -and (Registry-Fingerprint) -ceq $fp) ($a.Text+' / '+$b.Text)
    }
    Reset-Amend; $p=Amend-Params
    $p.AddPaths=@(('dir/file'+[char]0xA0),('dir/'+[char]0x2003+'file'),('dir/'+[char]0xE01+'file'))
    $x=Invoke-Amend $p; $obj=Get-Content -Raw -Encoding UTF8 $laneFile|ConvertFrom-Json
    Assert-True 'repair1 accepted Unicode components stored literally' ($x.ExitCode -eq 0 -and ($obj.allowed_paths[1..3] -join '|') -ceq ($p.AddPaths -join '|')) $x.Text
    $fp=Registry-Fingerprint; $p.AddPaths=@($p.AddPaths|ForEach-Object {$_.Replace('/','\')})
    $x=Invoke-Amend $p
    Assert-True 'repair1 separator-only Unicode replay NO_CHANGE' ($x.ExitCode -eq 0 -and $x.Text -match 'NO_CHANGE' -and (Registry-Fingerprint) -ceq $fp) $x.Text
    Reset-Amend; $p=Amend-Params
    $p.AddPaths=@(('names/'+[char]0xE9+'.txt'),('names/e'+[char]0x301+'.txt'))
    $x=Invoke-Amend $p; $obj=Get-Content -Raw -Encoding UTF8 $laneFile|ConvertFrom-Json
    Assert-True 'repair1 composed and decomposed Unicode are distinct Windows names' ($x.ExitCode -eq 0 -and $obj.allowed_paths.Count -eq 3 -and $obj.critical_paths.Count -eq 3) $x.Text
    Reset-Amend; Add-Competitor (([string][char]0xA0)+'identity.ps1')
    $p=Amend-Params; $p.AddPaths=@('identity.ps1'); $x=Invoke-Amend $p
    Assert-True 'repair1 distinct NBSP competitor does not alias plain path' ($x.ExitCode -eq 0 -and $x.Text -match 'AMENDED') $x.Text
    Reset-Amend; Add-Competitor (([string][char]0xA0)+'identity.ps1')
    $p=Amend-Params; $p.AddPaths=@((([string][char]0xA0)+'IDENTITY.PS1'))
    Refuse-Amend 'repair1 true Unicode competitor alias still conflicts' $p 'conflict'

    # Exercise every complete-record writer: AmendScope, Transition, and Claim's
    # superseded-record write. Depth 70 is accepted by AmendScope but exceeds 10.
    Reset-Amend; $obj=$baseline|ConvertFrom-Json
    $deep=[ordered]@{leaf=@('preserve',17,$null,[ordered]@{unicode=([string][char]0xE01);flag=$true})}
    1..70|ForEach-Object {$deep=[ordered]@{child=$deep}}
    $obj|Add-Member deep_extension $deep
    [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100))
    $deepExpected=Expected-Digest $deep
    $x=Invoke-Amend (Amend-Params); $obj=Get-Content -Raw -Encoding UTF8 $laneFile|ConvertFrom-Json
    Assert-True 'repair1 AmendScope preserves depth70 extension' ($x.ExitCode -eq 0 -and (Expected-Digest $obj.deep_extension) -ceq $deepExpected) $x.Text
    $receiptsExpected=Expected-Digest @($obj.scope_amendments)
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$amendRoot,'-LaneId','amend-lane','-ExpectedState','BLOCKED','-NewState','WAITING','-Json')
    $obj=Get-Content -Raw -Encoding UTF8 $laneFile|ConvertFrom-Json
    Assert-True 'repair1 subsequent Transition preserves depth70 extension' ($x.ExitCode -eq 0 -and (Expected-Digest $obj.deep_extension) -ceq $deepExpected) $x.Text
    Assert-True 'repair1 subsequent Transition preserves complete receipt bytes' ((Expected-Digest @($obj.scope_amendments)) -ceq $receiptsExpected) 'receipt digest mismatch'
    # Reseed from the accepted amended snapshot so this independently catches the
    # other full-record rewrite even if the preceding Transition regresses.
    $obj|Add-Member deep_extension $deep -Force
    [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100))
    $claim=New-ClaimArgs $amendRoot 'replacement' 'amend-owner' $wtC 'lane-c' $head 'other/scope' 'BLOCKED'
    $claim+=@('-SupersedeOwnLaneId','amend-lane'); $x=Invoke-Tool $claim
    $obj=Get-Content -Raw -Encoding UTF8 $laneFile|ConvertFrom-Json
    Assert-True 'repair1 superseding Claim preserves depth70 extension' ($x.ExitCode -eq 0 -and $obj.state -ceq 'DONE' -and (Expected-Digest $obj.deep_extension) -ceq $deepExpected) $x.Text
    Assert-True 'repair1 superseding Claim preserves complete receipt bytes' ((Expected-Digest @($obj.scope_amendments)) -ceq $receiptsExpected) 'receipt digest mismatch'
    Reset-Amend; $obj=$baseline|ConvertFrom-Json; $obj|Add-Member deep_extension $deep
    [IO.File]::WriteAllText($laneFile,($obj|ConvertTo-Json -Depth 100))
    $x=Invoke-Tool @('-Command','Transition','-RegistryRoot',$amendRoot,'-LaneId','amend-lane','-ExpectedState','BLOCKED','-NewState','WAITING','-Json')
    $obj=Get-Content -Raw -Encoding UTF8 $laneFile|ConvertFrom-Json
    Assert-True 'repair1 legacy record without amendments retains deep extension' ($x.ExitCode -eq 0 -and $obj.PSObject.Properties.Name -notcontains 'scope_amendments' -and (Expected-Digest $obj.deep_extension) -ceq $deepExpected) $x.Text

    # A real drive-relative reference exists in the child process working directory.
    Reset-Amend; $p=Amend-Params
    Push-Location $tempRoot
    try { $p.AuthorityRef=([IO.Path]::GetPathRoot($authority).Substring(0,2))+'authority.txt'; Refuse-Amend 'repair1 drive-relative authority refuses' $p 'authority_reference' }
    finally { Pop-Location }
    Reset-Amend; $p=Amend-Params; $p.AuthorityRef='\\localhost\C$\authority.txt'
    Refuse-Amend 'repair1 UNC authority refuses' $p 'authority_reference'
    foreach($prefix in @('\\?\','\\.\')){
        $p=Amend-Params; $p.AuthorityRef=$prefix+$authority
        Refuse-Amend "repair1 device authority refuses [$prefix]" $p 'authority_reference'
    }
    Reset-Amend; $p=Amend-Params
    $authoritySub=Join-Path $tempRoot 'authority-sub'; New-Item -ItemType Directory -Path $authoritySub|Out-Null
    $p.AuthorityRef=Join-Path $authoritySub '..\authority.txt'
    $x=Invoke-Amend $p; $obj=Get-Content -Raw -Encoding UTF8 $laneFile|ConvertFrom-Json
    Assert-True 'repair1 fully qualified local authority records resolved identity' ($x.ExitCode -eq 0 -and $obj.scope_amendments[0].authority_ref -ceq (Get-Item -LiteralPath $authority).FullName -and $obj.scope_amendments[0].authority_sha256 -ieq $authorityHash) $x.Text

    # Deterministic provider errors; no ACL privileges or network are required.
    # The shim emits normal nonterminating PowerShell errors, so SilentlyContinue
    # really hides them in the vulnerable implementation and Stop exposes them.
    $faultDriver=Join-Path $tempRoot 'fault-driver.ps1'
    [IO.File]::WriteAllText($faultDriver,@'
param($Tool,$InputFile,$FaultPath,$FaultKind)
$ErrorActionPreference='Stop'
function Get-Item {
    [CmdletBinding()]param([string]$LiteralPath,[switch]$Force)
    if($LiteralPath -ceq $FaultPath){
        $ex=if($FaultKind -eq 'access'){[UnauthorizedAccessException]::new('fixture access denied')}else{[IO.IOException]::new('fixture IO failure')}
        $category=if($FaultKind -eq 'access'){[Management.Automation.ErrorCategory]::PermissionDenied}else{[Management.Automation.ErrorCategory]::ReadError}
        $PSCmdlet.WriteError([Management.Automation.ErrorRecord]::new($ex,'FixtureInspectionFailure',$category,$LiteralPath))
        return
    }
    Microsoft.PowerShell.Management\Get-Item @PSBoundParameters
}
$p=Import-Clixml -LiteralPath $InputFile
& $Tool @p
'@)
    $denied=Join-Path $wtB 'denied'; New-Item -ItemType Directory -Path $denied|Out-Null
    foreach($kind in @('access','io')){
        Reset-Amend; $p=Amend-Params; $p.AddPaths=@('denied/new/leaf.ps1')
        $fp=Registry-Fingerprint; $inputFile=Join-Path $tempRoot 'fault-args.xml'; $p|Export-Clixml $inputFile
        $saved=$ErrorActionPreference; $ErrorActionPreference='Continue'
        try { $out=& powershell.exe -NoProfile -File $faultDriver $scriptPath $inputFile $denied $kind 2>&1; $code=$LASTEXITCODE }
        finally {$ErrorActionPreference=$saved}
        $output=($out|Out-String)
        Assert-True "repair1 ancestor $kind error fails closed without mutation" ($code -ne 0 -and $output -match 'unsafe_path' -and (Registry-Fingerprint) -ceq $fp) $output
    }
    Reset-Amend; $p=Amend-Params; $p.AddPaths=@('confirmed-absent/child/leaf.ps1')
    $x=Invoke-Amend $p
    Assert-True 'repair1 confirmed nonexistent suffix under inspected directory succeeds' ($x.ExitCode -eq 0 -and $x.Text -match 'AMENDED') $x.Text
    Write-Host "REPAIR1_MATRIX PASS=$($pass-$repairStart) FAIL=$($fail-$repairFailStart)"

    Write-Host "AMENDSCOPE_MATRIX PASS=$($pass-$oldPass) FAIL=$fail"
} catch {
    Fail 'test harness' $_.Exception.Message
} finally {
    $resolvedTemp=[IO.Path]::GetFullPath($tempRoot)
    if(-not $resolvedTemp.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolvedTemp) -notlike 'ea-lab-lane-registry-*'){ throw 'unsafe fixture cleanup root' }
    if(Test-Path $repo){ & git -C $repo worktree remove --force $wtB 2>$null; & git -C $repo worktree remove --force $wtC 2>$null }
    if(Test-Path $tempRoot){ Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "TOTAL PASS=$pass FAIL=$fail"
if($fail -gt 0){exit 1}else{exit 0}
