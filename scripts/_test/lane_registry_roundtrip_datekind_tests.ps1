[CmdletBinding()]
param(
    [string]$CleanWorktree = 'D:\EA_LAB_CONTROL\w\ct-lnwjud-temporal-failclosed-20261013'
)
$ErrorActionPreference = 'Stop'
$scriptPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\lane_registry.ps1')).Path
if (-not (Test-Path -LiteralPath $CleanWorktree -PathType Container)) { throw 'CLEAN_WORKTREE_MISSING' }
$head = (& git -C $CleanWorktree rev-parse HEAD).Trim()
$branch = (& git -C $CleanWorktree branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or @(& git -C $CleanWorktree status --porcelain).Count -gt 0) { throw 'UNCLEAN_FIXTURE_WORKTREE' }
$temp = Join-Path ([IO.Path]::GetTempPath()) ('ea-lane-datekind-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temp) | Out-Null
$exe = (Get-Process -Id $PID).Path
if ([string]::IsNullOrWhiteSpace($exe)) { throw 'CURRENT_POWERSHELL_EXE_UNKNOWN' }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Invoke-RegistryFixture {
    param([string]$Root, [string]$Command, [string]$ExpectedState = '', [string]$NewState = '')
    $stdout = Join-Path $temp ([guid]::NewGuid().ToString('N') + '.stdout')
    $stderr = Join-Path $temp ([guid]::NewGuid().ToString('N') + '.stderr')
    $argsList = @('-NoProfile','-File',$scriptPath,'-RegistryRoot',$Root,'-RepoRoot',$CleanWorktree,'-Command',$Command,'-LaneId','datekind-fixture-001')
    if ($ExpectedState) { $argsList += @('-ExpectedState',$ExpectedState) }
    if ($NewState) { $argsList += @('-NewState',$NewState,'-HeadSha',$head) }
    $proc = Start-Process -FilePath $exe -ArgumentList $argsList -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    return [pscustomobject]@{Exit=$proc.ExitCode;StdOut=([IO.File]::ReadAllText($stdout));StdErr=([IO.File]::ReadAllText($stderr))}
}
try {
    $registry = Join-Path $temp 'registry'
    [IO.Directory]::CreateDirectory($registry) | Out-Null
    $record = [ordered]@{
        lane_id='datekind-fixture-001';owner_chat='TEMP_TEST_ONLY';worker='TEST_AUTHOR';
        objective='DATEKIND_ROUNDTRIP_FIXTURE';state='WAITING';base_sha=$head;head_sha=$head;
        worktree=$CleanWorktree;branch=$branch;allowed_paths=@('scripts/lane_registry.ps1');
        critical_paths=@('scripts/lane_registry.ps1');runtime_lane='';writer=$true;
        dependencies=@();reviewer=$null;reviewed_head=$null;direct_consumer='TEMP_TEST_CONSUMER';
        blocker_class='';updated_at='2026-10-14T00:00:00.1234567+00:00'
    }
    $file = Join-Path $registry 'datekind-fixture-001.json'
    [IO.File]::WriteAllText($file,($record|ConvertTo-Json -Depth 40)+"`n",$utf8NoBom)
    $original = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    $result = Invoke-RegistryFixture -Root $registry -Command 'Transition' -ExpectedState 'WAITING' -NewState 'RUNNING'
    Write-Output ('TRANSITION_EXIT=' + $result.Exit)
    if ($result.Exit -ne 0) {
        Write-Output ('TRANSITION_ERROR=' + $result.StdErr.Trim())
        Write-Output ('FIXTURE_SHA_UNCHANGED=' + ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -eq $original))
        throw 'DATEKIND_TRANSITION_RED: isolated official WAITING_to_RUNNING refused'
    }
    $after = [IO.File]::ReadAllText($file)
    $roundtripParseArgs = @{}
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $roundtripParseArgs.DateKind = 'String' }
    $obj = $after | ConvertFrom-Json @roundtripParseArgs
    if ($obj.state -cne 'RUNNING') { throw 'NEW_STATE_MISMATCH' }
    if ([string]$obj.updated_at -notmatch '\+00:00') { throw 'DATE_TIMEZONE_NOT_PRESERVED' }
    if ($after -notmatch '"updated_at"\s*:\s*"[^"\r\n]*\+00:00"') { throw 'RAW_TIMESTAMP_OFFSET_REWRITTEN' }
    Write-Output 'PASS: official isolated WAITING_to_RUNNING accepted and UTC offset preserved'
    $negativeRoot = Join-Path $temp 'negative'
    [IO.Directory]::CreateDirectory($negativeRoot) | Out-Null
    $record.state = 'WAITING'
    $record.head_sha = 'not-a-valid-sha'
    $bad = Join-Path $negativeRoot 'datekind-fixture-001.json'
    [IO.File]::WriteAllText($bad,($record|ConvertTo-Json -Depth 40)+"`n",$utf8NoBom)
    $badSha = (Get-FileHash -LiteralPath $bad -Algorithm SHA256).Hash
    $negative = Invoke-RegistryFixture -Root $negativeRoot -Command 'Validate'
    if ($negative.Exit -eq 0) { throw 'BAD_SHA_UNEXPECTEDLY_ACCEPTED' }
    if ((Get-FileHash -LiteralPath $bad -Algorithm SHA256).Hash -ne $badSha) { throw 'NEGATIVE_FIXTURE_MUTATED' }
    Write-Output 'PASS: malformed SHA refused without fixture mutation'
    Write-Output ('RUNNER=' + $PSVersionTable.PSVersion.ToString())
    Write-Output 'DATEKIND_REGRESSION_PASS=2/2'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
