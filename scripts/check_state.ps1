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

$script:warn = 0
function Check($cond,$okMsg,$warnMsg){
  if($cond){ Write-Host "[OK]   $okMsg" -ForegroundColor Green }
  else     { Write-Host "[WARN] $warnMsg" -ForegroundColor Yellow; $script:warn++ }
}
function Has($file,$needle){ (Test-Path $file) -and ((Get-Content $file -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) -match [regex]::Escape($needle)) }

$PS   = Join-Path $Root 'PROJECT_STATE.md'
$DEMO = Join-Path $Root 'DEMO_DEPLOYMENT_PLAN.md'
$BL   = Join-Path $Root 'MASTER_BACKLOG.md'
$SC   = Join-Path $Root 'EA_SCORECARD_AND_REGISTRY.md'
$INV  = Join-Path $Root 'portfolio\DEPLOYMENTS.csv'
$DASH = Join-Path $Root 'scripts\live_dashboard.ps1'

Write-Host "=== EA_LAB state consistency check (inventory-driven, ORDER-093) ===" -ForegroundColor Cyan

# 1. canonical entry + inventory pointer
Check (Test-Path $PS) "PROJECT_STATE.md exists (the entry point)" "PROJECT_STATE.md MISSING - canonical entry gone"
Check (Has $PS 'DEPLOYMENTS.csv') "PROJECT_STATE declares the DEPLOYMENTS.csv inventory pointer" "PROJECT_STATE does not reference portfolio\DEPLOYMENTS.csv (section 0.5 pointer missing)"

# 2. inventory parses + shape
$rows = $null
if (Test-Path $INV) { try { $rows = @(Import-Csv $INV -Encoding UTF8) } catch { $rows = $null } }
Check ($null -ne $rows -and $rows.Count -gt 0) "DEPLOYMENTS.csv parses ($(if($rows){$rows.Count}else{0}) rows)" "portfolio\DEPLOYMENTS.csv missing or unparseable"
if ($null -ne $rows -and $rows.Count -gt 0) {
  $required = @('account','ea_name','magic','symbol','status','judge_date')
  $cols = $rows[0].PSObject.Properties.Name
  $missingCols = @($required | Where-Object { $cols -notcontains $_ })
  Check ($missingCols.Count -eq 0) "inventory has all required columns" ("inventory missing columns: " + ($missingCols -join ', '))

  $withMagic = @($rows | Where-Object { $_.magic -match '^\d+$' })
  $dups = @($withMagic | Group-Object { "$($_.account)|$($_.magic)" } | Where-Object Count -gt 1)
  Check ($dups.Count -eq 0) "no duplicate account|magic in inventory" ("duplicate account|magic: " + (($dups | ForEach-Object Name) -join ', '))

  # 3. accounts present in the deployment narrative doc
  $demoRaw = if (Test-Path $DEMO) { Get-Content $DEMO -Raw -Encoding UTF8 } else { '' }
  $accts = @($rows | Select-Object -ExpandProperty account -Unique)
  $missA = @($accts | Where-Object { $demoRaw -notmatch [regex]::Escape($_) })
  Check ($missA.Count -eq 0) "all $($accts.Count) inventory accounts present in DEMO_DEPLOYMENT_PLAN" ("accounts missing from DEMO plan: " + ($missA -join ', '))

  # 4/5. dashboard cohort map <-> inventory. CR-001 (2026-07-19): the map is GENERATED
  # from DEPLOYMENTS.csv inside live_dashboard.ps1, so coverage/ghost parity is now
  # guaranteed by construction. What can still drift: (4) the generation link itself
  # (someone points the dashboard elsewhere), (5) someone re-introduces a hardcoded
  # "account|magic" literal table that would shadow the inventory.
  $dashRaw = if (Test-Path $DASH) { Get-Content $DASH -Raw -Encoding UTF8 } else { '' }
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
foreach($f in @(Get-ChildItem $Root -Filter *.md -File | Where-Object { $_.Name -ne 'PROJECT_STATE.md' -and $_.Name -notmatch 'RESUME|RUN_REGISTRY' })){
  $n = 0
  foreach($line in (Get-Content $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)){
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
$mainEnd  = '2025.12.31'
$scopeDef = @()
$scopeDef += (Get-ChildItem (Join-Path $Root '.claude\agents') -Filter *.md -File -ErrorAction SilentlyContinue)
foreach($n in @('mt5_run.ps1','mt5_optimize.ps1')){
  $p = Join-Path $Root "scripts\$n"
  if(Test-Path $p){ $scopeDef += (Get-Item $p) }
}
$leaks = @()
foreach($f in $scopeDef){
  $i = 0
  foreach($line in (Get-Content $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue)){
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

if($script:warn -eq 0){ Write-Host "=== CLEAN - no drift detected ===" -ForegroundColor Green }
else { Write-Host ("=== {0} WARNING(s) - fix the drift above ===" -f $script:warn) -ForegroundColor Yellow }
if($Strict -and $script:warn -gt 0){ exit 1 }
exit 0
