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
param(
    [string]$RepoRoot,
    # ORDER-1130 T1: attribute this suite's cost to a PART, reproducibly, instead of to prose.
    [switch]$Timing
)

$ErrorActionPreference = 'Stop'

# ORDER-1130 T1. `Phase` is the only thing that may name a part, so the timing table and the
# headings cannot drift apart -- the failure the comment table in run_contract_binding_tests.ps1
# spent a year demonstrating. Prints the heading in every mode; records the clock only under
# -Timing, so an ordinary tier run pays one Stopwatch and nothing else.
$script:phaseTimes = @()
$script:phaseSw = $null
$script:phaseName = $null
# CAPTURED AT START, NOT AT REPORT TIME, and this is not a style preference: PART 6 sets
# EA_LAB_EVIDENCE and REMOVES it again in its finally block, so a report that read the variable
# at the end printed `worktree (default)` for a run launched with index. Observed on this
# instrumentation's first run. A number labelled with a mode that was not the mode is worse than
# an unlabelled number, because it is quotable.
$script:phaseMode = if ($env:EA_LAB_EVIDENCE) { $env:EA_LAB_EVIDENCE } else { 'worktree (default)' }
function Phase([string]$title) {
    if ($script:phaseSw) {
        $script:phaseSw.Stop()
        $script:phaseTimes += [pscustomobject]@{
            Phase = $script:phaseName
            Seconds = [math]::Round($script:phaseSw.Elapsed.TotalSeconds, 2)
        }
    }
    Write-Host $title
    $script:phaseName = $title
    $script:phaseSw = [System.Diagnostics.Stopwatch]::StartNew()
}
function PhaseReport([string]$label) {
    if ($script:phaseSw) {
        $script:phaseSw.Stop()
        $script:phaseTimes += [pscustomobject]@{
            Phase = $script:phaseName
            Seconds = [math]::Round($script:phaseSw.Elapsed.TotalSeconds, 2)
        }
        $script:phaseSw = $null
    }
    if (-not $Timing) { return }
    Write-Host ''
    Write-Host ("[$label] TIMING -- evidence mode: {0}" -f $script:phaseMode)
    foreach ($t in $script:phaseTimes) {
        Write-Host ('    {0,-72} {1,6:N2}s' -f $t.Phase, $t.Seconds)
    }
    Write-Host ('    {0,-72} {1,6:N2}s' -f 'SUM OF PHASES',
                ($script:phaseTimes | Measure-Object -Property Seconds -Sum).Sum)
}

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

    Phase '[guard-trigger] PART 1 -- every suite declares what it guards'
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

    Phase '[guard-trigger] PART 2 -- every declared path exists in git'
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

    Phase '[guard-trigger] PART 3 -- the committed pathspec is current, and selects every declared path'
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

    Phase '[guard-trigger] PART 4 -- undeclared references sweep'
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

    # ORDER-702. THE SWEEP ABOVE IS EXACTLY ONE LEVEL TOO SHALLOW, and that is not a nit: it
    # scans each .ps1 WRAPPER for path-shaped strings, but a wrapper's real dependency is what
    # its .py RUNS -- and `import evidence` is a MODULE NAME, not a path. Measured before this
    # was written: `git ls-files -- <pathspec>` matched registry.py (1) and evidence.py (0), so
    # a commit touching ONLY evidence.py -- the module ORDER-670 exists to provide, which every
    # migrated checker's correctness depends on -- ran ZERO cages. It was edited in this very
    # batch and the tier fired only because another declared file happened to be staged too.
    #
    # DERIVED, NOT HAND-ADDED (E2). Adding evidence.py to one guard list fixes today and leaves
    # the next import invisible, which is the hand-maintained cache of reality L0 exists to stop.
    $before = $fail
    $importRe = [regex]'(?m)^\s*(?:from\s+([A-Za-z_][A-Za-z0-9_]*)|import\s+([A-Za-z_][A-Za-z0-9_]*))'
    foreach ($s in $suites) {
        $pyFiles = @($declaredFor[$s] | Where-Object { $_ -like '*.py' })
        $ownPy = '_triage/factory_os/' + ($s -replace '\.ps1$', '.py')
        if ($tracked.ContainsKey($ownPy) -and $pyFiles -notcontains $ownPy) { $pyFiles += $ownPy }
        # THE TRANSITIVE CLOSURE, walked here rather than one level per commit. Reporting only
        # direct imports makes the sweep converge by repeated commits -- declare A, next run
        # demands B, declare B, next run demands C -- and each of those intermediate runs is a
        # RED tier for a reason that is not a defect. It also means the list is never provably
        # complete at any single moment. Walking it makes one run answer the whole question.
        $seen = @{}
        $stack = New-Object System.Collections.Generic.Stack[string]
        foreach ($p in $pyFiles) { $stack.Push($p); $seen[$p] = $true }
        while ($stack.Count -gt 0) {
            $py = $stack.Pop()
            $full = Join-Path $RepoRoot ($py -replace '/', '\')
            if (-not (Test-Path -LiteralPath $full)) { continue }
            $pysrc = Get-Content -LiteralPath $full -Raw
            foreach ($m in $importRe.Matches($pysrc)) {
                $mod = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
                $modRel = "_triage/factory_os/$mod.py"
                # Only a REPO FILE can be an input. `import io`, `import json`, `import ajv` are
                # not repo files and must never be demanded -- a guard that asks for a
                # declaration of the standard library is a guard people switch off, and it is
                # the specificity half of this check.
                if (-not $tracked.ContainsKey($modRel)) { continue }
                if ($seen.ContainsKey($modRel)) { continue }
                $seen[$modRel] = $true
                $stack.Push($modRel)
                if ($notDep -contains $modRel) { continue }
                if ($declaredFor[$s] -contains $modRel) { continue }
                Bad ("$s reaches '$modRel' through the imports of $py, but declares neither. A " +
                     "commit touching only that module would run no cage at all -- the " +
                     "wrapper's path-string sweep cannot see an ``import``.")
            }
        }
    }
    if ($fail -eq $before) {
        Good 'every tracked module a suite IMPORTS is declared -- the sweep follows the wrapper into its python'
    }

    # /scrutinize round 2: THE SWEEP ABOVE HAD NO NEGATIVE. It fired on 12 real undeclared
    # dependencies once, which is genuine observed-red -- and then every one was declared, so from
    # the next commit onward it matches nothing and prints green forever. A regex typo, a broken
    # closure walk, or an accidentally-emptied $pyFiles would all be invisible. That is shape 3 in
    # a check written the same hour, so it gets a fixture that does not depend on the repo being
    # broken.
    $before = $fail
    $tmpPy = Join-Path ([System.IO.Path]::GetTempPath()) ("gt702_" + [guid]::NewGuid().ToString('N') + '.py')
    try {
        # ATTACK: a module that imports a TRACKED repo module, with nothing declared for it.
        Set-Content -LiteralPath $tmpPy -Encoding ASCII -Value "import evidence`nimport registry`n"
        $hits = @()
        foreach ($m in $importRe.Matches((Get-Content -LiteralPath $tmpPy -Raw))) {
            $mod = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
            if ($tracked.ContainsKey("_triage/factory_os/$mod.py")) { $hits += $mod }
        }
        if ($hits.Count -eq 2) {
            Good 'PART 4b NEG the import matcher finds tracked repo modules (evidence, registry)'
        } else {
            Bad ("PART 4b NEG expected 2 tracked imports, found $($hits.Count) -- the matcher is " +
                 'no longer able to see an import, and the green above means nothing')
        }
        # SPECIFICITY: stdlib and third-party imports must NOT be demanded. A guard that asks you
        # to declare `import json` is a guard people switch off, which is the 2026-07-30 lesson.
        Set-Content -LiteralPath $tmpPy -Encoding ASCII -Value "import io`nimport json`nfrom collections import OrderedDict`n"
        $stray = @()
        foreach ($m in $importRe.Matches((Get-Content -LiteralPath $tmpPy -Raw))) {
            $mod = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
            if ($tracked.ContainsKey("_triage/factory_os/$mod.py")) { $stray += $mod }
        }
        if ($stray.Count -eq 0) {
            Good 'PART 4b SPECIFICITY stdlib imports are not demanded as declarations'
        } else {
            Bad "PART 4b SPECIFICITY the sweep would demand declarations for: $($stray -join ', ')"
        }
    } finally {
        Remove-Item -LiteralPath $tmpPy -Force -ErrorAction SilentlyContinue
    }
    if ($fail -eq $before) { Good 'the import sweep can still fire, and does not fire on the standard library' }

    # -------------------------------------------------------------------------------------
    Write-Host ''
    Phase '[guard-trigger] PART 5 -- BACKLOG-D32 per-path suite SELECTION'
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

    # 4b. A SUITE'S OWN FILE MUST SELECT IT. Added 2026-08-01 after staging
    #     run_front_guard_evidence_tests.ps1 alone ran two OTHER suites and skipped the one being
    #     edited: the pathspec generator has always claimed every suite implicitly guards itself,
    #     and Select-Suites matched only $SUITE_GUARDS, which never lists a suite's own path. The
    #     claim was true of the TRIGGER and false of the SELECTION, so the edit that breaks a cage
    #     was the one edit its cage did not run.
    #     SPECIFICITY in the same case: it must select that suite WITHOUT falling back to the
    #     whole tier, or "selected" would just be the fail-open branch wearing the right answer.
    #     THREE SUITES, NOT SIXTEEN, and the number is a measured trade rather than a shrug: each
    #     Selection call is a PowerShell process (~0.29s), so all sixteen cost 4.6s against 7s of
    #     full-tier headroom. Self-selection is ONE line in Select-Suites applying uniformly to
    #     every suite, so three instances catch its regression exactly as well as sixteen; the
    #     sixteenth would only pay for itself if selection ever became per-suite. If it does, this
    #     loop widens and something else in the tier gets displaced.
    $selfProbe = @($table.Suites[0], $table.Suites[[int]($table.Suites.Count / 2)],
                   $table.Suites[$table.Suites.Count - 1]) | Select-Object -Unique
    $selfMissed = @()
    $selfWide = @()
    foreach ($s in $selfProbe) {
        if ($table.Suites -notcontains $s) { Bad ("PART 4b probes '{0}', which is not in the suite table" -f $s); continue }
        $sel = Selection @('scripts/_test/' + $s)
        if ($sel -notcontains $s) { $selfMissed += $s }
        elseif ($sel.Count -eq $table.Suites.Count) { $selfWide += $s }
    }
    if ($selfMissed.Count -eq 0) {
        Good ("a suite's own file selects it ({0} probed: {1}), not the fail-open branch" -f $selfProbe.Count, ($selfProbe -join ', '))
    } else {
        Bad ("staging a suite's own file did not select it: {0}" -f ($selfMissed -join ', '))
    }
    if ($selfWide.Count -gt 0) {
        Bad ("staging only {0} selected the WHOLE tier -- that is fail-open, not self-selection" -f ($selfWide -join ', '))
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
    Phase '[guard-trigger] PART 6 -- ORDER-670 evidence-mode plumbing (T4 marker allowlist, T6 moved-index)'
    # The tier in -Hook mode must (a) fail when a declared evidence suite emits no marker --
    # the ALLOWLIST that replaced a "fail on the word worktree" blacklist, which passed a
    # suite that reported nothing -- and (b) refuse when the index moved mid-run. Both
    # refusals are driven here so they are OBSERVED RED, not merely written; a detector
    # nobody has seen fire is UNTESTED by the VERDICT GATE's own rule.
    $before = $fail
    # A staged path selecting ONE sub-second suite, because this part runs the nested tier THREE
    # times and pays for every selected suite three times over.
    #
    # 2026-07-31: it used to stage `scripts/check_taskboard_archive.ps1` under the comment "a
    # staged path selecting only three sub-second suites". That was true when it was written and
    # stopped being true the moment another suite declared `scripts/check_*.ps1` -- the fixture
    # then pulled in an 18s suite and PART 6 went 7s -> 106s, breaching the per-path budget on
    # the commit that made the declaration. Nothing was wrong with the declaration; the fixture's
    # CHEAPNESS WAS AN UNDECLARED ASSUMPTION about somebody else's table.
    # So: the pair moved to `docs/SESSION_LEDGER.md` + `run_order_collision_tests.ps1` (the same
    # cheap pair PART 7 already uses), and the assumption is ASSERTED below instead of assumed.
    $cheapStaged = Join-Path ([System.IO.Path]::GetTempPath()) ("gt670_" + [guid]::NewGuid().ToString('N') + '.txt')
    Set-Content -LiteralPath $cheapStaged -Encoding ASCII -Value 'docs/SESSION_LEDGER.md'
    try {
        # THE COST ASSUMPTION, CHECKED. If a future declaration widens what this path selects,
        # this says so in one line instead of being discovered as a budget breach three parts later.
        $cheapSel = @(Selection @('docs/SESSION_LEDGER.md'))
        if ($cheapSel.Count -le 2) {
            Good ("PART 6's fixture path still selects {0} suite(s) -- the nested runs stay cheap" -f $cheapSel.Count)
        } else {
            # PARENTHESISED AS ONE STRING. `"a" + "b" -f $x` parses as `"a" + ("b" -f $x)`, so only
            # the LAST fragment is formatted and every {0} above it prints literally. This exact
            # message did that when it was first observed red -- it named neither the count nor the
            # suites, which are the only two facts it exists to carry. Same trap the ORDER-674
            # library hit; caught here only because the case was DRIVEN red instead of reasoned red.
            Bad (("PART 6's fixture path now selects {0} suites ({1}) and this part runs the tier " +
                  "THREE times. Pick a cheaper staged path, or accept the cost in the budget " +
                  "deliberately -- do not leave it to be found as a breach.") -f $cheapSel.Count, ($cheapSel -join ', '))
        }
        # T4 ATTACK: declare the selected suite an evidence suite; it emits no marker => tier
        # fails, naming it. The suite named here MUST be one the fixture path selects, or the
        # attack would pass for the wrong reason (nothing in scope to be silent).
        $o1 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -Hook -StagedPathsFile $cheapStaged -EvidenceSuitesOverride @('run_order_collision_tests.ps1') 2>&1)
        if ($LASTEXITCODE -eq 1 -and (($o1 -join "`n") -match 'run_order_collision_tests\.ps1 emitted NO evidence-mode marker')) {
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

    # -------------------------------------------------------------------------------------
    Write-Host ''
    Phase '[guard-trigger] PART 7 -- ORDER-673 the time budget is ENFORCED, not advisory'
    # It printed yellow and exited 0 for days while breached. This drives the refusal so it is
    # OBSERVED, and the control so the refusal is not simply "always fail".
    $before = $fail
    $cheap7 = Join-Path ([System.IO.Path]::GetTempPath()) ("gt673_" + [guid]::NewGuid().ToString('N') + '.txt')
    Set-Content -LiteralPath $cheap7 -Encoding ASCII -Value 'docs/SESSION_LEDGER.md'
    try {
        # ATTACK: pad past the per-path budget => exit 1, and the message NAMES a suite (N3).
        # THE PAD AND THE BUDGET ARE BOTH PASSED, deliberately. The first version padded 40s
        # against a hardcoded 30.0s production default; when that default was raised to 65.0 the
        # attack stopped firing and this case went GREEN WHILE PROVING NOTHING -- a test whose
        # ability to fail depended on a constant it did not control. Both sides are now the
        # case's own, so it fires whatever the production numbers become.
        $b1 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -StagedPathsFile $cheap7 -BudgetSeconds 2 -DebugPadSeconds 5 2>&1)
        $b1t = ($b1 -join "`n")
        if ($LASTEXITCODE -eq 1 -and $b1t -match 'OVER BUDGET' -and $b1t -match 'run_order_collision_tests\.ps1\s+\S+s\s+=') {
            Good 'N2/N3 ATTACK over budget FAILS the tier and names the suite with its share'
        } else {
            Bad ("N2/N3 ATTACK expected exit 1 with a named suite; got exit {0}" -f $LASTEXITCODE)
        }
        # SPECIFICITY 1: the same run unpadded is green AND prints the headroom, so the next
        # person can see what is left BEFORE spending it. A budget first heard about when a
        # commit breaks is a budget discovered by breaking a commit.
        $b2 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -StagedPathsFile $cheap7 2>&1)
        if ($LASTEXITCODE -eq 0 -and (($b2 -join "`n") -match 'budget: .*headroom')) {
            Good 'N2 SPECIFICITY a normal run is green and states its remaining headroom'
        } else {
            Bad ("N2 SPECIFICITY expected exit 0 with a headroom line; got exit {0}" -f $LASTEXITCODE)
        }
        # SPECIFICITY 2: the two budgets are DIFFERENT numbers for different claims. A pad that
        # would bust the per-path budget must NOT bust the full-tier one -- one number would
        # either fail every full run or excuse every selected run.
        $b3 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -StagedPathsFile $cheap7 -BudgetSeconds 100 -DebugPadSeconds 5 2>&1)
        if ($LASTEXITCODE -eq 0) {
            Good 'N1 SPECIFICITY the per-path budget is a separate, separately-settable number'
        } else {
            Bad ("N1 SPECIFICITY raising only the per-path budget did not clear the run; exit {0}" -f $LASTEXITCODE)
        }
    } finally {
        Remove-Item -LiteralPath $cheap7 -Force -ErrorAction SilentlyContinue
    }
    # AND PIN THE PRODUCTION NUMBERS. Making the cases budget-independent (above) removed their
    # dependence on the defaults -- which also means they can no longer notice a default being
    # changed silently. Both properties are wanted, so the defaults are asserted separately, and
    # the values here are the ones the commit that set them measured.
    $cagesSrc = Get-Content -LiteralPath $cages -Raw
    # RAISED 2026-08-02 by ORDER-1100: per-path 65.0 -> 90.0 (measured worst green selection
    # 81.1s, of which 78.2s predates that slice) and full tier 90.0 -> 120.0 (measured 107.0s,
    # already 90.4s before the slice opened). These two lines are the friction that makes raising
    # a budget a deliberate two-file act, so they are updated WITH the numbers rather than to
    # match whatever the other file now says -- the point is that someone had to type them.
    if ($cagesSrc -match '\$BudgetSeconds\s*=\s*90\.0') { Good 'N1 the per-path default is the measured 90.0s' } else { Bad 'N1 the per-path default is not 90.0 -- it was changed without this case being updated' }
    if ($cagesSrc -match '\$FullTierBudgetSeconds\s*=\s*120\.0') { Good 'N1 the full-tier default is the measured 120.0s' } else { Bad 'N1 the full-tier default is not 120.0 -- it was changed without this case being updated' }
    if ($fail -eq $before) { Good 'the budget can fail, and does not fail a healthy run' }

    # Reported before BOTH exits: a suite that only attributes its cost when it passes cannot
    # answer "which part got slow" on the run where that question is actually being asked.
    PhaseReport 'guard-trigger'
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
