param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference='Stop'
. (Join-Path $Root 'scripts\lib\truncation_evidence.ps1')
$cases=@(
    @{code=0;detail='[OK] reached the window end within tolerance';status='CHECK_PASS';flag=$false},
    @{code=2;detail='[SUSPECT] stopped early';status='TRUNCATED';flag=$true},
    @{code=-1;detail='truncation check failed: synthetic exception';status='CHECK_ERROR';flag=$null},
    @{code=1;detail='[FAIL] report not found';status='CHECK_ERROR';flag=$null},
    @{code=$null;detail='[OK]';status='CHECK_ERROR';flag=$null},
    @{code=0;detail='[UNDETERMINED] check HAS NO POWER';status='UNKNOWN';flag=$null},
    @{code=0;detail='[INFO] no deals in report - nothing to judge';status='UNKNOWN';flag=$null},
    @{code=0;detail='';status='UNKNOWN';flag=$null},
    @{code=0;detail="[OK] earlier line`n[FAIL] later error";status='CHECK_ERROR';flag=$null}
)
foreach($case in $cases){
    $row=New-TruncationEvidence -ReportName 'FIXTURE_NO_MT5' -CheckerExitCode $case.code -Detail $case.detail
    if($row.check_status -cne $case.status -or $row.truncated -cne $case.flag){throw "classification mismatch code=$($case.code) expected=$($case.status) actual=$($row.check_status)"}
    if($row.checker_exit_code -cne $case.code){throw 'exit code lost'}
}
Write-Output "TRUNCATION_EVIDENCE PASS cases=$($cases.Count) mt5_runs=0"
