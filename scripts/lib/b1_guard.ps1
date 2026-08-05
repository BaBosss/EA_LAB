# B1_DATASET.csv guard rules -- ORDER-500 (user ratified option B, 2026-07-28)
#
# WHY THIS FILE EXISTS AS A LIBRARY RATHER THAN INLINE
#   ORDER-421 (2026-07-28) found that the negative suite protecting the pre-commit
#   hook had been running at 14% of itself for two days: the synthetic fixture copies
#   the real hook but its seed never stubbed the checkers the hook calls, so adding a
#   guard silently broke the cage of another. Nothing made the fixture track the hook's
#   dependency list.
#
#   Putting the rules in a dot-sourceable library removes that failure mode by
#   construction: `check_precommit_staged.ps1`, `.githooks/commit-msg` and
#   `scripts/_test/run_b1_guard_tests.ps1` all call THESE functions. There is one
#   implementation, so the cage cannot test something the production path does not run.
#
# WHAT ORDER-500 CHANGED, AND WHAT IT DELIBERATELY DID NOT
#   Default behaviour is unchanged: B1_DATASET.csv is append-only. Option B ADDS an
#   audited repair path (a declaration in the commit message) -- it does not relax the
#   default. The ORDER-144 rule still blocks every undeclared modification.
#
#   The gap the order actually named: the old guard checked that bytes were only ADDED,
#   never that what was added is a ROW. That is how ORDER-280's entry disappeared --
#   every character somebody wrote is still in the file, it just stopped being data.
#   Test-B1RowShape closes that, and it applies to a repair commit too.

# DELIBERATELY NO `Set-StrictMode` HERE.
#
# The first version of this file opened with `Set-StrictMode -Version Latest`. Because
# the file is DOT-SOURCED, that ran in the CALLER's scope and changed the execution
# semantics of the whole of check_precommit_staged.ps1, which had never run under strict
# mode. The next commit was rejected by an unrelated part of that script:
#   [precommit-staged] INTEGRITY: chain check threw: The property 'Length' cannot be
#   found on this object.
# Nothing about the chain logic had changed -- a library had reached out and altered the
# rules its host runs under. A shared library must be inert to its caller beyond the
# functions it defines; the cage sets its own strict mode instead, so these functions are
# still exercised under the strictest interpretation without imposing it on anyone.

# The declaration a commit message must contain to modify existing B1 bytes.
# Deliberately verbose and un-guessable-by-accident: 're-pin' is one hyphenated word
# that could plausibly appear in ordinary prose about baselines, and a repair here is
# rarer and more consequential than a baseline move.
$script:B1RepairKeyword = 'B1-REPAIR'

function Get-B1RepairKeyword { return $script:B1RepairKeyword }

# The canonical column count is derived from the file's OWN header inside
# Test-B1RowShape rather than hardcoded, so adding a column to the schema does not
# require editing this file -- while a row that disagrees with its own header is always
# wrong, which is the defect being caught. There is deliberately no second helper that
# recomputes it: an unexercised duplicate of this logic is the drift the library exists
# to prevent, and the first draft's copy carried the same StrictMode bug noted below.

# Minimal RFC4180 field splitter. B1 notes routinely contain commas and doubled quotes,
# so a plain -split ',' would report a false field count on almost every real row -- a
# guard that cries wolf teaches --no-verify, which is the failure mode ORDER-500 cites
# from memory `feedback-audit-rule-rationale-not-compliance`.
function Split-B1CsvLine {
    param([string]$Line)
    $fields = New-Object System.Collections.Generic.List[string]
    $sb = New-Object System.Text.StringBuilder
    $inQuotes = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $ch = $Line[$i]
        if ($inQuotes) {
            if ($ch -eq '"') {
                if (($i + 1) -lt $Line.Length -and $Line[$i + 1] -eq '"') { [void]$sb.Append('"'); $i++ }
                else { $inQuotes = $false }
            } else { [void]$sb.Append($ch) }
        } else {
            if ($ch -eq '"') { $inQuotes = $true }
            elseif ($ch -eq ',') { [void]$fields.Add($sb.ToString()); [void]$sb.Clear() }
            else { [void]$sb.Append($ch) }
        }
    }
    [void]$fields.Add($sb.ToString())
    # An unterminated quote means the row is not a row. Return $null rather than a
    # marker value: the first version of this returned @(,-1) and the cage caught it on
    # its very first run, because PowerShell hands a one-element array back as a scalar
    # and `.Count` then throws under StrictMode. That is memory
    # `powershell-pipeline-count-null-on-single-result` biting inside the very guard
    # written to stop silent-pass bugs -- worth leaving the note rather than the fix alone.
    if ($inQuotes) { return $null }
    # `,` forces an array back even when the record has exactly one field, for the same reason.
    return , $fields.ToArray()
}

# Split file bytes into logical CSV records. A quoted field may legally contain a
# newline, so records are NOT lines -- splitting on newline alone is what makes a
# glued row look like one long legal record instead of two broken ones.
function Split-B1Records {
    param([string]$Text)
    $records = New-Object System.Collections.Generic.List[string]
    $sb = New-Object System.Text.StringBuilder
    $inQuotes = $false
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($ch -eq '"') { $inQuotes = -not $inQuotes; [void]$sb.Append($ch); continue }
        if (-not $inQuotes -and ($ch -eq "`n")) {
            $rec = $sb.ToString().TrimEnd("`r")
            if ($rec.Trim()) { [void]$records.Add($rec) }
            [void]$sb.Clear()
            continue
        }
        [void]$sb.Append($ch)
    }
    $rec = $sb.ToString().TrimEnd("`r")
    if ($rec.Trim()) { [void]$records.Add($rec) }
    return $records.ToArray()
}

function ConvertTo-B1Text {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes) { return $null }
    return [System.Text.Encoding]::UTF8.GetString($Bytes)
}

# RULE 1 (ORDER-144, unchanged by default): existing HEAD bytes must be an exact prefix.
# -RepairDeclared is the ONLY thing that relaxes it, and the caller may only pass $true
# after reading the real commit message -- which pre-commit structurally cannot do.
function Test-B1AppendOnly {
    param(
        [byte[]]$HeadBytes,
        [byte[]]$StagedBytes,
        [bool]$RepairDeclared = $false
    )
    if ($null -eq $HeadBytes) { return $null }
    if ($RepairDeclared) { return $null }
    if ($null -eq $StagedBytes) { return 'B1_DATASET.csv staged bytes could not be read' }
    if ($StagedBytes.Length -lt $HeadBytes.Length) { return 'B1_DATASET.csv may only append rows; staged bytes are shorter than HEAD' }
    for ($i = 0; $i -lt $HeadBytes.Length; $i++) {
        if ($StagedBytes[$i] -ne $HeadBytes[$i]) { return 'B1_DATASET.csv may only append rows; existing HEAD bytes were modified' }
    }
    return $null
}

# RULE 2 (ORDER-500, new): every record must carry the header's field count.
# Runs on a repair commit too -- a declared repair that produces a malformed row is
# still a malformed row, and this is the assertion whose absence let ORDER-280 vanish.
function Test-B1RowShape {
    param([byte[]]$StagedBytes)
    if ($null -eq $StagedBytes) { return $null }
    $text = ConvertTo-B1Text -Bytes $StagedBytes
    $records = Split-B1Records -Text $text
    if ($records.Count -lt 1) { return 'B1_DATASET.csv has no records' }
    $headerFields = Split-B1CsvLine -Line ($records[0] -replace "^\xEF\xBB\xBF", '')
    if ($null -eq $headerFields) { return 'B1_DATASET.csv header has an unterminated quoted field' }
    $expected = $headerFields.Count
    if ($expected -le 1) { return 'B1_DATASET.csv header does not parse as a CSV row' }
    $bad = New-Object System.Collections.Generic.List[string]
    for ($i = 1; $i -lt $records.Count; $i++) {
        $fields = Split-B1CsvLine -Line $records[$i]
        if ($null -eq $fields) {
            $bad.Add(("record {0} has an unterminated quoted field" -f ($i + 1)))
            continue
        }
        $count = $fields.Count
        if ($count -ne $expected) {
            $id = ($records[$i] -split ',')[0]
            $bad.Add(("record {0} ({1}) has {2} fields, expected {3}" -f ($i + 1), $id, $count, $expected))
        }
    }
    if ($bad.Count -gt 0) {
        return ('B1_DATASET.csv contains malformed row(s) -- ' + ($bad -join ' | ') +
                '. A row with the wrong field count is not data: the append that produced it most likely lacked a leading newline and glued itself onto the previous row (ORDER-500).')
    }
    return $null
}

# Does this commit message declare an audited repair?
function Test-B1RepairDeclared {
    param([string]$Message)
    if ([string]::IsNullOrWhiteSpace($Message)) { return $false }
    return ($Message -cmatch [regex]::Escape($script:B1RepairKeyword))
}
