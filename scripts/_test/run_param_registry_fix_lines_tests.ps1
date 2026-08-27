<#
Regression cage for scripts/param_registry_fix_lines.ps1.
The fixture is disposable: the real docs/PARAM_REGISTRY.csv is never written.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Write-Utf8NoBomLf {
    param([string]$Path, [string[]]$Lines)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, (($Lines -join "`n") + "`n"), $enc)
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fixer = Join-Path $repoRoot 'scripts\param_registry_fix_lines.ps1'
$reader = Join-Path $repoRoot 'scripts\lib\param_registry_csv.ps1'
$powerShell = (Get-Process -Id $PID).Path
if (-not $powerShell) { $powerShell = 'powershell.exe' }
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ea_lab_param_fix_' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts\lib') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'ea_template\core') -Force | Out-Null
    Copy-Item -LiteralPath $fixer -Destination (Join-Path $tempRoot 'scripts\param_registry_fix_lines.ps1')
    Copy-Item -LiteralPath $reader -Destination (Join-Path $tempRoot 'scripts\lib\param_registry_csv.ps1')

    $inputLines = @(
        '// fixture line 1',
        '// fixture line 2',
        'input int DemoParam = 1;'
    )
    Write-Utf8NoBomLf -Path (Join-Path $tempRoot 'ea_template\core\Inputs.mqh') -Lines $inputLines

    $preamble = 1..9 | ForEach-Object { "> fixture preamble $_" }
    $header = '"name","owner","unit","context","active_when","coupled_parameters","default_profile","optimize_stage","safe_range","causal_question","classification","classification_note","parameter_pid","unit_true","portability","display_label","relation_hint"'
    $row = '"DemoParam","fixture","count","fixture","always","","DEMO(1) - Inputs.mqh:99","UNKNOWN","UNKNOWN","fixture question","ACTIVE","fixture note","20000","count","PORTABLE","Demo Param",""'
    $originalLines = @($preamble) + @($header, $row)
    $csvPath = Join-Path $tempRoot 'docs\PARAM_REGISTRY.csv'
    Write-Utf8NoBomLf -Path $csvPath -Lines $originalLines

    $beforeBytes = [IO.File]::ReadAllBytes($csvPath)
    $preview = @(& $powerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRoot 'scripts\param_registry_fix_lines.ps1') 2>&1 | ForEach-Object { $_.ToString() })
    Assert-True ($LASTEXITCODE -eq 0) "preview failed: $($preview -join "`n")"
    Assert-True (($preview -join "`n") -match '1 citation\(s\) would change') 'preview did not report exactly one repair'
    Assert-True ([Convert]::ToBase64String($beforeBytes) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($csvPath))) 'preview mutated the fixture'
    $apply = @(& $powerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tempRoot 'scripts\param_registry_fix_lines.ps1') -Apply 2>&1 | ForEach-Object { $_.ToString() })
    Assert-True ($LASTEXITCODE -eq 0) "apply failed: $($apply -join "`n")"

    $afterLines = @(Get-Content -LiteralPath $csvPath)
    Assert-True ($afterLines.Count -eq $originalLines.Count) "line count changed: $($originalLines.Count) -> $($afterLines.Count)"
    for ($i = 0; $i -lt $preamble.Count; $i++) {
        Assert-True ($afterLines[$i] -ceq $preamble[$i]) "preamble line $($i + 1) changed or disappeared"
    }
    Assert-True ($afterLines[$preamble.Count] -ceq $header) 'CSV header changed or disappeared'

    $expectedRow = $row.Replace('Inputs.mqh:99', 'Inputs.mqh:3')
    Assert-True ($afterLines[$preamble.Count + 1] -ceq $expectedRow) 'data row changed outside the citation digits or was reordered'
    Assert-True (($apply -join "`n") -match '1 citation\(s\) would change') 'apply did not report exactly one repair'

    $expectedLines = @($preamble) + @($header, $expectedRow)
    Assert-True ((Compare-Object -ReferenceObject $expectedLines -DifferenceObject $afterLines -SyncWindow 0).Count -eq 0) 'output differs from the exact permitted transformation'

    Write-Host '[PASS] preview is non-mutating'
    Write-Host '[PASS] preamble preserved'
    Write-Host '[PASS] CSV header preserved'
    Write-Host '[PASS] row ordering and all non-citation fields preserved'
    Write-Host '[PASS] only Inputs.mqh citation digits changed'
    Write-Host 'param_registry_fix_lines regression cage: PASS'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
