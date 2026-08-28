<#
param_registry_fix_lines.ps1 - refresh the "Inputs.mqh:<N>" citations in
docs/PARAM_REGISTRY.csv so they point at the current declaration lines.

WHY THIS EXISTS
  param_registry_check.ps1 DETECTS the drift; this REPAIRS it. The line numbers have
  now gone stale three separate times (ORDER-164 -> PARAM-SYNC-004 -> ORDER-191(a), and
  again the same day the moment ORDER-190 added one input near the top of the entry-16
  block). Each repair was previously a hand/agent pass over ~175 rows, which is both
  expensive and a chance to corrupt hand-traced cells. It is a mechanical transformation,
  so it should be a command.

  Adding or removing an input is still a human job: this script only fixes NUMBERS. If an
  identifier is missing from the registry entirely, it says so and changes nothing - write
  the row (owner / active_when / coupled_parameters are traced by reading code, never
  guessed) and then re-run.

WHAT IT TOUCHES
  Only the digits after "Inputs.mqh:" inside each row's default_profile cell. Every other
  character of every cell is preserved byte-for-byte.

USAGE
  powershell -File scripts\param_registry_fix_lines.ps1            # report what would change
  powershell -File scripts\param_registry_fix_lines.ps1 -Apply     # write the file
  powershell -File scripts\param_registry_check.ps1                # must then exit 0
#>
[CmdletBinding()]
param([switch]$Apply)
$ErrorActionPreference = 'Stop'

$repoRoot   = Split-Path -Parent $PSScriptRoot
$inputsPath = Join-Path $repoRoot 'ea_template\core\Inputs.mqh'
$csvPath    = Join-Path $repoRoot 'docs\PARAM_REGISTRY.csv'
$csvReader  = Join-Path $PSScriptRoot 'lib\param_registry_csv.ps1'
if (-not (Test-Path -LiteralPath $csvReader)) { throw "Not found: $csvReader" }
. $csvReader

# --- parse Inputs.mqh exactly the way param_registry_check.ps1 does, so the two agree by
# --- construction (same #ifdef nesting rules -> same LAB_ENTRY_nn disambiguation).
$inputsLines = Get-Content -LiteralPath $inputsPath
$codeInputs  = New-Object System.Collections.Generic.List[object]
$tagStack    = New-Object System.Collections.Generic.Stack[object]
function Get-CurrentLabEntryTag {
    foreach ($frame in $tagStack.ToArray()) { if ($null -ne $frame) { return $frame } }
    return $null
}
for ($i = 0; $i -lt $inputsLines.Count; $i++) {
    $line = $inputsLines[$i]
    if ($line -match '^\s*#ifdef\s+(\S+)') {
        # capture BEFORE the second -match: PowerShell's -match overwrites $Matches, and
        # '^LAB_ENTRY_\d+$' has no capture group, so $Matches[1] would come back $null and
        # every build tag would be lost. That exact slip made this script silently decline
        # to fix all 16 StackMode/StackConfirm rows on its first run.
        $directive = $Matches[1]
        if ($directive -match '^LAB_ENTRY_\d+$') { $tagStack.Push($directive) } else { $tagStack.Push($null) }
        continue
    }
    if ($line -match '^\s*#ifndef\s+(\S+)') { $tagStack.Push($null); continue }
    if ($line -match '^\s*#endif')          { if ($tagStack.Count -gt 0) { [void]$tagStack.Pop() }; continue }
    if ($line -match '^\s*input\s+(\S+)') {
        if ($Matches[1] -eq 'group') { continue }
        $tokens = $line.Trim() -split '\s+'
        if ($tokens.Count -lt 3) { continue }
        $ident = $tokens[2]
        if ($ident -match '^([^=;]+)') { $ident = $Matches[1] }
        $codeInputs.Add([pscustomobject]@{ Name = $ident; Line = ($i + 1); Tag = (Get-CurrentLabEntryTag) })
    }
}
$codeByName = @{}
foreach ($e in $codeInputs) {
    if (-not $codeByName.ContainsKey($e.Name)) { $codeByName[$e.Name] = New-Object System.Collections.Generic.List[object] }
    $codeByName[$e.Name].Add($e)
}

# --- Parse through the strict header-keyed reader first. The raw lines below are only used to
# --- preserve formatting while changing the one cited number.
$csvLines = Get-Content -LiteralPath $csvPath -Encoding UTF8
$records = @(Read-ParameterRegistryCsv -Path $csvPath)
$headerIndex = 0
while ($headerIndex -lt $csvLines.Count -and
       ($csvLines[$headerIndex].Trim().Length -eq 0 -or $csvLines[$headerIndex].StartsWith('>'))) { $headerIndex++ }
$dataLineIndices = @(
    for ($lineIndex = $headerIndex + 1; $lineIndex -lt $csvLines.Count; $lineIndex++) {
        if ($csvLines[$lineIndex].Trim().Length -gt 0 -and -not $csvLines[$lineIndex].StartsWith('>')) { $lineIndex }
    }
)
if ($dataLineIndices.Count -ne $records.Count) { throw "CSV parser/data-line count mismatch: $($records.Count) vs $($dataLineIndices.Count)" }
$defaultProfileIndex = [array]::IndexOf($script:ParameterRegistryLastHeaders, 'default_profile')
if ($defaultProfileIndex -lt 0) { throw 'default_profile header was not resolved' }
$out = New-Object System.Collections.Generic.List[string]
foreach ($csvLine in $csvLines) { $out.Add([string]$csvLine) }
$changed = 0; $unknown = New-Object System.Collections.Generic.List[string]

for ($rowIndex = 0; $rowIndex -lt $dataLineIndices.Count; $rowIndex++) {
    $lineIndex = [int]$dataLineIndices[$rowIndex]
    $line = $csvLines[$lineIndex]
    $record = $records[$rowIndex]
    $name = [string]$record.name
    $baseName = $name; $tag = $null
    if ($name -match '^(.*)\[(.+)\]$') { $baseName = $Matches[1]; $tag = $Matches[2] }

    $m = [regex]::Match([string]$record.default_profile, 'Inputs\.mqh:(\d+)')
    if (-not $m.Success) { continue }

    if (-not $codeByName.ContainsKey($baseName)) { $unknown.Add($name); continue }
    $candidates = $codeByName[$baseName]
    $entry = if ($candidates.Count -eq 1) { $candidates[0] }
             elseif ($tag) { $candidates | Where-Object { $_.Tag -eq $tag } | Select-Object -First 1 }
             else { $null }
    if (-not $entry) { $unknown.Add($name); continue }

    $cited = [int]$m.Groups[1].Value
    if ($cited -eq $entry.Line) { continue }

    # Find the header-selected field with a quote-aware scan; do not assume default_profile is
    # column 7 and do not touch an identical citation in another field.
    $spans = New-Object System.Collections.Generic.List[object]
    $inQuotes = $false; $start = 0; $i = 0
    while ($i -lt $line.Length) {
        $ch = $line[$i]
        if ($ch -eq '"') {
            if ($inQuotes -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '"') { $i++; }
            else { $inQuotes = -not $inQuotes }
        } elseif ($ch -eq ',' -and -not $inQuotes) {
            $spans.Add([pscustomobject]@{ Start = $start; Length = $i - $start })
            $start = $i + 1
        }
        $i++
    }
    $spans.Add([pscustomobject]@{ Start = $start; Length = $line.Length - $start })
    if ($spans.Count -le $defaultProfileIndex) { throw "Unable to locate default_profile field for $name" }
    $profileSpan = $spans[$defaultProfileIndex]
    $fieldText = $line.Substring($profileSpan.Start, $profileSpan.Length)
    $fieldMatch = [regex]::Match($fieldText, 'Inputs\.mqh:(\d+)')
    if (-not $fieldMatch.Success) { continue }
    $absIndex = $profileSpan.Start + $fieldMatch.Groups[1].Index
    $newLine = $line.Substring(0, $absIndex) + $entry.Line + $line.Substring($absIndex + $fieldMatch.Groups[1].Length)
    $out[$lineIndex] = $newLine
    $changed++
    Write-Host ("  {0,-34} {1} -> {2}" -f $name, $cited, $entry.Line)
}

Write-Host ""
if ($unknown.Count -gt 0) {
    Write-Host "NOT RESOLVED (no matching declaration - add/fix the row by hand, then re-run):" -ForegroundColor Red
    foreach ($u in $unknown) { Write-Host "  - $u" }
    Write-Host ""
}
Write-Host "$changed citation(s) would change." -ForegroundColor Cyan
if (-not $Apply) { Write-Host "DRY RUN - pass -Apply to write the file." -ForegroundColor Yellow; exit 0 }

# preserve the file's LF-only line endings and BOM-less UTF-8 encoding
[IO.File]::WriteAllText($csvPath, (($out -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
Write-Host "written -> $csvPath" -ForegroundColor Green
exit 0
