<#
optimize_guard.ps1 - ORDER-192(b) optimizer active-parameter guard

WHY THIS EXISTS
  An MT5 optimization pass burns wall-clock hours walking a parameter's range and
  scoring every combination. Two failure modes waste that time silently and both
  look identical to a real result in the optimizer's report grid:

    1. Sweeping a dimension that provably cannot affect the output on this build/
       config (dead code path, wrong build, or a sibling input that already
       overrides it). The optimizer still returns a full surface of PF/DD numbers
       for every value tried - it just never actually changed anything. That
       "plateau" LOOKS like a robust, insensitive parameter. It is pure noise:
       the report is real, the inference from it is not.
    2. Sweeping a SAFETY parameter (RC_*, ProtectLevel, _9_MaxLevels, or any input
       whose registry `context` is tagged safety) "for profit". These are the
       caps that stop ruin, not levers that produce edge - the whole VERDICT GATE
       structural-death check in CLAUDE.md exists because "the optimizer found
       a better RC_MaxLot" is exactly the kind of finding that should never reach
       a verdict. Optimizing the cage away is optimizing away the thing that
       makes uncapped-ruin unreachable in the first place.

  This script is a pre-flight check for an optimization .ini (or an explicit
  parameter list): it looks up each candidate dimension against the already-built
  evidence trail (PARAM_REGISTRY.csv classification, PARAM_LINKAGE.md override
  pairs, PARAM_INACTIVE_AUDIT.md build-dead-zone findings) and refuses to bless
  a sweep that is provably wasted or provably touches the cage. It does not
  re-derive any of that evidence - it consumes the three files as source of
  truth and fails closed (REFUSE) when it cannot resolve an identifier at all.

SOURCE OF TRUTH (read, never re-derived here)
  docs/PARAM_REGISTRY.csv          - name/context/active_when/classification per input
  docs/PARAM_LINKAGE.md            - "## Override pairs" section (winner beats loser)
  _triage/PARAM_INACTIVE_AUDIT.md  - "## 2. ... inert / no-effect / dead-at-default" table

FOUR CHECKS (verdict is REFUSE if ANY of these fire for a parameter)
  1. classification (PARAM_REGISTRY.csv) says the input is permanently dead:
     INACTIVE / COMPATIBILITY, or any value this script does not recognise
     (fail-closed). ACTIVE and OVERRIDE both pass this check - OVERRIDE means
     "member of a precedence chain", NOT "inactive", and whether a chain member
     is superseded in a particular run is decided by check 3 below from the
     sibling values actually present. Reading OVERRIDE as dead is what refused
     _2_BasketTP_ATRmult (Boss 14), _17_UseStructLevels (Boss 17) and
     _33_SL_MaxATRmult - three working dials - and the only escape was
     -SkipOptimizeGuard, which disables the checks that do have evidence.
     Cage: scripts\_test\run_optimize_guard_tests.ps1
  2. the parameter is inert for the specific Boss build being optimized, per the
     curated build-dead-zone table in PARAM_INACTIVE_AUDIT.md section 2 (the
     .ini's Expert= line names the build; StackMode/StackConfirm/etc. also carry
     a [LAB_ENTRY_nn] tag in the registry that must match).
  3. the parameter is OVERRIDDEN under the other values present in the same run
     (PARAM_LINKAGE.md override pairs) - e.g. sweeping _2_BasketTP_Money while
     _2_BasketTP_BalPct > 0 in the same .ini does nothing.
  4. the parameter is a SAFETY parameter: name matches ^RC_, or equals
     ProtectLevel / _9_MaxLevels, or its registry `context` column contains
     "safety" (case-insensitive) - e.g. exit/safety, execution/safety. These are
     ALWAYS refused, unconditionally, regardless of build/override state.

  An identifier this script cannot resolve against PARAM_REGISTRY.csv at all
  (unknown name, or an ambiguous multi-build identifier with no build context)
  is refused fail-closed - "sweep it anyway" is not the safe default for an
  unrecognized dial. EXCEPTION (user 2026-07-25): when the Expert is not a Boss
  build AND zero checked names resolve against the registry (an EA the registry
  has simply never catalogued), UNKNOWN downgrades to warn-only - refusing
  whole unregistered EAs only trains operators to -SkipOptimizeGuard everything.
  The safety-name check (RC_*/ProtectLevel/_9_MaxLevels) refuses regardless.

USAGE
  # audit the whole 184-row registry for how many dimensions are never-optimizable
  powershell -File scripts\optimize_guard.ps1

  # check every Y-flagged (optimize-enabled) dimension in a real Tester .ini
  powershell -File scripts\optimize_guard.ps1 -IniPath _mt5_auto\ini\BOSS14_OPT_AUDCAD_1.ini

  # check an explicit list of parameter names (optionally "Name=Value" to supply
  # a sibling value for override-gate checks when no .ini is given), against a
  # named build
  powershell -File scripts\optimize_guard.ps1 -ParamNames RC_MaxLot,TrendFilter -Build 16

  # report only, never fail the exit code (still prints REFUSE lines)
  powershell -File scripts\optimize_guard.ps1 -IniPath <path> -WarnOnly

EXIT CODE
  0 = every checked parameter is ALLOW (or -WarnOnly was passed)
  1 = at least one parameter is REFUSE (and -WarnOnly was not passed)
#>

param(
    [string]$IniPath,
    [string[]]$ParamNames,
    [Nullable[int]]$Build,
    [switch]$WarnOnly,
    # ORDER-630 (S5). When a run belongs to a registered hypothesis revision, the PER-HYPOTHESIS
    # binding also decides whether a parameter may be optimized -- the same input can be LOCKED in
    # B14-H01 and TUNABLE in B14-H02, which is the audit finding the ParameterBinding entity was
    # created for. That answer is NOT computed here. It comes from _triage/factory_os/registry.py,
    # which is the ONE resolver, because two consumers each combining permanent semantics
    # (docs/PARAM_REGISTRY.csv) with a per-hypothesis role their own way is how the same parameter
    # becomes tunable in one tool and locked in the other with nothing red anywhere.
    #
    # OMITTED = every existing call site. With no revision, not one line of this script's
    # behaviour changes; there is a control fixture asserting exactly that, byte for byte.
    [string]$HypothesisRevision = '',
    # An OVERLAY of extra ParameterBinding rows, on top of the canonical store. It exists so a
    # FIXTURE can drive this script against synthetic bindings without writing into the committed
    # store.
    #
    # ⚠️ THE ORIGINAL ARGUMENT FOR THIS PARAMETER WAS WRONG AND A BLIND AUDIT DISPROVED IT. It said
    # "there is no root that turns a REFUSE into an ALLOW", reasoning that a binding only ever adds
    # a refusal. True of ADDING one; false of REPLACING the store, which is what it did: a
    # canonical LOCKED binding gave REFUSE and an empty -BindingsRoot gave ALLOW. Reproduced end to
    # end. It passes --overlay-root now, and registry.py merges canonical-LAST, so the canonical
    # store wins every key it defines and an overlay cannot remove or relax a binding. The property
    # holds by construction rather than by this comment being persuasive.
    [string]$BindingsRoot = '',
    # ORDER-1253 (S13, design 8.6 item 6). The guard's verdicts were WRITTEN TO THE CONSOLE AND
    # LOST. `scripts\_test\run_optimize_guard_tests.ps1` drives 14 cases in both directions, but
    # CLAUDE.md's rule is that a guard with zero real fires is `UNTESTED` -- and there was nothing
    # an acceptance checker could read even after a real sweep happened, because no run left a
    # record behind. This appends ONE JSON object per submission to the named file.
    #
    # DEFAULT-OFF ON PURPOSE, and the honesty cost is stated rather than hidden: with -DecisionLog
    # omitted not one line of behaviour changes (asserted as a CONTROL in the cage), so a
    # submission can decline to be recorded. What the log proves is that the submissions IN IT
    # were judged -- never that every submission was. The alternative, writing unconditionally to
    # a fixed path, would make all 14 cage cases append to the committed store on every tier run.
    [string]$DecisionLog = '',
    # The MT5 install the sweep would run on. REQUIRED whenever -DecisionLog is given: design
    # 8.6 item 9 is "every run carries lane + data fingerprint", and a decision record that cannot
    # name the lane it authorised is not evidence about any particular lane. Fail-closed, like
    # every other unresolvable input in this script.
    [string]$Lane = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot     = Split-Path -Parent $PSScriptRoot
$csvReader    = Join-Path $PSScriptRoot 'lib\param_registry_csv.ps1'
if (-not (Test-Path -LiteralPath $csvReader -PathType Leaf)) { throw "Not found: $csvReader" }
. $csvReader
$registryPath = Join-Path $repoRoot 'docs\PARAM_REGISTRY.csv'
$linkagePath  = Join-Path $repoRoot 'docs\PARAM_LINKAGE.md'
$auditPath    = Join-Path $repoRoot '_triage\PARAM_INACTIVE_AUDIT.md'

foreach ($p in @($registryPath, $linkagePath, $auditPath)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" }
}

# ---------------------------------------------------------------------------
# ORDER-1253: the decision record. One JSON object per submission, appended.
# ---------------------------------------------------------------------------
if ($DecisionLog -ne '' -and $Lane -eq '') {
    throw "optimize_guard: -DecisionLog was given without -Lane. A decision record that cannot name the MT5 install it authorised is not evidence about any lane (design 8.6 item 9). Pass -Lane, or drop -DecisionLog and run it unrecorded."
}

function Write-DecisionRecord {
    <#
      Appends one record and returns nothing. The SHAPE is read back by
      _triage/factory_os/optimize_log.py, and the two ends are bound by a cage that RUNS this
      script into a temp file and hands the result to that module -- not by this comment.

      UTF-8 WITHOUT BOM, via AppendAllText rather than Out-File/Add-Content. Both of those write
      the console codepage or a BOM depending on host, and a BOM in the first line of a .jsonl
      makes json.loads fail on line 1 only, which reads as "the writer is broken" forever
      (memory `thai-output-kills-a-suite-inside-the-hook` is the same family: an encoding default
      that only bites inside another process).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Record
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    # -Depth 6: the default is 2, which silently renders the per-dimension `facts` array as the
    # string "System.Collections.Hashtable". A record whose reasons stringify to a type name is
    # the free-text failure this repo already has a memory for, arriving through the serializer.
    $json = ($Record | ConvertTo-Json -Depth 6 -Compress)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText($Path, $json + "`n", $enc)
    Write-Host ""
    Write-Host "DECISION RECORD -> $Path" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Small helper: split "Name[Tag]" into (BaseName, Tag)
# ---------------------------------------------------------------------------
function Split-NameTag {
    param([string]$Name)
    if ($Name -match '^(.*)\[(.+)\]$') {
        return [pscustomobject]@{ BaseName = $Matches[1]; Tag = $Matches[2] }
    }
    return [pscustomobject]@{ BaseName = $Name; Tag = $null }
}

# ---------------------------------------------------------------------------
# 1. Parse docs/PARAM_REGISTRY.csv (same quoted-field technique as
#    param_registry_check.ps1 - not a general-purpose CSV parser, relies on
#    every field being double-quoted with no embedded quotes, which holds for
#    this file).
# ---------------------------------------------------------------------------
function Get-RegistryRows {
    param([string]$Path)
    $parsed = Read-ParameterRegistryCsv -Path $Path
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($record in $parsed) {
        $nt = Split-NameTag $record.name
        $rows.Add([pscustomobject]@{
            Name               = $record.name
            BaseName           = $nt.BaseName
            Tag                = $nt.Tag
            Owner              = $record.owner
            Unit               = $record.unit
            Context            = $record.context
            ActiveWhen         = $record.active_when
            Coupled            = $record.coupled_parameters
            DefaultProfile     = $record.default_profile
            OptimizeStage      = $record.optimize_stage
            SafeRange          = $record.safe_range
            CausalQuestion     = $record.causal_question
            Classification     = $record.classification
            ClassificationNote = $record.classification_note
            ParameterPid       = [int]$record.parameter_pid
        })
    }
    return $rows
}

# ---------------------------------------------------------------------------
# 2. Parse docs/PARAM_LINKAGE.md "## Override pairs" bullet list:
#    - **`WINNER`** beats **`LOSER`** **[SILENT]** -- <note>
# ---------------------------------------------------------------------------
function Get-OverridePairs {
    param([string]$Path)
    $lines = Get-Content -LiteralPath $Path
    $pairs = New-Object System.Collections.Generic.List[object]
    foreach ($line in $lines) {
        if ($line -match '^-\s+\*\*`([^`]+)`\*\*\s+beats\s+\*\*`([^`]+)`\*\*') {
            $pairs.Add([pscustomobject]@{
                Winner = $Matches[1]
                Loser  = $Matches[2]
                Silent = ($line -match '\[SILENT\]')
            })
        }
    }
    return $pairs
}

# ---------------------------------------------------------------------------
# 3. Parse _triage/PARAM_INACTIVE_AUDIT.md section "## 2. Rows whose own
#    note/active_when declares inert / no-effect / dead-at-default" markdown
#    table into (Name, BuildsText, Why) rows.
# ---------------------------------------------------------------------------
function Get-BuildInertTable {
    param([string]$Path)
    $lines = Get-Content -LiteralPath $Path
    $inSection = $false
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in $lines) {
        if ($line -match '^##\s*2\.') { $inSection = $true; continue }
        if ($inSection -and $line -match '^##\s*3\.') { break }
        if (-not $inSection) { continue }
        if ($line -notmatch '^\|') { continue }
        if ($line -match '^\|\s*parameter\s*\|') { continue }
        if ($line -match '^\|\s*-{2,}\s*\|') { continue }
        $cols = $line.Trim().Trim('|').Split('|')
        if ($cols.Count -lt 3) { continue }
        $paramCell  = $cols[0].Trim()
        $buildsCell = $cols[1].Trim()
        $whyCell    = ($cols[2..($cols.Count - 1)] -join '|').Trim()
        if ($paramCell -match '`([^`]+)`') {
            $nt = Split-NameTag $Matches[1]
            $rows.Add([pscustomobject]@{
                Name       = $Matches[1]
                BaseName   = $nt.BaseName
                Tag        = $nt.Tag
                BuildsText = $buildsCell
                Why        = $whyCell
            })
        }
    }
    return $rows
}

# ---------------------------------------------------------------------------
# 4. Parse a Strategy Tester .ini: Expert= (-> build number) and every
#    [TesterInputs] Name=Value line, flagging which ones carry the
#    val||min||step||max||Y/N optimization-sweep syntax with Y (enabled).
# ---------------------------------------------------------------------------
function Get-IniTesterInputs {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Not found: $Path" }
    $lines = Get-Content -LiteralPath $Path
    $section = $null
    $expert = $null
    $inputs = @{}
    $sweepEnabled = @{}
    foreach ($raw in $lines) {
        $t = $raw.Trim()
        if ($t.Length -eq 0) { continue }
        if ($t -match '^\[(.+)\]$') { $section = $Matches[1]; continue }
        if ($section -eq 'Tester' -and $t -match '^Expert\s*=\s*(.+)$') {
            $expert = $Matches[1].Trim().Trim('"')
            continue
        }
        if ($section -eq 'TesterInputs' -and $t -match '^([^=]+)=(.*)$') {
            $name = $Matches[1].Trim()
            $val  = $Matches[2].Trim()
            $inputs[$name] = $val
            $isSweep = $false
            if ($val -match '^[^|]*\|\|[^|]*\|\|[^|]*\|\|[^|]*\|\|\s*([YyNn])\s*$') {
                $isSweep = ($Matches[1] -eq 'Y' -or $Matches[1] -eq 'y')
            }
            $sweepEnabled[$name] = $isSweep
        }
    }
    $buildNum = $null
    if ($expert -and $expert -match 'Boss_(\d+)_') { $buildNum = [int]$Matches[1] }
    return [pscustomobject]@{
        Expert       = $expert
        Build        = $buildNum
        Inputs       = $inputs
        SweepEnabled = $sweepEnabled
    }
}

function Get-EffectiveValue {
    param([string]$RawValue)
    if ($null -eq $RawValue) { return $null }
    if ($RawValue -match '^([^|]*)\|\|') { return $Matches[1].Trim() }
    return $RawValue.Trim()
}

function Test-Truthy {
    param([string]$ValueStr)
    if ([string]::IsNullOrWhiteSpace($ValueStr)) { return $false }
    $v = $ValueStr.Trim()
    if ($v -match '^(?i:true)$')  { return $true }
    if ($v -match '^(?i:false)$') { return $false }
    $num = 0.0
    if ([double]::TryParse($v, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$num)) {
        return ($num -ne 0)
    }
    return $false
}

# ---------------------------------------------------------------------------
# Classification vocabulary (docs/PARAM_REGISTRY.csv column 11).
#   LIVE = the input can still change behaviour somewhere. ACTIVE is
#          unconditional; OVERRIDE means it sits in a precedence chain, so
#          whether it does anything in a GIVEN run depends on the sibling
#          values in that run - which is check 3's job, not this column's.
#   DEAD = the input cannot change behaviour at all on the build it is tagged
#          for. Those are refused outright.
# Any value outside both lists is refused fail-closed (a new column value must
# be classified deliberately, never inherited as "probably fine").
# ---------------------------------------------------------------------------
$script:LiveClassifications = @('ACTIVE', 'OVERRIDE')
$script:DeadClassifications = @('INACTIVE', 'COMPATIBILITY')

# ---------------------------------------------------------------------------
# Per-parameter verdict
# ---------------------------------------------------------------------------
function Test-OptimizeParameter {
    param(
        [string]$Name,
        [Nullable[int]]$Build,
        [hashtable]$IniValues,
        [object[]]$RegistryRows,
        [object[]]$OverridePairs,
        [object[]]$InertTable,
        [bool]$UnknownIsWarn = $false
    )

    $facts = New-Object System.Collections.Generic.List[object]   # {Refuse=bool; Text=string}
    $nt = Split-NameTag $Name
    $baseName = $nt.BaseName

    # ---- check 4: SAFETY by name (unconditional, checked before anything else) ----
    $isSafetyName = ($baseName -match '^RC_') -or ($baseName -eq 'ProtectLevel') -or ($baseName -eq '_9_MaxLevels')
    if ($isSafetyName) {
        $facts.Add([pscustomobject]@{ Refuse = $true; Text = "SAFETY: name matches RC_*/ProtectLevel/_9_MaxLevels rule - must never be optimized for profit" })
    }

    # ---- resolve registry row(s) by base name ----
    $candidates = @($RegistryRows | Where-Object { $_.BaseName -eq $baseName })
    $row = $null
    if ($candidates.Count -eq 1) {
        $row = $candidates[0]
    } elseif ($candidates.Count -gt 1) {
        $wantTag = if ($Build) { "LAB_ENTRY_$Build" } else { $nt.Tag }
        if ($wantTag) { $row = $candidates | Where-Object { $_.Tag -eq $wantTag } | Select-Object -First 1 }
        if (-not $row) {
            $facts.Add([pscustomobject]@{ Refuse = $true; Text = "UNRESOLVED: $($candidates.Count) registry rows share identifier '$baseName' across builds and no -Build/-IniPath Expert= resolved which applies (fail-closed)" })
        }
    } else {
        if ($UnknownIsWarn) {
            # Non-Boss EA whose inputs the registry has never catalogued: refusing here
            # only trains operators to pass -SkipOptimizeGuard on every run, which also
            # silences the checks that DO have evidence behind them. Safety-name check
            # (RC_*/ProtectLevel/_9_MaxLevels) above still refuses unconditionally.
            $facts.Add([pscustomobject]@{ Refuse = $false; Text = "UNKNOWN (warn-only): '$baseName' not in docs/PARAM_REGISTRY.csv and Expert is not a registry-covered Boss build - cannot verify ACTIVE/override/inert status" })
        } else {
            $facts.Add([pscustomobject]@{ Refuse = $true; Text = "UNKNOWN: no row in docs/PARAM_REGISTRY.csv matches identifier '$baseName' (fail-closed - cannot verify ACTIVE classification)" })
        }
    }

    if ($row) {
        # ---- check 4b: SAFETY by registry context ----
        if ($row.Context -match '(?i)safety') {
            $facts.Add([pscustomobject]@{ Refuse = $true; Text = "SAFETY: registry context='$($row.Context)' - must never be optimized for profit" })
        }

        # ---- check 1: classification ----
        # This check used to be `-ne 'ACTIVE'`, which read OVERRIDE as "dead".
        # It does not mean that: OVERRIDE marks an input as a MEMBER OF A
        # PRECEDENCE CHAIN, and the member that wins the chain is the one doing
        # the work. Refusing it made three real, working dials un-sweepable
        # (_2_BasketTP_ATRmult on Boss 14, _17_UseStructLevels on Boss 17,
        # _33_SL_MaxATRmult) and the only way past the guard was
        # -SkipOptimizeGuard, which also switches off the checks that DO have
        # evidence behind them. Whether a chain member is actually dead in THIS
        # run is decided by check 3 from the sibling values present, not by a
        # static column - so classification now only answers "is this input
        # permanently dead?", and precedence is left to check 3.
        $cls = ("$($row.Classification)").Trim().ToUpperInvariant()
        $note = if ($row.ClassificationNote) { " - $($row.ClassificationNote)" } else { '' }
        if ($script:DeadClassifications -contains $cls) {
            $facts.Add([pscustomobject]@{ Refuse = $true; Text = "classification='$($row.Classification)' (docs/PARAM_REGISTRY.csv - permanently dead, not a precedence loser)$note" })
        } elseif ($script:LiveClassifications -notcontains $cls) {
            # An unrecognized classification is not evidence of health. Fail closed
            # rather than silently treating a new column value as sweepable.
            $facts.Add([pscustomobject]@{ Refuse = $true; Text = "classification='$($row.Classification)' is not a value this guard knows (expected one of: $(($script:LiveClassifications + $script:DeadClassifications) -join ', ')) - fail-closed$note" })
        } elseif ($cls -eq 'OVERRIDE') {
            $facts.Add([pscustomobject]@{ Refuse = $false; Text = "classification='OVERRIDE' (member of a precedence chain, not inactive)$note - whether it is superseded in THIS run is decided below from the sibling values supplied" })
        }

        # ---- check 2: build inertness ----
        if ($Build) {
            $inertHit = $InertTable | Where-Object {
                $_.BaseName -eq $baseName -and
                (-not $_.Tag -or $_.Tag -eq "LAB_ENTRY_$Build") -and
                ($_.BuildsText -match '\ball\s+\d+\s+builds\b' -or $_.BuildsText -match "\b$Build\b")
            } | Select-Object -First 1
            if ($inertHit) {
                $facts.Add([pscustomobject]@{ Refuse = $true; Text = "inert on build $Build per _triage/PARAM_INACTIVE_AUDIT.md ($($inertHit.BuildsText)) - $($inertHit.Why)" })
            }
        } else {
            $facts.Add([pscustomobject]@{ Refuse = $false; Text = "build-inertness NOT checked (no Boss build resolved - pass -Build or -IniPath); registry active_when: $($row.ActiveWhen)" })
        }
    }

    # ---- check 3: override (independent of row resolution - works off name alone) ----
    $asLoser = @($OverridePairs | Where-Object { $_.Loser -eq $baseName })
    foreach ($pair in $asLoser) {
        if ($IniValues.ContainsKey($pair.Winner)) {
            $winnerEff = Get-EffectiveValue $IniValues[$pair.Winner]
            if (Test-Truthy $winnerEff) {
                $silentTag = if ($pair.Silent) { ' [SILENT override - loser row carries no warning]' } else { '' }
                $facts.Add([pscustomobject]@{ Refuse = $true; Text = "OVERRIDDEN: '$($pair.Winner)'=$winnerEff in this run supersedes '$baseName' (docs/PARAM_LINKAGE.md)$silentTag - sweeping it does nothing" })
            }
        } else {
            $facts.Add([pscustomobject]@{ Refuse = $false; Text = "cannot verify override: winner '$($pair.Winner)'s value not supplied (docs/PARAM_LINKAGE.md lists it as overriding '$baseName' under some condition)" })
        }
    }

    if ($facts.Count -eq 0) {
        $facts.Add([pscustomobject]@{ Refuse = $false; Text = 'classification=ACTIVE, no build/override/safety conflict found' })
    }

    $verdict = if (@($facts | Where-Object { $_.Refuse }).Count -gt 0) { 'REFUSE' } else { 'ALLOW' }
    return [pscustomobject]@{
        Name    = $Name
        Verdict = $verdict
        Facts   = $facts
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
$registryRows  = Get-RegistryRows -Path $registryPath
$overridePairs = Get-OverridePairs -Path $linkagePath
$inertTable    = Get-BuildInertTable -Path $auditPath

Write-Host "=== optimize_guard.ps1 (ORDER-192b) ==="
Write-Host "Registry rows loaded  : $($registryRows.Count)"
Write-Host "Override pairs loaded : $($overridePairs.Count)"
Write-Host "Build-inert rows loaded: $($inertTable.Count)"
Write-Host ""

# ---- mode 0: no -IniPath and no -ParamNames -> whole-registry summary ----
if (-not $IniPath -and (-not $ParamNames -or $ParamNames.Count -eq 0)) {
    if ($DecisionLog -ne '') {
        # This mode judges no submission -- it tallies the registry. Writing a record here would
        # put a row in the log that no sweep ever asked for, and staying silent would drop a
        # record the caller asked for. Refuse instead of choosing one of those for them.
        throw "optimize_guard: -DecisionLog was given in whole-registry audit mode (no -IniPath and no -ParamNames). That mode judges no submission, so there is no decision to record. Give the .ini or the parameter list you want judged."
    }
    Write-Host "No -IniPath / -ParamNames given: reporting whole-registry never-optimizable summary." -ForegroundColor Yellow
    Write-Host ""
    $safetyNamePattern = { param($n) ($n -match '^RC_') -or ($n -eq 'ProtectLevel') -or ($n -eq '_9_MaxLevels') }
    $neverOptimizable = New-Object System.Collections.Generic.List[object]
    foreach ($row in $registryRows) {
        $isSafety = (& $safetyNamePattern $row.BaseName) -or ($row.Context -match '(?i)safety')
        # Same correction as check 1: OVERRIDE rows are precedence-chain members,
        # not never-optimizable rows. Counting them here made this tally overstate
        # how much of the registry is off-limits.
        $cls = ("$($row.Classification)").Trim().ToUpperInvariant()
        $isDead = ($script:DeadClassifications -contains $cls) -or ($script:LiveClassifications -notcontains $cls)
        if ($isSafety -or $isDead) {
            $reason = @()
            if ($isDead)   { $reason += "classification=$($row.Classification)" }
            if ($isSafety) { $reason += 'safety' }
            $neverOptimizable.Add([pscustomobject]@{ Name = $row.Name; Reason = ($reason -join '+') })
        }
    }
    $neverOptimizable | Sort-Object Reason, Name | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "Never-optimizable (dead classification OR safety): $($neverOptimizable.Count) / $($registryRows.Count) rows"
    Write-Host "(OVERRIDE rows are NOT counted here - they are precedence-chain members whose deadness depends on the sibling values in a specific run; the per-run override check decides those)"
    Write-Host "(build-specific inertness from PARAM_INACTIVE_AUDIT.md section 2 is a further, per-build REFUSE layer - only meaningful once a Boss build/.ini is named; not counted in this build-agnostic registry-wide tally)"
    exit 0
}

# ---- build the candidate parameter set + IniValues map ----
$iniValues = @{}
$build = $Build
$checkList = New-Object System.Collections.Generic.List[string]
$source = @{}   # Name -> how it entered the check set (for reporting)
$expertName = ''    # ORDER-1253: set from the .ini when there is one; '' is the honest value otherwise
$bindingFor = @{}   # ORDER-1253: Name -> the resolver's answer, kept STRUCTURED for the record

if ($IniPath) {
    $ini = Get-IniTesterInputs -Path $IniPath
    foreach ($k in $ini.Inputs.Keys) { $iniValues[$k] = $ini.Inputs[$k] }
    if (-not $build) { $build = $ini.Build }
    $expertName = $ini.Expert          # ORDER-1253: carried into the decision record
    Write-Host "Ini file   : $IniPath"
    Write-Host "Expert     : $($ini.Expert)"
    Write-Host "Boss build : $(if ($build) { $build } else { '(unresolved)' })"
    foreach ($name in $ini.SweepEnabled.Keys) {
        if ($ini.SweepEnabled[$name]) {
            [void]$checkList.Add($name)
            $source[$name] = 'swept (Y) in .ini'
        }
    }
    Write-Host "Sweep-enabled (Y) dimensions in this .ini: $($checkList.Count)"
    Write-Host ""
}

if ($ParamNames) {
    foreach ($item in $ParamNames) {
        $t = $item.Trim()
        if ($t -match '^([^=]+)=(.*)$') {
            $n = $Matches[1].Trim()
            $v = $Matches[2].Trim()
            $iniValues[$n] = $v
        } else {
            $n = $t
        }
        if (-not $checkList.Contains($n)) { [void]$checkList.Add($n) }
        if (-not $source.ContainsKey($n)) { $source[$n] = '-ParamNames' }
    }
}

if ($checkList.Count -eq 0) {
    Write-Host "Nothing to check (no Y-flagged sweep dimensions in the .ini and no -ParamNames given)." -ForegroundColor Yellow
    if ($DecisionLog -ne '') {
        # RECORDED, not skipped. A submission that judged nothing must not be absent from the log,
        # or "the guard never refused anything" and "the guard was never asked anything" become
        # the same reading of the same file.
        Write-DecisionRecord -Path $DecisionLog -Record @{
            record_version      = 1
            submitted_utc       = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            lane                = $Lane
            hypothesis_revision = $HypothesisRevision
            build               = $(if ($build) { $build } else { $null })
            ini_path            = $IniPath
            expert              = $expertName
            warn_only           = [bool]$WarnOnly
            result              = 'NOTHING_TO_CHECK'
            checked             = 0
            allow_count         = 0
            refuse_count        = 0
            dimensions          = @()
            exit_code           = 0
        }
    }
    exit 0
}

# Unknown-EA downgrade: if no Boss build resolved AND not a single checked name exists
# in the registry, this is an EA the registry has never catalogued (e.g. a standalone
# non-Boss expert) - report UNKNOWN as warn-only instead of REFUSE. A Boss build (or a
# partial match, which suggests a typo among known names) keeps the fail-closed default.
$resolvableCount = 0
foreach ($name in $checkList) {
    $bn = (Split-NameTag $name).BaseName
    if (@($registryRows | Where-Object { $_.BaseName -eq $bn }).Count -gt 0) { $resolvableCount++ }
}
$unknownIsWarn = (-not $build) -and ($resolvableCount -eq 0)
if ($unknownIsWarn) {
    Write-Host "NOTE: no Boss build and 0/$($checkList.Count) parameters known to the registry - unregistered EA, UNKNOWN downgraded to warn-only (safety-name check still enforced)." -ForegroundColor Yellow
    Write-Host ""
}

# ORDER-630 (S5): the per-hypothesis layer, resolved ONCE, by the one resolver.
# `$bindings` stays empty when no revision was given, so the loop below is a no-op and this
# script behaves exactly as it did before -- asserted as a CONTROL in run_registry_tests.ps1.
$bindings = @{}
if ($HypothesisRevision -ne '') {
    $py = Join-Path $repoRoot 'tools\python312\python.exe'
    $resolver = Join-Path $repoRoot '_triage\factory_os\registry.py'
    if (-not (Test-Path -LiteralPath $py) -or -not (Test-Path -LiteralPath $resolver)) {
        # Fail CLOSED. A revision was named, so the caller believes bindings apply; not being able
        # to read them is "I cannot tell", which must never be published as "nothing applies".
        throw "optimize_guard: -HypothesisRevision was given but the resolver is not available ($resolver). Refusing to run: 'I could not read the bindings' is not 'there are no bindings'."
    }
    $bindErr = Join-Path ([System.IO.Path]::GetTempPath()) ("optguard_" + [guid]::NewGuid().ToString('N') + ".err")
    $resolveArgs = @($resolver, 'resolve', $HypothesisRevision)
    # --overlay-root, NOT --root. A blind audit disproved the claim this seam was built on:
    # --root REPLACED the store, so a canonical LOCKED binding gave REFUSE and an empty
    # -BindingsRoot gave ALLOW. The seam bought exactly the permission its own comment said it
    # could not. An overlay merges canonical-last, so it can ADD a refusal and can never remove
    # one -- the property is now structural instead of argued.
    if ($BindingsRoot -ne '') { $resolveArgs += "--overlay-root=$BindingsRoot" }
    # ORDER-671 U3 / ORDER-672. The build being swept is passed to the resolver, so a binding that
    # names its build is found. Without this, a revision that binds one parameter PER BUILD makes
    # the resolver refuse the under-specified question -- and under 671 an unfound binding is now a
    # REFUSAL, so the consumer failing to ask precisely would look exactly like a policy violation.
    if ($build) { $resolveArgs += "--build-tag=$build" }
    $bindJson = & $py $resolveArgs 2>$bindErr
    $bindRc = $LASTEXITCODE
    $bindErrText = ''
    if (Test-Path -LiteralPath $bindErr) {
        $bindErrText = (Get-Content -LiteralPath $bindErr -Raw -ErrorAction SilentlyContinue)
        Remove-Item -LiteralPath $bindErr -ErrorAction SilentlyContinue
    }
    if ($bindRc -ne 0) { throw "optimize_guard: the ParameterBinding resolver refused (exit $bindRc): $(($bindJson -join ' ')) $bindErrText" }
    $parsed = ($bindJson -join '') | ConvertFrom-Json
    foreach ($p in $parsed.PSObject.Properties) { $bindings[$p.Name] = $p.Value }
    Write-Host ("BINDINGS: $HypothesisRevision resolved $($bindings.Count) ParameterBinding row(s) via _triage/factory_os/registry.py") -ForegroundColor Cyan
    Write-Host ""
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($name in $checkList) {
    $r = Test-OptimizeParameter -Name $name -Build $build -IniValues $iniValues -RegistryRows $registryRows -OverridePairs $overridePairs -InertTable $inertTable -UnknownIsWarn $unknownIsWarn
    $bn = (Split-NameTag $name).BaseName
    if ($bindings.ContainsKey($bn)) {
        $b = $bindings[$bn]
        # `optimizable` is DERIVED by the resolver and read here as a value. This script does not
        # know which roles are optimizable and must not learn -- that list is an allowlist in
        # registry.py, so a role added to the enum later is refused until somebody decides.
        # ORDER-1253: the resolver's answer, kept as FIELDS. The same answer also lands in the
        # fact text below, and that text is prose -- a reader asking "was this refused by the
        # binding layer" against prose is the equality-on-free-text shape ORDER-1251 exists for.
        $bindingFor[$name] = @{
            role        = $b.role
            optimizable = [bool]($b.optimizable -eq $true)
            surface     = $b.surface
            source      = 'ParameterBinding'
        }
        if ($b.optimizable -ne $true) {
            $r.Facts.Add([pscustomobject]@{ Refuse = $true; Text = "ParameterBinding: role='$($b.role)' in $HypothesisRevision is not optimizable (resolved by _triage/factory_os/registry.py, surface='$($b.surface)')" }) | Out-Null
            $r.Verdict = 'REFUSE'
        } else {
            $r.Facts.Add([pscustomobject]@{ Refuse = $false; Text = "ParameterBinding: role='$($b.role)' in $HypothesisRevision is optimizable" }) | Out-Null
        }
    } elseif ($HypothesisRevision -ne '') {
        # The `-ne ''` guard is NOT decoration. Without it this branch fired for EVERY parameter on
        # EVERY existing call site, because `$bindings` is empty when no revision was declared --
        # which would have broken the one promise this wiring made in writing: with no
        # -HypothesisRevision, not one line of output changes. Caught by the SPECIFICITY assertion
        # in run_registry_tests.ps1 ("with no revision declared, no UNBOUND note is emitted at
        # all"), on the first run after the fix for the audit finding went in. The fix for a
        # finding needed a fix.
        #
        # FOUND BY A BLIND AUDIT, 2026-07-31, and reproduced before being accepted. The resolver
        # returns optimizable=$null / source=UNBOUND for a parameter no binding describes, and its
        # own docstring says that exists so permission is never granted BY SILENCE. This branch did
        # not exist: the $null was computed and then dropped, so a run declared to belong to
        # B14-H01-r1 swept a parameter that revision never mentioned, and NOTHING anywhere said so.
        # The resolver kept its promise and the consumer broke it one line later.
        #
        # ⚠️ ORDER-671, OWNER-RATIFIED 2026-07-31 (PROJECT_STATE.md section 3): THIS IS NOW A
        # REFUSAL. The paragraph that used to sit here argued for a NOTE on COMPLETENESS grounds --
        # "whether a revision's binding set must be complete is undecided" -- and the owner decided
        # on different grounds entirely, which is why the argument did not survive its own logic:
        #
        #   `-HypothesisRevision X` is a CLAIM THAT THIS RUN IS EVIDENCE ABOUT X. A dimension X
        #   never describes cannot be evidence about X. That is ATTRIBUTION, not completeness, and
        #   it needs no ruling on whether a binding set must be closed.
        #
        # Taken at the cheapest moment it will ever be available: factory/hypotheses.jsonl is
        # EMPTY, so the strict rule refuses ZERO existing runs today. Every later day turns a
        # decision into a migration.
        #
        # SCOPE IS EXACT, and the `-ne ''` guard above is what makes it so: with no
        # -HypothesisRevision declared, this branch does not run and not one line of output
        # changes. That is U2, and it is asserted next to U1 in run_registry_tests.ps1 so neither
        # can be quoted without the other -- the first version of this repair fired on every
        # legacy call site and was caught only because that assertion already existed.
        $bindingFor[$name] = @{
            role        = $null
            optimizable = $false
            surface     = $null
            source      = 'UNBOUND'
        }
        $r.Facts.Add([pscustomobject]@{ Refuse = $true; Text = "ParameterBinding: UNBOUND - '$name' is swept under $HypothesisRevision, but that revision registers no binding for it (build tag: $(if ($build) { $build } else { '(none)' })). REFUSED (ORDER-671, owner-ratified): declaring -HypothesisRevision claims this run is EVIDENCE ABOUT $HypothesisRevision, and a dimension that revision never describes cannot be evidence about it. Either register a ParameterBinding for '$name' in $HypothesisRevision, or drop -HypothesisRevision and run it as an undeclared sweep." }) | Out-Null
        $r.Verdict = 'REFUSE'
    }
    $results.Add($r)
}

Write-Host "--- Per-parameter verdicts ---"
foreach ($r in $results) {
    $color = if ($r.Verdict -eq 'REFUSE') { 'Red' } else { 'Green' }
    Write-Host ("[{0}] {1}  (from: {2})" -f $r.Verdict, $r.Name, $source[$r.Name]) -ForegroundColor $color
    foreach ($f in $r.Facts) {
        $prefix = if ($f.Refuse) { '  - REFUSE-reason: ' } else { '  - note: ' }
        Write-Host ("$prefix$($f.Text)")
    }
}

$refuseCount = @($results | Where-Object { $_.Verdict -eq 'REFUSE' }).Count
$allowCount  = @($results | Where-Object { $_.Verdict -eq 'ALLOW' }).Count

Write-Host ""
Write-Host "--- Summary ---"
Write-Host "Checked : $($results.Count)"
Write-Host "ALLOW   : $allowCount"
Write-Host "REFUSE  : $refuseCount"

# ORDER-1253. The verdict is decided ONCE, here, and both the console line and the record read the
# same two variables. Computing "what the record says" separately from "what the operator was told"
# is how a log ends up disagreeing with the run it describes.
$overall  = if ($refuseCount -gt 0) { 'REFUSE' } else { 'ALLOW' }
$exitCode = if ($refuseCount -gt 0 -and -not $WarnOnly) { 1 } else { 0 }

if ($DecisionLog -ne '') {
    $dims = @()
    foreach ($r in $results) {
        $facts = @()
        foreach ($f in $r.Facts) {
            $facts += @{ refuse = [bool]$f.Refuse; text = [string]$f.Text }
        }
        $dims += @{
            name    = [string]$r.Name
            verdict = [string]$r.Verdict
            source  = [string]$source[$r.Name]
            binding = $(if ($bindingFor.ContainsKey($r.Name)) { $bindingFor[$r.Name] } else { $null })
            facts   = $facts
        }
    }
    Write-DecisionRecord -Path $DecisionLog -Record @{
        record_version      = 1
        submitted_utc       = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        lane                = $Lane
        hypothesis_revision = $HypothesisRevision
        build               = $(if ($build) { $build } else { $null })
        ini_path            = $IniPath
        expert              = $expertName
        warn_only           = [bool]$WarnOnly
        result              = $overall
        checked             = $results.Count
        allow_count         = $allowCount
        refuse_count        = $refuseCount
        dimensions          = $dims
        exit_code           = $exitCode
    }
}

if ($refuseCount -gt 0) {
    if ($WarnOnly) {
        Write-Host ""
        Write-Host "RESULT: $refuseCount parameter(s) would be REFUSEd - WarnOnly set, exiting 0." -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
    Write-Host "RESULT: REFUSE - $refuseCount parameter(s) failed the optimizer guard. Fix the sweep set before running." -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "RESULT: ALLOW - all $($results.Count) checked parameter(s) are clean to optimize." -ForegroundColor Green
    exit 0
}
