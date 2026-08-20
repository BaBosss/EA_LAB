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
              of four inputs, so every repo path a suite's wrapper or Python body mentions must
              be declared or listed in $NOT_A_DEPENDENCY. Root-level paths are included; silence
              is not available.

    Run standalone; it is wired into the fast tier so it guards itself.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    # ORDER-1130 T1: attribute this suite's cost to a PART, reproducibly, instead of to prose.
    [switch]$Timing,
    # D-F5 / PART 8. TEST SEAM, and deliberately a seam rather than a second implementation:
    # run_reverse_completeness_negative_tests.ps1 drives THIS script with a fabricated registry
    # so the firing direction is proven by the production code, not by a copy of it. Defaults to
    # the real registry, so an ordinary run and the hook are unaffected.
    [string]$RegistryPath = ''
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
    $notDepBySuite = @{}
    foreach ($p in $table.NotADependencyBySuite.PSObject.Properties) { $notDepBySuite[$p.Name] = @($p.Value) }
    function IsNotDependency([string]$suite, [string]$path) {
        return ($notDep -contains $path) -or ($notDepBySuite.ContainsKey($suite) -and
            $notDepBySuite[$suite] -contains $path)
    }

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
    # ORDER-1284: the old expression only matched directory-prefixed paths in PowerShell
    # wrappers. That missed root-level governance files and all paths named by a Python body.
    # Keep the expression deliberately file-shaped and repository-root bounded: a bare word
    # ending in .md in prose is considered, then tracked/declaration filtering decides whether
    # it is a real input or an explicit fixture exemption.
    $repoPathRe = [regex]'(?<![A-Za-z0-9_./\\-])(?:(?:(?:scripts|docs|_triage|portfolio|tools|\.githooks)[/\\][A-Za-z0-9_./\\-]+\.(?:ps1|psm1|csv|md|json|py|exe))|(?:[A-Za-z0-9_.-]+\.(?:ps1|psm1|csv|md|json|py|exe)))(?![A-Za-z0-9_./\\-])'
    foreach ($s in $suites) {
        $src = Get-Content -LiteralPath (Join-Path $RepoRoot "scripts\_test\$s") -Raw
        $refs = $repoPathRe.Matches($src)
        $seen = @{}
        foreach ($m in $refs) {
            $r = $m.Value.Replace('\', '/')
            if ($seen.ContainsKey($r)) { continue }
            $seen[$r] = $true
            if (-not $tracked.ContainsKey($r)) { continue }          # synthetic fixture name
            if (IsNotDependency $s $r) { continue }                  # declared non-dependency
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
                if (IsNotDependency $s $modRel) { continue }
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
    # PART 4c -- ORDER-1310 #7. THE SWEEPS ABOVE READ THE WRAPPER AND ITS IMPORTS. NEITHER CAN
    # SEE A PATH A CHECKER JUDGES THROUGH A MODULE CONSTANT. Both S2a checkers do exactly that,
    # and the independent review found both: check_coverage_transfer reads `SCHEMAS_PATH` for
    # A3's native-row allowlist, and check_s2a_migration's C3 io.open()s each `UNOWNABLE`
    # evidence file and requires the quoted claim sentence to still be there. Measured at HEAD
    # before this part was written: staging schemas.json selected 6 suites and staging the design
    # doc selected 2, and run_s2a_cages.ps1 was in NEITHER -- so a design-only edit deleting one
    # UNOWNABLE sentence invalidated C3 with the cage never running.
    #
    # The required set is DERIVED from the checkers' own constants, so a checker that starts
    # judging a NEW file declares it here by construction rather than by somebody remembering.
    $before = $fail
    $pyExe = Join-Path $RepoRoot 'tools\python312\python.exe'
    if (-not (Test-Path -LiteralPath $pyExe)) {
        Bad "PART 4c cannot run: no interpreter at $pyExe (this is a TOOL failure, not a pass)"
    } else {
        $probe = @'
import os, sys
sys.path.insert(0, os.path.join('_triage', 'factory_os'))
import check_coverage_transfer as cct
import check_s2a_migration as csm
judged = set([cct.SCHEMAS_PATH])
for _state, _path, _anchor in csm.UNOWNABLE.values():
    judged.add(_path)
for p in sorted(judged):
    print(p)
'@
        $probeFile = Join-Path ([System.IO.Path]::GetTempPath()) ("gt1310_" + [guid]::NewGuid().ToString('N') + '.py')
        try {
            Set-Content -LiteralPath $probeFile -Encoding UTF8 -Value $probe
            Push-Location $RepoRoot
            $judged = @(& $pyExe $probeFile) | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            Pop-Location
            if ($judged.Count -lt 2) {
                Bad ("PART 4c derived $($judged.Count) judged input(s) from the S2a checkers' own " +
                     'constants. It should be at least 2 -- an empty derivation makes the check below ' +
                     'vacuous, which is the failure mode it exists to prevent')
            }
            foreach ($j in $judged) {
                if ($declaredFor['run_s2a_cages.ps1'] -notcontains $j) {
                    Bad ("run_s2a_cages.ps1 JUDGES '$j' (derived from the checkers' own constants) " +
                         'but does not declare it, so a commit touching only that file runs no S2a ' +
                         'cage at all')
                }
            }
            # CONTROL: the membership test can say NO. Without it, a `$declaredFor` lookup that
            # silently returned everything would print green above.
            if ($declaredFor['run_s2a_cages.ps1'] -contains 'no/such/judged/input.json') {
                Bad 'PART 4c CONTROL the declaration lookup matches a path that does not exist'
            }
        } finally {
            Remove-Item -LiteralPath $probeFile -Force -ErrorAction SilentlyContinue
        }
    }
    if ($fail -eq $before) {
        Good 'PART 4c every path the S2a checkers JUDGE through a module constant is declared'
    }

    # -------------------------------------------------------------------------------------
    # PART 4d -- ORDER-1284. A wrapper is only the launcher; Python bodies also name files
    # directly. Parse string literals rather than scanning raw source so comments/docstrings
    # do not become accidental dependencies. The scan includes root-level files because S10
    # pins governance documents at HEAD. Every discovered tracked path must be declared or have
    # a narrow, named fixture exemption.
    $before = $fail
    $astProbe = @'
import ast
import json
import os
import re
import sys

root = sys.argv[1]
files = sys.argv[2:]
path_re = re.compile(
    r'(?<![A-Za-z0-9_./\\-])(?:'
    r'(?:(?:scripts|docs|_triage|portfolio|tools|\.githooks)[/\\]'
    r'[A-Za-z0-9_./\\-]+\.(?:ps1|psm1|csv|md|json|py|exe))|'
    r'(?:[A-Za-z0-9_.-]+\.(?:ps1|psm1|csv|md|json|py|exe))'
    r')(?![A-Za-z0-9_./\\-])'
)

for rel in files:
    full = os.path.join(root, rel.replace('/', os.sep))
    tree = ast.parse(open(full, encoding='utf-8').read(), filename=full)
    doc_nodes = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            if node.body and isinstance(node.body[0], ast.Expr):
                value = node.body[0].value
                if isinstance(value, ast.Constant) and isinstance(value.value, str):
                    doc_nodes.add(id(value))
    refs = set()
    for node in ast.walk(tree):
        if id(node) in doc_nodes or not isinstance(node, ast.Constant) or not isinstance(node.value, str):
            continue
        for match in path_re.finditer(node.value):
            refs.add(match.group(0).replace('\\', '/'))
    print(json.dumps({'path': rel, 'refs': sorted(refs)}))
'@
    $pythonEntries = @()
    foreach ($s in $suites) {
        $ownPy = '_triage/factory_os/' + ($s -replace '\.ps1$', '.py')
        if ($tracked.ContainsKey($ownPy)) { $pythonEntries += $ownPy }
    }
    if (-not (Test-Path -LiteralPath $pyExe -PathType Leaf)) {
        Bad "PART 4d cannot run: no interpreter at $pyExe"
    } elseif ($pythonEntries.Count -eq 0) {
        Bad 'PART 4d found no Python suite bodies to scan -- a vacuous green is not acceptable'
    } else {
        $savedEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $astOut = @(& $pyExe -c $astProbe $RepoRoot @($pythonEntries) 2>&1)
        $ErrorActionPreference = $savedEap
        if ($LASTEXITCODE -ne 0) {
            Bad ("PART 4d Python body parser failed: {0}" -f (($astOut | Select-Object -Last 3) -join ' | '))
        } else {
            foreach ($line in $astOut) {
                if (-not $line) { continue }
                try { $row = $line | ConvertFrom-Json } catch { Bad "PART 4d emitted invalid JSON: $line"; continue }
                $suite = Split-Path -Leaf $row.path
                $suite = $suite -replace '\.py$', '.ps1'
                foreach ($r in @($row.refs)) {
                    if (-not $tracked.ContainsKey($r)) { continue }
                    if (IsNotDependency $suite $r) { continue }
                    if ($declaredFor[$suite] -contains $r) { continue }
                    Bad "$suite Python body references tracked path '$r' but neither declares it nor lists it in `$NOT_A_DEPENDENCY"
                }
            }
        }
    }
    if ($fail -eq $before) {
        Good 'PART 4d every tracked path in a Python body is declared or explicitly exempt'
    }

    # NEGATIVE/control: prove the new scanner sees both a root-level path and a nested path,
    # while ignoring an untracked filename. Without this, a broken parser can report green only
    # because the real suite bodies happen not to contain a currently undeclared path.
    $before = $fail
    $tmpPy = Join-Path ([System.IO.Path]::GetTempPath()) ('gt1284_' + [guid]::NewGuid().ToString('N') + '.py')
    try {
        $fixture = @'
"README.md in this module docstring is not a dependency"
REFERENCES = ("AGENT_TASKBOARD.md", "scripts/check_state.ps1", "not-a-repo-file.txt")
'@
        [System.IO.File]::WriteAllText($tmpPy, $fixture, (New-Object System.Text.UTF8Encoding($false)))
        $savedEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $negOut = @(& $pyExe -c $astProbe $RepoRoot $tmpPy 2>&1)
        $ErrorActionPreference = $savedEap
        if ($LASTEXITCODE -ne 0) {
            Bad ("PART 4d NEG parser failed: {0}" -f (($negOut | Select-Object -Last 3) -join ' | '))
        } else {
            $negRow = $negOut | Select-Object -Last 1 | ConvertFrom-Json
            $negRefs = @($negRow.refs)
            if (($negRefs -contains 'AGENT_TASKBOARD.md') -and
                ($negRefs -contains 'scripts/check_state.ps1') -and
                ($negRefs -notcontains 'not-a-repo-file.txt') -and
                ($negRefs -notcontains 'README.md')) {
                Good 'PART 4d NEG finds root/nested tracked literals and ignores docstrings/untracked names'
            } else {
                Bad ("PART 4d NEG expected root+nested tracked refs only, got: {0}" -f ($negRefs -join ', '))
            }
        }
    } finally {
        Remove-Item -LiteralPath $tmpPy -Force -ErrorAction SilentlyContinue
    }
    if ($fail -eq $before) { Good 'PART 4d negative/control remains red-capable' }

    # -------------------------------------------------------------------------------------
    Write-Host ''
    Phase '[guard-trigger] PART 5 -- BACKLOG-D32 per-path suite SELECTION'
    # This part exists because the repo's own memory says a path-filter must not land without a
    # targeted test: filtering the pre-commit trigger wrong means guards stop running while
    # everything still looks green. The selection is designed to fail OPEN, and these cases assert
    # that it does -- every failure mode must run MORE suites than necessary, never fewer.
    $before = $fail
    $cages = Join-Path $PSScriptRoot 'run_fast_cages.ps1'

    function SelectionBatch([object[]]$queries) {
        $batchFile = Join-Path ([System.IO.Path]::GetTempPath()) ("gt673_selection_" + [guid]::NewGuid().ToString('N') + '.txt')
        try {
            $lines = New-Object System.Collections.Generic.List[string]
            foreach ($query in $queries) {
                $paths = @($query)
                if ($paths.Count -eq 0) { [void]$lines.Add('__NONE__') }
                else { [void]$lines.Add(($paths -join "`t")) }
            }
            Set-Content -LiteralPath $batchFile -Encoding ASCII -Value $lines
            $out = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -ExportSelectionBatchFile $batchFile 2>&1)
            $code = $LASTEXITCODE
            if ($code -ne 0) { throw ("selection batch exited {0}: {1}" -f $code, (($out | Select-Object -Last 3) -join ' | ')) }
            # The unmatched-path query deliberately exercises Select-Suites' fail-open warning;
            # keep that diagnostic but parse only the JSON result rows from the batch channel.
            $rows = @($out | Where-Object { "$($_)" -match '^\s*\{' } |
                      ForEach-Object { $_ | ConvertFrom-Json })
            if ($rows.Count -ne $queries.Count) { throw ("selection batch returned {0} row(s) for {1} query(ies)" -f $rows.Count, $queries.Count) }
            return $rows
        } finally {
            Remove-Item -LiteralPath $batchFile -Force -ErrorAction SilentlyContinue
        }
    }

    function Selection([string[]]$staged) {
        @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -ExportSelection -StagedPaths $staged)
    }

    # Build the complete PART 5 matrix first, then drive the real production selector for every
    # query in one child process. No assertion is removed: the batch output is still the exact
    # Select-Suites result for each independent staged-path set.
    $selectionQueries = New-Object System.Collections.Generic.List[object]
    [void]$selectionQueries.Add([object[]]@())
    $allQuery = 0
    $reachQuery = @{}
    foreach ($s in $table.Suites) {
        $g = $table.Guards.$s
        if (-not $g -or $g.Count -eq 0) { continue }
        $reachQuery[$s] = $selectionQueries.Count
        [void]$selectionQueries.Add([object[]]@($g[0]))
    }
    $oneGuard = $table.Guards.'run_guard_trigger_tests.ps1'[0]
    $oneQuery = $selectionQueries.Count
    [void]$selectionQueries.Add([object[]]@($oneGuard))
    $selfProbe = @($table.Suites[0], $table.Suites[[int]($table.Suites.Count / 2)],
                   $table.Suites[$table.Suites.Count - 1]) | Select-Object -Unique
    $selfQuery = @{}
    foreach ($s in $selfProbe) {
        if ($table.Suites -notcontains $s) { Bad ("PART 4b probes '{0}', which is not in the suite table" -f $s); continue }
        $selfQuery[$s] = $selectionQueries.Count
        [void]$selectionQueries.Add([object[]]@('scripts/_test/' + $s))
    }
    $unmatchedQuery = $selectionQueries.Count
    [void]$selectionQueries.Add([object[]]@('no/such/path/at/all.txt'))
    $selectionRows = @(SelectionBatch $selectionQueries.ToArray())

    # 1. no staged paths -> EVERYTHING. Manual runs and any caller that cannot determine the
    #    staged set must get the full tier.
    $all = @($selectionRows[$allQuery].Selected)
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
        $sel = @($selectionRows[$reachQuery[$s]].Selected)
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
    $subset = @($selectionRows[$oneQuery].Selected)
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
    #     THREE SUITES, NOT SIXTEEN, and the number is a measured trade rather than a shrug. The
    #     three queries remain independent; SelectionBatch only avoids paying PowerShell launcher
    #     startup once per query.
    $selfMissed = @()
    $selfWide = @()
    foreach ($s in $selfProbe) {
        if ($table.Suites -notcontains $s) { continue }
        $sel = @($selectionRows[$selfQuery[$s]].Selected)
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
    $unmatched = @($selectionRows[$unmatchedQuery].Selected | Where-Object { $_ -like '*.ps1' })
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
        $o1 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -Hook -ReuseCurrentSnapshot -StagedPathsFile $cheapStaged -EvidenceSuitesOverride @('run_order_collision_tests.ps1') 2>&1)
        if ($LASTEXITCODE -eq 1 -and (($o1 -join "`n") -match 'run_order_collision_tests\.ps1 emitted NO evidence-mode marker')) {
            Good 'T4 ATTACK a declared evidence suite emitting no marker fails the hook tier, by name'
        } else {
            Bad ("T4 ATTACK expected exit 1 naming the silent suite; got exit {0}" -f $LASTEXITCODE)
        }
        # T4 SPECIFICITY: with no evidence suite selected, the same run is green -- the
        # verifier must not fire on suites that never migrated.
        $o2 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -Hook -ReuseCurrentSnapshot -StagedPathsFile $cheapStaged -EvidenceSuitesOverride 'NONE' 2>&1)
        if ($LASTEXITCODE -eq 0) {
            Good 'T4 SPECIFICITY the same hook run with no evidence suite in scope is green'
        } else {
            Bad ("T4 SPECIFICITY expected exit 0; got {0}: {1}" -f $LASTEXITCODE, (($o2 | Select-Object -Last 3) -join ' | '))
        }
        # T6 ATTACK: force the end-stamp mismatch => the tier refuses and says the index moved.
        $o3 = @(& $ps -NoProfile -ExecutionPolicy Bypass -File $cages -Hook -ReuseCurrentSnapshot -StagedPathsFile $cheapStaged -EvidenceSuitesOverride 'NONE' -DebugPretendIndexMoved 2>&1)
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
    # RAISED 2026-08-20, post-audit M0 repair program (owner-approved): full tier 120.0 -> 195.0
    # (measured 172.6s / 157.6s at the integration point, 168.0s independently by M0-Lane3 in
    # isolation -- see run_fast_cages.ps1's own note next to the parameter). Per-path 90.0
    # untouched; that budget was not breached.
    if ($cagesSrc -match '\$BudgetSeconds\s*=\s*90\.0') { Good 'N1 the per-path default is the measured 90.0s' } else { Bad 'N1 the per-path default is not 90.0 -- it was changed without this case being updated' }
    if ($cagesSrc -match '\$FullTierBudgetSeconds\s*=\s*195\.0') { Good 'N1 the full-tier default is the measured 195.0s' } else { Bad 'N1 the full-tier default is not 195.0 -- it was changed without this case being updated' }
    if ($fail -eq $before) { Good 'the budget can fail, and does not fail a healthy run' }

    # -------------------------------------------------------------------------------------
    Write-Host ''
    Phase '[guard-trigger] PART 8 -- D-F5 REVERSE completeness: every run_* file is classified'
    # PARTS 1-3 walk `foreach ($s in $suites)` where $suites IS $FAST_SUITES, so they validate the
    # declared set AGAINST ITSELF. A run_* suite nobody ever classified is not failed, not warned
    # about -- it is never looked at. Measured at canonical 649207d6: 69 tracked run_* files under
    # scripts/_test/, 31 in $FAST_SUITES, 38 invisible.
    #
    # This part asks the reverse question against scripts/_test/SUITE_TIER_REGISTRY.txt: for every
    # tracked run_* FILE, is there a row? It does NOT wire anything into the fast tier and it does
    # NOT spend the pinned 120.0s budget -- EXEMPT-with-reason (SLOW / NOT_WIRED / UNMEASURED) is a
    # valid outcome. The requirement is visibility, not execution.
    #
    # THE REGISTRY IS A CLOSED SET BY CONSTRUCTION: literal file names only, no wildcard, one row
    # per real file, and a row naming a non-existent file FAILS. So a single blanket/catch-all
    # entry cannot silence this check -- the defect class this repo has already paid for
    # (citation-guard-satisfied-by-a-universal-file).
    $before = $fail
    $regPath = if ($RegistryPath) { $RegistryPath } else { Join-Path $RepoRoot 'scripts\_test\SUITE_TIER_REGISTRY.txt' }
    $VALID_TIERS = @('FAST', 'HARNESS', 'SLOW', 'NOT_WIRED', 'UNMEASURED')
    if (-not (Test-Path -LiteralPath $regPath)) {
        Bad 'PART 8 scripts/_test/SUITE_TIER_REGISTRY.txt does not exist -- the reverse check cannot run, and a check that cannot run is a FAILURE, not a pass'
    } else {
        # The files, from git (the index), not from the filesystem: an untracked scratch file in
        # scripts/_test is not something the trigger map owes an entry for.
        $suiteFiles = @{}
        foreach ($t in (git ls-files -- 'scripts/_test/run_*')) {
            $suiteFiles[(Split-Path -Leaf $t.Replace('\', '/'))] = $true
        }

        $rows = @{}
        $dupes = @()
        $lineNo = 0
        foreach ($raw in (Get-Content -LiteralPath $regPath)) {
            $lineNo++
            $line = $raw.Trim()
            if (-not $line -or $line.StartsWith('#')) { continue }
            $parts = $line -split '\|', 3
            if ($parts.Count -ne 3) {
                Bad "PART 8 registry line ${lineNo} is not <filename>|<TIER>|<reason>: $line"
                continue
            }
            $fn = $parts[0].Trim(); $tier = $parts[1].Trim(); $reason = $parts[2].Trim()
            # NO WILDCARDS. This single rule is what makes the set closed.
            if ($fn -match '[*?\[\]]') {
                Bad "PART 8 registry line ${lineNo} uses a WILDCARD name '$fn' -- the registry must be a closed set of literal file names"
                continue
            }
            if ($fn -match '[/\\]') {
                Bad "PART 8 registry line ${lineNo} carries a directory in '$fn' -- leaf file names only"
                continue
            }
            if ($VALID_TIERS -notcontains $tier) {
                Bad "PART 8 registry line ${lineNo} tier '$tier' is not one of: $($VALID_TIERS -join ', ')"
                continue
            }
            if ($reason.Length -lt 20) {
                Bad "PART 8 registry line ${lineNo} ('$fn') has no usable reason -- a classification with no reason is the silence this part exists to remove"
                continue
            }
            if ($rows.ContainsKey($fn)) { $dupes += $fn; continue }
            $rows[$fn] = [pscustomobject]@{ Tier = $tier; Reason = $reason; Line = $lineNo }
        }
        foreach ($d in ($dupes | Sort-Object -Unique)) {
            Bad "PART 8 '$d' is classified more than once -- one row per file, so a reader cannot be shown two answers"
        }

        # (1) every FILE has a row
        foreach ($f in ($suiteFiles.Keys | Sort-Object)) {
            if (-not $rows.ContainsKey($f)) {
                Bad "PART 8 UNCLASSIFIED: scripts/_test/$f is tracked but has no row in SUITE_TIER_REGISTRY.txt (classify it, or exempt it WITH A REASON)"
            }
        }
        # (2) every ROW names a real file -- a stale row is a declaration that matches nothing,
        #     which is the original D-F5 defect wearing a classification.
        foreach ($f in ($rows.Keys | Sort-Object)) {
            if (-not $suiteFiles.ContainsKey($f)) {
                Bad "PART 8 STALE ROW: registry line $($rows[$f].Line) classifies '$f', which is not a tracked scripts/_test/run_* file"
            }
        }
        # (3) FAST must agree with $FAST_SUITES IN BOTH DIRECTIONS. This is what stops the
        #     registry becoming a second, drifting copy of the tier: it is checked against the
        #     tier's own exported table, not against a literal typed here.
        foreach ($f in ($rows.Keys | Sort-Object)) {
            $isFastHere = ($rows[$f].Tier -eq 'FAST')
            $isFastThere = ($suites -contains $f)
            if ($isFastHere -and -not $isFastThere) {
                Bad "PART 8 '$f' is tier FAST in the registry but is NOT in `$FAST_SUITES"
            }
            if ($isFastThere -and -not $isFastHere) {
                Bad "PART 8 '$f' is in `$FAST_SUITES but the registry does not classify it FAST (tier=$($rows[$f].Tier))"
            }
        }
        # (4) NO SILENT WIRING. The registry must not become a way to grow the fast tier: the
        #     count of FAST rows is asserted against the tier's own count, so a FAST row added
        #     without touching run_fast_cages.ps1 (or the reverse) is refused.
        $fastRows = @($rows.Values | Where-Object { $_.Tier -eq 'FAST' })
        if ($fastRows.Count -ne $suites.Count) {
            Bad ("PART 8 registry FAST rows = {0} but `$FAST_SUITES = {1}" -f $fastRows.Count, $suites.Count)
        }

        # PRINT THE SCOPE, NOT JUST THE VERDICT. A roll-up that says "complete" without naming
        # what it looked at has already burned this repo (guard-must-print-its-scope-not-just-
        # its-verdict). These counts are the whole point of the part.
        $byTier = @{}
        foreach ($t in $VALID_TIERS) { $byTier[$t] = @($rows.Values | Where-Object { $_.Tier -eq $t }).Count }
        Write-Host ("  [scope] examined {0} tracked scripts/_test/run_* file(s); registry rows {1}" -f `
                    $suiteFiles.Count, $rows.Count)
        Write-Host ("  [scope] classified: FAST {0} (= FAST_SUITES {1}) | HARNESS {2} | SLOW {3} | NOT_WIRED {4} | UNMEASURED {5}" -f `
                    $byTier['FAST'], $suites.Count, $byTier['HARNESS'], $byTier['SLOW'], `
                    $byTier['NOT_WIRED'], $byTier['UNMEASURED'])
        $exempt = $byTier['SLOW'] + $byTier['NOT_WIRED'] + $byTier['UNMEASURED']
        Write-Host ("  [scope] explicitly EXEMPT-with-reason (not wired, not costing budget): {0}" -f $exempt)
        # The accepted PREDEV disposition is named, so a future lane that quietly re-wires it has
        # to change this assertion too. PROJECT_STATE 2026-08-19: MEASURED_NOT_WIRED, still parked.
        foreach ($predev in @('run_new_template_entry_tests.ps1',
                              'run_mt5_optimize_launcher_hardening_tests.ps1',
                              'run_legacy_quarantine_tests.ps1')) {
            if (-not $rows.ContainsKey($predev)) {
                Bad "PART 8 the accepted PREDEV suite '$predev' has no registry row"
            } elseif ($rows[$predev].Tier -ne 'NOT_WIRED') {
                Bad ("PART 8 PREDEV disposition BROKEN: '{0}' is tier {1}, but PROJECT_STATE 2026-08-19 records MEASURED_NOT_WIRED" -f `
                     $predev, $rows[$predev].Tier)
            }
        }
    }
    if ($fail -eq $before) { Good 'every tracked run_* file is classified or explicitly exempt WITH a reason' }

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
