<#
    run_guard_trigger_tests.ps1 -- BACKLOG-D32 cage.

    Guards the thing that decides whether any other cage runs at all.

    History this exists for: the pre-commit hook chose to run the fast tier by matching staged
    files against a hand-listed set of directories. Five times in four days a new suite guarded
    a file no entry matched, so that suite executed only when something unrelated was staged
    beside it. It looked enforced and was not, and one of those five was found only by staging a
    single file and counting the hook's output lines.

    Four checks, in order of what they catch:

      PART 1  every suite in $FAST_SUITES declares guarded paths, and nothing declares paths for
              a suite that is not in the tier. This is what makes "forgot the whole suite"
              impossible -- the two key sets must be equal.
      PART 2  every declared path is tracked in git. A declaration pointing at a path that was
              renamed is a trigger entry that matches nothing, i.e. the original defect wearing
              a declaration.
      PART 3  the committed .githooks/fast_tier_pathspec matches the declarations, and every
              declared path is actually SELECTED by it -- measured with git, not reasoned about.
      PART 4  the undeclared-reference sweep. PART 1 cannot see a declaration that lists three
              of four inputs, so every repo path a suite's source mentions must be declared or
              listed in $NOT_A_DEPENDENCY. Silence is not available.

    Run standalone; it is wired into the fast tier so it guards itself.
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

Push-Location $RepoRoot
$fail = 0
function Bad([string]$m) { Write-Host "  [FAIL] $m" -ForegroundColor Red; $script:fail++ }
function Good([string]$m) { Write-Host "  [ok]   $m" }

try {
    $ps = (Get-Process -Id $PID).Path
    if (-not $ps) { $ps = 'powershell.exe' }

    $cages = Join-Path $RepoRoot 'scripts\_test\run_fast_cages.ps1'
    $json = & $ps -NoProfile -ExecutionPolicy Bypass -File $cages -ExportGuards
    if ($LASTEXITCODE -ne 0) {
        Bad 'could not read the suite/guards table -- treating as failure, not as "nothing to check"'
        exit 1
    }
    $table = ($json | Out-String) | ConvertFrom-Json

    $suites = @($table.Suites)
    $declaredFor = @{}
    foreach ($p in $table.Guards.PSObject.Properties) { $declaredFor[$p.Name] = @($p.Value) }
    $notDep = @($table.NotADependency)

    Write-Host '[guard-trigger] PART 1 -- every suite declares what it guards'
    foreach ($s in $suites) {
        if (-not $declaredFor.ContainsKey($s) -or $declaredFor[$s].Count -eq 0) {
            Bad "suite $s is in the fast tier but declares no guarded paths"
        }
    }
    foreach ($k in $declaredFor.Keys) {
        if ($suites -notcontains $k) { Bad "guards declared for '$k', which is not in `$FAST_SUITES" }
    }
    if ($fail -eq 0) { Good "$($suites.Count) suites, all declared" }

    # One snapshot of the index, reused by every part below. The first version spawned git
    # once per declared path -- about 25 processes, 2.1s, which would have pushed the fast
    # tier past the budget that is the only reason the tier survives being a hook at all.
    $tracked = @{}
    foreach ($t in (git ls-files)) { $tracked[$t.Replace('\', '/')] = $true }

    # Glob entries still go through git, because reimplementing pathspec matching is how the
    # original trigger came to be believed correct. Three calls, not twenty-five.
    $globHits = @{}
    foreach ($s in $suites) {
        foreach ($p in $declaredFor[$s]) {
            if ($p -match '[*?]' -and -not $globHits.ContainsKey($p)) {
                $globHits[$p] = @(git ls-files -- $p)
            }
        }
    }

    Write-Host '[guard-trigger] PART 2 -- every declared path exists in git'
    $before = $fail
    foreach ($s in $suites) {
        foreach ($p in $declaredFor[$s]) {
            if ($p -match '[*?]') {
                if ($globHits[$p].Count -eq 0) { Bad "$s declares '$p', which matches no tracked file" }
            } elseif (-not $tracked.ContainsKey($p)) {
                Bad "$s declares '$p', which is not tracked in git"
            }
        }
    }
    if ($fail -eq $before) { Good 'all declared paths are tracked' }

    Write-Host '[guard-trigger] PART 3 -- the committed pathspec is current, and selects every declared path'
    $before = $fail
    & $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\gen_fast_tier_pathspec.ps1') -Check | Out-Null
    if ($LASTEXITCODE -ne 0) { Bad '.githooks/fast_tier_pathspec is stale -- run scripts/gen_fast_tier_pathspec.ps1' }

    $specPath = Join-Path $RepoRoot '.githooks\fast_tier_pathspec'
    if (-not (Test-Path -LiteralPath $specPath)) {
        Bad '.githooks/fast_tier_pathspec does not exist'
    } else {
        $spec = @(Get-Content -LiteralPath $specPath | Where-Object { $_ })
        # Measure selection with git itself. Reasoning about pathspec semantics is how the
        # original glob was believed correct for four days.
        # git ls-files emits forward slashes, so no separator normalisation is needed here.
        $selected = @{}
        foreach ($f in (git ls-files -- $spec)) { $selected[$f] = $true }
        foreach ($s in $suites) {
            foreach ($p in $declaredFor[$s]) {
                $hit = if ($p -match '[*?]') { $globHits[$p] } else { @($p) }
                foreach ($h in $hit) {
                    if (-not $selected.ContainsKey($h)) {
                        Bad "declared input '$h' (from $s) is NOT selected by the generated pathspec"
                    }
                }
            }
        }
    }
    if ($fail -eq $before) { Good 'pathspec current, and every declared input is selected by it' }

    Write-Host '[guard-trigger] PART 4 -- undeclared references sweep'
    $before = $fail
    foreach ($s in $suites) {
        $src = Get-Content -LiteralPath (Join-Path $RepoRoot "scripts\_test\$s") -Raw
        $refs = [regex]::Matches($src, '(?:scripts|docs|_triage|portfolio|tools|\.githooks)[/\\][A-Za-z0-9_./\\-]+\.(?:ps1|psm1|csv|md|json|py|exe)')
        $seen = @{}
        foreach ($m in $refs) {
            $r = $m.Value.Replace('\', '/')
            if ($seen.ContainsKey($r)) { continue }
            $seen[$r] = $true
            if (-not $tracked.ContainsKey($r)) { continue }          # synthetic fixture name
            if ($notDep -contains $r) { continue }                   # declared non-dependency
            if ($declaredFor[$s] -contains $r) { continue }          # declared
            if ("scripts/_test/$s" -eq $r) { continue }              # itself
            Bad "$s references tracked path '$r' but neither declares it nor lists it in `$NOT_A_DEPENDENCY"
        }
    }
    if ($fail -eq $before) { Good 'no suite references a tracked path it has not accounted for' }

    # -------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[guard-trigger] PART 5 -- BACKLOG-D32 per-path suite SELECTION'
    # This part exists because the repo's own memory says a path-filter must not land without a
    # targeted test: filtering the pre-commit trigger wrong means guards stop running while
    # everything still looks green. The selection is designed to fail OPEN, and these cases assert
    # that it does -- every failure mode must run MORE suites than necessary, never fewer.
    $before = $fail
    $cages = Join-Path $PSScriptRoot 'run_fast_cages.ps1'

    function Selection([string[]]$staged) {
        if ($staged) { @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -ExportSelection -StagedPaths $staged) }
        else         { @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -ExportSelection) }
    }

    # 1. no staged paths -> EVERYTHING. Manual runs and any caller that cannot determine the
    #    staged set must get the full tier.
    $all = Selection $null
    if ($all.Count -eq $table.Suites.Count) {
        Good ("no staged paths selects the whole tier ({0} suites)" -f $all.Count)
    } else {
        Bad ("no staged paths selected {0} of {1} suites -- the empty case MUST run everything" -f $all.Count, $table.Suites.Count)
    }

    # 2. every suite must be REACHABLE by something it declares. A suite nothing can select is a
    #    suite that silently never runs, which is worse than a slow tier.
    $unreachable = @()
    foreach ($s in $table.Suites) {
        $g = $table.Guards.$s
        if (-not $g -or $g.Count -eq 0) { continue }     # no guards = always runs, checked below
        $sel = Selection @($g[0])
        if ($sel -notcontains $s) { $unreachable += "$s (via $($g[0]))" }
    }
    if ($unreachable.Count -eq 0) { Good 'every guarded suite is selected by its own first declared path' }
    else { Bad ("suite(s) unreachable by their own declarations: {0}" -f ($unreachable -join '; ')) }

    # 3. PART 1 already fails any suite with no declared guards, so the "unguarded suite" case
    #    cannot exist in the real table -- the fail-open branch in Select-Suites is belt to
    #    PART 1's braces, and is documented inline there rather than tested through a synthetic
    #    table this cage would then have to keep in sync.

    # 4. THE FILTER MUST NOT BE INERT: a path guarded by one suite must select a PROPER SUBSET.
    #    Measured against a real declaration rather than a guess, so it cannot rot into a tautology.
    $oneGuard = $table.Guards.'run_guard_trigger_tests.ps1'[0]
    $subset = Selection @($oneGuard)
    if ($subset.Count -gt 0 -and $subset.Count -lt $table.Suites.Count) {
        Good ("a single guarded path selects a proper subset ({0} of {1}) -- the filter is not inert" -f $subset.Count, $table.Suites.Count)
    } else {
        Bad ("staging '{0}' selected {1} of {2} suites -- the filter is inert or empty" -f $oneGuard, $subset.Count, $table.Suites.Count)
    }

    # 5. FAIL-OPEN: staged paths that match NO suite must run EVERYTHING, not nothing.
    #    The pathspec is generated from these same guards, so "staged but unmatched" is a
    #    contradiction -- the list arrived mangled or the declarations drifted. This case is here
    #    because the first version of the feature did the opposite: the very commit that
    #    introduced per-path selection ran ZERO suites, while printing a confident selection
    #    message, because `powershell -File` bound a comma-joined list of three paths as one
    #    literal. It failed CLOSED while claiming it could only fail open.
    $unmatched = @(Selection @('no/such/path/at/all.txt') | Where-Object { $_ -like '*.ps1' })
    if ($unmatched.Count -eq $table.Suites.Count) {
        Good ('staged paths matching nothing fall back to the WHOLE tier ({0}) -- fails open' -f $unmatched.Count)
    } else {
        Bad ("staged paths matching nothing selected {0} of {1} -- this MUST fail open" -f $unmatched.Count, $table.Suites.Count)
    }

    if ($fail -eq $before) { Good 'per-path selection fails OPEN and every suite stays reachable' }

    Write-Host ''
    # -------------------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[guard-trigger] PART 6 -- ORDER-670 evidence-mode plumbing (T4 marker allowlist, T6 moved-index)'
    # The tier in -Hook mode must (a) fail when a declared evidence suite emits no marker --
    # the ALLOWLIST that replaced a "fail on the word worktree" blacklist, which passed a
    # suite that reported nothing -- and (b) refuse when the index moved mid-run. Both
    # refusals are driven here so they are OBSERVED RED, not merely written; a detector
    # nobody has seen fire is UNTESTED by the VERDICT GATE's own rule.
    $before = $fail
    # A staged path selecting only three sub-second suites, so these nested tier runs are
    # cheap; none of the three is a declared evidence suite, which is exactly what the
    # override exists to simulate.
    $cheapStaged = Join-Path ([System.IO.Path]::GetTempPath()) ("gt670_" + [guid]::NewGuid().ToString('N') + '.txt')
    Set-Content -LiteralPath $cheapStaged -Encoding ASCII -Value 'scripts/check_taskboard_archive.ps1'
    try {
        # T4 ATTACK: declare statusclass an evidence suite; it emits no marker => tier fails, naming it.
        $o1 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -Hook -StagedPathsFile $cheapStaged -EvidenceSuitesOverride @('run_statusclass_tests.ps1') 2>&1)
        if ($LASTEXITCODE -eq 1 -and (($o1 -join "`n") -match 'run_statusclass_tests\.ps1 emitted NO evidence-mode marker')) {
            Good 'T4 ATTACK a declared evidence suite emitting no marker fails the hook tier, by name'
        } else {
            Bad ("T4 ATTACK expected exit 1 naming the silent suite; got exit {0}" -f $LASTEXITCODE)
        }
        # T4 SPECIFICITY: with no evidence suite selected, the same run is green -- the
        # verifier must not fire on suites that never migrated.
        $o2 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -Hook -StagedPathsFile $cheapStaged -EvidenceSuitesOverride 'NONE' 2>&1)
        if ($LASTEXITCODE -eq 0) {
            Good 'T4 SPECIFICITY the same hook run with no evidence suite in scope is green'
        } else {
            Bad ("T4 SPECIFICITY expected exit 0; got {0}: {1}" -f $LASTEXITCODE, (($o2 | Select-Object -Last 3) -join ' | '))
        }
        # T6 ATTACK: force the end-stamp mismatch => the tier refuses and says the index moved.
        $o3 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -Hook -StagedPathsFile $cheapStaged -EvidenceSuitesOverride 'NONE' -DebugPretendIndexMoved 2>&1)
        if ($LASTEXITCODE -eq 1 -and (($o3 -join "`n") -match 'rewritten during the tier')) {
            Good 'T6 ATTACK an index rewritten mid-tier is refused, loudly'
        } else {
            Bad ("T6 ATTACK expected exit 1 naming the moved index; got {0}" -f $LASTEXITCODE)
        }
        # T4 POSITIVE, direct: the one migrated suite emits exactly one marker carrying the
        # env-selected mode through its own process chain (wrapper -> python -> evidence).
        $env:EA_LAB_EVIDENCE = 'index'
        try {
            $o4 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run_registry_tests.ps1') 2>&1)
        } finally {
            Remove-Item Env:EA_LAB_EVIDENCE -ErrorAction SilentlyContinue
        }
        $m4 = @($o4 | Where-Object { "$_" -match '^##EVIDENCE-MODE## run_registry_tests\.ps1 index\b' })
        if ($LASTEXITCODE -eq 0 -and $m4.Count -eq 1) {
            Good 'T4 POSITIVE the migrated suite emits exactly one marker, carrying mode=index from the env'
        } else {
            Bad ("T4 POSITIVE expected exit 0 with one index marker; got exit {0}, {1} marker(s)" -f $LASTEXITCODE, $m4.Count)
        }
    } finally {
        Remove-Item -LiteralPath $cheapStaged -Force -ErrorAction SilentlyContinue
    }
    if ($fail -eq $before) { Good 'evidence-mode plumbing holds in both directions' }

    if ($fail -gt 0) {
        Write-Host "[guard-trigger] $fail FAILURE(S)" -ForegroundColor Red
        exit 1
    }
    Write-Host '[guard-trigger] all parts green -- the trigger is derived from the declarations, and both are current'
    exit 0
}
finally {
    Pop-Location
}
