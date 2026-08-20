<#
Cage for Test-TemplateEntryWrapperRegistered (B-F2, Audit B): the wrapper -> registry direction
check. Confirms it fires closed for an unregistered LAB_ENTRY_<N> and stays silent (Ok=$true) for
a registered one, plus the surrounding refusal paths (no token in the wrapper, missing files).
Runs entirely against temp fixtures -- never touches the real ea_template/.
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

$utf8NoBom = New-Object Text.UTF8Encoding($false)
$root = Join-Path ([IO.Path]::GetTempPath()) ('wrapper_registration_' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null

    # Inputs.mqh registers only LAB_ENTRY_18 (fallback chain of one), plus the stack-region-end
    # anchor Get-TemplateEntryInputsAnchors also validates -- reused unchanged from the B-F1
    # scaffold-insertion check, so a real Inputs.mqh whose SHAPE this scaffold no longer
    # understands correctly fails this registration check closed too, rather than guessing.
    $inputs = @(
        '#ifndef LAB_ENTRY_18'
        '#define LAB_ENTRY_11          // fallback build'
        '#endif'
        '#ifndef LAB_CONST__9_StepUseATR'
        'input bool _9_StepUseATR = true;'
        '#endif'
        ''
    ) -join "`n"
    $inputsPath = Join-Path $root 'Inputs.mqh'
    [IO.File]::WriteAllText($inputsPath, $inputs, $utf8NoBom)

    # --- control: a wrapper for the REGISTERED tag must pass (Ok=$true), not just "not refused" ---
    $registeredWrapper = Join-Path $root 'Boss_18_Registered.mq5'
    [IO.File]::WriteAllText($registeredWrapper, "#define LAB_ENTRY_18`n#include ""core/LabCore.mqh""`n", $utf8NoBom)
    $okResult = Test-TemplateEntryWrapperRegistered -WrapperPath $registeredWrapper -InputsPath $inputsPath
    Check 'registered wrapper (LAB_ENTRY_18) passes' ($okResult.Ok -and $okResult.EntryNumber -eq 18) ($okResult | ConvertTo-Json)

    # --- attack: an unregistered tag must fire, not fall through silently ---
    $unregisteredWrapper = Join-Path $root 'Boss_50_Unregistered.mq5'
    [IO.File]::WriteAllText($unregisteredWrapper, "#define LAB_ENTRY_50`n#include ""core/LabCore.mqh""`n", $utf8NoBom)
    $badResult = Test-TemplateEntryWrapperRegistered -WrapperPath $unregisteredWrapper -InputsPath $inputsPath
    Check 'unregistered wrapper (LAB_ENTRY_50) is refused' ((-not $badResult.Ok) -and $badResult.Reason.StartsWith('UNREGISTERED') -and $badResult.EntryNumber -eq 50) ($badResult | ConvertTo-Json)

    # --- a wrapper defining no LAB_ENTRY_* token at all is a distinct refusal, not a false pass ---
    $noTokenWrapper = Join-Path $root 'Boss_NoToken.mq5'
    [IO.File]::WriteAllText($noTokenWrapper, "#include ""core/LabCore.mqh""`n", $utf8NoBom)
    $noTokenResult = Test-TemplateEntryWrapperRegistered -WrapperPath $noTokenWrapper -InputsPath $inputsPath
    Check 'wrapper with no LAB_ENTRY_* token is refused, not silently passed' ((-not $noTokenResult.Ok) -and $noTokenResult.Reason.StartsWith('NO_LAB_ENTRY_TOKEN')) ($noTokenResult | ConvertTo-Json)

    # --- missing files fail closed, not silently ---
    $missingWrapperResult = Test-TemplateEntryWrapperRegistered -WrapperPath (Join-Path $root 'DoesNotExist.mq5') -InputsPath $inputsPath
    Check 'missing wrapper file is refused' ((-not $missingWrapperResult.Ok) -and $missingWrapperResult.Reason.StartsWith('WRAPPER_NOT_FOUND'))

    $missingInputsResult = Test-TemplateEntryWrapperRegistered -WrapperPath $registeredWrapper -InputsPath (Join-Path $root 'DoesNotExist.mqh')
    Check 'missing Inputs.mqh is refused' ((-not $missingInputsResult.Ok) -and $missingInputsResult.Reason.StartsWith('INPUTS_NOT_FOUND'))

    # --- fire-count sanity: registering the same-numbered tag flips the same wrapper from
    # --- refused to passed -- proves the check actually reads Inputs.mqh, not just the wrapper ---
    $fallbackBlock = "#ifndef LAB_ENTRY_18`n#define LAB_ENTRY_11          // fallback build`n#endif"
    $fallbackBlockWith50 = "#ifndef LAB_ENTRY_18`n#ifndef LAB_ENTRY_50`n#define LAB_ENTRY_11          // fallback build`n#endif`n#endif"
    $inputsWith50 = $inputs -replace [regex]::Escape($fallbackBlock), $fallbackBlockWith50
    [IO.File]::WriteAllText($inputsPath, $inputsWith50, $utf8NoBom)
    $nowRegistered = Test-TemplateEntryWrapperRegistered -WrapperPath $unregisteredWrapper -InputsPath $inputsPath
    Check 'the same wrapper flips to registered once Inputs.mqh actually knows the tag' ($nowRegistered.Ok) ($nowRegistered | ConvertTo-Json)
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "[wrapper-registration] $pass passed, $fail failed"
if ($fail -gt 0) { exit 1 }
exit 0
