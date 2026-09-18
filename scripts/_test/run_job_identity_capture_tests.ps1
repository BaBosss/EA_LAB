$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$capture = Join-Path $repo 'scripts\execution_reliability\capture_job_identity.ps1'
$canonicalHelper = Join-Path $repo 'scripts\long_jobs\_long_job_runner_lib.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ea-lab-job-identity-tests-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tempRoot)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT: $Message" }
}

function Write-FixtureJson {
    param([string]$Path, $Value)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent) }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 12) + "`n"), (New-Object Text.UTF8Encoding($false)))
}

function New-FixtureRepo {
    param([string]$Path, [string]$HelperText)
    [void](New-Item -ItemType Directory -Path (Join-Path $Path 'scripts\long_jobs') -Force)
    [IO.File]::WriteAllText((Join-Path $Path 'scripts\long_jobs\_long_job_runner_lib.ps1'), $HelperText,
        (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $Path 'tracked.txt'), "clean`n", (New-Object Text.UTF8Encoding($false)))
    & git -c core.excludesFile= -C $Path init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'fixture git init failed' }
    & git -c core.excludesFile= -c core.autocrlf=false -C $Path -c user.name=fixture -c user.email=fixture@example.invalid add --all
    if ($LASTEXITCODE -ne 0) { throw 'fixture git add failed' }
    & git -c core.excludesFile= -C $Path -c user.name=fixture -c user.email=fixture@example.invalid commit --quiet -m fixture
    if ($LASTEXITCODE -ne 0) { throw 'fixture git commit failed' }
    return (& git -c core.excludesFile= -C $Path rev-parse HEAD).Trim()
}

try {
    [void][scriptblock]::Create([IO.File]::ReadAllText($capture))

    # JIPV1-002: repo trust is established before a helper with side effects can run.
    $marker = Join-Path $tempRoot 'UNTRUSTED_HELPER_EXECUTED.txt'
    $maliciousRepo = Join-Path $tempRoot 'untrusted-repo'
    $escapedMarker = $marker.Replace("'", "''")
    $maliciousHelper = "[IO.File]::WriteAllText('$escapedMarker','executed')`nfunction Get-LjrProcessSnapshot { param([int]`$ProcessId); return `$null }`n"
    $maliciousHead = New-FixtureRepo $maliciousRepo $maliciousHelper
    $junction = Join-Path $tempRoot 'untrusted-junction'
    [void](New-Item -ItemType Junction -Path $junction -Target $maliciousRepo)
    foreach ($case in @(
        @{ Root = $junction; Head = $maliciousHead; Name = 'reparse' },
        @{ Root = $maliciousRepo; Head = ('0' * 40); Name = 'wrong-head' }
    )) {
        $refused = $false
        try {
            . $capture -RepoRoot $case.Root -ExpectedHead $case.Head -CanonicalObservedHead ('c' * 40) `
                -LeaseRoot $tempRoot -JobsRoot $tempRoot -LaneIds @() -OutputRoot (Join-Path $tempRoot ('unused-' + $case.Name)) -LibraryOnly
        } catch { $refused = $true }
        Assert-True $refused "$($case.Name) repository was not refused"
        Assert-True (-not (Test-Path -LiteralPath $marker)) "$($case.Name) repository executed its helper before refusal"
    }
    [IO.File]::AppendAllText((Join-Path $maliciousRepo 'tracked.txt'), "dirty`n")
    $dirtyRefused = $false
    try {
        . $capture -RepoRoot $maliciousRepo -ExpectedHead $maliciousHead -CanonicalObservedHead ('c' * 40) `
            -LeaseRoot $tempRoot -JobsRoot $tempRoot -LaneIds @() -OutputRoot (Join-Path $tempRoot 'unused-dirty') -LibraryOnly
    } catch { $dirtyRefused = $true }
    Assert-True $dirtyRefused 'dirty repository was not refused'
    Assert-True (-not (Test-Path -LiteralPath $marker)) 'dirty repository executed its helper before refusal'

    # Load the canonical helper only from a clean, exact disposable repository.
    $fixtureRepo = Join-Path $tempRoot 'trusted-repo'
    $fixtureHead = New-FixtureRepo $fixtureRepo ([IO.File]::ReadAllText($canonicalHelper))
    . $capture -RepoRoot $fixtureRepo -ExpectedHead $fixtureHead -CanonicalObservedHead ('c' * 40) `
        -LeaseRoot $tempRoot -JobsRoot $tempRoot -LaneIds @() -OutputRoot (Join-Path $tempRoot 'unused-library') -LibraryOnly

    $self = Get-LjrProcessSnapshot -ProcessId $PID
    Assert-True ($null -ne $self) 'canonical helper could not observe the test process'
    $matching = Get-IdentityEvidence -LaneId 'fixture-lane' -JobId 'fixture-job' -Role runner `
        -PidValue $PID -ExpectedCreationUtc $self.StartTimeUtc
    Assert-True ($matching.identity -ceq 'MATCHING_RECORDED_PROCESS') 'self-process identity did not match'
    Assert-True ($matching.current_creation_utc -ceq $self.StartTimeUtc) 'self-process creation time lost precision'

    $precise = [DateTimeOffset]::Parse($self.StartTimeUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
    $differentExpected = $precise.AddTicks(1).ToString('o')
    $different = Get-IdentityEvidence -LaneId 'fixture-lane' -JobId 'fixture-job' -Role runner `
        -PidValue $PID -ExpectedCreationUtc $differentExpected
    Assert-True ($different.identity -ceq 'DIFFERENT_CREATION_IDENTITY') '100ns identity difference was truncated'

    $absent = Get-IdentityEvidence -LaneId 'fixture-lane' -JobId 'fixture-job' -Role child `
        -PidValue ([int]::MaxValue) -ExpectedCreationUtc '2000-01-01T00:00:00.0000000Z'
    Assert-True ($absent.identity -ceq 'RECORDED_PROCESS_NOT_PRESENT') 'known absent PID was not distinguished'
    $notConfigured = Get-IdentityEvidence -LaneId 'fixture-lane' -JobId 'fixture-job' -Role postcondition `
        -PidValue $null -ExpectedCreationUtc $null -PostconditionNotConfigured:$true
    Assert-True ($notConfigured.query_status -ceq 'NOT_CONFIGURED') 'NOT_CONFIGURED evidence was not retained'

    # JIPV1-001/JIPV1-007: real-format eleven-field lease, untrusted path fields,
    # and a self-process query flow through collector and adapter end to end.
    $laneId = 'fixture-lane'
    $jobId = 'fixture-job'
    $baseSha = 'b' * 40
    $canonicalSha = 'c' * 40
    $leaseRoot = Join-Path $tempRoot 'leases'
    $jobsRoot = Join-Path $tempRoot 'jobs'
    $jobRoot = Join-Path $jobsRoot $jobId
    [void](New-Item -ItemType Directory -Path $leaseRoot)
    [void](New-Item -ItemType Directory -Path $jobRoot -Force)
    $created = $precise.AddMinutes(-1).ToString('o')
    $lease = [ordered]@{
        lane_id = $laneId; job_id = $jobId; created_utc = $created
        job_root = 'Z:\untrusted\job-root'; status_script = 'Z:\untrusted\status.ps1'
        runner_root = 'Z:\untrusted\runner'; requested_file = 'Z:\untrusted\request.ps1'
        launch_file = 'Z:\untrusted\powershell.exe'; worktree = 'Z:\untrusted\worktree'
        base_sha = $baseSha; stage = 'DISPOSABLE_FIXTURE'
    }
    $job = [ordered]@{
        job_id = $jobId; file_path = 'Z:\private\worker.ps1'; arg_count = 0; arg_hash = 'private'
        timeout_sec = 3600; heartbeat_sec = 5; worktree = 'Z:\private\worktree'; base_sha = $baseSha
        stage = 'DISPOSABLE_FIXTURE'; postcondition_file_path = ''; postcondition_arg_count = 0
        postcondition_arg_hash = 'private'; created_utc = $created
    }
    $state = [ordered]@{
        job_id = $jobId; state = 'RUNNING'; runner_pid = $PID; runner_start_utc = $self.StartTimeUtc
        child_pid = $PID; child_start_utc = $self.StartTimeUtc; created_utc = $created; started_utc = $self.StartTimeUtc
        timeout_sec = 3600; heartbeat_sec = 5; file_path = 'Z:\private\worker.ps1'; postcondition_file_path = ''
    }
    $leasePath = Join-Path $leaseRoot ($laneId + '.json')
    $statePath = Join-Path $jobRoot 'state.json'
    Write-FixtureJson $leasePath $lease
    Write-FixtureJson (Join-Path $jobRoot 'job.json') $job
    Write-FixtureJson $statePath $state
    $bundle = Join-Path $tempRoot 'bundle'
    . $capture -RepoRoot $fixtureRepo -ExpectedHead $fixtureHead -CanonicalObservedHead $canonicalSha `
        -LeaseRoot $leaseRoot -JobsRoot $jobsRoot -LaneIds @($laneId) -OutputRoot $bundle | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $bundle 'manifest.json') -PathType Leaf) 'end-to-end capture did not publish a manifest'

    . (Join-Path $repo 'scripts\use_python.ps1')
    Assert-PortablePython -Root $repo
    $publication = Join-Path $tempRoot 'publication'
    & python (Join-Path $repo 'tools\mobile_report_hub\job_identity_provider.py') `
        --bundle-manifest (Join-Path $bundle 'manifest.json') --output-root $publication | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "end-to-end adapter failed: $LASTEXITCODE" }
    $public = Get-Content -LiteralPath (Join-Path $publication 'job_observations.json') -Raw | ConvertFrom-Json
    $private = Get-Content -LiteralPath (Join-Path $publication 'private_provenance_receipt.json') -Raw | ConvertFrom-Json
    Assert-True ($public.canonical_observed_sha -ceq $canonicalSha) 'candidate source head was mislabeled canonical'
    Assert-True ($private.candidate_source_head -ceq $fixtureHead) 'candidate source provenance was not retained'
    Assert-True ($public.observations[0].observed_state -ceq 'RUNNING') 'self-process fixture did not remain RUNNING'

    # Duplicate and extra keys refuse before any output is created. The hostile duplicate
    # PID is last so a non-strict parser would attempt to use it.
    $validStateBytes = [IO.File]::ReadAllBytes($statePath)
    $duplicateState = '{"job_id":"fixture-job","state":"RUNNING","runner_pid":' + $PID + `
        ',"runner\u005fpid":"hostile","runner_start_utc":"' + $self.StartTimeUtc + '","child_pid":' + $PID + `
        ',"child_start_utc":"' + $self.StartTimeUtc + '"}'
    [IO.File]::WriteAllText($statePath, $duplicateState, (New-Object Text.UTF8Encoding($false)))
    $duplicateOutput = Join-Path $tempRoot 'duplicate-output'
    $duplicateRefused = $false
    try {
        . $capture -RepoRoot $fixtureRepo -ExpectedHead $fixtureHead -CanonicalObservedHead $canonicalSha `
            -LeaseRoot $leaseRoot -JobsRoot $jobsRoot -LaneIds @($laneId) -OutputRoot $duplicateOutput | Out-Null
    } catch { $duplicateRefused = $_.Exception.Message -match 'duplicate JSON key' }
    Assert-True $duplicateRefused 'duplicate PID key was not refused before process selection'
    Assert-True (-not (Test-Path -LiteralPath $duplicateOutput)) 'duplicate-key refusal created output'
    [IO.File]::WriteAllBytes($statePath, $validStateBytes)

    $extraLease = [ordered]@{}
    foreach ($key in $lease.Keys) { $extraLease[$key] = $lease[$key] }
    $extraLease['unexpected'] = 'refuse'
    Write-FixtureJson $leasePath $extraLease
    $extraOutput = Join-Path $tempRoot 'extra-output'
    $extraRefused = $false
    try {
        . $capture -RepoRoot $fixtureRepo -ExpectedHead $fixtureHead -CanonicalObservedHead $canonicalSha `
            -LeaseRoot $leaseRoot -JobsRoot $jobsRoot -LaneIds @($laneId) -OutputRoot $extraOutput | Out-Null
    } catch { $extraRefused = $_.Exception.Message -match 'extra JSON key' }
    Assert-True $extraRefused 'extra lease key was not refused before process selection'
    Assert-True (-not (Test-Path -LiteralPath $extraOutput)) 'extra-key refusal created output'
    Write-FixtureJson $leasePath $lease

    # JIPV1-003: overlap and hardlinks are refused before output creation.
    $overlapOutput = Join-Path $jobsRoot 'forbidden-output'
    $overlapRefused = $false
    try {
        . $capture -RepoRoot $fixtureRepo -ExpectedHead $fixtureHead -CanonicalObservedHead $canonicalSha `
            -LeaseRoot $leaseRoot -JobsRoot $jobsRoot -LaneIds @($laneId) -OutputRoot $overlapOutput | Out-Null
    } catch { $overlapRefused = $_.Exception.Message -match 'overlap' }
    Assert-True $overlapRefused 'output/source overlap was not refused'
    Assert-True (-not (Test-Path -LiteralPath $overlapOutput)) 'overlap refusal created output'

    $reparseOutput = Join-Path $junction 'forbidden-output'
    $reparseOutputRefused = $false
    try {
        . $capture -RepoRoot $fixtureRepo -ExpectedHead $fixtureHead -CanonicalObservedHead $canonicalSha `
            -LeaseRoot $leaseRoot -JobsRoot $jobsRoot -LaneIds @($laneId) -OutputRoot $reparseOutput | Out-Null
    } catch { $reparseOutputRefused = $_.Exception.Message -match 'reparse' }
    Assert-True $reparseOutputRefused 'reparse output parent was not refused'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $maliciousRepo 'forbidden-output'))) 'reparse refusal created output'

    $leaseHardlink = Join-Path $leaseRoot 'lease-hardlink.json'
    [void](New-Item -ItemType HardLink -Path $leaseHardlink -Target $leasePath)
    $hardlinkOutput = Join-Path $tempRoot 'hardlink-output'
    $hardlinkRefused = $false
    try {
        . $capture -RepoRoot $fixtureRepo -ExpectedHead $fixtureHead -CanonicalObservedHead $canonicalSha `
            -LeaseRoot $leaseRoot -JobsRoot $jobsRoot -LaneIds @($laneId) -OutputRoot $hardlinkOutput | Out-Null
    } catch { $hardlinkRefused = $_.Exception.Message -match 'hardlink' }
    Assert-True $hardlinkRefused 'hardlinked source was not refused'
    Assert-True (-not (Test-Path -LiteralPath $hardlinkOutput)) 'hardlink refusal created output'

    & python -m unittest discover -s (Join-Path $repo 'tools\mobile_report_hub\tests') -p test_job_identity_provider.py -v
    if ($LASTEXITCODE -ne 0) { throw "Python identity-provider tests failed: $LASTEXITCODE" }
    Write-Output 'JOB_IDENTITY_CAPTURE_TESTS_PASS'
} finally {
    $fullTempRoot = [IO.Path]::GetFullPath($tempRoot)
    $systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($fullTempRoot.StartsWith($systemTempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $fullTempRoot).StartsWith('ea-lab-job-identity-tests-', [StringComparison]::Ordinal)) {
        if (Test-Path -LiteralPath $fullTempRoot) { Remove-Item -LiteralPath $fullTempRoot -Recurse -Force }
    } else {
        throw 'refusing unsafe fixture cleanup target'
    }
}
