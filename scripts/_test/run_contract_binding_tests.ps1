<#
    run_contract_binding_tests.ps1 -- BACKLOG-D31 cage.

    Guards the seam that produced every regression across three blind audits of the Factory
    OS design: the normative contract written by hand in TWO places -- the design prose and
    _triage/factory_os/schemas.json -- with nothing binding them. Audit 3 measured the first
    attempt at a cure (check_schema_structure.py) against the 7 REGRESSED findings: it would
    have caught 0 of 7, and it printed STRUCTURE OK on a commit where the design described
    `attempts[]`, a lease with `pid`, and `launched_at` while the schema said the opposite.

    Two things run here, and the second is the one that matters:
      1. gen_design_contracts.py --check   -- the design's generated tables still match the schema
      2. run_contract_binding_tests.py     -- the binding still CATCHES all seven regressions,
                                              re-applied as schema mutations, with three controls
                                              proving the harness is not simply always red

    A cage that has never been shown to fail is untested by this repo's own rule, so (2) is
    not optional decoration -- it is the only evidence (1) is worth running.

    Interpreter: tools\python312\python.exe, committed in-repo. Neither script needs ajv or
    any network access; run_schema_fixtures.py is the one with the ajv dependency and it is
    deliberately NOT in this hook tier for that reason.

    MEASURED 0.4s (both scripts plus process startup). The whole fast tier re-measured at
    13.3s against its 15s budget with this suite in place.
#>
[CmdletBinding()]
param([string]$RepoRoot)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}

$python = Join-Path $RepoRoot 'tools\python312\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    # A missing interpreter is a failure, not a skip. A cage that silently opts out when its
    # tool is absent is the exact defect class this repo has hit five times: the artifact
    # keeps being produced and quietly stops being true.
    Write-Host "[contract-binding] FAIL: interpreter not found at $python" -ForegroundColor Red
    exit 1
}

$scripts = @(
    @{ Path = '_triage\factory_os\gen_design_contracts.py'; Args = @('--check') },
    @{ Path = '_triage\factory_os\run_contract_binding_tests.py'; Args = @() }
)

$failed = 0
foreach ($s in $scripts) {
    $full = Join-Path $RepoRoot $s.Path
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Host ("[contract-binding] FAIL: missing {0}" -f $s.Path) -ForegroundColor Red
        $failed++
        continue
    }
    $out = & $python $full @($s.Args) 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("[contract-binding] FAIL {0}" -f $s.Path) -ForegroundColor Red
        Write-Host ($out | Out-String)
        $failed++
    }
}

if ($failed -gt 0) { exit 1 }
Write-Host '[contract-binding] design tables match the schema, and all 7 regressions are still caught'
exit 0
