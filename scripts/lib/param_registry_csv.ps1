<#
Strict header-keyed reader for docs/PARAM_REGISTRY.csv.

The registry has a prose preamble followed by one CSV header and one physical
CSV record per parameter. TextFieldParser supplies quote/comma handling; this
function supplies the fail-closed schema checks shared by the PowerShell
consumers. Extra columns are returned and ignored by callers, never guessed by
position.
#>

$script:ParameterRegistryRequiredHeaders = @(
    'name', 'owner', 'unit', 'context', 'active_when', 'coupled_parameters',
    'default_profile', 'optimize_stage', 'safe_range', 'causal_question',
    'classification', 'classification_note', 'parameter_pid'
)

function Read-ParameterRegistryCsv {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "PARAM_REGISTRY.csv not found: $Path"
    }
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
    $lines = Get-Content -LiteralPath $Path
    $headerIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim().Length -gt 0 -and -not $lines[$i].StartsWith('>')) {
            $headerIndex = $i
            break
        }
    }
    if ($headerIndex -lt 0) { throw "$Path has no CSV header" }

    $text = ($lines[$headerIndex..($lines.Count - 1)] -join "`n")
    $parser = [Microsoft.VisualBasic.FileIO.TextFieldParser]::new(
        [System.IO.StringReader]::new($text))
    $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
    $parser.SetDelimiters(',')
    $parser.HasFieldsEnclosedInQuotes = $true
    try {
        try { $headers = $parser.ReadFields() }
        catch { throw "${Path}: malformed CSV header: $($_.Exception.Message)" }
        if ($null -eq $headers -or $headers.Count -eq 0) { throw "$Path has an empty CSV header" }
        $duplicates = @($headers | Group-Object | Where-Object Count -gt 1 | Select-Object -ExpandProperty Name)
        if ($duplicates.Count -gt 0) { throw "$Path has duplicate CSV header(s): $($duplicates -join ', ')" }
        $missing = @($script:ParameterRegistryRequiredHeaders | Where-Object { $_ -notin $headers })
        if ($missing.Count -gt 0) { throw "$Path is missing required CSV header(s): $($missing -join ', ')" }

        $rows = New-Object System.Collections.Generic.List[object]
        while (-not $parser.EndOfData) {
            try { $fields = $parser.ReadFields() }
            catch { throw "${Path}: malformed CSV row near line $($parser.LineNumber): $($_.Exception.Message)" }
            if ($fields.Count -ne $headers.Count) {
                throw "${Path}: row near line $($parser.LineNumber) has $($fields.Count) fields; header declares $($headers.Count)"
            }
            if (@($fields | Where-Object { $_ -match "`r|`n" }).Count -gt 0) {
                throw "${Path}: multiline rich metadata is not supported during the PID migration"
            }
            $record = [ordered]@{}
            for ($j = 0; $j -lt $headers.Count; $j++) { $record[$headers[$j]] = $fields[$j] }
            if ([string]::IsNullOrWhiteSpace([string]$record['name'])) {
                throw "${Path}: registry row near line $($parser.LineNumber) has an empty name"
            }
            if ([string]$record['parameter_pid'] -notmatch '^[1-9][0-9]{4}$') {
                throw "${Path}: registry row near line $($parser.LineNumber) has malformed parameter_pid '$($record['parameter_pid'])'"
            }
            $rows.Add([pscustomobject]$record)
        }
        if ($rows.Count -eq 0) { throw "$Path parsed to zero registry rows" }
        $script:ParameterRegistryLastHeaders = @($headers)
        return $rows
    } finally {
        $parser.Close()
    }
}
