<#
run_snapshot_s4_tests.ps1 - ORDER-612 (slice S4) acceptance, C3 and C6: the READER half.

C1 is asserted in _triage\factory_os\run_schema_fixtures.py (the line whose flip IS the
acceptance). C2/C4/C5/C7 are asserted in _triage\factory_os\run_snapshot_s4_tests.py.
C3 and C6 live here because the readers are PowerShell.

  C3  a missing / unreadable / stale MANDATORY source must not be able to render ALL CLEAR.
      Three separate negatives, each OBSERVED FIRING, and the fire count is printed -- per the
      VERDICT GATE's guard rule, a guard that fires 0 times is UNTESTED, not passed.

  C6  make_status.ps1 and the digest reader consume ONLY a validated snapshot and refuse to
      render on a failed build. The two readers answer the three states DIFFERENTLY and both
      answers are pre-registered in scripts\lib\snapshot_reader.ps1; what they SHARE, and what is
      asserted here in both directions, is that neither ever emits a number from an unverified
      document.

Every fixture is BUILT through snapshot_build.py rather than hand-authored, for the reason the
whole slice exists: a hand-typed `verdict` is the attack, not the test.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_snapshot_s4_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }

$script:pass = 0
$script:fail = 0
function Assert-True([string]$name, $cond) {
    if ($cond) { $script:pass++; Write-Host "   [PASS] $name" }
    else { $script:fail++; Write-Host "   [FAIL] $name" }
}
function Assert-Equal([string]$name, $expected, $actual) {
    if ("$expected" -eq "$actual") { $script:pass++; Write-Host "   [PASS] $name" }
    else {
        $script:fail++
        Write-Host "   [FAIL] $name"
        Write-Host "          expected: $expected"
        Write-Host "          actual  : $actual"
    }
}

. (Join-Path $RepoRoot 'scripts\lib\snapshot_reader.ps1')
. (Join-Path $RepoRoot 'scripts\lib\monitor_coverage.ps1')

$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$builder = Join-Path $RepoRoot '_triage\factory_os\snapshot_build.py'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("s4rd_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

# --- fixture construction ---------------------------------------------------------------
# Sources resolve against $work, never against the repo: a source row pointing at a repo file
# would make `fresh` a function of that file's mtime, so these fixtures would go red with the
# passage of time rather than with any code change.
function New-Src([string]$name, [double]$ageHours) {
    $p = Join-Path $work $name
    Set-Content -LiteralPath $p -Value "src $name" -Encoding ASCII
    if ($ageHours -gt 0) {
        (Get-Item $p).LastWriteTime = (Get-Date).AddHours(-1 * $ageHours)
    }
    return $p
}
function Build-Fixture([string]$tag, $sourceRows, [string[]]$mandatory) {
    $inp = [ordered]@{
        entity = 'SnapshotBuilderInput'
        meta = [ordered]@{
            schema = 'ControlRoomSnapshot'; version = 5
            generated_at = (Get-Date).ToString('s'); stale_bar_hours = 30
            mandatory_sources = $mandatory
            sources = $sourceRows
            reconciliation = [ordered]@{
                discovered = 0; categorized = 0
                categories = [ordered]@{ actionable=0; running=0; waiting=0; review_audit=0; completed=0; cancelled_by_user=0 }
                duplicates = 0; conflicts = 0; unclassified = 0
                coverage = [ordered]@{ cells_in_universe=0; tested=0; untested=0; not_applicable=0 }
            }
        }
        system_health = @([ordered]@{ account='100000001'; collector='MT5'; state='FRESH'; age_hours=0.1; governance_scope='LAB_MANAGED' })
        floating_risk = @([ordered]@{ account='100000001'; state='FRESH'; age_hours=0.0; equity=1.0; balance=1.0; floating_pl=0.0; magics=@() })
        deployments = [ordered]@{}; unknown_magics = @(); attestation = @()
        judge_readiness = @(); judge_cohorts = @(); summary = [ordered]@{ unknown_magics_unclassified = 0 }
    }
    $inPath = Join-Path $work "in_$tag.json"
    $outPath = Join-Path $work "v5_$tag.json"
    [System.IO.File]::WriteAllText($inPath, ($inp | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($false)))
    $o = & $py $builder build $inPath $outPath $work 2>&1
    if ($LASTEXITCODE -ne 0) { throw "fixture $tag did not build: $($o -join ' ')" }
    return $outPath
}
function Row([string]$name, [string]$path, [bool]$mandatory) {
    return [ordered]@{ name=$name; path=$path; mandatory=$mandatory
                       read_ok=$null; sha256=$null; mtime=$null; age_hours=$null; fresh=$null }
}

try {
Write-Host '=== C3: a missing / unreadable / stale MANDATORY source cannot render ALL CLEAR ==='

# BASE CONTROL. Per the VERDICT GATE's guard rule, a guard is only evidence when there is a run
# over a window where it SHOULD fire and a run where it should NOT. This is the should-not run.
New-Src 'fresh.txt' 0 | Out-Null
$clean = Build-Fixture 'clean' @((Row 'srcFresh' 'fresh.txt' $true)) @('srcFresh')
$cleanDoc = Get-Content -LiteralPath $clean -Raw | ConvertFrom-Json
Assert-True 'BASE CONTROL: every mandatory source present, readable and fresh => reconciliation_clear' `
    ($cleanDoc.verdict.reconciliation_clear -eq $true)
Assert-Equal 'BASE CONTROL: and it says so with ZERO reasons' 0 (@($cleanDoc.verdict.reasons).Count)

$fired = @{}

# C3-a MISSING: the registry names a source no row supplies.
$miss = Build-Fixture 'missing' @((Row 'srcFresh' 'fresh.txt' $true)) @('srcFresh','srcAbsent')
$missDoc = Get-Content -LiteralPath $miss -Raw | ConvertFrom-Json
$missCodes = @($missDoc.verdict.reasons | ForEach-Object { $_.code })
Assert-True 'C3-a a MISSING mandatory source cannot be clear' ($missDoc.verdict.reconciliation_clear -eq $false)
Assert-True 'C3-a and the reason is MANDATORY_SOURCE_MISSING naming the source' `
    (@($missDoc.verdict.reasons | Where-Object { $_.code -eq 'MANDATORY_SOURCE_MISSING' -and $_.detail -eq 'srcAbsent' }).Count -eq 1)
if ($missCodes -contains 'MANDATORY_SOURCE_MISSING') { $fired['MANDATORY_SOURCE_MISSING'] = 1 }

# C3-b UNREADABLE: a row whose file is not on disk. read_ok is DERIVED false; the builder cannot
# claim otherwise (that is C4's negative), so this is the only way to reach the code.
$unread = Build-Fixture 'unreadable' @((Row 'srcFresh' 'fresh.txt' $true), (Row 'srcGone' 'gone.txt' $true)) @('srcFresh','srcGone')
$unreadDoc = Get-Content -LiteralPath $unread -Raw | ConvertFrom-Json
Assert-True 'C3-b an UNREADABLE mandatory source cannot be clear' ($unreadDoc.verdict.reconciliation_clear -eq $false)
Assert-True 'C3-b and UNREADABLE is its own code, never collapsed into MISSING' `
    (@($unreadDoc.verdict.reasons | Where-Object { $_.code -eq 'MANDATORY_SOURCE_UNREADABLE' -and $_.detail -eq 'srcGone' }).Count -eq 1)
Assert-True 'C3-b specificity: the readable sibling is NOT reported unreadable' `
    (@($unreadDoc.verdict.reasons | Where-Object { $_.detail -eq 'srcFresh' }).Count -eq 0)
if (@($unreadDoc.verdict.reasons | ForEach-Object { $_.code }) -contains 'MANDATORY_SOURCE_UNREADABLE') { $fired['MANDATORY_SOURCE_UNREADABLE'] = 1 }

# C3-c STALE: a real file, older than the bar. Measured first, so the fixture cannot be one that
# silently stopped being stale.
$oldPath = New-Src 'old.txt' 100
$measuredAge = ((Get-Date) - (Get-Item $oldPath).LastWriteTime).TotalHours
Assert-True 'C3-c the stale fixture really is over the 30h bar (measured, not assumed)' ($measuredAge -gt 30)
$stale = Build-Fixture 'stale' @((Row 'srcFresh' 'fresh.txt' $true), (Row 'srcOld' 'old.txt' $true)) @('srcFresh','srcOld')
$staleDoc = Get-Content -LiteralPath $stale -Raw | ConvertFrom-Json
Assert-True 'C3-c a STALE mandatory source cannot be clear' ($staleDoc.verdict.reconciliation_clear -eq $false)
Assert-True 'C3-c and STALE is its own code, never collapsed into UNREADABLE' `
    (@($staleDoc.verdict.reasons | Where-Object { $_.code -eq 'MANDATORY_SOURCE_STALE' -and $_.detail -eq 'srcOld' }).Count -eq 1)
Assert-True 'C3-c specificity: the fresh sibling derives fresh=true' `
    ((@($staleDoc.meta.sources | Where-Object { $_.name -eq 'srcFresh' })[0].fresh) -eq $true)
if (@($staleDoc.verdict.reasons | ForEach-Object { $_.code }) -contains 'MANDATORY_SOURCE_STALE') { $fired['MANDATORY_SOURCE_STALE'] = 1 }

# The fire count, printed rather than implied. A run in which these fired 0 times is UNTESTED and
# must not be written up as passed -- CLAUDE.md's guard/filter row, applied to this suite.
Write-Host ("   GUARD FIRE COUNT: {0}/3 C3 codes observed firing -> {1}" -f $fired.Count, (($fired.Keys | Sort-Object) -join ', '))
Assert-Equal 'C3 all three codes were OBSERVED FIRING (0 would mean UNTESTED, not safe)' 3 $fired.Count

Write-Host ''
Write-Host '=== C6: readers consume ONLY a validated snapshot ==='

# --- C6 reader 1: Format-ControlRoomBlock, which is what make_status.ps1 renders ---------
$okBlock = (Format-ControlRoomBlock -Verified (Get-VerifiedSnapshot -SnapshotPath $clean -RepoRoot $RepoRoot)) -join "`n"
Assert-True 'C6 OK renders the verified build id' ($okBlock -match 'Verified snapshot')
Assert-True 'C6 OK renders the reconciliation counts' ($okBlock -match 'orders discovered')

# NEGATIVE 1: an INVALID snapshot. The order's wording: "point them at an invalid snapshot => they
# must fail loudly, not render a stale-but-pretty page."
$tampered = Join-Path $work 'tampered.json'
$t = Get-Content -LiteralPath $clean -Raw | ConvertFrom-Json
$t.verdict.reconciliation_clear = $false   # the document now disagrees with its own evidence
[System.IO.File]::WriteAllText($tampered, ($t | ConvertTo-Json -Depth 14), (New-Object System.Text.UTF8Encoding($false)))
$vT = Get-VerifiedSnapshot -SnapshotPath $tampered -RepoRoot $RepoRoot
Assert-Equal 'C6 NEG a tampered verdict is REFUSED' 'REFUSED' $vT.State
Assert-Equal 'C6 NEG and the code says it is the VERDICT, not corrupt bytes' 'VERDICT' $vT.Code
Assert-True  'C6 NEG the reader hands back NO document, so no caller can read numbers off it' ($null -eq $vT.Document)
$refBlock = (Format-ControlRoomBlock -Verified $vT) -join "`n"
Assert-True 'C6 NEG the page says SNAPSHOT REFUSED, loudly' ($refBlock -match 'SNAPSHOT REFUSED')
Assert-True 'C6 NEG and renders NO counts from it' ($refBlock -notmatch 'orders discovered')
Assert-True 'C6 NEG and no build id either' ($refBlock -notmatch 'Verified snapshot')

# NEGATIVE 2: a MISSING snapshot -- the pre-registered asymmetry. It must degrade, not block.
$vM = Get-VerifiedSnapshot -SnapshotPath (Join-Path $work 'no_such_file.json') -RepoRoot $RepoRoot
Assert-Equal 'C6 NEG a missing snapshot is UNAVAILABLE, not REFUSED' 'UNAVAILABLE' $vM.State
Assert-Equal 'C6 NEG with the MISSING code, distinct from a tool failure' 'MISSING' $vM.Code
$missBlock = (Format-ControlRoomBlock -Verified $vM) -join "`n"
Assert-True 'C6 NEG the page says SNAPSHOT UNAVAILABLE' ($missBlock -match 'SNAPSHOT UNAVAILABLE')
Assert-True 'C6 NEG and still renders NO counts' ($missBlock -notmatch 'orders discovered')
Assert-True 'C6 NEG and states that this is about the INSTRUMENT, not the fleet' ($missBlock -match 'INSTRUMENT')

# NEGATIVE 3: corrupt bytes. Distinct from both of the above.
$corrupt = Join-Path $work 'corrupt.json'
Set-Content -LiteralPath $corrupt -Value '{ "entity": ' -Encoding ASCII
$vC = Get-VerifiedSnapshot -SnapshotPath $corrupt -RepoRoot $RepoRoot
Assert-Equal 'C6 NEG corrupt bytes are REFUSED' 'REFUSED' $vC.State
Assert-Equal 'C6 NEG with the MALFORMED code - "no coverage data" is not "the numbers do not add up"' 'MALFORMED' $vC.Code

# THE PREFERENCE-INDEPENDENCE PROPERTY. This is the defect the monitor cage caught: `2>&1` on a
# native command wraps stderr in ErrorRecords, so under 'Stop' the same file came back UNAVAILABLE
# and under 'Continue' it came back REFUSED. Asserted under BOTH preferences, one step apart.
$savedEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$vC_cont = Get-VerifiedSnapshot -SnapshotPath $corrupt -RepoRoot $RepoRoot
$vT_cont = Get-VerifiedSnapshot -SnapshotPath $tampered -RepoRoot $RepoRoot
$ErrorActionPreference = $savedEap
Assert-Equal 'C6 the reader gives the SAME answer for corrupt bytes under EAP=Continue' $vC.Code $vC_cont.Code
Assert-Equal 'C6 the reader gives the SAME answer for a tampered verdict under EAP=Continue' $vT.Code $vT_cont.Code

# THE SHAPE-1 FIX'S OWN TWO BRANCHES. Both were added in round 1 of the self-scrutinize loop and
# both are fixtured here, because a branch nobody can make fire is the A8 defect: a rule that
# shipped with no fixture at all.
#
# Branch 1: the reader's own read does not match the bytes the validator verified. There is no way
# to lose that race on demand, so Get-FileHash is SHADOWED in this scope -- the library is
# dot-sourced into it, so its call resolves to this function. That is a real exercise of the
# comparison, not a simulation of its outcome: the branch is entered by the code under test.
# HOW THIS CASE IS DRIVEN CHANGED, and the reason is the finding itself. It used to SHADOW
# Get-FileHash to force a mismatch. A blind audit then found the reader still hashed the file with
# Get-FileHash and re-opened it with Get-Content to parse -- two reads, so the digest described one
# and the caller got the other. The repair reads the bytes ONCE and hashes that buffer, which
# removed the cmdlet the fixture was leaning on: the fixture stopped discriminating in the same
# commit that closed the hole, and said so by going red.
#
# It is driven through a STUB VALIDATOR now: one that answers OK and publishes a digest that does
# not match the file. That exercises the comparison branch through the reader's real code path,
# and -- unlike the shadow -- it does not depend on which cmdlet the implementation happens to use.
$raceRoot = Join-Path $work 'raceroot'
New-Item -ItemType Directory -Path (Join-Path $raceRoot ('_triage'+[char]92+'factory_os')) -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $raceRoot 'tools') -Force | Out-Null
cmd /c mklink /J "$(Join-Path $raceRoot ('tools'+[char]92+'python312'))" "$(Join-Path $RepoRoot ('tools'+[char]92+'python312'))" | Out-Null
Set-Content -LiteralPath (Join-Path $raceRoot ('_triage'+[char]92+'factory_os'+[char]92+'snapshot_validator.py')) -Encoding ASCII -Value @(
    'import sys',
    'print("[OK] %s: stored verdict matches" % sys.argv[2])',
    'print("verified-sha256: " + "f"*64)',
    'sys.exit(0)')
$vRace = Get-VerifiedSnapshot -SnapshotPath $clean -RepoRoot $raceRoot
Assert-Equal 'C6 SHAPE-1 a read that does not match the verified bytes is UNAVAILABLE' 'UNAVAILABLE' $vRace.State
Assert-Equal 'C6 SHAPE-1 and it is a TOOL problem, not a verdict about the document' 'TOOL' $vRace.Code
Assert-True  'C6 SHAPE-1 and it names both digests so the reader can see WHICH read drifted' `
    ($vRace.Reason -match 'changed between being verified')
Assert-True  'C6 SHAPE-1 and hands back no document' ($null -eq $vRace.Document)
# CONTROL: the SAME file through the REAL validator is OK -- so the branch above was entered
# because the digests disagreed, not because the fixture or the file is broken.
Assert-Equal 'C6 SHAPE-1 CONTROL the same snapshot verifies OK against the real validator' `
    'OK' (Get-VerifiedSnapshot -SnapshotPath $clean -RepoRoot $RepoRoot).State
# ...and the digest the REAL validator publishes must actually match the file, or the comparison
# above would be passing for the wrong reason.
$realOut = & (Join-Path $RepoRoot ('tools'+[char]92+'python312'+[char]92+'python.exe')) `
    (Join-Path $RepoRoot ('_triage'+[char]92+'factory_os'+[char]92+'snapshot_validator.py')) verify $clean
$published = (@($realOut) | Where-Object { $_ -match '^verified-sha256:' }) -replace '^verified-sha256:\s*',''
Assert-Equal 'C6 SHAPE-1 CONTROL the published digest equals the file on disk' `
    ((Get-FileHash -LiteralPath $clean -Algorithm SHA256).Hash.ToLower()) ("$published".Trim())

# Branch 2: the validator reports OK but publishes no verified-sha256 line -- an older or patched
# validator. Reproduced with a STUB REPO ROOT: a directory holding a stub snapshot_validator.py
# and a junction to the real interpreter, so the reader runs its real code path against a
# validator that answers the old way.
$stubRoot = Join-Path $work 'stubroot'
New-Item -ItemType Directory -Path (Join-Path $stubRoot ('_triage'+[char]92+'factory_os')) -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stubRoot 'tools') -Force | Out-Null
cmd /c mklink /J "$(Join-Path $stubRoot ('tools'+[char]92+'python312'))" "$(Join-Path $RepoRoot ('tools'+[char]92+'python312'))" | Out-Null
Set-Content -LiteralPath (Join-Path $stubRoot ('_triage'+[char]92+'factory_os'+[char]92+'snapshot_validator.py')) -Encoding ASCII -Value @(
    'import sys',
    'print("[OK] %s: stored verdict matches" % sys.argv[2])',
    'sys.exit(0)')
$vNoDigest = Get-VerifiedSnapshot -SnapshotPath $clean -RepoRoot $stubRoot
Assert-Equal 'C6 SHAPE-1 a validator that publishes no digest is UNAVAILABLE, not OK' 'UNAVAILABLE' $vNoDigest.State
Assert-True  'C6 SHAPE-1 and says it cannot prove it is reading the verified bytes' `
    ($vNoDigest.Reason -match 'no verified-sha256')
Assert-True  'C6 SHAPE-1 and hands back no document' ($null -eq $vNoDigest.Document)

# --- C6 reader 2: the daily digest, which pre-registers the OPPOSITE exit behaviour ------
$cov = Get-MonitorCoverage -SnapshotPath $clean
Assert-Equal 'C6 digest: a verified snapshot produces no failure token' 0 $cov.Failures.Count
$covT = Get-MonitorCoverage -SnapshotPath $tampered
Assert-Equal 'C6 NEG digest: a tampered verdict IS red, with its own token' 'snapshot-refused' ($covT.Failures -join ',')
Assert-True  'C6 NEG digest: and it says none of the numbers may be read' ($covT.Summary -match 'may be read')
$covM = Get-MonitorCoverage -SnapshotPath (Join-Path $work 'no_such_file.json')
Assert-Equal 'C6 NEG digest: a MISSING snapshot IS red here, unlike on the STATUS page' 'snapshot-missing' ($covM.Failures -join ',')
$covC = Get-MonitorCoverage -SnapshotPath $corrupt
Assert-Equal 'C6 NEG digest: corrupt bytes keep the token this cage already asserted' 'snapshot-unreadable' ($covC.Failures -join ',')

# The asymmetry itself, asserted rather than described: SAME input, DIFFERENT pre-registered
# handling, and the shared invariant holds in both.
Assert-True 'C6 the pre-registered asymmetry holds: MISSING is red for the digest and not for the page' `
    (($covM.Failures.Count -gt 0) -and ($missBlock -notmatch 'orders discovered'))

Write-Host ''
if ($script:fail -gt 0) { Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail); exit 1 }
Write-Host ("PASS  {0}/{0}" -f $script:pass)
exit 0
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
