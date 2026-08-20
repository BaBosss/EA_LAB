# Scaffolding for a new LAB_ENTRY_<N> template plugin (Boss wrapper + entry skeleton + LabCore.mqh
# + core/Inputs.mqh wiring). The mechanical part of ea_template's "add a new strategy" procedure
# (docs/EA_CORE_AND_TEMPLATE_GUIDE.md S3.4 steps 3-4) has no automation today, and a static
# per-entry list once silently omitted Boss_17_Wave5 from deploy.ps1 (ORDER-129) because nobody
# remembered every touch point by hand. This scaffold makes every touch point mechanical and
# impossible to omit, and refuses instead of guessing when it cannot find them.
#
# B-F1 (Audit B, P0 blocker). core/Inputs.mqh used to be deliberately left un-auto-edited here,
# on the theory that its scattered LAB_ENTRY_<n> sections were too risky to touch by regex and a
# reported anchor line was safer than a guess. In practice that meant a genuinely new
# LAB_ENTRY_<N> compiled SILENTLY WRONG: Inputs.mqh's top-of-file fallback chain
# (`#ifndef LAB_ENTRY_11 ... #ifndef LAB_ENTRY_18 #define LAB_ENTRY_11`) does not know the new
# token, so it ALSO fires and defines LAB_ENTRY_11 -- and LabCore.mqh then compiles in BOTH the
# new entry's module and entries/Entry_GridTrendMA.mqh, which fails with "function already
# defined and has body" on the duplicate Entry_Evaluate() (confirmed by a real MetaEditor
# compile during Audit B reproduction). Two touch points in Inputs.mqh are therefore mechanical
# and mandatory, exactly like the two in LabCore.mqh already were:
#   (1) the top fallback #ifndef chain: add one more nested `#ifndef LAB_ENTRY_<N>` so the
#       fallback build no longer fires when the wrapper defines the new token.
#   (2) the "9x Stack" guard-pair block: StackMode/StackConfirm are declared once per
#       #ifdef LAB_ENTRY_<n> and are referenced UNCONDITIONALLY by Stack.mqh/ExitManager.mqh
#       regardless of which entry is active, so a new entry with no such block leaves both
#       inputs undeclared -- a second, independent way to fail to compile.
# Both are patched by exact, validated anchor matches (same "refuse rather than guess"
# philosophy as the LabCore.mqh patch below) -- see Get-TemplateEntryScaffoldPlan and the
# $inputsNew construction in New-TemplateEntryScaffold.
#
# StackMode/StackConfirm are MONEY/RISK-semantic (they select single-order vs. grid-add vs.
# pending-ladder behavior and the add-confirmation rule) -- CLAUDE.md's verdict-gate discipline
# and this program's explicit non-goals forbid this scaffold from silently guessing a default for
# either one. -StackMode/-StackConfirm are therefore MANDATORY parameters, validated against the
# real ENUM_STACK_MODE / ENUM_STACK_CONFIRM member names parsed live out of core/Inputs.mqh (never
# a hand-kept copy of the enum -- the same "derived, never listed" rule _triage/factory_os/preset.py
# uses for LAB_ENTRY tags). The caller must state an explicit, real member name; there is no
# fallback value.
#
# Everything else in core/Inputs.mqh (the strategy-specific `input group "=== E<N> ..."` block
# further down) stays untouched by design: the scaffolded Entry_<Name>.mqh never references a
# strategy-specific input (it always returns Entry_MakeNone(), a TODO stub), so nothing there is
# required for a 0-error/0-warning compile, and inventing strategy-specific inputs here would be
# exactly the semantic guessing this scaffold must refuse to do.

function Test-TemplateEntryName {
    param([Parameter(Mandatory)][string]$Name)
    return [bool]($Name -cmatch '^[A-Za-z][A-Za-z0-9]*$')
}

# Derived from the real `enum ENUM_STACK_MODE { STACK_SINGLE = 90, ... };` /
# `enum ENUM_STACK_CONFIRM { ... };` blocks in core/Inputs.mqh -- never a hand-kept copy. Returns
# $null if the named enum cannot be found (caller treats that as MISSING_ANCHOR, not as "no members").
function Get-TemplateEntryEnumMembers {
    param(
        [Parameter(Mandatory)][string]$InputsText,
        [Parameter(Mandatory)][string]$EnumName
    )
    $m = [regex]::Match($InputsText, '(?ms)^\s*enum\s+' + [regex]::Escape($EnumName) + '\s*\r?\n\s*\{(.*?)\}\s*;')
    if (-not $m.Success) { return $null }
    $body = $m.Groups[1].Value
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($body -split "`n")) {
        $mm = [regex]::Match($line, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=')
        if ($mm.Success) { [void]$names.Add($mm.Groups[1].Value) }
    }
    return @($names)
}

# Locates (and validates the SHAPE of) the two mandatory core/Inputs.mqh touch points for a new
# LAB_ENTRY_<N>, by exact structural anchor -- never by guessing a line number. Refuses
# (Valid=$false) rather than patch a file whose shape has drifted from what this scaffold knows
# how to extend safely. Used by both the plan (validation) and the apply step (same computation,
# re-derived from the live file so plan and apply can never disagree about where to insert).
function Get-TemplateEntryInputsAnchors {
    param(
        [Parameter(Mandatory)][string]$InputsText,
        [Parameter(Mandatory)][int]$EntryNumber
    )
    $result = [ordered]@{
        Valid                   = $false
        Reason                  = ''
        Lines                   = $null
        FallbackDefineLineIndex = -1
        FallbackChainCount      = 0
        StackRegionEndLineIndex = -1
    }
    $lines = $InputsText -split "`n"
    $result.Lines = $lines

    $defMatches = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*#define\s+LAB_ENTRY_\d+\s*//\s*fallback build\s*$') { $defMatches += $i }
    }
    if ($defMatches.Count -ne 1) {
        $result.Reason = "MISSING_ANCHOR: expected exactly one '#define LAB_ENTRY_<n> // fallback build' line in core\Inputs.mqh, found $($defMatches.Count)"
        return [pscustomobject]$result
    }
    $defIdx = $defMatches[0]

    # Walk upward collecting the contiguous '#ifndef LAB_ENTRY_<n>' chain immediately above the
    # fallback #define -- these are the entries the file currently KNOWS about.
    $tags = @()
    $i = $defIdx - 1
    while ($i -ge 0 -and $lines[$i] -match '^\s*#ifndef\s+LAB_ENTRY_(\d+)\s*$') {
        $tags += [int]$Matches[1]
        $i--
    }
    if ($tags.Count -eq 0) {
        $result.Reason = 'MISSING_ANCHOR: no #ifndef LAB_ENTRY_<n> chain found immediately above the fallback #define in core\Inputs.mqh'
        return [pscustomobject]$result
    }
    if ($tags -contains $EntryNumber) {
        $result.Reason = "ENTRY_NUMBER_COLLISION: LAB_ENTRY_$EntryNumber already referenced in core\Inputs.mqh's fallback chain"
        return [pscustomobject]$result
    }

    # Walk downward collecting the matching '#endif' run; count MUST equal the ifndef count, or
    # this scaffold does not know which #endif closes which #ifndef and refuses rather than guess.
    $j = $defIdx + 1
    $endifCount = 0
    while ($j -lt $lines.Count -and $lines[$j] -match '^\s*#endif\s*$') { $endifCount++; $j++ }
    if ($endifCount -ne $tags.Count) {
        $result.Reason = "MISSING_ANCHOR: fallback chain in core\Inputs.mqh has $($tags.Count) '#ifndef LAB_ENTRY_<n>' line(s) but $endifCount matching '#endif' line(s) -- refusing rather than guessing where the chain ends"
        return [pscustomobject]$result
    }

    $result.FallbackDefineLineIndex = $defIdx
    $result.FallbackChainCount      = $tags.Count

    if ($InputsText -match "#ifdef\s+LAB_ENTRY_$EntryNumber\b") {
        $result.Reason = "ENTRY_NUMBER_COLLISION: '#ifdef LAB_ENTRY_$EntryNumber' already present in core\Inputs.mqh"
        return [pscustomobject]$result
    }

    # The StackMode/StackConfirm guard-pair blocks (one #ifdef LAB_ENTRY_<n> block per existing
    # entry) sit directly above this single anchor line -- insert the new entry's block right
    # before it, after the last existing one.
    $regionEndMatches = @()
    for ($k = 0; $k -lt $lines.Count; $k++) {
        if ($lines[$k] -match '^\s*#ifndef\s+LAB_CONST__9_StepUseATR\s*$') { $regionEndMatches += $k }
    }
    if ($regionEndMatches.Count -ne 1) {
        $result.Reason = "MISSING_ANCHOR: expected exactly one '#ifndef LAB_CONST__9_StepUseATR' line in core\Inputs.mqh, found $($regionEndMatches.Count)"
        return [pscustomobject]$result
    }
    $result.StackRegionEndLineIndex = $regionEndMatches[0]

    $result.Valid  = $true
    $result.Reason = 'OK'
    return [pscustomobject]$result
}

function Get-TemplateEntryScaffoldPlan {
    param(
        [Parameter(Mandatory)]$EntryNumber,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$TemplateRoot,
        # MONEY/RISK-semantic (StackMode selects single-order vs. grid-add vs. pending-ladder;
        # StackConfirm selects the add-confirmation rule) -- MANDATORY, no default, validated
        # against the real enum member names in core\Inputs.mqh. See file header (B-F1).
        [Parameter(Mandatory)][string]$StackMode,
        [Parameter(Mandatory)][string]$StackConfirm
    )
    $plan = [ordered]@{
        Valid             = $false
        Reason            = ''
        EntryNumber       = $EntryNumber
        Name              = $Name
        TemplateRoot      = $TemplateRoot
        StackMode         = $StackMode
        StackConfirm      = $StackConfirm
        BossPath          = $null
        EntryPath         = $null
        LabCorePath       = $null
        InputsPath        = $null
        InputsAnchorLines = @()
    }

    $numOk  = $false
    $numInt = 0
    if ("$EntryNumber" -match '^[0-9]+$') { $numInt = [int]$EntryNumber; $numOk = ($numInt -ge 1) }
    if (-not $numOk) {
        $plan.Reason = "INVALID_ENTRY_NUMBER: '$EntryNumber' is not a positive integer"
        return [pscustomobject]$plan
    }
    $plan.EntryNumber = $numInt

    if (-not (Test-TemplateEntryName -Name $Name)) {
        $plan.Reason = "INVALID_NAME: '$Name' must match ^[A-Za-z][A-Za-z0-9]*`$"
        return [pscustomobject]$plan
    }

    if (-not (Test-Path -LiteralPath $TemplateRoot)) {
        $plan.Reason = "TEMPLATE_ROOT_NOT_FOUND: '$TemplateRoot'"
        return [pscustomobject]$plan
    }
    $labCorePath = Join-Path $TemplateRoot 'core\LabCore.mqh'
    if (-not (Test-Path -LiteralPath $labCorePath)) {
        $plan.Reason = "TEMPLATE_ROOT_NOT_FOUND: no core\LabCore.mqh under '$TemplateRoot'"
        return [pscustomobject]$plan
    }
    $plan.LabCorePath = $labCorePath
    $labCoreText = Get-Content -LiteralPath $labCorePath -Raw -Encoding UTF8

    if ($labCoreText -match "LAB_ENTRY_$($numInt)\b") {
        $plan.Reason = "ENTRY_NUMBER_COLLISION: LAB_ENTRY_$numInt already referenced in core\LabCore.mqh"
        return [pscustomobject]$plan
    }
    $bossCollision = Get-ChildItem -LiteralPath $TemplateRoot -Filter "Boss_${numInt}_*.mq5" -File -ErrorAction SilentlyContinue
    if ($bossCollision) {
        $plan.Reason = "ENTRY_NUMBER_COLLISION: $($bossCollision[0].Name) already exists"
        return [pscustomobject]$plan
    }

    $entryPath = Join-Path $TemplateRoot "core\entries\Entry_$Name.mqh"
    if (Test-Path -LiteralPath $entryPath) {
        $plan.Reason = "NAME_COLLISION: core\entries\Entry_$Name.mqh already exists"
        return [pscustomobject]$plan
    }
    $nameCollision = Get-ChildItem -LiteralPath $TemplateRoot -Filter "Boss_*_$Name.mq5" -File -ErrorAction SilentlyContinue
    if ($nameCollision) {
        $plan.Reason = "NAME_COLLISION: $($nameCollision[0].Name) already uses the name '$Name'"
        return [pscustomobject]$plan
    }

    $entrySelectAnchor = @($labCoreText -split "`n" | Where-Object { $_ -match '^\s*#ifndef\s+LAB_ENTRY_TAG\s*$' })
    if ($entrySelectAnchor.Count -ne 1) {
        $plan.Reason = "MISSING_ANCHOR: expected exactly one '#ifndef LAB_ENTRY_TAG' line in core\LabCore.mqh, found $($entrySelectAnchor.Count)"
        return [pscustomobject]$plan
    }
    $initAnchorPattern = [regex]::Escape('PrintFormat("[INIT] Boss_%s |')
    $initAnchor = @($labCoreText -split "`n" | Where-Object { $_ -match $initAnchorPattern })
    if ($initAnchor.Count -ne 1) {
        $plan.Reason = "MISSING_ANCHOR: expected exactly one OnInit PrintFormat anchor in core\LabCore.mqh, found $($initAnchor.Count)"
        return [pscustomobject]$plan
    }

    $plan.BossPath  = Join-Path $TemplateRoot "Boss_${numInt}_$Name.mq5"
    $plan.EntryPath = $entryPath

    $inputsPath = Join-Path $TemplateRoot 'core\Inputs.mqh'
    if (-not (Test-Path -LiteralPath $inputsPath)) {
        $plan.Reason = "TEMPLATE_ROOT_NOT_FOUND: no core\Inputs.mqh under '$TemplateRoot'"
        return [pscustomobject]$plan
    }
    $plan.InputsPath = $inputsPath
    $inputsText = Get-Content -LiteralPath $inputsPath -Raw -Encoding UTF8

    $anchors = Get-TemplateEntryInputsAnchors -InputsText $inputsText -EntryNumber $numInt
    if (-not $anchors.Valid) {
        $plan.Reason = $anchors.Reason
        return [pscustomobject]$plan
    }
    $plan.InputsAnchorLines = @(
        [pscustomobject]@{ Line = $anchors.FallbackDefineLineIndex + 1; Text = ($anchors.Lines[$anchors.FallbackDefineLineIndex]).Trim() }
        [pscustomobject]@{ Line = $anchors.StackRegionEndLineIndex + 1; Text = ($anchors.Lines[$anchors.StackRegionEndLineIndex]).Trim() }
    )

    $stackModeMembers = Get-TemplateEntryEnumMembers -InputsText $inputsText -EnumName 'ENUM_STACK_MODE'
    if ($null -eq $stackModeMembers) {
        $plan.Reason = "MISSING_ANCHOR: 'enum ENUM_STACK_MODE { ... };' not found in core\Inputs.mqh"
        return [pscustomobject]$plan
    }
    if ($stackModeMembers -notcontains $StackMode) {
        $plan.Reason = "INVALID_STACK_MODE: '$StackMode' is not a member of ENUM_STACK_MODE in core\Inputs.mqh (known: $($stackModeMembers -join ', '))"
        return [pscustomobject]$plan
    }

    $stackConfirmMembers = Get-TemplateEntryEnumMembers -InputsText $inputsText -EnumName 'ENUM_STACK_CONFIRM'
    if ($null -eq $stackConfirmMembers) {
        $plan.Reason = "MISSING_ANCHOR: 'enum ENUM_STACK_CONFIRM { ... };' not found in core\Inputs.mqh"
        return [pscustomobject]$plan
    }
    if ($stackConfirmMembers -notcontains $StackConfirm) {
        $plan.Reason = "INVALID_STACK_CONFIRM: '$StackConfirm' is not a member of ENUM_STACK_CONFIRM in core\Inputs.mqh (known: $($stackConfirmMembers -join ', '))"
        return [pscustomobject]$plan
    }

    $plan.Valid  = $true
    $plan.Reason = 'OK'
    return [pscustomobject]$plan
}

function New-TemplateEntryScaffold {
    param(
        [Parameter(Mandatory)]$EntryNumber,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$TemplateRoot,
        # MONEY/RISK-semantic, mandatory, no default -- see file header (B-F1) and
        # Get-TemplateEntryScaffoldPlan, which validates these against the real enum members.
        [Parameter(Mandatory)][string]$StackMode,
        [Parameter(Mandatory)][string]$StackConfirm,
        [string]$Description = '',
        # TEST-ONLY fault-injection seam. No production caller (scripts\new_template_entry.ps1)
        # ever passes this. When set, it is invoked with a publication checkpoint name
        # immediately before that checkpoint's write/swap; a hook that throws simulates a
        # mid-write I/O fault at exactly that point so rollback can be exercised
        # deterministically without touching real disk I/O. Checkpoints, in order:
        # 'BeforeBoss' -> 'AfterBoss' -> 'AfterEntry' -> 'BeforeLabCoreReplace' ->
        # 'AfterLabCoreReplace' -> 'BeforeInputsReplace' -> 'AfterInputsReplace'.
        [Parameter(DontShow)][scriptblock]$TestFaultHook = $null
    )
    $plan = Get-TemplateEntryScaffoldPlan -EntryNumber $EntryNumber -Name $Name -TemplateRoot $TemplateRoot -StackMode $StackMode -StackConfirm $StackConfirm
    if (-not $plan.Valid) {
        return [pscustomobject]@{ Applied = $false; Reason = $plan.Reason; Plan = $plan }
    }

    function Invoke-Checkpoint([string]$Point) {
        if ($TestFaultHook) { & $TestFaultHook $Point }
    }

    $n         = $plan.EntryNumber
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    $desc      = if ($Description) { $Description } else { 'TODO: describe the signal' }
    $nameUpper = $Name.ToUpperInvariant()

    # ---- render every target's final content up front; nothing below this point
    # ---- mutates a live target until the publish sequence begins. ----
    $bossContent = (@(
        '//+------------------------------------------------------------------+'
        ('//|                                       Boss_{0}_{1}.mq5' -f $n, $Name)
        ('//|   Boss Lab V2 chassis - Entry {0}: {1}' -f $n, $desc)
        '//|   Scaffolded by scripts/new_template_entry.ps1 -- NOT deploy-     |'
        ('//|   approved until Entry_{0}.mqh implements real signal logic.' -f $Name)
        '//+------------------------------------------------------------------+'
        '#property copyright "EA_LAB / Boss"'
        '#property version   "1.00"'
        ('#property description "Boss Lab V2 - {0} {1} (scaffolded, entry logic not yet implemented)"' -f $n, $Name)
        '#property strict'
        ''
        "#define LAB_ENTRY_$n"
        ('#define LAB_ENTRY_TAG "{0}_{1}"' -f $n, $Name)
        '#include "core/LabCore.mqh"'
        ''
    ) -join "`n")

    $entryContent = (@(
        '//+------------------------------------------------------------------+'
        ('//| Entry_{0}.mqh (V2) - {1}' -f $Name, $desc)
        '//| Scaffolded by scripts/new_template_entry.ps1.                     |'
        '//| direction: 0=NONE 1=BUY 2=SELL (see IEntry.mqh)                   |'
        '//+------------------------------------------------------------------+'
        "#ifndef BOSS_LAB_ENTRY_${nameUpper}_MQH"
        "#define BOSS_LAB_ENTRY_${nameUpper}_MQH"
        '#include "IEntry.mqh"'
        ''
        "void Entry_${Name}_Init()"
        '{'
        '   // TODO: one-time state setup for this entry, if any.'
        '}'
        ''
        'EntrySignal Entry_Evaluate()'
        '{'
        ('   // TODO: implement the {0} signal. Until then this entry never opens a position.' -f $Name)
        ('   return Entry_MakeNone("Entry_{0} not implemented yet");' -f $Name)
        '}'
        ''
        "#endif // BOSS_LAB_ENTRY_${nameUpper}_MQH"
        ''
    ) -join "`n")

    $labCoreOriginal = Get-Content -LiteralPath $plan.LabCorePath -Raw -Encoding UTF8
    $selectBlock = "#ifdef LAB_ENTRY_$n`n   #include ""entries/Entry_$Name.mqh""`n#endif`n"
    $labCoreNew = [regex]::Replace(
        $labCoreOriginal,
        '(?m)^[ \t]*#ifndef[ \t]+LAB_ENTRY_TAG[ \t]*$',
        { param($m) $selectBlock + $m.Value }
    )
    $initBlock = "#ifdef LAB_ENTRY_$n`n   Entry_${Name}_Init();`n#endif`n"
    $labCoreNew = [regex]::Replace(
        $labCoreNew,
        '(?m)^[ \t]*' + [regex]::Escape('PrintFormat("[INIT] Boss_%s |'),
        { param($m) $initBlock + $m.Value }
    )

    # ---- B-F1: core\Inputs.mqh's two mandatory touch points. Re-derive the anchors from the
    # ---- live file (not from $plan) so publish can never disagree with what validation saw. ----
    $inputsOriginal = Get-Content -LiteralPath $plan.InputsPath -Raw -Encoding UTF8
    $inputsAnchors  = Get-TemplateEntryInputsAnchors -InputsText $inputsOriginal -EntryNumber $n
    if (-not $inputsAnchors.Valid) {
        return [pscustomobject]@{ Applied = $false; Reason = "PUBLISH_FAILED: core\Inputs.mqh anchors changed between plan and apply: $($inputsAnchors.Reason)"; Plan = $plan }
    }
    $inputsLines = [System.Collections.Generic.List[string]]::new([string[]]$inputsAnchors.Lines)

    $stackBlock = [string[]]@(
        "#ifdef LAB_ENTRY_$n"
        '#ifndef LAB_CONST_StackMode'
        ('input ENUM_STACK_MODE    StackMode    = {0};   // [P50200] Stack Mode | with P80012' -f $StackMode)
        '#endif'
        '#ifdef LAB_CONST_StackMode'
        'const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;'
        '#endif'
        '#ifndef LAB_CONST_StackConfirm'
        ('input ENUM_STACK_CONFIRM StackConfirm = {0};   // [P50201] Stack Confirm | with P50240' -f $StackConfirm)
        '#endif'
        '#ifdef LAB_CONST_StackConfirm'
        'const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;'
        '#endif'
        '#endif'
    )
    # Insert strictly highest-index-first so earlier indices never shift out from under a
    # later (lower-index) insertion.
    $inputsLines.InsertRange($inputsAnchors.StackRegionEndLineIndex, $stackBlock)
    $fallbackEndifInsertAt = $inputsAnchors.FallbackDefineLineIndex + $inputsAnchors.FallbackChainCount + 1
    $inputsLines.Insert($fallbackEndifInsertAt, '#endif')
    $inputsLines.Insert($inputsAnchors.FallbackDefineLineIndex, "#ifndef LAB_ENTRY_$n")
    $inputsNew = [string]::Join("`n", $inputsLines)

    # ---- publish: Boss, then Entry, then LabCore -- same order as before, now
    # ---- rollback-safe. Boss/Entry are staged via a same-directory temp file
    # ---- and published with an atomic same-volume rename to a not-yet-existing
    # ---- path. LabCore.mqh (the only pre-existing target) is staged the same
    # ---- way and published with [IO.File]::Replace, which atomically swaps the
    # ---- temp file in while moving the original bytes to a backup file -- so a
    # ---- fault strictly before the Replace call never touches the real file,
    # ---- and a fault strictly after it can still restore the original bytes
    # ---- from that backup. Any real I/O exception hits the same catch as an
    # ---- injected one, so production faults roll back identically. ----
    $bossCreated   = $false
    $entryCreated  = $false
    $tempFiles     = New-Object System.Collections.Generic.List[string]
    $labCoreBackup = $null
    $inputsBackup  = $null

    try {
        Invoke-Checkpoint 'BeforeBoss'
        $bossTmp = "$($plan.BossPath).scaffoldtmp_$([guid]::NewGuid().ToString('N'))"
        $tempFiles.Add($bossTmp)
        [IO.File]::WriteAllText($bossTmp, $bossContent, $utf8NoBom)
        [IO.File]::Move($bossTmp, $plan.BossPath)
        $tempFiles.Remove($bossTmp) | Out-Null
        $bossCreated = $true

        Invoke-Checkpoint 'AfterBoss'
        $entryTmp = "$($plan.EntryPath).scaffoldtmp_$([guid]::NewGuid().ToString('N'))"
        $tempFiles.Add($entryTmp)
        [IO.File]::WriteAllText($entryTmp, $entryContent, $utf8NoBom)
        [IO.File]::Move($entryTmp, $plan.EntryPath)
        $tempFiles.Remove($entryTmp) | Out-Null
        $entryCreated = $true

        Invoke-Checkpoint 'AfterEntry'
        $labCoreTmp = "$($plan.LabCorePath).scaffoldtmp_$([guid]::NewGuid().ToString('N'))"
        $tempFiles.Add($labCoreTmp)
        [IO.File]::WriteAllText($labCoreTmp, $labCoreNew, $utf8NoBom)

        Invoke-Checkpoint 'BeforeLabCoreReplace'
        $labCoreBackup = "$($plan.LabCorePath).scaffoldbak_$([guid]::NewGuid().ToString('N'))"
        [IO.File]::Replace($labCoreTmp, $plan.LabCorePath, $labCoreBackup)
        $tempFiles.Remove($labCoreTmp) | Out-Null

        # NOTE: $labCoreBackup is deliberately NOT cleaned up here. Inputs.mqh still has to be
        # written and swapped in below, and cleaning the LabCore.mqh backup this early would mean
        # a fault during the Inputs.mqh half (WriteAllText, or the Replace itself) could no
        # longer roll LabCore.mqh back -- leaving it permanently patched for an entry number
        # whose Inputs.mqh half never landed (a real defect caught by this suite's
        # 'BeforeInputsReplace'/'AfterInputsReplace' fault-injection cases; both backups are
        # cleaned together, once, only after every file has landed).
        Invoke-Checkpoint 'AfterLabCoreReplace'

        $inputsTmp = "$($plan.InputsPath).scaffoldtmp_$([guid]::NewGuid().ToString('N'))"
        $tempFiles.Add($inputsTmp)
        [IO.File]::WriteAllText($inputsTmp, $inputsNew, $utf8NoBom)

        Invoke-Checkpoint 'BeforeInputsReplace'
        $inputsBackup = "$($plan.InputsPath).scaffoldbak_$([guid]::NewGuid().ToString('N'))"
        [IO.File]::Replace($inputsTmp, $plan.InputsPath, $inputsBackup)
        $tempFiles.Remove($inputsTmp) | Out-Null

        Invoke-Checkpoint 'AfterInputsReplace'
        Remove-Item -LiteralPath $labCoreBackup -Force -ErrorAction SilentlyContinue
        $labCoreBackup = $null
        Remove-Item -LiteralPath $inputsBackup -Force -ErrorAction SilentlyContinue
        $inputsBackup = $null

        return [pscustomobject]@{
            Applied           = $true
            Reason            = 'OK'
            Plan              = $plan
            FilesWritten      = @($plan.BossPath, $plan.EntryPath)
            FilesPatched      = @($plan.LabCorePath, $plan.InputsPath)
            InputsAnchorLines = $plan.InputsAnchorLines
        }
    }
    catch {
        $failureReason = "PUBLISH_FAILED: $($_.Exception.Message)"

        # Restore in reverse publish order: Inputs.mqh (last successful step), then
        # LabCore.mqh, then delete Entry/Boss. Each Replace-based restore only runs if that
        # step's atomic swap already happened (the backup file only exists once Replace()
        # has succeeded).
        if ($inputsBackup -and (Test-Path -LiteralPath $inputsBackup)) {
            try {
                $discardBackup = "$($plan.InputsPath).scaffoldbak_$([guid]::NewGuid().ToString('N'))"
                [IO.File]::Replace($inputsBackup, $plan.InputsPath, $discardBackup)
                Remove-Item -LiteralPath $discardBackup -Force -ErrorAction SilentlyContinue
            } catch {
                $failureReason += "; ROLLBACK_INPUTS_RESTORE_FAILED: $($_.Exception.Message)"
            }
        }

        if ($labCoreBackup -and (Test-Path -LiteralPath $labCoreBackup)) {
            try {
                # [IO.File]::Replace's 3-arg overload rejects a null/empty backup
                # path on this runtime ("The path is not of a legal form."), so a
                # real (throwaway) backup path is always supplied and removed right after.
                $discardBackup = "$($plan.LabCorePath).scaffoldbak_$([guid]::NewGuid().ToString('N'))"
                [IO.File]::Replace($labCoreBackup, $plan.LabCorePath, $discardBackup)
                Remove-Item -LiteralPath $discardBackup -Force -ErrorAction SilentlyContinue
            } catch {
                $failureReason += "; ROLLBACK_LABCORE_RESTORE_FAILED: $($_.Exception.Message)"
            }
        }

        if ($entryCreated -and (Test-Path -LiteralPath $plan.EntryPath)) {
            Remove-Item -LiteralPath $plan.EntryPath -Force -ErrorAction SilentlyContinue
        }
        if ($bossCreated -and (Test-Path -LiteralPath $plan.BossPath)) {
            Remove-Item -LiteralPath $plan.BossPath -Force -ErrorAction SilentlyContinue
        }
        foreach ($t in $tempFiles) {
            if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue }
        }

        return [pscustomobject]@{ Applied = $false; Reason = $failureReason; Plan = $plan }
    }
}
