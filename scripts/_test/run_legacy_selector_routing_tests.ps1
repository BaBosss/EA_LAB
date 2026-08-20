<#
run_legacy_selector_routing_tests.ps1 - M1 LANE A / finding A-F5.

WHAT THIS GUARDS, AND WHAT IT DOES NOT
  The EXECUTABLE quarantine of the legacy optimization-selection path (select_robust_pass.py,
  set_from_robust.py, run_pipeline.py, log_run.py optimize, walkforward.ps1, OPTIMIZE_GUIDE.md --
  all refusing by default with exit 3 / "REFUSED (LEGACY / NON_FACTORY)") already exists and is
  cased by scripts\_test\run_legacy_quarantine_tests.ps1. This suite does NOT re-test it.

  What was still open is the INSTRUCTION layer: the surfaces that TELL an operator or a dispatched
  subagent what to run. Those still contained live invocations of the quarantined tools, so an
  agent following its own definition would either hit the refusal or -- worse -- reach for
  --allow-legacy-selection to get past it. A quarantine that the dispatch instructions route into
  is a quarantine only for people who already know about it.

  This suite fails CLOSED on reintroduction into the DISPATCHABLE surfaces, and prints its scope
  (which files, how many hits, and which token exempted every surviving mention) rather than only
  a verdict.

WHY THE SURFACE LIST IS CLOSED AND ENUMERATED
  A blanket rule ("any .md that mentions it") would be satisfied by, or would fire on, the repo's
  historical record -- PROJECT_HISTORY.md, ARCHIVE_TASKBOARD_*, docs\_legacy_manual\**, the
  existing ROBUSTNESS_VERDICT.md files, the scorecard. Those are PROVENANCE: rewriting them would
  destroy the record of what was actually done, and a guard that pressures someone to rewrite them
  is worse than no guard. So the scope is an explicit list of surfaces that are DISPATCHED FROM,
  each with a stated reason, and every allowance is a named entry rather than a wildcard.

HOW "ROUTING" IS TOLD FROM "WARNING"
  Two independent checks, because either alone is gameable:
   1. INVOCATION SHAPES -- the tool name in a form that can be pasted and run (a `python ...` line,
      the script name followed by an argument, an `import` of the retired scorer, a read of its
      score field, or the legacy escape flag). These are BANNED OUTRIGHT in a dispatchable surface;
      there is no prose that makes a runnable command line safe.
   2. BARE MENTIONS -- the tool named in prose. Allowed only if a PROHIBITION token from a closed
      list appears within 2 lines. The suite PRINTS the exempting token for each one, so a reader
      can check the reasoning instead of trusting a tick.
  And for the one executable-adjacent surface (scripts\lib\optimize_next_step.ps1) the check is
  ALSO behavioural: the function's actual RETURNED STRINGS are inspected, not its header comment.
  A guard that scans a docstring proves nothing about what the operator is shown.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI). Note that the .md
files under scan are UTF-8 and may contain Thai; they are read with -Encoding UTF8 and only ASCII
is ever printed from this suite (Thai out of a suite inside the pre-commit hook is a
UnicodeEncodeError that reads as "SUITE THREW").
USAGE  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\_test\run_legacy_selector_routing_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$script:pass = 0
$script:fail = 0
function Assert-True([string]$name, $cond, [string]$detail = '') {
  if ($cond) { $script:pass++; Write-Output "   [PASS] $name" }
  else { $script:fail++; Write-Output "   [FAIL] $name$(if ($detail) { ' -- ' + $detail })" }
}

# ---------------------------------------------------------------------------------------------
# THE CLOSED SCOPE. Each entry is a surface something is DISPATCHED FROM, with the reason it
# qualifies. Adding a surface here is a deliberate act; there is no pattern that sweeps in more.
# ---------------------------------------------------------------------------------------------
$dispatchable = @(
  @{ path = '.claude\agents\ea-validator.md'
     why  = 'subagent definition -- the Agent tool loads this as the worker prompt' }
  @{ path = '.claude\agents\ea-screener.md'
     why  = 'subagent definition -- the Agent tool loads this as the worker prompt' }
  @{ path = 'AUTOMATION_GUIDE.md'
     why  = 'the repo-root operator runbook for optimize/select' }
  @{ path = 'docs\MT5_AUTOMATION.md'
     why  = 'the MT5 automation runbook an operator follows by hand' }
  @{ path = 'scripts\lib\optimize_next_step.ps1'
     why  = 'executable-adjacent: its return value IS the instruction the launcher prints' }
  @{ path = 'docs\skills_mirror\skills\README.md'
     why  = 'live skills mirror -- read as current guidance, not as history' }
  @{ path = 'docs\skills_mirror\skills\backtest-report-analyzer\SKILL.md'
     why  = 'live skills mirror -- the report-analysis skill an operator invokes' }
)

# ---------------------------------------------------------------------------------------------
# BANNED INVOCATION SHAPES. A runnable form of a quarantined tool, or the escape flag.
# ---------------------------------------------------------------------------------------------
$invocationShapes = @(
  @{ name = 'python-invocation of a quarantined selector/pipeline'
     re   = '(?i)python[^\r\n]{0,120}?(select_robust_pass|set_from_robust|run_pipeline|log_run|score_backtest)\.py' }
  @{ name = 'quarantined script name followed by an argument'
     re   = '(?i)(select_robust_pass|set_from_robust|run_pipeline|score_backtest)\.py\s+["'']?[-\w$\\/.]' }
  # A NEGATED imperative ("do not use", "must not use", "never use") is the prohibition text this
  # quarantine is built out of, not a runnable directive -- it falls through to the bare-mention
  # check below (and needs a prohibition token nearby there, same as any other mention). Only a
  # POSITIVE imperative counts as an invocation shape.
  @{ name = 'bare-name imperative for the legacy selector'
     re   = '(?i)(?<!not )(?<!never )(run|use|call|execute)\s+`?select_robust_pass`?' }
  @{ name = 'import of the retired BacktestScore v1 scorer'
     re   = '(?i)from\s+score_backtest\s+import' }
  @{ name = 'read of the retired BacktestScore score field'
     re   = '\[\s*["'']BacktestScore["'']\s*\]' }
  @{ name = 'legacy walkforward / OPTIMIZE_GUIDE routing'
     re   = '(?i)(walkforward\.ps1|OPTIMIZE_GUIDE\.md)' }
)

# The legacy escape flag is handled separately: naming it in order to FORBID it is legitimate, so
# it is checked under the prohibition-window rule rather than banned outright.
$flagRe = '(?i)(--allow-legacy-selection|-AllowLegacySelection)'

# Bare prose mention of a quarantined tool.
$mentionRe = '(?i)(select_robust_pass|set_from_robust|run_pipeline|score_backtest|BacktestScore)'

# CLOSED prohibition-token list. Deliberately all negative/terminal words -- none of them can be
# satisfied by a neutral sentence that happens to sit nearby.
#
# 'REFUSED' / 'refuses' are deliberately NOT in this list even though the tool's own quarantined
# exit path is literally named that. Both words also read naturally as the setup half of a
# bypass instruction ("if it refuses, pass --allow-legacy-selection and carry on") -- exactly the
# routing text this guard exists to catch -- so on their own they are not proof of a prohibition.
# Every real occurrence in this repo already sits next to 'do not' / 'must not' / 'never' /
# 'archived' / 'NON-AUTHORITATIVE' anyway (see the fire-test control below, which pins this).
$prohibitionTokens = @('do not', 'must not', 'never', 'REMOVED', 'QUARANTINE', 'quarantined',
                       'retired', 'superseded', 'archived', 'BLOCKED',
                       'NON-AUTHORITATIVE', 'NON_FACTORY')

function Test-Window {
  <# -> the prohibition token that exempts line $i (window +-2 lines), or '' if none. #>
  param([string[]]$Lines, [int]$Index)
  $lo = [Math]::Max(0, $Index - 2)
  $hi = [Math]::Min($Lines.Count - 1, $Index + 2)
  $window = ($Lines[$lo..$hi] -join ' ')
  foreach ($t in $prohibitionTokens) {
    if ($window -match [regex]::Escape($t)) { return $t }
  }
  return ''
}

function Measure-Surface {
  <# -> a report object for one file: invocation hits, unexempted mentions, exempted mentions. #>
  param([string]$FullPath)
  $lines = @(Get-Content -LiteralPath $FullPath -Encoding UTF8)
  $inv = @(); $bad = @(); $ok = @()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    foreach ($shape in $invocationShapes) {
      if ($line -match $shape.re) { $inv += ("line " + ($i + 1) + ": " + $shape.name) }
    }
    $isMention = ($line -match $mentionRe) -or ($line -match $flagRe)
    if (-not $isMention) { continue }
    $tok = Test-Window -Lines $lines -Index $i
    if ($tok -eq '') { $bad += ("line " + ($i + 1)) } else { $ok += ("line " + ($i + 1) + " [" + $tok + "]") }
  }
  return [pscustomobject]@{ Invocations = $inv; Unexempted = $bad; Exempted = $ok; LineCount = $lines.Count }
}

Write-Output '=== A-F5 instruction-layer legacy-selector quarantine ==='
Write-Output ''
Write-Output ("SCOPE: " + @($dispatchable).Count + " dispatchable surface(s). Not swept: the historical record")
Write-Output '       (PROJECT_HISTORY.md, ARCHIVE_TASKBOARD_*, docs\_legacy_manual\**, existing'
Write-Output '       ROBUSTNESS_VERDICT.md, EA_SCORECARD_AND_REGISTRY.md, EDGE_CATALOG.md,'
Write-Output '       PROJECT_STATE.md, AGENT_TASKBOARD.md) -- provenance, deliberately not rewritten.'
Write-Output ''

$totalInv = 0; $totalBad = 0; $totalOk = 0; $scanned = 0
foreach ($entry in $dispatchable) {
  $full = Join-Path $RepoRoot $entry.path
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
    # A missing declared surface is a REFUSAL, not a pass. A closed list whose entries can vanish
    # silently is a list that gets smaller every time someone renames a file.
    Assert-True ("declared dispatchable surface exists: " + $entry.path) $false 'file not found'
    continue
  }
  $scanned++
  $r = Measure-Surface -FullPath $full
  $totalInv += @($r.Invocations).Count
  $totalBad += @($r.Unexempted).Count
  $totalOk  += @($r.Exempted).Count
  Write-Output ("  SCANNED  {0}  ({1} lines) -- {2}" -f $entry.path, $r.LineCount, $entry.why)
  Write-Output ("           invocation hits: {0} | unexempted mentions: {1} | exempted mentions: {2}" -f `
                @($r.Invocations).Count, @($r.Unexempted).Count, @($r.Exempted).Count)
  foreach ($h in $r.Invocations) { Write-Output ("           BANNED INVOCATION -> " + $h) }
  foreach ($h in $r.Unexempted)  { Write-Output ("           UNEXEMPTED MENTION -> " + $h) }
  foreach ($h in $r.Exempted)    { Write-Output ("           allowed: " + $h) }
}

Write-Output ''
Assert-True ("all " + @($dispatchable).Count + " declared surfaces were found and scanned") `
  ($scanned -eq @($dispatchable).Count) ("scanned " + $scanned)
Assert-True 'no runnable invocation of a quarantined tool in any dispatchable surface' `
  ($totalInv -eq 0) ("invocation hits: " + $totalInv)
Assert-True 'every surviving mention carries a prohibition token within 2 lines' `
  ($totalBad -eq 0) ("unexempted mentions: " + $totalBad)
# NOT INERT BY EMPTINESS. If the exempted count were 0 the scan would be passing because it found
# nothing at all -- which is what a broken regex looks like from the outside.
Assert-True 'the scan actually matched something (exempted mentions > 0, so the regexes bite)' `
  ($totalOk -gt 0) ("exempted mentions: " + $totalOk)

# ---------------------------------------------------------------------------------------------
# THE GUARD MUST FIRE. A planted surface carrying each banned shape, scanned by the same code.
# ---------------------------------------------------------------------------------------------
Write-Output ''
Write-Output '=== fire test: the same scanner run against a planted reintroduction ==='
$tmp = Join-Path $env:TEMP ('af5_fire_' + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
  $plantedBad = Join-Path $tmp 'planted_bad.md'
  Set-Content -LiteralPath $plantedBad -Encoding UTF8 -Value @(
    '# A reintroduced routing surface',
    '- Select: `python scripts\select_robust_pass.py "OPT_label.xml" --strategy trend`',
    '- Scorer: `from score_backtest import score` -> `score(d, name)["BacktestScore"]`',
    '- If it refuses, pass --allow-legacy-selection and carry on.',
    '- See OPTIMIZE_GUIDE.md for the ranking formula.'
  )
  $fire = Measure-Surface -FullPath $plantedBad
  Write-Output ("  planted surface: invocation hits={0} unexempted mentions={1}" -f `
                @($fire.Invocations).Count, @($fire.Unexempted).Count)
  foreach ($h in $fire.Invocations) { Write-Output ("           fired -> " + $h) }
  Assert-True 'the scanner fires on a planted python-invocation + import + score-field + guide route' `
    (@($fire.Invocations).Count -ge 4) ("hits: " + @($fire.Invocations).Count)
  Assert-True 'the planted --allow-legacy-selection line is reported as an unexempted mention' `
    (@($fire.Unexempted).Count -ge 1) ("unexempted: " + @($fire.Unexempted).Count)

  # ...and it must NOT fire on a healthy control that names the tool only to forbid it.
  $plantedGood = Join-Path $tmp 'planted_good.md'
  Set-Content -LiteralPath $plantedGood -Encoding UTF8 -Value @(
    '# A correctly quarantined surface',
    'The archived BacktestScore v1 selector is quarantined and must not be run.',
    'Do not pass --allow-legacy-selection to get past the refusal.',
    'Selection is contract-driven; with no contract bound the launcher prints SELECTION BLOCKED.'
  )
  $clean = Measure-Surface -FullPath $plantedGood
  Write-Output ("  healthy control: invocation hits={0} unexempted mentions={1} exempted={2}" -f `
                @($clean.Invocations).Count, @($clean.Unexempted).Count, @($clean.Exempted).Count)
  Assert-True 'the scanner does NOT fire on a prohibition-only surface (no invocation hits)' `
    (@($clean.Invocations).Count -eq 0) ("hits: " + @($clean.Invocations).Count)
  Assert-True 'the healthy control has no unexempted mentions' `
    (@($clean.Unexempted).Count -eq 0) ("unexempted: " + @($clean.Unexempted).Count)
  Assert-True 'the healthy control still matched (so the pass is not emptiness)' `
    (@($clean.Exempted).Count -gt 0) ''

  # AND the exemption must not be satisfiable by a universal/blanket file. Prove the prohibition
  # window is LOCAL: a forbidding sentence 20 lines away must not exempt a mention.
  $plantedFar = Join-Path $tmp 'planted_far.md'
  $far = @('Nothing in this repo may use the archived selector. It must not be run.')
  1..20 | ForEach-Object { $far += ('filler line ' + $_) }
  $far += 'Then rank the passes with the archived scoring path.'
  $far += 'Use select_robust_pass on the collected XML.'
  Set-Content -LiteralPath $plantedFar -Encoding UTF8 -Value $far
  $farR = Measure-Surface -FullPath $plantedFar
  Assert-True 'a prohibition 20 lines away does NOT exempt a mention (window is local, not global)' `
    (@($farR.Invocations).Count -ge 1) `
    ("invocation hits: " + @($farR.Invocations).Count + " unexempted: " + @($farR.Unexempted).Count)
}
finally { Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue }

# ---------------------------------------------------------------------------------------------
# BEHAVIOURAL: the actual strings the operator is shown, not the file's header comment.
# ---------------------------------------------------------------------------------------------
Write-Output ''
Write-Output '=== behavioural: the launcher next-step message routes to the contract, not the tool ==='
. (Join-Path $RepoRoot 'scripts\lib\optimize_next_step.ps1')
$bound   = Get-OptimizeNextStepMessage -DestXml 'C:\fixture\OUT.xml' -HypothesisRevision 'B99-TESTHYP'
$unbound = Get-OptimizeNextStepMessage -DestXml 'C:\fixture\OUT.xml' -HypothesisRevision ''
foreach ($pair in @(@{ n = 'contract bound'; s = $bound }, @{ n = 'no contract bound'; s = $unbound })) {
  $s = $pair.s
  Assert-True ("emitted message (" + $pair.n + ") contains no runnable invocation") `
    (-not (@($invocationShapes | Where-Object { $s -match $_.re }).Count -gt 0)) $s
  Assert-True ("emitted message (" + $pair.n + ") names the legacy tool only under a prohibition") `
    (($s -notmatch $mentionRe) -or ($s -match '(?i)(do not use|must not be used)')) $s
}
Assert-True 'the unbound message says SELECTION BLOCKED rather than offering a fallback' `
  ($unbound -match 'SELECTION BLOCKED') $unbound
Assert-True 'no emitted message invents a replacement ranking rule' `
  (($bound + ' ' + $unbound) -notmatch '(?i)(profit factor|plateau|ranking formula|highest score)') ''

Write-Output ''
if ($script:fail -gt 0) {
  Write-Output ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail)
  exit 1
}
Write-Output ("PASS  {0}/{0}" -f $script:pass)
exit 0
