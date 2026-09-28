<# Real-path cage for the narrow declared historical-wrapper admission. No MT5 is invoked. #>
[CmdletBinding()]
param([string]$RepoRoot = '', [string]$EvidenceArchiveRoot = '', [switch]$PrecommitOnly)
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $RepoRoot 'scripts\lib\evidence.ps1')

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
$precommitRepo = Join-Path $fixture 'precommit-repo'
$precommitEvidence = Join-Path $fixture 'precommit-evidence'
$pass = 0
$testStatus = 1

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
function Invoke-PrecommitHarness([string]$Tree, [string]$IndexPath, [string]$Control = $controlCommit,
                                 [string]$Parent = '5845c4e039a3d9ef57e6997af42655a3d854d34e',
                                 [string[]]$Declared = $paths, [string]$EvidenceName = '') {
    if (-not $EvidenceName) { $EvidenceName = [guid]::NewGuid().ToString('N') }
    $quote = { param($v) "'" + ([string]$v).Replace("'","''") + "'" }
    $items = @($Declared | ForEach-Object { & $quote $_ }) -join ','
    $evidence = Join-Path $precommitEvidence $EvidenceName
    $command = '$env:GIT_INDEX_FILE=' + (& $quote $IndexPath) + ';' +
        '$env:GIT_CONFIG_COUNT=''1'';$env:GIT_CONFIG_KEY_0=''core.excludesfile'';$env:GIT_CONFIG_VALUE_0=' + (& $quote $emptyExclude) + ';' +
        '$p=@{ValidateOnly=$true;PrecommitExactTree=$true;ControlCommit=' + (& $quote $Control) +
        ';RepairParent=' + (& $quote $Parent) + ';SourceTree=' + (& $quote $Tree) +
        ';BehavioralDeltaPaths=@(' + $items + ');PrecommitEvidenceRoot=' + (& $quote $evidence) + '};& ' +
        (& $quote (Join-Path $precommitRepo 'scripts\tpl_regression.ps1')) + ' @p'
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
  if (-not $PrecommitOnly) {
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
  }

    # Repair1 precommit tree fixture. The candidate repository remains at the
    # frozen parent; only a disposable alternate index receives the exact
    # copied repair bytes and git write-tree creates the candidate identity.
    & git clone --quiet --no-local --no-checkout $RepoRoot $precommitRepo
    if ($LASTEXITCODE -ne 0) { throw 'precommit fixture clone failed' }
    & git -C $precommitRepo config core.longpaths true
    & git -C $precommitRepo config core.autocrlf false
    & git -C $precommitRepo checkout --quiet '5845c4e039a3d9ef57e6997af42655a3d854d34e'
    # Reuse the installed, ignored portable-Python stdlib archive. It is a
    # host runtime dependency, not a candidate-tree source byte.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'tools\python312\python312.zip') -Destination (Join-Path $precommitRepo 'tools\python312\python312.zip')
    $repairPaths = @(
        'ea_template/Boss_15_ST03.mq5',
        'ea_template/core/LabCore.mqh',
        'ea_template/core/MacroGate_Core.mqh',
        'ea_template/core/Execution.mqh',
        'scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1',
        'scripts/_test/macrogate_tester_transfer_probe.mq5',
        'scripts/_test/test_macrogate_tester_transfer_contract.py',
        'scripts/tpl_regression.ps1',
        'scripts/lib/tpl_baseline.ps1',
        'scripts/_test/run_tpl_declared_wrapper_tests.ps1'
    )
    foreach ($path in $repairPaths) {
        $target = Join-Path $precommitRepo ($path -replace '/','\')
        New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath (Join-Path $RepoRoot ($path -replace '/','\')) -Destination $target -Force
    }
    $baseIndex = Join-Path $fixture 'precommit-base.index'
    $env:GIT_INDEX_FILE = $baseIndex
    & git -C $precommitRepo read-tree HEAD
    & git -C $precommitRepo add -- $repairPaths
    $precommitTree = (& git -C $precommitRepo write-tree).Trim()
    Remove-Item Env:\GIT_INDEX_FILE
    if ($precommitTree -notmatch '^[0-9a-f]{40}$') { throw 'precommit fixture write-tree failed' }

    $positive = Invoke-PrecommitHarness $precommitTree $baseIndex $controlCommit '5845c4e039a3d9ef57e6997af42655a3d854d34e' $paths 'positive'
    if ($positive.ExitCode -ne 0 -or $positive.Output -notmatch 'PRECOMMIT EXACT TREE STRUCTURALLY READY') {
        throw "FAIL: exact precommit tree positive: $($positive.Output)"
    }
    $receipt = Get-Content -Raw (Join-Path $precommitEvidence 'positive\TPL_PRECOMMIT_EXACT_TREE_RECEIPT.json') | ConvertFrom-Json
    if ($receipt.status -ne 'VALIDATE_ONLY_PASS_RUNTIME_NOT_RUN' -or $receipt.source_tree -ne $precommitTree -or -not $receipt.materialized_root) {
        throw 'FAIL: precommit identity receipt plumbing'
    }
    $pass++; Write-Host '[PASS] exact staged tree is byte-materialized and identity-bound without a candidate commit'

    Expect-Refusal 'precommit rejects commit object as tree' { Invoke-PrecommitHarness '5845c4e039a3d9ef57e6997af42655a3d854d34e' $baseIndex } 'not a resolvable tree object'
    Expect-Refusal 'precommit rejects malformed tree hash' { Invoke-PrecommitHarness ('f' * 40) $baseIndex } 'not a resolvable tree object'
    Expect-Refusal 'precommit rejects wrong frozen control' { Invoke-PrecommitHarness $precommitTree $baseIndex '94f20ad4191b066253daaf101f28b0078f2a6805' } 'parent/control do not match'
    Expect-Refusal 'precommit rejects wrong frozen parent' { Invoke-PrecommitHarness $precommitTree $baseIndex $controlCommit $controlCommit } 'parent/control do not match'
    Expect-Refusal 'precommit rejects missing behavioral declaration' { Invoke-PrecommitHarness $precommitTree $baseIndex $controlCommit '5845c4e039a3d9ef57e6997af42655a3d854d34e' @($paths | Select-Object -First 3) } 'exactly four'
    Expect-Refusal 'precommit rejects case alias declaration' { Invoke-PrecommitHarness $precommitTree $baseIndex $controlCommit '5845c4e039a3d9ef57e6997af42655a3d854d34e' @('EA_TEMPLATE/Boss_15_ST03.mq5',$paths[1],$paths[2],$paths[3]) } 'not owner-frozen'
    Expect-Refusal 'precommit rejects traversal declaration' { Invoke-PrecommitHarness $precommitTree $baseIndex $controlCommit '5845c4e039a3d9ef57e6997af42655a3d854d34e' @('ea_template/core/../Boss_15_ST03.mq5',$paths[1],$paths[2],$paths[3]) } 'noncanonical literal'

    $stalePath = Join-Path $precommitRepo 'scripts\tpl_regression.ps1'
    [IO.File]::AppendAllText($stalePath,"`r`n# stale-after-write-tree")
    Expect-Refusal 'precommit rejects changed working bytes after write-tree' { Invoke-PrecommitHarness $precommitTree $baseIndex } 'working tree differs|working source bytes differ'
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\tpl_regression.ps1') -Destination $stalePath -Force

    $extraPath = Join-Path $precommitRepo 'scripts\UNDECLARED_PRECOMMIT_EXTRA.ps1'
    [IO.File]::WriteAllText($extraPath,'# undeclared source')
    Expect-Refusal 'precommit rejects undeclared untracked source path' { Invoke-PrecommitHarness $precommitTree $baseIndex } 'undeclared untracked path'
    Remove-Item -LiteralPath $extraPath -Force

    $staleIndex = Join-Path $fixture 'precommit-stale.index'
    Copy-Item -LiteralPath $baseIndex -Destination $staleIndex
    $env:GIT_INDEX_FILE = $staleIndex
    [IO.File]::AppendAllText((Join-Path $precommitRepo 'scripts\_test\test_macrogate_tester_transfer_contract.py'),"`n# staged-after-tree")
    & git -C $precommitRepo add -- scripts/_test/test_macrogate_tester_transfer_contract.py
    Remove-Item Env:\GIT_INDEX_FILE
    Expect-Refusal 'precommit rejects stale passed tree versus current index' { Invoke-PrecommitHarness $precommitTree $staleIndex } 'stale staged tree'
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'scripts\_test\test_macrogate_tester_transfer_contract.py') -Destination (Join-Path $precommitRepo 'scripts\_test\test_macrogate_tester_transfer_contract.py') -Force

    foreach ($tamper in @('ea_template/regression_baseline.active.json','ea_template/sets/regression/Boss_15_ST03_defaults.set')) {
        $tamperIndex = Join-Path $fixture ((Split-Path $tamper -Leaf) + '.index')
        Copy-Item -LiteralPath $baseIndex -Destination $tamperIndex
        $target = Join-Path $precommitRepo ($tamper -replace '/','\')
        [IO.File]::AppendAllText($target,"`r`n# forbidden precommit tamper")
        $env:GIT_INDEX_FILE = $tamperIndex
        & git -C $precommitRepo add -- $tamper
        $tamperTree = (& git -C $precommitRepo write-tree).Trim()
        Remove-Item Env:\GIT_INDEX_FILE
        Expect-Refusal "precommit rejects altered pinned $tamper" { Invoke-PrecommitHarness $tamperTree $tamperIndex } 'undeclared repair path'
        $original = Invoke-EvidenceGitBytes -RepoRoot $precommitRepo -Arguments ('show "HEAD:{0}"' -f $tamper)
        if ($original.ExitCode -ne 0) { throw "fixture restore failed: $tamper" }
        [IO.File]::WriteAllBytes($target,[byte[]]$original.Bytes)
    }

    Write-Host "TPL DECLARED WRAPPER TESTS: $pass/$pass PASS"
    $testStatus = 0
} catch {
    Write-Host ("[FAIL] " + $_.Exception.Message) -ForegroundColor Red
    $testStatus = 1
} finally {
    if ($EvidenceArchiveRoot -and (Test-Path -LiteralPath $precommitEvidence -PathType Container)) {
        $archiveFull = [IO.Path]::GetFullPath($EvidenceArchiveRoot)
        $repoFull = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\') + '\'
        if ($archiveFull.StartsWith($repoFull,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'EvidenceArchiveRoot must be outside the repository'
        }
        if (Test-Path -LiteralPath $archiveFull) { throw 'EvidenceArchiveRoot already exists' }
        New-Item -ItemType Directory -Path $archiveFull | Out-Null
        foreach ($receipt in @(Get-ChildItem -LiteralPath $precommitEvidence -Filter 'TPL_PRECOMMIT_EXACT_TREE_RECEIPT.json' -File -Recurse -ErrorAction SilentlyContinue)) {
            $relative = $receipt.FullName.Substring(([IO.Path]::GetFullPath($precommitEvidence).TrimEnd('\') + '\').Length)
            $target = Join-Path $archiveFull $relative
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath $receipt.FullName -Destination $target
        }
    }
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'tpl_declared_wrapper_*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if ($testStatus -ne 0) { [Environment]::Exit(1) }
[Environment]::Exit(0)
