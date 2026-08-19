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
        [string]$Description = '',
        # TEST-ONLY fault-injection seam. No production caller (scripts\new_template_entry.ps1)
        # ever passes this. When set, it is invoked with a publication checkpoint name
        # immediately before that checkpoint's write/swap; a hook that throws simulates a
        # mid-write I/O fault at exactly that point so rollback can be exercised
        # deterministically without touching real disk I/O. Checkpoints, in order:
        # 'BeforeBoss' -> 'AfterBoss' -> 'AfterEntry' -> 'BeforeLabCoreReplace' -> 'AfterLabCoreReplace'.
        [Parameter(DontShow)][scriptblock]$TestFaultHook = $null
    )
    $plan = Get-TemplateEntryScaffoldPlan -EntryNumber $EntryNumber -Name $Name -TemplateRoot $TemplateRoot
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

    $labCoreOriginal = Get-Content -LiteralPath $plan.LabCorePath -Raw
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

        Invoke-Checkpoint 'AfterLabCoreReplace'
        Remove-Item -LiteralPath $labCoreBackup -Force -ErrorAction SilentlyContinue
        $labCoreBackup = $null

        return [pscustomobject]@{
            Applied           = $true
            Reason            = 'OK'
            Plan              = $plan
            FilesWritten      = @($plan.BossPath, $plan.EntryPath)
            FilesPatched      = @($plan.LabCorePath)
            InputsAnchorLines = $plan.InputsAnchorLines
        }
    }
    catch {
        $failureReason = "PUBLISH_FAILED: $($_.Exception.Message)"

        # Restore LabCore.mqh byte-identical first, if the atomic swap already
        # happened (the backup file only exists once Replace() has succeeded).
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
