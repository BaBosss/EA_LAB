# make_status.ps1 - regenerate STATUS.md (one-file mobile dashboard) + copy to OneDrive.
# Agents run this after every commit (AGENTS.md rule 7); safe to run manually anytime.
# ASCII-only source on purpose: PowerShell 5.1 chokes on BOM-less UTF-8 Thai literals.
#
# WORKTREE ISOLATION (monitoring-status-audit follow-on). Until this param block, $repo was
# hardcoded to "D:\EA_LAB" -- so running this script from ANY isolated worktree silently read
# and wrote against the SHARED primary checkout and its live OneDrive-synced files instead of
# the worktree the caller was actually sandboxed to (reproduced directly in that earlier
# session: an incidental run from an isolated worktree overwrote D:\EA_LAB\STATUS.html and its
# OneDrive copy). $repo now resolves from where THIS SCRIPT FILE lives on disk (or an explicit
# -RepoRoot), via the same Resolve-EaLabRepoRoot walker scripts\daily_monitor.ps1 already uses --
# not invented here. A root that cannot be resolved (no .git found walking up) THROWS and stops
# the script; there is no fallback to "D:\EA_LAB" on failure.
#
# PUBLICATION STAYS GATED, NOT REMOVED: the OneDrive copy below only fires when the resolved
# root equals -PrimaryRepoRoot (default 'D:\EA_LAB', the one real owner checkout). Any other
# resolved root -- an isolated worktree, a CI checkout, a test fixture -- is, by construction,
# not the primary workspace, so it can never publish to the owner's shared files by accident.
# -PrimaryRepoRoot and -OneDrivePath are override points ONLY for tests (see
# scripts\_test\run_make_status_worktree_isolation_tests.ps1); their defaults reproduce the
# exact prior behavior for the real primary checkout.
param(
    [string]$RepoRoot = '',
    [string]$PrimaryRepoRoot = 'D:\EA_LAB',
    [string]$OneDrivePath = 'C:\Users\patip\OneDrive\EA_LAB_STATUS.md'
)
. (Join-Path $PSScriptRoot 'lib\repo_paths.ps1')
$repo = if ($RepoRoot) { Resolve-EaLabRepoRoot -AnchorPath $RepoRoot } else { Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath }
$isPrimaryWorkspace = ($repo -eq $PrimaryRepoRoot.TrimEnd('\'))

$ErrorActionPreference = "SilentlyContinue"
$out  = Join-Path $repo "STATUS.md"
$oneDrive = $OneDrivePath

$now = Get-Date -Format "yyyy-MM-dd HH:mm"
$branch = git -C $repo rev-parse --abbrev-ref HEAD

# --- taskboard read: same "unreadable must not equal silent nothing" rule as ORDER-612 -------
#
# Design row 4 ("make_status.ps1 still has an 'unreadable = nothing found' path") named THIS
# block too, not only the Control Room read below. Under the file-wide SilentlyContinue, a
# missing/unreadable AGENT_TASKBOARD.md and a taskboard with genuinely zero '## ORDER-' lines
# both produced $null -- one line in the rendered page for two different facts. Narrowed the
# same way ORDER-612 narrows around Get-VerifiedSnapshot: EAP='Stop' for the read alone, an
# explicit UNKNOWN line on failure, an explicit placeholder on a real empty queue, so the two
# cases are never the same bytes in STATUS.md.
#
# ORDER: taskboard-active-split-20260822. AGENT_TASKBOARD.md is now a manifest; its ORDER
# blocks live in taskboards/active/*. scripts/lib/taskboard_source.ps1 reconstructs the full
# logical active board (declared parts, in order) so this page keeps seeing every order.
. (Join-Path $PSScriptRoot 'lib\taskboard_source.ps1')
$savedEapTb = $ErrorActionPreference
$ErrorActionPreference = 'Stop'
try {
  $orders = Get-TaskboardActiveLogicalLines -RepoRoot $repo -Mode Working |
    Where-Object { $_ -match '^## ORDER-' } |
    ForEach-Object { $_ -replace '^## ', '- ' }
  if (-not $orders) { $orders = @('- (no open orders -- taskboard read OK, zero matching lines)') }
} catch {
  $orders = @("- UNKNOWN: AGENT_TASKBOARD.md could not be read ($($_.Exception.Message))")
} finally {
  $ErrorActionPreference = $savedEapTb
}

$log = git -C $repo log --oneline -12 | ForEach-Object { "- $_" }

# --- ORDER-612 (S4): the Control Room block, from a VERIFIED snapshot or from nothing --------
#
# Design row 4 ("make_status.ps1 still has an 'unreadable = nothing found' path") is what this
# closes. The rule is NOT "never fail" and NOT "always fail": it is that this page never prints a
# number it did not obtain through snapshot_validator.
#
# PRE-REGISTERED, and deliberately different from monitor_coverage.ps1's answer to the same three
# states (both are written down in scripts\lib\snapshot_reader.ps1):
#   OK          -> render the verdict and the counts.
#   REFUSED     -> render a REFUSED banner with the refusal text. NO numbers. exit 0.
#   UNAVAILABLE -> render an UNAVAILABLE banner. NO numbers. exit 0.
#
# Why exit 0 in both failure states, when the daily chain goes red for the same input: this script
# runs after EVERY commit (AGENTS.md rule 7). A reader that fails closed on a MISSING snapshot
# would convert "no snapshot has been built yet" -- true in a fresh clone, and true for anyone who
# has not run the builder -- into "this repo cannot finish a commit". That is a self-inflicted
# outage, not a safety property, and absence already IS loud in the place that owns it: the daily
# chain returns a hard failure token for exactly the same three states.
#
# $ErrorActionPreference is 'SilentlyContinue' for this whole file, which is itself the
# "unreadable = nothing found" habit. It is narrowed to 'Continue' around this block so a failure
# here cannot be swallowed; Get-VerifiedSnapshot is preference-independent by construction (it
# keeps native stderr out of the pipeline), and that independence is asserted by
# scripts\_test\run_monitor_integrity_tests.ps1.
$savedEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
. (Join-Path $repo 'scripts\lib\snapshot_reader.ps1')
$cr = Get-VerifiedSnapshot -SnapshotPath (Join-Path $repo 'portfolio\control_room_snapshot.json') -RepoRoot $repo
$ErrorActionPreference = $savedEap

$crLines = Format-ControlRoomBlock -Verified $cr

# --- AUDIT C, C-A10 (2026-08-20, lane M0-L1): monitoring-chain health on the operator surface ---
#
# MEASURED on canonical 649207d6: portfolio\daily_monitor_last_success.txt read 20 days old and
# portfolio\MONITOR_ALERT.txt carried a standing "monitoring chain UNHEALTHY: snapshot, ..." alert,
# while neither STATUS.md nor STATUS.html mentioned "last success", "daily_monitor" or
# "MONITOR_ALERT" anywhere -- the ONLY monitoring indicator on this page was
# Format-ControlRoomBlock above, which is fed by the very snapshot the outage stops refreshing.
# This block gives the operator the chain's OWN statement about itself, independent of whether the
# snapshot it produces still verifies. No new threshold: the overdue bar is the same
# meta.stale_bar_hours C-A1 already reads (via $cr.Age.StaleBarHours), so an unavailable snapshot
# yields an honest UNKNOWN bar rather than an invented number.
. (Join-Path $repo 'scripts\lib\monitor_coverage.ps1')
$chainBarHours = if ($null -ne $cr.Age -and $null -ne $cr.Age.StaleBarHours) { [double]$cr.Age.StaleBarHours } else { 0 }
$chainHealth = Get-MonitorChainHealth -RepoRoot $repo -BarHours $chainBarHours
$chainLines = Format-MonitorChainBlock -Health $chainHealth

$body = @()
$body += "# EA_LAB STATUS  (auto-generated $now / branch: $branch)"
$body += ""
$body += "> Auto-regenerated by scripts\make_status.ps1 after every commit - do not edit by hand."
$body += "> Full detail: PROJECT_STATE.md / work queue: AGENT_TASKBOARD.md"
$body += ""
$body += "## Monitoring chain health"
$body += $chainLines
$body += ""
$body += "## Control Room (verified snapshot only)"
$body += $crLines
$body += ""
$body += "## Work queue (all orders)"
$body += $orders
$body += ""
$body += "## Recent commits"
$body += $log
$body | Set-Content $out -Encoding UTF8

# PUBLICATION GATE: see the WORKTREE ISOLATION note at the top of this file. $isPrimaryWorkspace
# is FALSE for any resolved root other than -PrimaryRepoRoot, so an isolated worktree or test
# fixture never reaches Copy-Item against the owner's real OneDrive files, however Test-Path
# resolves on this machine.
if ($isPrimaryWorkspace -and (Test-Path (Split-Path $oneDrive))) {
  Copy-Item $out $oneDrive -Force
  Copy-Item (Join-Path $repo "EA_MASTER_INDEX.csv") (Join-Path (Split-Path $oneDrive) 'EA_MASTER_INDEX.csv') -Force
}

# STATUS.html - single-file visual dashboard (same data, same OneDrive drop). The resolved root
# and primary-workspace decision are PASSED THROUGH, not re-resolved: two independent
# Resolve-EaLabRepoRoot calls (one here, one inside make_status_html.ps1) could in principle
# disagree if the two scripts ever lived at different depths; passing the already-resolved
# values removes that possibility entirely.
& (Join-Path $PSScriptRoot "make_status_html.ps1") -RepoRoot $repo -IsPrimaryWorkspace $isPrimaryWorkspace -OneDrivePath (Join-Path (Split-Path $oneDrive) 'EA_LAB_STATUS.html')

# EA_LAB_MAP.html - visual canvas map of every EA in EA_MASTER_INDEX.csv (docs\memory_control\FACT_OWNER_MAP.md row 10b).
# Generation runs in ANY worktree (make_ea_map.py resolves its own repo root from its file
# location and only reads EA_MASTER_INDEX.csv, same non-mutating contract as the rest of this
# pipeline). Python comes from Assert-PortablePython -Provision (scripts\use_python.ps1) -- the
# same call .githooks\pre-commit already makes -- so a worktree missing tools\python312\python312.zip
# (gitignored; not checked out per-worktree) hydrates it from the primary checkout instead of
# failing. The OneDrive copy reuses the SAME $isPrimaryWorkspace gate as the STATUS.md/.html
# copies above -- see the WORKTREE ISOLATION note at the top of this file -- so an isolated
# worktree can regenerate the map locally but can never publish it to the owner's OneDrive.
. (Join-Path $PSScriptRoot "use_python.ps1")
$pyExe = Assert-PortablePython -Root $repo -Provision
& $pyExe (Join-Path $PSScriptRoot "make_ea_map.py")
if ($isPrimaryWorkspace -and (Test-Path (Split-Path $oneDrive))) {
  Copy-Item (Join-Path $repo "EA_LAB_MAP.html") (Join-Path (Split-Path $oneDrive) 'EA_LAB_MAP.html') -Force
}

