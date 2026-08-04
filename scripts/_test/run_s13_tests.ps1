<#
run_s13_tests.ps1 -- ORDER-1210 (slice S13).

Drives the cage for _triage/factory_os/check_pilot_acceptance.py, which turns design section 8.6
-- "the pass/fail for the whole Stage-4 pilot" -- from fourteen markdown tickboxes into a
mechanical verdict about EVIDENCE COMPLETENESS.

WHAT THE CAGE IS FOR, stated here because the suite's shape only makes sense with it: the checker's
commonest answer today is BLOCKED (most of the pilot has not been run). A reporter whose usual
output is "not yet" is trivially green and would keep saying "not yet" long after the mechanism
under it had rotted. So the cases attack the three ways it could be wrong -- the checklist and the
handlers drifting apart, BLOCKED quietly satisfying the roll-up, and the process dying with its
reason swallowed -- rather than the one way it is right.

🚫 design section 10 stops this slice's automation at EVIDENCE_COMPLETE. PART 4 of the suite
asserts the checker emits no verdict vocabulary, and drives a handler that WOULD emit one to prove
the detector fires.

ASCII-only (Windows PowerShell 5.1 decodes a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_s13_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$python = Join-Path $RepoRoot 'tools\python312\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    # A missing interpreter is a FAILURE, not a skip. A cage that silently opts out when its tool
    # is absent is the defect class this repo has hit five times.
    Write-Host "[s13] FAIL: interpreter not found at $python" -ForegroundColor Red
    exit 1
}

# 🔴 REQUIRED, and it is not boilerplate. design 8.6's own wording carries `section`, `<=` and `.`
# as non-ASCII glyphs, and this suite PRINTS the checklist. python takes its stdout encoding from
# the console codepage, so a child of the pre-commit hook gets an ANSI-codepage pipe and the first
# such character raises UnicodeEncodeError -- which the tier surfaces as `exit -1 SUITE THREW`
# with the cause swallowed. It took down S11's suite latently for as long as that suite existed
# (memory `thai-output-kills-a-suite-inside-the-hook`). Reproduce the failure with `chcp 1252`.
# The module ALSO reconfigures its own streams; both are kept, because this wrapper is not the
# only caller and the module is not the only thing that prints.
$prevEnc = $env:PYTHONIOENCODING
$env:PYTHONIOENCODING = 'utf-8'
try {
    $out = & $python (Join-Path $RepoRoot '_triage\factory_os\run_s13_tests.py') 2>&1
    $rc = $LASTEXITCODE
    Write-Host ($out | Out-String).TrimEnd()
    if ($rc -ne 0) {
        Write-Host "[s13] FAIL: the S13 cage exited $rc" -ForegroundColor Red
        exit 1
    }

    # ...and DRIVE the real checker over the real repository, which the cage above deliberately
    # does not do (its fixtures are synthetic so it stays green whatever the pilot's state
    # becomes). This half asserts the checker can still RUN end-to-end against committed
    # evidence -- a module that only works on fixtures is the `pure-cage-proves-only-the-pure-half`
    # shape, and 9 of 9 defects in that memory lived in the half the pure cage could not reach.
    #
    # Exit codes: 0 EVIDENCE_COMPLETE - 1 at least one item FAIL - 2 the checker could not answer
    # - 3 blocked only. Only 2 is a failure OF THIS SUITE: 1 and 3 are the checker working and
    # reporting honestly about a pilot that has not been run. Treating 1 or 3 as red here would
    # make this cage go permanently red for a true report, which is how a suite earns being
    # switched off.
    $real = & $python (Join-Path $RepoRoot '_triage\factory_os\check_pilot_acceptance.py') 2>&1
    $realRc = $LASTEXITCODE
    $realText = ($real | Out-String)
    if ($realRc -eq 2) {
        Write-Host '[s13] FAIL: check_pilot_acceptance REFUSED against the real repository --' -ForegroundColor Red
        Write-Host '       the checklist binding or an input read is broken. This is a defect in' -ForegroundColor Red
        Write-Host '       the checker, NOT a statement about the pilot.' -ForegroundColor Red
        Write-Host $realText.TrimEnd()
        exit 1
    }
    if ($realRc -notin @(0, 1, 3)) {
        Write-Host "[s13] FAIL: check_pilot_acceptance returned an undeclared exit code $realRc" -ForegroundColor Red
        exit 1
    }
    # The marker proves WHICH BYTES were judged, and the tier verifies it per suite.
    if ($realText -notmatch '##EVIDENCE-MODE## check_pilot_acceptance ') {
        Write-Host '[s13] FAIL: the real run emitted no evidence-mode marker' -ForegroundColor Red
        exit 1
    }
    # The roll-up line must always be present -- a run that printed items and then died before
    # summarising is the "guard reports nothing" shape, and it would otherwise look like a pass.
    if ($realText -notmatch '\[pilot-acceptance\] \d+ item\(s\):') {
        Write-Host '[s13] FAIL: the real run printed no roll-up line' -ForegroundColor Red
        Write-Host $realText.TrimEnd()
        exit 1
    }
    # @() IS LOAD-BEARING. A Where-Object yielding exactly ONE line returns a bare [string], and
    # `[0]` then indexes into that STRING and hands back a [char] -- which has no .Trim(). This
    # line threw on its first run for precisely that reason. Same family as memory
    # `powershell-pipeline-count-null-on-single-result`, and it is always one match here, so the
    # unwrapped form would have failed every single time rather than intermittently.
    $summary = @($realText -split "`n" | Where-Object { $_ -match '\[pilot-acceptance\] \d+ item' })[0]
    Write-Host ''
    Write-Host ('[s13] real repository: ' + $summary.Trim())

    # --- ORDER-1272 -----------------------------------------------------------------------
    # `gen_pilot_cells.py --check` is the ONLY thing standing between `factory/coverage.jsonl` and
    # a hand edit, and until this block existed NOTHING RAN IT -- one grep returned the generator
    # and no other caller. `factory/coverage.jsonl` did trigger this suite, so a hand edit ran the
    # ACCEPTANCE cases, which read the store and would happily agree with whatever it said.
    # Nothing re-derived it from its source. `declared-as-trigger-but-never-read`, exactly.
    #
    # Its cage runs FIRST and the real re-derivation second, in that order on purpose: if the
    # checker is broken, "the store matches" is not information.
    # EAP=Continue around both children. Under 'Stop' a native command writing to stderr can raise
    # NativeCommandError and kill this script before it reaches its own diagnosis -- measured on the
    # sibling suite `run_selection_tests.ps1`, where exactly that hid a real defect behind a
    # PowerShell stack trace. Forcing a traceback out of gen_pilot_cells here did NOT reproduce it,
    # which is precisely why the guard goes in: the two suites should not differ on a mechanism
    # nobody can explain.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $cage = & $python (Join-Path $RepoRoot '_triage\factory_os\run_pilot_cells_tests.py') 2>&1
    $cageRc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    if ($cageRc -ne 0) {
        Write-Host '[s13] FAIL: the gen_pilot_cells cage went red -- the drift detector itself is' -ForegroundColor Red
        Write-Host '       broken, so nothing it says about the store can be believed.' -ForegroundColor Red
        Write-Host ($cage | Out-String).TrimEnd()
        exit 1
    }
    Write-Host (($cage | Out-String).TrimEnd() -split "`n" | Select-Object -Last 1)

    $ErrorActionPreference = 'Continue'
    $gen = & $python (Join-Path $RepoRoot '_triage\factory_os\gen_pilot_cells.py') '--check' 2>&1
    $genRc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    $genText = ($gen | Out-String)
    # Exit codes are THREE, not two: 0 the store re-derives, 1 DRIFT, 2 the reader could not
    # answer. 2 must not be reported as drift -- telling a committer their store is wrong when
    # what happened is that nothing could read it sends them to fix the wrong file.
    if ($genRc -eq 2) {
        Write-Host '[s13] FAIL: gen_pilot_cells --check CANNOT ANSWER (exit 2) -- an input could' -ForegroundColor Red
        Write-Host '       not be read from the snapshot in force. This is a reader failure, NOT' -ForegroundColor Red
        Write-Host '       a statement that the coverage store is wrong.' -ForegroundColor Red
        Write-Host $genText.TrimEnd()
        exit 1
    }
    if ($genRc -ne 0) {
        Write-Host '[s13] FAIL: factory/coverage.jsonl does not match what the run evidence' -ForegroundColor Red
        Write-Host '       generates. The store is GENERATED -- re-run gen_pilot_cells.py --apply,' -ForegroundColor Red
        Write-Host '       or explain the row it calls UNDERIVABLE. Do not hand-edit the store.' -ForegroundColor Red
        Write-Host $genText.TrimEnd()
        exit 1
    }
    # The marker proves WHICH BYTES were re-derived from. Without it a green --check in the hook
    # could have been a green --check of the working tree, which is the defect this migration closed.
    if ($genText -notmatch '##EVIDENCE-MODE## gen_pilot_cells ') {
        Write-Host '[s13] FAIL: gen_pilot_cells --check emitted no evidence-mode marker' -ForegroundColor Red
        exit 1
    }
    Write-Host (($genText.TrimEnd() -split "`n" | Select-Object -Last 1))

    # --- ORDER-1273 step 6 ------------------------------------------------------------------
    # Same question as the block above, asked of the store one directory away:
    # `factory/runs/pilot/verification/` is generated evidence and nothing re-derived it either.
    # ORDER-1272 closed this for `factory/coverage.jsonl`, the next lane recreated it for
    # `selection/`, and this store was the third instance. It is wired HERE rather than as a new
    # tier entry deliberately: registering a suite means editing `$FAST_SUITES` and
    # `.githooks/fast_tier_pathspec`, which a concurrently ACTIVE lane declares in the ledger, and
    # this suite is 0.1s (measured 97/98/99 ms) against a full-tier headroom of ~19s that the two
    # lanes spend independently.
    $prevEap2 = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $vcage = & $python (Join-Path $RepoRoot 'scripts\_test\run_pilot_verify_tests.py') 2>&1
    $vcageRc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap2
    if ($vcageRc -ne 0) {
        Write-Host '[s13] FAIL: the pilot-verify cage went red -- the surface lookup and the' -ForegroundColor Red
        Write-Host '       verification-store checker cannot be believed while it is.' -ForegroundColor Red
        Write-Host ($vcage | Out-String).TrimEnd()
        exit 1
    }
    Write-Host (($vcage | Out-String).TrimEnd() -split "`n" | Select-Object -Last 1)

    $ErrorActionPreference = 'Continue'
    $vc = & $python (Join-Path $RepoRoot 'scripts\pilot_verify_check.py') 2>&1
    $vcRc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap2
    $vcText = ($vc | Out-String)
    # THREE exit codes again, and 2 is the one that must not block a commit. The reports live under
    # `_mt5_auto/reports/`, which is gitignored by design at 3-4 MB per file -- so on any clone that
    # legitimately lacks them this is "not on this machine", reported and skipped, never merged with
    # "the evidence is wrong" and never with a pass. A suite on the commit path that asserted
    # against those artefacts blocked every such commit once already, this month.
    if ($vcRc -eq 2) {
        Write-Host ('[s13] pilot_verify_check: SKIPPED -- ' + ($vcText.TrimEnd() -split "`n" | Select-Object -Last 1)) -ForegroundColor DarkYellow
    } elseif ($vcRc -ne 0) {
        # The remedy line comes from the checker's own output below, not from prose here: naming the
        # runner's path in this file makes the trigger-map guard read it as an undeclared
        # dependency, and it cannot tell a path that is read from one that is mentioned.
        Write-Host '[s13] FAIL: a verification record no longer matches the report it names.' -ForegroundColor Red
        Write-Host $vcText.TrimEnd()
        exit 1
    } else {
        Write-Host ($vcText.TrimEnd() -split "`n" | Select-Object -Last 1)
    }

    Write-Host '[s13] S13 cage green; the 8.6 checklist is derived from the design, not restated here'
    exit 0
} finally {
    if ($null -eq $prevEnc) { Remove-Item Env:PYTHONIOENCODING -ErrorAction SilentlyContinue }
    else { $env:PYTHONIOENCODING = $prevEnc }
}
