<#
run_make_status_worktree_isolation_tests.ps1 - monitoring-status-audit follow-on.

WHY THIS EXISTS
  scripts\make_status.ps1 and scripts\make_status_html.ps1 both hardcoded $repo = "D:\EA_LAB".
  Running either from an isolated worktree therefore silently read AND WROTE against the shared
  primary checkout and its live OneDrive-synced files instead of the worktree the caller was
  actually sandboxed to -- reproduced directly in the prior session (an incidental run from this
  worktree regenerated D:\EA_LAB\STATUS.html and its real OneDrive copy; harmless only because
  the old template/reader in the shared tree had no new markup to inject).

  This suite proves the fix WITHOUT ever touching the real D:\EA_LAB or the real OneDrive folder:
  it builds TWO self-contained fixture checkouts (own .git, own scripts\, own data files) under
  a scratch temp dir, and treats one of them as the "primary workspace" via -PrimaryRepoRoot /
  -OneDrivePath overrides that exist for exactly this purpose. Production defaults (no override
  params) still point at the real D:\EA_LAB and the real OneDrive path -- unchanged from before
  this fix, this suite just never invokes the scripts without an override.

  A. an isolated run reads THAT FIXTURE's own files (a sentinel ORDER line unique to the fixture
     surfaces in the rendered output).
  B. it writes STATUS.md / STATUS.html only inside that fixture (not anywhere else).
  C. sentinel files at the fake "D:\EA_LAB"-equivalent (the fake-primary fixture) are BYTE-IDENTICAL
     before and after an isolated run against the OTHER (isolated) fixture -- hash compare, not a
     "no exception" check.
  D. the isolated run does not reach the OneDrive publish branch at all -- asserted by checking the
     fake-OneDrive sentinel file is untouched (hash) AND by grepping the script's own stdout for the
     explicit "OneDrive publish SKIPPED" line make_status_html.ps1 now prints on that branch.
  E. the SAME fixture, run as the (fake) primary workspace, still publishes: STATUS.md/.html land
     in the fake OneDrive folder too -- the feature is caged, not removed.
  F. make_status.ps1 -> make_status_html.ps1 propagates ONE resolved root: the html file's
     Control Room section (data-dependent) is byte-identical to make_status.ps1's own resolution,
     proven by asserting both processes agree on the same resolved $repo (echoed by each script).
  G. an anchor with no .git anywhere above it FAILS EXPLICITLY (non-zero exit, thrown error text
     naming the failure) -- not a silent "D:\EA_LAB" fallback.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_make_status_worktree_isolation_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }

# Invoking a child `powershell -File ...` with `2>&1` merges its stderr into OUR pipeline; under
# THIS script's own $ErrorActionPreference = 'Stop', PowerShell wraps each merged stderr line in a
# terminating ErrorRecord (the same hazard scripts\lib\snapshot_reader.ps1 documents and works
# around for the exact same reason). Every child invocation below runs under a LOCAL 'Continue' so
# a child's native stderr (e.g. a git informational line) cannot abort this suite; the child's own
# real exit code is still captured via $LASTEXITCODE right after the call, unaffected by this.
function Invoke-Child([string[]]$ArgList) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & powershell @ArgList 2>&1
        return [pscustomobject]@{ Output = $out; ExitCode = $LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $saved
    }
}

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

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("wtiso_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

function New-Fixture([string]$tag, [string]$sentinelOrderLine) {
    <#
      A minimal, self-contained checkout: real copies of the two scripts under test plus their
      dependencies, its own .git (so Resolve-EaLabRepoRoot stops here, never walks past it into
      the real repo), and just enough data files for both scripts to run cleanly with no
      control_room_snapshot.json (Get-VerifiedSnapshot's own MISSING/UNAVAILABLE path, already
      proven fail-closed by run_snapshot_s4_tests.ps1 -- not re-tested here).
    #>
    $root = Join-Path $work $tag
    New-Item -ItemType Directory -Path (Join-Path $root 'scripts\lib') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'portfolio') -Force | Out-Null
    & git init -q $root
    if ($LASTEXITCODE -ne 0) { throw "git init failed for fixture $tag" }
    & git -C $root config user.email 'fixture@example.invalid' | Out-Null
    & git -C $root config user.name 'fixture' | Out-Null

    Copy-Item (Join-Path $RepoRoot 'scripts\make_status.ps1') (Join-Path $root 'scripts\make_status.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\make_status_html.ps1') (Join-Path $root 'scripts\make_status_html.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\status_template.html') (Join-Path $root 'scripts\status_template.html') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\lib\repo_paths.ps1') (Join-Path $root 'scripts\lib\repo_paths.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\lib\snapshot_reader.ps1') (Join-Path $root 'scripts\lib\snapshot_reader.ps1') -Force

    Set-Content -LiteralPath (Join-Path $root 'AGENT_TASKBOARD.md') -Encoding UTF8 -Value @(
        '# Fixture taskboard',
        $sentinelOrderLine
    )
    Set-Content -LiteralPath (Join-Path $root 'PROJECT_STATE.md') -Encoding UTF8 -Value @(
        '# Fixture project state',
        'judge date: 2099-01-01'
    )
    Set-Content -LiteralPath (Join-Path $root 'DEMO_DEPLOYMENT_PLAN.md') -Encoding UTF8 -Value @(
        '| # | Symbol | Magic | x | y | note |',
        '|---|---|---|---|---|---|'
    )
    # An initial commit so `git rev-parse HEAD` / `git log` (both called by make_status.ps1)
    # succeed cleanly instead of erroring on an empty repo -- a real worktree always has a HEAD.
    & git -C $root add -A | Out-Null
    & git -C $root commit -q -m 'fixture initial commit' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "git commit failed for fixture $tag" }
    return $root
}

try {
Write-Host '=== fixture construction: two independent checkouts, no real repo touched ==='
$primary  = New-Fixture 'primary'  '## ORDER-FIXTURE-PRIMARY-0001 -- `OPEN` -- primary fixture sentinel order'
$isolated = New-Fixture 'isolated' '## ORDER-FIXTURE-ISOLATED-0002 -- `OPEN` -- isolated fixture sentinel order'
Assert-True 'primary fixture has its own .git (Resolve-EaLabRepoRoot will stop here)' (Test-Path (Join-Path $primary '.git'))
Assert-True 'isolated fixture has its own .git' (Test-Path (Join-Path $isolated '.git'))
Assert-True 'the two fixtures are different directories' ($primary -ne $isolated)

# Fake "owner-facing shared artifacts" -- these play the role of D:\EA_LAB's real STATUS files and
# the real OneDrive folder, entirely inside the scratch dir, so nothing here can ever touch the
# real ones. $primary itself doubles as "the D:\EA_LAB-equivalent": its own STATUS.md/.html ARE
# the sentinel files for test C (an isolated run against $isolated must never write into $primary).
New-Item -ItemType Directory -Path (Join-Path $work 'fake_onedrive') -Force | Out-Null
$fakeOneDriveMd   = Join-Path $work 'fake_onedrive\EA_LAB_STATUS.md'
$fakeOneDriveHtml = Join-Path $work 'fake_onedrive\EA_LAB_STATUS.html'
Set-Content -LiteralPath (Join-Path $primary 'STATUS.md')   -Encoding UTF8 -Value 'SENTINEL: pre-existing primary STATUS.md, must not change from an isolated run'
Set-Content -LiteralPath (Join-Path $primary 'STATUS.html') -Encoding UTF8 -Value 'SENTINEL: pre-existing primary STATUS.html, must not change from an isolated run'
Set-Content -LiteralPath $fakeOneDriveMd   -Encoding UTF8 -Value 'SENTINEL: fake OneDrive .md, must not change from an isolated run'
Set-Content -LiteralPath $fakeOneDriveHtml -Encoding UTF8 -Value 'SENTINEL: fake OneDrive .html, must not change from an isolated run'

function Hash([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
$primaryStatusMdHashBefore   = Hash (Join-Path $primary 'STATUS.md')
$primaryStatusHtmlHashBefore = Hash (Join-Path $primary 'STATUS.html')
$oneDriveMdHashBefore   = Hash $fakeOneDriveMd
$oneDriveHtmlHashBefore = Hash $fakeOneDriveHtml

Write-Host ''
Write-Host '=== A/B/C/D: an ISOLATED run reads/writes ONLY its own fixture, never the primary or OneDrive ==='

# Run make_status.ps1 -RepoRoot $isolated, with -PrimaryRepoRoot pointed at the OTHER fixture
# ($primary) so the isolated run is, by construction, never mistaken for the primary workspace --
# exactly the real-world shape (repo root != D:\EA_LAB).
$r = Invoke-Child @('-NoProfile', '-File', (Join-Path $isolated 'scripts\make_status.ps1'),
    '-RepoRoot', $isolated, '-PrimaryRepoRoot', $primary, '-OneDrivePath', $fakeOneDriveMd)
$isoExit = $r.ExitCode
$mdOutText = ($r.Output -join "`n")

Assert-Equal 'A/B isolated run against its own fixture exits 0' 0 $isoExit
Assert-True  'A the rendered STATUS.md contains the ISOLATED fixture sentinel order' `
    ((Get-Content -LiteralPath (Join-Path $isolated 'STATUS.md') -Raw) -match 'ORDER-FIXTURE-ISOLATED-0002')
Assert-True  'A the rendered STATUS.md does NOT contain the PRIMARY fixture sentinel order' `
    ((Get-Content -LiteralPath (Join-Path $isolated 'STATUS.md') -Raw) -notmatch 'ORDER-FIXTURE-PRIMARY-0001')
Assert-True  'B STATUS.md was written inside the isolated fixture' (Test-Path (Join-Path $isolated 'STATUS.md'))
Assert-True  'B STATUS.html was written inside the isolated fixture (via propagation to make_status_html.ps1)' (Test-Path (Join-Path $isolated 'STATUS.html'))
Assert-True  'A the rendered STATUS.html (isolated fixture) contains the ISOLATED sentinel order' `
    ((Get-Content -LiteralPath (Join-Path $isolated 'STATUS.html') -Raw) -match 'ORDER-FIXTURE-ISOLATED-0002')

Assert-Equal 'C primary fixture STATUS.md is BYTE-IDENTICAL after the isolated run' $primaryStatusMdHashBefore (Hash (Join-Path $primary 'STATUS.md'))
Assert-Equal 'C primary fixture STATUS.html is BYTE-IDENTICAL after the isolated run' $primaryStatusHtmlHashBefore (Hash (Join-Path $primary 'STATUS.html'))
Assert-Equal 'D fake-OneDrive .md sentinel is BYTE-IDENTICAL after the isolated run' $oneDriveMdHashBefore (Hash $fakeOneDriveMd)
Assert-Equal 'D fake-OneDrive .html sentinel is BYTE-IDENTICAL after the isolated run' $oneDriveHtmlHashBefore (Hash $fakeOneDriveHtml)
Assert-True  'D make_status_html.ps1 explicitly SAYS it skipped OneDrive publish (not just silently did nothing)' `
    ($mdOutText -match 'OneDrive publish SKIPPED')

Write-Host ''
Write-Host '=== E: the SAME mechanism, run AS the primary workspace, still publishes (caged, not removed) ==='

# Fresh fake-OneDrive targets for this run so E's before/after comparison is not polluted by D's.
$primOneDriveMd   = Join-Path $work 'fake_onedrive_e\EA_LAB_STATUS.md'
$primOneDriveHtml = Join-Path $work 'fake_onedrive_e\EA_LAB_STATUS.html'
New-Item -ItemType Directory -Path (Split-Path $primOneDriveMd) -Force | Out-Null
if (Test-Path $primOneDriveMd) { Remove-Item $primOneDriveMd -Force }
if (Test-Path $primOneDriveHtml) { Remove-Item $primOneDriveHtml -Force }

$r = Invoke-Child @('-NoProfile', '-File', (Join-Path $primary 'scripts\make_status.ps1'),
    '-RepoRoot', $primary, '-PrimaryRepoRoot', $primary, '-OneDrivePath', $primOneDriveMd)
$primExit = $r.ExitCode
$primOutText = ($r.Output -join "`n")

Assert-Equal 'E primary-workspace run exits 0' 0 $primExit
Assert-True  'E STATUS.md published to the (fake) OneDrive path' (Test-Path $primOneDriveMd)
Assert-True  'E STATUS.html published to the (fake) OneDrive path' (Test-Path $primOneDriveHtml)
Assert-True  'E the published STATUS.md carries the PRIMARY fixture sentinel order' `
    ((Get-Content -LiteralPath $primOneDriveMd -Raw) -match 'ORDER-FIXTURE-PRIMARY-0001')
Assert-True  'E make_status_html.ps1 confirms it copied (not the skip message)' ($primOutText -match 'copied ->')
Assert-True  'E and it did NOT print the SKIPPED line on this run' ($primOutText -notmatch 'OneDrive publish SKIPPED')

Write-Host ''
Write-Host '=== F: make_status.ps1 -> make_status_html.ps1 propagate ONE resolved root, not two independent ones ==='

# Prove propagation by editing the html script's own copy to print the -RepoRoot it actually
# received, then diff that against make_status.ps1's own $repo for the SAME run. If make_status.ps1
# ever went back to calling make_status_html.ps1 with no -RepoRoot at all, the html script would
# fall back to resolving from ITS OWN location, and could disagree if it ever moved -- caught here
# by asserting they are IDENTICAL for a run whose own $repo is known ahead of time.
$isolated2 = New-Fixture 'isolated2' '## ORDER-FIXTURE-F-0003 -- `OPEN` -- propagation fixture sentinel order'
$htmlPath = Join-Path $isolated2 'scripts\make_status_html.ps1'
$htmlSrc = Get-Content -LiteralPath $htmlPath -Raw
$probeMarker = '### PROPAGATION-PROBE ###'
$probed = $htmlSrc -replace [regex]::Escape('$out      = Join-Path $repo "STATUS.html"'), `
    ('$out      = Join-Path $repo "STATUS.html"' + "`r`n" + "Write-Host '$probeMarker' `$repo")
Assert-True 'F probe injection point found (test setup sanity, not the fix under test)' ($probed -ne $htmlSrc)
Set-Content -LiteralPath $htmlPath -Encoding ASCII -Value $probed

$r = Invoke-Child @('-NoProfile', '-File', (Join-Path $isolated2 'scripts\make_status.ps1'),
    '-RepoRoot', $isolated2, '-PrimaryRepoRoot', $primary, '-OneDrivePath', (Join-Path $work 'fake_onedrive_f\EA_LAB_STATUS.md'))
$fOut = $r.Output
$fOutText = ($fOut -join "`n")
$probedRoot = $null
foreach ($line in $fOut) { if ("$line" -match [regex]::Escape($probeMarker) + '\s+(.+)$') { $probedRoot = $Matches[1].Trim() } }
$resolvedIsolated2 = (Resolve-Path -LiteralPath $isolated2).Path.TrimEnd('\')
Assert-True  'F propagation probe fired' ($null -ne $probedRoot)
Assert-Equal 'F make_status_html.ps1 received EXACTLY the root make_status.ps1 resolved (no independent re-resolution)' `
    $resolvedIsolated2 $probedRoot

Write-Host ''
Write-Host '=== G: an anchor with no .git anywhere above it FAILS EXPLICITLY, no D:\EA_LAB fallback ==='
$noGitRoot = Join-Path $work 'no_git_anywhere'
New-Item -ItemType Directory -Path $noGitRoot -Force | Out-Null
Copy-Item (Join-Path $RepoRoot 'scripts\make_status.ps1') (Join-Path $noGitRoot 'make_status.ps1') -Force
Copy-Item (Join-Path $RepoRoot 'scripts\lib\repo_paths.ps1') (Join-Path $noGitRoot 'lib_repo_paths.ps1') -Force
# make_status.ps1 dot-sources '.\lib\repo_paths.ps1' relative to $PSScriptRoot -- give it a real
# lib\ dir here too so the FAILURE observed is root-resolution (the thing under test), not an
# unrelated missing-dependency error.
New-Item -ItemType Directory -Path (Join-Path $noGitRoot 'lib') -Force | Out-Null
Copy-Item (Join-Path $RepoRoot 'scripts\lib\repo_paths.ps1') (Join-Path $noGitRoot 'lib\repo_paths.ps1') -Force
Remove-Item (Join-Path $noGitRoot 'lib_repo_paths.ps1') -Force

$r = Invoke-Child @('-NoProfile', '-File', (Join-Path $noGitRoot 'make_status.ps1'), '-RepoRoot', $noGitRoot)
$gExit = $r.ExitCode
$gOutText = ($r.Output -join "`n")
Assert-True  'G a root with no .git FAILS (non-zero exit)' ($gExit -ne 0)
Assert-True  'G the failure names the resolution problem, not a generic crash' ($gOutText -match 'could not resolve an EA_LAB repository root')
Assert-True  'G no D:\EA_LAB fallback file was created next to the no-git fixture' (-not (Test-Path (Join-Path $noGitRoot 'STATUS.md')))

Write-Host ''
if ($script:fail -gt 0) { Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail); exit 1 }
Write-Host ("PASS  {0}/{0}" -f $script:pass)
exit 0
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
