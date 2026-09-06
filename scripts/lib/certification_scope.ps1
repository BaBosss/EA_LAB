# certification_scope.ps1 - PowerShell bridge to the canonical certification-scope classifier.
#
# RUNTIME_IDENTITY_COVERAGE_CONTRACT_20260905. Mirrors scripts/lib/runtime_identity.ps1's role:
# the canonical comparison logic lives in _triage/factory_os/certification_scope.py; PowerShell
# only reads portfolio/CERTIFICATION_SCOPE.csv and the expected forward-observed scope, transports
# them into that validator, and returns its result. This file never parses DEPLOYMENTS.csv.notes.
#
# NOTE: this file deliberately sets no $ErrorActionPreference and no Set-StrictMode. Dot-sourcing
# does not create a scope, so either one would silently change the rules the CALLING script runs
# under (memory: strictmode-in-dotsourced-library-leaks). A shared library must be inert to its
# caller.

function Get-CertificationScopeRows {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    return @(Import-Csv -LiteralPath $Path)
}

function Get-CertificationScopeCoverage {
    <#
      Returns the same shape certification_scope.py's classify_forward_scope() produces:
        state / scope_total_forward_observed / scope_native_identity_capable /
        scope_mechanism_unavailable / scope_lab_certified / scope_user_owned_uncertified /
        scope_unknown / missing_scope_fact / orphaned_scope_rows / reason
      plus 'parse_errors' when the CSV itself fails shape/enum/key-uniqueness validation, in which
      case state is forced to 'FAIL' by the python validator and none of the counts may be trusted.
      An unreadable/missing CSV is passed through as zero rows -- every expected key then reports
      via missing_scope_fact, never a silent pass.
    #>
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [AllowNull()][string[]]$ExpectedScope,
        [string]$CsvPath = '',
        [string]$PythonPath = ''
    )
    if ($CsvPath -eq '') { $CsvPath = Join-Path $RepoRoot 'portfolio\CERTIFICATION_SCOPE.csv' }
    if ($PythonPath -eq '') { $PythonPath = Join-Path $RepoRoot 'tools\python312\python.exe' }
    $work = Join-Path ([IO.Path]::GetTempPath()) ('certification_scope_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        $emptyCsvPath = Join-Path $work 'empty_certification_scope.csv'
        $csvToRead = if (Test-Path -LiteralPath $CsvPath) { $CsvPath } else {
            [IO.File]::WriteAllText($emptyCsvPath,
                "account,magic,identity_mechanism_capability,identity_certification_scope,evidence_ref,status`n",
                (New-Object Text.UTF8Encoding($false)))
            $emptyCsvPath
        }
        $expectedJsonPath = Join-Path $work 'expected.json'
        $expectedArray = @($ExpectedScope | Where-Object { "$_" -ne '' })
        $expectedJson = if ($expectedArray.Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject @($expectedArray) -Depth 4 }
        [IO.File]::WriteAllText($expectedJsonPath, $expectedJson, (New-Object Text.UTF8Encoding($false)))
        $validator = Join-Path $RepoRoot '_triage\factory_os\certification_scope.py'
        $out = & $PythonPath $validator classify $csvToRead $expectedJsonPath 2>&1
        $json = @($out) | Where-Object { "$($_)" -match '^\{' } | Select-Object -Last 1
        if (-not $json) { throw "certification scope validator produced no JSON result: $($out -join ' ')" }
        return ($json | ConvertFrom-Json)
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
