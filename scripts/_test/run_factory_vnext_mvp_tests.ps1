[CmdletBinding()]
param(
  [string]$RepoRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent),
  [string]$PythonExe
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

if ([string]::IsNullOrWhiteSpace($PythonExe)) {
  . (Join-Path $RepoRoot 'scripts\use_python.ps1')
  $PythonExe = Assert-PortablePython -Root $RepoRoot
}
if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
  throw "PythonExe not found: $PythonExe"
}
$probe = @(& $PythonExe -c 'import encodings; print(31210)' 2>&1)
if ($LASTEXITCODE -ne 0 -or ($probe -join "`n") -notmatch '31210') {
  throw "PythonExe is unusable: $PythonExe :: $($probe -join ' ')"
}

$fixtureRoot = Join-Path $RepoRoot 'scripts\_test\fixtures\factory_vnext'
$tests = @(Get-ChildItem -LiteralPath $fixtureRoot -File -Filter 'test_*.py' | Sort-Object Name)
if ($tests.Count -lt 1) { throw 'Factory vNext test fixture set is empty' }
foreach ($test in $tests) {
  Write-Host ("[RUN] " + $test.Name)
  & $PythonExe $test.FullName
  if ($LASTEXITCODE -ne 0) { throw "Factory vNext test failed: $($test.Name) exit=$LASTEXITCODE" }
}

$modules = @(
  '_triage\factory_vnext\contracts.py',
  '_triage\factory_vnext\architecture.py'
) | ForEach-Object { Join-Path $RepoRoot $_ }
& $PythonExe -m py_compile @modules
if ($LASTEXITCODE -ne 0) { throw "Factory vNext py_compile failed exit=$LASTEXITCODE" }

Write-Host ("[PASS] Factory vNext MVP focused suite files=" + $tests.Count)
exit 0
