# Pure serialization boundary. Does not run a checker or change tester policy.
function New-TruncationEvidence {
    param([string]$ReportName, $CheckerExitCode, [string]$Detail)
    $status='CHECK_ERROR'
    $flag=$null
    if ($null -ne $CheckerExitCode -and $CheckerExitCode -is [int]) {
        if ($CheckerExitCode -eq 2) { $status='TRUNCATED'; $flag=$true }
        elseif ($CheckerExitCode -eq 0) {
            $status='UNKNOWN'
            if ($Detail -match '(?m)^\[FAIL\]') { $status='CHECK_ERROR' }
            elseif ($Detail -notmatch '\[UNDETERMINED\]' -and $Detail -match '(?m)^\[OK\]') {
                $status='CHECK_PASS'; $flag=$false
            }
        }
    }
    [pscustomobject][ordered]@{
        schema_version=2
        report_name=$ReportName
        check_status=$status
        checker_exit_code=$CheckerExitCode
        truncated=$flag
        detail=$Detail.Trim()
    }
}
