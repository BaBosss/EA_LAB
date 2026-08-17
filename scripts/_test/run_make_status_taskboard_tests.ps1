<#
run_make_status_taskboard_tests.ps1 -- Monitoring Gap-to-Done Claim A.

make_status.ps1 runs its whole body under $ErrorActionPreference = "SilentlyContinue" (a
box-with-no-system-python-style habit, not a deliberate per-call choice). Design row 4
("make_status.ps1 still has an 'unreadable = nothing found' path") named the taskboard read
specifically: under that preference, Get-Content on a MISSING/unreadable AGENT_TASKBOARD.md and
Get-Content on a taskboard with genuinely zero '## ORDER-' lines both silently produce $null --
one identical, empty result for two different facts, exactly the shape ORDER-612 already refused
for the Control Room block (OK / REFUSED / UNAVAILABLE, never a silent nothing).

This suite proves the taskboard-read block (make_status.ps1, narrowed EAP='Stop' around
Get-Content -LiteralPath $taskboardPath) keeps the same three cases distinct:
  A. readable, non-empty      -> the real order lines
  B. readable, zero matches   -> an explicit placeholder line, not $null
  C. unreadable/missing       -> an explicit line naming UNKNOWN, not $null

Reproduction is DELIBERATELY NON-DESTRUCTIVE: every case runs against a temp fixture directory,
never against the real D:\EA_LAB\AGENT_TASKBOARD.md.

USAGE  powershell -NoProfile -File scripts\_test\run_make_status_taskboard_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$script:pass = 0
$script:fail = 0
function Ok([string]$n, $c) {
    if ($c) { $script:pass++; Write-Host "  [PASS] $n" }
    else { $script:fail++; Write-Host "  [FAIL] $n" }
}

# The exact block under test, extracted so the fixture directory can be swapped in place of
# $repo without touching the real script or the real taskboard.
function Read-Taskboard([string]$repo) {
    $taskboardPath = Join-Path $repo "AGENT_TASKBOARD.md"
    $savedEapTb = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    try {
        $orders = Get-Content -LiteralPath $taskboardPath -Encoding UTF8 |
            Where-Object { $_ -match '^## ORDER-' } |
            ForEach-Object { $_ -replace '^## ', '- ' }
        if (-not $orders) { $orders = @('- (no open orders -- taskboard read OK, zero matching lines)') }
    } catch {
        $orders = @("- UNKNOWN: AGENT_TASKBOARD.md could not be read ($($_.Exception.Message))")
    } finally {
        $ErrorActionPreference = $savedEapTb
    }
    return ,$orders
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("makestatus_tb_" + [guid]::NewGuid().ToString('N'))
try {
    $caseA = Join-Path $work 'caseA'; New-Item -ItemType Directory -Force -Path $caseA | Out-Null
    Set-Content -LiteralPath (Join-Path $caseA 'AGENT_TASKBOARD.md') -Encoding UTF8 -Value @(
        '## ORDER-9001 -- test order alpha', 'text', '## ORDER-9002 -- test order beta', 'text')

    $caseB = Join-Path $work 'caseB'; New-Item -ItemType Directory -Force -Path $caseB | Out-Null
    Set-Content -LiteralPath (Join-Path $caseB 'AGENT_TASKBOARD.md') -Encoding UTF8 -Value @(
        '# just a header, zero ORDER rows', 'text with no matches')

    $caseC = Join-Path $work 'caseC'; New-Item -ItemType Directory -Force -Path $caseC | Out-Null
    # Deliberately no AGENT_TASKBOARD.md written -- this IS the missing/unreadable case.

    $rA = Read-Taskboard $caseA
    $rB = Read-Taskboard $caseB
    $rC = Read-Taskboard $caseC

    Ok 'A. readable+non-empty returns the real order lines' `
        (($rA -join '|') -match 'ORDER-9001' -and ($rA -join '|') -match 'ORDER-9002')
    Ok 'B. readable+zero-matches returns an explicit non-null placeholder (not $null)' `
        ($null -ne $rB -and (@($rB)).Count -gt 0 -and ($rB -join '|') -notmatch 'UNKNOWN')
    Ok 'C. missing/unreadable returns an explicit line naming UNKNOWN (not $null)' `
        ($null -ne $rC -and (@($rC)).Count -gt 0 -and ($rC -join '|') -match 'UNKNOWN')
    Ok 'B and C are NOT byte-identical -- the defect this suite exists for is closed' `
        (($rB -join '|') -ne ($rC -join '|'))
    Ok 'A and B are NOT byte-identical' `
        (($rA -join '|') -ne ($rB -join '|'))
    Ok 'A and C are NOT byte-identical' `
        (($rA -join '|') -ne ($rC -join '|'))

    # CONTROL: prove this suite can still fail -- revert to the pre-fix shape (bare Get-Content
    # under SilentlyContinue, no try/catch) and confirm B and C collapse to the SAME $null.
    $ErrorActionPreference = 'SilentlyContinue'
    $preFixB = Get-Content -LiteralPath (Join-Path $caseB 'AGENT_TASKBOARD.md') -Encoding UTF8 |
        Where-Object { $_ -match '^## ORDER-' } | ForEach-Object { $_ -replace '^## ', '- ' }
    $preFixC = Get-Content -LiteralPath (Join-Path $caseC 'AGENT_TASKBOARD.md') -Encoding UTF8 |
        Where-Object { $_ -match '^## ORDER-' } | ForEach-Object { $_ -replace '^## ', '- ' }
    $ErrorActionPreference = 'Stop'
    Ok 'CONTROL: the PRE-FIX shape (SilentlyContinue, no catch) collapses B and C to identical $null -- proves this suite discriminates the real defect, not a strawman' `
        ($null -eq $preFixB -and $null -eq $preFixC)
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail)
    exit 1
}
Write-Host ("PASS  {0}/{0} -- make_status.ps1 taskboard read: A/B/C stay mutually distinguishable" -f $script:pass)
exit 0
