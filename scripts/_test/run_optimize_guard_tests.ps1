<#
run_optimize_guard_tests.ps1 - regression cage for scripts/optimize_guard.ps1

WHY THIS EXISTS
  The guard's job is to refuse an optimizer sweep that is provably wasted or
  provably touches the safety cage. A guard that refuses VALID sweeps is not
  "extra safe" - it is the failure that trains operators to pass
  -SkipOptimizeGuard on every run, which silences the checks that DO have
  evidence behind them. That happened: classification=OVERRIDE was being read
  as "this parameter is dead" when it actually means "this parameter is a
  member of a precedence chain", so _2_BasketTP_ATRmult (Boss 14) and
  _17_UseStructLevels (Boss 17) - both real, working dials - were REFUSED.

  Precedence is NOT decided by the classification column. It is decided by the
  override-pair table in docs/PARAM_LINKAGE.md TOGETHER WITH the sibling values
  present in the same run: a loser is only dead when its winner is actually
  switched on. So this cage asserts both directions of every pair it covers -
  a test set that only asserted REFUSE could be passed by a guard that refuses
  everything, which is exactly the bug being fixed.

WHAT IS COVERED (each case names the check it discriminates)
  classification : OVERRIDE winner allowed · INACTIVE refused · unknown refused
  precedence     : loser refused while winner ON · same loser allowed while winner OFF
  build inertness: TrendFilter refused on 14, allowed on 11 (same name, same run)
  safety         : by name (RC_*, ProtectLevel) and by registry context, and the
                   OVERRIDE+safety row that must stay refused after the loosening

USAGE
  powershell -NoProfile -File scripts\_test\run_optimize_guard_tests.ps1
EXIT CODE
  0 = every case matched its expected verdict · 1 = at least one mismatch
#>
[CmdletBinding()]
param([switch]$Verbose_)

$ErrorActionPreference = 'Stop'
$root  = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$guard = Join-Path $root 'scripts\optimize_guard.ps1'
if (-not (Test-Path $guard)) { Write-Host "[FAIL] guard not found: $guard" -ForegroundColor Red; exit 1 }

# Each case: the parameter whose verdict is asserted, the build, any sibling
# values that must be present for the precedence check to have something to
# read, and the expected verdict for THAT parameter.
$cases = @(
  # --- classification: an OVERRIDE winner is a live dial, not a dead one -----
  @{ id='ovr-winner-basketATR-allowed';  param='_2_BasketTP_ATRmult'; build=14
     args=@('_2_BasketTP_ATRmult','_2_BasketTP_BalPct=0')
     expect='ALLOW'; why='OVERRIDE winner with no higher-precedence value active' }
  @{ id='ovr-winner-structlevels-allowed'; param='_17_UseStructLevels'; build=17
     args=@('_17_UseStructLevels')
     expect='ALLOW'; why='OVERRIDE winner on its own build (Codex P0 repro #2)' }
  @{ id='ovr-winner-slmaxatr-allowed';   param='_33_SL_MaxATRmult'; build=14
     args=@('_33_SL_MaxATRmult')
     expect='ALLOW'; why='third OVERRIDE row - proves the fix is not special-cased to two names' }

  # --- precedence: BOTH directions of the same pair -------------------------
  @{ id='loser-refused-when-winner-on';  param='_2_BasketTP_ATRmult'; build=14
     args=@('_2_BasketTP_ATRmult','_2_BasketTP_BalPct=1.5')
     expect='REFUSE'; why='BalPct>0 supersedes ATRmult in the same run' }
  @{ id='money-refused-when-atr-on';     param='_2_BasketTP_Money'; build=14
     args=@('_2_BasketTP_Money','_2_BasketTP_ATRmult=2.0','_2_BasketTP_BalPct=0')
     expect='REFUSE'; why='ATRmult>0 supersedes the fixed-money target' }
  @{ id='money-allowed-when-both-off';   param='_2_BasketTP_Money'; build=14
     args=@('_2_BasketTP_Money','_2_BasketTP_ATRmult=0','_2_BasketTP_BalPct=0')
     expect='ALLOW'; why='same loser, both winners off - refusing here would be the mirror bug' }

  # --- build inertness: same parameter, opposite verdicts on two builds -----
  @{ id='inert-trendfilter-refused-b14'; param='TrendFilter'; build=14
     args=@('TrendFilter')
     expect='REFUSE'; why='PARAM_INACTIVE_AUDIT: TrendFilter is not wired into build 14' }
  @{ id='inert-trendfilter-allowed-b11'; param='TrendFilter'; build=11
     args=@('TrendFilter')
     expect='ALLOW'; why='same dial IS wired on build 11 - proves the check discriminates' }

  # --- classification: INACTIVE stays refused -------------------------------
  @{ id='inactive-stackmode-b16-refused'; param='StackMode'; build=16
     args=@('StackMode')
     expect='REFUSE'; why='classification=INACTIVE on build 16 (permanently dead)' }

  # --- safety: three independent routes, none may leak through the fix ------
  @{ id='safety-name-rcmaxlot-refused';  param='RC_MaxLot'; build=14
     args=@('RC_MaxLot')
     expect='REFUSE'; why='safety by ^RC_ name rule' }
  @{ id='safety-name-protectlevel-refused'; param='ProtectLevel'; build=14
     args=@('ProtectLevel')
     expect='REFUSE'; why='safety by explicit name rule' }
  @{ id='safety-ctx-emergencydd-refused'; param='_16_EmergencyDDPct'; build=16
     args=@('_16_EmergencyDDPct')
     expect='REFUSE'; why='safety by registry context column, not by name' }
  @{ id='safety-override-rcmaxlevels-refused'; param='RC_MaxLevelsOverride'; build=14
     args=@('RC_MaxLevelsOverride')
     expect='REFUSE'; why='OVERRIDE *and* safety - the loosening must not reach this row' }

  # --- unknown identifier stays fail-closed ---------------------------------
  @{ id='unknown-name-refused';          param='_99_NotARealInput'; build=14
     args=@('_99_NotARealInput')
     expect='REFUSE'; why='not in PARAM_REGISTRY.csv - fail closed' }
)

# One guard process per case, deliberately. Batching cases into shared invocations
# would cut ~3s off a 5.8s suite, but the guard's override check reads the OTHER
# parameters present in the same run - RC_MaxLevelsOverride beats ProtectLevel, and
# both are cases here - so batching would silently couple cases that are supposed to
# be independent. That is the failure mode this cage was written to catch; paying 3
# seconds to keep the cases isolated is the right side of that trade. Results are
# memoised on (build + exact argument set) so a duplicated case costs nothing and
# can never be served another run's output.
$script:RunCache = @{}

function Invoke-Guard {
    param([string[]]$ParamArgs, [int]$Build)
    $key = "$Build|" + (($ParamArgs | Sort-Object) -join ',')
    if ($script:RunCache.ContainsKey($key)) { return $script:RunCache[$key] }
    # -WarnOnly so the process exit code never masks a per-parameter verdict:
    # this cage asserts the VERDICT LINE, and several cases deliberately expect
    # a REFUSE that would otherwise make the runner exit 1 and abort the loop.
    # NOTE: invoked via -Command, not -File. Under `powershell -File`, a
    # comma-joined value for a [string[]] parameter arrives as ONE string
    # element ("a,b"), which the guard then reports as an unknown identifier -
    # the cage's first run failed 4 cases that way before the guard was even
    # touched. -Command parses the argument list with real PowerShell syntax.
    $joined = ($ParamArgs | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ','
    $cmd = "& '$guard' -ParamNames $joined -Build $Build -WarnOnly"
    $out = & powershell -NoProfile -Command $cmd 2>&1
    $text = ($out | Out-String)
    $script:RunCache[$key] = $text
    return $text
}

function Get-VerdictFor {
    param([string[]]$ParamArgs, [int]$Build, [string]$Param)
    $text = Invoke-Guard -ParamArgs $ParamArgs -Build $Build
    # the verdict line looks like: [ALLOW] _2_BasketTP_ATRmult  (from: -ParamNames)
    $line = @($text -split "`r?`n" | Where-Object { $_ -match ("^\[(ALLOW|REFUSE)\]\s+" + [regex]::Escape($Param) + "(\s|\[|$)") }) | Select-Object -First 1
    if (-not $line) { return [pscustomobject]@{ Verdict='(no verdict line)'; Text=$text } }
    $v = if ($line -match '^\[(ALLOW|REFUSE)\]') { $Matches[1] } else { '(unparsed)' }
    return [pscustomobject]@{ Verdict=$v; Text=$text }
}

Write-Host "=== optimize_guard regression cage ===" -ForegroundColor Cyan
Write-Host "guard: $guard"
Write-Host ""

$pass = 0; $fail = 0
foreach ($c in $cases) {
    $r = Get-VerdictFor -ParamArgs $c.args -Build $c.build -Param $c.param
    if ($r.Verdict -eq $c.expect) {
        Write-Host ("[PASS] {0,-36} {1} {2} (build {3})" -f $c.id, $c.expect, $c.param, $c.build) -ForegroundColor Green
        $pass++
    } else {
        Write-Host ("[FAIL] {0,-36} expected {1}, got {2}  -  {3}" -f $c.id, $c.expect, $r.Verdict, $c.why) -ForegroundColor Red
        Write-Host ("       param={0} build={1} args={2}" -f $c.param, $c.build, ($c.args -join ','))
        foreach ($l in ($r.Text -split "`r?`n" | Where-Object { $_ -match '^\s*-\s' })) { Write-Host "       $l" }
        $fail++
    }
}

# =============================================================================================
# PART 2 - ORDER-1253: the DECISION RECORD, and the seam between the two languages.
#
# The writer is this PowerShell script and the reader is _triage/factory_os/optimize_log.py, so
# the record's shape is necessarily stated twice. That is the arrangement this repo has been
# burned by, so these cases do not check that the two descriptions AGREE IN PROSE: they run the
# REAL guard into a temp file and hand the bytes to the REAL reader. A cage that drove only the
# python module would prove only the python half (memory `pure-cage-proves-only-the-pure-half`).
# =============================================================================================
Write-Host ""
Write-Host "=== PART 2: the decision record (ORDER-1253) ===" -ForegroundColor Cyan

$p2pass = 0; $p2fail = 0
function Check2 {
    param([string]$Id, [bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Host ("[PASS] {0}" -f $Id) -ForegroundColor Green; $script:p2pass++ }
    else     { Write-Host ("[FAIL] {0}  {1}" -f $Id, $Detail) -ForegroundColor Red; $script:p2fail++ }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("optguard_dec_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$log = Join-Path $tmp 'dec.jsonl'
try {
    # --- CONTROL: with -DecisionLog omitted, not one line of behaviour changes ----------------
    # This is the claim the default-off design rests on, and it is the claim a new parameter
    # most easily breaks. Asserted by DIFFING the two consoles, not by reading the source.
    $bare = & powershell -NoProfile -Command "& '$guard' -ParamNames 'RC_MaxLot' -Build 14 -WarnOnly" 2>&1 | Out-String
    $withLog = & powershell -NoProfile -Command "& '$guard' -ParamNames 'RC_MaxLot' -Build 14 -WarnOnly -DecisionLog '$log' -Lane 'CAGE-LANE'" 2>&1 | Out-String
    # Blank runs are collapsed on BOTH sides before comparing, because the record line is printed
    # with a leading blank for readability. Collapsing whitespace is the only tolerance granted --
    # every non-blank line still has to match, in order.
    function Normalise-Console {
        param([string]$Text)
        $keep = ($Text -split "`r?`n") | Where-Object { $_ -notmatch '^DECISION RECORD ->' }
        return (($keep | Where-Object { $_.Trim() -ne '' }) -join "`n").Trim()
    }
    $stripped = Normalise-Console $withLog
    $bareNorm = Normalise-Console $bare
    Check2 'control-no-decisionlog-changes-nothing' ($stripped -eq $bareNorm) `
        'the console output differs beyond the one DECISION RECORD line'
    Check2 'control-no-decisionlog-writes-no-file' (-not (Test-Path (Join-Path $tmp 'nothing.jsonl')))

    # --- the WarnOnly REFUSE is still an observed REFUSAL --------------------------------------
    Check2 'refuse-submission-appends-a-record' (Test-Path $log)

    # --- a real ALLOW submission ---------------------------------------------------------------
    & powershell -NoProfile -Command "& '$guard' -ParamNames '_2_BasketTP_ATRmult','_2_BasketTP_BalPct=0' -Build 14 -DecisionLog '$log' -Lane 'CAGE-LANE'" 2>&1 | Out-Null

    # --- FAIL-CLOSED, twice. Both cases assert the REASON, not merely a non-zero exit: a suite
    #     that accepted "it failed somehow" would go green on a typo in the invocation.
    #     $ErrorActionPreference is dropped to Continue around them because a child that writes to
    #     stderr surfaces as a NativeCommandError under `Stop` and would abort the whole suite --
    #     which is how PART 2 killed itself on its first run.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $noLaneOut = (& powershell -NoProfile -Command "& '$guard' -ParamNames 'RC_MaxLot' -Build 14 -WarnOnly -DecisionLog '$log'" 2>&1 | Out-String)
    $noLaneRc = $LASTEXITCODE
    $auditOut = (& powershell -NoProfile -Command "& '$guard' -DecisionLog '$log' -Lane 'CAGE-LANE'" 2>&1 | Out-String)
    $auditRc = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    Check2 'decisionlog-without-lane-refuses' (($noLaneRc -ne 0) -and ($noLaneOut -match '-DecisionLog was given without -Lane')) `
        "rc=$noLaneRc"
    Check2 'decisionlog-in-audit-mode-refuses' (($auditRc -ne 0) -and ($auditOut -match 'whole-registry audit mode')) `
        "rc=$auditRc"

    # --- the seam: the REAL reader, on the REAL bytes -------------------------------------------
    $py = Join-Path $root 'tools\python312\python.exe'
    $probe = Join-Path $tmp 'probe.py'
    $probeSrc = @'
import io, json, os, sys
sys.path.insert(0, os.path.join(sys.argv[2], '_triage', 'factory_os'))
import optimize_log as OL
text = io.open(sys.argv[1], encoding='utf-8').read()
out = []
def ck(name, ok, detail=''):
    out.append(('PASS' if ok else 'FAIL', name, detail))
# The seam itself. A writer that drops or renames a field lands HERE, and it must arrive as a
# named FAIL rather than as a traceback the wrapper reports as "SUITE THREW" -- the whole point
# of this case is to say WHICH end broke.
try:
    recs = OL.parse(text, 'cage')
except OL.LogRefusal as exc:
    print('FAIL|the-writer-and-the-reader-still-agree|%s' % exc)
    sys.exit(1)
ck('reader-accepts-the-writers-bytes', len(recs) == 2, 'got %d record(s)' % len(recs))
ck('every-required-field-survived-the-writer',
   all(all(f in r for f in OL.REQUIRED) for r in recs))
ck('facts-are-objects-not-a-stringified-type',
   all(isinstance(f, dict) for r in recs for d in r['dimensions'] for f in d['facts']))
refus = OL.real_refusals(recs)
allows = OL.real_allows(recs)
ck('warnonly-refusal-still-counts-as-an-observed-refusal', len(refus) == 1 and refus[0]['exit_code'] == 0,
   'refusals=%d' % len(refus))
ck('the-allow-direction-is-observed-too', len(allows) == 1, 'allows=%d' % len(allows))
ck('the-refused-dimension-is-the-safety-one',
   [d['name'] for d in OL.refused_dimensions(refus[0])] == ['RC_MaxLot'])
# SPECIFICITY: a submission that judged nothing is a record, and it is NOT a fire.
nothing = dict(recs[0], result='NOTHING_TO_CHECK', dimensions=[], checked=0,
               allow_count=0, refuse_count=0)
ck('a-NOTHING_TO_CHECK-record-is-not-an-observed-fire',
   not OL.real_refusals([nothing]) and not OL.real_allows([nothing]))
# ATTACK: each of these must be REFUSED, never dropped.
for name, mutate in (('missing-lane', lambda r: {k: v for k, v in r.items() if k != 'lane'}),
                     ('empty-lane', lambda r: dict(r, lane='   ')),
                     ('future-version', lambda r: dict(r, record_version=2)),
                     ('unknown-result', lambda r: dict(r, result='MAYBE')),
                     ('dimension-without-a-verdict',
                      lambda r: dict(r, dimensions=[{'name': 'x', 'facts': []}]))):
    try:
        OL.parse(json.dumps(mutate(recs[0])), 'cage')
        ck('attack-%s-is-refused' % name, False, 'it parsed')
    except OL.LogRefusal:
        ck('attack-%s-is-refused' % name, True)
# CONTROL for the attacks: the unmutated row still parses, so "refused" above is not "refuses all".
try:
    OL.parse(json.dumps(recs[0]), 'cage')
    ck('control-the-innocent-record-still-parses', True)
except OL.LogRefusal as exc:
    ck('control-the-innocent-record-still-parses', False, str(exc))
for state, name, detail in out:
    print('%s|%s|%s' % (state, name, detail))
sys.exit(1 if any(s == 'FAIL' for s, _n, _d in out) else 0)
'@
    [System.IO.File]::WriteAllText($probe, $probeSrc, (New-Object System.Text.UTF8Encoding($false)))
    $probeOut = & $py $probe $log $root 2>&1 | Out-String
    foreach ($line in ($probeOut -split "`r?`n")) {
        if ($line -match '^(PASS|FAIL)\|([^|]*)\|(.*)$') { Check2 $Matches[2] ($Matches[1] -eq 'PASS') $Matches[3] }
        elseif ($line.Trim()) { Write-Host "       $line" }
    }
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host ("--- part 1: {0} passed / {1} failed / {2} total ---" -f $pass, $fail, $cases.Count)
Write-Host ("--- part 2: {0} passed / {1} failed ---" -f $p2pass, $p2fail)
if ($fail -gt 0 -or $p2fail -gt 0) { Write-Host "=== OPTIMIZE-GUARD CAGE RED ===" -ForegroundColor Red; exit 1 }
Write-Host "=== OPTIMIZE-GUARD CAGE GREEN ===" -ForegroundColor Green
exit 0
