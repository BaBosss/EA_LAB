<#
.SYNOPSIS
  Anti-drift guard for EA_LAB docs. ORDER-093 rewrite (2026-07-11, CODEX-AUDIT A2/C1):
  the deployment inventory portfolio\DEPLOYMENTS.csv is the machine-readable owner of
  "what runs where"; this script validates every other surface AGAINST it instead of
  checking that a few hardcoded legacy strings exist somewhere.
  Warn-only (exit 0) unless -Strict (used by .githooks\pre-commit).

.DESCRIPTION
  Checks:
   1. PROJECT_STATE.md exists and declares the DEPLOYMENTS.csv pointer (section 0.5)
   2. DEPLOYMENTS.csv parses, has required columns, no duplicate account|magic
   2b. GLOBAL magic uniqueness (ORDER-1100/S10) - one magic belongs to exactly one EA across
       every account, with the three ratified legacy exceptions read out of
       factory\magic_allocations.jsonl. Delegated to _triage\factory_os\magic.py so the rule has
       ONE implementation; both inputs are handed to it as judged BYTES, never as repo paths.
   3. every account in the inventory appears in DEMO_DEPLOYMENT_PLAN.md
   4. every inventory row with a magic (status not UNVERIFIED) has a dashboard cohort
      map entry "account|magic" in scripts\live_dashboard.ps1
   5. every dashboard cohort map entry maps back to an inventory row (no ghost rows)
   6. every judge_date in the inventory appears in DEMO_DEPLOYMENT_PLAN.md
   7. no competing single-entry claim outside PROJECT_STATE (EN/TH needles)
   8. owner banner present on secondary owner docs
  ASCII-only on purpose (Windows PowerShell 5.1 reads scripts as ANSI).
  NOTE: data variable is $rows, NOT $inv - PS variables are case-insensitive and
  $inv would collide with the $INV path constant.
#>
[CmdletBinding()]
param(
  [string]$Root = $(if($PSScriptRoot){ (Resolve-Path (Join-Path $PSScriptRoot '..')).Path } else { (Get-Location).Path }),
  [switch]$Strict
)

# ORDER-674. THE READS BELOW ARE JUDGED EVIDENCE AND THIS GUARD READ THE WORKING TREE.
# PROVED before the fix, not inferred: append a duplicate account|magic row to
# portfolio\DEPLOYMENTS.csv, STAGE it, restore the clean worktree copy, run this script ->
#     [OK]   no duplicate account|magic in inventory
#     === CLEAN - no drift detected ===
# The commit writes a corrupted LIVE-MONEY inventory with the gate green. A7 exactly, at the
# highest-value target in the repo -- and this is the guard the pre-commit hook runs FIRST.
. (Join-Path $PSScriptRoot 'lib\evidence.ps1')
# ORDER-1100 (S10): the global magic rule, as one callable both this guard and its cage can drive.
. (Join-Path $PSScriptRoot 'lib\magic_guard.ps1')

$script:warn = 0
$script:toolFail = 0
function ReadJudged($rel){
  # SNAPSHOT: chosen by the CALLER's mode, not by this function -- `Read-Committed` returns the
  # index in hook mode and the disk otherwise, and that is the whole point of routing every read
  # through one reader. This wrapper therefore carries no `# snapshot:` and neither does any of
  # its ~8 call sites: a declaration on each would be a comment restating what the call already
  # decides, which is precisely the substitution ORDER-670's T7 refuses. The same holds for
  # Test-CommittedPath and Get-CommittedPaths below. The lint (L3) skips reader calls for this
  # reason; the ONE read in this file that does not go through the reader is declared, and it is
  # the only one that had a choice to make.
  #
  # One place maps "cannot read" to a COUNTER, never to a pass. A guard whose reader throws
  # must not look identical to a guard whose subject is fine.
  try { return (Read-Committed -RelPath $rel -RepoRoot $Root) }
  catch { Write-Host ("[TOOL] cannot read {0}: {1}" -f $rel, $_.Exception.Message) -ForegroundColor Red
          $script:toolFail++; return $null }
}
function Check($cond,$okMsg,$warnMsg){
  if($cond){ Write-Host "[OK]   $okMsg" -ForegroundColor Green }
  else     { Write-Host "[WARN] $warnMsg" -ForegroundColor Yellow; $script:warn++ }
}
function Has($rel,$needle){
  $t = ReadJudged $rel
  return ($null -ne $t) -and ($t -match [regex]::Escape($needle))
}

# REPO-RELATIVE now, because that is what a judged read is addressed by. The absolute paths
# these used to be are only meaningful on a disk.
$PS   = 'PROJECT_STATE.md'
$DEMO = 'DEMO_DEPLOYMENT_PLAN.md'
$BL   = 'MASTER_BACKLOG.md'
$SC   = 'EA_SCORECARD_AND_REGISTRY.md'
$INV  = 'portfolio/DEPLOYMENTS.csv'
# ORDER-1100 (S10): the magic exception list. Read through the SAME judged reader as the
# inventory, because the rule they are compared under is one rule and two vintages would let a
# staged inventory be judged against a committed exception list.
$ALLOC = 'factory/magic_allocations.jsonl'
$DASH = 'scripts/live_dashboard.ps1'

Write-Host "=== EA_LAB state consistency check (inventory-driven, ORDER-093) ===" -ForegroundColor Cyan
Write-Host (Get-EvidenceMarker -Component 'check_state.ps1')

# 1. canonical entry + inventory pointer
Check (Test-CommittedPath -RelPath $PS -RepoRoot $Root) "PROJECT_STATE.md exists (the entry point)" "PROJECT_STATE.md MISSING - canonical entry gone"
Check (Has $PS 'DEPLOYMENTS.csv') "PROJECT_STATE declares the DEPLOYMENTS.csv inventory pointer" "PROJECT_STATE does not reference portfolio\DEPLOYMENTS.csv (section 0.5 pointer missing)"

# 2. inventory parses + shape
# Import-Csv reads a PATH, so the inventory is read as TEXT through the judged reader and
# parsed from that text. Same bytes, one vintage -- rather than a parser that reaches past the
# reader to the disk, which is the exact shape being fixed.
$rows = $null
$invText = if (Test-CommittedPath -RelPath $INV -RepoRoot $Root) { ReadJudged $INV } else { $null }
if ($null -ne $invText) { try { $rows = @($invText | ConvertFrom-Csv) } catch { $rows = $null } }
Check ($null -ne $rows -and $rows.Count -gt 0) "DEPLOYMENTS.csv parses ($(if($rows){$rows.Count}else{0}) rows)" "portfolio\DEPLOYMENTS.csv missing or unparseable"
if ($null -ne $rows -and $rows.Count -gt 0) {
  $required = @('account','ea_name','magic','symbol','status','judge_date')
  $cols = $rows[0].PSObject.Properties.Name
  $missingCols = @($required | Where-Object { $cols -notcontains $_ })
  Check ($missingCols.Count -eq 0) "inventory has all required columns" ("inventory missing columns: " + ($missingCols -join ', '))

  $withMagic = @($rows | Where-Object { $_.magic -match '^\d+$' })
  $dups = @($withMagic | Group-Object { "$($_.account)|$($_.magic)" } | Where-Object Count -gt 1)
  Check ($dups.Count -eq 0) "no duplicate account|magic in inventory" ("duplicate account|magic: " + (($dups | ForEach-Object Name) -join ', '))

  # ORDER-1260 #5, the PowerShell half. The filter above drops every row whose magic is not a
  # number, and until now it dropped them SILENTLY -- so an ACTIVE deployment with a blank or
  # malformed magic was absent from this duplicate check, from the global rule, and from the
  # cohort-map check, with nothing anywhere reporting a count. magic.py refuses the same shape now
  # (INVENTORY_RUNNING_STATUSES) and check 2b below would surface it, but that check reads the
  # STAGED bytes through the judged reader, and this one reads the same $rows the line above does.
  # The two are kept separate deliberately: a row that this loop can see and 2b cannot is exactly
  # the case worth naming out loud.
  #
  # UNVERIFIED is the declared exemption and it is the same one magic.py declares -- the word
  # already means "the lab has not established what this row is" three checks further down.
  $unreadable = @($rows | Where-Object { $_.magic -notmatch '^\d+$' -and $_.status -eq 'ACTIVE' })
  Check ($unreadable.Count -eq 0) "every ACTIVE inventory row has a readable magic" ("ACTIVE row(s) whose magic is not a number, and which are therefore invisible to every uniqueness check: " + (($unreadable | ForEach-Object { "$($_.account)/$($_.ea_name)" }) -join ', '))

  # 2b. THE GLOBAL MAGIC RULE. ORDER-1100 (slice S10).
  #
  # PROJECT_STATE section 0.5, owner-ratified 2026-08-01: uniqueness scope is GLOBAL -- one magic
  # belongs to exactly one EA across every account -- and this checker "flips to the global rule
  # only when S10 gives it an exception list to read, because flipping it first would redden the
  # state check on three rows the owner has just declared legitimate". The list is
  # factory\magic_allocations.jsonl and it exists now, so the rule is on.
  #
  # The account|magic check above STAYS. It is not superseded: it is strictly weaker (global
  # uniqueness implies it) and the three legacy exceptions pass it by construction, so keeping it
  # costs nothing and keeps the backstop schemas.json names on MagicAllocation.
  #
  # WHY THIS SHELLS OUT INSTEAD OF REIMPLEMENTING THE RULE HERE. The same rule written twice --
  # once in python for the factory, once in PowerShell for the hook -- is two opinions, and the
  # second one is the one nobody drives. _triage\factory_os\magic.py owns it, run_s10_tests.py
  # enumerates it, and this guard asks that module rather than agreeing with it.
  #
  # WHY THE CHILD IS HANDED BYTES AND NOT PATHS. ORDER-674's A7 was exactly this shape: a guard
  # that reached past the judged reader to the working tree passed a duplicate account|magic that
  # was STAGED behind a clean worktree copy. A child process given a repo path would read the
  # disk and reintroduce it. Both inputs therefore go through ReadJudged and are spilled to temp
  # files; the disk is a transport here, not a source.
  # THE RULE ITSELF LIVES IN scripts\lib\magic_guard.ps1 so the cage can drive it without paying
  # 3.0s to spawn this whole script per case -- see that file's header for why that mattered.
  $allocText = if (Test-CommittedPath -RelPath $ALLOC -RepoRoot $Root) { ReadJudged $ALLOC } else { $null }
  $magic = Test-MagicUniqueness -RepoRoot $Root -AllocText $allocText -InvText $invText
  Check $magic.ok "global magic uniqueness (magic.py, with the legacy exception list)" $magic.detail

  # 3. accounts present in the deployment narrative doc
  $demoRaw = if (Test-CommittedPath -RelPath $DEMO -RepoRoot $Root) { (ReadJudged $DEMO) } else { '' }
  if ($null -eq $demoRaw) { $demoRaw = '' }
  $accts = @($rows | Select-Object -ExpandProperty account -Unique)
  $missA = @($accts | Where-Object { $demoRaw -notmatch [regex]::Escape($_) })
  Check ($missA.Count -eq 0) "all $($accts.Count) inventory accounts present in DEMO_DEPLOYMENT_PLAN" ("accounts missing from DEMO plan: " + ($missA -join ', '))

  # 4/5. dashboard cohort map <-> inventory. CR-001 (2026-07-19): the map is GENERATED
  # from DEPLOYMENTS.csv inside live_dashboard.ps1, so coverage/ghost parity is now
  # guaranteed by construction. What can still drift: (4) the generation link itself
  # (someone points the dashboard elsewhere), (5) someone re-introduces a hardcoded
  # "account|magic" literal table that would shadow the inventory.
  $dashRaw = if (Test-CommittedPath -RelPath $DASH -RepoRoot $Root) { (ReadJudged $DASH) } else { '' }
  if ($null -eq $dashRaw) { $dashRaw = '' }
  Check ($dashRaw -match 'DEPLOYMENTS\.csv') "dashboard cohort map is generated from DEPLOYMENTS.csv" "live_dashboard.ps1 no longer references DEPLOYMENTS.csv - cohort map generation link broken (audit A5)"
  $hardKeys = @([regex]::Matches($dashRaw,'"(\d+)\|(\d+)"\s*=') | ForEach-Object { "$($_.Groups[1].Value)|$($_.Groups[2].Value)" })
  Check ($hardKeys.Count -eq 0) "no hardcoded cohort map literals in dashboard (generation only)" ("hardcoded account|magic literals back in live_dashboard.ps1 (would shadow the inventory): " + ($hardKeys -join ', '))

  # 6. judge dates in narrative doc
  $judges = @($rows | Where-Object { $_.judge_date -match '^\d{4}-\d{2}-\d{2}$' } | Select-Object -ExpandProperty judge_date -Unique)
  $missJ = @($judges | Where-Object { $demoRaw -notmatch [regex]::Escape($_) })
  Check ($missJ.Count -eq 0) "all judge dates ($($judges -join ', ')) present in DEMO plan" ("judge dates missing from DEMO plan: " + ($missJ -join ', '))
}

# 7. no competing single-entry claim (English OR Thai) outside PROJECT_STATE
#
#    ORDER-219 REWRITE. The rule being protected is "exactly one doc claims to be the entry
#    point". The old implementation tested for the PHRASE anywhere in the file, which is a
#    different rule: on 2026-07-25 it fired three times on ordinary Thai prose, including on
#    the report that was describing this very bug, and BOTH sessions cleared it by rewording
#    the sentence. That means the rule was never actually enforced that day - it was routed
#    around - and a guard that people learn to reword past protects nothing.
#
#    So match the SHAPE OF A CLAIM, not the vocabulary:
#      - the needle has to sit in a structural assertion: a heading, a bold run, or a
#        blockquote banner. Those are how a doc declares its own standing. A sentence in
#        the middle of a paragraph is discussing the idea, not claiming the title.
#      - a line that names PROJECT_STATE is DEFERRING to it ("canonical entry = PROJECT_STATE"),
#        which is the correct banner every secondary owner doc carries - never a rival claim.
#      - `ENTRY-CLAIM-OK` on the line is the deliberate escape hatch, same convention as the
#        holdout guard below, so the answer to a false positive is a marker in the file rather
#        than silently editing the prose until the check shuts up.
$thaiOnly = -join (0x0E44,0x0E1F,0x0E25,0x0E4C,0x0E40,0x0E14,0x0E35,0x0E22,0x0E27 | ForEach-Object {[char]$_})
$claimNeedle = '(single source of truth|canonical entry|' + [regex]::Escape($thaiOnly) + ')'
$rivals = @()
# ORDER-674 round 1: ENUMERATE AND READ AS JUDGED EVIDENCE. Get-ChildItem picked the sweep's
# population from the DISK, so a rival-claim doc staged with its worktree copy deleted was
# invisible to the one check whose job is "exactly one doc claims the title" -- the same
# enumeration hole T3 closed in the python tier. Get-CommittedPaths follows the mode; in
# worktree mode both behave as before.
foreach($fRel in @(Get-CommittedPaths -Pattern '*.md' -RepoRoot $Root | Where-Object { $_ -ne 'PROJECT_STATE.md' -and $_ -notmatch 'RESUME|RUN_REGISTRY' })){
  $f = [pscustomobject]@{ Name = $fRel }
  $fText = ReadJudged $fRel
  if ($null -eq $fText) { continue }   # counted by $toolFail, which now fails the run
  $n = 0
  foreach($line in ($fText -split "`n")){
    $n++
    if($line -match 'ENTRY-CLAIM-OK'){ continue }
    if($line -notmatch "(?i)$claimNeedle"){ continue }
    if($line -match 'PROJECT_STATE'){ continue }          # deferring to the owner, not claiming
    $isHeading   = $line -match '^\s{0,3}#{1,6}\s'
    $isBold      = $line -match "(?i)\*\*[^*]*$claimNeedle"
    $isBanner    = $line -match '^\s{0,3}>'
    if($isHeading -or $isBold -or $isBanner){ $rivals += ("{0}:{1}" -f $f.Name,$n) }
  }
}
Check ($rivals.Count -eq 0) "no competing single-entry claim (EN/TH, structural claims only)" `
  ("competing entry claim at: " + ($rivals -join ', ') + " -- either point the line at PROJECT_STATE.md or mark it ENTRY-CLAIM-OK if it is deliberate")

# 8. owner banner present on the secondary owners
foreach($f in @($DEMO,$BL,$SC)){
  $n = Split-Path $f -Leaf
  Check (Has $f 'canonical entry =') "$n has owner banner" "$n missing 'canonical entry =' banner"
}

# 9. HOLDOUT GUARD (2026-07-25). A test window that ends after MAIN spends the holdout,
#    and a holdout is spent the FIRST time it is touched. On 2026-07-25 both EA subagent
#    definitions were found running every screen and every optimize with -ToDate 2026.06.01,
#    i.e. six months inside the 2026H1 holdout, for an unknown length of time. Nothing failed
#    loudly; it was found by hand. This check is the loud failure.
#
#    SCOPE IS DELIBERATELY NARROW: only files that DEFINE how future runs happen. Historical
#    one-shot runners (gsmc_validate.ps1, order104*.ps1, qwen_batch_runner.ps1 ...) keep their
#    old windows on purpose - rewriting them would misrepresent what past runs actually did.
#
#    RE-PIN WHEN MAIN MOVES: MAIN is re-pinned every ~6 months (CLAUDE.md VERDICT GATE). When
#    it does, update $mainEnd here in the same commit, and declare the new holdout first.
#    ESCAPE HATCH: put HOLDOUT-OK on the line when a run is meant to spend the holdout.
#
#    SCOPE WIDENED 2026-07-27 (ORDER-238). The original scope listed only the MT5
#    pair. Three more files define how future runs happen and were outside it:
#      run_backtest.ps1  - shipped a holdout-crossing DEFAULT -ToDate, so invoking
#                          it with no dates spent the holdout silently. Worst of
#                          the set, and the least visible.
#      mt4_run.ps1 / mt4_optimize.ps1 - the MT4 twins of the two files already in
#                          scope. Nothing made them different; they were just
#                          missed.
#    Historical one-shot runners stay OUT of scope by the rule above, but they now
#    carry a HOLDOUT-BURNED banner instead of being silently trusted.
$mainEnd  = '2025.12.31'
$scopeDef = @()
# ORDER-674 round 1: same fix as section 7 -- the holdout guard's scope was enumerated from
# the disk and read from the worktree. A subagent definition with a holdout-crossing -ToDate
# STAGED behind a clean worktree copy sailed through the check that exists because exactly
# such a definition once spent six months of holdout unnoticed.
$scopeDef += @(Get-CommittedPaths -Pattern '.claude/agents/*.md' -RepoRoot $Root)
foreach($n in @('mt5_run.ps1','mt5_optimize.ps1','mt4_run.ps1','mt4_optimize.ps1','run_backtest.ps1')){
  $rel = "scripts/$n"
  if(Test-CommittedPath -RelPath $rel -RepoRoot $Root){ $scopeDef += $rel }
}
$leaks = @()
foreach($fRel in $scopeDef){
  $f = [pscustomobject]@{ Name = (Split-Path $fRel -Leaf) }
  $fText = ReadJudged $fRel
  if ($null -eq $fText) { continue }   # counted by $toolFail, which now fails the run
  $i = 0
  foreach($line in ($fText -split "`n")){
    $i++
    if($line -match 'HOLDOUT-OK'){ continue }
    # only an actual ToDate ASSIGNMENT counts -- prose that merely mentions a date must not trip
    foreach($m in [regex]::Matches($line,'(?i)-?ToDate[=\s:]+["'']?(\d{4}\.\d{2}\.\d{2})')){
      $d = $m.Groups[1].Value
      if($d -gt $mainEnd){
        $leaks += ("{0}:{1} ToDate={2}" -f $f.Name,$i,$d)
      }
    }
  }
}
Check ($leaks.Count -eq 0) ("holdout guard: no reusable definition selects past $mainEnd") `
  ("HOLDOUT LEAK - these select/screen on data past MAIN ($mainEnd), which spends the holdout: " + ($leaks -join '; ') + " -- fix the window, or add HOLDOUT-OK on the line if spending it is intended")

# 10. SKILLS MIRROR (2026-07-27, ORDER-251). The skills library owns every decision
#     bar in this project (THE LADDER, the DEMOTED banner, the corr ladder) and lives
#     outside the repo, so until now nothing could tell whether a bar had drifted.
#     docs/skills_mirror/ is a content mirror plus a sha256 manifest; this compares
#     the live library against it. WARN, not block: the library legitimately changes,
#     it just must not change UNOBSERVED.
$mirrorScript = Join-Path $Root 'scripts\sync_skills_mirror.ps1'
# snapshot: not-a-judged-input -- and this one is worth stating rather than assuming, because it
# is the ONE check here whose subject is deliberately OUTSIDE git. The skills library lives on
# this machine, not in the repo; the question is "does the live library still match the committed
# mirror", so the disk is the subject, not a shortcut to it. Test-Path asks whether the comparison
# tool exists before running it. WARN-only by design: the library legitimately changes, it just
# must not change UNOBSERVED.
if(Test-Path $mirrorScript){
  $mirrorOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $mirrorScript -Check -RepoRoot $Root 2>&1
  $mirrorOk = ($LASTEXITCODE -eq 0)
  Check $mirrorOk "skills mirror matches the live library" `
    ("SKILLS DRIFT - the decision bars changed outside git: " + (($mirrorOut | Select-Object -Skip 1 | Select-Object -First 6) -join ' | ') + " -- if intended, run scripts\sync_skills_mirror.ps1 -Update and commit the mirror alongside the reason")
}

# /scrutinize (ORDER-674 round 1): $toolFail EXISTED AND NOTHING READ IT. A ReadJudged throw
# printed [TOOL] in red, returned $null -- and unless that null happened to trip a downstream
# Check, the run ended "=== CLEAN ===" exit 0. "I could not read my inputs" was a PASS, in the
# guard this whole order migrated precisely so that reads mean what they claim. Exit 2, before
# any verdict line, in EVERY mode: a guard that cannot see cannot say CLEAN, strict or not.
if($script:toolFail -gt 0){
  Write-Host ("=== TOOL FAILURE - {0} input(s) could not be read; the verdicts above are over an incomplete evidence set ===" -f $script:toolFail) -ForegroundColor Red
  exit 2
}
if($script:warn -eq 0){ Write-Host "=== CLEAN - no drift detected ===" -ForegroundColor Green }
else { Write-Host ("=== {0} WARNING(s) - fix the drift above ===" -f $script:warn) -ForegroundColor Yellow }
if($Strict -and $script:warn -gt 0){ exit 1 }
exit 0
