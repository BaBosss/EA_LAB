<#
Cage for scripts/lib/new_template_entry.ps1 (the LAB_ENTRY_<N> scaffold generator).

Runs entirely against a temp fixture template root -- never touches the real ea_template/ --
so it exercises the happy path plus every refusal reason without any risk to a real Boss EA.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $RepoRoot 'scripts\lib\new_template_entry.ps1')

$pass = 0
$fail = 0
function Check([string]$name, [bool]$condition, [string]$detail = '') {
    if ($condition) { $script:pass++; Write-Host "[PASS] $name" }
    else { $script:fail++; Write-Host "[FAIL] $name :: $detail" -ForegroundColor Red }
}

function New-FixtureTemplateRoot([string]$Root) {
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    New-Item -ItemType Directory -Path (Join-Path $Root 'core\entries') -Force | Out-Null

    $labCore = @(
        '#ifndef BOSS_LAB_CORE_MQH'
        '#define BOSS_LAB_CORE_MQH'
        '#include "Inputs.mqh"'
        '// marker-before-select'
        '#ifdef LAB_ENTRY_18'
        '   #include "entries/Entry_JumStoch.mqh"'
        '#endif'
        '#ifndef LAB_ENTRY_TAG'
        '   #define LAB_ENTRY_TAG "??"'
        '#endif'
        '// marker-after-select'
        'int OnInit()'
        '{'
        '#ifdef LAB_ENTRY_18'
        '   Entry_JumStoch_Init();'
        '#endif'
        '   PrintFormat("[INIT] Boss_%s | exit=%d", LAB_ENTRY_TAG, ExitMode);'
        '   return INIT_SUCCEEDED;'
        '}'
        '#endif'
        ''
    ) -join "`n"
    [IO.File]::WriteAllText((Join-Path $Root 'core\LabCore.mqh'), $labCore, $utf8NoBom)

    # Mirrors the REAL core\Inputs.mqh shape (B-F1 fixture), scaled to one existing entry (18)
    # instead of eight: a top fallback #ifndef chain, then a StackMode/StackConfirm guard-pair
    # block per entry, then the region-end anchor Get-TemplateEntryInputsAnchors looks for.
    $inputs = @(
        '#ifndef LAB_ENTRY_18'
        '#define LAB_ENTRY_11          // fallback build'
        '#endif'
        ''
        'enum ENUM_STACK_MODE'
        '{'
        '   STACK_SINGLE       = 90,'
        '   STACK_GRID_TREND   = 91,'
        '   STACK_GRID_AGAINST = 92,'
        '   STACK_PYRAMID      = 93'
        '};'
        ''
        'enum ENUM_STACK_CONFIRM'
        '{'
        '   CONF_DISTANCE   = 0,'
        '   CONF_SIG_VALID  = 1'
        '};'
        ''
        '#ifdef LAB_ENTRY_18'
        '#ifndef LAB_CONST_StackMode'
        'input ENUM_STACK_MODE    StackMode    = STACK_GRID_AGAINST;   // [P50200] Stack Mode | with P80012'
        '#endif'
        '#ifdef LAB_CONST_StackMode'
        'const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;'
        '#endif'
        '#ifndef LAB_CONST_StackConfirm'
        'input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;   // [P50201] Stack Confirm | with P50240'
        '#endif'
        '#ifdef LAB_CONST_StackConfirm'
        'const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;'
        '#endif'
        '#endif'
        '#ifndef LAB_CONST__9_StepUseATR'
        'input bool _9_StepUseATR = true;'
        '#endif'
        '#ifdef LAB_ENTRY_18'
        'input int _18_Foo = 1;'
        '#endif'
        '#ifdef LAB_ENTRY_18'
        'input int _18_Bar = 2;'
        '#endif'
        ''
    ) -join "`n"
    [IO.File]::WriteAllText((Join-Path $Root 'core\Inputs.mqh'), $inputs, $utf8NoBom)

    [IO.File]::WriteAllText((Join-Path $Root 'Boss_18_JumStoch.mq5'), "#define LAB_ENTRY_18`n#include ""core/LabCore.mqh""`n", $utf8NoBom)
    [IO.File]::WriteAllText((Join-Path $Root 'core\entries\Entry_JumStoch.mqh'), "EntrySignal Entry_Evaluate() { return Entry_MakeNone(""x""); }`n", $utf8NoBom)
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('new_template_entry_' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    New-FixtureTemplateRoot -Root $tmp

    # --- happy path ---
    $before = Get-Content -LiteralPath (Join-Path $tmp 'core\LabCore.mqh') -Raw
    $r = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Foo' -TemplateRoot $tmp -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE' -Description 'test signal'
    Check 'happy path applies' $r.Applied ($r | ConvertTo-Json -Depth 5)
    Check 'happy path writes Boss wrapper' (Test-Path -LiteralPath (Join-Path $tmp 'Boss_19_Foo.mq5'))
    Check 'happy path writes entry skeleton' (Test-Path -LiteralPath (Join-Path $tmp 'core\entries\Entry_Foo.mqh'))

    $bossText = Get-Content -LiteralPath (Join-Path $tmp 'Boss_19_Foo.mq5') -Raw
    Check 'Boss wrapper defines LAB_ENTRY_19' ($bossText.Contains('#define LAB_ENTRY_19') -and $bossText.Contains('LAB_ENTRY_TAG "19_Foo"') -and $bossText.Contains('#include "core/LabCore.mqh"'))

    $entryText = Get-Content -LiteralPath (Join-Path $tmp 'core\entries\Entry_Foo.mqh') -Raw
    Check 'entry skeleton declares Entry_Evaluate and Entry_Foo_Init' ($entryText.Contains('EntrySignal Entry_Evaluate()') -and $entryText.Contains('void Entry_Foo_Init()') -and $entryText.Contains('Entry_MakeNone("Entry_Foo not implemented yet")'))

    $labCoreAfter = Get-Content -LiteralPath (Join-Path $tmp 'core\LabCore.mqh') -Raw
    Check 'LabCore.mqh gains exactly one select-block include for entry 19' (([regex]::Matches($labCoreAfter, [regex]::Escape('#include "entries/Entry_Foo.mqh"'))).Count -eq 1)
    Check 'LabCore.mqh gains exactly one Init call for entry 19' (([regex]::Matches($labCoreAfter, [regex]::Escape('Entry_Foo_Init();'))).Count -eq 1)
    Check 'LabCore.mqh preserves the pre-existing entry 18 wiring' ($labCoreAfter.Contains('#include "entries/Entry_JumStoch.mqh"') -and $labCoreAfter.Contains('Entry_JumStoch_Init();'))
    Check 'LabCore.mqh preserves surrounding markers untouched' ($labCoreAfter.Contains('// marker-before-select') -and $labCoreAfter.Contains('// marker-after-select'))

    Check 'result reports the two core\Inputs.mqh touch points actually patched' (@($r.InputsAnchorLines).Count -eq 2 -and $r.InputsAnchorLines[0].Text -match 'fallback build' -and $r.InputsAnchorLines[1].Text -match 'LAB_CONST__9_StepUseATR')

    # --- B-F1: core\Inputs.mqh itself must now be genuinely patched, not just reported ---
    $inputsAfter = Get-Content -LiteralPath (Join-Path $tmp 'core\Inputs.mqh') -Raw
    Check 'Inputs.mqh fallback chain gains #ifndef LAB_ENTRY_19' (([regex]::Matches($inputsAfter, [regex]::Escape('#ifndef LAB_ENTRY_19'))).Count -eq 1)
    Check 'Inputs.mqh gains a StackMode/StackConfirm block for entry 19' ($inputsAfter -match '(?s)#ifdef LAB_ENTRY_19.*?input ENUM_STACK_MODE\s+StackMode\s+= STACK_SINGLE;.*?input ENUM_STACK_CONFIRM StackConfirm\s+= CONF_DISTANCE;.*?#endif')
    Check 'Inputs.mqh preserves the pre-existing entry 18 StackMode block' ($inputsAfter.Contains('StackMode    = STACK_GRID_AGAINST'))
    Check 'Inputs.mqh fallback #ifndef/#endif chain stays balanced (9 ifndef, 9 endif around the fallback #define)' ((([regex]::Matches($inputsAfter, '(?m)^#ifndef LAB_ENTRY_\d+\s*$')).Count -eq 2) -and (([regex]::Matches($inputsAfter, '(?m)^#endif\s*$')).Count -ge 2))

    # --- negative: unknown StackMode / StackConfirm member is refused, not guessed ---
    $badStackMode = New-TemplateEntryScaffold -EntryNumber 22 -Name 'Qux2' -TemplateRoot $tmp -StackMode 'STACK_NOT_REAL' -StackConfirm 'CONF_DISTANCE'
    Check 'unknown StackMode enum member is refused' ((-not $badStackMode.Applied) -and $badStackMode.Reason.StartsWith('INVALID_STACK_MODE')) $badStackMode.Reason
    $badStackConfirm = New-TemplateEntryScaffold -EntryNumber 22 -Name 'Qux2' -TemplateRoot $tmp -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_NOT_REAL'
    Check 'unknown StackConfirm enum member is refused' ((-not $badStackConfirm.Applied) -and $badStackConfirm.Reason.StartsWith('INVALID_STACK_CONFIRM')) $badStackConfirm.Reason
    Check 'refused StackMode/StackConfirm calls do not create the Boss file' (-not (Test-Path -LiteralPath (Join-Path $tmp 'Boss_22_Qux2.mq5')))

    # --- negative: entry number already known to Inputs.mqh's fallback chain (but not to
    # --- LabCore.mqh) is refused via Inputs.mqh, not silently accepted ---
    $inputsCollisionRoot = Join-Path ([IO.Path]::GetTempPath()) ('new_template_entry_inputs_collision_' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path (Join-Path $inputsCollisionRoot 'core\entries') -Force | Out-Null
        New-FixtureTemplateRoot -Root $inputsCollisionRoot
        $inputsPath = Join-Path $inputsCollisionRoot 'core\Inputs.mqh'
        $inputsText = (Get-Content -LiteralPath $inputsPath -Raw) -replace [regex]::Escape('#ifdef LAB_ENTRY_18'), '#ifdef LAB_ENTRY_23'
        [IO.File]::WriteAllText($inputsPath, $inputsText, (New-Object Text.UTF8Encoding($false)))
        $inputsCollision = New-TemplateEntryScaffold -EntryNumber 23 -Name 'Collide' -TemplateRoot $inputsCollisionRoot -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
        Check 'entry number already used only in Inputs.mqh is refused' ((-not $inputsCollision.Applied) -and $inputsCollision.Reason.StartsWith('ENTRY_NUMBER_COLLISION')) $inputsCollision.Reason
    } finally {
        Remove-Item -LiteralPath $inputsCollisionRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --- negative: Inputs.mqh fallback chain shape has drifted (ifndef/endif count mismatch) ---
    $shapeDriftRoot = Join-Path ([IO.Path]::GetTempPath()) ('new_template_entry_shape_drift_' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path (Join-Path $shapeDriftRoot 'core\entries') -Force | Out-Null
        New-FixtureTemplateRoot -Root $shapeDriftRoot
        $inputsPath = Join-Path $shapeDriftRoot 'core\Inputs.mqh'
        $inputsText = (Get-Content -LiteralPath $inputsPath -Raw) -replace [regex]::Escape("#define LAB_ENTRY_11          // fallback build`n#endif"), '#define LAB_ENTRY_11          // fallback build'
        [IO.File]::WriteAllText($inputsPath, $inputsText, (New-Object Text.UTF8Encoding($false)))
        $shapeDrift = New-TemplateEntryScaffold -EntryNumber 24 -Name 'Drift' -TemplateRoot $shapeDriftRoot -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
        Check 'unbalanced fallback ifndef/endif chain is refused, not guessed' ((-not $shapeDrift.Applied) -and $shapeDrift.Reason.StartsWith('MISSING_ANCHOR')) $shapeDrift.Reason
    } finally {
        Remove-Item -LiteralPath $shapeDriftRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --- negative: entry-number collision (re-run same number) ---
    $before2 = Get-Content -LiteralPath (Join-Path $tmp 'core\LabCore.mqh') -Raw
    $dup = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Bar' -TemplateRoot $tmp -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
    Check 'duplicate entry number is refused' ((-not $dup.Applied) -and $dup.Reason.StartsWith('ENTRY_NUMBER_COLLISION')) $dup.Reason
    $after2 = Get-Content -LiteralPath (Join-Path $tmp 'core\LabCore.mqh') -Raw
    Check 'refused call does not mutate LabCore.mqh' ($after2 -eq $before2)

    # --- negative: name collision (different number, name already used) ---
    $nameDup = New-TemplateEntryScaffold -EntryNumber 20 -Name 'Foo' -TemplateRoot $tmp -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
    Check 'duplicate name is refused' ((-not $nameDup.Applied) -and $nameDup.Reason.StartsWith('NAME_COLLISION')) $nameDup.Reason

    # --- negative: invalid inputs ---
    $badNum1 = New-TemplateEntryScaffold -EntryNumber 0 -Name 'Baz' -TemplateRoot $tmp -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
    Check 'entry number 0 is refused' ((-not $badNum1.Applied) -and $badNum1.Reason.StartsWith('INVALID_ENTRY_NUMBER')) $badNum1.Reason

    $badNum2 = New-TemplateEntryScaffold -EntryNumber -3 -Name 'Baz' -TemplateRoot $tmp -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
    Check 'negative entry number is refused' ((-not $badNum2.Applied) -and $badNum2.Reason.StartsWith('INVALID_ENTRY_NUMBER')) $badNum2.Reason

    $badName1 = New-TemplateEntryScaffold -EntryNumber 21 -Name '9Bad' -TemplateRoot $tmp -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
    Check 'name starting with a digit is refused' ((-not $badName1.Applied) -and $badName1.Reason.StartsWith('INVALID_NAME')) $badName1.Reason

    $badName2 = New-TemplateEntryScaffold -EntryNumber 21 -Name 'Bad-Name' -TemplateRoot $tmp -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
    Check 'name with a hyphen is refused' ((-not $badName2.Applied) -and $badName2.Reason.StartsWith('INVALID_NAME')) $badName2.Reason

    # --- negative: unknown template root ---
    $badRoot = New-TemplateEntryScaffold -EntryNumber 21 -Name 'Qux' -TemplateRoot (Join-Path $tmp 'does_not_exist') -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
    Check 'missing template root is refused' ((-not $badRoot.Applied) -and $badRoot.Reason.StartsWith('TEMPLATE_ROOT_NOT_FOUND')) $badRoot.Reason

    # --- negative: missing LabCore.mqh anchor (no #ifndef LAB_ENTRY_TAG) ---
    $tmp2 = Join-Path ([IO.Path]::GetTempPath()) ('new_template_entry_noanchor_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $tmp2 'core\entries') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $tmp2 'core\LabCore.mqh'), "#ifndef BOSS_LAB_CORE_MQH`n#define BOSS_LAB_CORE_MQH`nint OnInit() { return INIT_SUCCEEDED; }`n#endif`n", (New-Object Text.UTF8Encoding($false)))
    try {
        $noAnchor = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Foo' -TemplateRoot $tmp2 -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
        Check 'missing LabCore.mqh anchor is refused, not guessed' ((-not $noAnchor.Applied) -and $noAnchor.Reason.StartsWith('MISSING_ANCHOR')) $noAnchor.Reason
    } finally {
        Remove-Item -LiteralPath $tmp2 -Recurse -Force -ErrorAction SilentlyContinue
    }

    # =====================================================================
    # Transaction-safety: fault-injection rollback tests.
    #
    # New-TemplateEntryScaffold takes a TEST-ONLY -TestFaultHook scriptblock.
    # It is invoked with a checkpoint-name string immediately before that
    # checkpoint's publication step; a hook that throws simulates a mid-write
    # I/O fault at exactly that point without touching real disk I/O. No
    # production caller (scripts\new_template_entry.ps1) ever passes it, so
    # default (unset) behavior is unaffected.
    # =====================================================================
    function New-ThrowingFaultHook([string]$TripPoint) {
        return { param($Point) if ($Point -eq $TripPoint) { throw "INJECTED_TEST_FAULT_AT_$Point" } }.GetNewClosure()
    }

    function Get-ScaffoldTempResidue([string]$Root) {
        return @(Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '\.scaffoldtmp_|\.scaffoldbak_' })
    }

    function Invoke-ScaffoldFaultTest([string]$TripPoint) {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('new_template_entry_fault_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        New-FixtureTemplateRoot -Root $root
        $before = Get-Content -LiteralPath (Join-Path $root 'core\LabCore.mqh') -Raw
        $beforeInputs = Get-Content -LiteralPath (Join-Path $root 'core\Inputs.mqh') -Raw
        $result = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Fault' -TemplateRoot $root -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE' -TestFaultHook (New-ThrowingFaultHook $TripPoint)
        return [pscustomobject]@{ Root = $root; Before = $before; BeforeInputs = $beforeInputs; Result = $result }
    }

    function Assert-FullRollback([string]$TripPoint) {
        $ctx = Invoke-ScaffoldFaultTest $TripPoint
        try {
            Check "fault at $TripPoint is reported as not applied" (-not $ctx.Result.Applied) ($ctx.Result | ConvertTo-Json -Depth 5)
            Check "fault at $TripPoint returns an explicit failure reason" ([string]::IsNullOrEmpty($ctx.Result.Reason) -eq $false -and $ctx.Result.Reason -ne 'OK') $ctx.Result.Reason
            Check "fault at $TripPoint leaves zero Boss file" (-not (Test-Path -LiteralPath (Join-Path $ctx.Root 'Boss_19_Fault.mq5')))
            Check "fault at $TripPoint leaves zero Entry file" (-not (Test-Path -LiteralPath (Join-Path $ctx.Root 'core\entries\Entry_Fault.mqh')))
            $after = Get-Content -LiteralPath (Join-Path $ctx.Root 'core\LabCore.mqh') -Raw
            Check "fault at $TripPoint restores LabCore.mqh byte-identical" ($after -ceq $ctx.Before)
            $afterInputs = Get-Content -LiteralPath (Join-Path $ctx.Root 'core\Inputs.mqh') -Raw
            Check "fault at $TripPoint restores Inputs.mqh byte-identical" ($afterInputs -ceq $ctx.BeforeInputs)
            $residue = Get-ScaffoldTempResidue $ctx.Root
            Check "fault at $TripPoint leaves zero temp/backup files" ($residue.Count -eq 0) (($residue | ForEach-Object { $_.FullName }) -join '; ')
        } finally {
            Remove-Item -LiteralPath $ctx.Root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Assert-FullRollback 'BeforeBoss'
    Assert-FullRollback 'AfterBoss'
    Assert-FullRollback 'AfterEntry'
    Assert-FullRollback 'BeforeLabCoreReplace'
    Assert-FullRollback 'AfterLabCoreReplace'
    Assert-FullRollback 'BeforeInputsReplace'
    Assert-FullRollback 'AfterInputsReplace'

    # --- sanity: a hook present but never tripped must not change the happy path ---
    $hookedRoot = Join-Path ([IO.Path]::GetTempPath()) ('new_template_entry_hooked_' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $hookedRoot -Force | Out-Null
        New-FixtureTemplateRoot -Root $hookedRoot
        $hookedResult = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Hooked' -TemplateRoot $hookedRoot -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE' -TestFaultHook (New-ThrowingFaultHook 'NeverMatchedPoint')
        Check 'successful publication is unaffected by a hook that never trips' $hookedResult.Applied ($hookedResult | ConvertTo-Json -Depth 5)
        Check 'successful publication writes Boss file with hook present' (Test-Path -LiteralPath (Join-Path $hookedRoot 'Boss_19_Hooked.mq5'))
        Check 'successful publication writes Entry file with hook present' (Test-Path -LiteralPath (Join-Path $hookedRoot 'core\entries\Entry_Hooked.mqh'))
        $hookedResidue = Get-ScaffoldTempResidue $hookedRoot
        Check 'successful publication leaves zero temp/backup files' ($hookedResidue.Count -eq 0) (($hookedResidue | ForEach-Object { $_.FullName }) -join '; ')
    } finally {
        Remove-Item -LiteralPath $hookedRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --- negative: ambiguous LabCore.mqh anchor (two OnInit PrintFormat lines) ---
    $tmp3 = Join-Path ([IO.Path]::GetTempPath()) ('new_template_entry_ambiguous_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $tmp3 'core\entries') -Force | Out-Null
    $ambiguousCore = @(
        '#ifndef LAB_ENTRY_TAG'
        '#endif'
        'PrintFormat("[INIT] Boss_%s | one", LAB_ENTRY_TAG);'
        'PrintFormat("[INIT] Boss_%s | two", LAB_ENTRY_TAG);'
        ''
    ) -join "`n"
    [IO.File]::WriteAllText((Join-Path $tmp3 'core\LabCore.mqh'), $ambiguousCore, (New-Object Text.UTF8Encoding($false)))
    try {
        $ambiguous = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Foo' -TemplateRoot $tmp3 -StackMode 'STACK_SINGLE' -StackConfirm 'CONF_DISTANCE'
        Check 'ambiguous OnInit anchor is refused, not guessed' ((-not $ambiguous.Applied) -and $ambiguous.Reason.StartsWith('MISSING_ANCHOR')) $ambiguous.Reason
    } finally {
        Remove-Item -LiteralPath $tmp3 -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "[new-template-entry] $pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }
exit 0
