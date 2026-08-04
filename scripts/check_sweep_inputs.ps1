<#
.SYNOPSIS
    Refuse a parameter sweep whose reports did not actually run distinct configurations.

.DESCRIPTION
    A backtest report carrying a plausible number is NOT evidence that the intended configuration
    ran. On 2026-08-04 a 25-cell sweep was preceded by 15 reports, each named for a different
    (SlAtrMult, AtrPeriod) pair, every one of which had actually run the untouched baseline and
    returned the identical result. Nothing caught it; it was avoided by an accident of filename
    parsing. Had those files been read, the conclusion would have been "both axes are inert" --
    the exact opposite of the truth, supported by fifteen mutually consistent reports.

    This script reads the values a report's own Inputs page records and refuses when a set of
    reports that is supposed to be a sweep is not one.

    TWO CHECKS, and the first is the one that matters:

    1. DISTINCTNESS (always). Across the matched reports, the swept parameters must not collapse.
       If N reports share one identical parameter tuple, the .set edits did not land. This needs no
       filename convention and no manifest, which is why it is the default: the failure it catches
       is precisely the failure that looks like success.

    2. FILENAME AGREEMENT (opt-in, -ExpectFromName). When report names encode the values, each
       report's Inputs page must agree with its own name. Off by default because naming schemes
       drift -- the 2026-08-04 incident had `Sl1` and `Sl1.0` in the same directory meaning
       different things.

    MT5 writes reports as UTF-16. Reading them with a default-encoding reader finds nothing and
    reports zero mismatches, which is a pass that means "I could not see the file". The reader here
    detects the encoding and REFUSES a report whose Inputs section it cannot locate at all, rather
    than counting it as clean.

.PARAMETER ReportGlob
    Glob for the reports forming one sweep, e.g. 'D:\EA_LAB\_mt5_auto\reports\O1411_PVT2_*.htm'.

.PARAMETER Parameter
    One or more EA input names that the sweep varies, e.g. _02_SlAtrMult,_01_AtrPeriod.

.PARAMETER ExpectFromName
    Also require each report's values to match what its filename claims. Supply -NamePattern.

.PARAMETER NamePattern
    Regex with one named capture group per -Parameter, in the same order, used with
    -ExpectFromName. Example: 'Sl(?<p1>[0-9.]+)_Atr(?<p2>[0-9]+)'

.OUTPUTS
    Exit 0  every matched report was readable and the sweep varies as claimed.
    Exit 1  a real defect: collapsed configurations, or a name/report disagreement.
    Exit 2  tooling failure: no reports matched, or a report's Inputs section was unreadable.
            Never conflated with exit 1 -- "I could not check" is not "I checked and it is fine".
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReportGlob,
    [Parameter(Mandatory = $true)][string[]]$Parameter,
    [switch]$ExpectFromName,
    [string]$NamePattern
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Tag = '[sweep-inputs]'

# `powershell -File script.ps1 -Parameter a,b` passes ONE string "a,b", not two arguments -- with
# -File every argument is a literal string, and binding one string to [string[]] yields a
# single-element array whose element contains a comma. The script then hunted for a parameter
# literally named "a,b", found nothing, and reported the file as unreadable: a wrong answer in the
# shape of a right one, on the very run this script was written to prevent that class of.
# Agents invoke it from briefs with -File, so the fix belongs here rather than in the call sites.
$Parameter = @($Parameter | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Parameter.Count -eq 0) {
    Write-Host ("{0} TOOLING: -Parameter resolved to nothing" -f $Tag)
    exit 2
}

function Read-ReportText {
    <# MT5 writes UTF-16LE, but not every report on disk is UTF-16, so the encoding has to be
       chosen per file rather than assumed.

       The sanity token MUST be something that cannot appear by chance. The first version of this
       function accepted a decode as successful if the text contained '=' -- and a mis-decoded
       UTF-16 file read as UTF8 is full of '=' by accident, so it returned garbage and the caller
       then reported "the Inputs page has no such parameter". That is a wrong answer wearing the
       shape of a right one: exactly the defect class this whole script exists to refuse, reproduced
       inside the script on its first run.

       So the token is the caller's own parameter names. A decode counts only if at least one of
       them is actually present. If no encoding yields them, we cannot see the file and say so. #>
    param([string]$Path, [string[]]$Tokens)
    foreach ($enc in @([System.Text.Encoding]::Unicode, [System.Text.Encoding]::UTF8, [System.Text.Encoding]::Default)) {
        $t = [System.IO.File]::ReadAllText($Path, $enc)
        foreach ($tok in $Tokens) {
            if ($t.Contains($tok)) { return $t }
        }
    }
    return $null
}

$reports = @(Get-ChildItem -Path $ReportGlob -File -ErrorAction SilentlyContinue)
if ($reports.Count -eq 0) {
    Write-Host ("{0} TOOLING: no report matched {1} -- nothing was checked" -f $Tag, $ReportGlob)
    exit 2
}

if ($ExpectFromName -and [string]::IsNullOrWhiteSpace($NamePattern)) {
    Write-Host ("{0} TOOLING: -ExpectFromName requires -NamePattern" -f $Tag)
    exit 2
}

$rows = New-Object System.Collections.Generic.List[object]
$unreadable = New-Object System.Collections.Generic.List[string]

foreach ($r in $reports) {
    $text = Read-ReportText -Path $r.FullName -Tokens $Parameter
    if ($null -eq $text) {
        $unreadable.Add(("{0} (no encoding yielded any of: {1})" -f $r.Name, ($Parameter -join ', ')))
        continue
    }

    $values = [ordered]@{}
    $missing = @()
    foreach ($p in $Parameter) {
        $m = [regex]::Match($text, ('(?<![A-Za-z0-9_]){0}=([^;<\s]+)' -f [regex]::Escape($p)))
        if ($m.Success) { $values[$p] = $m.Groups[1].Value } else { $missing += $p }
    }
    if ($missing.Count -gt 0) {
        # A parameter absent from the Inputs page is not a value of "unset" -- it means this report
        # cannot answer the question, which is a tooling failure, not a clean result.
        $unreadable.Add(("{0} (Inputs page has no: {1})" -f $r.Name, ($missing -join ', ')))
        continue
    }

    $rows.Add([pscustomobject]@{
        Name  = $r.Name
        Base  = $r.BaseName
        Tuple = (($Parameter | ForEach-Object { '{0}={1}' -f $_, $values[$_] }) -join '  ')
        Values = $values
    })
}

if ($unreadable.Count -gt 0) {
    Write-Host ("{0} TOOLING: {1} report(s) could not be read for these parameters:" -f $Tag, $unreadable.Count)
    $unreadable | ForEach-Object { Write-Host ("           {0}" -f $_) }
    Write-Host ("{0} refusing rather than reporting the readable subset as clean" -f $Tag)
    exit 2
}

$violations = New-Object System.Collections.Generic.List[string]

# ---- CHECK 1: distinctness -------------------------------------------------------------------
# @() is load-bearing. Without it, a sweep that collapsed to ONE configuration leaves $groups as a
# single GroupInfo, and $groups.Count then returns that group's OWN member count -- so the summary
# line printed "15 distinct configuration(s)" for the case where there was exactly 1. The refusal
# below was still correct, but the human-readable line above it said the opposite: a red that reads
# green at a glance. Same shape as memory `powershell-pipeline-count-null-on-single-result`.
$groups = @($rows | Group-Object Tuple | Sort-Object Count -Descending)
foreach ($g in $groups) {
    if ($g.Count -gt 1) {
        $names = ($g.Group | ForEach-Object { $_.Base }) -join ', '
        $violations.Add(("{0} report(s) ran the IDENTICAL configuration [{1}] -- the .set edits did not land: {2}" -f $g.Count, $g.Name, $names))
    }
}

# ---- CHECK 2: filename agreement (opt-in) ----------------------------------------------------
if ($ExpectFromName) {
    foreach ($row in $rows) {
        $m = [regex]::Match($row.Base, $NamePattern)
        if (-not $m.Success) {
            $violations.Add(("{0}: name does not match -NamePattern, so its claim cannot be checked" -f $row.Base))
            continue
        }
        for ($i = 0; $i -lt $Parameter.Count; $i++) {
            $grp = 'p' + ($i + 1)
            if (-not $m.Groups[$grp].Success) {
                $violations.Add(("{0}: -NamePattern has no group '{1}' for parameter {2}" -f $row.Base, $grp, $Parameter[$i]))
                continue
            }
            $claimed = $m.Groups[$grp].Value
            $actual  = $row.Values[$Parameter[$i]]
            # Compare numerically when both sides are numeric, so 1 and 1.0 agree rather than
            # producing a false mismatch -- and so 1 and 1.5 still disagree.
            $cd = 0.0; $ad = 0.0
            $bothNumeric = [double]::TryParse($claimed, [ref]$cd) -and [double]::TryParse($actual, [ref]$ad)
            $same = if ($bothNumeric) { $cd -eq $ad } else { $claimed -eq $actual }
            if (-not $same) {
                $violations.Add(("{0}: name claims {1}={2} but the report ran {1}={3}" -f $row.Base, $Parameter[$i], $claimed, $actual))
            }
        }
    }
}

Write-Host ("{0} {1} report(s), {2} distinct configuration(s) over: {3}" -f $Tag, $rows.Count, $groups.Count, ($Parameter -join ', '))

if ($violations.Count -gt 0) {
    Write-Host ("{0} REFUSED -- {1} defect(s):" -f $Tag, $violations.Count)
    $violations | ForEach-Object { Write-Host ("           {0}" -f $_) }
    exit 1
}

Write-Host ("{0} PASS -- every report is readable and no two ran the same configuration" -f $Tag)
exit 0
