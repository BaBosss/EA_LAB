<# Real-path cage for the narrow declared historical-wrapper admission. No MT5 is invoked. #>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$sourceCommit = '94f20ad4191b066253daaf101f28b0078f2a6805'
$controlCommit = 'b586d4d32c04fa33a30517ab3a1a8469b238d2ac'
$paths = @(
    'ea_template/Boss_15_ST03.mq5',
    'ea_template/core/Execution.mqh',
    'ea_template/core/LabCore.mqh',
    'ea_template/core/MacroGate_Core.mqh'
)
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('tpl_declared_wrapper_' + [guid]::NewGuid().ToString('N'))
$harness = Join-Path $fixture 'harness'
$source = Join-Path $fixture 'source'
$emptyExclude = Join-Path $fixture 'empty-global-excludes'
$pass = 0

function Invoke-EncodedHarness([string]$Command) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    $id = [guid]::NewGuid().ToString('N')
    $stdout = Join-Path $fixture ($id + '.stdout.log')
    $stderr = Join-Path $fixture ($id + '.stderr.log')
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoLogo','-NoProfile','-EncodedCommand',$encoded) -RedirectStandardOutput $stdout -RedirectStandardError $stderr -Wait -PassThru -WindowStyle Hidden
    $output = @((Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue),(Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)) -join "`n"
    return [pscustomobject]@{ ExitCode=$proc.ExitCode; Output=$output }
}

function Invoke-Harness([string]$SourceRoot, [string]$Control = $controlCommit, [string]$SourceRef = $sourceCommit, [string[]]$Declared = $paths) {
    $quote = { param($v) "'" + ([string]$v).Replace("'","''") + "'" }
    $items = @($Declared | ForEach-Object { & $quote $_ }) -join ','
    $command = '$env:GIT_CONFIG_COUNT=''1'';$env:GIT_CONFIG_KEY_0=''core.excludesfile'';$env:GIT_CONFIG_VALUE_0=' + (& $quote $emptyExclude) + ';' +
        '$p=@{ValidateOnly=$true;DeclaredCoreDelta=$true;ControlCommit=' + (& $quote $Control) +
        ';SourceCommit=' + (& $quote $SourceRef) + ';BehavioralDeltaPaths=@(' + $items + ');SourceRoot=' +
        (& $quote $SourceRoot) + '};& ' + (& $quote (Join-Path $harness 'scripts\tpl_regression.ps1')) + ' @p'
    return Invoke-EncodedHarness $command
}
function Expect-Pass([string]$Name, [scriptblock]$Run) {
    $result = & $Run
    if ($result.ExitCode -ne 0) { throw "FAIL: $Name exit=$($result.ExitCode) output=$($result.Output)" }
    $script:pass++; Write-Host "[PASS] $Name"
}
function Expect-Refusal([string]$Name, [scriptblock]$Run, [string]$Pattern) {
    $result = & $Run
    if ($result.ExitCode -eq 0 -or $result.Output -notmatch $Pattern) { throw "FAIL: $Name expected '$Pattern', exit=$($result.ExitCode) output=$($result.Output)" }
    $script:pass++; Write-Host "[PASS] $Name :: $($result.Output.Trim())"
}

New-Item -ItemType Directory -Force $fixture | Out-Null
[IO.File]::WriteAllText($emptyExclude,'')
try {
    & git clone --quiet --no-local --no-checkout $RepoRoot $harness
    if ($LASTEXITCODE -ne 0) { throw 'fixture clone failed' }
    & git -C $harness config core.longpaths true
    & git -C $harness config core.autocrlf false
    & git -C $harness checkout --quiet $sourceCommit
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\tpl_regression.ps1') -Destination (Join-Path $harness 'scripts\tpl_regression.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\tpl_baseline.ps1') -Destination (Join-Path $harness 'scripts\lib\tpl_baseline.ps1') -Force
    & git -C $harness config user.name 'TPL wrapper cage'
    & git -C $harness config user.email 'tpl-wrapper@example.invalid'
    & git -C $harness add -- scripts/tpl_regression.ps1 scripts/lib/tpl_baseline.ps1
    & git -C $harness commit --quiet -m 'fixture harness child'
    if ($LASTEXITCODE -ne 0) { throw 'fixture harness commit failed' }
    & git -C $harness worktree add --quiet --detach $source $sourceCommit
    if ($LASTEXITCODE -ne 0) { throw 'fixture source worktree failed' }

    $legacyCommand = "`$env:GIT_CONFIG_COUNT='1';`$env:GIT_CONFIG_KEY_0='core.excludesfile';`$env:GIT_CONFIG_VALUE_0='" + $emptyExclude.Replace("'","''") + "';& '" + (Join-Path $harness 'scripts\tpl_regression.ps1').Replace("'","''") + "' -ValidateOnly"
    $legacy = Invoke-EncodedHarness $legacyCommand
    if ($legacy.ExitCode -eq 0 -or $legacy.Output -notmatch 'source hash mismatch') { throw 'FAIL: default mode no longer byte-pins the wrapper baseline' }
    $pass++; Write-Host '[PASS] default mode still rejects the 94f wrapper'

    Expect-Pass 'declared mode admits exact 94f/b586 through SourceRoot' { Invoke-Harness $source }
    Expect-Refusal 'wrong control is rejected' { Invoke-Harness $source $sourceCommit } 'expected wrapper identity|single immediate parent'
    Expect-Refusal 'undeclared wrapper is rejected' { Invoke-Harness $source $controlCommit $sourceCommit @($paths | Where-Object { $_ -ne 'ea_template/Boss_15_ST03.mq5' }) } 'source hash mismatch'
    Expect-Refusal 'duplicate declaration is rejected' { Invoke-Harness $source $controlCommit $sourceCommit @($paths + $paths[0]) } 'duplicate behavioral declaration'
    Expect-Refusal 'case alias is rejected' { Invoke-Harness $source $controlCommit $sourceCommit @('EA_TEMPLATE/BOSS_15_ST03.MQ5') } 'source hash mismatch|case-aliased'
    Expect-Refusal 'malicious traversal is rejected' { Invoke-Harness $source $controlCommit $sourceCommit @($paths + 'ea_template/core/../core/LabCore.mqh') } 'noncanonical literal'
    Expect-Refusal 'SourceRoot identity mismatch is rejected' { Invoke-Harness $harness } 'SourceRoot HEAD must equal exact SourceCommit'

    [IO.File]::WriteAllText((Join-Path $source 'dirty.txt'),'dirty')
    Expect-Refusal 'dirty SourceRoot is rejected' { Invoke-Harness $source } 'SourceRoot must be completely clean'
    Remove-Item -LiteralPath (Join-Path $source 'dirty.txt') -Force

    $other = Join-Path $fixture 'other-repository'
    & git clone --quiet --no-local --no-checkout $RepoRoot $other
    & git -C $other config core.longpaths true
    & git -C $other config core.autocrlf false
    & git -C $other checkout --quiet $sourceCommit
    Expect-Refusal 'different repository SourceRoot is rejected' { Invoke-Harness $other } 'same-repository checkout'

    $tampered = Join-Path $fixture 'tampered-source'
    & git -C $harness worktree add --quiet --detach $tampered $sourceCommit
    $manifestPath = Join-Path $tampered 'ea_template\regression_baseline_build6090.manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $case = @($manifest.cases | Where-Object source_path -eq 'ea_template/Boss_15_ST03.mq5')[0]
    $case.source_sha256 = ('0' * 64)
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
    & git -C $tampered add -- ea_template/regression_baseline_build6090.manifest.json
    & git -C $tampered -c user.name='TPL wrapper cage' -c user.email='tpl-wrapper@example.invalid' commit --quiet -m 'tampered expected wrapper hash'
    $tamperedCommit = (& git -C $tampered rev-parse HEAD).Trim()
    Expect-Refusal 'tampered expected wrapper hash is rejected from exact Git bytes' { Invoke-Harness $tampered $controlCommit $tamperedCommit } 'expected wrapper identity'

    $legacyControl = Join-Path $fixture 'legacy-control'
    & git -C $harness worktree add --quiet --detach $legacyControl $controlCommit
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\tpl_regression.ps1') -Destination (Join-Path $legacyControl 'scripts\tpl_regression.ps1') -Force
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\lib\tpl_baseline.ps1') -Destination (Join-Path $legacyControl 'scripts\lib\tpl_baseline.ps1') -Force
    $legacySuiteCommand = "`$env:GIT_CONFIG_COUNT='1';`$env:GIT_CONFIG_KEY_0='core.excludesfile';`$env:GIT_CONFIG_VALUE_0='" + $emptyExclude.Replace("'","''") + "';& '" +
        (Join-Path $legacyControl 'scripts\_test\run_tpl_baseline_negative_tests.ps1').Replace("'","''") + "' -RepoRoot '" + $legacyControl.Replace("'","''") + "'"
    $legacySuite = Invoke-EncodedHarness $legacySuiteCommand
    if ($legacySuite.ExitCode -ne 0 -or $legacySuite.Output -notmatch 'TPL DECLARED DELTA TESTS:') { throw "FAIL: existing baseline negative suite on byte-pinned control: $($legacySuite.Output)" }
    $pass++; Write-Host '[PASS] existing baseline negative/declared-delta suite remains green on byte-pinned control'

    Write-Host "TPL DECLARED WRAPPER TESTS: $pass/$pass PASS"
    exit 0
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'tpl_declared_wrapper_*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}
