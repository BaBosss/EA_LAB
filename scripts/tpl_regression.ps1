<#
tpl_regression.ps1 - versioned, fail-closed Boss V2 regression cage.

The active selector names a Build-6090 provenance manifest.  The historical
ea_template\regression_baseline.csv is retained as Build-5836 evidence only and
is never loaded as a comparator.
#>
[CmdletBinding()]
param(
    [string]$Symbol = 'XAUUSD',
    [string]$Period = 'H1',
    [string]$FromDate = '2024.01.01',
    [string]$ToDate = '2024.07.01',
    [int]$Model = 1,
    [string]$Terminal = 'D:\Meta 5\terminal64.exe',
    [string]$DataDir = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
    [switch]$Portable,
    [switch]$ValidateOnly,
    [string]$ActiveSelectorPath = '',
    [string]$AdjacentControlRef = '',
    [switch]$DeclaredCoreDelta,
    [switch]$PrecommitExactTree,
    [string]$ControlCommit = '',
    [string]$SourceCommit = '',
    [string]$SourceTree = '',
    [string]$RepairParent = '',
    [string[]]$BehavioralDeltaPaths = @(),
    [string]$SourceRoot = '',
    [string]$PrecommitEvidenceRoot = ''
)

$ErrorActionPreference = 'Stop'
$invocationRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$harnessRoot = $invocationRoot
$gitRoot = $invocationRoot
$root = $harnessRoot
$precommitMaterialization = ''
$precommitReceiptPath = ''
$precommitExtractorScript = ''
$precommitExtractorSha256 = ''

. (Join-Path $invocationRoot 'scripts\lib\tpl_baseline.ps1')

function New-TplPrecommitMaterialization([string]$Repo, [string]$Tree, [string]$EvidenceRoot) {
    $destination = Join-Path $EvidenceRoot ('tree_' + $Tree.Substring(0,12))
    $archive = $destination + '.zip'
    $evidencePrefix = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\') + '\'
    if (-not [IO.Path]::GetFullPath($destination).StartsWith($evidencePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'REFUSE: unsafe precommit materialization path'
    }
    New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null
    if ((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath $archive)) {
        throw 'REFUSE: precommit materialization target already exists'
    }
    & git -C $Repo -c core.longpaths=true archive --format=zip --output=$archive $Tree
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        throw 'REFUSE: could not export SourceTree'
    }
    New-Item -ItemType Directory -Path $destination | Out-Null
    $script:precommitExtractorScript = Join-Path $EvidenceRoot 'extract_git_tree.py'
    $extractor = @'
import os
import pathlib
import sys
import zipfile

archive, destination = sys.argv[1:3]
root = os.path.abspath(destination)
root_long = "\\\\?\\" + root
with zipfile.ZipFile(archive, "r") as source:
    for entry in source.infolist():
        name = entry.filename
        pure = pathlib.PurePosixPath(name)
        if pure.is_absolute() or not pure.parts or any(part in ("", ".", "..") for part in pure.parts):
            raise SystemExit("unsafe archive member: " + name)
        target = os.path.join(root_long, *pure.parts)
        if entry.is_dir():
            os.makedirs(target, exist_ok=True)
            continue
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with source.open(entry, "r") as reader, open(target, "wb") as writer:
            while True:
                block = reader.read(1024 * 1024)
                if not block:
                    break
                writer.write(block)
'@
    [IO.File]::WriteAllText($script:precommitExtractorScript,$extractor,[Text.UTF8Encoding]::new($false))
    $script:precommitExtractorSha256 = Get-TplSha256 $script:precommitExtractorScript
    . (Join-Path $invocationRoot 'scripts\use_python.ps1')
    $extractPython = Assert-PortablePython -Root $invocationRoot -Provision
    try {
        & $extractPython $script:precommitExtractorScript $archive $destination
        if ($LASTEXITCODE -ne 0) { throw 'REFUSE: could not extract SourceTree archive' }
    } finally {
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    }
    return $destination
}

function Write-TplPrecommitReceipt([object]$Value) {
    if (-not $PrecommitEvidenceRoot) { return }
    if (-not (Test-Path -LiteralPath $PrecommitEvidenceRoot -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $PrecommitEvidenceRoot | Out-Null
    }
    $script:precommitReceiptPath = Join-Path $PrecommitEvidenceRoot 'TPL_PRECOMMIT_EXACT_TREE_RECEIPT.json'
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $script:precommitReceiptPath -Encoding UTF8
}

function Invoke-TplCompile([string]$SourceRoot, [string]$Label) {
    & (Join-Path $SourceRoot 'ea_template\deploy.ps1') -Compile | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "REFUSE: $Label source compile failed" }
}

function Invoke-TplRegressionCase([object]$Case, [string]$SetPath, [string]$RunLabel, [string]$BuildReceiptRegistry) {
    $runStart = Get-Date
    $reportName = if ($RunLabel) { 'TPLREG_' + $RunLabel + '_' + $Case.ea } else { 'TPLREG_' + $Case.ea }
    $runArgs = @{
        Expert = 'EALabTpl\' + $Case.ea
        Symbol = $Symbol
        Period = $Period
        FromDate = $FromDate
        ToDate = $ToDate
        Model = $Model
        ReportName = $reportName
        SetFile = $SetPath
        Terminal = $Terminal
        DataDir = $DataDir
        Deposit = 10000
        Leverage = 100
        BuildReceiptRegistry = $BuildReceiptRegistry
    }
    if ($Portable) { $runArgs.Portable = $true }
    $runnerOutput = & (Join-Path $harnessRoot 'scripts\mt5_run.ps1') @runArgs 2>&1
    $runnerExit = $LASTEXITCODE
    $runnerOutput | ForEach-Object { Write-Host $_ }
    $reportPath = Join-Path $harnessRoot ('_mt5_auto\reports\' + $reportName + '.htm')
    if (-not (Test-ReportIsFresh -Htm $reportPath -RunStart $runStart -RunnerExit $runnerExit -Label $Case.ea)) { throw "REFUSE: $($Case.ea) stale report" }
    $json = & $py $parser $reportPath --json
    if ($LASTEXITCODE -ne 0) { throw "REFUSE: $($Case.ea) report parse failed" }
    $report = $json | ConvertFrom-Json
    if ([int]$report.report_build -ne 6090) { throw "NONCOMPARABLE: $($Case.ea) report Build $($report.report_build), expected 6090" }
    if ($report.symbol -ne $Symbol -or $report.period -ne $Period -or $report.from_date -ne $FromDate -or $report.to_date -ne $ToDate -or [int]$report.initial_deposit -ne 10000 -or $report.currency -ne 'USD' -or $report.leverage -ne '1:100') { throw "REFUSE: $($Case.ea) tester contract mismatch" }
    return [pscustomobject]@{
        ea = [string]$Case.ea
        net = ('{0:F2}' -f [double]$report.net_profit)
        pf = ('{0:F2}' -f [double]$report.profit_factor)
        trades = ('{0:0}' -f [double]$report.total_trades)
        eqdd = ('{0:F2}({1:F2}%)' -f [double]$report.equity_drawdown_maximal_abs, [double]$report.equity_drawdown_maximal_pct)
    }
}

function Assert-TplMetricMatch([object]$Expected, [object]$Actual, [string]$ExpectedLabel, [string]$ActualLabel) {
    if ($Expected.net -ne $Actual.net -or $Expected.pf -ne $Actual.pf -or $Expected.trades -ne $Actual.trades -or $Expected.eqdd -ne $Actual.eqdd) {
        Write-Host ("[DRIFT] {0}: {1} net={2} pf={3} trades={4} eqdd={5}; {6} net={7} pf={8} trades={9} eqdd={10}" -f $Actual.ea,$ExpectedLabel,$Expected.net,$Expected.pf,$Expected.trades,$Expected.eqdd,$ActualLabel,$Actual.net,$Actual.pf,$Actual.trades,$Actual.eqdd) -ForegroundColor Red
        return $false
    }
    return $true
}

try {
    $precommitNames = @('PrecommitExactTree','SourceTree','RepairParent','PrecommitEvidenceRoot')
    $precommitExplicit = @($precommitNames | Where-Object { $PSBoundParameters.ContainsKey($_) }).Count -gt 0
    $explicitDelta = @('DeclaredCoreDelta','ControlCommit','SourceCommit','BehavioralDeltaPaths') | Where-Object { $PSBoundParameters.ContainsKey($_) }
    $useDeclaredDelta = (@($explicitDelta).Count -gt 0) -and -not $PrecommitExactTree
    if ($PrecommitExactTree) {
        if ($DeclaredCoreDelta -or $SourceCommit -or $AdjacentControlRef -or $SourceRoot) {
            throw 'REFUSE: precommit exact-tree mode cannot mix with commit/legacy/SourceRoot admission'
        }
        if (-not $SourceTree -or -not $RepairParent -or -not $ControlCommit -or @($BehavioralDeltaPaths).Count -eq 0 -or -not $PrecommitEvidenceRoot) {
            throw 'REFUSE: precommit exact-tree mode requires SourceTree, RepairParent, ControlCommit, BehavioralDeltaPaths and PrecommitEvidenceRoot'
        }
        if ($SourceTree -cnotmatch '^[0-9a-f]{40}$' -or $RepairParent -cnotmatch '^[0-9a-f]{40}$' -or $ControlCommit -cnotmatch '^[0-9a-f]{40}$') {
            throw 'REFUSE: precommit identities must be exact lowercase 40-hex object IDs'
        }
        if ($RepairParent -cne '5845c4e039a3d9ef57e6997af42655a3d854d34e' -or
            $ControlCommit -cne 'b586d4d32c04fa33a30517ab3a1a8469b238d2ac') {
            throw 'REFUSE: precommit exact-tree parent/control do not match the owner-frozen Repair1 lineage'
        }
        $evidenceFull = [IO.Path]::GetFullPath($PrecommitEvidenceRoot).TrimEnd('\')
        $repoFull = [IO.Path]::GetFullPath($invocationRoot).TrimEnd('\')
        if (-not [IO.Path]::IsPathRooted($PrecommitEvidenceRoot) -or
            $evidenceFull.StartsWith($repoFull + '\',[StringComparison]::OrdinalIgnoreCase) -or
            $evidenceFull -ieq $repoFull) {
            throw 'REFUSE: PrecommitEvidenceRoot must be an absolute external path outside the candidate repository'
        }
        $sourceObject = Assert-TplTreeIdentity $gitRoot $SourceTree 'SourceTree'
        $sourceEntries = Get-TplTree $gitRoot $sourceObject
        $expectedBehavioral = @(
            'ea_template/Boss_15_ST03.mq5',
            'ea_template/core/LabCore.mqh',
            'ea_template/core/MacroGate_Core.mqh',
            'ea_template/core/Execution.mqh'
        )
        if (@($BehavioralDeltaPaths).Count -ne 4) { throw 'REFUSE: precommit admission requires exactly four behavioral delta paths' }
        foreach ($path in $BehavioralDeltaPaths) {
            Assert-TplLiteralPath $path
            if ($expectedBehavioral -cnotcontains $path) { throw "REFUSE: precommit behavioral declaration is not owner-frozen: $path" }
        }
        foreach ($path in $expectedBehavioral) {
            if (@($BehavioralDeltaPaths | Where-Object { $_ -ceq $path }).Count -ne 1) { throw "REFUSE: missing or duplicate owner-frozen behavioral declaration: $path" }
        }
        $earlyAllowed = @($expectedBehavioral + @(
            'scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1',
            'scripts/_test/macrogate_tester_transfer_probe.mq5',
            'scripts/_test/test_macrogate_tester_transfer_contract.py',
            'scripts/tpl_regression.ps1',
            'scripts/lib/tpl_baseline.ps1',
            'scripts/_test/run_tpl_declared_wrapper_tests.ps1'
        ))
        $earlyIndexTree = (& git -C $gitRoot write-tree 2>$null).Trim()
        if ($LASTEXITCODE -ne 0 -or $earlyIndexTree -cne $sourceObject) { throw 'REFUSE: stale staged tree; git write-tree differs from SourceTree' }
        & git -C $gitRoot diff --quiet -- 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'REFUSE: working tree differs from the exact staged SourceTree' }
        $untracked = @(& git -C $gitRoot ls-files --others --exclude-standard 2>$null)
        if ($LASTEXITCODE -ne 0 -or $untracked.Count -ne 0) { throw "REFUSE: undeclared untracked path outside SourceTree: $($untracked -join ', ')" }
        $earlyChanges = @(& git -C $gitRoot diff-tree --no-commit-id --no-renames --name-only -r $RepairParent $sourceObject 2>$null)
        if ($LASTEXITCODE -ne 0 -or $earlyChanges.Count -eq 0) { throw 'REFUSE: cannot establish RepairParent-to-SourceTree delta' }
        foreach ($path in $earlyChanges) {
            if ($earlyAllowed -cnotcontains $path) { throw "REFUSE: SourceTree changes an undeclared repair path: $path" }
            if (-not $sourceEntries.ContainsKey($path)) { throw "REFUSE: Repair1 deletion is not admitted: $path" }
            Assert-TplDiskIdentity -Root $invocationRoot -Path $path -Entry $sourceEntries[$path] -GitRoot $gitRoot
        }
        $harnessPaths = @(
            'scripts/tpl_regression.ps1',
            'scripts/lib/tpl_baseline.ps1',
            'scripts/lib/evidence.ps1',
            'scripts/lib/report_freshness.ps1',
            'scripts/lib/setfile_surface.ps1',
            'scripts/use_python.ps1',
            'scripts/parse_mt5_report.py',
            'scripts/mt5_run.ps1'
        )
        foreach ($path in $harnessPaths) {
            if (-not $sourceEntries.ContainsKey($path)) { throw "REFUSE: SourceTree omits runtime harness path: $path" }
            Assert-TplDiskIdentity -Root $invocationRoot -Path $path -Entry $sourceEntries[$path] -GitRoot $gitRoot
        }
        foreach ($path in $sourceEntries.Keys) {
            Assert-TplSafeTreePath $path
            $entry=$sourceEntries[$path]
            if ($entry.Type -ne 'blob' -or $entry.Mode -notin @('100644','100755')) {
                throw "REFUSE: symlink/submodule/nonregular entry in SourceTree: $path"
            }
        }
        $precommitMaterialization = New-TplPrecommitMaterialization -Repo $gitRoot -Tree $sourceObject -EvidenceRoot $PrecommitEvidenceRoot
        $root = $precommitMaterialization
        $harnessRoot = $precommitMaterialization
        . (Join-Path $harnessRoot 'scripts\lib\tpl_baseline.ps1')
    } elseif ($precommitExplicit) {
        throw 'REFUSE: partial precommit exact-tree arguments are not admitted'
    }
    if ($PSBoundParameters.ContainsKey('SourceRoot') -and -not $useDeclaredDelta) { throw 'REFUSE: SourceRoot is usable only with explicit DeclaredCoreDelta' }
    if ($useDeclaredDelta) {
        if (-not $DeclaredCoreDelta -or $PSBoundParameters.ContainsKey('AdjacentControlRef')) { throw 'REFUSE: declared delta requires explicit mode and cannot mix with legacy AdjacentControlRef' }
        if ($SourceRoot) {
            $root = (Resolve-Path -LiteralPath $SourceRoot).Path
            $sourceTop = (& git -C $root rev-parse --show-toplevel 2>$null)
            if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath(([string]$sourceTop).Trim()) -ine $root) { throw 'REFUSE: SourceRoot must be an exact repository root' }
            $sourceHead = (& git -C $root rev-parse HEAD 2>$null)
            if ($LASTEXITCODE -ne 0 -or ([string]$sourceHead).Trim() -cne $SourceCommit) { throw 'REFUSE: SourceRoot HEAD must equal exact SourceCommit' }
            function Get-CommonGitDirectory([string]$Repo) {
                $value = (& git -C $Repo rev-parse --git-common-dir 2>$null)
                if ($LASTEXITCODE -ne 0 -or -not $value) { throw 'REFUSE: repository common directory unavailable' }
                $path = ([string]$value).Trim()
                if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $Repo $path }
                return [IO.Path]::GetFullPath($path).TrimEnd('\')
            }
            if ((Get-CommonGitDirectory $root) -ine (Get-CommonGitDirectory $harnessRoot)) { throw 'REFUSE: SourceRoot must be a same-repository checkout' }
            $dirty = @(& git -C $root status --porcelain --untracked-files=all 2>$null)
            if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) { throw 'REFUSE: SourceRoot must be completely clean' }
        }
        if ($ActiveSelectorPath -and $ActiveSelectorPath -cne (Join-Path $root 'ea_template\regression_baseline.active.json')) {
            throw 'REFUSE: declared delta requires the canonical baseline selector path'
        }
    }
    $baselineArgs = @{ Root=$root; ActiveSelectorPath=$ActiveSelectorPath }
    if ($useDeclaredDelta) { $baselineArgs.DeclaredCoreDelta=$true; $baselineArgs.ControlCommit=$ControlCommit; $baselineArgs.SourceCommit=$SourceCommit; $baselineArgs.BehavioralDeltaPaths=$BehavioralDeltaPaths }
    if ($PrecommitExactTree) { $baselineArgs.GitRoot=$gitRoot; $baselineArgs.PrecommitExactTree=$true; $baselineArgs.ControlCommit=$ControlCommit; $baselineArgs.SourceTree=$SourceTree; $baselineArgs.BehavioralDeltaPaths=$BehavioralDeltaPaths }
    $baseline = Get-TplActiveBaseline @baselineArgs
    if ($PrecommitExactTree) {
        $allowedRepairPaths = @(
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
        $precommitContract = Assert-TplPrecommitExactTreeContract -GitRoot $gitRoot -SourceRoot $root -Baseline $baseline -ControlCommit $ControlCommit -RepairParent $RepairParent -SourceTree $SourceTree -BehavioralDeltaPaths $BehavioralDeltaPaths -AllowedRepairPaths $allowedRepairPaths
        $sourceCommit = $SourceTree
        $controlCommit = $ControlCommit
        $harnessCommit = (& git -C $gitRoot rev-parse HEAD 2>$null).Trim()
        $harnessTree = (& git -C $gitRoot rev-parse 'HEAD^{tree}' 2>$null).Trim()
        $harnessFiles = @($harnessPaths | ForEach-Object {
            [ordered]@{
                path=$_
                tree_blob=$sourceEntries[$_].Blob
                invocation_sha256=(Get-TplSha256 (Join-Path $invocationRoot ($_ -replace '/','\')))
                materialized_sha256=(Get-TplSha256 (Join-Path $precommitMaterialization ($_ -replace '/','\')))
            }
        })
        Write-TplPrecommitReceipt ([ordered]@{
            schema='tpl_precommit_exact_tree_receipt/1'; status='IDENTITY_VALIDATED_RUNTIME_PENDING'
            source_identity_kind='GIT_TREE'; source_tree=$SourceTree; repair_parent=$RepairParent; control_commit=$ControlCommit
            materialized_root=$precommitMaterialization; materialized_entry_count=$precommitContract.EntryCount
            changed_paths=@($precommitContract.ChangedPaths); harness_identity_kind='SOURCE_TREE_FILE_SET'
            harness_source_tree=$SourceTree; harness_invocation_head=$harnessCommit; harness_invocation_tree=$harnessTree
            harness_files=$harnessFiles; extractor_script=$precommitExtractorScript; extractor_sha256=$precommitExtractorSha256
            validate_only=[bool]$ValidateOnly; timestamp_utc=(Get-Date).ToUniversalTime().ToString('o')
        })
    } elseif ($useDeclaredDelta) {
        $sourceCommit = Assert-TplSourceContract -Root $root -Baseline $baseline -DeclaredCoreDelta -ControlCommit $ControlCommit -SourceCommit $SourceCommit -BehavioralDeltaPaths $BehavioralDeltaPaths
        $controlCommit = $ControlCommit
    } elseif ($AdjacentControlRef) {
        $sourceCommit = Assert-TplSourceContract -Root $root -Baseline $baseline -AdjacentControlRef $AdjacentControlRef -RegisteredUnbaselinedEas @($baseline.RegisteredUnbaselinedEas)
        $controlCommit = Assert-TplCommitIdentity -Root $root -Sha $AdjacentControlRef -Label 'AdjacentControlRef'
    } else {
        $sourceCommit = Assert-TplSourceContract -Root $root -Baseline $baseline
    }
    $harnessCommit = (& git -C $gitRoot rev-parse HEAD 2>$null)
    $harnessTree = (& git -C $gitRoot rev-parse 'HEAD^{tree}' 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $harnessCommit -or -not $harnessTree) { throw 'REFUSE: harness identity unavailable' }
    Write-Host ("[IDENTITY] harness={0} harness_tree={1} source_root={2} source={3} control={4}" -f ([string]$harnessCommit).Trim(),([string]$harnessTree).Trim(),$root,$sourceCommit,$controlCommit) -ForegroundColor Cyan
    $contract = $baseline.Manifest.tester_contract
    if ($Symbol -ne $contract.symbol -or $Period -ne $contract.timeframe -or $FromDate -ne $contract.date_from -or $ToDate -ne $contract.date_to -or $Model -ne [int]$contract.model) {
        throw 'REFUSE: requested tester contract does not match the active Build-6090 baseline'
    }
    if ($ValidateOnly) {
        if ($PrecommitExactTree) {
            Write-TplPrecommitReceipt ([ordered]@{
                schema='tpl_precommit_exact_tree_receipt/1'; status='VALIDATE_ONLY_PASS_RUNTIME_NOT_RUN'
                source_identity_kind='GIT_TREE'; source_tree=$SourceTree; repair_parent=$RepairParent; control_commit=$ControlCommit
                materialized_root=$precommitMaterialization; materialized_entry_count=$precommitContract.EntryCount
                changed_paths=@($precommitContract.ChangedPaths); harness_identity_kind='SOURCE_TREE_FILE_SET'
                harness_source_tree=$SourceTree; harness_invocation_head=([string]$harnessCommit).Trim(); harness_invocation_tree=([string]$harnessTree).Trim()
                harness_files=$harnessFiles; extractor_script=$precommitExtractorScript; extractor_sha256=$precommitExtractorSha256
                validate_only=$true; timestamp_utc=(Get-Date).ToUniversalTime().ToString('o')
            })
            Write-Host "=== PRECOMMIT EXACT TREE STRUCTURALLY READY; FULL RUNTIME CONTROL+CURRENT RUN REQUIRED (control $controlCommit, tree $sourceCommit) ===" -ForegroundColor Yellow
        } elseif ($AdjacentControlRef -or $useDeclaredDelta) {
            Write-Host "=== ADJACENT CONTROL STRUCTURALLY READY; RUNTIME CONTROL+CURRENT RUN REQUIRED (control $controlCommit, source $sourceCommit) ===" -ForegroundColor Yellow
        } else {
            Write-Host "=== BASELINE CONTRACT CLEAN (Build 6090, source $sourceCommit) ===" -ForegroundColor Green
        }
        exit 0
    }

    if (-not (Test-Path -LiteralPath $Terminal -PathType Leaf)) { throw "REFUSE: terminal not found: $Terminal" }
    . (Join-Path $harnessRoot 'scripts\lib\report_freshness.ps1')
    . (Join-Path $harnessRoot 'scripts\lib\setfile_surface.ps1')
    . (Join-Path $harnessRoot 'scripts\use_python.ps1')
    # A precommit materialization is an immutable Git tree export, deliberately
    # without .git or ignored host runtime dependencies. Resolve the portable
    # interpreter from the invocation checkout; scripts still run from the
    # byte-verified materialized tree.
    $pythonRoot = if ($PrecommitExactTree) { $invocationRoot } else { $harnessRoot }
    $py = Assert-PortablePython -Root $pythonRoot -Provision
    $parser = Join-Path $harnessRoot 'scripts\parse_mt5_report.py'
    $cases = @($baseline.Manifest.cases | Sort-Object ea)
    $sets = @{}
    foreach ($case in $cases) {
        $setPath = Resolve-TplRepoPath $root ([string]$case.declared_set_path) "$($case.ea).declared_set_path"
        $surface = Get-SetSurfaceState -Path $setPath
        if ($surface.State -ne 'FULL' -or (Get-TplSha256 $setPath) -ne ([string]$case.declared_set_sha256).ToLowerInvariant()) { throw "REFUSE: $($case.ea) set hash differs or set is undeclared" }
        $sets[$case.ea] = $setPath
    }

    if (-not $AdjacentControlRef -and -not $useDeclaredDelta -and -not $PrecommitExactTree) {
        Invoke-TplCompile -SourceRoot $root -Label 'current'
        $fail = 0
        foreach ($case in $cases) {
            $actual = Invoke-TplRegressionCase -Case $case -SetPath $sets[$case.ea] -RunLabel ''
            $expected = @($baseline.Metrics | Where-Object ea -eq $case.ea)[0]
            if (-not (Assert-TplMetricMatch -Expected $expected -Actual $actual -ExpectedLabel 'baseline' -ActualLabel 'now')) { $fail++ }
            else { Write-Host "[OK] $($case.ea) matches Build-6090 baseline" -ForegroundColor Green }
        }
        if ($fail -gt 0) { throw "REGRESSION: $fail exact metric mismatch(es)" }
        Write-Host "=== REGRESSION CLEAN ($($cases.Count)/$($cases.Count), Build 6090, lane $Terminal, source $sourceCommit) ===" -ForegroundColor Green
    } else {
        $tmpParent = 'C:\ea_lab_tmp'
        $controlWorktree = Join-Path $tmpParent ('tpl_adjacent_control_' + [guid]::NewGuid().ToString('N'))
        if (-not $controlWorktree.StartsWith('C:\ea_lab_tmp\tpl_adjacent_control_', [StringComparison]::OrdinalIgnoreCase)) { throw 'REFUSE: unsafe adjacent control worktree path' }
        New-Item -ItemType Directory -Force $tmpParent | Out-Null
        if (Test-Path -LiteralPath $controlWorktree) { throw "REFUSE: adjacent control worktree already exists: $controlWorktree" }
        try {
            & git -C $gitRoot worktree add --detach $controlWorktree $controlCommit | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $controlWorktree -PathType Container)) { throw 'REFUSE: could not create detached adjacent control worktree' }

            Invoke-TplCompile -SourceRoot $controlWorktree -Label 'adjacent control'
            $controlMetrics = @{}
            foreach ($case in $cases) {
                $controlMetrics[$case.ea] = Invoke-TplRegressionCase -Case $case -SetPath $sets[$case.ea] -RunLabel 'CONTROL' -BuildReceiptRegistry (Join-Path $controlWorktree 'portfolio\build_receipts.jsonl')
            }

            Invoke-TplCompile -SourceRoot $root -Label 'current'
            $fail = 0
            foreach ($case in $cases) {
                $actual = Invoke-TplRegressionCase -Case $case -SetPath $sets[$case.ea] -RunLabel 'CURRENT' -BuildReceiptRegistry (Join-Path $root 'portfolio\build_receipts.jsonl')
                if (-not (Assert-TplMetricMatch -Expected $controlMetrics[$case.ea] -Actual $actual -ExpectedLabel 'control' -ActualLabel 'current')) { $fail++ }
                else { Write-Host "[OK] $($case.ea) current matches adjacent control" -ForegroundColor Green }
            }
            if ($fail -gt 0) { throw "REGRESSION: $fail adjacent control metric mismatch(es)" }
            if ($PrecommitExactTree) {
                Write-TplPrecommitReceipt ([ordered]@{
                    schema='tpl_precommit_exact_tree_receipt/1'; status='FULL_TPL_CLEAN'
                    source_identity_kind='GIT_TREE'; source_tree=$SourceTree; repair_parent=$RepairParent; control_commit=$ControlCommit
                    materialized_root=$precommitMaterialization; materialized_entry_count=$precommitContract.EntryCount
                    changed_paths=@($precommitContract.ChangedPaths); harness_identity_kind='SOURCE_TREE_FILE_SET'
                    harness_source_tree=$SourceTree; harness_invocation_head=([string]$harnessCommit).Trim(); harness_invocation_tree=([string]$harnessTree).Trim()
                    harness_files=$harnessFiles; extractor_script=$precommitExtractorScript; extractor_sha256=$precommitExtractorSha256
                    validate_only=$false; cases=$cases.Count; terminal=$Terminal; data_dir=$DataDir; build=6090
                    timestamp_utc=(Get-Date).ToUniversalTime().ToString('o')
                })
            }
            Write-Host "=== ADJACENT REGRESSION CLEAN ($($cases.Count)/$($cases.Count), Build 6090, lane $Terminal, control $controlCommit, source $sourceCommit) ===" -ForegroundColor Green
        } finally {
            if ($controlWorktree -and (Test-Path -LiteralPath $controlWorktree)) {
                Write-Host "[PRESERVED] detached control worktree: $controlWorktree" -ForegroundColor Yellow
            }
        }
    }
    exit 0
} catch {
    if ($PrecommitExactTree -and $PrecommitEvidenceRoot) {
        Write-TplPrecommitReceipt ([ordered]@{
            schema='tpl_precommit_exact_tree_receipt/1'; status='REFUSE'; source_tree=$SourceTree
            repair_parent=$RepairParent; control_commit=$ControlCommit; materialized_root=$precommitMaterialization
            error=$_.Exception.Message; validate_only=[bool]$ValidateOnly; timestamp_utc=(Get-Date).ToUniversalTime().ToString('o')
        })
    }
    Write-Host ("[TPL REGRESSION REFUSED] " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
