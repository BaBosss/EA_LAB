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
} catch {
    Fail 'test harness' $_.Exception.Message
} finally {
    if(Test-Path $repo){ & git -C $repo worktree remove --force $wtB 2>$null; & git -C $repo worktree remove --force $wtC 2>$null }
    if(Test-Path $tempRoot){ Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "TOTAL PASS=$pass FAIL=$fail"
if($fail -gt 0){exit 1}else{exit 0}
