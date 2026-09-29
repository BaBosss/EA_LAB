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
  H. STATUS.html consumes a split active-taskboard manifest plus the separate merge board, counts
     known nonterminal and fail-visible UNPARSEABLE rows in the open queue, sees USER-ACTION in an
     active part, and remains isolated.

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
    Copy-Item (Join-Path $RepoRoot 'scripts\lib\taskboard_source.ps1') (Join-Path $root 'scripts\lib\taskboard_source.ps1') -Force

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
Write-Host '=== H: split active taskboard + merge board feed STATUS.html without weakening isolation ==='
$split = New-Fixture 'split' '## ORDER-FIXTURE-LEGACY-0004 -- `OPEN` -- overwritten by split manifest'
$constructionEmoji = [char]::ConvertFromUtf32(0x1F6A7)
# Exact UTF-8 active-board headers, Base64-encoded so this deliberately ASCII-only PowerShell
# source remains safe under Windows PowerShell 5.1's ANSI reading of BOM-less .ps1 files.
$realOrder045 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('IyMgT1JERVItMDQ1IOKAlCBNVDQgZGVtbyBleHBlcmltZW50ICMyOiBVbk5vbUd1YWkgKyBSU0kgZnJvbSBwaXBzICjguITguLnguYgsIOC4muC4seC4jeC4iuC4teC5g+C4q+C4oeC5iCkg4oCUIGBXQUlUSU5HLVVTRVIgKGF0dGFjaCkg4oaSIOC5geC4peC5ieC4p+C4hOC5iOC4reC4ouC5gOC4m+C5h+C4mSBtb25pdG9yaW5nIGxvb3BgIMK3ICoq4LmA4LiI4LmJ4Liy4LiC4Lit4LiHOiB1c2VyIChhdHRhY2gpICsgQ2xhdWRlIChqdWRnZSkqKiBfKOC4reC4reC4gSAyMDI2LTA3LTA3IOC4q+C4peC4seC4hyB1c2VyIOC4reC4meC4uOC4oeC4seC4leC4tClf'))
$realOrder1269 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('IyMgT1JERVItMTI2OSDigJQgW2ZhY3RvcnkvUzJdIFRoZSBhcHByb3ZhbCB0aGF0IGF1dGhvcmlzZXMgdGhlIENvdmVyYWdlIHRyYW5zZmVyIGJpbmRzIGFuIGV2b2x2aW5nIHdob2xlIHN0b3JlLCBhbmQgdGhlIG93bmVyJ3Mgb3duIGhhbmRvdXQgdGVsbHMgdGhlbSB0byB3ZWFrZW4gaXRzIGNoZWNrZXIg4oCUIGAjMSArICMzIERPTkUgMjAyNi0wOC0wNGAgKGxhbmUgYFMtMjAyNi0wOC0wNC1DT1JSRUNUM2A6IGBlMjcyYTM0YmAgIzMgZmlyc3QgZm9ybSDCtyBgZGRmMzE1M2ZgICMxICsgIzMgcmV3b3JrZWQgwrcgYDkyOWYzYjE4YCB0aGUgdGllciB3aXJpbmcpIMK3ICoqIzIgYW5kICM0IHN0aWxsIE9QRU4qKiDCtyDguJfguLPguYTguJTguYk6IENsYXVkZS9PcHVzIChjb3JyZWN0aW9ucyBsYW5lKSDCtyDwn5GJIOC5geC4meC4sDogQ2xhdWRl'))
$realOrder162 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('IyMgT1JERVItMTYyIOKAlCBbaW52ZXN0aWdhdGlvbl0gfn5NVDUgdGVzdGVyIGVuZ2luZSBkcmlmdH5+IOKGkiAqKlJPT1QgQ0FVU0UgPSBsZXZlcmFnZSB1bnBpbm5hYmxlICsgbWFyZ2luLWdhdGUqKiAo4LmE4Lih4LmI4LmD4LiK4LmIIGVuZ2luZSBkcmlmdCkg4oCUIGBSRVNPTFZFRChDbGF1ZGUgMjAyNi0wNy0yMyDguKPguK3guJogMykg4oCUIOC5gOC4q+C4peC4t+C4reC5gOC4qOC4qeC5gOC4peC5h+C4gSAxIOC4reC4ouC5iOC4suC4h+C4ouC4seC4h+C4hOC5ieC4suC4hyDCtyDguYHguJXguIHguYDguJvguYfguJkgT1JERVItMTY1IChUMCBibG9ja2VyKWA='))
$realOrder215 = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('IyMgT1JERVItMjE1IOKAlCBb8J+UtCDguYDguIfguLTguJnguIjguKPguLTguIcgwrcgaW50ZWdyaXR5XSBNYXRjaGFHcmlkIENIRkpQWTogdmVyZGljdCBDT1JFIOC4reC5ieC4suC4hyBnZW5ldGljIHJ1biDguJfguLXguYjguYTguKHguYjguKHguLUgZmluZS1zdGFnZSDigJQgYFBBUlQgMSBET05FKENsYXVkZS9PcHVzIDIwMjYtMDctMjUpIMK3IFBBUlQgMiBDVVRMT1NTLVFVRVNUSU9OIERPTkUoQ2xhdWRlL1Nvbm5ldCAyMDI2LTA3LTI2KTogImJvdW5kZWQrU0wiIOC4luC4reC4meC5geC4peC5ieC4pyDigJQgc2FmZXR5IHN3aXRjaCDguYTguKHguYjguJXguK3guJrguKrguJnguK3guIcgwrcgcmUtbWVhc3VyZSBmdW5uZWwg4Lii4Lix4LiHIE9QRU5g'))
$realOrderDemoReplay = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('IyMgT1JERVItREVNTy1TQU1FUEVSSU9ELVJFUExBWS0yMDI2MDkxNSDigJQgW3Jlc2VhcmNoL2RpYWdub3N0aWNdIERlbW8gdnMgc2FtZS1wZXJpb2QgZnJvemVuLWJ1bmRsZSByZXBsYXkg4oCUIGBFWEVDVVRFRCAvIERPQ1VNRU5URURfV0lUSF9CTE9DS0VSUyAvIEVYQUNUX1BBUklUWV9OT1RfQ0VSVElGSUFCTEVg'))
New-Item -ItemType Directory -Path (Join-Path $split 'taskboards\active') -Force | Out-Null
[System.IO.File]::WriteAllLines((Join-Path $split 'AGENT_TASKBOARD.md'), [string[]]@(
    '# Split fixture manifest',
    '<!-- TASKBOARD-ACTIVE-PARTS',
    'taskboards/active/A-open.md',
    'taskboards/active/Z-mixed.md',
    '-->'
), (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllLines((Join-Path $split 'taskboards\active\A-open.md'), [string[]]@(
    '## ORDER-SPLIT-OPEN-1001 -- `OPEN` -- rendered open row',
    '## ORDER-SPLIT-BLOCKED-1002 -- `BLOCKED_C_ENVIRONMENT_DEPENDENCY` -- rendered blocked row',
    '## ORDER-SPLIT-PARTIAL-1003 -- `PARTIAL` -- rendered partial row',
    '## ORDER-SPLIT-DONE-1004 -- `DONE blocked with reasons retained for history` -- terminal row',
    $realOrder045,
    '## ORDER-SPLIT-WAITING-1006 -- `WAITING` -- rendered waiting row',
    '## ORDER-SPLIT-INPROGRESS-1007 -- `IN-PROGRESS(worker)` -- rendered in-progress row',
    '## ORDER-SPLIT-RUNNING-1008 -- `RUNNING` -- rendered running row',
    '## ORDER-SPLIT-PARKED-1009 -- `PARKED` -- rendered parked row',
    '## ORDER-SPLIT-PENDING-1010 -- `PENDING` -- rendered pending row',
    ("## ORDER-SPLIT-EMOJI-OPEN-1011 -- ``$constructionEmoji OPEN`` -- leading-symbol OPEN row"),
    '## ORDER-SPLIT-BLOCKEDREVIEW-1012 -- `BLOCKED_REVIEW` -- rendered as BLOCKED',
    '## ORDER-SPLIT-NOBT-OPEN-1013 -- legacy header OPEN pending owner response',
    '## ORDER-SPLIT-NOBT-DONE-1014 -- legacy header DONE(2026-09-29)',
    '## ORDER-SPLIT-REVIEWED-HOLDOUT-1015 -- `REVIEWED(2026-09-29) -- holdout remains unspent` -- terminal row',
    '## ORDER-SPLIT-REVIEWED-QUESTION-1016 -- `REVIEWED(2026-09-29) -- open question retained` -- terminal row',
    '## ORDER-SPLIT-DONE-REVIEWED-1017 -- `DONE(2026-09-29, `abc123`) + REVIEWED(2026-09-29)` -- terminal split-code row',
    '## ORDER-SPLIT-DONE-THEN-OPEN-1018 -- `DONE` -- `OPEN` -- nonterminal span wins',
    'USER-ACTION: split active part requires owner input'
), (New-Object System.Text.UTF8Encoding($false)))
[System.IO.File]::WriteAllLines((Join-Path $split 'taskboards\active\Z-mixed.md'), [string[]]@(
    '## ORDER-SPLIT-REOPENED-1005 -- `RE-OPENED` -- rendered reopened row',
    '## ORDER-SPLIT-OPENSTANDING-1006 -- `OPEN-STANDING` -- rendered standing row',
    '## ORDER-SPLIT-CLAIMED-1007 -- `CLAIMED(worker)` -- rendered claimed row',
    '## ORDER-SPLIT-DONEVAR-1008 -- `DONE_FINAL` -- terminal done variant',
    '## ORDER-SPLIT-CLOSED-1009 -- `CLOSED` -- terminal closed row',
    '## ORDER-SPLIT-CLOSEDVAR-1010 -- `CLOSED_FINAL` -- terminal closed variant',
    '## ORDER-SPLIT-REVIEWED-1011 -- `REVIEWED` -- terminal reviewed row',
    '## ORDER-SPLIT-REVIEWEDVAR-1012 -- `REVIEWED_FINAL` -- terminal reviewed variant',
    '## ORDER-SPLIT-SKIPPED-1013 -- `SKIPPED` -- terminal skipped row',
    '## ORDER-SPLIT-SKIPPEDVAR-1014 -- `SKIPPED_FINAL` -- terminal skipped variant',
    '## ORDER-SPLIT-DONESTAGE-1015 -- `DONE-STOPPED-AT-STAGE-2` -- terminal canonical composite',
    '## ORDER-SPLIT-DONEPHASE-1016 -- `DONE-PHASE1` -- terminal canonical composite',
    '## ORDER-SPLIT-REVIEWEDCLOSED-1017 -- `REVIEWED/CLOSED` -- terminal canonical composite',
    '## ORDER-SPLIT-BUILTFUNNELED-1018 -- `BUILT+FUNNELED` -- terminal canonical composite',
    '## ORDER-SPLIT-BUILTCLOSED-1019 -- `BUILT+CLOSED` -- terminal canonical composite',
    '## ORDER-SPLIT-STAGE2DONE-1020 -- `STAGE2-DONE` -- terminal canonical composite',
    '## ORDER-SPLIT-BUILT-1021 -- `BUILT` -- terminal canonical row',
    '## ORDER-SPLIT-FUNNELED-1022 -- `FUNNELED` -- terminal canonical row',
    '## ORDER-SPLIT-NONSTATUS-1023 -- `implementation blocked with reasons` -- unknown span is fail-visible',
    $realOrder1269,
    $realOrder215,
    $realOrderDemoReplay,
    '## ORDER-SPLIT-STATUSLESS-1024 -- active order with no classifiable status',
    '## ORDER-SPLIT_STATUSLESS-1025 -- underscore-bearing active id with no classifiable status',
    '## ORDER-SPLIT-PROSE-REVIEWED-1026 -- `prose REVIEWED(Claude)` -- not a status at span start',
    $realOrder162
), (New-Object System.Text.UTF8Encoding($false)))
Set-Content -LiteralPath (Join-Path $split 'AGENT_TASKBOARD_MERGE.md') -Encoding UTF8 -Value @(
    '# Separate legacy merge board',
    '## MERGE-SPLIT-HOLD-2001 -- `HOLD` -- rendered merge hold row'
)

$splitOneDrive = Join-Path $work 'fake_onedrive_h\EA_LAB_STATUS.html'
New-Item -ItemType Directory -Path (Split-Path $splitOneDrive) -Force | Out-Null
Set-Content -LiteralPath $splitOneDrive -Encoding UTF8 -Value 'SENTINEL: split fixture must not publish here'
$splitOneDriveHashBefore = Hash $splitOneDrive
$r = Invoke-Child @('-NoProfile', '-File', (Join-Path $split 'scripts\make_status_html.ps1'),
    '-RepoRoot', $split, '-PrimaryRepoRoot', $primary, '-OneDrivePath', $splitOneDrive)
$splitOutText = ($r.Output -join "`n")
$splitHtml = if (Test-Path (Join-Path $split 'STATUS.html')) {
    Get-Content -LiteralPath (Join-Path $split 'STATUS.html') -Raw
} else { '' }

Assert-Equal 'H split-manifest STATUS.html generation exits 0' 0 $r.ExitCode
$expectedOpenIds = @(
    'ORDER-SPLIT-OPEN-1001', 'ORDER-SPLIT-BLOCKED-1002', 'ORDER-SPLIT-PARTIAL-1003',
    'ORDER-045', 'ORDER-SPLIT-WAITING-1006',
    'ORDER-SPLIT-INPROGRESS-1007', 'ORDER-SPLIT-RUNNING-1008',
    'ORDER-SPLIT-PARKED-1009', 'ORDER-SPLIT-PENDING-1010',
    'ORDER-SPLIT-EMOJI-OPEN-1011', 'ORDER-SPLIT-BLOCKEDREVIEW-1012',
    'ORDER-SPLIT-NOBT-OPEN-1013', 'ORDER-SPLIT-DONE-THEN-OPEN-1018',
    'ORDER-SPLIT-REOPENED-1005', 'ORDER-SPLIT-OPENSTANDING-1006',
    'ORDER-SPLIT-CLAIMED-1007', 'MERGE-SPLIT-HOLD-2001',
    'ORDER-SPLIT-NONSTATUS-1023', 'ORDER-1269', 'ORDER-215',
    'ORDER-DEMO-SAMEPERIOD-REPLAY-20260915', 'ORDER-SPLIT-STATUSLESS-1024',
    'ORDER-SPLIT_STATUSLESS-1025', 'ORDER-SPLIT-PROSE-REVIEWED-1026', 'ORDER-162'
)
foreach ($id in $expectedOpenIds) {
    Assert-True "H nonterminal/unparseable row $id is rendered" ($splitHtml -match [regex]::Escape($id))
}
$expectedKnownStatuses = [ordered]@{
    'ORDER-SPLIT-OPEN-1001'           = 'OPEN'
    'ORDER-SPLIT-BLOCKED-1002'        = 'BLOCKED'
    'ORDER-SPLIT-PARTIAL-1003'        = 'PARTIAL'
    'ORDER-045'                       = 'WAITING-USER'
    'ORDER-SPLIT-WAITING-1006'        = 'WAITING'
    'ORDER-SPLIT-INPROGRESS-1007'     = 'IN-PROGRESS'
    'ORDER-SPLIT-RUNNING-1008'        = 'RUNNING'
    'ORDER-SPLIT-PARKED-1009'         = 'PARKED'
    'ORDER-SPLIT-PENDING-1010'        = 'PENDING'
    'ORDER-SPLIT-EMOJI-OPEN-1011'     = 'OPEN'
    'ORDER-SPLIT-BLOCKEDREVIEW-1012'  = 'BLOCKED'
    'ORDER-SPLIT-NOBT-OPEN-1013'      = 'OPEN'
    'ORDER-SPLIT-DONE-THEN-OPEN-1018' = 'OPEN'
    'ORDER-SPLIT-REOPENED-1005'       = 'OPEN'
    'ORDER-SPLIT-OPENSTANDING-1006'   = 'OPEN'
    'ORDER-SPLIT-CLAIMED-1007'        = 'CLAIMED'
    'MERGE-SPLIT-HOLD-2001'           = 'HOLD'
}
foreach ($id in $expectedKnownStatuses.Keys) {
    $encodedId = [regex]::Escape($id)
    $encodedStatus = [regex]::Escape($expectedKnownStatuses[$id])
    Assert-True "H known status $id is classified $($expectedKnownStatuses[$id])" (
        $splitHtml -match "<td class='mono'>$encodedId</td><td><span class='tag [^']+'>$encodedStatus</span>"
    )
}
$expectedTerminalIds = @(
    'ORDER-SPLIT-DONE-1004', 'ORDER-SPLIT-DONEVAR-1008',
    'ORDER-SPLIT-NOBT-DONE-1014', 'ORDER-SPLIT-REVIEWED-HOLDOUT-1015',
    'ORDER-SPLIT-REVIEWED-QUESTION-1016', 'ORDER-SPLIT-DONE-REVIEWED-1017',
    'ORDER-SPLIT-CLOSED-1009', 'ORDER-SPLIT-CLOSEDVAR-1010',
    'ORDER-SPLIT-REVIEWED-1011', 'ORDER-SPLIT-REVIEWEDVAR-1012',
    'ORDER-SPLIT-SKIPPED-1013', 'ORDER-SPLIT-SKIPPEDVAR-1014',
    'ORDER-SPLIT-DONESTAGE-1015', 'ORDER-SPLIT-DONEPHASE-1016',
    'ORDER-SPLIT-REVIEWEDCLOSED-1017', 'ORDER-SPLIT-BUILTFUNNELED-1018',
    'ORDER-SPLIT-BUILTCLOSED-1019', 'ORDER-SPLIT-STAGE2DONE-1020',
    'ORDER-SPLIT-BUILT-1021', 'ORDER-SPLIT-FUNNELED-1022'
)
foreach ($id in $expectedTerminalIds) {
    Assert-True "H terminal row $id is absent from the open queue" ($splitHtml -notmatch [regex]::Escape($id))
}
foreach ($id in @(
    'ORDER-SPLIT-NONSTATUS-1023', 'ORDER-1269', 'ORDER-215',
    'ORDER-DEMO-SAMEPERIOD-REPLAY-20260915', 'ORDER-SPLIT-STATUSLESS-1024',
    'ORDER-SPLIT_STATUSLESS-1025', 'ORDER-SPLIT-PROSE-REVIEWED-1026', 'ORDER-162'
)) {
    $encodedId = [regex]::Escape($id)
    Assert-True "H unparseable row $id has warning/red status" (
        $splitHtml -match "<td class='mono'>$encodedId</td><td><span class='tag t-user'>UNPARSEABLE</span>"
    )
}
$splitRenderedRows = [regex]::Matches($splitHtml, '<td class=''mono''>(?:ORDER|MERGE)-[A-Z0-9_-]+</td>').Count
Assert-Equal 'H rendered open-row count equals every known nonterminal plus UNPARSEABLE row' $expectedOpenIds.Count $splitRenderedRows
$expectedOpenCountMarkup = '<div class="n" style="color:var(--blue)">' + $expectedOpenIds.Count + '</div>'
Assert-True  'H OPEN_COUNT includes every known nonterminal plus UNPARSEABLE row' ($splitHtml.Contains($expectedOpenCountMarkup))
Assert-True  'H USER-ACTION text from an active part is rendered' ($splitHtml -match 'split active part requires owner input')
Assert-True  'H USER_ACTION_COUNT is exactly one' ($splitHtml -match '<div class="n" style="color:var\(--red\)">1</div>')
Assert-Equal 'H isolated split run leaves fake OneDrive BYTE-IDENTICAL' $splitOneDriveHashBefore (Hash $splitOneDrive)
Assert-True  'H isolated split run explicitly skips OneDrive publication' ($splitOutText -match 'OneDrive publish SKIPPED')

Write-Host ''
if ($script:fail -gt 0) { Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail); exit 1 }
Write-Host ("PASS  {0}/{0}" -f $script:pass)
exit 0
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
