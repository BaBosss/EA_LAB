# check_verdict_kill.ps1 — WARN-ONLY pre-commit reminder (added 2026-07-16).
#
# Anti-recurrence backstop for a REPEATED failure: killing a source-available EA/signal on a
# default-param smoke without optimizing (SMC×STO 2026-07-16 — nearly killed for nothing, revived
# by the user's optimize+filter push; also the 2026-07-08 double-kill). The VERDICT GATE rule
# exists in CLAUDE.md but reasoning-time rules get rationalized around — this fires a hard reminder
# at COMMIT time so a kill can't land silently.
#
# WARN-ONLY: this script ALWAYS exits 0. It never blocks a commit. Its only job is to print the
# KILL-GATE questions when a commit appears to add a concept-kill verdict WITHOUT optimize evidence,
# so the author consciously confirms (structural kill? optimized on the right home?).

$ErrorActionPreference = 'SilentlyContinue'

# verdict-bearing files worth scanning
$targets = git diff --cached --name-only -- '_triage/*.md' 'EDGE_CATALOG.md' 'AGENT_TASKBOARD.md' 'EA_SCORECARD_AND_REGISTRY.md'
if (-not $targets) { exit 0 }

# only the ADDED lines in this commit
$added = git diff --cached --unified=0 -- $targets | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' }
if (-not $added) { exit 0 }

# a concept-level kill being asserted (not just the word appearing in prose)
$killPat = 'DEAD|REJECT|no[- ]edge|concept.*(ตาย|park|dead)|(ตาย|kill).*concept|dead skeleton|ตายเปล่า'
$killLines = $added | Where-Object { $_ -match $killPat }
if (-not $killLines) { exit 0 }

# optimize / structural evidence anywhere in the staged additions = the kill is (probably) justified
$evidencePat = 'optimi[sz]|ceiling|both-window|plateau|structural|uncapped|flat-lot|cracked|no-source|Model-4|holdout|SPR30|spread-stress'
$hasEvidence = ($added | Where-Object { $_ -match $evidencePat }).Count -gt 0

if (-not $hasEvidence) {
  Write-Output ""
  Write-Output "==================== KILL-GATE REMINDER (warn-only, commit NOT blocked) ===================="
  Write-Output "This commit ADDS a kill/DEAD/REJECT verdict but the staged changes show NO optimize or"
  Write-Output "structural evidence. Before you let this land, confirm (VERDICT GATE + signal-scanner):"
  Write-Output "  [ ] Is the death STRUCTURAL? (recovery-dependent / uncapped-ruin / cracked / no-source)"
  Write-Output "      -> if yes, name it in the verdict and this reminder is satisfied."
  Write-Output "  [ ] Otherwise: did you OPTIMIZE >=3 levers on the RIGHT HOME before killing?"
  Write-Output "      (reversion -> ranger EURUSD/EURGBP/AUDNZD, NOT a trender; momentum -> XAU/GBP)"
  Write-Output "      A low DEFAULT-param smoke is 'not optimized yet', NOT dead."
  Write-Output "  Paid 2026-07-16: SMC×STO killed on default-smoke (0.63-0.89) -> after optimize (StoK 5->13)"
  Write-Output "  + ADX filter = real EURUSD candidate 1.14-1.39 both-window+holdout+Model-4. Nearly lost."
  Write-Output "  If this really is optimize-confirmed/structural, add that word to the verdict & re-commit."
  Write-Output "==========================================================================================="
  Write-Output ""
}
exit 0
