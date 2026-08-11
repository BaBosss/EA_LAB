<# Focused fail-closed tests for the versioned TPL baseline contract. #>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $RepoRoot 'scripts\lib\tpl_baseline.ps1')

$template = Join-Path ([IO.Path]::GetTempPath()) ('tpl_baseline_fixture_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $template | Out-Null
function New-Fixture {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('tpl_baseline_case_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force (Join-Path $dir 'ea_template\sets\regression') | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $dir 'ea_template\regression_reports\build6090') | Out-Null
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\Boss_*.mq5') | Copy-Item -Destination (Join-Path $dir 'ea_template')
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\sets\regression\*.set') | Copy-Item -Destination (Join-Path $dir 'ea_template\sets\regression')
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\regression_reports\build6090\*.htm') | Copy-Item -Destination (Join-Path $dir 'ea_template\regression_reports\build6090')
    Get-ChildItem (Join-Path $RepoRoot 'ea_template\regression_baseline*.json'), (Join-Path $RepoRoot 'ea_template\regression_baseline_build6090.csv') | Copy-Item -Destination (Join-Path $dir 'ea_template')
    return $dir
}
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Write-Json([string]$Path, [object]$Value) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false))) }
function Expect-Refusal([string]$Name, [scriptblock]$Mutate) {
    $dir = New-Fixture
    try {
        & $Mutate $dir
        $ok = $false; $message = ''
        try { Get-TplActiveBaseline -Root $dir -ActiveSelectorPath (Join-Path $dir 'ea_template\regression_baseline.active.json') | Out-Null }
        catch { $message = $_.Exception.Message; $ok = $true }
        if (-not $ok) { throw "FAIL: $Name unexpectedly passed" }
        Write-Host "[PASS] $Name :: $message"
    } finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

try {
    Expect-Refusal 'missing active manifest' { param($d) Remove-Item (Join-Path $d 'ea_template\regression_baseline.active.json') -Force }
    Expect-Refusal 'missing versioned metrics' { param($d) Remove-Item (Join-Path $d 'ea_template\regression_baseline_build6090.csv') -Force }
    Expect-Refusal 'corrupted metrics hash' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.csv'; $b=[IO.File]::ReadAllBytes($p); $b[20]=($b[20] -bxor 1); [IO.File]::WriteAllBytes($p,$b) }
    Expect-Refusal 'wrong MT5 build' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.expected_mt5_build=5836; Write-Json $p $m }
    Expect-Refusal 'Build-5836 report compared to Build-6090 reference' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].report_build=5836; Write-Json $p $m }
    Expect-Refusal 'wrong set hash' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].declared_set_sha256=('0'*64); Write-Json $p $m }
    Expect-Refusal 'undeclared set' { param($d) $set=Join-Path $d 'ea_template\sets\regression\Boss_11_GridTrend_defaults.set'; $lines=@(Get-Content $set | Where-Object { $_ -notmatch '^;\s*build=' }); [IO.File]::WriteAllLines($set,$lines); $hash=(Get-FileHash $set -Algorithm SHA256).Hash.ToLowerInvariant(); $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].declared_set_sha256=$hash; Write-Json $p $m }
    Expect-Refusal 'wrong source identity' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].source_commit='ac294d3a8f8e3a2b0dfa88860c2558e0646df6fb'; Write-Json $p $m }
    Expect-Refusal 'stale report' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].report_fresh=$false; Write-Json $p $m }
    Expect-Refusal 'tester contract mismatch' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.tester_contract.timeframe='M30'; Write-Json $p $m }
    Expect-Refusal 'missing EA' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases=@($m.cases | Select-Object -Skip 1); Write-Json $p $m }
    Expect-Refusal 'extra EA' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].ea='Boss_99_Extra'; Write-Json $p $m }
    Expect-Refusal 'malformed manifest' { param($d) [IO.File]::WriteAllText((Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'), '{not-json') }
    Expect-Refusal 'incomplete provenance' { param($d) $p=Join-Path $d 'ea_template\regression_baseline_build6090.manifest.json'; $m=Read-Json $p; $m.cases[0].report_sha256=$null; Write-Json $p $m }
    Write-Host 'TPL BASELINE NEGATIVE TESTS: 14/14 PASS' -ForegroundColor Green
    exit 0
} finally { Remove-Item -LiteralPath $template -Recurse -Force -ErrorAction SilentlyContinue }
