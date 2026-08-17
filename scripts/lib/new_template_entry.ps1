# Scaffolding for a new LAB_ENTRY_<N> template plugin (Boss wrapper + entry skeleton + LabCore.mqh
# wiring). The mechanical part of ea_template's "add a new strategy" procedure (docs/
# EA_CORE_AND_TEMPLATE_GUIDE.md S3.4 steps 3-4) has no automation today, and a static per-entry
# list once silently omitted Boss_17_Wave5 from deploy.ps1 (ORDER-129) because nobody remembered
# every touch point by hand. This scaffold makes the two LabCore.mqh touch points mechanical and
# impossible to omit, and refuses instead of guessing when it cannot find them.
#
# core/Inputs.mqh is deliberately NOT auto-edited: its LAB_ENTRY_<n> sections are scattered across
# several non-contiguous blocks (general params, strategy params, late overrides), and its exact
# input names feed the generated fingerprint pipeline (InputSurface_gen.mqh / LockedConstants_gen.mqh
# via _triage/factory_os/gen_input_surface.py). Get-TemplateEntryScaffoldPlan reports every anchor
# line for the highest existing entry instead, so that manual step cannot silently miss one.

function Test-TemplateEntryName {
    param([Parameter(Mandatory)][string]$Name)
    return [bool]($Name -cmatch '^[A-Za-z][A-Za-z0-9]*$')
}

function Get-TemplateEntryScaffoldPlan {
    param(
        [Parameter(Mandatory)]$EntryNumber,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$TemplateRoot
    )
    $plan = [ordered]@{
        Valid             = $false
        Reason            = ''
        EntryNumber       = $EntryNumber
        Name              = $Name
        TemplateRoot      = $TemplateRoot
        BossPath          = $null
        EntryPath         = $null
        LabCorePath       = $null
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
    $labCoreText = Get-Content -LiteralPath $labCorePath -Raw

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
    if (Test-Path -LiteralPath $inputsPath) {
        $lines    = Get-Content -LiteralPath $inputsPath
        $maxEntry = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'LAB_ENTRY[_=]+(\d+)') {
                $n = [int]$Matches[1]
                if ($n -gt $maxEntry) { $maxEntry = $n }
            }
        }
        if ($maxEntry -gt 0) {
            $anchors = @()
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "LAB_ENTRY[_=]+$maxEntry\b") {
                    $anchors += [pscustomobject]@{ Line = $i + 1; Text = $lines[$i].Trim() }
                }
            }
            $plan.InputsAnchorLines = $anchors
        }
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
        [string]$Description = ''
    )
    $plan = Get-TemplateEntryScaffoldPlan -EntryNumber $EntryNumber -Name $Name -TemplateRoot $TemplateRoot
    if (-not $plan.Valid) {
        return [pscustomobject]@{ Applied = $false; Reason = $plan.Reason; Plan = $plan }
    }

    $n         = $plan.EntryNumber
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    $desc      = if ($Description) { $Description } else { 'TODO: describe the signal' }
    $nameUpper = $Name.ToUpperInvariant()

    $bossLines = @(
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
    )
    [IO.File]::WriteAllText($plan.BossPath, ($bossLines -join "`n"), $utf8NoBom)

    $entryLines = @(
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
    )
    [IO.File]::WriteAllText($plan.EntryPath, ($entryLines -join "`n"), $utf8NoBom)

    $labCoreText = Get-Content -LiteralPath $plan.LabCorePath -Raw
    $selectBlock = "#ifdef LAB_ENTRY_$n`n   #include ""entries/Entry_$Name.mqh""`n#endif`n"
    $labCoreText = [regex]::Replace(
        $labCoreText,
        '(?m)^[ \t]*#ifndef[ \t]+LAB_ENTRY_TAG[ \t]*$',
        { param($m) $selectBlock + $m.Value }
    )
    $initBlock = "#ifdef LAB_ENTRY_$n`n   Entry_${Name}_Init();`n#endif`n"
    $labCoreText = [regex]::Replace(
        $labCoreText,
        '(?m)^[ \t]*' + [regex]::Escape('PrintFormat("[INIT] Boss_%s |'),
        { param($m) $initBlock + $m.Value }
    )
    [IO.File]::WriteAllText($plan.LabCorePath, $labCoreText, $utf8NoBom)

    return [pscustomobject]@{
        Applied           = $true
        Reason            = 'OK'
        Plan              = $plan
        FilesWritten      = @($plan.BossPath, $plan.EntryPath)
        FilesPatched      = @($plan.LabCorePath)
        InputsAnchorLines = $plan.InputsAnchorLines
    }
}
