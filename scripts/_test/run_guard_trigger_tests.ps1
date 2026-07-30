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

    # 4. an unrelated staged path must not select a suite that does not guard it.
    $none = Selection @('no/such/path/at/all.txt')
    if ($none.Count -lt $table.Suites.Count) { Good ('an unrelated staged path selects fewer suites ({0})' -f $none.Count) }
    else { Bad 'an unrelated staged path still selected every suite -- the filter is inert' }

    if ($fail -eq $before) { Good 'per-path selection fails OPEN and every suite stays reachable' }

    Write-Host ''
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
