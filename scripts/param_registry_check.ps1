<#
param_registry_check.ps1 - guard against docs/PARAM_REGISTRY.csv drifting away from
ea_template/core/Inputs.mqh (ORDER-191 part b).

WHY THIS EXISTS
  The registry has drifted TWICE already, silently:
    - ORDER-164 (2026-07-23) shipped the registry 6 rows short of the real input
      list (the 6 *_BalPct additive inputs were missing entirely) - PARAM-SYNC-004
      (2026-07-24) had to append them by hand.
    - Between ORDER-164's pinned commit and 2026-07-24 the file grew by ~16 lines
      from unrelated edits, so ~174 of the 183 "Inputs.mqh:<N>" line-number
      citations in default_profile silently went stale (still valid identifiers,
      wrong line numbers) - ORDER-191 part (a) had to re-walk every row by hand
      to fix them.
  Both incidents were invisible to anyone reading the registry - it still looked
  complete and plausible. This script makes both classes of drift a hard,
  scriptable CI-style check instead of something a human has to notice.

WHAT IT CHECKS
  1. Every `input` identifier declared in Inputs.mqh has a matching row in
     PARAM_REGISTRY.csv (by name, with any "[LAB_ENTRY_nn]" build-suffix
     stripped) - and vice versa (every registry row's identifier still exists
     in Inputs.mqh).
  2. Every "Inputs.mqh:<N>" line-number reference inside a registry row's
     default_profile cell actually points at that identifier's real `input`
     declaration line in the CURRENT working-tree Inputs.mqh. For the six
     identifiers that are compile-time duplicated across #ifdef LAB_ENTRY_11..18
     blocks (StackMode / StackConfirm), the registry's "[LAB_ENTRY_nn]" suffix on
     the name is used to pick the correct one of the 8 declarations to check
     against.

EXIT CODE
  0 = clean (no missing identifiers either direction, no stale line numbers)
  1 = any discrepancy found (see the printed sections for detail)

USAGE
  powershell -File scripts\param_registry_check.ps1
#>

$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $PSScriptRoot
$inputsPath = Join-Path $repoRoot 'ea_template\core\Inputs.mqh'
$csvPath    = Join-Path $repoRoot 'docs\PARAM_REGISTRY.csv'

if (-not (Test-Path $inputsPath)) { throw "Not found: $inputsPath" }
if (-not (Test-Path $csvPath))    { throw "Not found: $csvPath" }

# ---------------------------------------------------------------------------
# 1. Parse ea_template/core/Inputs.mqh: every `input` declaration (not
#    `input group`), tracking #ifdef/#ifndef/#endif nesting so identifiers that
#    are compile-time duplicated across LAB_ENTRY_nn blocks (StackMode,
#    StackConfirm) can be told apart by which block they're declared in.
# ---------------------------------------------------------------------------
$inputsLines = Get-Content -LiteralPath $inputsPath

# Each entry: @{ Name=<identifier>; Line=<1-based line number>; Tag=<LAB_ENTRY_nn or $null> }
$codeInputs = New-Object System.Collections.Generic.List[object]

# Stack of tags pushed by every #ifdef/#ifndef, so #endif pops the right frame.
# A frame's tag is the LAB_ENTRY_nn name when the directive is `#ifdef LAB_ENTRY_nn`,
# otherwise $null (ifndef guards and unrelated ifdefs don't identify a build).
$tagStack = New-Object System.Collections.Generic.Stack[object]

function Get-CurrentLabEntryTag {
    foreach ($frame in $tagStack.ToArray()) {
        if ($null -ne $frame) { return $frame }
    }
    return $null
}

for ($i = 0; $i -lt $inputsLines.Count; $i++) {
    $line   = $inputsLines[$i]
    $lineNo = $i + 1

    if ($line -match '^\s*#ifdef\s+(\S+)') {
        $name = $Matches[1]
        if ($name -match '^LAB_ENTRY_\d+$') { $tagStack.Push($name) } else { $tagStack.Push($null) }
        continue
    }
    if ($line -match '^\s*#ifndef\s+(\S+)') {
        $tagStack.Push($null)   # ifndef guards never themselves identify a build
        continue
    }
    if ($line -match '^\s*#endif') {
        if ($tagStack.Count -gt 0) { [void]$tagStack.Pop() }
        continue
    }

    if ($line -match '^\s*input\s+(\S+)') {
        if ($Matches[1] -eq 'group') { continue }   # input group "..." - not a parameter
        $tokens = $line.Trim() -split '\s+'
        if ($tokens.Count -lt 3) { continue }
        $ident = $tokens[2]
        if ($ident -match '^([^=;]+)') { $ident = $Matches[1] }   # identifier before any '=' or ';'
        $codeInputs.Add([pscustomobject]@{
            Name = $ident
            Line = $lineNo
            Tag  = (Get-CurrentLabEntryTag)
        })
    }
}

if ($tagStack.Count -ne 0) {
    Write-Warning "Inputs.mqh #ifdef/#ifndef/#endif nesting did not balance while parsing (stack depth $($tagStack.Count) at EOF) - tag tracking past that point may be unreliable."
}

$codeByName = @{}
foreach ($e in $codeInputs) {
    if (-not $codeByName.ContainsKey($e.Name)) { $codeByName[$e.Name] = New-Object System.Collections.Generic.List[object] }
    $codeByName[$e.Name].Add($e)
}
$codeNameSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($k in $codeByName.Keys) { [void]$codeNameSet.Add($k) }

# ---------------------------------------------------------------------------
# 2. Parse docs/PARAM_REGISTRY.csv: skip leading "> ..." comment lines, take the
#    header, then every data row. All 12 columns are always double-quoted and
#    none of the traced text in this file contains an escaped/embedded quote,
#    so a simple "all-quoted-fields-in-order" extraction is safe here (this is
#    NOT a general-purpose CSV parser).
# ---------------------------------------------------------------------------
$csvLines = Get-Content -LiteralPath $csvPath
$dataLines = $csvLines | Where-Object { $_.Length -gt 0 -and $_[0] -ne '>' -and $_ -ne 'name,owner,unit,context,active_when,coupled_parameters,default_profile,optimize_stage,safe_range,causal_question,classification,classification_note' }

# csvRows: one per data row (name, baseName, tag, defaultProfileCell)
$csvRows = New-Object System.Collections.Generic.List[object]
foreach ($line in $dataLines) {
    if ($line[0] -ne '"') { continue }   # defensive: only quoted data rows
    $fieldMatches = [regex]::Matches($line, '"([^"]*)"')
    if ($fieldMatches.Count -lt 7) {
        Write-Warning "Could not parse expected columns out of CSV row: $line"
        continue
    }
    $name = $fieldMatches[0].Groups[1].Value
    $defaultProfile = $fieldMatches[6].Groups[1].Value

    $baseName = $name
    $tag = $null
    if ($name -match '^(.*)\[(.+)\]$') {
        $baseName = $Matches[1]
        $tag = $Matches[2]
    }
    $csvRows.Add([pscustomobject]@{
        Name = $name
        BaseName = $baseName
        Tag = $tag
        DefaultProfile = $defaultProfile
    })
}

$csvNameSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($r in $csvRows) { [void]$csvNameSet.Add($r.BaseName) }

# ---------------------------------------------------------------------------
# 3. Direction A: identifiers in Inputs.mqh missing from the registry.
#    Direction B: identifiers in the registry missing from Inputs.mqh.
# ---------------------------------------------------------------------------
$missingFromCsv = $codeNameSet | Where-Object { -not $csvNameSet.Contains($_) } | Sort-Object
$missingFromCode = $csvNameSet | Where-Object { -not $codeNameSet.Contains($_) } | Sort-Object

# ---------------------------------------------------------------------------
# 4. Line-number verification: every "Inputs.mqh:<N>" reference in a row's
#    default_profile cell must point at that identifier's real declaration line.
# ---------------------------------------------------------------------------
$lineMismatches = New-Object System.Collections.Generic.List[object]
$unresolvedTagRows = New-Object System.Collections.Generic.List[object]

foreach ($row in $csvRows) {
    $m = [regex]::Match($row.DefaultProfile, 'Inputs\.mqh:(\d+)')
    if (-not $m.Success) { continue }   # row cites no line number (e.g. _0_Magic) - nothing to verify
    $expected = [int]$m.Groups[1].Value

    if (-not $codeByName.ContainsKey($row.BaseName)) { continue }   # already reported as missingFromCode
    $candidates = $codeByName[$row.BaseName]

    $actualEntry = $null
    if ($candidates.Count -eq 1) {
        $actualEntry = $candidates[0]
    } elseif ($row.Tag) {
        $actualEntry = $candidates | Where-Object { $_.Tag -eq $row.Tag } | Select-Object -First 1
        if (-not $actualEntry) {
            $unresolvedTagRows.Add([pscustomobject]@{ Name = $row.Name; Tag = $row.Tag })
            continue
        }
    } else {
        # multiple declarations exist but the registry row carries no [tag] to disambiguate
        $unresolvedTagRows.Add([pscustomobject]@{ Name = $row.Name; Tag = '(none - ambiguous)' })
        continue
    }

    if ($actualEntry.Line -ne $expected) {
        $lineMismatches.Add([pscustomobject]@{
            Name = $row.Name
            CitedLine = $expected
            ActualLine = $actualEntry.Line
        })
    }
}

# ---------------------------------------------------------------------------
# 5. Report
# ---------------------------------------------------------------------------
Write-Host "=== param_registry_check.ps1 ==="
Write-Host "Inputs.mqh identifiers found : $($codeNameSet.Count)"
Write-Host "Registry rows found         : $($csvRows.Count) (unique identifiers: $($csvNameSet.Count))"
Write-Host ""

$hasError = $false

if ($missingFromCsv.Count -gt 0) {
    $hasError = $true
    Write-Host "MISSING FROM REGISTRY (declared in Inputs.mqh, no CSV row):" -ForegroundColor Red
    foreach ($n in $missingFromCsv) { Write-Host "  - $n" }
    Write-Host ""
} else {
    Write-Host "OK: every Inputs.mqh identifier has a registry row." -ForegroundColor Green
}

if ($missingFromCode.Count -gt 0) {
    $hasError = $true
    Write-Host "MISSING FROM Inputs.mqh (registry row, no matching declaration):" -ForegroundColor Red
    foreach ($n in $missingFromCode) { Write-Host "  - $n" }
    Write-Host ""
} else {
    Write-Host "OK: every registry identifier exists in Inputs.mqh." -ForegroundColor Green
}

if ($unresolvedTagRows.Count -gt 0) {
    $hasError = $true
    Write-Host "AMBIGUOUS / UNRESOLVED [tag] (duplicated identifier, registry tag didn't match any #ifdef block):" -ForegroundColor Red
    foreach ($u in $unresolvedTagRows) { Write-Host "  - $($u.Name)  (tag: $($u.Tag))" }
    Write-Host ""
}

if ($lineMismatches.Count -gt 0) {
    $hasError = $true
    Write-Host "STALE LINE NUMBERS (Inputs.mqh:<N> in the registry no longer matches the real declaration line):" -ForegroundColor Red
    foreach ($mm in $lineMismatches) {
        Write-Host ("  - {0,-32} cited Inputs.mqh:{1,-5} actual Inputs.mqh:{2}" -f $mm.Name, $mm.CitedLine, $mm.ActualLine)
    }
    Write-Host ""
} else {
    Write-Host "OK: every Inputs.mqh:<N> line-number reference in the registry matches the current file." -ForegroundColor Green
}

Write-Host ""
if ($hasError) {
    Write-Host "RESULT: DISCREPANCIES FOUND - see above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "RESULT: CLEAN - PARAM_REGISTRY.csv is in sync with Inputs.mqh." -ForegroundColor Green
    exit 0
}
