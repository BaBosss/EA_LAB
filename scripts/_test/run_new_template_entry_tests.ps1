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

    $inputs = @(
        '#ifndef LAB_ENTRY_18'
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
    $r = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Foo' -TemplateRoot $tmp -Description 'test signal'
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

    Check 'result reports the highest existing (18) Inputs.mqh anchors' (@($r.InputsAnchorLines).Count -eq 3 -and ($r.InputsAnchorLines | ForEach-Object { $_.Text -match 'LAB_ENTRY_18' }) -notcontains $false)

    # --- negative: entry-number collision (re-run same number) ---
    $before2 = Get-Content -LiteralPath (Join-Path $tmp 'core\LabCore.mqh') -Raw
    $dup = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Bar' -TemplateRoot $tmp
    Check 'duplicate entry number is refused' ((-not $dup.Applied) -and $dup.Reason.StartsWith('ENTRY_NUMBER_COLLISION')) $dup.Reason
    $after2 = Get-Content -LiteralPath (Join-Path $tmp 'core\LabCore.mqh') -Raw
    Check 'refused call does not mutate LabCore.mqh' ($after2 -eq $before2)

    # --- negative: name collision (different number, name already used) ---
    $nameDup = New-TemplateEntryScaffold -EntryNumber 20 -Name 'Foo' -TemplateRoot $tmp
    Check 'duplicate name is refused' ((-not $nameDup.Applied) -and $nameDup.Reason.StartsWith('NAME_COLLISION')) $nameDup.Reason

    # --- negative: invalid inputs ---
    $badNum1 = New-TemplateEntryScaffold -EntryNumber 0 -Name 'Baz' -TemplateRoot $tmp
    Check 'entry number 0 is refused' ((-not $badNum1.Applied) -and $badNum1.Reason.StartsWith('INVALID_ENTRY_NUMBER')) $badNum1.Reason

    $badNum2 = New-TemplateEntryScaffold -EntryNumber -3 -Name 'Baz' -TemplateRoot $tmp
    Check 'negative entry number is refused' ((-not $badNum2.Applied) -and $badNum2.Reason.StartsWith('INVALID_ENTRY_NUMBER')) $badNum2.Reason

    $badName1 = New-TemplateEntryScaffold -EntryNumber 21 -Name '9Bad' -TemplateRoot $tmp
    Check 'name starting with a digit is refused' ((-not $badName1.Applied) -and $badName1.Reason.StartsWith('INVALID_NAME')) $badName1.Reason

    $badName2 = New-TemplateEntryScaffold -EntryNumber 21 -Name 'Bad-Name' -TemplateRoot $tmp
    Check 'name with a hyphen is refused' ((-not $badName2.Applied) -and $badName2.Reason.StartsWith('INVALID_NAME')) $badName2.Reason

    # --- negative: unknown template root ---
    $badRoot = New-TemplateEntryScaffold -EntryNumber 21 -Name 'Qux' -TemplateRoot (Join-Path $tmp 'does_not_exist')
    Check 'missing template root is refused' ((-not $badRoot.Applied) -and $badRoot.Reason.StartsWith('TEMPLATE_ROOT_NOT_FOUND')) $badRoot.Reason

    # --- negative: missing LabCore.mqh anchor (no #ifndef LAB_ENTRY_TAG) ---
    $tmp2 = Join-Path ([IO.Path]::GetTempPath()) ('new_template_entry_noanchor_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path (Join-Path $tmp2 'core\entries') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $tmp2 'core\LabCore.mqh'), "#ifndef BOSS_LAB_CORE_MQH`n#define BOSS_LAB_CORE_MQH`nint OnInit() { return INIT_SUCCEEDED; }`n#endif`n", (New-Object Text.UTF8Encoding($false)))
    try {
        $noAnchor = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Foo' -TemplateRoot $tmp2
        Check 'missing LabCore.mqh anchor is refused, not guessed' ((-not $noAnchor.Applied) -and $noAnchor.Reason.StartsWith('MISSING_ANCHOR')) $noAnchor.Reason
    } finally {
        Remove-Item -LiteralPath $tmp2 -Recurse -Force -ErrorAction SilentlyContinue
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
        $ambiguous = New-TemplateEntryScaffold -EntryNumber 19 -Name 'Foo' -TemplateRoot $tmp3
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
