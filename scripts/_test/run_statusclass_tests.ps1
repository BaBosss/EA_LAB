<#
.SYNOPSIS
    Focused tests for Get-StatusClass in scripts/check_taskboard_archive.ps1 (ORDER-260).

.DESCRIPTION
    Why this file exists: the two suites that nominally cage this validator --
    run_order101_negative_tests.ps1 and run_order103_negative_tests.ps1 -- both HANG in
    this environment (measured 2026-07-26: no output, <1s CPU after 25+ minutes, no child
    processes). A cage that never runs protects nothing, so a change to the single
    function every classification decision depends on needed a cage that does run.

    Scope is deliberately narrow: status-token classification only. Every case below is
    a real status string taken from AGENT_TASKBOARD.md or ARCHIVE_TASKBOARD_2026-07A.md,
    not an invented one -- the bug being guarded against was invisible to synthetic
    inputs precisely because it needed a verdict that happened to contain the word
    "holdout".

.NOTES
    Saved as UTF-8 WITH BOM: the cases carry Thai text and em-dashes, and PowerShell 5.1
    reads a BOM-less .ps1 as ANSI, which would mangle them before any regex ran.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'

# This file lives in scripts/_test/, so the repo root is TWO levels up, not one. And
# $PSScriptRoot comes back empty under `powershell.exe -File <relative-path>` from a
# non-PowerShell shell, so fall back to $MyInvocation rather than silently computing a
# wrong root (which is how the first run of this file went looking for
# scripts\scripts\check_taskboard_archive.ps1).
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}
$validator = Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1'
. $validator -RepoRoot $RepoRoot 6>$null

$script:pass = 0
$script:fail = 0

function Assert-Status {
    param(
        [string]$Name,
        [string]$Header,
        [ValidateSet('Terminal','NonTerminal','NA','Unparseable')][string]$ExpectClass,
        [string]$ExpectLabelLike = $null
    )
    $r = Get-StatusClass -Header $Header -BlockType 'ORDER'
    $okClass = ($r.Class -eq $ExpectClass)
    $okLabel = $true
    if ($ExpectLabelLike) { $okLabel = ($r.Label -like $ExpectLabelLike) }
    if ($okClass -and $okLabel) {
        Write-Host ("  ok   {0}" -f $Name)
        $script:pass++
    } else {
        Write-Host ("  FAIL {0}" -f $Name) -ForegroundColor Red
        Write-Host ("         expected class={0} label-like='{1}'" -f $ExpectClass, $ExpectLabelLike)
        Write-Host ("         actual   class={0} label='{1}'" -f $r.Class, $r.Label)
        $script:fail++
    }
}

Write-Host '[statusclass-tests] running'

# --- the ORDER-260 regression itself: REVIEWED verdicts whose PROSE contains a
#     non-terminal vocabulary word. Before the fix these classified NonTerminal. ---
Assert-Status 'REVIEWED whose verdict says "holdout" (ORDER-167, real)' `
    '## ORDER-167 — [funnel completion] holdout ที่ค้าง — `REVIEWED(Claude/Opus 2026-07-23) — 4/5 cells ตายที่ holdout · 1 เหลือ BUILD-ON`' `
    'Terminal' 'REVIEWED*'

Assert-Status 'REVIEWED whose verdict says "open question" (ORDER-198, real)' `
    '## ORDER-198 — [ops] triage — `REVIEWED(Claude 2026-07-24): NO BUG FOUND — the "18 shortfall" is a formula artifact, one open question`' `
    'Terminal' 'REVIEWED*'

Assert-Status 'REVIEWED whose verdict says "decision open for user" (ORDER-202, real)' `
    '## ORDER-202 — [audit] retro-scan — `REVIEWED(Claude 2026-07-25) — 2 damaged, 2 survive, 1 real-money decision open for user`' `
    'Terminal' 'REVIEWED*'

# --- non-terminal statuses MUST still classify non-terminal. If anchoring broke any of
#     these, closed-looking work would be archivable while still open. ---
Assert-Status 'bare OPEN'                  '## ORDER-222 — test — `OPEN`'                                  'NonTerminal' '*OPEN*'
Assert-Status 'OPEN-STANDING'              '## ORDER-GEN-STANDING — matrix — `OPEN-STANDING`'               'NonTerminal' '*OPEN*'
Assert-Status 'OPEN with trailing prose (ORDER-095, real)' `
    '## ORDER-095 — CAMPAIGN — `OPEN (multi-session, pace 1 EA/batch) · batch 1 DONE(Claude 2026-07-14)`'   'NonTerminal' '*OPEN*'
Assert-Status 'WAITING-USER (ORDER-045, real)' `
    '## ORDER-045 — MT4 demo — `WAITING-USER (attach) → แล้วค่อยเป็น monitoring loop`'                      'NonTerminal' '*WAITING-USER*'
Assert-Status 'CLAIMED'                    '## ORDER-205 — expand — `CLAIMED(oc-qwen, 2026-07-26 10:00)`'   'NonTerminal' '*CLAIMED*'
Assert-Status 'bare HOLD'                  '## MERGE-07 — Entry_ST03 — `HOLD`'                              'NonTerminal' '*HOLD*'
Assert-Status 'IN-PROGRESS'                '## ORDER-999 — probe — `IN-PROGRESS`'                           'NonTerminal' '*IN-PROGRESS*'
Assert-Status 'leading non-letter before the verb still matches' `
    '## ORDER-999 — probe — `· OPEN`'                                                                       'NonTerminal' '*OPEN*'

# --- composite terminal verbs: label must resolve to the SELF-ATTESTING verb where one
#     is present, because only StatusLabel -like 'REVIEWED*' is archivable. ---
Assert-Status 'DONE + REVIEWED -> label REVIEWED (ORDER-218, real)' `
    '## ORDER-218 — [ops/integrity] error sweep — `DONE + REVIEWED(Claude/Opus 2026-07-25)`'                'Terminal' 'REVIEWED*'
Assert-Status 'FIXED + REVIEWED -> label REVIEWED (ORDER-203, real)' `
    '## ORDER-203 — [macro/bug] core MRIS — `FIXED + REVIEWED(Claude/Opus 2026-07-25)`'                     'Terminal' 'REVIEWED*'
Assert-Status 'DONE + VERIFIED-NEUTRAL -> label DONE, NOT archivable (ORDER-161, real)' `
    '## ORDER-161 — template — `DONE + VERIFIED-NEUTRAL(Claude 2026-07-23)`'                                'Terminal' 'DONE*'
Assert-Status 'bare DONE stays DONE (needs a linked review)' `
    '## ORDER-188 — [test] cage — `DONE(Claude/Fable 2026-07-24)`'                                          'Terminal' 'DONE*'
Assert-Status 'CLOSED-OBSOLETE -> CLOSED, not archivable' `
    '## ORDER-118 — ST03 guardrail — `CLOSED-OBSOLETE (Claude 2026-07-18)`'                                 'Terminal' 'CLOSED*'

# --- the no-backtick fallback must stay UNANCHORED. The search space there is the whole
#     header, where the verb is never at position 0. ---
Assert-Status 'no backticks, DONE mid-header (ORDER-091C-D1e, real corpus case)' `
    '## ORDER-091C-D1e — JUMSTOCH probe — DONE(Claude 2026-07-16)'                                          'Terminal' 'DONE*'
Assert-Status 'no backticks, OPEN mid-header still NonTerminal' `
    '## ORDER-999 — some probe — OPEN pending user input'                                                   'NonTerminal' '*OPEN*'

# --- unchanged behaviour worth pinning: RESOLVED is in NEITHER vocabulary. ORDER-162 uses
#     it, and it must not silently become archivable. ---
Assert-Status 'RESOLVED matches no vocabulary -> Unparseable (ORDER-162, real)' `
    '## ORDER-162 — [investigation] tester drift — `RESOLVED(Claude 2026-07-23)`'                            'Unparseable'

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host ("FAIL {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail) -ForegroundColor Red
    exit 1
}
Write-Host ("PASS {0}/{0}" -f $script:pass) -ForegroundColor Green
exit 0
