<#
Stage A: -Mode Prepare -EvidenceDirectory <NEW external directory>
Stage B (CT only): -Mode Compare -EvidenceDirectory <prepared directory>
                  -StageBReceipt <CT-frozen qualification receipt.json>

This runner NEVER launches MetaEditor, terminal or tester and never writes an
installation. CT owns reservations, actual identity freeze, compilation and the
exact no-trade fixture execution. Compare binds supplied artifacts and refuses
any differing boundary result. No production warning waiver or acceptance.

StageBReceipt fields:
  compiler, terminal: {path, sha256, build}; lane: MT5_PRIMARY;
  reservation, data_directory: nonempty strings;
  fixture_manifest_sha256: SHA256 of prepared fixture_manifest.json;
  compiles: four records {role, source_sha256, product:{path,sha256}, log:{path,sha256}};
    roles: production, harness, explicit, implicit_test_control.
  runs: two records {role, product_sha256, log:{path,sha256}};
    roles: explicit, implicit_test_control. Same frozen terminal/install for both.
Compiler and runtime build numbers are separate and MUST come from actual files.
Historical 6182/6090 are not defaults. Compiler full-production gate and separate
exact-head Scrutiny remain CT gates after this engineering-only comparison.
#>
[CmdletBinding()]
param(
    [ValidateSet('Prepare','Compare')][string]$Mode = 'Prepare',
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
    [string]$StageBReceipt = '',
    [string]$RepoRoot = ''
)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
. (Join-Path $RepoRoot 'scripts/use_python.ps1')
$fixturePython = Assert-PortablePython -Root $RepoRoot
$env:PYTHONDONTWRITEBYTECODE = '1'
$generator = Join-Path $RepoRoot 'tools/df03_compat/template_engine.py'
$destination = [IO.Path]::GetFullPath($EvidenceDirectory)
$rootPath = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
if ($destination -eq $rootPath -or $destination.StartsWith($rootPath+'\',[StringComparison]::OrdinalIgnoreCase)) {
    throw 'External evidence directory required'
}
function Hash([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
function BoundFile($Record) {
    if (-not $Record.path -or $Record.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Missing artifact identity' }
    $path = (Resolve-Path -LiteralPath $Record.path).Path
    if ((Hash $path) -cne $Record.sha256) { throw "Artifact hash mismatch: $path" }
    if ((Get-Item -LiteralPath $path).Length -eq 0) { throw "Empty artifact: $path" }
    return $path
}
if ($Mode -eq 'Prepare') {
    if ($StageBReceipt) { throw 'Stage B receipt is not a Prepare input' }
    & $fixturePython -B $generator --prepare-fixture $destination
    exit $LASTEXITCODE
}
if (-not $StageBReceipt) { throw 'CT frozen StageBReceipt required; no launch authority is inferred' }
$output = Join-Path $destination 'conversion_comparison.json'
if (Test-Path -LiteralPath $output) { throw 'Refuse overwriting comparison evidence' }
$receipt = Get-Content -LiteralPath $StageBReceipt -Raw | ConvertFrom-Json
$manifestPath = Join-Path $destination 'fixture_manifest.json'
if ((Hash $manifestPath) -cne $receipt.fixture_manifest_sha256) { throw 'Fixture manifest identity mismatch' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
foreach ($file in $manifest.files.PSObject.Properties) {
    $path = [IO.Path]::GetFullPath((Join-Path (Join-Path $destination 'source') $file.Name))
    if (-not $path.StartsWith((Join-Path $destination 'source')+'\',[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Source manifest traversal'
    }
    if ((Hash $path) -cne $file.Value) { throw "Prepared source drift: $($file.Name)" }
}
# Reject source drift between preparation and this offline comparison.
foreach ($relative in @('tools/df03_compat/template_engine.py','ea_template/tests/DF03_ConversionCompat_Test.mq5',
                       'scripts/_test/run_df03_conversion_compat_tests.ps1')) {
    if ((Hash (Join-Path $RepoRoot $relative)) -cne $manifest.files.$relative) { throw 'Runner/fixture drift' }
}
$compiler = BoundFile $receipt.compiler
$terminal = BoundFile $receipt.terminal
if ($receipt.lane -cne 'MT5_PRIMARY' -or -not $receipt.reservation -or -not $receipt.data_directory) {
    throw 'Primary installation and CT reservation binding required'
}
if ($terminal -ine 'D:\Meta 5\terminal64.exe' -or (Split-Path $compiler -Parent) -ine 'D:\Meta 5') {
    throw 'Only the frozen primary installation is permitted'
}
foreach ($binding in @(@($compiler,$receipt.compiler),@($terminal,$receipt.terminal))) {
    $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($binding[0])
    if ($binding[1].build -isnot [int] -or $binding[1].build -le 0 -or
        @($version.FileBuildPart,$version.FilePrivatePart) -notcontains $binding[1].build) {
        throw 'Actual executable build differs from independently frozen identity'
    }
}
$roles = @('production','harness','explicit','implicit_test_control')
if (@($receipt.compiles).Count -ne 4) { throw 'Four fresh compile artifact bindings required' }
$products = @{}
foreach ($role in $roles) {
    $items = @($receipt.compiles | Where-Object { $_.role -ceq $role })
    if ($items.Count -ne 1) { throw "Missing/duplicate compile role: $role" }
    $item = $items[0]
    $relative = $manifest.targets.$role
    if ($item.source_sha256 -cne $manifest.files.$relative) { throw "Wrong compile source: $role" }
    $product = BoundFile $item.product
    $log = BoundFile $item.log
    if ([IO.Path]::GetExtension($product) -ine '.ex5') { throw 'EX5 product required' }
    $text = Get-Content -LiteralPath $log -Raw
    $sourcePath = [IO.Path]::GetFullPath((Join-Path (Join-Path $destination 'source') $relative))
    if ($product -ine [IO.Path]::ChangeExtension($sourcePath,'.ex5') -or
        $text.IndexOf(('information: compiling '+$sourcePath),[StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Compiler source/product path binding failed: $role"
    }
    $summary = [regex]::Matches($text,'(?im)\bResult:\s*(\d+) errors?,\s*(\d+) warnings?')
    $warnings = if ($role -ceq 'implicit_test_control') { 24 } else { 0 }
    if ($summary.Count -ne 1 -or [int]$summary[0].Groups[1].Value -ne 0 -or
        [int]$summary[0].Groups[2].Value -ne $warnings) { throw "Compile gate failed: $role" }
    $diagnostics = [regex]::Matches($text,'(?im)^([^\r\n]+)\((\d+),(\d+)\)\s*:\s*warning (\d+):\s*([^\r\n]+)')
    if ($diagnostics.Count -ne $warnings) { throw "Diagnostic count differs: $role" }
    if ($role -ceq 'implicit_test_control') {
        $seen = @{}
        foreach ($diagnostic in $diagnostics) {
            $line = [int]$diagnostic.Groups[2].Value
            $expected = @($manifest.oracle_warnings | Where-Object { $_.line -eq $line })
            if ($seen.ContainsKey($line) -or $expected.Count -ne 1 -or
                $diagnostic.Groups[1].Value -ine $sourcePath -or
                [int]$diagnostic.Groups[4].Value -ne $expected[0].code -or
                $diagnostic.Groups[5].Value.Trim() -cne $expected[0].message) {
                throw 'Unexpected or unbound oracle diagnostic'
            }
            $seen[$line] = $true
        }
    }
    $products[$role] = $item.product.sha256
}
if (@($receipt.runs).Count -ne 2) { throw 'Exactly two no-trade fixture logs required' }
$logs = @{}
foreach ($role in @('implicit_test_control','explicit')) {
    $items = @($receipt.runs | Where-Object { $_.role -ceq $role })
    if ($items.Count -ne 1 -or $items[0].product_sha256 -cne $products[$role]) {
        throw "Runtime product binding failed: $role"
    }
    $logs[$role] = BoundFile $items[0].log
}
$resultText = & $fixturePython -B $generator --compare-fixture $logs.implicit_test_control $logs.explicit
if ($LASTEXITCODE -ne 0) { throw 'BLOCK: incomplete or differing conversion observations' }
$result = $resultText | ConvertFrom-Json
if ($result.runtime_build -ne $receipt.terminal.build) { throw 'Runtime log/executable build differs' }
$evidence = [ordered]@{
    status = 'CONVERSION_DIFFERENTIAL_EQUAL_PENDING_CT_GATES'
    rows = $result.rows
    stage_b_receipt_sha256 = Hash (Resolve-Path -LiteralPath $StageBReceipt).Path
    fixture_manifest_sha256 = Hash $manifestPath
    compiler_sha256 = $receipt.compiler.sha256
    compiler_build = $receipt.compiler.build
    terminal_sha256 = $receipt.terminal.sha256
    terminal_build = $receipt.terminal.build
    production_acceptance = $false
}
[IO.File]::WriteAllText($output,($evidence | ConvertTo-Json -Depth 8)+"`n",(New-Object Text.UTF8Encoding($false)))
$evidence | ConvertTo-Json -Depth 8
