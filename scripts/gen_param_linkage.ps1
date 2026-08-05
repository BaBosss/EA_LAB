<#
.SYNOPSIS
  Generates docs/PARAM_LINKAGE.md from docs/PARAM_REGISTRY.csv.

.DESCRIPTION
  ORDER-191(b). This script is the SOLE source of docs/PARAM_LINKAGE.md - that file is
  generated output and must never be hand-edited. Regenerate it any time
  docs/PARAM_REGISTRY.csv changes (i.e. any time param_registry_check.ps1 has been re-run
  after an Inputs.mqh edit) by running:

      powershell -File scripts\gen_param_linkage.ps1

  The script is deterministic: given the same PARAM_REGISTRY.csv it always produces
  byte-identical output (no timestamps, no wall-clock data, no random ordering).

  Sections produced, in order:
    1. "Override pairs" - every case where one input silently supersedes another,
       discovered by pattern-scanning the coupled_parameters and classification_note
       columns for supersedes / overrides-this / this-overrides / OVERRIDDEN-when /
       overridden-by / superseded-by phrasing (see Get-KnownNameMatches / the
       $overridePairs build loop below). This section is placed FIRST because it is
       the single most load-bearing section in the document.
    2. One section per distinct `context` value found in the registry (sorted
       alphabetically) - the section list is derived from the data, never hardcoded.
       Each section is a table: parameter | active when | coupled with | what it does.
#>

[CmdletBinding()]
param(
    [string]$RegistryPath,
    [string]$OutPath
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot  = Split-Path -Parent $scriptDir
if (-not $RegistryPath) { $RegistryPath = Join-Path $repoRoot 'docs\PARAM_REGISTRY.csv' }
if (-not $OutPath)      { $OutPath      = Join-Path $repoRoot 'docs\PARAM_LINKAGE.md' }

if (-not (Test-Path -LiteralPath $RegistryPath)) {
    throw "Registry not found: $RegistryPath"
}

# ---------------------------------------------------------------------------
# 1. Parse the CSV: skip leading '>' comment lines, then ConvertFrom-Csv on
#    the header + data lines. One registry row = one physical line (verified:
#    no embedded newlines inside quoted fields in this file).
# ---------------------------------------------------------------------------
$rawLines = Get-Content -LiteralPath $RegistryPath -Encoding UTF8

$dataStart = -1
for ($i = 0; $i -lt $rawLines.Count; $i++) {
    if ($rawLines[$i].TrimStart().StartsWith('>')) { continue }
    $dataStart = $i
    break
}
if ($dataStart -lt 0) { throw "Could not find header line in $RegistryPath" }

$csvLines = $rawLines[$dataStart..($rawLines.Count - 1)] | Where-Object { $_.Trim().Length -gt 0 }
$rows = $csvLines | ConvertFrom-Csv

if (-not $rows -or $rows.Count -eq 0) { throw "No data rows parsed from $RegistryPath" }

$allNames = @($rows | ForEach-Object { $_.name })

function Escape-Cell {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $t = $Text -replace "`r`n", ' ' -replace "`n", ' ' -replace "`r", ' '
    $t = $t -replace '\|', '\|'
    return $t.Trim()
}

function Get-KnownNameMatches {
    param(
        [string]$Text,
        [string[]]$AllNames,
        [string]$Exclude
    )
    $found = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrEmpty($Text)) { return $found }
    foreach ($n in $AllNames) {
        if ($n -eq $Exclude) { continue }
        $pat = [regex]::Escape($n)
        if ($Text -match "(?<![A-Za-z0-9_])$pat(?![A-Za-z0-9_])") {
            if (-not $found.Contains($n)) { [void]$found.Add($n) }
        }
    }
    return $found
}

# ---------------------------------------------------------------------------
# 2. Discover override pairs by scanning coupled_parameters + classification_note.
#    Trigger vocabulary: supersedes / OVERRIDDEN / "this overrides" / "overrides
#    this" / overridden...by / superseded...by. Deliberately requires the exact
#    verb forms (word-boundary matched) so it does NOT fire on parameter *names*
#    that merely contain the substring "Override" (e.g. RC_MaxLevelsOverride) or
#    on unrelated ".set overrides StackMode to 91/92" prose.
# ---------------------------------------------------------------------------
$pairs = New-Object System.Collections.Generic.List[object]

foreach ($r in $rows) {
    $name    = $r.name
    $note    = [string]$r.classification_note
    $coupled = [string]$r.coupled_parameters

    if ($note -match '(?i)\bsupersedes(/blanks)?\b') {
        foreach ($l in (Get-KnownNameMatches -Text $note -AllNames $allNames -Exclude $name)) {
            $pairs.Add([pscustomobject]@{ Winner = $name; Loser = $l; Condition = $note.Trim(); Source = 'note:supersedes' })
        }
    }
    if ($note -match '(?i)\boverridden\b.*\bby\b') {
        foreach ($w in (Get-KnownNameMatches -Text $note -AllNames $allNames -Exclude $name)) {
            $pairs.Add([pscustomobject]@{ Winner = $w; Loser = $name; Condition = $note.Trim(); Source = 'note:overridden-by' })
        }
    }
    if ($note -match '(?i)\bsuperseded\b.*\bby\b') {
        foreach ($w in (Get-KnownNameMatches -Text $note -AllNames $allNames -Exclude $name)) {
            $pairs.Add([pscustomobject]@{ Winner = $w; Loser = $name; Condition = $note.Trim(); Source = 'note:superseded-by' })
        }
    }

    if ($coupled) {
        foreach ($seg0 in ($coupled -split ';')) {
            $seg = $seg0.Trim()
            if (-not $seg) { continue }
            $parenIdx   = $seg.IndexOf('(')
            $beforeParen = if ($parenIdx -ge 0) { $seg.Substring(0, $parenIdx) } else { $seg }

            if ($seg -match '(?i)this\s+overrides|OVERRIDDEN when|both OVERRIDDEN') {
                $losers = Get-KnownNameMatches -Text $beforeParen -AllNames $allNames -Exclude $name
                if ($losers.Count -eq 0) { $losers = Get-KnownNameMatches -Text $seg -AllNames $allNames -Exclude $name }
                foreach ($l in $losers) {
                    $pairs.Add([pscustomobject]@{ Winner = $name; Loser = $l; Condition = $seg; Source = 'coupled:self-overrides' })
                }
            }
            elseif ($seg -match '(?i)overrides\s+this\b') {
                $winners = Get-KnownNameMatches -Text $beforeParen -AllNames $allNames -Exclude $name
                if ($winners.Count -eq 0) { $winners = Get-KnownNameMatches -Text $seg -AllNames $allNames -Exclude $name }
                foreach ($w in $winners) {
                    $pairs.Add([pscustomobject]@{ Winner = $w; Loser = $name; Condition = $seg; Source = 'coupled:ident-overrides-self' })
                }
            }
            elseif ($seg -match '(?i)(?<![A-Za-z0-9_])overrides(?![A-Za-z0-9_])') {
                $m = [regex]::Match($seg, '(?i)^(?<subject>.*?)\boverrides\b')
                if ($m.Success) {
                    $winners = Get-KnownNameMatches -Text $m.Groups['subject'].Value -AllNames $allNames -Exclude $name
                    foreach ($w in $winners) {
                        $pairs.Add([pscustomobject]@{ Winner = $w; Loser = $name; Condition = $seg; Source = 'coupled:generic-overrides' })
                    }
                }
            }
        }
    }
}

# Dedup by (Winner,Loser); keep first condition text seen; sort for determinism.
$dedup = [ordered]@{}
foreach ($p in $pairs) {
    $key = "$($p.Winner)||$($p.Loser)"
    if (-not $dedup.Contains($key)) { $dedup[$key] = $p }
}
$overridePairs = $dedup.Values | Sort-Object Winner, Loser

# "Silent" flag: the LOSER's own classification_note contains no acknowledgement
# (overridden / superseded / OVERRIDDEN) that IT can be overridden.
$noteByName = @{}
foreach ($r in $rows) { $noteByName[$r.name] = [string]$r.classification_note }
foreach ($p in $overridePairs) {
    $loserNote = $noteByName[$p.Loser]
    $p | Add-Member -NotePropertyName IsSilent -NotePropertyValue ([bool]($loserNote -notmatch '(?i)overridden|superseded|OVERRIDDEN')) -Force
}

# ---------------------------------------------------------------------------
# 3. Build the markdown.
# ---------------------------------------------------------------------------
$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine('# Parameter Linkage Map')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> **GENERATED FILE - do not hand-edit.** Produced by `scripts/gen_param_linkage.ps1`')
[void]$sb.AppendLine('> from `docs/PARAM_REGISTRY.csv` (one row per MQL5 input declared in')
[void]$sb.AppendLine('> `ea_template/core/Inputs.mqh`). Any manual edit to this file will be silently')
[void]$sb.AppendLine('> overwritten the next time the generator runs.')
[void]$sb.AppendLine('>')
[void]$sb.AppendLine('> **Regenerate whenever `docs/PARAM_REGISTRY.csv` changes** - i.e. any time an')
[void]$sb.AppendLine('> `Inputs.mqh` edit is followed by a registry sync. Run:')
[void]$sb.AppendLine('> `powershell -File scripts\gen_param_linkage.ps1`, then re-run')
[void]$sb.AppendLine('> `powershell -File scripts\param_registry_check.ps1` to confirm the registry itself')
[void]$sb.AppendLine('> is still in sync with the code before trusting this doc.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Rows in source registry: $($rows.Count).")
[void]$sb.AppendLine('')

# --- Override pairs (first: most load-bearing section) ---
[void]$sb.AppendLine('## Override pairs')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Every case in the registry where one input silently supersedes another under some')
[void]$sb.AppendLine('condition - discovered by scanning `coupled_parameters` and `classification_note` for')
[void]$sb.AppendLine('*supersedes / overrides-this / this-overrides / OVERRIDDEN / overridden-by / superseded-by*')
[void]$sb.AppendLine('phrasing. **SILENT** means the losing input''s own row carries no note warning the')
[void]$sb.AppendLine('reader that it can be overridden - the reader would only discover this by reading the')
[void]$sb.AppendLine('*winner''s* row. See `_triage/PARAM_INACTIVE_AUDIT.md` for why each silent case matters.')
[void]$sb.AppendLine('')
if ($overridePairs.Count -eq 0) {
    [void]$sb.AppendLine('_None found._')
} else {
    foreach ($p in $overridePairs) {
        $tag = if ($p.IsSilent) { ' **[SILENT]**' } else { '' }
        $cond = Escape-Cell $p.Condition
        [void]$sb.AppendLine("- **``$($p.Winner)``** beats **``$($p.Loser)``**$tag -- $cond")
    }
}
[void]$sb.AppendLine('')

# --- One section per distinct context, derived from the data ---
$contexts = @($rows | ForEach-Object { $_.context } | Sort-Object -Unique)

[void]$sb.AppendLine('## Parameters by context')
[void]$sb.AppendLine('')

$totalRowsEmitted = 0
foreach ($ctx in $contexts) {
    $ctxRows = @($rows | Where-Object { $_.context -eq $ctx } | Sort-Object name)
    $totalRowsEmitted += $ctxRows.Count

    [void]$sb.AppendLine("### $ctx")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| parameter | active when | coupled with | what it does |')
    [void]$sb.AppendLine('|---|---|---|---|')
    foreach ($r in $ctxRows) {
        $p1 = Escape-Cell $r.name
        $p2 = Escape-Cell $r.active_when
        $p3 = Escape-Cell $r.coupled_parameters
        $p4 = Escape-Cell $r.causal_question
        [void]$sb.AppendLine("| ``$p1`` | $p2 | $p3 | $p4 |")
    }
    [void]$sb.AppendLine('')
}

[void]$sb.AppendLine('---')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Total parameter rows across the context sections above: $totalRowsEmitted (must equal the source registry's $($rows.Count) rows, each appearing exactly once - context is a single-valued column so grouping by it partitions the rows).")
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Override pairs found: $($overridePairs.Count).")

# Write UTF-8 without BOM for a clean, diff-friendly generated file.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutPath, $sb.ToString(), $utf8NoBom)

Write-Host "Wrote $OutPath"
Write-Host "Rows parsed from registry : $($rows.Count)"
Write-Host "Distinct context sections : $($contexts.Count)"
Write-Host "Rows emitted across sections: $totalRowsEmitted"
Write-Host "Override pairs found      : $($overridePairs.Count)"
