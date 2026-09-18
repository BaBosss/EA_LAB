$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$capture = Join-Path $repo 'scripts\execution_reliability\capture_job_identity.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ea-lab-job-identity-tests-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tempRoot)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT: $Message" }
}

try {
    [void][scriptblock]::Create([IO.File]::ReadAllText($capture))
    . $capture -RepoRoot $repo -ExpectedHead ('0' * 40) -LeaseRoot $tempRoot -JobsRoot $tempRoot `
        -LaneIds @() -OutputRoot (Join-Path $tempRoot 'unused-output') -LibraryOnly

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
    Assert-True ($absent.query_status -ceq 'NOT_PRESENT') 'known absent PID query status is wrong'

    $notConfigured = Get-IdentityEvidence -LaneId 'fixture-lane' -JobId 'fixture-job' -Role postcondition `
        -PidValue $null -ExpectedCreationUtc $null -PostconditionNotConfigured:$true
    Assert-True ($notConfigured.identity -ceq 'RECORDED_PROCESS_NOT_PRESENT') 'explicit NOT_CONFIGURED was not absent'
    Assert-True ($notConfigured.query_status -ceq 'NOT_CONFIGURED') 'NOT_CONFIGURED evidence was not retained'

    $unknown = Get-IdentityEvidence -LaneId 'fixture-lane' -JobId 'fixture-job' -Role runner `
        -PidValue $null -ExpectedCreationUtc $null
    Assert-True ($unknown.identity -ceq 'UNKNOWN') 'missing required runner identity did not remain unknown'

    $privateJson = @($matching, $different, $absent, $notConfigured, $unknown) | ConvertTo-Json -Depth 6
    Assert-True ($privateJson -notmatch '(?i)process_name|command_line|account|credential|token') 'process evidence exposed forbidden text'

    $realDir = Join-Path $tempRoot 'real'
    $junction = Join-Path $tempRoot 'junction'
    [void](New-Item -ItemType Directory -Path $realDir)
    [void](New-Item -ItemType Junction -Path $junction -Target $realDir)
    $reparseRefused = $false
    try { Assert-NoReparseComponents (Join-Path $junction 'child.json') 'fixture path' }
    catch { $reparseRefused = $_.Exception.Message -match 'reparse' }
    Assert-True $reparseRefused 'junction/reparse path was not refused'

    . (Join-Path $repo 'scripts\use_python.ps1')
    Assert-PortablePython -Root $repo
    & python -m unittest discover -s (Join-Path $repo 'tools\mobile_report_hub\tests') -p test_job_identity_provider.py -v
    if ($LASTEXITCODE -ne 0) { throw "Python identity-provider tests failed: $LASTEXITCODE" }
    Write-Output 'JOB_IDENTITY_CAPTURE_TESTS_PASS'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
