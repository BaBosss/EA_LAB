<#
.SYNOPSIS
    ORDER-105 Contract D negative, concurrency, recovery, and real-hook suite.

.DESCRIPTION
    Every mutable scenario runs in a GUID-named repository under TEMP. The
    shared repository is captured before the suite and compared afterward for
    HEAD, index, worktree status, and local Git config identity. Child processes
    have bounded waits and are terminated if their case deadline expires.
#>
param(
    [int]$ChildTimeoutSeconds = 45,
    [switch]$DevFast
)

$ErrorActionPreference = 'Stop'
$SourceRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
. (Join-Path $SourceRoot 'scripts\experiment_event_log.ps1') -RepoRoot $SourceRoot

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false, $true)
$Results = New-Object System.Collections.Generic.List[object]
$RunId = [guid]::NewGuid().ToString('N')
$Scratch = Join-Path $env:TEMP ('ea_lab_order105_' + $RunId)
$Seed = Join-Path $Scratch 'seed'
$SharedScopeExact = @(
    'scripts/experiment_event_log.ps1',
    'scripts/check_experiment_events.ps1',
    'scripts/_test/run_order105_negative_tests.ps1',
    '.githooks/pre-commit',
    '.gitattributes'
)

function Add-Case {
    param([string]$Name,[bool]$Pass,[string]$Detail='')
    $Results.Add([pscustomobject]@{Name=$Name;Pass=$Pass;Detail=$Detail})
    Write-Host ("[progress] $Name = $(if($Pass){'PASS'}else{'FAIL'})")
}

function Write-Utf8 {
    param([string]$Path,[string]$Text)
    $parent=Split-Path -Parent $Path;if($parent -and -not (Test-Path $parent)){New-Item -ItemType Directory -Force $parent|Out-Null}
    [System.IO.File]::WriteAllText($Path,$Text.Replace("`r`n","`n").Replace("`r","`n"),$Utf8NoBom)
}

function Write-Bytes {
    param([string]$Path,[byte[]]$Bytes)
    $parent=Split-Path -Parent $Path;if($parent -and -not (Test-Path $parent)){New-Item -ItemType Directory -Force $parent|Out-Null}
    [System.IO.File]::WriteAllBytes($Path,$Bytes)
}

function Invoke-BoundedProcess {
    # Every synchronous child (powershell.exe or git) runs under a finite deadline so
    # a hung child fails visibly instead of stalling the suite (annex F14; review
    # round 3 finding 2). Mirrors the Start-UtilityProcess ProcessStartInfo + quoting
    # used by the async Wait-Child path, adding a WaitForExit deadline + kill. Pipes
    # are drained asynchronously before the wait so a full pipe buffer cannot deadlock
    # against WaitForExit.
    param([string]$FileName,[string[]]$AllArgs,[hashtable]$EnvVars,[int]$TimeoutSeconds=$ChildTimeoutSeconds)
    $psi=New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName=$FileName
    $psi.Arguments=(($AllArgs|ForEach-Object{Quote-ProcessArgument $_}) -join ' ')
    $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    if($EnvVars){foreach($k in $EnvVars.Keys){$psi.EnvironmentVariables[$k]=$EnvVars[$k]}}
    $p=New-Object System.Diagnostics.Process;$p.StartInfo=$psi
    if(-not $p.Start()){throw "failed to start child '$FileName'"}
    $outTask=$p.StandardOutput.ReadToEndAsync();$errTask=$p.StandardError.ReadToEndAsync()
    if(-not $p.WaitForExit($TimeoutSeconds*1000)){try{$p.Kill()}catch{};try{[void]$p.WaitForExit(5000)}catch{};throw "child '$FileName' exceeded ${TimeoutSeconds}s deadline and was terminated"}
    $code=$p.ExitCode;$out=$outTask.GetAwaiter().GetResult();$err=$errTask.GetAwaiter().GetResult();$p.Dispose()
    return [pscustomobject]@{ExitCode=$code;StdOut=$out;StdErr=$err}
}

function Invoke-TestGit {
    param([string]$Root,[string[]]$GitArgs,[switch]$AllowFailure)
    # Bounded so a wedged git child (e.g. a hung hook) cannot stall the suite. Git
    # commit paths run the pre-commit hook (PowerShell checkers), so allow more time.
    $r=Invoke-BoundedProcess -FileName 'git' -AllArgs (@('-C',$Root)+$GitArgs) -TimeoutSeconds ([Math]::Max($ChildTimeoutSeconds,120))
    # Trim() both ends, not TrimEnd(): stdout is empty for a hook failure, so the
    # leading newline survived and the reporter printed "[FAIL] <case> ::" with the
    # real message on the next line. That read as an empty detail and cost a whole
    # diagnosis cycle -- the message was never swallowed, only pushed off the line.
    $text=(($r.StdOut+"`n"+$r.StdErr) -join '').Trim()
    if(-not $AllowFailure -and $r.ExitCode -ne 0){
        # A git child can also fail with nothing at all on either stream. Reporting
        # an empty throw there is a counter that lies; name the command instead.
        if(-not $text){$text="git child exited $($r.ExitCode) with no stdout/stderr (root='$Root'; args='$($GitArgs -join ' ')')"}
        throw $text
    }
    return [pscustomobject]@{ExitCode=$r.ExitCode;Text=$text}
}

function Test-IsSharedScopePath {
    param([string]$Path)
    $normalized=$Path.Replace('\','/')
    return ($normalized -in $SharedScopeExact -or $normalized.StartsWith('docs/memory_control/experiment_events/',[StringComparison]::Ordinal))
}

function Get-SharedScopePaths {
    $paths=New-Object Collections.Generic.HashSet[string] ([StringComparer]::Ordinal)
    foreach($path in $SharedScopeExact){[void]$paths.Add($path)}
    $listed=Invoke-TestGit -Root $SourceRoot -GitArgs @('ls-files','--cached','--others','--exclude-standard','--','docs/memory_control/experiment_events') -AllowFailure
    if($listed.ExitCode -ne 0){throw "shared scope enumeration failed: $($listed.Text)"}
    foreach($path in ($listed.Text -split "`r?`n")){if($path){[void]$paths.Add($path.Replace('\','/'))}}
    return @($paths|Sort-Object)
}

function Get-SharedIdentity {
    $head=(Invoke-TestGit -Root $SourceRoot -GitArgs @('rev-parse','HEAD')).Text
    $config=(Invoke-TestGit -Root $SourceRoot -GitArgs @('config','--local','--list')).Text
    $index=@{};$worktree=@{}
    foreach($path in Get-SharedScopePaths){
        $indexResult=Invoke-TestGit -Root $SourceRoot -GitArgs @('rev-parse','--verify',(':'+$path)) -AllowFailure
        $index[$path]=if($indexResult.ExitCode -eq 0){$indexResult.Text}else{'<absent>'}
        $worktree[$path]=Get-FileIdentity (Join-Path $SourceRoot ($path-replace '/','\'))
    }
    return [pscustomobject]@{Head=$head;Index=$index;Worktree=$worktree;Config=$config}
}

function Compare-SharedScopeMap {
    param([hashtable]$Before,[hashtable]$After)
    $keys=@($Before.Keys)+@($After.Keys)|Sort-Object -Unique
    $changed=New-Object Collections.Generic.List[string]
    foreach($key in $keys){
        $left=if($Before.ContainsKey($key)){$Before[$key]}else{'<absent>'}
        $right=if($After.ContainsKey($key)){$After[$key]}else{'<absent>'}
        if($left -cne $right){$changed.Add($key)}
    }
    return @($changed)
}

function Remove-Scratch {
    param([string]$Path)
    $full=[System.IO.Path]::GetFullPath($Path)
    $temp=[System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
    if(-not $full.StartsWith($temp,[System.StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $full) -notmatch '^ea_lab_order105_[0-9a-f]{32}$'){
        throw "refusing unsafe scratch removal '$full'"
    }
    if(Test-Path $full){Remove-Item -LiteralPath $full -Recurse -Force}
}

function Invoke-Utility {
    param([string]$Root,[string[]]$UtilityArgs)
    # Bounded synchronous utility child (review round 3 finding 2). Env is passed to
    # the child process directly rather than mutating the parent's environment.
    $script=Join-Path $Root 'scripts\experiment_event_log.ps1'
    $all=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script,'-RepoRoot',$Root)+$UtilityArgs
    $r=Invoke-BoundedProcess -FileName 'powershell.exe' -AllArgs $all -EnvVars @{EA_LAB_EVENT_TEST_MODE='1'}
    $output=@((($r.StdOut+"`n"+$r.StdErr) -split "`r?`n")|Where-Object{$_ -ne ''})
    $json=$null
    foreach($line in $output){try{$candidate=$line|ConvertFrom-Json;if($candidate.status){$json=$candidate}}catch{}}
    return [pscustomobject]@{ExitCode=$r.ExitCode;Output=($output -join "`n");Json=$json}
}

function Start-UtilityProcess {
    param([string]$Root,[string[]]$UtilityArgs,[string]$OutPath,[string]$ErrPath,[string]$ScriptPath)
    # ScriptPath (optional) runs a test-owned wrapper script instead of the utility;
    # the caller then supplies ALL arguments itself (no implicit -RepoRoot injection).
    $script=if($ScriptPath){$ScriptPath}else{Join-Path $Root 'scripts\experiment_event_log.ps1'}
    $psi=New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName='powershell.exe'
    $all=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$script)
    if(-not $ScriptPath){$all+=@('-RepoRoot',$Root)}
    $all+=$UtilityArgs
    $psi.Arguments=(($all|ForEach-Object{Quote-ProcessArgument $_}) -join ' ')
    $psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $psi.EnvironmentVariables['EA_LAB_EVENT_TEST_MODE']='1'
    $p=New-Object System.Diagnostics.Process;$p.StartInfo=$psi
    if(-not $p.Start()){throw 'failed to start child PowerShell'}
    return [pscustomobject]@{Process=$p;OutPath=$OutPath;ErrPath=$ErrPath}
}

function Wait-Child {
    param($Child,[int]$TimeoutSeconds=$ChildTimeoutSeconds)
    if(-not $Child.Process.WaitForExit($TimeoutSeconds*1000)){
        try{$Child.Process.Kill()}catch{};throw "child process timed out after $TimeoutSeconds seconds"
    }
    $stdout=$Child.Process.StandardOutput.ReadToEnd();$stderr=$Child.Process.StandardError.ReadToEnd();$code=$Child.Process.ExitCode;$Child.Process.Dispose()
    if($Child.OutPath){Write-Utf8 $Child.OutPath $stdout};if($Child.ErrPath){Write-Utf8 $Child.ErrPath $stderr}
    $json=$null;foreach($line in ($stdout -split "`r?`n")){try{$c=$line|ConvertFrom-Json;if($c.status){$json=$c}}catch{}}
    return [pscustomobject]@{ExitCode=$code;StdOut=$stdout;StdErr=$stderr;Json=$json}
}

function Add-HookPrereqs {
    # The real pre-commit hook fails closed when its interpreter is missing, which is the
    # correct behaviour for the repo and fatal for a fixture clone. The interpreter is
    # git-ignored in the seed (22 MB of binary must not travel through git objects into
    # fifty clones), so every fixture worktree gets it here instead.
    #
    # ONE real copy per suite run, under $Scratch, and HARD LINKS from each fixture. The
    # first version copied 22 MB per fixture and left 1,101 MB in TEMP -- measured -- which
    # this suite cannot afford, because it gets interrupted often and an interrupted run
    # never reaches Remove-Scratch. Hard links are safe to delete (unlink, never follow) and
    # both ends are always under $env:TEMP, so they are always on one volume. A junction to
    # the repo's real tools/ directory would be cheaper still and is deliberately NOT used:
    # that would put a delete-through-reparse-point hazard between Remove-Scratch and the
    # only interpreter the commit path has.
    param([string]$Root)
    $src=Join-Path $SourceRoot ($script:HookPythonDirRel -replace '/','\')
    if(-not (Test-Path -LiteralPath $src)){ throw "hook prereq: '$src' does not exist, but .githooks/pre-commit fails closed without it -- every fixture commit would die at PRECOMMIT-FAIL-CLOSED" }
    if(-not $script:HookPyCache){
        $script:HookPyCache=Join-Path $Scratch '_hook_interpreter'
        Copy-Item -LiteralPath $src -Destination $script:HookPyCache -Recurse -Force
    }
    $dst=Join-Path $Root ($script:HookPythonDirRel -replace '/','\')
    if(Test-Path -LiteralPath $dst){ return }
    New-Item -ItemType Directory -Force $dst|Out-Null
    foreach($f in (Get-ChildItem -LiteralPath $script:HookPyCache -File -Recurse)){
        $rel=$f.FullName.Substring($script:HookPyCache.Length).TrimStart('\')
        $target=Join-Path $dst $rel
        $targetDir=Split-Path -Parent $target
        if(-not (Test-Path -LiteralPath $targetDir)){ New-Item -ItemType Directory -Force $targetDir|Out-Null }
        try{ New-Item -ItemType HardLink -Path $target -Value $f.FullName -ErrorAction Stop|Out-Null }
        catch{ Copy-Item -LiteralPath $f.FullName -Destination $target -Force }
    }
}

function New-Fixture {
    param([string]$Name)
    $root=Join-Path $Scratch $Name
    $clone=Invoke-TestGit -Root $Scratch -GitArgs @('clone','--quiet','--no-hardlinks',$Seed,$root)
    Add-HookPrereqs -Root $root
    Invoke-TestGit -Root $root -GitArgs @('config','user.name','ORDER105 Test')|Out-Null
    Invoke-TestGit -Root $root -GitArgs @('config','user.email','order105@example.invalid')|Out-Null
    Invoke-TestGit -Root $root -GitArgs @('config','core.hooksPath','.githooks')|Out-Null
    return $root
}

function New-ZeroManifestFixture {
    param([string]$Name)
    $root=Join-Path $Scratch $Name
    Invoke-TestGit -Root $Scratch -GitArgs @('clone','--quiet','--no-hardlinks',$Seed,$root)|Out-Null
    Add-HookPrereqs -Root $root
    Invoke-TestGit -Root $root -GitArgs @('checkout','--quiet',$script:ZeroManifestCommit)|Out-Null
    Invoke-TestGit -Root $root -GitArgs @('config','user.name','ORDER105 Zero Test')|Out-Null
    Invoke-TestGit -Root $root -GitArgs @('config','user.email','order105-zero@example.invalid')|Out-Null
    Invoke-TestGit -Root $root -GitArgs @('config','core.hooksPath','.githooks')|Out-Null
    return $root
}

function Get-HeadCommit {
    param([string]$Root)
    return (Invoke-TestGit -Root $Root -GitArgs @('rev-parse','HEAD')).Text
}

function New-OwnerRef {
    param([string]$Root,[string]$OwnerType,[string]$Path,[string]$Anchor)
    $commit=Get-HeadCommit $Root
    $blob=Get-CommittedBlobRecord -Root $Root -Commit $commit -Path $Path -Anchor $Anchor -RequireAnchor
    return [pscustomobject][ordered]@{owner_type=$OwnerType;path=$Path;commit_oid=$commit;blob_oid=$blob.BlobOid;raw_sha256=$blob.RawSha256;anchor=$Anchor}
}

function Get-SeedEvidence {
    param([string]$Root)
    $schemas=Get-SchemaObjects -Root $Root;$live=Get-LiveSnapshotBytes -Root $Root
    $read=Read-JsonlRecords -Bytes $live.ManifestBytes -Path 'manifest' -Schema $schemas.Evidence -Kind Evidence -Root $Root -ResolveReferences -RequireCanonical
    return $read.Records[0].Object
}

function New-IdeaRequest {
    param([string]$Root,[string]$EventId=('evt_'+[guid]::NewGuid().ToString()),[string]$ExperimentId=('exp_'+[guid]::NewGuid().ToString()),[string]$ReasonRef='ORDER-105')
    return [pscustomobject][ordered]@{
        schema_version=1;event_id=$EventId;experiment_id=$ExperimentId;event_type='IDEA_CREATED';actor='codex';role='peer_engineer'
        prior_event_id=$null;prior_event_sha256=$null
        artifact_hashes=[pscustomobject][ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null}
        trial_family=$null;trial_count=$null;evidence_ids=@();owner_refs=@((New-OwnerRef -Root $Root -OwnerType taskboard_order -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_IDEA'))
        reason_code='experiment_initiated';reason_ref=$ReasonRef
    }
}

function Write-Request {
    param([string]$Root,$Request,[string]$Name=('request_'+[guid]::NewGuid().ToString('N')+'.json'))
    $path=Join-Path $Root $Name
    Write-Utf8 -Path $path -Text ($Request|ConvertTo-Json -Compress -Depth 20)
    return $path
}

function Get-LastEventRecord {
    param([string]$Root)
    $schemas=Get-SchemaObjects -Root $Root;$live=Get-LiveSnapshotBytes -Root $Root
    $snapshot=Invoke-ValidateEventSnapshot -EventFiles $live.EventFiles -ManifestBytes $live.ManifestBytes -EventSchema $schemas.Event -EvidenceSchema $schemas.Evidence -Root $Root -ResolveReferences
    if(-not $snapshot.IsValid){throw (($snapshot.Errors|ForEach-Object{$_.Detail}) -join '; ')}
    return $snapshot.Events[$snapshot.Events.Count-1]
}

function New-NextRequest {
    param([string]$Root,[string]$Type,[string]$ExperimentId,[string]$EventId=('evt_'+[guid]::NewGuid().ToString()))
    $prior=Get-LastEventRecord $Root;$evd=Get-SeedEvidence $Root
    $hashes=[pscustomobject][ordered]@{ea=$evd.raw_sha256;source=$evd.raw_sha256;set=$evd.raw_sha256;data=$evd.raw_sha256;tester=$evd.raw_sha256}
    $actor='codex';$role='peer_engineer';$trialFamily='order105';$trialCount=1;$evidence=@();$ownerType='taskboard_order';$ownerPath='AGENT_TASKBOARD.md';$anchor='ANCHOR_RUN';$reason='run_started'
    switch($Type){
        'HYPOTHESIS_REGISTERED'{$hashes.ea=$null;$hashes.set=$null;$hashes.data=$null;$hashes.tester=$null;$trialFamily=$null;$trialCount=$null;$anchor='ANCHOR_HYP';$reason='hypothesis_registered'}
        'BAR_PREREGISTERED'{$trialFamily=$null;$trialCount=$null;$ownerType='preregistration';$ownerPath='docs/preregistration.md';$anchor='ANCHOR_PREREG';$reason='bar_preregistered'}
        'RUN_STARTED'{$anchor='ANCHOR_RUN';$reason='run_started'}
        'RESULT_LINKED'{$evidence=@($evd.evidence_id);$anchor='ANCHOR_RESULT';$reason='result_available'}
        'REVIEW_LINKED'{$evidence=@($evd.evidence_id);$ownerType='taskboard_archive';$ownerPath='ARCHIVE_TASKBOARD_2026-07A.md';$anchor='ANCHOR_REVIEW';$reason='review_recorded'}
        'DECISION_LINKED'{$actor='claude';$role='lead_judge';$ownerType='project_decision';$ownerPath='PROJECT_STATE.md';$anchor='ANCHOR_DECISION';$reason='decision_recorded'}
        default{throw "unsupported next type $Type"}
    }
    return [pscustomobject][ordered]@{schema_version=1;event_id=$EventId;experiment_id=$ExperimentId;event_type=$Type;actor=$actor;role=$role;prior_event_id=$prior.Object.event_id;prior_event_sha256=$prior.Sha256;artifact_hashes=$hashes;trial_family=$trialFamily;trial_count=$trialCount;evidence_ids=$evidence;owner_refs=@((New-OwnerRef -Root $Root -OwnerType $ownerType -Path $ownerPath -Anchor $anchor));reason_code=$reason;reason_ref='ORDER-105'}
}

function Add-CoreChain {
    param([string]$Root,[string[]]$Times=@('2026-01-31T23:59:59.999Z','2026-02-01T00:00:00.000Z','2026-02-01T00:00:00.000Z','2026-02-01T00:00:00.001Z','2026-02-01T00:00:00.002Z','2026-02-01T00:00:00.003Z','2026-02-01T00:00:00.004Z'))
    $idea=New-IdeaRequest -Root $Root;$exp=$idea.experiment_id;$requests=@($idea)
    foreach($type in @('HYPOTHESIS_REGISTERED','BAR_PREREGISTERED','RUN_STARTED','RESULT_LINKED','REVIEW_LINKED','DECISION_LINKED')){
        $path=Write-Request -Root $Root -Request $requests[$requests.Count-1]
        $result=Invoke-Utility -Root $Root -UtilityArgs @('-Command','Append','-EventJsonPath',$path,'-TestUtcNow',$Times[$requests.Count-1])
        if($result.ExitCode -ne 0){throw "chain append failed: $($result.Output)"}
        $requests+=,(New-NextRequest -Root $Root -Type $type -ExperimentId $exp)
    }
    $lastPath=Write-Request -Root $Root -Request $requests[$requests.Count-1]
    $last=Invoke-Utility -Root $Root -UtilityArgs @('-Command','Append','-EventJsonPath',$lastPath,'-TestUtcNow',$Times[6])
    if($last.ExitCode -ne 0){throw "chain append failed: $($last.Output)"}
    return $exp
}

function Get-FileIdentity {
    param([string]$Path)
    if(-not (Test-Path $Path)){return '<absent>'}
    $bytes=[IO.File]::ReadAllBytes($Path);return "$($bytes.Length):$(Get-Sha256Hex $bytes)"
}

function Stage-And-Check {
    param([string]$Root,[string[]]$Paths)
    Invoke-TestGit -Root $Root -GitArgs (@('add','--')+$Paths)|Out-Null
    # Bounded checker child (review round 4 finding 2) -- no synchronous unbounded child.
    $r=Invoke-BoundedProcess -FileName 'powershell.exe' -AllArgs @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $Root 'scripts\check_experiment_events.ps1'),'-RepoRoot',$Root)
    return [pscustomobject]@{ExitCode=$r.ExitCode;Output=(($r.StdOut+"`n"+$r.StdErr))}
}

function Initialize-Seed {
    New-Item -ItemType Directory -Force $Seed|Out-Null
    Invoke-TestGit -Root $Seed -GitArgs @('init','--quiet')|Out-Null
    Invoke-TestGit -Root $Seed -GitArgs @('config','user.name','ORDER105 Seed')|Out-Null;Invoke-TestGit -Root $Seed -GitArgs @('config','user.email','seed@example.invalid')|Out-Null
    foreach($dir in @('scripts','scripts/_test','.githooks','docs/memory_control/experiment_events/schema','portfolio','docs')){New-Item -ItemType Directory -Force (Join-Path $Seed ($dir-replace '/','\'))|Out-Null}
    Copy-Item (Join-Path $SourceRoot 'scripts\experiment_event_log.ps1') (Join-Path $Seed 'scripts\experiment_event_log.ps1')
    Copy-Item (Join-Path $SourceRoot 'scripts\check_experiment_events.ps1') (Join-Path $Seed 'scripts\check_experiment_events.ps1')
    Copy-Item (Join-Path $SourceRoot '.githooks\pre-commit') (Join-Path $Seed '.githooks\pre-commit')
    Copy-Item (Join-Path $SourceRoot '.gitattributes') (Join-Path $Seed '.gitattributes')
    Copy-Item (Join-Path $SourceRoot 'docs\memory_control\experiment_events\schema\*.json') (Join-Path $Seed 'docs\memory_control\experiment_events\schema\')
    Write-Bytes (Join-Path $Seed 'docs\memory_control\experiment_events\evidence-manifest.jsonl') ([byte[]]@())
    # Every checker the real .githooks/pre-commit invokes needs a pass-stub here, or the
    # synthetic commit dies before it ever reaches check_experiment_events.ps1 and the
    # failure gets reported against whichever assertion happened to run next.
    #
    # This list is DERIVED from the hook, not hand-maintained, and that is the whole point.
    # The hand-maintained version is what broke: ad470945 (2026-07-26) added
    # check_order_collision.ps1 to the hook and b5d71e47 later added
    # check_handoff_contract.ps1, neither commit touched this file, and the suite died at
    # case 15 of 105 for two days. A by-name defence already existed for exactly this
    # failure (see the -cnotmatch on the two zero-byte cases) and it did not cover the new
    # checker, because it named one script instead of describing the class. Deriving the
    # list means the next checker added to the hook is stubbed the moment it is added.
    # Match EVERY '-File scripts/....ps1' the hook runs, not just the check_* ones. The
    # narrower check_* pattern left scripts/_test/run_fast_cages.ps1 unstubbed, and that
    # was safe only by accident: this suite's synthetic commits stage event files, which
    # do not match the hook's cage pathspec, so that block happens to no-op. Safe-by-
    # condition is the same trap as safe-by-hand-maintained-list, one layer further in.
    $hookText = Get-Content (Join-Path $SourceRoot '.githooks\pre-commit') -Raw -Encoding UTF8
    $needed = @([regex]::Matches($hookText,'-File\s+(scripts/[A-Za-z0-9_/]+)\.ps1') |
                ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    # check_experiment_events is the guard under test -- it is copied in for real above and
    # must never be stubbed, or every case in this suite would pass against nothing.
    $needed = @($needed | Where-Object { $_ -ne 'scripts/check_experiment_events' })
    if($needed.Count -lt 2){ throw "seed: parsed only $($needed.Count) script(s) out of .githooks/pre-commit -- the hook format changed and this stub list is no longer derived from anything" }
    foreach($rel in $needed){
        $stub = Join-Path $Seed (($rel -replace '/','\') + '.ps1')
        New-Item -ItemType Directory -Force (Split-Path -Parent $stub)|Out-Null
        Write-Utf8 $stub "exit 0`n"
    }
    # The hook's PYTHON leg needs the same treatment and the derivation above does not reach
    # it: the pattern matches '-File scripts/....ps1', and fefce8fd (2026-08-01) added a leg
    # that runs a .py through an interpreter instead. The fixture repos have neither, so the
    # hook took its FAIL-CLOSED branch on every synthetic commit and this suite aborted at
    # case 15 of 105 -- for five days, exactly the way the -File list broke before it
    # (ORDER-1460). Two things are derived here, both from the hook's own text:
    #   * the interpreter PATH, from the hook's own assignment -- copied per fixture by
    #     Add-HookPrereqs, because a 22 MB binary must not travel through the seed's git
    #     objects into fifty clones;
    #   * the .py checkers it runs -- stubbed to exit 0 and COMMITTED, exactly like the
    #     PowerShell stubs above, because they are not the guard under test either.
    $pyAssign=[regex]::Match($hookText,'(?m)^\s*py="([^"]+)"')
    if(-not $pyAssign.Success){ throw "seed: no py=`"...`" interpreter assignment in .githooks/pre-commit -- the hook format changed and the interpreter path is no longer derived from anything" }
    $script:HookPythonRel=$pyAssign.Groups[1].Value
    $script:HookPythonDirRel=($script:HookPythonRel -replace '/[^/]+$','')
    if($script:HookPythonDirRel -eq $script:HookPythonRel){ throw "seed: interpreter path '$($script:HookPythonRel)' has no directory component -- cannot stage it per fixture" }
    $pyNeeded=@([regex]::Matches($hookText,'"\$py"\s+([A-Za-z0-9_/.\-]+\.py)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if($pyNeeded.Count -lt 1){ throw "seed: parsed 0 python checker(s) out of .githooks/pre-commit while it does assign an interpreter -- the hook format changed and this stub list is no longer derived from anything" }
    foreach($rel in $pyNeeded){
        $stub=Join-Path $Seed ($rel -replace '/','\')
        New-Item -ItemType Directory -Force (Split-Path -Parent $stub)|Out-Null
        Write-Utf8 $stub "raise SystemExit(0)`n"
    }
    Write-Utf8 (Join-Path $Seed 'AGENT_TASKBOARD.md') "ANCHOR_IDEA`nANCHOR_HYP`nANCHOR_RUN`nANCHOR_RESULT`nANCHOR_RECOVERY`n"
    Write-Utf8 (Join-Path $Seed 'ARCHIVE_TASKBOARD_2026-07A.md') "ANCHOR_REVIEW`n"
    Write-Utf8 (Join-Path $Seed 'EA_SCORECARD_AND_REGISTRY.md') "ANCHOR_SCORECARD`n"
    Write-Utf8 (Join-Path $Seed 'PROJECT_STATE.md') "ANCHOR_DECISION`n"
    Write-Utf8 (Join-Path $Seed 'portfolio\DEPLOYMENTS.csv') "ANCHOR_DEPLOYMENT`n"
    Write-Utf8 (Join-Path $Seed 'docs\preregistration.md') "ANCHOR_PREREG`n"
    Write-Utf8 (Join-Path $Seed 'artifact.bin') 'seed-evidence-bytes'
    Write-Utf8 (Join-Path $Seed '.gitignore') "transient/`n*.tmp-ignore`n$($script:HookPythonDirRel)/`n"
    Invoke-TestGit -Root $Seed -GitArgs @('add','.')|Out-Null;Invoke-TestGit -Root $Seed -GitArgs @('commit','--quiet','-m','seed canonical owners')|Out-Null
    $script:ZeroManifestCommit=Get-HeadCommit $Seed
    $reg=Invoke-Utility -Root $Seed -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','artifact.bin','-CommitOid',(Get-HeadCommit $Seed),'-MediaType','application/octet-stream')
    if($reg.ExitCode -ne 0){throw "seed evidence registration failed: $($reg.Output)"}
    Invoke-TestGit -Root $Seed -GitArgs @('add','docs/memory_control/experiment_events/evidence-manifest.jsonl')|Out-Null;Invoke-TestGit -Root $Seed -GitArgs @('commit','--quiet','-m','seed evidence manifest')|Out-Null
    Invoke-TestGit -Root $Seed -GitArgs @('config','core.hooksPath','.githooks')|Out-Null
    # The seed is a hooked repository too. It is never committed to after this line, but the
    # coverage case below enumerates hooked repositories rather than trusting a list, and a
    # repository that is exempt "because we know it never commits" is the assumption that
    # produced this whole order.
    Add-HookPrereqs -Root $Seed
}

$SharedBefore=Get-SharedIdentity
$Fatal=$null
try{
    New-Item -ItemType Directory -Force $Scratch|Out-Null
    Initialize-Seed

    # The shipped manifest is a committed zero-byte blob.  Prove the first
    # utility append survives the complete production hook from that state.
    $zeroManifest=New-ZeroManifestFixture 'zero_manifest_first_event';$zeroRequest=Write-Request -Root $zeroManifest -Request (New-IdeaRequest -Root $zeroManifest);$zeroAppend=Invoke-Utility -Root $zeroManifest -UtilityArgs @('-Command','Append','-EventJsonPath',$zeroRequest,'-TestUtcNow','2026-01-01T00:00:00.000Z');Invoke-TestGit -Root $zeroManifest -GitArgs @('add','docs/memory_control/experiment_events/events-2026-01.jsonl')|Out-Null;$zeroCommit=Invoke-TestGit -Root $zeroManifest -GitArgs @('commit','-m','first event from empty manifest') -AllowFailure
    Add-Case 'real-hook-first-event-from-committed-zero-byte-manifest-passes' ($zeroAppend.ExitCode -ceq 0 -and $zeroCommit.ExitCode -ceq 0 -and $zeroCommit.Text -cmatch 'PASS' -and $zeroCommit.Text -cnotmatch 'cannot find the file') (($zeroAppend.Output,$zeroCommit.Text)-join "`n")

    $zeroMonth=New-ZeroManifestFixture 'zero_month_first_event';Invoke-TestGit -Root $zeroMonth -GitArgs @('config','core.hooksPath','.no-hooks')|Out-Null;Write-Bytes (Join-Path $zeroMonth 'docs\memory_control\experiment_events\events-2026-01.jsonl') ([byte[]]@());Invoke-TestGit -Root $zeroMonth -GitArgs @('add','docs/memory_control/experiment_events/events-2026-01.jsonl')|Out-Null;Invoke-TestGit -Root $zeroMonth -GitArgs @('commit','--quiet','-m','committed zero byte month')|Out-Null;Invoke-TestGit -Root $zeroMonth -GitArgs @('config','core.hooksPath','.githooks')|Out-Null;$zeroMonthRequest=Write-Request -Root $zeroMonth -Request (New-IdeaRequest -Root $zeroMonth);$zeroMonthAppend=Invoke-Utility -Root $zeroMonth -UtilityArgs @('-Command','Append','-EventJsonPath',$zeroMonthRequest,'-TestUtcNow','2026-01-01T00:00:00.000Z');Invoke-TestGit -Root $zeroMonth -GitArgs @('add','docs/memory_control/experiment_events/events-2026-01.jsonl')|Out-Null;$zeroMonthCommit=Invoke-TestGit -Root $zeroMonth -GitArgs @('commit','-m','first event from empty month') -AllowFailure
    Add-Case 'real-hook-first-event-from-committed-zero-byte-month-passes' ($zeroMonthAppend.ExitCode -ceq 0 -and $zeroMonthCommit.ExitCode -ceq 0 -and $zeroMonthCommit.Text -cmatch 'PASS' -and $zeroMonthCommit.Text -cnotmatch 'cannot find the file') (($zeroMonthAppend.Output,$zeroMonthCommit.Text)-join "`n")

    # ------------------------------------------------------------------
    # Locking, concurrency, idempotency, and atomic installation
    # ------------------------------------------------------------------
    $con=New-Fixture 'concurrency_150'
    $requestRoot=Join-Path $con 'requests';New-Item -ItemType Directory -Force $requestRoot|Out-Null
    $eventsPerWriter=if($DevFast){1}else{50}
    for($w=1;$w -le 3;$w++){
        $dir=Join-Path $requestRoot ("w$w");New-Item -ItemType Directory -Force $dir|Out-Null
        for($i=1;$i -le $eventsPerWriter;$i++){$req=New-IdeaRequest -Root $con;[void](Write-Request -Root $dir -Request $req -Name (('{0:D3}.json' -f $i)))}
    }
    $workerPath=Join-Path $con 'worker.ps1'
    Write-Utf8 $workerPath @'
param($Root,$RequestDir,$Ready,$Gate,$Attempt,$Log)
$ErrorActionPreference='Stop';$env:EA_LAB_EVENT_TEST_MODE='1';$env:EA_LAB_EVENT_STATUS_FILE=$Log;$utf8=New-Object Text.UTF8Encoding($false)
. (Join-Path $Root 'scripts\experiment_event_log.ps1') -RepoRoot $Root
[IO.File]::WriteAllText($Ready,'ready',$utf8)
$deadline=[datetime]::UtcNow.AddSeconds(30);while(-not(Test-Path $Gate)){if([datetime]::UtcNow -gt $deadline){exit 90};Start-Sleep -Milliseconds 20}
[IO.File]::WriteAllText($Attempt,'attempt',$utf8);$failed=0;$processed=0;$lines=New-Object Collections.Generic.List[string]
foreach($request in Get-ChildItem -LiteralPath $RequestDir -Filter '*.json'|Sort-Object Name){
  # ORDER-501 STEP 2. The bounded 3-attempt x 100ms budget is GONE. STEP 1 measured nine runs
  # and found `events < 150` if and only if a child exited non-zero -- every shortfall was a
  # WRITER GIVING UP, never the log dropping a write it had accepted. The budget was 3 tries
  # while three writers pushed 50 requests each through one lock, so it was deterministically
  # too small whenever the run was slow, and what predicted slow was WALL-CLOCK, not load
  # (mean lost 7.67 / 1.67 / 15.33 at 0 / 10 / 20 busy cores; the gap 687s..861s is empty).
  #
  # 🔴 IT IS NOT ENOUGH TO DELETE THE LOOP, and that is worth stating because it is the obvious
  # reading of this order. Three attempts each passing $LockTimeoutSeconds=30 is up to NINETY
  # seconds of waiting per request; one bare call is THIRTY. Deleting the loop and stopping
  # there would have cut the total wait to a third on exactly the slow runs the shortfalls came
  # from -- fixing the shape of the defect while making its incidence worse. STEP 1 never
  # captured WHICH status the failing attempts returned (the scratch tree is deleted at the end
  # of every run), so "30s is plenty" was never measured; it was assumed.
  #
  # So the wait is UNBOUNDED IN TRIES and bounded by WHAT THE WRITE SAYS, which is the
  # difference between waiting for a lock and retrying an error:
  #   * `lock_timeout` means the lock was busy and nothing was decided -> keep waiting.
  #   * any other non-zero status is the log REFUSING this event (conflict, schema, clock
  #     skew). Retrying cannot change it, so it stops immediately and reports what was said.
  # No new number is introduced. The outer bound is the parent's existing
  # `WaitForExit(600000)`: a writer that cannot land one request in ten minutes of pure
  # contention is killed there, `childOk` goes False, and the case fails loudly -- which is a
  # true statement about the log and not a test running out of patience.
  $lastStatus=''
  while($true){
    $Command='Append';$RepoRoot=$Root;$EventJsonPath=$request.FullName;$TestUtcNow='2026-03-01T00:00:00.000Z';$LockTimeoutSeconds=30;$RegisterEvidencePath='';$TestFaultPoint=''
    $rc=Invoke-EventUtilityMain
    if($rc -eq 0){break}
    # The utility writes one status JSON per call to EA_LAB_EVENT_STATUS_FILE, which is $Log.
    $lastStatus='<unreadable>'
    foreach($sl in @(Get-Content -LiteralPath $Log -ErrorAction SilentlyContinue)){
      try{$sj=$sl|ConvertFrom-Json;if($sj.status){$lastStatus=[string]$sj.status}}catch{}
    }
    if($lastStatus -ne 'lock_timeout'){break}
    Start-Sleep -Milliseconds 100
  }
  $processed++
  if($rc -ne 0){$failed++;$lines.Add(("refused {0} rc={1} status={2}" -f $request.Name,$rc,$lastStatus))}
  # Yield after every completed attempt so one process cannot immediately
  # reacquire the production lock for all 50 requests while peers exhaust the
  # pinned 30-second lock timeout.  The held-lock barrier above still proves
  # actual contention and positive retry telemetry for all three writers.
  Start-Sleep -Milliseconds 100
}
[IO.File]::AppendAllText($Log,("completed={0} failed={1}{2}`n" -f $processed,$failed,$(if($lines.Count){' :: '+($lines -join '; ')}else{''})),$utf8);exit $(if($failed){1}else{0})
'@
    $held=$null;$children=@()
    try {
        $held=Enter-EventLock -Root $con -TimeoutSeconds 5
        $gate=Join-Path $con 'barrier.go'
        for($w=1;$w -le 3;$w++){
            $ready=Join-Path $con "ready$w";$attempt=Join-Path $con "attempt$w";$log=Join-Path $con "writer$w.log"
            $p=Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$workerPath,$con,(Join-Path $requestRoot "w$w"),$ready,$gate,$attempt,$log) -WindowStyle Hidden -PassThru
            $children+=[pscustomobject]@{Process=$p;Ready=$ready;Attempt=$attempt;Log=$log}
        }
        $deadline=[datetime]::UtcNow.AddSeconds(30);while(@($children|Where-Object{-not(Test-Path $_.Ready)}).Count){if([datetime]::UtcNow -gt $deadline){throw 'concurrency workers did not reach ready barrier'};Start-Sleep -Milliseconds 20}
        Write-Utf8 $gate 'go'
        $deadline=[datetime]::UtcNow.AddSeconds(30);while(@($children|Where-Object{-not(Test-Path $_.Attempt)}).Count){if([datetime]::UtcNow -gt $deadline){throw 'concurrency workers did not announce lock attempt'};Start-Sleep -Milliseconds 20}
        Start-Sleep -Milliseconds 600;$held.Stream.Dispose();$held=$null
        $childOk=$true
        foreach($child in $children){if(-not $child.Process.WaitForExit(600000)){try{$child.Process.Kill()}catch{};$childOk=$false}else{$childOk=$childOk -and ($child.Process.ExitCode -eq 0)};$child.Process.Dispose();$child.Process=$null}
        $scan=Invoke-Utility -Root $con -UtilityArgs @('-Command','Scan')
        $waitCounts=@();foreach($child in $children){foreach($line in ((Get-Content -LiteralPath $child.Log -ErrorAction SilentlyContinue)-split "`r?`n")){try{$j=$line|ConvertFrom-Json;if($j.status){$waitCounts+=[int]$j.lock_wait_count}}catch{}}}
        $eventCount=if($scan.Json){[int]$scan.Json.details.event_count}else{-1}
        Add-Case 'locking-barrier-held-lock-three-writers-observe-retry' ($childOk -and @($waitCounts|Where-Object{$_ -gt 0}).Count -ge 3) "positive_waits=$(@($waitCounts|Where-Object{$_ -gt 0}).Count)"
        # ORDER-501 STEP 2, the reporting half. The event-count case below cannot tell "the log
        # dropped a write it accepted" from "a writer gave up before writing" -- it reports
        # `events=147 expected=150` for both, and the first reading is a Contract D data-loss
        # defect while the second is a test that ran out of patience. STEP 1 needed NINE runs to
        # establish which one was happening. That discriminator is recorded here instead of
        # re-derived: the writers' own completion lines are read, so the next short run says
        # which of the two it was in its own detail. The scratch tree is deleted in `finally`,
        # so this has to be lifted into a case detail or it is gone with it.
        $abandoned=0;$writerLines=@()
        foreach($child in $children){
            $txt=(@(Get-Content -LiteralPath $child.Log -ErrorAction SilentlyContinue) -join "`n")
            $m=[regex]::Match($txt,'completed=(\d+) failed=(\d+)([^\r\n]*)')
            if($m.Success){$abandoned+=[int]$m.Groups[2].Value;$writerLines+=("{0}/{1}{2}" -f $m.Groups[2].Value,$m.Groups[1].Value,$m.Groups[3].Value)}
            else{$writerLines+='<no completion line>'}
        }
        Add-Case 'concurrent-write-no-writer-abandoned-a-request' ($abandoned -eq 0) "abandoned=$abandoned per-writer(failed/completed)=$($writerLines -join ' | ')"
        $expectedConcurrent=3*$eventsPerWriter
        Add-Case 'concurrent-write-3x50-parseable-150-unique-events' ($childOk -and $scan.ExitCode -eq 0 -and $eventCount -eq $expectedConcurrent -and @($scan.Json.details.good_event_ids|Select-Object -Unique).Count -eq $expectedConcurrent) "events=$eventCount expected=$expectedConcurrent childOk=$childOk"
    } finally {
        if($held){try{$held.Stream.Dispose()}catch{}}
        foreach($child in $children){
            if($child.Process){
                try{if(-not $child.Process.HasExited){$child.Process.Kill();[void]$child.Process.WaitForExit(5000)}}catch{}
                try{$child.Process.Dispose()}catch{}
                $child.Process=$null
            }
        }
    }

    $timeout=New-Fixture 'lock_timeout';$before=Get-FileIdentity (Join-Path $timeout 'docs\memory_control\experiment_events\evidence-manifest.jsonl');$lock=Enter-EventLock -Root $timeout -TimeoutSeconds 5
    try{$req=Write-Request -Root $timeout -Request (New-IdeaRequest -Root $timeout);$child=Start-UtilityProcess -Root $timeout -UtilityArgs @('-Command','Append','-EventJsonPath',$req,'-LockTimeoutSeconds','1') -OutPath '' -ErrPath ''; $timed=Wait-Child $child 10}finally{$lock.Stream.Dispose()}
    $after=Get-FileIdentity (Join-Path $timeout 'docs\memory_control\experiment_events\evidence-manifest.jsonl')
    Add-Case 'lock-timeout-status-and-no-file-mutation' ($timed.ExitCode -ne 0 -and $timed.Json.status -eq 'lock_timeout' -and $before -eq $after -and -not(Test-Path (Join-Path $timeout 'docs\memory_control\experiment_events\events-2026-07.jsonl'))) $timed.StdOut

    $stale=New-Fixture 'stale_lock_path';$lockPath=Get-PrivateGitPath -Root $stale -Name 'ea-lab-experiment-events.lock';Write-Utf8 $lockPath 'stale pathname';$req=Write-Request -Root $stale -Request (New-IdeaRequest -Root $stale);$r=Invoke-Utility -Root $stale -UtilityArgs @('-Command','Append','-EventJsonPath',$req,'-TestUtcNow','2026-03-01T00:00:00.000Z')
    Add-Case 'stale-lock-path-without-handle-does-not-block' ($r.ExitCode -eq 0 -and $r.Json.status -eq 'appended') $r.Output

    $idem=New-Fixture 'idempotency';$id='evt_'+[guid]::NewGuid().ToString();$idea=New-IdeaRequest -Root $idem -EventId $id;$req=Write-Request -Root $idem -Request $idea
    $first=Invoke-Utility -Root $idem -UtilityArgs @('-Command','Append','-EventJsonPath',$req,'-TestUtcNow','2026-03-01T00:00:00.000Z');$logPath=Join-Path $idem 'docs\memory_control\experiment_events\events-2026-03.jsonl';$identity=Get-FileIdentity $logPath
    $retries=@();1..3|ForEach-Object{$retries+=,(Invoke-Utility -Root $idem -UtilityArgs @('-Command','Append','-EventJsonPath',$req,'-TestUtcNow','2026-03-01T00:00:01.000Z'))}
    Add-Case 'idempotency-three-retries-byte-identical-already-appended' ($first.Json.status -eq 'appended' -and @($retries|Where-Object{$_.Json.status -eq 'already_appended'}).Count -eq 3 -and (Get-FileIdentity $logPath) -eq $identity) (($retries|ForEach-Object{$_.Output}) -join '; ')
    $conflictReq=New-IdeaRequest -Root $idem -EventId $id -ExperimentId $idea.experiment_id -ReasonRef 'ORDER-105-CONFLICT';$conflictPath=Write-Request -Root $idem -Request $conflictReq;$conflict=Invoke-Utility -Root $idem -UtilityArgs @('-Command','Append','-EventJsonPath',$conflictPath,'-TestUtcNow','2026-03-01T00:00:01.000Z')
    Add-Case 'same-event-id-different-payload-conflict-no-mutation' ($conflict.ExitCode -ne 0 -and $conflict.Json.status -eq 'event_id_conflict' -and (Get-FileIdentity $logPath) -eq $identity) $conflict.Output

    $fork=New-Fixture 'same_prior_race';$idea=New-IdeaRequest -Root $fork;$ip=Write-Request -Root $fork -Request $idea;[void](Invoke-Utility -Root $fork -UtilityArgs @('-Command','Append','-EventJsonPath',$ip,'-TestUtcNow','2026-03-01T00:00:00.000Z'))
    $h1=New-NextRequest -Root $fork -Type HYPOTHESIS_REGISTERED -ExperimentId $idea.experiment_id;$h2=New-NextRequest -Root $fork -Type HYPOTHESIS_REGISTERED -ExperimentId $idea.experiment_id;$p1=Write-Request -Root $fork -Request $h1;$p2=Write-Request -Root $fork -Request $h2
    $c1=Start-UtilityProcess -Root $fork -UtilityArgs @('-Command','Append','-EventJsonPath',$p1,'-TestUtcNow','2026-03-01T00:00:01.000Z') -OutPath '' -ErrPath '';$c2=Start-UtilityProcess -Root $fork -UtilityArgs @('-Command','Append','-EventJsonPath',$p2,'-TestUtcNow','2026-03-01T00:00:01.000Z') -OutPath '' -ErrPath '';$o1=Wait-Child $c1;$o2=Wait-Child $c2
    $statuses=@($o1.Json.status,$o2.Json.status);$forkScan=Invoke-Utility -Root $fork -UtilityArgs @('-Command','Scan')
    Add-Case 'same-experiment-same-prior-concurrency-one-stale-no-fork' (($statuses -contains 'appended') -and ($statuses -contains 'stale_prior') -and $forkScan.Json.details.event_count -eq 2) ($statuses -join ',')

    $crash=New-Fixture 'faults';$idea=New-IdeaRequest -Root $crash;$req=Write-Request -Root $crash -Request $idea;$target=Join-Path $crash 'docs\memory_control\experiment_events\events-2026-03.jsonl'
    foreach($point in @('before_temp_flush','after_temp_flush_before_replace')){$before=Get-FileIdentity $target;$rr=Invoke-Utility -Root $crash -UtilityArgs @('-Command','Append','-EventJsonPath',$req,'-TestUtcNow','2026-03-01T00:00:00.000Z','-TestFaultPoint',$point);Add-Case ("fault-$point-no-target-mutation") ($rr.ExitCode -ne 0 -and (Get-FileIdentity $target) -eq $before -and -not @(Get-ChildItem (Split-Path $target -Parent) -Filter '.ea-lab-events-*.tmp').Count) $rr.Output}
    $afterReplace=Invoke-Utility -Root $crash -UtilityArgs @('-Command','Append','-EventJsonPath',$req,'-TestUtcNow','2026-03-01T00:00:00.000Z','-TestFaultPoint','after_replace');$postScan=Invoke-Utility -Root $crash -UtilityArgs @('-Command','Scan')
    Add-Case 'fault-after-replace-leaves-valid-complete-install' ($afterReplace.ExitCode -ne 0 -and $postScan.ExitCode -eq 0 -and $postScan.Json.details.event_count -eq 1) $afterReplace.Output
    $unrelated=Join-Path $crash 'docs\memory_control\experiment_events\.ea-lab-unrelated.tmp';Write-Utf8 $unrelated 'keep';$owned=Join-Path $crash 'docs\memory_control\experiment_events\.ea-lab-events-tmp-00000000000000000000000000000000.tmp';Write-Utf8 $owned 'orphan';[void](Invoke-Utility -Root $crash -UtilityArgs @('-Command','Scan'))
    Add-Case 'orphan-temp-cleanup-is-name-scoped' ((Test-Path $unrelated) -and -not(Test-Path $owned)) ''

    $orphan=New-Fixture 'orphan_manifest';Write-Utf8 (Join-Path $orphan 'orphan.bin') 'orphan-only-evidence';Invoke-TestGit -Root $orphan -GitArgs @('add','orphan.bin')|Out-Null;Invoke-TestGit -Root $orphan -GitArgs @('commit','--quiet','-m','orphan evidence artifact')|Out-Null;$reg=Invoke-Utility -Root $orphan -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','orphan.bin','-CommitOid',(Get-HeadCommit $orphan),'-MediaType','application/octet-stream');$scan=Invoke-Utility -Root $orphan -UtilityArgs @('-Command','Scan')
    Add-Case 'orphan-manifest-entry-is-valid' ($reg.ExitCode -eq 0 -and $scan.ExitCode -eq 0 -and $scan.Json.details.event_count -eq 0) $scan.Output

    $sameRace=New-Fixture 'same_id_race';$sameRequest=New-IdeaRequest -Root $sameRace;$samePath=Write-Request -Root $sameRace -Request $sameRequest;$held=Enter-EventLock -Root $sameRace -TimeoutSeconds 5;$sameChildren=@();1..3|ForEach-Object{$sameChildren+=,(Start-UtilityProcess -Root $sameRace -UtilityArgs @('-Command','Append','-EventJsonPath',$samePath,'-TestUtcNow','2026-03-02T00:00:00.000Z') -OutPath '' -ErrPath '')};Start-Sleep -Milliseconds 500;$held.Stream.Dispose();$sameOut=@($sameChildren|ForEach-Object{Wait-Child $_});$sameStatuses=@($sameOut|ForEach-Object{$_.Json.status});$sameScan=Invoke-Utility -Root $sameRace -UtilityArgs @('-Command','Scan')
    Add-Case 'concurrent-same-id-same-payload-one-append-rest-idempotent' (@($sameStatuses|Where-Object{$_ -eq 'appended'}).Count -eq 1 -and @($sameStatuses|Where-Object{$_ -eq 'already_appended'}).Count -eq 2 -and $sameScan.Json.details.event_count -eq 1) ($sameStatuses -join ',')

    $diffRace=New-Fixture 'same_id_diff_race';$sharedId='evt_'+[guid]::NewGuid().ToString();$sharedExp='exp_'+[guid]::NewGuid().ToString();$held=Enter-EventLock -Root $diffRace -TimeoutSeconds 5;$diffChildren=@();1..3|ForEach-Object{$rq=New-IdeaRequest -Root $diffRace -EventId $sharedId -ExperimentId $sharedExp -ReasonRef ("ORDER-105-DIFF-$_");$rp=Write-Request -Root $diffRace -Request $rq;$diffChildren+=,(Start-UtilityProcess -Root $diffRace -UtilityArgs @('-Command','Append','-EventJsonPath',$rp,'-TestUtcNow','2026-03-02T00:00:00.000Z') -OutPath '' -ErrPath '')};Start-Sleep -Milliseconds 500;$held.Stream.Dispose();$diffOut=@($diffChildren|ForEach-Object{Wait-Child $_});$diffStatuses=@($diffOut|ForEach-Object{$_.Json.status});$diffScan=Invoke-Utility -Root $diffRace -UtilityArgs @('-Command','Scan')
    Add-Case 'concurrent-same-id-different-payload-one-append-rest-conflict' (@($diffStatuses|Where-Object{$_ -eq 'appended'}).Count -eq 1 -and @($diffStatuses|Where-Object{$_ -eq 'event_id_conflict'}).Count -eq 2 -and $diffScan.Json.details.event_count -eq 1) ($diffStatuses -join ',')

    $combined=New-Fixture 'combined_evidence_event';Write-Utf8 (Join-Path $combined 'combined.bin') 'combined-evidence';Invoke-TestGit -Root $combined -GitArgs @('add','combined.bin')|Out-Null;Invoke-TestGit -Root $combined -GitArgs @('commit','--quiet','-m','combined evidence artifact')|Out-Null;$blob=Get-CommittedBlobRecord -Root $combined -Commit (Get-HeadCommit $combined) -Path 'combined.bin';$newId='evd_sha256_'+$blob.RawSha256;$rq=New-IdeaRequest -Root $combined;$rq.evidence_ids=@($newId);$rp=Write-Request -Root $combined -Request $rq
    $fault=Invoke-Utility -Root $combined -UtilityArgs @('-Command','Append','-EventJsonPath',$rp,'-RegisterEvidencePath','combined.bin','-RegisterEvidenceCommitOid',(Get-HeadCommit $combined),'-RegisterEvidenceMediaType','application/octet-stream','-TestUtcNow','2026-03-02T00:00:00.000Z','-TestFaultPoint','after_manifest_install_before_event_install');$faultScan=Invoke-Utility -Root $combined -UtilityArgs @('-Command','Scan')
    Add-Case 'fault-after-manifest-before-event-leaves-valid-orphan-not-dangling' ($fault.ExitCode -ne 0 -and $faultScan.ExitCode -eq 0 -and $faultScan.Json.details.evidence_count -eq 2 -and $faultScan.Json.details.event_count -eq 0) (($fault.Output,$faultScan.Output)-join '; ')
    $retryCombined=Invoke-Utility -Root $combined -UtilityArgs @('-Command','Append','-EventJsonPath',$rp,'-RegisterEvidencePath','combined.bin','-RegisterEvidenceCommitOid',(Get-HeadCommit $combined),'-RegisterEvidenceMediaType','application/octet-stream','-TestUtcNow','2026-03-02T00:00:00.000Z');$combinedScan=Invoke-Utility -Root $combined -UtilityArgs @('-Command','Scan')
    Add-Case 'combined-evidence-registration-before-event-no-dangling-reference' ($retryCombined.ExitCode -eq 0 -and $combinedScan.ExitCode -eq 0 -and $combinedScan.Json.details.event_count -eq 1) $combinedScan.Output

    $evidenceRace=New-Fixture 'concurrent_evidence_reference';Write-Utf8 (Join-Path $evidenceRace 'race-evidence.bin') 'race-evidence-bytes';Invoke-TestGit -Root $evidenceRace -GitArgs @('add','race-evidence.bin')|Out-Null;Invoke-TestGit -Root $evidenceRace -GitArgs @('commit','--quiet','-m','race evidence artifact')|Out-Null;$raceCommit=Get-HeadCommit $evidenceRace;$raceBlob=Get-CommittedBlobRecord -Root $evidenceRace -Commit $raceCommit -Path 'race-evidence.bin';$raceEvidenceId='evd_sha256_'+$raceBlob.RawSha256;$raceRequest=New-IdeaRequest -Root $evidenceRace;$raceRequest.evidence_ids=@($raceEvidenceId);$raceRequestPath=Write-Request -Root $evidenceRace -Request $raceRequest
    # Ready/attempt barrier for BOTH children before the held lock is released
    # (review round 7 finding 1): a fixed post-start sleep lets a slow-starting
    # child first attempt the lock after release and report lock_wait_count=0.
    # Mirrors the synchronized three-writer case above.
    $raceWorkerPath=Join-Path $evidenceRace 'race_worker.ps1'
    Write-Utf8 $raceWorkerPath @'
param($Root,$Ready,$Gate,$Attempt,$Mode,$RequestPath,$EvidencePath,$EvidenceCommit,$EvidenceMediaType,$AppendUtcNow)
$ErrorActionPreference='Stop';$env:EA_LAB_EVENT_TEST_MODE='1';$utf8=New-Object Text.UTF8Encoding($false)
. (Join-Path $Root 'scripts\experiment_event_log.ps1') -RepoRoot $Root
[IO.File]::WriteAllText($Ready,'ready',$utf8)
$deadline=[datetime]::UtcNow.AddSeconds(30);while(-not(Test-Path $Gate)){if([datetime]::UtcNow -gt $deadline){exit 90};Start-Sleep -Milliseconds 20}
[IO.File]::WriteAllText($Attempt,'attempt',$utf8)
$RepoRoot=$Root;$LockTimeoutSeconds=30;$TestFaultPoint='';$RegisterEvidencePath=''
if($Mode -ceq 'register'){$Command='RegisterEvidence';$ArtifactPath=$EvidencePath;$CommitOid=$EvidenceCommit;$MediaType=$EvidenceMediaType}
else{$Command='Append';$EventJsonPath=$RequestPath;$TestUtcNow=$AppendUtcNow}
exit (Invoke-EventUtilityMain)
'@
    $raceGate=Join-Path $evidenceRace 'race-barrier.go';$registerReady=Join-Path $evidenceRace 'race-register.ready';$registerAttempt=Join-Path $evidenceRace 'race-register.attempt';$referenceReady=Join-Path $evidenceRace 'race-reference.ready';$referenceAttempt=Join-Path $evidenceRace 'race-reference.attempt'
    $raceHeld=Enter-EventLock -Root $evidenceRace -TimeoutSeconds 5
    $registerChild=$null;$referenceChild=$null;$raceBarrierOk=$false
    try{
        $registerChild=Start-UtilityProcess -Root $evidenceRace -ScriptPath $raceWorkerPath -UtilityArgs @('-Root',$evidenceRace,'-Ready',$registerReady,'-Gate',$raceGate,'-Attempt',$registerAttempt,'-Mode','register','-EvidencePath','race-evidence.bin','-EvidenceCommit',$raceCommit,'-EvidenceMediaType','application/octet-stream') -OutPath '' -ErrPath ''
        $referenceChild=Start-UtilityProcess -Root $evidenceRace -ScriptPath $raceWorkerPath -UtilityArgs @('-Root',$evidenceRace,'-Ready',$referenceReady,'-Gate',$raceGate,'-Attempt',$referenceAttempt,'-Mode','append','-RequestPath',$raceRequestPath,'-AppendUtcNow','2026-03-03T00:00:00.000Z') -OutPath '' -ErrPath ''
        $deadline=[datetime]::UtcNow.AddSeconds(30);while(-not((Test-Path $registerReady) -and (Test-Path $referenceReady))){if([datetime]::UtcNow -gt $deadline){throw 'evidence-race children did not reach ready barrier'};Start-Sleep -Milliseconds 20}
        Write-Utf8 $raceGate 'go'
        $deadline=[datetime]::UtcNow.AddSeconds(30);while(-not((Test-Path $registerAttempt) -and (Test-Path $referenceAttempt))){if([datetime]::UtcNow -gt $deadline){throw 'evidence-race children did not announce lock attempt'};Start-Sleep -Milliseconds 20}
        Start-Sleep -Milliseconds 600
        $raceBarrierOk=$true
    }finally{
        $raceHeld.Stream.Dispose()
        if(-not $raceBarrierOk){foreach($rc in @($registerChild,$referenceChild)){if($rc -and $rc.Process){try{if(-not $rc.Process.HasExited){$rc.Process.Kill();[void]$rc.Process.WaitForExit(5000)}}catch{};try{$rc.Process.Dispose()}catch{}}}}
    }
    $registerOutcome=Wait-Child $registerChild;$referenceOutcome=Wait-Child $referenceChild;$raceFirstScan=Invoke-Utility -Root $evidenceRace -UtilityArgs @('-Command','Scan');$referenceStatus=$referenceOutcome.Json.status
    if($referenceStatus -eq 'reference_invalid'){$referenceRetry=Invoke-Utility -Root $evidenceRace -UtilityArgs @('-Command','Append','-EventJsonPath',$raceRequestPath,'-TestUtcNow','2026-03-03T00:00:00.000Z')}else{$referenceRetry=$referenceOutcome}
    $raceFinalScan=Invoke-Utility -Root $evidenceRace -UtilityArgs @('-Command','Scan')
    Add-Case 'true-concurrent-evidence-registration-versus-referencing-event-never-dangles' ($registerOutcome.ExitCode -eq 0 -and $registerOutcome.Json.lock_wait_count -gt 0 -and $referenceOutcome.Json.lock_wait_count -gt 0 -and $referenceStatus -in @('appended','reference_invalid') -and $raceFirstScan.ExitCode -eq 0 -and $referenceRetry.ExitCode -eq 0 -and $raceFinalScan.ExitCode -eq 0 -and $raceFinalScan.Json.details.event_count -eq 1) (($registerOutcome.StdOut,$referenceOutcome.StdOut,$raceFinalScan.Output)-join '; ')
    $missing=New-Fixture 'missing_manifest_ref';$rq=New-IdeaRequest -Root $missing;$rq.evidence_ids=@('evd_sha256_'+('f'*64));$rp=Write-Request -Root $missing -Request $rq;$before=Get-FileIdentity (Join-Path $missing 'docs\memory_control\experiment_events\evidence-manifest.jsonl');$mr=Invoke-Utility -Root $missing -UtilityArgs @('-Command','Append','-EventJsonPath',$rp,'-TestUtcNow','2026-03-02T00:00:00.000Z')
    Add-Case 'event-with-missing-manifest-reference-rejected-without-mutation' ($mr.ExitCode -ne 0 -and $mr.Json.status -eq 'reference_invalid' -and (Get-FileIdentity (Join-Path $missing 'docs\memory_control\experiment_events\evidence-manifest.jsonl')) -eq $before) $mr.Output

    # ------------------------------------------------------------------
    # Rotation, UTC time, global IDs, chains, and lifecycle
    # ------------------------------------------------------------------
    $rotation=New-Fixture 'rotation';$exp=Add-CoreChain -Root $rotation;$scan=Invoke-Utility -Root $rotation -UtilityArgs @('-Command','Scan')
    $jan=Join-Path $rotation 'docs\memory_control\experiment_events\events-2026-01.jsonl';$feb=Join-Path $rotation 'docs\memory_control\experiment_events\events-2026-02.jsonl'
    Add-Case 'cross-month-full-core-chain-resolves' ($scan.ExitCode -eq 0 -and (Test-Path $jan) -and (Test-Path $feb) -and $scan.Json.details.event_count -eq 7) $scan.Output
    $schemas=Get-SchemaObjects -Root $rotation;$live=Get-LiveSnapshotBytes -Root $rotation;$snapshot=Invoke-ValidateEventSnapshot -EventFiles $live.EventFiles -ManifestBytes $live.ManifestBytes -EventSchema $schemas.Event -EvidenceSchema $schemas.Evidence -Root $rotation -ResolveReferences
    $sameTs=@($snapshot.Events|Where-Object{$_.Object.timestamp_utc -eq '2026-02-01T00:00:00.000Z'})
    Add-Case 'same-timestamp-chain-order-unambiguous' ($sameTs.Count -eq 2 -and $sameTs[1].Object.prior_event_id -eq $sameTs[0].Object.event_id) "same_timestamp_count=$($sameTs.Count)"
    $back=New-IdeaRequest -Root $rotation;$bp=Write-Request -Root $rotation -Request $back;$before=Get-FileIdentity $feb;$br=Invoke-Utility -Root $rotation -UtilityArgs @('-Command','Append','-EventJsonPath',$bp,'-TestUtcNow','2026-01-15T00:00:00.000Z')
    Add-Case 'clock-rollback-backdate-cannot-reopen-old-month' ($br.ExitCode -ne 0 -and $br.Json.status -eq 'clock_skew' -and (Get-FileIdentity $feb) -eq $before) $br.Output

    $chainBad=New-Fixture 'chain_matrix';$idea=New-IdeaRequest -Root $chainBad;$ip=Write-Request -Root $chainBad -Request $idea;[void](Invoke-Utility -Root $chainBad -UtilityArgs @('-Command','Append','-EventJsonPath',$ip,'-TestUtcNow','2026-04-01T00:00:00.000Z'))
    $base=New-NextRequest -Root $chainBad -Type HYPOTHESIS_REGISTERED -ExperimentId $idea.experiment_id
    $chainCases=@()
    $m=$base|ConvertTo-Json -Depth 20|ConvertFrom-Json;$m.prior_event_id='evt_'+[guid]::NewGuid().ToString();$chainCases+=,@('missing-prior',$m)
    $m=$base|ConvertTo-Json -Depth 20|ConvertFrom-Json;$m.prior_event_sha256='0'*64;$chainCases+=,@('wrong-prior-hash',$m)
    $m=$base|ConvertTo-Json -Depth 20|ConvertFrom-Json;$m.prior_event_id=$m.event_id;$chainCases+=,@('self-link',$m)
    $m=$base|ConvertTo-Json -Depth 20|ConvertFrom-Json;$m.experiment_id='exp_'+[guid]::NewGuid().ToString();$chainCases+=,@('prior-other-experiment',$m)
    $badCount=0
    foreach($case in $chainCases){$path=Write-Request -Root $chainBad -Request $case[1];$rr=Invoke-Utility -Root $chainBad -UtilityArgs @('-Command','Append','-EventJsonPath',$path,'-TestUtcNow','2026-04-01T00:00:01.000Z');if($rr.ExitCode -ne 0){$badCount++}}
    Add-Case 'missing-cross-experiment-wrong-hash-self-prior-rejected' ($badCount -eq 4) "rejected=$badCount/4"
    $runEarly=New-NextRequest -Root $chainBad -Type RUN_STARTED -ExperimentId $idea.experiment_id;$rp=Write-Request -Root $chainBad -Request $runEarly;$rr=Invoke-Utility -Root $chainBad -UtilityArgs @('-Command','Append','-EventJsonPath',$rp,'-TestUtcNow','2026-04-01T00:00:01.000Z')
    Add-Case 'out-of-order-lifecycle-transition-rejected' ($rr.ExitCode -ne 0 -and $rr.Json.status -eq 'stale_prior') $rr.Output

    $validHyp=New-NextRequest -Root $chainBad -Type HYPOTHESIS_REGISTERED -ExperimentId $idea.experiment_id;$validHypPath=Write-Request -Root $chainBad -Request $validHyp;$validHypResult=Invoke-Utility -Root $chainBad -UtilityArgs @('-Command','Append','-EventJsonPath',$validHypPath,'-TestUtcNow','2026-04-01T00:00:02.000Z')
    $duplicateHyp=New-NextRequest -Root $chainBad -Type HYPOTHESIS_REGISTERED -ExperimentId $idea.experiment_id;$duplicateHypPath=Write-Request -Root $chainBad -Request $duplicateHyp;$duplicateHypResult=Invoke-Utility -Root $chainBad -UtilityArgs @('-Command','Append','-EventJsonPath',$duplicateHypPath,'-TestUtcNow','2026-04-01T00:00:03.000Z')
    Add-Case 'duplicate-core-transition-rejected-distinct-from-out-of-order' ($validHypResult.ExitCode -eq 0 -and $duplicateHypResult.ExitCode -ne 0 -and $duplicateHypResult.Json.status -eq 'stale_prior') $duplicateHypResult.Output

    $nonTail=New-NextRequest -Root $chainBad -Type BAR_PREREGISTERED -ExperimentId $idea.experiment_id;$chainSnapshot=Invoke-ValidateEventSnapshot -EventFiles (Get-LiveSnapshotBytes -Root $chainBad).EventFiles -ManifestBytes (Get-LiveSnapshotBytes -Root $chainBad).ManifestBytes -EventSchema (Get-SchemaObjects -Root $chainBad).Event -EvidenceSchema (Get-SchemaObjects -Root $chainBad).Evidence -Root $chainBad -ResolveReferences;$ideaRecord=@($chainSnapshot.Events|Where-Object{$_.Object.event_id -eq $idea.event_id})[0];$nonTail.prior_event_id=$ideaRecord.Object.event_id;$nonTail.prior_event_sha256=$ideaRecord.Sha256;$nonTailPath=Write-Request -Root $chainBad -Request $nonTail;$nonTailResult=Invoke-Utility -Root $chainBad -UtilityArgs @('-Command','Append','-EventJsonPath',$nonTailPath,'-TestUtcNow','2026-04-01T00:00:03.000Z')
    Add-Case 'non-tail-prior-link-rejected' ($nonTailResult.ExitCode -ne 0 -and $nonTailResult.Json.status -eq 'stale_prior' -and $nonTailResult.Output -match 'tail') $nonTailResult.Output

    foreach($linkMode in @('forward','cycle')){
        $linkFx=New-Fixture ("${linkMode}_link");$linkIdea=New-IdeaRequest -Root $linkFx;$linkIdeaPath=Write-Request -Root $linkFx -Request $linkIdea;[void](Invoke-Utility -Root $linkFx -UtilityArgs @('-Command','Append','-EventJsonPath',$linkIdeaPath,'-TestUtcNow','2026-04-02T00:00:00.000Z'))
        $linkSchemas=Get-SchemaObjects -Root $linkFx;$linkLive=Get-LiveSnapshotBytes -Root $linkFx;$futureId='evt_'+[guid]::NewGuid().ToString();$hypRequest=New-NextRequest -Root $linkFx -Type HYPOTHESIS_REGISTERED -ExperimentId $linkIdea.experiment_id;$hypRequest.prior_event_id=$futureId;$hypRequest.prior_event_sha256='0'*64;$hypEvent=Add-TimestampToRequest -Request $hypRequest -Timestamp '2026-04-02T00:00:01.000Z' -EventSchema $linkSchemas.Event;$hypBytes=ConvertTo-CanonicalJsonBytes -Object $hypEvent -Schema $linkSchemas.Event
        $barRequest=New-NextRequest -Root $linkFx -Type BAR_PREREGISTERED -ExperimentId $linkIdea.experiment_id;$barRequest.event_id=$futureId
        if($linkMode -eq 'cycle'){$barRequest.prior_event_id=$hypRequest.event_id;$barRequest.prior_event_sha256=Get-Sha256Hex $hypBytes}
        $barEvent=Add-TimestampToRequest -Request $barRequest -Timestamp '2026-04-02T00:00:02.000Z' -EventSchema $linkSchemas.Event;$barBytes=ConvertTo-CanonicalJsonBytes -Object $barEvent -Schema $linkSchemas.Event;$linkPath=Join-Path $linkFx 'docs\memory_control\experiment_events\events-2026-04.jsonl';$candidate=Join-LineToFileBytes -Existing $linkLive.EventFiles['docs/memory_control/experiment_events/events-2026-04.jsonl'] -Line $hypBytes;$candidate=Join-LineToFileBytes -Existing $candidate -Line $barBytes;Write-Bytes $linkPath $candidate;$linkScan=Invoke-Utility -Root $linkFx -UtilityArgs @('-Command','Scan')
        Add-Case ("${linkMode}-reference-link-rejected") ($linkScan.ExitCode -ne 0 -and $linkScan.Json.status -eq 'integrity_corrupt' -and @($linkScan.Json.details.bad_lines|Where-Object{$_.code -eq 'missing_prior'}).Count -gt 0) $linkScan.Output
    }

    $dupMonth=New-Fixture 'duplicate_cross_month';$idea=New-IdeaRequest -Root $dupMonth;$p=Write-Request -Root $dupMonth -Request $idea;[void](Invoke-Utility -Root $dupMonth -UtilityArgs @('-Command','Append','-EventJsonPath',$p,'-TestUtcNow','2026-01-01T00:00:00.000Z'))
    $line=[IO.File]::ReadAllText((Join-Path $dupMonth 'docs\memory_control\experiment_events\events-2026-01.jsonl'),$Utf8NoBom).TrimEnd("`n");$line2=$line.Replace('2026-01-01T00:00:00.000Z','2026-02-01T00:00:00.000Z');Write-Utf8 (Join-Path $dupMonth 'docs\memory_control\experiment_events\events-2026-02.jsonl') ($line2+"`n");$dupScan=Invoke-Utility -Root $dupMonth -UtilityArgs @('-Command','Scan')
    Add-Case 'duplicate-event-id-across-months-detected' ($dupScan.ExitCode -ne 0 -and $dupScan.Json.status -eq 'integrity_corrupt') $dupScan.Output

    $dupExp=New-Fixture 'duplicate_experiment';$idea=New-IdeaRequest -Root $dupExp;$p=Write-Request -Root $dupExp -Request $idea;[void](Invoke-Utility -Root $dupExp -UtilityArgs @('-Command','Append','-EventJsonPath',$p,'-TestUtcNow','2026-04-01T00:00:00.000Z'));$idea2=New-IdeaRequest -Root $dupExp -ExperimentId $idea.experiment_id;$p2=Write-Request -Root $dupExp -Request $idea2;$dr=Invoke-Utility -Root $dupExp -UtilityArgs @('-Command','Append','-EventJsonPath',$p2,'-TestUtcNow','2026-04-01T00:00:01.000Z')
    Add-Case 'second-idea-with-duplicate-experiment-id-rejected' ($dr.ExitCode -ne 0) $dr.Output

    $boundary=New-Fixture 'boundary_race';$rJan=New-IdeaRequest -Root $boundary;$rFeb=New-IdeaRequest -Root $boundary;$pJan=Write-Request -Root $boundary -Request $rJan;$pFeb=Write-Request -Root $boundary -Request $rFeb;$held=Enter-EventLock -Root $boundary -TimeoutSeconds 5;$b1=Start-UtilityProcess -Root $boundary -UtilityArgs @('-Command','Append','-EventJsonPath',$pJan,'-TestUtcNow','2026-05-31T23:59:59.999Z') -OutPath '' -ErrPath '';$b2=Start-UtilityProcess -Root $boundary -UtilityArgs @('-Command','Append','-EventJsonPath',$pFeb,'-TestUtcNow','2026-06-01T00:00:00.000Z') -OutPath '' -ErrPath '';Start-Sleep -Milliseconds 500;$held.Stream.Dispose();$bo1=Wait-Child $b1;$bo2=Wait-Child $b2;$bs=Invoke-Utility -Root $boundary -UtilityArgs @('-Command','Scan');$boundaryStatuses=@($bo1.Json.status,$bo2.Json.status);$boundarySafe=($bs.ExitCode -eq 0 -and @($boundaryStatuses|Where-Object{$_ -eq 'appended'}).Count -ge 1 -and @($boundaryStatuses|Where-Object{$_ -notin @('appended','clock_skew')}).Count -eq 0)
    Add-Case 'concurrent-utc-month-boundary-never-reopens-or-corrupts' $boundarySafe (($bo1.StdOut,$bo2.StdOut,$bs.Output)-join '; ')

    # ------------------------------------------------------------------
    # Schema, ownership boundary, primitive formats, and serialization
    # ------------------------------------------------------------------
    $schemaFx=New-Fixture 'schema_matrix';$valid=New-IdeaRequest -Root $schemaFx
    $mutations=New-Object System.Collections.Generic.List[object]
    function Add-Mutation([string]$Name,[scriptblock]$Change){$o=$valid|ConvertTo-Json -Depth 20|ConvertFrom-Json;&$Change $o;$mutations.Add([pscustomobject]@{Name=$Name;Object=$o})}
    Add-Mutation 'missing-required' {param($o)$o.PSObject.Properties.Remove('reason_ref')}
    Add-Mutation 'wrong-type' {param($o)$o.schema_version='1'}
    Add-Mutation 'unknown-event' {param($o)$o.event_type='NOT_AN_EVENT'}
    Add-Mutation 'legacy-result-attached' {param($o)$o.event_type='RESULT_ATTACHED'}
    Add-Mutation 'legacy-review-recorded' {param($o)$o.event_type='REVIEW_RECORDED'}
    Add-Mutation 'legacy-decision-signed' {param($o)$o.event_type='DECISION_SIGNED'}
    Add-Mutation 'unknown-field' {param($o)$o|Add-Member NoteProperty arbitrary_metadata 'x'}
    Add-Mutation 'future-version' {param($o)$o.schema_version=2}
    Add-Mutation 'bad-experiment-id' {param($o)$o.experiment_id='EXP_BAD'}
    Add-Mutation 'bad-actor-role' {param($o)$o.role='lead_judge'}
    Add-Mutation 'forbidden-result-field' {param($o)$o|Add-Member NoteProperty result 'copied narrative'}
    Add-Mutation 'forbidden-verdict-field' {param($o)$o|Add-Member NoteProperty verdict 'copied verdict'}
    Add-Mutation 'narrative-reason-alias' {param($o)$o|Add-Member NoteProperty reason 'free prose'}
    Add-Mutation 'duplicate-evidence-id' {param($o)$o.evidence_ids=@('evd_sha256_'+('a'*64),'evd_sha256_'+('a'*64))}
    Add-Mutation 'uppercase-hash' {param($o)$o.artifact_hashes.source='A'*64}
    Add-Mutation 'oversized-string' {param($o)$o.reason_ref='A'*129}
    Add-Mutation 'narrative-reason-ref' {param($o)$o.reason_ref='RESULT-WAS-REJECTED-DUE-TO-LOW-PF'}
    Add-Mutation 'caller-timestamp' {param($o)$o|Add-Member NoteProperty timestamp_utc '2026-04-01T00:00:00.000Z'}
    $schemaRejected=0;$manifestBefore=Get-FileIdentity (Join-Path $schemaFx 'docs\memory_control\experiment_events\evidence-manifest.jsonl')
    foreach($m in $mutations){$path=Write-Request -Root $schemaFx -Request $m.Object;$rr=Invoke-Utility -Root $schemaFx -UtilityArgs @('-Command','Append','-EventJsonPath',$path,'-TestUtcNow','2026-04-01T00:00:00.000Z');if($rr.ExitCode -ne 0 -and $rr.Json.status -eq 'schema_invalid' -and -not(Test-Path (Join-Path $schemaFx 'docs\memory_control\experiment_events\events-2026-04.jsonl'))){$schemaRejected++}}
    Add-Case 'schema-fail-closed-matrix-byte-identical' ($schemaRejected -eq $mutations.Count -and (Get-FileIdentity (Join-Path $schemaFx 'docs\memory_control\experiment_events\evidence-manifest.jsonl')) -eq $manifestBefore) "rejected=$schemaRejected/$($mutations.Count)"

    $exactFx=New-Fixture 'exact_case_and_bounded_tokens';$exactIdea=New-IdeaRequest -Root $exactFx -EventId 'evt_cccccccc-cccc-4ccc-8ccc-cccccccccccc' -ExperimentId 'exp_bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';$exactIdeaPath=Write-Request -Root $exactFx -Request $exactIdea;[void](Invoke-Utility -Root $exactFx -UtilityArgs @('-Command','Append','-EventJsonPath',$exactIdeaPath,'-TestUtcNow','2026-04-01T00:00:00.000Z'));$exactBase=New-NextRequest -Root $exactFx -Type HYPOTHESIS_REGISTERED -ExperimentId $exactIdea.experiment_id -EventId 'evt_aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';$exactLog=Join-Path $exactFx 'docs\memory_control\experiment_events\events-2026-04.jsonl';$exactManifest=Join-Path $exactFx 'docs\memory_control\experiment_events\evidence-manifest.jsonl'
    function Invoke-ExactSchemaProbe([string]$Name,$Request){$beforeLog=Get-FileIdentity $exactLog;$beforeManifest=Get-FileIdentity $exactManifest;$probePath=Write-Request -Root $exactFx -Request $Request -Name ("exact_$Name.json");$outcome=Invoke-Utility -Root $exactFx -UtilityArgs @('-Command','Append','-EventJsonPath',$probePath,'-TestUtcNow','2026-04-01T00:00:01.000Z');return [pscustomobject]@{Pass=($outcome.ExitCode -ne 0 -and $outcome.Json.status -ceq 'schema_invalid' -and (Get-FileIdentity $exactLog) -ceq $beforeLog -and (Get-FileIdentity $exactManifest) -ceq $beforeManifest);Output=$outcome.Output}}
    function Copy-ExactBase {$exactBase|ConvertTo-Json -Depth 20|ConvertFrom-Json}
    $probe=Copy-ExactBase;$probe.event_type='Hypothesis_registered';$out=Invoke-ExactSchemaProbe 'mixed_event_type' $probe;Add-Case 'exact-case-mixed-event-type-schema-invalid-byte-identical' $out.Pass $out.Output
    $uuidPass=0;$uuidDetails=@()
    $probe=Copy-ExactBase;$probe.event_id='evt_Aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';$out=Invoke-ExactSchemaProbe 'uppercase_event_id' $probe;if($out.Pass){$uuidPass++};$uuidDetails+=$out.Output
    $probe=Copy-ExactBase;$probe.experiment_id='exp_Bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';$out=Invoke-ExactSchemaProbe 'uppercase_experiment_id' $probe;if($out.Pass){$uuidPass++};$uuidDetails+=$out.Output
    $probe=Copy-ExactBase;$probe.prior_event_id='evt_Cccccccc-cccc-4ccc-8ccc-cccccccccccc';$out=Invoke-ExactSchemaProbe 'uppercase_prior_event_id' $probe;if($out.Pass){$uuidPass++};$uuidDetails+=$out.Output
    $amendBase=[pscustomobject][ordered]@{schema_version=1;event_id='evt_dddddddd-dddd-4ddd-8ddd-dddddddddddd';experiment_id=$exactIdea.experiment_id;event_type='AMENDMENT_ADDED';actor='codex';role='peer_engineer';prior_event_id=$exactIdea.event_id;prior_event_sha256=(Get-LastEventRecord $exactFx).Sha256;artifact_hashes=[pscustomobject][ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null};trial_family=$null;trial_count=$null;evidence_ids=@();owner_refs=@((New-OwnerRef -Root $exactFx -OwnerType taskboard_order -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_RECOVERY'));reason_code='logical_correction';reason_ref='ORDER-105';target_event_id='evt_Cccccccc-cccc-4ccc-8ccc-cccccccccccc';target_event_sha256=(Get-LastEventRecord $exactFx).Sha256};$out=Invoke-ExactSchemaProbe 'uppercase_target_event_id' $amendBase;if($out.Pass){$uuidPass++};$uuidDetails+=$out.Output
    Add-Case 'exact-case-uppercase-uuid-in-each-event-id-field-schema-invalid-byte-identical' ($uuidPass -eq 4) (($uuidDetails)-join '; ')
    $probe=Copy-ExactBase;$probe.actor='Codex';$out=Invoke-ExactSchemaProbe 'wrong_case_actor' $probe;Add-Case 'exact-case-wrong-case-actor-schema-invalid-byte-identical' $out.Pass $out.Output
    $probe=Copy-ExactBase;$probe.role='Peer_engineer';$out=Invoke-ExactSchemaProbe 'wrong_case_role' $probe;Add-Case 'exact-case-wrong-case-role-schema-invalid-byte-identical' $out.Pass $out.Output
    $probe=Copy-ExactBase;$probe.reason_code='Hypothesis_registered';$out=Invoke-ExactSchemaProbe 'wrong_case_reason_code' $probe;Add-Case 'exact-case-wrong-case-reason-code-schema-invalid-byte-identical' $out.Pass $out.Output
    $probe=Copy-ExactBase;$probe.owner_refs[0].owner_type='Taskboard_order';$out=Invoke-ExactSchemaProbe 'wrong_case_owner_type' $probe;Add-Case 'exact-case-wrong-case-owner-type-schema-invalid-byte-identical' $out.Pass $out.Output
    $probe=Copy-ExactBase;$probe.artifact_hashes.source='A'*64;$out=Invoke-ExactSchemaProbe 'uppercase_hash' $probe;Add-Case 'exact-case-uppercase-hash-hex-schema-invalid-byte-identical' $out.Pass $out.Output
    $probe=Copy-ExactBase;$probe.evidence_ids=@('evd_sha256_'+('A'*64));$out=Invoke-ExactSchemaProbe 'uppercase_evidence_id' $probe;Add-Case 'exact-case-uppercase-evidence-id-schema-invalid-byte-identical' $out.Pass $out.Output
    $probe=Copy-ExactBase;$probe.owner_refs[0].anchor='ANCHOR HYP copied sentence';$out=Invoke-ExactSchemaProbe 'sentence_anchor' $probe;Add-Case 'bounded-anchor-containing-space-or-sentence-schema-invalid-byte-identical' $out.Pass $out.Output
    $probe=Copy-ExactBase;$probe.reason_ref='ORDER-'+('A'*35);$out=Invoke-ExactSchemaProbe 'overlong_reason_ref' $probe;Add-Case 'bounded-overlong-reason-ref-schema-invalid-byte-identical' $out.Pass $out.Output
    $trialPass=0;$trialDetails=@();foreach($badTrial in @('Order105','order 105')){$probe=New-NextRequest -Root $exactFx -Type RUN_STARTED -ExperimentId $exactIdea.experiment_id;$probe.trial_family=$badTrial;$out=Invoke-ExactSchemaProbe ('trial_'+($badTrial-replace ' ','_')) $probe;if($out.Pass){$trialPass++};$trialDetails+=$out.Output};Add-Case 'bounded-trial-family-uppercase-and-space-schema-invalid-byte-identical' ($trialPass -eq 2) ($trialDetails -join '; ')

    $schemaObject=Get-SchemaObjects -Root $schemaFx;$eventWithTs=Add-TimestampToRequest -Request $valid -Timestamp '2026-04-01T00:00:00.000Z' -EventSchema $schemaObject.Event;$primitiveBad=0
    foreach($change in @(
        {param($o)$o.timestamp_utc='2026-04-01T00:00:00Z'},
        {param($o)$o.timestamp_utc='2026-04-01T00:00:00.00Z'},
        {param($o)$o.timestamp_utc='2026-04-01T07:00:00.000+07:00'},
        {param($o)$o.timestamp_utc='2026-02-31T00:00:00.000Z'},
        {param($o)$o.actor='unknown'},
        {param($o)$o.event_id='evt_'+('a'*35)},
        {param($o)$o.owner_refs=@($o.owner_refs[0],$o.owner_refs[0],$o.owner_refs[0],$o.owner_refs[0],$o.owner_refs[0],$o.owner_refs[0],$o.owner_refs[0],$o.owner_refs[0],$o.owner_refs[0])}
    )){$o=$eventWithTs|ConvertTo-Json -Depth 20|ConvertFrom-Json;&$change $o;if(@(Test-EventAgainstSchema -Event $o -Schema $schemaObject.Event).Count -gt 0){$primitiveBad++}}
    Add-Case 'timestamp-id-actor-owner-array-size-primitive-matrix-rejected' ($primitiveBad -eq 7) "rejected=$primitiveBad/7"

    $nullability=0
    foreach($type in @('IDEA_CREATED','HYPOTHESIS_REGISTERED','BAR_PREREGISTERED','RUN_STARTED','RESULT_LINKED','REVIEW_LINKED','DECISION_LINKED','AMENDMENT_ADDED','TOMBSTONE_ADDED')){
        $rule=$schemaObject.Event.'x-ea-lab-rules'.event_rules.PSObject.Properties[$type].Value
        if($rule.artifacts -in @('all_null','source_required','all_required') -and $rule.trial -in @('null','required') -and $rule.prior -in @('null','required')){$nullability++}
    }
    Add-Case 'all-nine-event-types-have-declarative-nullability-prior-trial-rules' ($nullability -eq 9) "rules=$nullability/9"

    $rawFx=New-Fixture 'raw_serialization';$idea=New-IdeaRequest -Root $rawFx;$p=Write-Request -Root $rawFx -Request $idea;[void](Invoke-Utility -Root $rawFx -UtilityArgs @('-Command','Append','-EventJsonPath',$p,'-TestUtcNow','2026-04-01T00:00:00.000Z'));$eventPath=Join-Path $rawFx 'docs\memory_control\experiment_events\events-2026-04.jsonl';$good=[IO.File]::ReadAllBytes($eventPath)
    $rawCases=@{}
    $rawCases['bom']=([byte[]](0xEF,0xBB,0xBF)+$good)
    $rawCases['crlf']=$Utf8NoBom.GetBytes(($Utf8NoBom.GetString($good)).Replace("`n","`r`n"))
    $rawCases['missing-final-lf']=$good[0..($good.Length-2)]
    $rawCases['blank-line']=$Utf8NoBom.GetBytes(($Utf8NoBom.GetString($good))+"`n")
    $rawCases['garbage']=$Utf8NoBom.GetBytes("{garbage}`n")
    $rawCases['non-object']=$Utf8NoBom.GetBytes("[]`n")
    $rawCases['multiple-objects']=$Utf8NoBom.GetBytes("{} {}`n")
    $rawCases['invalid-utf8']=[byte[]](0x7B,0x22,0x78,0x22,0x3A,0x22,0xC3,0x0A)
    $rawRejected=0
    foreach($key in $rawCases.Keys){Write-Bytes $eventPath $rawCases[$key];$rr=Invoke-Utility -Root $rawFx -UtilityArgs @('-Command','Scan');if($rr.ExitCode -ne 0 -and $rr.Json.status -eq 'integrity_corrupt'){$rawRejected++};Write-Bytes $eventPath $good}
    Add-Case 'bom-crlf-missinglf-blank-garbage-nonobject-multiobject-invalidutf8-rejected' ($rawRejected -eq $rawCases.Count) "rejected=$rawRejected/$($rawCases.Count)"

    $diagFx=New-Fixture 'diagnostic';1..3|ForEach-Object{$req=New-IdeaRequest -Root $diagFx;$path=Write-Request -Root $diagFx -Request $req;[void](Invoke-Utility -Root $diagFx -UtilityArgs @('-Command','Append','-EventJsonPath',$path,'-TestUtcNow',("2026-04-01T00:00:0$_.000Z")))};$dp=Join-Path $diagFx 'docs\memory_control\experiment_events\events-2026-04.jsonl';$lines=[IO.File]::ReadAllLines($dp,$Utf8NoBom);$diagnosticPass=0
    foreach($index in @(0,1,2)){$copy=@($lines);$copy[$index]='{garbage';Write-Utf8 $dp (($copy -join "`n")+"`n");$rr=Invoke-Utility -Root $diagFx -UtilityArgs @('-Command','Scan');if($rr.ExitCode -ne 0 -and @($rr.Json.details.bad_lines|Where-Object{$_.line -eq $index+1}).Count -gt 0 -and @($rr.Json.details.good_event_ids).Count -eq 2){$diagnosticPass++}}
    Add-Case 'diagnostic-first-middle-final-corruption-line-numbers-and-good-ids' ($diagnosticPass -eq 3) "passed=$diagnosticPass/3"

    foreach($diagnosticMode in @('truncated-multibyte-utf8','structurally-valid-schema-invalid')){
        $diagExact=New-Fixture ('diagnostic_'+($diagnosticMode-replace '-','_'));1..3|ForEach-Object{$req=New-IdeaRequest -Root $diagExact;$path=Write-Request -Root $diagExact -Request $req;[void](Invoke-Utility -Root $diagExact -UtilityArgs @('-Command','Append','-EventJsonPath',$path,'-TestUtcNow',("2026-04-03T00:00:0$_.000Z")))};$diagPath=Join-Path $diagExact 'docs\memory_control\experiment_events\events-2026-04.jsonl';$originalDiag=[IO.File]::ReadAllBytes($diagPath);$splitDiag=Split-JsonlBytes -Bytes $originalDiag -Path 'diagnostic' -MaxLineBytes 32768;$goodExpected=@((ConvertFrom-StrictJsonBytes -Bytes $splitDiag.Lines[0].Bytes -Context 'line1').event_id,(ConvertFrom-StrictJsonBytes -Bytes $splitDiag.Lines[2].Bytes -Context 'line3').event_id)
        if($diagnosticMode -eq 'truncated-multibyte-utf8'){$badLine=[byte[]](0x7B,0x22,0x78,0x22,0x3A,0x22,0xE2,0x82)}
        else{$badObject=ConvertFrom-StrictJsonBytes -Bytes $splitDiag.Lines[1].Bytes -Context 'line2';$badObject.reason_ref='schema invalid prose value';$badLine=$Utf8NoBom.GetBytes(($badObject|ConvertTo-Json -Compress -Depth 20))}
        $buffer=New-Object Collections.Generic.List[byte];foreach($piece in @($splitDiag.Lines[0].Bytes,$badLine,$splitDiag.Lines[2].Bytes)){foreach($byte in $piece){$buffer.Add($byte)};$buffer.Add(0x0A)};Write-Bytes $diagPath $buffer.ToArray();$diagResult=Invoke-Utility -Root $diagExact -UtilityArgs @('-Command','Scan');$reportedGood=@($diagResult.Json.details.good_event_ids|Sort-Object);$expectedGood=@($goodExpected|Sort-Object);$goodExact=(($reportedGood -join ',') -ceq ($expectedGood -join ','));$lineExact=@($diagResult.Json.details.bad_lines|Where-Object{$_.line -eq 2}).Count -gt 0
        Add-Case ("diagnostic-$diagnosticMode-exact-line-2-and-readable-good-ids") ($diagResult.ExitCode -ne 0 -and $diagResult.Json.status -eq 'integrity_corrupt' -and $lineExact -and $goodExact) $diagResult.Output
    }

    # ------------------------------------------------------------------
    # Committed Git evidence and canonical-owner object resolution
    # ------------------------------------------------------------------
    $refs=New-Fixture 'references';$refFailures=0
    foreach($badPath in @('C:/outside.txt','../artifact.bin','missing.bin','Artifact.bin')){
        $rr=Invoke-Utility -Root $refs -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath',$badPath,'-CommitOid',(Get-HeadCommit $refs),'-MediaType','application/octet-stream')
        if($rr.ExitCode -ne 0 -and $rr.Json.status -eq 'reference_invalid'){$refFailures++}
    }
    $short=(Get-HeadCommit $refs).Substring(0,8);$rr=Invoke-Utility -Root $refs -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','artifact.bin','-CommitOid',$short,'-MediaType','application/octet-stream');if($rr.ExitCode -ne 0){$refFailures++}
    Write-Utf8 (Join-Path $refs 'dirty.bin') 'dirty';$dirty=Invoke-Utility -Root $refs -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','dirty.bin','-CommitOid',(Get-HeadCommit $refs),'-MediaType','application/octet-stream');if($dirty.ExitCode -ne 0){$refFailures++}
    Write-Utf8 (Join-Path $refs 'transient\ignored.bin') 'ignored';$ignored=Invoke-Utility -Root $refs -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','transient/ignored.bin','-CommitOid',(Get-HeadCommit $refs),'-MediaType','application/octet-stream');if($ignored.ExitCode -ne 0){$refFailures++}
    Add-Case 'absolute-traversal-missing-case-abbrev-dirty-ignored-evidence-contract' ($refFailures -eq 7) "checks=$refFailures/7"

    $stagedFx=New-Fixture 'staged_uncommitted_evidence';Write-Utf8 (Join-Path $stagedFx 'staged-only.bin') 'staged but not committed';Invoke-TestGit -Root $stagedFx -GitArgs @('add','staged-only.bin')|Out-Null;$stagedResult=Invoke-Utility -Root $stagedFx -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','staged-only.bin','-CommitOid',(Get-HeadCommit $stagedFx),'-MediaType','application/octet-stream')
    Add-Case 'staged-but-uncommitted-evidence-rejected-as-not-durable' ($stagedResult.ExitCode -ne 0 -and $stagedResult.Json.status -eq 'reference_invalid') $stagedResult.Output

    foreach($missingField in @('commit_oid','blob_oid')){
        $missingOidFx=New-Fixture ('missing_'+$missingField);$missingRecord=(Get-SeedEvidence $missingOidFx)|ConvertTo-Json -Depth 10|ConvertFrom-Json;$missingRecord.PSObject.Properties.Remove($missingField);$missingManifest=Join-Path $missingOidFx 'docs\memory_control\experiment_events\evidence-manifest.jsonl';Write-Utf8 $missingManifest (($missingRecord|ConvertTo-Json -Compress -Depth 10)+"`n");$missingOidScan=Invoke-Utility -Root $missingOidFx -UtilityArgs @('-Command','Scan')
        Add-Case ("manifest-missing-$($missingField-replace '_','-')-rejected") ($missingOidScan.ExitCode -ne 0 -and $missingOidScan.Json.status -eq 'integrity_corrupt' -and @($missingOidScan.Json.details.bad_lines|Where-Object{$_.line -eq 1}).Count -gt 0) $missingOidScan.Output
    }

    $symlinkFx=New-Fixture 'symlink_escape';Write-Utf8 (Join-Path $symlinkFx 'symlink-payload.txt') '../outside-artifact.bin';$symlinkBlob=(Invoke-TestGit -Root $symlinkFx -GitArgs @('hash-object','-w','symlink-payload.txt')).Text;Invoke-TestGit -Root $symlinkFx -GitArgs @('update-index','--add','--cacheinfo',("120000,$symlinkBlob,escape-link"))|Out-Null;Invoke-TestGit -Root $symlinkFx -GitArgs @('commit','--quiet','-m','fixture git symlink')|Out-Null;$symlinkResult=Invoke-Utility -Root $symlinkFx -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','escape-link','-CommitOid',(Get-HeadCommit $symlinkFx),'-MediaType','application/octet-stream')
    Add-Case 'git-symlink-escape-evidence-rejected' ($symlinkResult.ExitCode -ne 0 -and $symlinkResult.Json.status -eq 'reference_invalid' -and $symlinkResult.Output -match 'regular Git blob') $symlinkResult.Output

    $normalizedFx=New-Fixture 'normalized_text_hash';$rawTextPath=Join-Path $normalizedFx 'raw-crlf.txt';Write-Bytes $rawTextPath $Utf8NoBom.GetBytes("alpha`r`nbeta`r`n");$rawObject=(Invoke-TestGit -Root $normalizedFx -GitArgs @('hash-object','-w','--no-filters','raw-crlf.txt')).Text;Invoke-TestGit -Root $normalizedFx -GitArgs @('update-index','--add','--cacheinfo',("100644,$rawObject,raw-crlf.txt"))|Out-Null;Invoke-TestGit -Root $normalizedFx -GitArgs @('commit','--quiet','-m','raw text evidence')|Out-Null;$normalizedCommit=Get-HeadCommit $normalizedFx;$rawBlob=Get-CommittedBlobRecord -Root $normalizedFx -Commit $normalizedCommit -Path 'raw-crlf.txt';$normalizedHash=Get-Sha256Hex $Utf8NoBom.GetBytes("alpha`nbeta`n");$normalizedRecord=[pscustomobject][ordered]@{schema_version=1;evidence_id=('evd_sha256_'+$normalizedHash);path='raw-crlf.txt';commit_oid=$normalizedCommit;blob_oid=$rawBlob.BlobOid;raw_sha256=$normalizedHash;byte_length=[long]$rawBlob.ByteLength;media_type='text/plain'};$normalizedBytes=ConvertTo-CanonicalJsonBytes -Object $normalizedRecord -Schema (Get-SchemaObjects -Root $normalizedFx).Evidence;Write-Bytes (Join-Path $normalizedFx 'docs\memory_control\experiment_events\evidence-manifest.jsonl') (Join-LineToFileBytes -Existing (New-Object byte[] 0) -Line $normalizedBytes);$normalizedScan=Invoke-Utility -Root $normalizedFx -UtilityArgs @('-Command','Scan')
    Add-Case 'hash-from-normalized-text-rejected-against-raw-committed-bytes' ($normalizedScan.ExitCode -ne 0 -and $normalizedScan.Json.status -eq 'integrity_corrupt' -and $normalizedScan.Output -match 'raw_sha256 mismatch') $normalizedScan.Output

    $directory=Invoke-Utility -Root $refs -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','docs','-CommitOid',(Get-HeadCommit $refs),'-MediaType','application/octet-stream')
    $externalRecord=(Get-SeedEvidence $refs)|ConvertTo-Json -Depth 10|ConvertFrom-Json;$externalRecord|Add-Member NoteProperty store_type 'external';$externalErrors=New-Object Collections.Generic.List[string];Test-ValueAgainstDefinition -Value $externalRecord -Definition (Get-SchemaObjects -Root $refs).Evidence -RootSchema (Get-SchemaObjects -Root $refs).Evidence -Path '$' -Errors $externalErrors
    Add-Case 'directory-and-unsupported-external-store-locators-rejected' ($directory.ExitCode -ne 0 -and $externalErrors.Count -gt 0) (($directory.Output,$externalErrors -join '; ')-join '; ')

    $decisionProbe=New-Fixture 'decision_authority';[void](Add-CoreChain -Root $decisionProbe);$schemas=Get-SchemaObjects -Root $decisionProbe;$live=Get-LiveSnapshotBytes -Root $decisionProbe;$snap=Invoke-ValidateEventSnapshot -EventFiles $live.EventFiles -ManifestBytes $live.ManifestBytes -EventSchema $schemas.Event -EvidenceSchema $schemas.Evidence -Root $decisionProbe -ResolveReferences;$decision=$snap.Events[$snap.Events.Count-1].Object|ConvertTo-Json -Depth 20|ConvertFrom-Json;$decision.actor='codex';$decision.role='peer_engineer';$decisionErrors=@(Test-EventAgainstSchema -Event $decision -Schema $schemas.Event)
    Add-Case 'non-lead-actor-cannot-link-canonical-decision' ($decisionErrors.Count -gt 0) ($decisionErrors -join '; ')

    Write-Utf8 (Join-Path $refs 'transient\forced.bin') 'forced';Invoke-TestGit -Root $refs -GitArgs @('add','-f','transient/forced.bin')|Out-Null;Invoke-TestGit -Root $refs -GitArgs @('commit','--quiet','-m','force tracked evidence')|Out-Null;$forceCommit=Get-HeadCommit $refs
    $forced=Invoke-Utility -Root $refs -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','transient/forced.bin','-CommitOid',$forceCommit,'-MediaType','application/octet-stream')
    Remove-Item -LiteralPath (Join-Path $refs 'transient\forced.bin') -Force;$historic=Invoke-Utility -Root $refs -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','transient/forced.bin','-CommitOid',$forceCommit,'-MediaType','application/octet-stream')
    Write-Utf8 (Join-Path $refs 'artifact.bin') 'working tree changed';$changed=Invoke-Utility -Root $refs -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','artifact.bin','-CommitOid',(Invoke-TestGit -Root $refs -GitArgs @('rev-list','--max-parents=0','HEAD')).Text,'-MediaType','application/octet-stream')
    Add-Case 'force-tracked-and-historical-absent-or-changed-worktree-resolve-from-git' ($forced.ExitCode -eq 0 -and $historic.ExitCode -eq 0 -and $historic.Json.status -eq 'already_appended' -and $changed.ExitCode -eq 0) (($forced.Output,$historic.Output,$changed.Output)-join '; ')

    $badOwnerFx=New-Fixture 'owner_failures';$idea=New-IdeaRequest -Root $badOwnerFx;$ownerRejected=0
    foreach($mode in @('anchor-missing','anchor-nonunique','blob-mismatch','sha-mismatch')){
        $o=$idea|ConvertTo-Json -Depth 20|ConvertFrom-Json
        if($mode -eq 'anchor-missing'){$o.owner_refs[0].anchor='NO_SUCH_ANCHOR'}
        if($mode -eq 'anchor-nonunique'){$o.owner_refs[0].anchor='ANCHOR'}
        if($mode -eq 'blob-mismatch'){$o.owner_refs[0].blob_oid='0'*40}
        if($mode -eq 'sha-mismatch'){$o.owner_refs[0].raw_sha256='0'*64}
        $path=Write-Request -Root $badOwnerFx -Request $o;$x=Invoke-Utility -Root $badOwnerFx -UtilityArgs @('-Command','Append','-EventJsonPath',$path,'-TestUtcNow','2026-05-01T00:00:00.000Z');if($x.ExitCode -ne 0 -and $x.Json.status -eq 'reference_invalid'){$ownerRejected++}
    }
    Add-Case 'owner-blob-hash-anchor-missing-or-nonunique-rejected' ($ownerRejected -eq 4) "rejected=$ownerRejected/4"

    $manifestBad=New-Fixture 'manifest_mismatch';$schema=Get-SchemaObjects -Root $manifestBad;$evd=Get-SeedEvidence $manifestBad;$bad=$evd|ConvertTo-Json -Depth 10|ConvertFrom-Json;$bad.byte_length=[long]$bad.byte_length+1;$line=ConvertTo-CanonicalJsonBytes -Object $bad -Schema $schema.Evidence;$mp=Join-Path $manifestBad 'docs\memory_control\experiment_events\evidence-manifest.jsonl';Write-Bytes $mp (Join-LineToFileBytes -Existing ([IO.File]::ReadAllBytes($mp)) -Line $line);$badScan=Invoke-Utility -Root $manifestBad -UtilityArgs @('-Command','Scan')
    Add-Case 'manifest-blob-sha-size-locator-mismatch-fails-closed' ($badScan.ExitCode -ne 0 -and $badScan.Json.status -eq 'integrity_corrupt') $badScan.Output

    foreach($locatorDimension in @('path','commit','blob','sha256','size','media')){
        $locatorFx=New-Fixture ('manifest_locator_'+$locatorDimension);$locatorSchema=Get-SchemaObjects -Root $locatorFx;$locatorRecord=(Get-SeedEvidence $locatorFx)|ConvertTo-Json -Depth 10|ConvertFrom-Json
        switch($locatorDimension){
            'path'{$locatorRecord.path='missing-locator.bin'}
            'commit'{$locatorRecord.commit_oid='0'*40}
            'blob'{$locatorRecord.blob_oid='0'*40}
            'sha256'{$locatorRecord.raw_sha256='0'*64;$locatorRecord.evidence_id='evd_sha256_'+('0'*64)}
            'size'{$locatorRecord.byte_length=[long]$locatorRecord.byte_length+1}
            'media'{$locatorRecord.media_type='application/x-mismatched'}
        }
        $locatorLine=ConvertTo-CanonicalJsonBytes -Object $locatorRecord -Schema $locatorSchema.Evidence;$locatorManifest=Join-Path $locatorFx 'docs\memory_control\experiment_events\evidence-manifest.jsonl';Write-Bytes $locatorManifest (Join-LineToFileBytes -Existing (New-Object byte[] 0) -Line $locatorLine);$locatorScan=Invoke-Utility -Root $locatorFx -UtilityArgs @('-Command','Scan')
        Add-Case ("manifest-locator-$locatorDimension-mismatch-rejected") ($locatorScan.ExitCode -ne 0 -and $locatorScan.Json.status -eq 'integrity_corrupt' -and @($locatorScan.Json.details.bad_lines|Where-Object{$_.line -eq 1}).Count -gt 0) $locatorScan.Output
    }

    $canary=New-Fixture 'canary';[void](Add-CoreChain -Root $canary);$scan=Invoke-Utility -Root $canary -UtilityArgs @('-Command','Scan');$allText=((Get-ChildItem (Join-Path $canary 'docs\memory_control\experiment_events') -Filter 'events-*.jsonl'|Get-Content -Raw)-join '')
    $narrativeAbsent=($allText -notmatch '"(result|verdict|decision|disposition|profit|PF|reason|metadata)"\s*:')
    Add-Case 'canary-seven-core-events-git-object-resolved-no-copied-owner-content' ($scan.ExitCode -eq 0 -and $scan.Json.details.event_count -eq 7 -and $narrativeAbsent) $scan.Output

    # Logical amendment/tombstone target rules.
    $tomb=New-Fixture 'tombstones';$exp=Add-CoreChain -Root $tomb;$snapSchemas=Get-SchemaObjects -Root $tomb;$live=Get-LiveSnapshotBytes -Root $tomb;$snap=Invoke-ValidateEventSnapshot -EventFiles $live.EventFiles -ManifestBytes $live.ManifestBytes -EventSchema $snapSchemas.Event -EvidenceSchema $snapSchemas.Evidence -Root $tomb -ResolveReferences;$target=$snap.Events[0];$prior=$snap.Events[$snap.Events.Count-1]
    $tombReq=[pscustomobject][ordered]@{schema_version=1;event_id=('evt_'+[guid]::NewGuid().ToString());experiment_id=$exp;event_type='TOMBSTONE_ADDED';actor='codex';role='peer_engineer';prior_event_id=$prior.Object.event_id;prior_event_sha256=$prior.Sha256;artifact_hashes=[pscustomobject][ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null};trial_family=$null;trial_count=$null;evidence_ids=@();owner_refs=@((New-OwnerRef -Root $tomb -OwnerType taskboard_order -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_RECOVERY'));reason_code='invalidated_occurrence';reason_ref='ORDER-105';target_event_id=$target.Object.event_id;target_event_sha256=$target.Sha256}
    $tp=Write-Request -Root $tomb -Request $tombReq;$ok=Invoke-Utility -Root $tomb -UtilityArgs @('-Command','Append','-EventJsonPath',$tp,'-TestUtcNow','2026-02-01T00:00:01.000Z')
    $last=Get-LastEventRecord $tomb;$double=$tombReq|ConvertTo-Json -Depth 20|ConvertFrom-Json;$double.event_id='evt_'+[guid]::NewGuid().ToString();$double.prior_event_id=$last.Object.event_id;$double.prior_event_sha256=$last.Sha256;$dp=Write-Request -Root $tomb -Request $double;$bad=Invoke-Utility -Root $tomb -UtilityArgs @('-Command','Append','-EventJsonPath',$dp,'-TestUtcNow','2026-02-01T00:00:02.000Z')
    Add-Case 'tombstone-valid-target-and-double-tombstone-rejected' ($ok.ExitCode -eq 0 -and $bad.ExitCode -ne 0) (($ok.Output,$bad.Output)-join '; ')

    $tail=Get-LastEventRecord $tomb
    $amend=[pscustomobject][ordered]@{schema_version=1;event_id=('evt_'+[guid]::NewGuid().ToString());experiment_id=$exp;event_type='AMENDMENT_ADDED';actor='codex';role='peer_engineer';prior_event_id=$tail.Object.event_id;prior_event_sha256=$tail.Sha256;artifact_hashes=[pscustomobject][ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null};trial_family=$null;trial_count=$null;evidence_ids=@();owner_refs=@((New-OwnerRef -Root $tomb -OwnerType taskboard_order -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_RECOVERY'));reason_code='logical_correction';reason_ref='ORDER-105-AMENDMENT';target_event_id=$target.Object.event_id;target_event_sha256=$target.Sha256}
    $ap=Write-Request -Root $tomb -Request $amend;$amendOk=Invoke-Utility -Root $tomb -UtilityArgs @('-Command','Append','-EventJsonPath',$ap,'-TestUtcNow','2026-02-01T00:00:03.000Z')
    $invalidTargets=0
    foreach($mode in @('unknown','wrong-hash','self','unauthorized-recovery')){
        $tail=Get-LastEventRecord $tomb;$probe=$amend|ConvertTo-Json -Depth 20|ConvertFrom-Json;$probe.event_id='evt_'+[guid]::NewGuid().ToString();$probe.prior_event_id=$tail.Object.event_id;$probe.prior_event_sha256=$tail.Sha256
        if($mode -eq 'unknown'){$probe.target_event_id='evt_'+[guid]::NewGuid().ToString()}
        if($mode -eq 'wrong-hash'){$probe.target_event_sha256='0'*64}
        if($mode -eq 'self'){$probe.target_event_id=$probe.event_id}
        if($mode -eq 'unauthorized-recovery'){$probe.reason_code='physical_recovery'}
        $pp=Write-Request -Root $tomb -Request $probe;$pr=Invoke-Utility -Root $tomb -UtilityArgs @('-Command','Append','-EventJsonPath',$pp,'-TestUtcNow','2026-02-01T00:00:04.000Z');if($pr.ExitCode -ne 0){$invalidTargets++}
    }
    Add-Case 'amendment-target-unknown-wrong-hash-self-and-unauthorized-recovery-rejected' ($amendOk.ExitCode -eq 0 -and $invalidTargets -eq 4) "rejected=$invalidTargets/4"

    $actorRoles=$snapSchemas.Event.'x-ea-lab-rules'.actor_roles.PSObject.Properties;$logicalMatrixChecks=0;$logicalMatrixPass=0;$physicalMatrixChecks=0;$physicalMatrixPass=0
    foreach($actorRole in $actorRoles){
        $actorName=[string]$actorRole.Name;$roleName=[string]@($actorRole.Value)[0]
        foreach($template in @($amend,$tombReq)){
            $logical=$template|ConvertTo-Json -Depth 20|ConvertFrom-Json;$logical.event_id='evt_'+[guid]::NewGuid().ToString();$logical.actor=$actorName;$logical.role=$roleName;$logicalEvent=Add-TimestampToRequest -Request $logical -Timestamp '2026-02-01T00:00:05.000Z' -EventSchema $snapSchemas.Event;$logicalMatrixChecks++;if(@(Test-EventAgainstSchema -Event $logicalEvent -Schema $snapSchemas.Event).Count -eq 0){$logicalMatrixPass++}
            $physical=$logical|ConvertTo-Json -Depth 20|ConvertFrom-Json;$physical.reason_code='physical_recovery';$physical|Add-Member NoteProperty recovery_target_month '2026-02';$physicalEvent=Add-TimestampToRequest -Request $physical -Timestamp '2026-02-01T00:00:05.000Z' -EventSchema $snapSchemas.Event;$physicalErrors=@(Test-EventAgainstSchema -Event $physicalEvent -Schema $snapSchemas.Event);$expectedPhysical=($actorName -in @('user','claude'));$physicalMatrixChecks++;if(($expectedPhysical -and $physicalErrors.Count -eq 0) -or (-not $expectedPhysical -and $physicalErrors.Count -gt 0)){$physicalMatrixPass++}
        }
    }
    Add-Case 'logical-amendment-tombstone-authorization-all-declared-actor-role-pairs' ($logicalMatrixPass -eq $logicalMatrixChecks -and $logicalMatrixChecks -eq 16) "passed=$logicalMatrixPass/$logicalMatrixChecks"
    Add-Case 'physical-recovery-amendment-tombstone-authorization-owner-lead-only-matrix' ($physicalMatrixPass -eq $physicalMatrixChecks -and $physicalMatrixChecks -eq 16) "passed=$physicalMatrixPass/$physicalMatrixChecks"

    $tombLive=Get-LiveSnapshotBytes -Root $tomb;$tombSnapshot=Invoke-ValidateEventSnapshot -EventFiles $tombLive.EventFiles -ManifestBytes $tombLive.ManifestBytes -EventSchema $snapSchemas.Event -EvidenceSchema $snapSchemas.Evidence -Root $tomb -ResolveReferences
    $nullabilityChecks=0;$nullabilityRejected=0
    foreach($record in $tombSnapshot.Events){
        $rule=$snapSchemas.Event.'x-ea-lab-rules'.event_rules.PSObject.Properties[[string]$record.Object.event_type].Value
        $mutated=$record.Object|ConvertTo-Json -Depth 20|ConvertFrom-Json
        if($rule.artifacts -eq 'all_null'){$mutated.artifact_hashes.ea='a'*64}
        elseif($rule.artifacts -eq 'source_required'){$mutated.artifact_hashes.source=$null}
        else{$mutated.artifact_hashes.tester=$null}
        $nullabilityChecks++;if(@(Test-EventAgainstSchema -Event $mutated -Schema $snapSchemas.Event).Count -gt 0){$nullabilityRejected++}
        $mutated=$record.Object|ConvertTo-Json -Depth 20|ConvertFrom-Json
        if($rule.trial -eq 'null'){$mutated.trial_family='forbidden'}else{$mutated.trial_count=$null}
        $nullabilityChecks++;if(@(Test-EventAgainstSchema -Event $mutated -Schema $snapSchemas.Event).Count -gt 0){$nullabilityRejected++}
    }
    Add-Case 'all-nine-event-types-artifact-and-trial-nullability-mutated' ($tombSnapshot.Events.Count -eq 9 -and $nullabilityRejected -eq $nullabilityChecks) "events=$($tombSnapshot.Events.Count) rejected=$nullabilityRejected/$nullabilityChecks"

    # ------------------------------------------------------------------
    # Staged Git enforcement and real commit hook path
    # ------------------------------------------------------------------
    $hookBase=New-Fixture 'hook_base';[void](Add-CoreChain -Root $hookBase);Invoke-TestGit -Root $hookBase -GitArgs @('add','docs/memory_control/experiment_events')|Out-Null;$commitOut=Invoke-TestGit -Root $hookBase -GitArgs @('commit','-m','valid utility chain') -AllowFailure
    Add-Case 'real-hook-valid-utility-produced-chain-commit-passes' ($commitOut.ExitCode -eq 0) $commitOut.Text
    function Clone-HookBase([string]$Name){$r=Join-Path $Scratch $Name;Invoke-TestGit -Root $Scratch -GitArgs @('clone','--quiet','--no-hardlinks',$hookBase,$r)|Out-Null;Add-HookPrereqs -Root $r;Invoke-TestGit -Root $r -GitArgs @('config','user.name','Hook Test')|Out-Null;Invoke-TestGit -Root $r -GitArgs @('config','user.email','hook@example.invalid')|Out-Null;Invoke-TestGit -Root $r -GitArgs @('config','core.hooksPath','.githooks')|Out-Null;return $r}
    $closed=Clone-HookBase 'hook_closed_edit';$p=Join-Path $closed 'docs\memory_control\experiment_events\events-2026-01.jsonl';$text=[IO.File]::ReadAllText($p,$Utf8NoBom).Replace('experiment_initiated','experiment_initiated ');Write-Utf8 $p $text;Invoke-TestGit -Root $closed -GitArgs @('add',$p)|Out-Null;$c=Invoke-TestGit -Root $closed -GitArgs @('commit','-m','edit closed month') -AllowFailure
    Add-Case 'real-hook-blocks-hand-edited-closed-month' ($c.ExitCode -ne 0 -and $c.Text -match 'closed month|invalid') $c.Text
    $deleted=Clone-HookBase 'hook_delete';Remove-Item (Join-Path $deleted 'docs\memory_control\experiment_events\events-2026-01.jsonl');Invoke-TestGit -Root $deleted -GitArgs @('add','--update','--','docs/memory_control/experiment_events/events-2026-01.jsonl')|Out-Null;$c=Invoke-TestGit -Root $deleted -GitArgs @('commit','-m','delete month') -AllowFailure
    Add-Case 'real-hook-blocks-deleted-month' ($c.ExitCode -ne 0 -and $c.Text -match 'deleted|renamed') $c.Text
    $renamed=Clone-HookBase 'hook_rename';Invoke-TestGit -Root $renamed -GitArgs @('mv','docs/memory_control/experiment_events/events-2026-01.jsonl','docs/memory_control/experiment_events/events-2026-01-renamed.jsonl')|Out-Null;$c=Invoke-TestGit -Root $renamed -GitArgs @('commit','-m','rename month') -AllowFailure
    Add-Case 'real-hook-blocks-renamed-month' ($c.ExitCode -ne 0) $c.Text
    $crlf=Clone-HookBase 'hook_crlf';$p=Join-Path $crlf 'docs\memory_control\experiment_events\events-2026-02.jsonl';$bytes=[IO.File]::ReadAllBytes($p);$txt=$Utf8NoBom.GetString($bytes).Replace("`n","`r`n");[IO.File]::WriteAllText($p,$txt,$Utf8NoBom);Invoke-TestGit -Root $crlf -GitArgs @('add','--renormalize','docs/memory_control/experiment_events/events-2026-02.jsonl')|Out-Null
    # .gitattributes normalizes CRLF on add, so stage the raw CRLF blob explicitly.
    $rawBlob=(Invoke-TestGit -Root $crlf -GitArgs @('hash-object','-w','--no-filters',$p)).Text;Invoke-TestGit -Root $crlf -GitArgs @('update-index','--cacheinfo',"100644,$rawBlob,docs/memory_control/experiment_events/events-2026-02.jsonl")|Out-Null;$c=Invoke-TestGit -Root $crlf -GitArgs @('commit','-m','crlf drift') -AllowFailure
    Add-Case 'real-hook-blocks-crlf-only-drift' ($c.ExitCode -ne 0 -and $c.Text -match 'CR|crlf|invalid') $c.Text
    $ordinary=Clone-HookBase 'hook_ordinary';Write-Utf8 (Join-Path $ordinary 'ordinary.txt') 'ordinary';Invoke-TestGit -Root $ordinary -GitArgs @('add','ordinary.txt')|Out-Null;$c=Invoke-TestGit -Root $ordinary -GitArgs @('commit','-m','ordinary') -AllowFailure
    Add-Case 'event-checker-ordinary-commit-fast-pass' ($c.ExitCode -eq 0 -and $c.Text -notmatch '\[experiment-events\]') $c.Text

    $validAppend=Clone-HookBase 'hook_valid_append';$idea=New-IdeaRequest -Root $validAppend;$p=Write-Request -Root $validAppend -Request $idea;$a=Invoke-Utility -Root $validAppend -UtilityArgs @('-Command','Append','-EventJsonPath',$p,'-TestUtcNow','2026-02-02T00:00:00.000Z');Invoke-TestGit -Root $validAppend -GitArgs @('add','docs/memory_control/experiment_events/events-2026-02.jsonl')|Out-Null;$c=Invoke-TestGit -Root $validAppend -GitArgs @('commit','-m','valid prefix append') -AllowFailure
    Add-Case 'real-hook-valid-latest-month-prefix-append-passes' ($a.ExitCode -eq 0 -and $c.ExitCode -eq 0 -and $c.Text -match 'PASS') $c.Text

    $truncate=Clone-HookBase 'hook_truncate';$p=Join-Path $truncate 'docs\memory_control\experiment_events\events-2026-02.jsonl';$ls=[IO.File]::ReadAllLines($p,$Utf8NoBom);Write-Utf8 $p (($ls[0..($ls.Count-2)]-join "`n")+"`n");Invoke-TestGit -Root $truncate -GitArgs @('add',$p)|Out-Null;$c=Invoke-TestGit -Root $truncate -GitArgs @('commit','-m','truncate month') -AllowFailure
    Add-Case 'real-hook-blocks-truncated-month' ($c.ExitCode -ne 0) $c.Text
    $reorder=Clone-HookBase 'hook_reorder';$p=Join-Path $reorder 'docs\memory_control\experiment_events\events-2026-02.jsonl';$ls=[IO.File]::ReadAllLines($p,$Utf8NoBom);$tmp=$ls[0];$ls[0]=$ls[1];$ls[1]=$tmp;Write-Utf8 $p (($ls-join "`n")+"`n");Invoke-TestGit -Root $reorder -GitArgs @('add',$p)|Out-Null;$c=Invoke-TestGit -Root $reorder -GitArgs @('commit','-m','reorder month') -AllowFailure
    Add-Case 'real-hook-blocks-reordered-month' ($c.ExitCode -ne 0) $c.Text
    $schemaOnly=Clone-HookBase 'hook_schema_change';$p=Join-Path $schemaOnly 'docs\memory_control\experiment_events\schema\event-v1.schema.json';$txt=[IO.File]::ReadAllText($p,$Utf8NoBom).Replace('EA_LAB experiment event v1','EA_LAB modified event v1');Write-Utf8 $p $txt;Invoke-TestGit -Root $schemaOnly -GitArgs @('add',$p)|Out-Null;$c=Invoke-TestGit -Root $schemaOnly -GitArgs @('commit','-m','modify v1 schema') -AllowFailure
    Add-Case 'real-hook-blocks-established-schema-only-change' ($c.ExitCode -ne 0 -and $c.Text -match 'schema.*immutable') $c.Text
    $manifestOnly=Clone-HookBase 'hook_manifest_invalid';$p=Join-Path $manifestOnly 'docs\memory_control\experiment_events\evidence-manifest.jsonl';Write-Utf8 $p (([IO.File]::ReadAllText($p,$Utf8NoBom))+"{bad}`n");Invoke-TestGit -Root $manifestOnly -GitArgs @('add',$p)|Out-Null;$c=Invoke-TestGit -Root $manifestOnly -GitArgs @('commit','-m','invalid manifest') -AllowFailure
    Add-Case 'real-hook-blocks-manifest-only-inconsistent-transaction' ($c.ExitCode -ne 0) $c.Text

    # ------------------------------------------------------------------
    # Disable/re-enable and authorized physical recovery transaction
    # ------------------------------------------------------------------
    $recovery=Clone-HookBase 'recovery';$canonicalBefore=@{};foreach($cp in @('AGENT_TASKBOARD.md','ARCHIVE_TASKBOARD_2026-07A.md','PROJECT_STATE.md','EA_SCORECARD_AND_REGISTRY.md','portfolio/DEPLOYMENTS.csv')){$canonicalBefore[$cp]=Get-FileIdentity (Join-Path $recovery ($cp-replace '/','\'))};$cleanJan=[IO.File]::ReadAllBytes((Join-Path $recovery 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$cleanFeb=[IO.File]::ReadAllBytes((Join-Path $recovery 'docs\memory_control\experiment_events\events-2026-02.jsonl'))
    $corrupt=New-Object byte[] ($cleanJan.Length+9);[array]::Copy($cleanJan,$corrupt,$cleanJan.Length);[array]::Copy($Utf8NoBom.GetBytes("{garbage`n"),0,$corrupt,$cleanJan.Length,9);Write-Bytes (Join-Path $recovery 'quarantine.bin') $corrupt;Write-Bytes (Join-Path $recovery 'docs\memory_control\experiment_events\events-2026-01.jsonl') $corrupt
    Invoke-TestGit -Root $recovery -GitArgs @('config','core.hooksPath','.no-hooks')|Out-Null;Invoke-TestGit -Root $recovery -GitArgs @('add','quarantine.bin','docs/memory_control/experiment_events/events-2026-01.jsonl')|Out-Null;Invoke-TestGit -Root $recovery -GitArgs @('commit','--quiet','-m','fixture corrupt closed month')|Out-Null;Invoke-TestGit -Root $recovery -GitArgs @('config','core.hooksPath','.githooks')|Out-Null
    $corruptCommit=Get-HeadCommit $recovery;$qreg=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','quarantine.bin','-CommitOid',$corruptCommit,'-MediaType','application/octet-stream');$qid=$qreg.Json.details.evidence_id
    $auth=New-OwnerRef -Root $recovery -OwnerType recovery_authorization -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_RECOVERY';$authPath=Join-Path $recovery 'authorization.json';Write-Utf8 $authPath ($auth|ConvertTo-Json -Compress -Depth 10)
    $unauth=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Disable','-Actor','codex','-Role','peer_engineer','-AuthorizationRefJsonPath',$authPath)
    $disable=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Disable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath)
    $newIdea=Write-Request -Root $recovery -Request (New-IdeaRequest -Root $recovery);$blocked=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Append','-EventJsonPath',$newIdea,'-TestUtcNow','2026-02-02T00:00:00.000Z')
    Add-Case 'disable-authority-and-new-writer-disabled-without-mutation' ($unauth.ExitCode -ne 0 -and $disable.ExitCode -eq 0 -and $blocked.Json.status -eq 'disabled') (($unauth.Output,$disable.Output,$blocked.Output)-join '; ')

    $schemas=Get-SchemaObjects -Root $recovery;$cleanMap=@{'docs/memory_control/experiment_events/events-2026-01.jsonl'=$cleanJan;'docs/memory_control/experiment_events/events-2026-02.jsonl'=$cleanFeb};$manifest=[IO.File]::ReadAllBytes((Join-Path $recovery 'docs\memory_control\experiment_events\evidence-manifest.jsonl'));$cleanSnap=Invoke-ValidateEventSnapshot -EventFiles $cleanMap -ManifestBytes $manifest -EventSchema $schemas.Event -EvidenceSchema $schemas.Evidence -Root $recovery -ResolveReferences;$target=$cleanSnap.Events[0];$tail=$cleanSnap.Events[$cleanSnap.Events.Count-1]
    $recoverReq=[pscustomobject][ordered]@{schema_version=1;event_id=('evt_'+[guid]::NewGuid().ToString());experiment_id=$tail.Object.experiment_id;event_type='AMENDMENT_ADDED';actor='claude';role='lead_judge';prior_event_id=$tail.Object.event_id;prior_event_sha256=$tail.Sha256;artifact_hashes=[pscustomobject][ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null};trial_family=$null;trial_count=$null;evidence_ids=@($qid);owner_refs=@($auth);reason_code='physical_recovery';reason_ref='ORDER-105-RECOVERY';target_event_id=$target.Object.event_id;target_event_sha256=$target.Sha256;recovery_target_month='2026-01'}
    $recoverReqPath=Write-Request -Root $recovery -Request $recoverReq;$cleanPath=Join-Path $recovery 'clean-jan.jsonl';Write-Bytes $cleanPath $cleanJan

    # A recovery transaction may rebuild one damaged target month only.  Make
    # an otherwise-valid candidate that also rewrites February's last event;
    # the staged checker must reject the two-month rewrite explicitly.
    $twoTouch=Join-Path $Scratch 'recovery_two_months';Invoke-TestGit -Root $Scratch -GitArgs @('clone','--quiet','--no-hardlinks',$recovery,$twoTouch)|Out-Null;Add-HookPrereqs -Root $twoTouch;Invoke-TestGit -Root $twoTouch -GitArgs @('config','user.name','Recovery Two Touch')|Out-Null;Invoke-TestGit -Root $twoTouch -GitArgs @('config','user.email','recovery-two@example.invalid')|Out-Null;Invoke-TestGit -Root $twoTouch -GitArgs @('config','core.hooksPath','.githooks')|Out-Null;$twoQreg=Invoke-Utility -Root $twoTouch -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','quarantine.bin','-CommitOid',(Get-HeadCommit $twoTouch),'-MediaType','application/octet-stream');$twoQid=$twoQreg.Json.details.evidence_id;$twoSchemas=Get-SchemaObjects -Root $twoTouch;$twoAuth=New-OwnerRef -Root $twoTouch -OwnerType recovery_authorization -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_RECOVERY';$febSplit=Split-JsonlBytes -Bytes $cleanFeb -Path 'clean-feb' -MaxLineBytes 32768;$changedTail=ConvertFrom-StrictJsonBytes -Bytes $febSplit.Lines[$febSplit.Lines.Count-1].Bytes -Context 'february tail';$changedTail.timestamp_utc='2026-02-01T00:00:00.005Z';$changedTailBytes=ConvertTo-CanonicalJsonBytes -Object $changedTail -Schema $twoSchemas.Event;$changedFeb=New-Object Collections.Generic.List[byte];foreach($lineRecord in @($febSplit.Lines|Select-Object -First ($febSplit.Lines.Count-1))){foreach($byte in $lineRecord.Bytes){$changedFeb.Add($byte)};$changedFeb.Add(0x0A)};foreach($byte in $changedTailBytes){$changedFeb.Add($byte)};$changedFeb.Add(0x0A);$twoRecovery=[pscustomobject][ordered]@{schema_version=1;event_id=('evt_'+[guid]::NewGuid().ToString());experiment_id=$changedTail.experiment_id;event_type='AMENDMENT_ADDED';actor='claude';role='lead_judge';prior_event_id=$changedTail.event_id;prior_event_sha256=(Get-Sha256Hex $changedTailBytes);artifact_hashes=[pscustomobject][ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null};trial_family=$null;trial_count=$null;evidence_ids=@($twoQid);owner_refs=@($twoAuth);reason_code='physical_recovery';reason_ref='ORDER-105-RECOVERY';target_event_id=$target.Object.event_id;target_event_sha256=$target.Sha256;recovery_target_month='2026-01'};$twoRecoveryEvent=Add-TimestampToRequest -Request $twoRecovery -Timestamp '2026-02-02T00:00:00.000Z' -EventSchema $twoSchemas.Event;$twoRecoveryBytes=ConvertTo-CanonicalJsonBytes -Object $twoRecoveryEvent -Schema $twoSchemas.Event;$changedFebWithRecovery=Join-LineToFileBytes -Existing $changedFeb.ToArray() -Line $twoRecoveryBytes;Write-Bytes (Join-Path $twoTouch 'docs\memory_control\experiment_events\events-2026-01.jsonl') $cleanJan;Write-Bytes (Join-Path $twoTouch 'docs\memory_control\experiment_events\events-2026-02.jsonl') $changedFebWithRecovery;$twoTouchCheck=Stage-And-Check -Root $twoTouch -Paths @('docs/memory_control/experiment_events/evidence-manifest.jsonl','docs/memory_control/experiment_events/events-2026-01.jsonl','docs/memory_control/experiment_events/events-2026-02.jsonl')
    Add-Case 'staged-recovery-rewriting-two-month-files-rejected' ($twoTouchCheck.ExitCode -ne 0 -and $twoTouchCheck.Output -match 'more than one monthly file') $twoTouchCheck.Output
    $badAuth=$auth|ConvertTo-Json -Depth 10|ConvertFrom-Json;$badAuth.raw_sha256='0'*64;$badAuthPath=Join-Path $recovery 'bad-auth.json';Write-Utf8 $badAuthPath ($badAuth|ConvertTo-Json -Compress -Depth 10);$unauthorizedRecovery=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$badAuthPath,'-QuarantineEvidenceId',$qid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$cleanPath,'-EventJsonPath',$recoverReqPath,'-TestUtcNow','2026-02-02T00:00:00.000Z')
    Add-Case 'closed-month-physical-recovery-requires-valid-authorization-and-quarantine-reference' ($unauthorizedRecovery.ExitCode -ne 0 -and $unauthorizedRecovery.Json.status -eq 'reference_invalid') $unauthorizedRecovery.Output
    $enableBeforeProbe=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Enable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath)
    $withoutDisable=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath,'-QuarantineEvidenceId',$qid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$cleanPath,'-EventJsonPath',$recoverReqPath,'-TestUtcNow','2026-02-02T00:00:00.000Z')
    $disableAgain=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Disable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath)
    $missingQuarantine=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath,'-QuarantineEvidenceId','evd_sha256_'+('0'*64),'-RecoveryMonth','2026-01','-RecoveryFilePath',$cleanPath,'-EventJsonPath',$recoverReqPath,'-TestUtcNow','2026-02-02T00:00:00.000Z')
    $unrelatedEvidence=(Get-SeedEvidence $recovery).evidence_id
    $wrongQuarantine=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath,'-QuarantineEvidenceId',$unrelatedEvidence,'-RecoveryMonth','2026-01','-RecoveryFilePath',$cleanPath,'-EventJsonPath',$recoverReqPath,'-TestUtcNow','2026-02-02T00:00:00.000Z')
    Add-Case 'physical-recovery-requires-disabled-state-and-exact-corrupt-byte-evidence' ($enableBeforeProbe.ExitCode -eq 0 -and $withoutDisable.ExitCode -ne 0 -and $disableAgain.ExitCode -eq 0 -and $missingQuarantine.ExitCode -ne 0 -and $wrongQuarantine.ExitCode -ne 0) (($withoutDisable.Output,$missingQuarantine.Output,$wrongQuarantine.Output)-join '; ')
    $omittedJanuaryPath=Join-Path $recovery 'clean-jan-omits-valid-event.jsonl';Write-Bytes $omittedJanuaryPath ([byte[]]@());$omittedJanuary=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath,'-QuarantineEvidenceId',$qid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$omittedJanuaryPath,'-EventJsonPath',$recoverReqPath,'-TestUtcNow','2026-02-02T00:00:00.000Z')
    Add-Case 'closed-january-recovery-omitting-independently-valid-event-rejected' ($omittedJanuary.ExitCode -ne 0 -and $omittedJanuary.Json.status -eq 'reference_invalid') $omittedJanuary.Output
    # Review round 2 finding 2: a two-file recovery installs the recovery record
    # (event month) first, then rewrites the target month. A fault after the record
    # is durable but before the target rewrite must leave a resumable state, and a
    # re-run must COMPLETE it (not duplicate the record or dead-end). Uses a fresh
    # clone of the still-corrupt fixture so the live $recovery is untouched.
    $resumeFx=Join-Path $Scratch 'recovery_resume';Invoke-TestGit -Root $Scratch -GitArgs @('clone','--quiet','--no-hardlinks',$recovery,$resumeFx)|Out-Null;Add-HookPrereqs -Root $resumeFx;Invoke-TestGit -Root $resumeFx -GitArgs @('config','user.name','Recovery Resume')|Out-Null;Invoke-TestGit -Root $resumeFx -GitArgs @('config','user.email','resume@example.invalid')|Out-Null;Invoke-TestGit -Root $resumeFx -GitArgs @('config','core.hooksPath','.githooks')|Out-Null
    $resumeQreg=Invoke-Utility -Root $resumeFx -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','quarantine.bin','-CommitOid',(Get-HeadCommit $resumeFx),'-MediaType','application/octet-stream');$resumeQid=$resumeQreg.Json.details.evidence_id
    $resumeAuth=New-OwnerRef -Root $resumeFx -OwnerType recovery_authorization -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_RECOVERY';$resumeAuthPath=Join-Path $resumeFx 'auth.json';Write-Utf8 $resumeAuthPath ($resumeAuth|ConvertTo-Json -Compress -Depth 10)
    $resumeSchemas=Get-SchemaObjects -Root $resumeFx;$resumeCleanMap=@{'docs/memory_control/experiment_events/events-2026-01.jsonl'=$cleanJan;'docs/memory_control/experiment_events/events-2026-02.jsonl'=$cleanFeb};$resumeManifest=[IO.File]::ReadAllBytes((Join-Path $resumeFx 'docs\memory_control\experiment_events\evidence-manifest.jsonl'));$resumeSnap=Invoke-ValidateEventSnapshot -EventFiles $resumeCleanMap -ManifestBytes $resumeManifest -EventSchema $resumeSchemas.Event -EvidenceSchema $resumeSchemas.Evidence -Root $resumeFx -ResolveReferences;$resumeTarget=$resumeSnap.Events[0];$resumeTail=$resumeSnap.Events[$resumeSnap.Events.Count-1]
    $resumeReq=[pscustomobject][ordered]@{schema_version=1;event_id=('evt_'+[guid]::NewGuid().ToString());experiment_id=$resumeTail.Object.experiment_id;event_type='AMENDMENT_ADDED';actor='claude';role='lead_judge';prior_event_id=$resumeTail.Object.event_id;prior_event_sha256=$resumeTail.Sha256;artifact_hashes=[pscustomobject][ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null};trial_family=$null;trial_count=$null;evidence_ids=@($resumeQid);owner_refs=@($resumeAuth);reason_code='physical_recovery';reason_ref='ORDER-105-RECOVERY';target_event_id=$resumeTarget.Object.event_id;target_event_sha256=$resumeTarget.Sha256;recovery_target_month='2026-01'}
    $resumeReqPath=Write-Request -Root $resumeFx -Request $resumeReq;$resumeCleanPath=Join-Path $resumeFx 'clean-jan.jsonl';Write-Bytes $resumeCleanPath $cleanJan
    $resumeDisable=Invoke-Utility -Root $resumeFx -UtilityArgs @('-Command','Disable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$resumeAuthPath)
    $resumeFault=Invoke-Utility -Root $resumeFx -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$resumeAuthPath,'-QuarantineEvidenceId',$resumeQid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$resumeCleanPath,'-EventJsonPath',$resumeReqPath,'-TestUtcNow','2026-02-02T00:00:00.000Z','-TestFaultPoint','after_temp_flush_before_replace')
    $resumeJanFault=[IO.File]::ReadAllBytes((Join-Path $resumeFx 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$resumeFebFault=[IO.File]::ReadAllBytes((Join-Path $resumeFx 'docs\memory_control\experiment_events\events-2026-02.jsonl'))
    $recordDurable=($resumeFebFault.Length -gt $cleanFeb.Length);$targetStillCorrupt=(-not (Test-ByteArrayEqual $cleanJan $resumeJanFault))
    # A resume with the SAME event id but a DIFFERENT payload must conflict, not be
    # accepted as a silent resume (pinned #15; review round 3 finding 1). Reuse the
    # interrupted state: same event_id, changed reason_ref.
    $resumeConflictReq=$resumeReq|ConvertTo-Json -Depth 20|ConvertFrom-Json;$resumeConflictReq.reason_ref='ORDER-105-DIFFERENT';$resumeConflictPath=Write-Request -Root $resumeFx -Request $resumeConflictReq -Name 'resume-conflict-request.json'
    $resumeConflict=Invoke-Utility -Root $resumeFx -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$resumeAuthPath,'-QuarantineEvidenceId',$resumeQid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$resumeCleanPath,'-EventJsonPath',$resumeConflictPath,'-TestUtcNow','2026-02-03T00:00:00.000Z')
    $resumeJanAfterConflict=[IO.File]::ReadAllBytes((Join-Path $resumeFx 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$conflictLeftTargetCorrupt=(-not (Test-ByteArrayEqual $cleanJan $resumeJanAfterConflict))
    Add-Case 'resume-with-same-id-different-payload-conflicts-and-does-not-install-target' ($resumeConflict.ExitCode -ne 0 -and $resumeConflict.Json.status -eq 'event_id_conflict' -and $conflictLeftTargetCorrupt) "exit=$($resumeConflict.ExitCode) status=$($resumeConflict.Json.status) targetStillCorrupt=$conflictLeftTargetCorrupt"
    # Same event_id but a changed reason_code must ALSO be event_id_conflict, not
    # reference_invalid -- the existing-ID branch classifies before recovery-request
    # validation (review round 4 finding 1).
    $resumeCodeReq=$resumeReq|ConvertTo-Json -Depth 20|ConvertFrom-Json;$resumeCodeReq.reason_code='logical_correction';$resumeCodePath=Write-Request -Root $resumeFx -Request $resumeCodeReq -Name 'resume-code-conflict-request.json'
    $resumeCodeConflict=Invoke-Utility -Root $resumeFx -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$resumeAuthPath,'-QuarantineEvidenceId',$resumeQid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$resumeCleanPath,'-EventJsonPath',$resumeCodePath,'-TestUtcNow','2026-02-03T00:00:00.000Z')
    $resumeJanAfterCode=[IO.File]::ReadAllBytes((Join-Path $resumeFx 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$codeLeftTargetCorrupt=(-not (Test-ByteArrayEqual $cleanJan $resumeJanAfterCode))
    Add-Case 'resume-with-same-id-changed-reason-code-is-conflict-not-reference-invalid' ($resumeCodeConflict.ExitCode -ne 0 -and $resumeCodeConflict.Json.status -eq 'event_id_conflict' -and $codeLeftTargetCorrupt) "status=$($resumeCodeConflict.Json.status) targetStillCorrupt=$codeLeftTargetCorrupt"
    # From the interrupted state (occurrence durable, target still corrupt), a recovery
    # with a NEW event id for the SAME target must conflict -- a second occurrence is a
    # state the staged checker rejects (review round 5 finding 2).
    $secondReq=$resumeReq|ConvertTo-Json -Depth 20|ConvertFrom-Json;$secondReq.event_id=('evt_'+[guid]::NewGuid().ToString());$secondPath=Write-Request -Root $resumeFx -Request $secondReq -Name 'second-occurrence-request.json'
    $secondOccurrence=Invoke-Utility -Root $resumeFx -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$resumeAuthPath,'-QuarantineEvidenceId',$resumeQid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$resumeCleanPath,'-EventJsonPath',$secondPath,'-TestUtcNow','2026-02-03T00:00:00.000Z')
    $resumeJanAfterSecond=[IO.File]::ReadAllBytes((Join-Path $resumeFx 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$secondLeftCorrupt=(-not (Test-ByteArrayEqual $cleanJan $resumeJanAfterSecond))
    Add-Case 'second-recovery-occurrence-for-same-target-different-id-is-conflict' ($secondOccurrence.ExitCode -ne 0 -and $secondOccurrence.Json.status -eq 'event_id_conflict' -and $secondLeftCorrupt) "status=$($secondOccurrence.Json.status) targetStillCorrupt=$secondLeftCorrupt"
    $resumeFinish=Invoke-Utility -Root $resumeFx -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$resumeAuthPath,'-QuarantineEvidenceId',$resumeQid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$resumeCleanPath,'-EventJsonPath',$resumeReqPath,'-TestUtcNow','2026-02-03T00:00:00.000Z')
    $resumeEnable=Invoke-Utility -Root $resumeFx -UtilityArgs @('-Command','Enable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$resumeAuthPath)
    $resumeJanFinal=[IO.File]::ReadAllBytes((Join-Path $resumeFx 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$resumeJanClean=(Test-ByteArrayEqual $cleanJan $resumeJanFinal)
    Invoke-TestGit -Root $resumeFx -GitArgs @('add','docs/memory_control/experiment_events')|Out-Null;$resumeCommit=Invoke-TestGit -Root $resumeFx -GitArgs @('commit','-m','resumed physical recovery') -AllowFailure
    Add-Case 'fault-interrupted-two-file-recovery-record-durable-then-resume-completes' ($resumeFault.ExitCode -ne 0 -and $recordDurable -and $targetStillCorrupt -and $resumeFinish.ExitCode -eq 0 -and $resumeFinish.Json.details.resumed -eq $true -and $resumeJanClean -and $resumeEnable.ExitCode -eq 0 -and $resumeCommit.ExitCode -eq 0) "fault=$($resumeFault.ExitCode) recordDurable=$recordDurable targetCorrupt=$targetStillCorrupt finish=$($resumeFinish.ExitCode) resumed=$($resumeFinish.Json.details.resumed) janClean=$resumeJanClean commit=$($resumeCommit.ExitCode) commitOut=$($resumeCommit.Text -replace '\s+',' ')"
    # after_replace fault leaves recovery COMPLETE (target restored + occurrence recorded);
    # a byte-identical retry must be idempotent (already_appended, no mutation), not
    # reference_invalid (review round 5 finding 1).
    $replFx=Join-Path $Scratch 'recovery_replace';Invoke-TestGit -Root $Scratch -GitArgs @('clone','--quiet','--no-hardlinks',$recovery,$replFx)|Out-Null;Add-HookPrereqs -Root $replFx;Invoke-TestGit -Root $replFx -GitArgs @('config','user.name','Recovery Replace')|Out-Null;Invoke-TestGit -Root $replFx -GitArgs @('config','user.email','replace@example.invalid')|Out-Null;Invoke-TestGit -Root $replFx -GitArgs @('config','core.hooksPath','.githooks')|Out-Null
    $replQreg=Invoke-Utility -Root $replFx -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','quarantine.bin','-CommitOid',(Get-HeadCommit $replFx),'-MediaType','application/octet-stream');$replQid=$replQreg.Json.details.evidence_id
    $replAuth=New-OwnerRef -Root $replFx -OwnerType recovery_authorization -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_RECOVERY';$replAuthPath=Join-Path $replFx 'auth.json';Write-Utf8 $replAuthPath ($replAuth|ConvertTo-Json -Compress -Depth 10)
    $replSchemas=Get-SchemaObjects -Root $replFx;$replMap=@{'docs/memory_control/experiment_events/events-2026-01.jsonl'=$cleanJan;'docs/memory_control/experiment_events/events-2026-02.jsonl'=$cleanFeb};$replManifest=[IO.File]::ReadAllBytes((Join-Path $replFx 'docs\memory_control\experiment_events\evidence-manifest.jsonl'));$replSnap=Invoke-ValidateEventSnapshot -EventFiles $replMap -ManifestBytes $replManifest -EventSchema $replSchemas.Event -EvidenceSchema $replSchemas.Evidence -Root $replFx -ResolveReferences;$replTarget=$replSnap.Events[0];$replTail=$replSnap.Events[$replSnap.Events.Count-1]
    $replReq=[pscustomobject][ordered]@{schema_version=1;event_id=('evt_'+[guid]::NewGuid().ToString());experiment_id=$replTail.Object.experiment_id;event_type='AMENDMENT_ADDED';actor='claude';role='lead_judge';prior_event_id=$replTail.Object.event_id;prior_event_sha256=$replTail.Sha256;artifact_hashes=[pscustomobject][ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null};trial_family=$null;trial_count=$null;evidence_ids=@($replQid);owner_refs=@($replAuth);reason_code='physical_recovery';reason_ref='ORDER-105-RECOVERY';target_event_id=$replTarget.Object.event_id;target_event_sha256=$replTarget.Sha256;recovery_target_month='2026-01'}
    $replReqPath=Write-Request -Root $replFx -Request $replReq;$replCleanPath=Join-Path $replFx 'clean-jan.jsonl';Write-Bytes $replCleanPath $cleanJan
    Invoke-Utility -Root $replFx -UtilityArgs @('-Command','Disable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$replAuthPath)|Out-Null
    $replFault=Invoke-Utility -Root $replFx -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$replAuthPath,'-QuarantineEvidenceId',$replQid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$replCleanPath,'-EventJsonPath',$replReqPath,'-TestUtcNow','2026-02-02T00:00:00.000Z','-TestFaultPoint','after_replace')
    $replJanFault=[IO.File]::ReadAllBytes((Join-Path $replFx 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$replFebFault=[IO.File]::ReadAllBytes((Join-Path $replFx 'docs\memory_control\experiment_events\events-2026-02.jsonl'));$replComplete=(Test-ByteArrayEqual $cleanJan $replJanFault)
    $replRetry=Invoke-Utility -Root $replFx -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$replAuthPath,'-QuarantineEvidenceId',$replQid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$replCleanPath,'-EventJsonPath',$replReqPath,'-TestUtcNow','2026-02-04T00:00:00.000Z')
    $replJanRetry=[IO.File]::ReadAllBytes((Join-Path $replFx 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$replFebRetry=[IO.File]::ReadAllBytes((Join-Path $replFx 'docs\memory_control\experiment_events\events-2026-02.jsonl'));$replNoMutation=((Test-ByteArrayEqual $replJanFault $replJanRetry) -and (Test-ByteArrayEqual $replFebFault $replFebRetry))
    Add-Case 'completed-recovery-after-replace-fault-retry-is-idempotent-already-appended' ($replComplete -and $replRetry.ExitCode -eq 0 -and $replRetry.Json.status -eq 'already_appended' -and $replNoMutation) "complete=$replComplete retryExit=$($replRetry.ExitCode) status=$($replRetry.Json.status) noMutation=$replNoMutation"
    # Completion must be judged from the LIVE state, not the retry's candidate file:
    # a byte-identical request retried with a DIFFERENT-but-valid candidate must still
    # be already_appended with zero mutation, never a reinstall (review round 6 finding 1).
    $replSchemas2=Get-SchemaObjects -Root $replFx
    $altIdea=New-IdeaRequest -Root $replFx;$altIdeaEvent=Add-TimestampToRequest -Request $altIdea -Timestamp '2026-01-01T00:00:59.000Z' -EventSchema $replSchemas2.Event
    $altIdeaErrors=@(Test-EventAgainstSchema -Event $altIdeaEvent -Schema $replSchemas2.Event);if($altIdeaErrors.Count -ne 0){throw "alt candidate construction invalid: $($altIdeaErrors -join '; ')"}
    $altCandidate=Join-LineToFileBytes -Existing $cleanJan -Line (ConvertTo-CanonicalJsonBytes -Object $altIdeaEvent -Schema $replSchemas2.Event)
    $altPath=Join-Path $replFx 'alt-jan.jsonl';Write-Bytes $altPath $altCandidate
    $replAltRetry=Invoke-Utility -Root $replFx -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$replAuthPath,'-QuarantineEvidenceId',$replQid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$altPath,'-EventJsonPath',$replReqPath,'-TestUtcNow','2026-02-05T00:00:00.000Z')
    $replJanAlt=[IO.File]::ReadAllBytes((Join-Path $replFx 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$replFebAlt=[IO.File]::ReadAllBytes((Join-Path $replFx 'docs\memory_control\experiment_events\events-2026-02.jsonl'));$altNoMutation=((Test-ByteArrayEqual $replJanRetry $replJanAlt) -and (Test-ByteArrayEqual $replFebRetry $replFebAlt))
    Add-Case 'completed-recovery-retry-with-alternate-valid-candidate-still-already-appended-no-reinstall' ($replAltRetry.ExitCode -eq 0 -and $replAltRetry.Json.status -eq 'already_appended' -and $altNoMutation) "exit=$($replAltRetry.ExitCode) status=$($replAltRetry.Json.status) noMutation=$altNoMutation"
    $recover=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath,'-QuarantineEvidenceId',$qid,'-RecoveryMonth','2026-01','-RecoveryFilePath',$cleanPath,'-EventJsonPath',$recoverReqPath,'-TestUtcNow','2026-02-02T00:00:00.000Z')
    $enable=Invoke-Utility -Root $recovery -UtilityArgs @('-Command','Enable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath)
    Invoke-TestGit -Root $recovery -GitArgs @('add','docs/memory_control/experiment_events')|Out-Null;$recoveryCommit=Invoke-TestGit -Root $recovery -GitArgs @('commit','-m','authorized physical recovery') -AllowFailure
    Add-Case 'authorized-closed-january-recovery-appends-event-to-latest-february-and-passes-real-hook' ($recover.ExitCode -eq 0 -and $recover.Json.details.target_month -eq '2026-01' -and $recover.Json.details.event_month -eq '2026-02' -and $enable.ExitCode -eq 0 -and $recoveryCommit.ExitCode -eq 0 -and $recoveryCommit.Text -match 'recognized authorized recovery') (($recover.Output,$recoveryCommit.Text)-join "`n")
    $canonicalAfterClean=$true;foreach($cp in $canonicalBefore.Keys){if($canonicalBefore[$cp] -ne (Get-FileIdentity (Join-Path $recovery ($cp-replace '/','\')))){$canonicalAfterClean=$false}}
    $recoveredJan=[IO.File]::ReadAllBytes((Join-Path $recovery 'docs\memory_control\experiment_events\events-2026-01.jsonl'));$recoveredFeb=[IO.File]::ReadAllBytes((Join-Path $recovery 'docs\memory_control\experiment_events\events-2026-02.jsonl'));$febPrefix=New-Object byte[] $cleanFeb.Length;if($recoveredFeb.Length -ge $cleanFeb.Length){[array]::Copy($recoveredFeb,0,$febPrefix,0,$cleanFeb.Length)};$preservedClosedMonth=(Test-ByteArrayEqual $cleanJan $recoveredJan);$recoveryAppendedToLatest=($recoveredFeb.Length -gt $cleanFeb.Length -and (Test-ByteArrayEqual $cleanFeb $febPrefix))
    Add-Case 'closed-month-recovery-preserves-january-bytes-appends-february-and-does-not-alter-owners' ($preservedClosedMonth -and $recoveryAppendedToLatest -and $canonicalAfterClean) "january=$preservedClosedMonth february_append=$recoveryAppendedToLatest owners=$canonicalAfterClean"

    # Disable first proves it waits for an existing holder. Then, while the
    # disabled sentinel exists, a writer is deliberately queued behind another
    # held production lock and must recheck the sentinel after acquisition.
    $disableFx=New-Fixture 'disable_queue';$auth=New-OwnerRef -Root $disableFx -OwnerType recovery_authorization -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_RECOVERY';$authPath=Join-Path $disableFx 'auth.json';Write-Utf8 $authPath ($auth|ConvertTo-Json -Compress -Depth 10);$req=Write-Request -Root $disableFx -Request (New-IdeaRequest -Root $disableFx);$held=Enter-EventLock -Root $disableFx -TimeoutSeconds 5
    $dchild=Start-UtilityProcess -Root $disableFx -UtilityArgs @('-Command','Disable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authPath) -OutPath '' -ErrPath '';Start-Sleep -Milliseconds 500;$held.Stream.Dispose();$do=Wait-Child $dchild
    $heldAgain=Enter-EventLock -Root $disableFx -TimeoutSeconds 5;$wchild=Start-UtilityProcess -Root $disableFx -UtilityArgs @('-Command','Append','-EventJsonPath',$req,'-TestUtcNow','2026-06-01T00:00:00.000Z') -OutPath '' -ErrPath '';Start-Sleep -Milliseconds 500;$heldAgain.Stream.Dispose();$wo=Wait-Child $wchild
    Add-Case 'disable-waits-for-holder-queued-writer-rechecks-sentinel' ($do.ExitCode -eq 0 -and $do.Json.lock_wait_count -gt 0 -and $wo.Json.status -eq 'disabled' -and $wo.Json.lock_wait_count -gt 0 -and -not(Test-Path (Join-Path $disableFx 'docs\memory_control\experiment_events\events-2026-06.jsonl'))) (($do.StdOut,$wo.StdOut)-join '; ')

    # Three clones of one corrupt nonterminal snapshot prove survival,
    # deterministic recovery replay, and omission rejection independently.
    $replayBase=New-Fixture 'recovery_replay_base';$replayIdea=New-IdeaRequest -Root $replayBase;$replayIdeaPath=Write-Request -Root $replayBase -Request $replayIdea;[void](Invoke-Utility -Root $replayBase -UtilityArgs @('-Command','Append','-EventJsonPath',$replayIdeaPath,'-TestUtcNow','2026-06-10T00:00:00.000Z'));$replayIds=New-Object Collections.Generic.List[string];$replayIds.Add($replayIdea.event_id)
    foreach($replayType in @('HYPOTHESIS_REGISTERED','BAR_PREREGISTERED')){$replayRequest=New-NextRequest -Root $replayBase -Type $replayType -ExperimentId $replayIdea.experiment_id;$replayRequestPath=Write-Request -Root $replayBase -Request $replayRequest;[void](Invoke-Utility -Root $replayBase -UtilityArgs @('-Command','Append','-EventJsonPath',$replayRequestPath,'-TestUtcNow',$(if($replayType -eq 'HYPOTHESIS_REGISTERED'){'2026-06-10T00:00:01.000Z'}else{'2026-06-10T00:00:02.000Z'})));$replayIds.Add($replayRequest.event_id)}
    $independentIdea=New-IdeaRequest -Root $replayBase;$independentPath=Write-Request -Root $replayBase -Request $independentIdea;[void](Invoke-Utility -Root $replayBase -UtilityArgs @('-Command','Append','-EventJsonPath',$independentPath,'-TestUtcNow','2026-06-10T00:00:03.000Z'));$replayEventPath=Join-Path $replayBase 'docs\memory_control\experiment_events\events-2026-06.jsonl';$replayClean=[IO.File]::ReadAllBytes($replayEventPath);$replaySchemas=Get-SchemaObjects -Root $replayBase;$replayLive=Get-LiveSnapshotBytes -Root $replayBase;$replaySnapshot=Invoke-ValidateEventSnapshot -EventFiles $replayLive.EventFiles -ManifestBytes $replayLive.ManifestBytes -EventSchema $replaySchemas.Event -EvidenceSchema $replaySchemas.Evidence -Root $replayBase -ResolveReferences;$replayTarget=$replaySnapshot.EventById[$replayIdea.event_id];$replayTail=$replaySnapshot.TailByExperiment[$replayIdea.experiment_id]
    $replayCorrupt=New-Object byte[] ($replayClean.Length+9);[array]::Copy($replayClean,$replayCorrupt,$replayClean.Length);[array]::Copy($Utf8NoBom.GetBytes("{garbage`n"),0,$replayCorrupt,$replayClean.Length,9);Write-Bytes (Join-Path $replayBase 'replay-quarantine.bin') $replayCorrupt;Write-Bytes $replayEventPath $replayCorrupt;Invoke-TestGit -Root $replayBase -GitArgs @('config','core.hooksPath','.no-hooks')|Out-Null;Invoke-TestGit -Root $replayBase -GitArgs @('add','replay-quarantine.bin','docs/memory_control/experiment_events/events-2026-06.jsonl')|Out-Null;Invoke-TestGit -Root $replayBase -GitArgs @('commit','--quiet','-m','corrupt nonterminal replay fixture')|Out-Null;$replayCorruptCommit=Get-HeadCommit $replayBase;$replayQreg=Invoke-Utility -Root $replayBase -UtilityArgs @('-Command','RegisterEvidence','-ArtifactPath','replay-quarantine.bin','-CommitOid',$replayCorruptCommit,'-MediaType','application/octet-stream');$replayQid=$replayQreg.Json.details.evidence_id;Invoke-TestGit -Root $replayBase -GitArgs @('add','docs/memory_control/experiment_events/evidence-manifest.jsonl')|Out-Null;Invoke-TestGit -Root $replayBase -GitArgs @('commit','--quiet','-m','register replay quarantine evidence')|Out-Null;Invoke-TestGit -Root $replayBase -GitArgs @('config','core.hooksPath','.githooks')|Out-Null
    function New-ReplayClone([string]$Name){$cloneRoot=Join-Path $Scratch $Name;Invoke-TestGit -Root $Scratch -GitArgs @('clone','--quiet','--no-hardlinks',$replayBase,$cloneRoot)|Out-Null;Add-HookPrereqs -Root $cloneRoot;Invoke-TestGit -Root $cloneRoot -GitArgs @('config','user.name','Replay Test')|Out-Null;Invoke-TestGit -Root $cloneRoot -GitArgs @('config','user.email','replay@example.invalid')|Out-Null;Invoke-TestGit -Root $cloneRoot -GitArgs @('config','core.hooksPath','.githooks')|Out-Null;return $cloneRoot}
    function Invoke-ReplayRecovery([string]$Root,[byte[]]$Candidate,[string]$EventId){
        $authorization=New-OwnerRef -Root $Root -OwnerType recovery_authorization -Path 'AGENT_TASKBOARD.md' -Anchor 'ANCHOR_RECOVERY';$authorizationPath=Join-Path $Root 'replay-authorization.json';Write-Utf8 $authorizationPath ($authorization|ConvertTo-Json -Compress -Depth 10);$candidatePath=Join-Path $Root 'replay-candidate.jsonl';Write-Bytes $candidatePath $Candidate;$recoveryRequest=[pscustomobject][ordered]@{schema_version=1;event_id=$EventId;experiment_id=$replayIdea.experiment_id;event_type='AMENDMENT_ADDED';actor='claude';role='lead_judge';prior_event_id=$replayTail.Object.event_id;prior_event_sha256=$replayTail.Sha256;artifact_hashes=[pscustomobject][ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null};trial_family=$null;trial_count=$null;evidence_ids=@($replayQid);owner_refs=@($authorization);reason_code='physical_recovery';reason_ref='ORDER-105-RECOVERY';target_event_id=$replayTarget.Object.event_id;target_event_sha256=$replayTarget.Sha256;recovery_target_month='2026-06'};$requestPath=Write-Request -Root $Root -Request $recoveryRequest -Name 'replay-recovery-request.json';$disabled=Invoke-Utility -Root $Root -UtilityArgs @('-Command','Disable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authorizationPath);$recovered=Invoke-Utility -Root $Root -UtilityArgs @('-Command','Recover','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authorizationPath,'-QuarantineEvidenceId',$replayQid,'-RecoveryMonth','2026-06','-RecoveryFilePath',$candidatePath,'-EventJsonPath',$requestPath,'-TestUtcNow','2026-06-10T00:00:04.000Z');$enabled=if($recovered.ExitCode -eq 0){Invoke-Utility -Root $Root -UtilityArgs @('-Command','Enable','-Actor','claude','-Role','lead_judge','-AuthorizationRefJsonPath',$authorizationPath)}else{$null};return [pscustomobject]@{Disable=$disabled;Recover=$recovered;Enable=$enabled;AuthorizationPath=$authorizationPath}
    }
    $replayA=New-ReplayClone 'recovery_replay_a';$replayB=New-ReplayClone 'recovery_replay_b';$fixedRecoveryId='evt_33333333-3333-4333-8333-333333333333';$replayOutcomeA=Invoke-ReplayRecovery -Root $replayA -Candidate $replayClean -EventId $fixedRecoveryId;$replayOutcomeB=Invoke-ReplayRecovery -Root $replayB -Candidate $replayClean -EventId $fixedRecoveryId;$recoveredA=[IO.File]::ReadAllBytes((Join-Path $replayA 'docs\memory_control\experiment_events\events-2026-06.jsonl'));$recoveredB=[IO.File]::ReadAllBytes((Join-Path $replayB 'docs\memory_control\experiment_events\events-2026-06.jsonl'))
    Add-Case 'deterministic-replay-two-rebuilds-byte-identical' ($replayOutcomeA.Recover.ExitCode -eq 0 -and $replayOutcomeB.Recover.ExitCode -eq 0 -and $replayOutcomeA.Enable.ExitCode -eq 0 -and $replayOutcomeB.Enable.ExitCode -eq 0 -and (Test-ByteArrayEqual $recoveredA $recoveredB)) "shaA=$(Get-Sha256Hex $recoveredA) shaB=$(Get-Sha256Hex $recoveredB)"
    $continuedRun=New-NextRequest -Root $replayA -Type RUN_STARTED -ExperimentId $replayIdea.experiment_id;$continuedPath=Write-Request -Root $replayA -Request $continuedRun;$continued=Invoke-Utility -Root $replayA -UtilityArgs @('-Command','Append','-EventJsonPath',$continuedPath,'-TestUtcNow','2026-06-10T00:00:05.000Z');$continuedSchemas=Get-SchemaObjects -Root $replayA;$continuedLive=Get-LiveSnapshotBytes -Root $replayA;$continuedSnapshot=Invoke-ValidateEventSnapshot -EventFiles $continuedLive.EventFiles -ManifestBytes $continuedLive.ManifestBytes -EventSchema $continuedSchemas.Event -EvidenceSchema $continuedSchemas.Evidence -Root $replayA -ResolveReferences;$survivingIds=@($continuedSnapshot.Events|Where-Object{$_.Object.experiment_id -eq $replayIdea.experiment_id}|ForEach-Object{$_.Object.event_id});$hasAllPreserved=(@($replayIds|Where-Object{$_ -notin $survivingIds}).Count -eq 0);$hasDecision=@($continuedSnapshot.Events|Where-Object{$_.Object.experiment_id -eq $replayIdea.experiment_id -and $_.Object.event_type -eq 'DECISION_LINKED'}).Count -gt 0
    Add-Case 'nonterminal-experiment-survives-disable-rebuild-reenable-with-traceability' ($replayOutcomeA.Disable.ExitCode -eq 0 -and $replayOutcomeA.Recover.ExitCode -eq 0 -and $replayOutcomeA.Enable.ExitCode -eq 0 -and $continued.ExitCode -eq 0 -and $continuedSnapshot.IsValid -and $hasAllPreserved -and -not $hasDecision) "preserved=$hasAllPreserved continued=$($continued.Json.status) decision=$hasDecision"
    $omitClone=New-ReplayClone 'recovery_omission';$splitReplay=Split-JsonlBytes -Bytes $replayClean -Path 'replay-clean' -MaxLineBytes 32768;$omitBytes=New-Object Collections.Generic.List[byte];foreach($lineRecord in @($splitReplay.Lines|Select-Object -First ($splitReplay.Lines.Count-1))){foreach($byte in $lineRecord.Bytes){$omitBytes.Add($byte)};$omitBytes.Add(0x0A)};$omitOutcome=Invoke-ReplayRecovery -Root $omitClone -Candidate $omitBytes.ToArray() -EventId 'evt_44444444-4444-4444-8444-444444444444'
    Add-Case 'recovery-candidate-omitting-independently-valid-event-rejected' ($omitOutcome.Disable.ExitCode -eq 0 -and $omitOutcome.Recover.ExitCode -ne 0 -and $omitOutcome.Recover.Json.status -eq 'reference_invalid' -and $omitOutcome.Recover.Output -match 'omits or reorders') $omitOutcome.Recover.Output

    # Schema determinism and core.autocrlf index candidate.
    $det=New-Fixture 'determinism';Invoke-TestGit -Root $det -GitArgs @('config','core.autocrlf','true')|Out-Null;$idea=New-IdeaRequest -Root $det;$p=Write-Request -Root $det -Request $idea;$a=Invoke-Utility -Root $det -UtilityArgs @('-Command','Append','-EventJsonPath',$p,'-TestUtcNow','2026-07-01T00:00:00.000Z');$bytes1=[IO.File]::ReadAllBytes((Join-Path $det 'docs\memory_control\experiment_events\events-2026-07.jsonl'));$retry=Invoke-Utility -Root $det -UtilityArgs @('-Command','Append','-EventJsonPath',$p,'-TestUtcNow','2026-07-01T00:00:01.000Z');$bytes2=[IO.File]::ReadAllBytes((Join-Path $det 'docs\memory_control\experiment_events\events-2026-07.jsonl'));$check=Stage-And-Check -Root $det -Paths @('docs/memory_control/experiment_events/events-2026-07.jsonl')
    Add-Case 'canonical-serialization-deterministic-under-autocrlf-true' ($a.ExitCode -eq 0 -and $retry.Json.status -eq 'already_appended' -and (Test-ByteArrayEqual $bytes1 $bytes2) -and $check.ExitCode -eq 0) $check.Output

    $processA=New-Fixture 'canonical_process_a';$processB=New-Fixture 'canonical_process_b';$fixedEventId='evt_11111111-1111-4111-8111-111111111111';$fixedExperimentId='exp_22222222-2222-4222-8222-222222222222';$processRequest=New-IdeaRequest -Root $processA -EventId $fixedEventId -ExperimentId $fixedExperimentId;$processRequestA=Write-Request -Root $processA -Request $processRequest -Name 'canonical-request.json';$processRequestB=Write-Request -Root $processB -Request $processRequest -Name 'canonical-request.json';$processChildA=Start-UtilityProcess -Root $processA -UtilityArgs @('-Command','Append','-EventJsonPath',$processRequestA,'-TestUtcNow','2026-07-02T00:00:00.000Z') -OutPath '' -ErrPath '';$processChildB=Start-UtilityProcess -Root $processB -UtilityArgs @('-Command','Append','-EventJsonPath',$processRequestB,'-TestUtcNow','2026-07-02T00:00:00.000Z') -OutPath '' -ErrPath '';$processOutcomeA=Wait-Child $processChildA;$processOutcomeB=Wait-Child $processChildB;$processBytesA=[IO.File]::ReadAllBytes((Join-Path $processA 'docs\memory_control\experiment_events\events-2026-07.jsonl'));$processBytesB=[IO.File]::ReadAllBytes((Join-Path $processB 'docs\memory_control\experiment_events\events-2026-07.jsonl'))
    Add-Case 'two-powershell-5-1-processes-canonical-serialization-byte-identical' ($processOutcomeA.ExitCode -eq 0 -and $processOutcomeB.ExitCode -eq 0 -and (Test-ByteArrayEqual $processBytesA $processBytesB)) "shaA=$(Get-Sha256Hex $processBytesA) shaB=$(Get-Sha256Hex $processBytesB)"

    # Shared-repository and scratch hygiene is itself a permanent case.
    $SharedAfter=Get-SharedIdentity
    $headSafe=$true;$headScopeChanges=@()
    if($SharedBefore.Head -ne $SharedAfter.Head){
        $headLog=Invoke-TestGit -Root $SourceRoot -GitArgs @('log','--format=','--name-only',("$($SharedBefore.Head)..$($SharedAfter.Head)")) -AllowFailure
        if($headLog.ExitCode -ne 0){$headSafe=$false;$headScopeChanges=@('<git-log-failed>')}
        else{$headScopeChanges=@($headLog.Text -split "`r?`n"|Where-Object{$_ -and (Test-IsSharedScopePath $_)}|Sort-Object -Unique);$headSafe=($headScopeChanges.Count -eq 0)}
    }
    $indexChanges=@(Compare-SharedScopeMap -Before $SharedBefore.Index -After $SharedAfter.Index)
    $worktreeChanges=@(Compare-SharedScopeMap -Before $SharedBefore.Worktree -After $SharedAfter.Worktree)
    $configSame=($SharedBefore.Config -ceq $SharedAfter.Config)
    $sharedClean=($headSafe -and $indexChanges.Count -eq 0 -and $worktreeChanges.Count -eq 0 -and $configSame)
    $sharedDetail="head_scope_safe=$headSafe head_scope_changes=$($headScopeChanges -join ',') index_changes=$($indexChanges -join ',') worktree_changes=$($worktreeChanges -join ',') config=$configSame"
    Add-Case 'shared-repo-head-index-worktree-config-unchanged' $sharedClean $sharedDetail

    # DERIVED, not remembered. Every fixture that commits through the real hook needs the
    # interpreter, and this suite has SEVEN clone sites: four helpers and three written
    # inline. The first fix wired four of them, and the suite still failed -- on a case that
    # had not run since 2026-08-01, with the same PRECOMMIT-FAIL-CLOSED line, because a
    # hand-followed list missed three. That is the same defect the seed's stub list was made
    # derived to end (see Initialize-Seed), one layer out. So the list is not trusted here:
    # every repository under the scratch root whose core.hooksPath is .githooks is
    # enumerated, and each one must carry the interpreter the hook refuses to run without.
    $hookedMissing=@()
    foreach($d in @(Get-ChildItem -LiteralPath $Scratch -Directory -ErrorAction SilentlyContinue)){
        if(-not (Test-Path -LiteralPath (Join-Path $d.FullName '.git'))){ continue }
        $hp=Invoke-TestGit -Root $d.FullName -GitArgs @('config','--get','core.hooksPath') -AllowFailure
        if($hp.Text -ne '.githooks'){ continue }
        if(-not (Test-Path -LiteralPath (Join-Path $d.FullName ($script:HookPythonRel -replace '/','\')))){ $hookedMissing+=$d.Name }
    }
    Add-Case 'every-hooked-fixture-carries-the-hook-interpreter' ($hookedMissing.Count -eq 0) "missing=$($hookedMissing -join ',')"
}catch{
    $Fatal=$_.Exception.Message+' | '+$_.InvocationInfo.PositionMessage+' | '+$_.ScriptStackTrace
    Write-Host ('FATAL-BRIEF: '+$Fatal)
    Add-Case 'suite-unhandled-exception' $false $Fatal
}finally{
    try{Remove-Scratch $Scratch}catch{Add-Case 'scratch-cleanup-exception' $false $_.Exception.Message}
}

$leftovers=@(Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter ('ea_lab_order105_'+$RunId) -ErrorAction SilentlyContinue)
Add-Case 'guid-scratch-leftovers-zero' ($leftovers.Count -eq 0) "leftovers=$($leftovers.Count)"

# A truncated run must not read like a short run. ORDER-1460: this suite aborted at case 15
# of 105 for five days, and every line it printed was true -- fifteen honest results, thirteen
# of them PASS. What it could not say was that ninety cases had not been ASKED. The floor is a
# case like any other, so it fails loudly in the same list and takes the exit code with it.
# It is a FLOOR (-ge), not an equality: adding cases must never turn this red. Raise it when
# the suite genuinely grows; never lower it to make a run go green.
$MinimumCaseCount=105
$countBeforeFloor=$Results.Count
Add-Case 'case-count-at-or-above-floor' ($countBeforeFloor -ge $MinimumCaseCount) "reached=$countBeforeFloor floor=$MinimumCaseCount$(if($countBeforeFloor -lt $MinimumCaseCount){' -- TRUNCATED RUN: '+($MinimumCaseCount-$countBeforeFloor)+' case(s) were never asked; the results above are not a pass'})"

$allPass=$true
foreach($result in $Results){$label=if($result.Pass){'PASS'}else{$allPass=$false;'FAIL'};Write-Host ("[$label] $($result.Name)$(if($result.Detail){' :: '+$result.Detail}else{''})")}
Write-Host ("CASE COUNT: $($Results.Count)")
if($allPass){Write-Host 'ALL CASES PASSED';exit 0}
Write-Host 'ONE OR MORE CASES FAILED -- see above';exit 1
