# ORDER-1708 (E-2): Offline resume-identity & negative-control test suite for scripts\run_batch.ps1
# Verifies without launching live MT4/MT5:
#   R1. Positive control: job1 done + job2 failed -> state.json records execution_identity + artifact_sha256;
#       resume with identical identity/artifact skips job1 (artifact untouched) and runs job2 to completion.
#   R2. Negative control (.set SHA256 drift): mutating job1's .set file before resume triggers IDENTITY_MISMATCH (set_sha256) and stops batch.
#   R3. Negative control (.ex5 binary SHA256 drift): mutating job1's .ex5 binary before resume triggers IDENTITY_MISMATCH (binary_sha256) and stops batch.
#   R4. Negative control (.mq5 source SHA256 drift): mutating job1's .mq5 source before resume triggers IDENTITY_MISMATCH (source_sha256) and stops batch.
#   R5. Negative control (expect_artifact SHA256 drift): mutating job1's output artifact before resume triggers ARTIFACT_MISMATCH and stops batch.
#   R6. Negative control (expect_artifact missing): deleting job1's output artifact before resume triggers ARTIFACT_MISSING and stops batch.
#   R7. Negative control (legacy done state without execution_identity or RESUME_ADMISSION.json): marks UNVERIFIED and refuses skip.
#   R8. Negative control (active native process guard): -SimulateActiveNativeProcess aborts with exit 2 before launching or skipping.

$ErrorActionPreference = "Stop"
$repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$runBatch   = Join-Path $repoRoot "scripts\run_batch.ps1"
$mockRunner = Join-Path $repoRoot "scripts\_test\mock_runner.ps1"
$tmpRoot    = Join-Path ([System.IO.Path]::GetTempPath()) ("run_batch_resume_id_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

$passed = 0
$failed = 0

function Assert-Case {
    param([string]$Name, [bool]$Condition, [string]$Detail = "")
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $Name :: $Detail" -ForegroundColor Red
        $script:failed++
    }
}

function Get-RunnerDependencySha256-Local {
    param([string]$RunnerPath)
    if (-not $RunnerPath) { return $null }
    $dir = Split-Path -Parent $RunnerPath
    $libDirs = @((Join-Path $dir 'lib'), (Join-Path (Split-Path -Parent $dir) 'lib')) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique
    $entries = @()
    foreach ($ld in $libDirs) {
        foreach ($f in @(Get-ChildItem -LiteralPath $ld -Filter *.ps1 -File | Sort-Object Name)) {
            $entries += [ordered]@{ name = $f.Name; sha256 = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
        }
    }
    if ($entries.Count -eq 0) { return $null }
    $json = ConvertTo-Json -InputObject @($entries) -Compress -Depth 4
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    return (-join ($hasher.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }))
}

function New-TestScenario {
    param([string]$CaseName)
    $caseDir = Join-Path $tmpRoot $CaseName
    $dataDir = Join-Path $caseDir "DataDir"
    $expDir  = Join-Path $dataDir "MQL5\Experts\EA_LAB_TEST"
    $stateDir = Join-Path $caseDir "state"
    $artDir   = Join-Path $caseDir "reports"
    New-Item -ItemType Directory -Force -Path $expDir, $stateDir, $artDir | Out-Null

    $set1 = Join-Path $caseDir "job1.set"
    "_0_FastMA=20" | Set-Content -LiteralPath $set1 -Encoding ASCII
    $bin1 = Join-Path $expDir "TestEA1.ex5"
    "BINARY_V1_BYTES" | Set-Content -LiteralPath $bin1 -Encoding ASCII
    $src1 = Join-Path $caseDir "TestEA1.mq5"
    "// SOURCE_V1_BYTES" | Set-Content -LiteralPath $src1 -Encoding ASCII

    $art1 = Join-Path $artDir "job1_report.htm"
    $art2 = Join-Path $artDir "job2_report.htm"
    $exitFile2 = Join-Path $caseDir "job2_exit.txt"
    "5" | Set-Content -LiteralPath $exitFile2 -Encoding ASCII

    $jobs = @(
        @{
            id              = "job1"
            runner          = $mockRunner
            lane            = "ID_TEST_LANE"
            model           = 1
            set_file        = $set1
            expert          = "EA_LAB_TEST\TestEA1"
            binary_path     = $bin1
            source_path     = $src1
            expect_artifact = $art1
            args            = @(
                "-MarkerFile", $art1,
                "-ExitCode", 0,
                "-JobId", "job1"
            )
        },
        @{
            id              = "job2"
            runner          = $mockRunner
            lane            = "ID_TEST_LANE"
            model           = 1
            expect_artifact = $art2
            args            = @(
                "-MarkerFile", $art2,
                "-ExitCode", 0,
                "-ExitCodeFile", $exitFile2,
                "-JobId", "job2"
            )
        }
    )
    $manifestPath = Join-Path $caseDir "manifest.json"
    ConvertTo-Json -InputObject $jobs -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    return [PSCustomObject]@{
        CaseDir      = $caseDir
        StateDir     = $stateDir
        ManifestPath = $manifestPath
        Set1         = $set1
        Bin1         = $bin1
        Src1         = $src1
        Art1         = $art1
        Art2         = $art2
        ExitFile2    = $exitFile2
    }
}

function Invoke-Batch {
    param([string]$ManifestPath, [string]$StateDir, [switch]$SimulateActive)
    $simFlag = if ($SimulateActive) { "-SimulateActiveNativeProcess" } else { "" }
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$runBatch' -Manifest '$ManifestPath' -StateDir '$StateDir' $simFlag; exit `$LASTEXITCODE" 2>&1 | Out-String
    return [PSCustomObject]@{ Output = $out; ExitCode = $LASTEXITCODE }
}

function Get-State {
    param([string]$StateDir)
    $p = Join-Path $StateDir "state.json"
    $parsed = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
    return @($parsed | ForEach-Object { $_ })
}

try {
    Write-Host "=== ORDER-1708 (E-2) run_batch.ps1 Resume Identity & Negative-Control Cage ==="

    # --- R1: Positive control (verified skip) ---
    $s1 = New-TestScenario -CaseName "R1_positive"
    $run1a = Invoke-Batch -ManifestPath $s1.ManifestPath -StateDir $s1.StateDir
    $st1a  = Get-State -StateDir $s1.StateDir
    $j1a   = $st1a | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R1.a initial run records execution_identity + artifact_sha256 on done job1" (
        ($run1a.ExitCode -eq 1) -and ($j1a.state -eq "done") -and
        ($null -ne $j1a.execution_identity) -and
        ($j1a.execution_identity.set_sha256 -match "^[0-9a-f]{64}$") -and
        ($j1a.execution_identity.binary_sha256 -match "^[0-9a-f]{64}$") -and
        ($j1a.execution_identity.source_sha256 -match "^[0-9a-f]{64}$") -and
        ($j1a.artifact_sha256 -match "^[0-9a-f]{64}$")
    )
    $art1Before = Get-Content -LiteralPath $s1.Art1 -Raw
    "0" | Set-Content -LiteralPath $s1.ExitFile2 -Encoding ASCII
    Remove-Item -LiteralPath $s1.Art2 -Force -ErrorAction SilentlyContinue
    $run1b = Invoke-Batch -ManifestPath $s1.ManifestPath -StateDir $s1.StateDir
    $st1b  = Get-State -StateDir $s1.StateDir
    $art1After = Get-Content -LiteralPath $s1.Art1 -Raw
    Assert-Case "R1.b verified resume skips job1 without rewriting artifact and completes job2" (
        ($run1b.ExitCode -eq 0) -and ($art1Before -eq $art1After) -and
        (($st1b | Where-Object { $_.state -ne "done" }).Count -eq 0)
    )

    # --- R2: Negative control (.set SHA256 drift) ---
    $s2 = New-TestScenario -CaseName "R2_set_drift"
    [void](Invoke-Batch -ManifestPath $s2.ManifestPath -StateDir $s2.StateDir)
    "0" | Set-Content -LiteralPath $s2.ExitFile2 -Encoding ASCII
    Remove-Item -LiteralPath $s2.Art2 -Force -ErrorAction SilentlyContinue
    "_0_FastMA=99" | Set-Content -LiteralPath $s2.Set1 -Encoding ASCII
    $run2b = Invoke-Batch -ManifestPath $s2.ManifestPath -StateDir $s2.StateDir
    $st2b  = Get-State -StateDir $s2.StateDir
    $j2_1  = $st2b | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R2.a .set SHA256 drift marks job1 IDENTITY_MISMATCH (set_sha256)" (
        ($run2b.ExitCode -eq 1) -and ($j2_1.state -eq "IDENTITY_MISMATCH") -and ($j2_1.fail_reason -match "set_sha256")
    ) "state=$($j2_1.state) reason=$($j2_1.fail_reason)"
    Assert-Case "R2.b .set drift stops batch before job2 runs" (-not (Test-Path -LiteralPath $s2.Art2))

    # --- R3: Negative control (.ex5 binary SHA256 drift) ---
    $s3 = New-TestScenario -CaseName "R3_bin_drift"
    [void](Invoke-Batch -ManifestPath $s3.ManifestPath -StateDir $s3.StateDir)
    "0" | Set-Content -LiteralPath $s3.ExitFile2 -Encoding ASCII
    Remove-Item -LiteralPath $s3.Art2 -Force -ErrorAction SilentlyContinue
    "BINARY_V2_RECOMPILED_BYTES" | Set-Content -LiteralPath $s3.Bin1 -Encoding ASCII
    $run3b = Invoke-Batch -ManifestPath $s3.ManifestPath -StateDir $s3.StateDir
    $st3b  = Get-State -StateDir $s3.StateDir
    $j3_1  = $st3b | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R3.a .ex5 binary SHA256 drift marks job1 IDENTITY_MISMATCH (binary_sha256)" (
        ($run3b.ExitCode -eq 1) -and ($j3_1.state -eq "IDENTITY_MISMATCH") -and ($j3_1.fail_reason -match "binary_sha256")
    ) "state=$($j3_1.state) reason=$($j3_1.fail_reason)"
    Assert-Case "R3.b .ex5 binary drift stops batch before job2 runs" (-not (Test-Path -LiteralPath $s3.Art2))

    # --- R4: Negative control (.mq5 source SHA256 drift) ---
    $s4 = New-TestScenario -CaseName "R4_src_drift"
    [void](Invoke-Batch -ManifestPath $s4.ManifestPath -StateDir $s4.StateDir)
    "0" | Set-Content -LiteralPath $s4.ExitFile2 -Encoding ASCII
    Remove-Item -LiteralPath $s4.Art2 -Force -ErrorAction SilentlyContinue
    "// SOURCE_V2_MODIFIED_BYTES" | Set-Content -LiteralPath $s4.Src1 -Encoding ASCII
    $run4b = Invoke-Batch -ManifestPath $s4.ManifestPath -StateDir $s4.StateDir
    $st4b  = Get-State -StateDir $s4.StateDir
    $j4_1  = $st4b | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R4.a .mq5 source SHA256 drift marks job1 IDENTITY_MISMATCH (source_sha256)" (
        ($run4b.ExitCode -eq 1) -and ($j4_1.state -eq "IDENTITY_MISMATCH") -and ($j4_1.fail_reason -match "source_sha256")
    ) "state=$($j4_1.state) reason=$($j4_1.fail_reason)"
    Assert-Case "R4.b .mq5 source drift stops batch before job2 runs" (-not (Test-Path -LiteralPath $s4.Art2))

    # --- R5: Negative control (output expect_artifact SHA256 tampered) ---
    $s5 = New-TestScenario -CaseName "R5_artifact_drift"
    [void](Invoke-Batch -ManifestPath $s5.ManifestPath -StateDir $s5.StateDir)
    "0" | Set-Content -LiteralPath $s5.ExitFile2 -Encoding ASCII
    Remove-Item -LiteralPath $s5.Art2 -Force -ErrorAction SilentlyContinue
    "TAMPERED_REPORT_BYTES" | Set-Content -LiteralPath $s5.Art1 -Encoding ASCII
    $run5b = Invoke-Batch -ManifestPath $s5.ManifestPath -StateDir $s5.StateDir
    $st5b  = Get-State -StateDir $s5.StateDir
    $j5_1  = $st5b | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R5.a tampered output artifact marks job1 ARTIFACT_MISMATCH" (
        ($run5b.ExitCode -eq 1) -and ($j5_1.state -eq "ARTIFACT_MISMATCH")
    ) "state=$($j5_1.state) reason=$($j5_1.fail_reason)"
    Assert-Case "R5.b tampered output artifact stops batch before job2 runs" (-not (Test-Path -LiteralPath $s5.Art2))

    # --- R6: Negative control (output expect_artifact deleted) ---
    $s6 = New-TestScenario -CaseName "R6_artifact_missing"
    [void](Invoke-Batch -ManifestPath $s6.ManifestPath -StateDir $s6.StateDir)
    "0" | Set-Content -LiteralPath $s6.ExitFile2 -Encoding ASCII
    Remove-Item -LiteralPath $s6.Art2 -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $s6.Art1 -Force
    $run6b = Invoke-Batch -ManifestPath $s6.ManifestPath -StateDir $s6.StateDir
    $st6b  = Get-State -StateDir $s6.StateDir
    $j6_1  = $st6b | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R6.a deleted output artifact marks job1 ARTIFACT_MISSING" (
        ($run6b.ExitCode -eq 1) -and ($j6_1.state -eq "ARTIFACT_MISSING")
    ) "state=$($j6_1.state) reason=$($j6_1.fail_reason)"
    Assert-Case "R6.b deleted output artifact stops batch before job2 runs" (-not (Test-Path -LiteralPath $s6.Art2))

    # --- R7: Negative control (legacy done record lacking execution_identity and RESUME_ADMISSION.json) ---
    $s7 = New-TestScenario -CaseName "R7_legacy_unverified"
    $legacyState = @(
        @{
            id          = "job1"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "done"
            start       = "2026-10-31T00:00:00Z"
            end         = "2026-10-31T00:00:05Z"
            exit_code   = 0
            fail_reason = $null
        },
        @{
            id          = "job2"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "pending"
            start       = $null
            end         = $null
            exit_code   = $null
            fail_reason = $null
        }
    )
    ConvertTo-Json -InputObject $legacyState -Depth 6 | Set-Content -LiteralPath (Join-Path $s7.StateDir "state.json") -Encoding UTF8
    "0" | Set-Content -LiteralPath $s7.ExitFile2 -Encoding ASCII
    $run7 = Invoke-Batch -ManifestPath $s7.ManifestPath -StateDir $s7.StateDir
    $st7  = Get-State -StateDir $s7.StateDir
    $j7_1 = $st7 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R7.a legacy done state without execution_identity marked UNVERIFIED" (
        ($run7.ExitCode -eq 1) -and ($j7_1.state -eq "UNVERIFIED")
    ) "state=$($j7_1.state) reason=$($j7_1.fail_reason)"
    Assert-Case "R7.b legacy unverified state stops batch before job2 runs" (-not (Test-Path -LiteralPath $s7.Art2))

    # --- R8: Negative control (active native process guard) ---
    $s8 = New-TestScenario -CaseName "R8_active_native"
    $run8 = Invoke-Batch -ManifestPath $s8.ManifestPath -StateDir $s8.StateDir -SimulateActive
    Assert-Case "R8.a active native process guard aborts with exit 2" (
        ($run8.ExitCode -eq 2) -and ($run8.Output -match "active native process detected")
    ) "exit=$($run8.ExitCode)"
    Assert-Case "R8.b active native process guard prevents job1 launch" (-not (Test-Path -LiteralPath $s8.Art1))

    # --- R9: Repeated resume (2nd & 3rd runs) on refusal states + orphan running ---
    $art2Before = Get-Content -LiteralPath $s2.Art1 -Raw
    $run2_repeat2 = Invoke-Batch -ManifestPath $s2.ManifestPath -StateDir $s2.StateDir
    $run2_repeat3 = Invoke-Batch -ManifestPath $s2.ManifestPath -StateDir $s2.StateDir
    $st2_repeat = Get-State -StateDir $s2.StateDir
    $j2_repeat = $st2_repeat | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    $art2After = Get-Content -LiteralPath $s2.Art1 -Raw
    Assert-Case "R9.a repeated resume (2nd & 3rd) on IDENTITY_MISMATCH stays refused and preserves artifact/identity" (
        ($run2_repeat2.ExitCode -eq 1) -and ($run2_repeat3.ExitCode -eq 1) -and
        ($j2_repeat.state -eq "IDENTITY_MISMATCH") -and ($art2Before -eq $art2After) -and
        ($null -ne $j2_repeat.execution_identity) -and (-not (Test-Path -LiteralPath $s2.Art2))
    ) "state=$($j2_repeat.state)"

    $run5_repeat2 = Invoke-Batch -ManifestPath $s5.ManifestPath -StateDir $s5.StateDir
    $st5_repeat = Get-State -StateDir $s5.StateDir
    $j5_repeat = $st5_repeat | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R9.b repeated resume on ARTIFACT_MISMATCH stays refused" (
        ($run5_repeat2.ExitCode -eq 1) -and ($j5_repeat.state -eq "ARTIFACT_MISMATCH") -and (-not (Test-Path -LiteralPath $s5.Art2))
    ) "state=$($j5_repeat.state)"

    $run6_repeat2 = Invoke-Batch -ManifestPath $s6.ManifestPath -StateDir $s6.StateDir
    $st6_repeat = Get-State -StateDir $s6.StateDir
    $j6_repeat = $st6_repeat | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R9.c repeated resume on ARTIFACT_MISSING stays refused and does not recreate Art1" (
        ($run6_repeat2.ExitCode -eq 1) -and ($j6_repeat.state -eq "ARTIFACT_MISSING") -and (-not (Test-Path -LiteralPath $s6.Art1))
    ) "state=$($j6_repeat.state)"

    $run7_repeat2 = Invoke-Batch -ManifestPath $s7.ManifestPath -StateDir $s7.StateDir
    $st7_repeat = Get-State -StateDir $s7.StateDir
    $j7_repeat = $st7_repeat | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R9.d repeated resume on UNVERIFIED stays refused" (
        ($run7_repeat2.ExitCode -eq 1) -and ($j7_repeat.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $s7.Art2))
    ) "state=$($j7_repeat.state)"

    # Orphan running state
    $s9 = New-TestScenario -CaseName "R9_orphan_running"
    $orphanState = @(
        @{
            id          = "job1"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "running"
            start       = "2026-10-31T00:00:00"
            end         = $null
            exit_code   = $null
            fail_reason = $null
        },
        @{
            id          = "job2"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "pending"
            start       = $null
            end         = $null
            exit_code   = $null
            fail_reason = $null
        }
    )
    ConvertTo-Json -InputObject $orphanState -Depth 6 | Set-Content -LiteralPath (Join-Path $s9.StateDir "state.json") -Encoding UTF8
    $run9_1 = Invoke-Batch -ManifestPath $s9.ManifestPath -StateDir $s9.StateDir
    $run9_2 = Invoke-Batch -ManifestPath $s9.ManifestPath -StateDir $s9.StateDir
    $st9 = Get-State -StateDir $s9.StateDir
    $j9_1 = $st9 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R9.e orphan running state refuses execution across repeated runs without launching job1 or job2" (
        ($run9_1.ExitCode -eq 1) -and ($run9_2.ExitCode -eq 1) -and
        ($j9_1.state -eq "running") -and (-not (Test-Path -LiteralPath $s9.Art1)) -and (-not (Test-Path -LiteralPath $s9.Art2))
    ) "state=$($j9_1.state)"

    # --- R10: Explicit operator reconciliation (resetting state to pending allows clean re-run) ---
    $st2_reconcile = Get-State -StateDir $s2.StateDir
    $j2_rec = $st2_reconcile | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    $j2_rec.state = "pending"
    $j2_rec.fail_reason = $null
    ConvertTo-Json -InputObject $st2_reconcile -Depth 8 | Set-Content -LiteralPath (Join-Path $s2.StateDir "state.json") -Encoding UTF8
    $run10 = Invoke-Batch -ManifestPath $s2.ManifestPath -StateDir $s2.StateDir
    $st10 = Get-State -StateDir $s2.StateDir
    $j10_1 = $st10 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    $j10_2 = $st10 | Where-Object { $_.id -eq "job2" } | Select-Object -First 1
    Assert-Case "R10.a explicit operator reconciliation to pending allows job1 + failed job2 to complete" (
        ($run10.ExitCode -eq 0) -and ($j10_1.state -eq "done") -and ($j10_2.state -eq "done")
    ) "exit=$($run10.ExitCode) j1=$($j10_1.state) j2=$($j10_2.state)"

    # --- R11: Legacy RESUME_ADMISSION.json binding (manifest_sha256 + state row + artifact) ---
    $s11 = New-TestScenario -CaseName "R11_legacy_admission"
    "LEGACY_REPORT_BYTES" | Set-Content -LiteralPath $s11.Art1 -Encoding ASCII
    "0" | Set-Content -LiteralPath $s11.ExitFile2 -Encoding ASCII
    $art11Sha = (Get-FileHash -LiteralPath $s11.Art1 -Algorithm SHA256).Hash.ToLowerInvariant()
    $origManifestSha = (Get-FileHash -LiteralPath $s11.ManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $legacyState11 = @(
        @{
            id          = "job1"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "done"
            start       = "2026-10-31T01:00:00"
            end         = "2026-10-31T01:05:00"
            exit_code   = 0
            fail_reason = $null
        },
        @{
            id          = "job2"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "pending"
            start       = $null
            end         = $null
            exit_code   = $null
            fail_reason = $null
        }
    )
    ConvertTo-Json -InputObject $legacyState11 -Depth 6 | Set-Content -LiteralPath (Join-Path $s11.StateDir "state.json") -Encoding UTF8
    $origSetSha11     = (Get-FileHash -LiteralPath $s11.Set1 -Algorithm SHA256).Hash.ToLowerInvariant()
    $origBinSha11     = (Get-FileHash -LiteralPath $s11.Bin1 -Algorithm SHA256).Hash.ToLowerInvariant()
    $origSrcSha11     = (Get-FileHash -LiteralPath $s11.Src1 -Algorithm SHA256).Hash.ToLowerInvariant()
    $origRunnerSha11  = (Get-FileHash -LiteralPath $mockRunner -Algorithm SHA256).Hash.ToLowerInvariant()
    $origRunnerDeps11 = Get-RunnerDependencySha256-Local -RunnerPath $mockRunner

    $admissionObj = @{
        manifest_sha256   = $origManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $mockRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path           = $s11.Art1
                raw_sha256         = $art11Sha
                set_sha256         = $origSetSha11
                binary_sha256      = $origBinSha11
                source_sha256      = $origSrcSha11
                runner_sha256      = $origRunnerSha11
                runner_deps_sha256 = $origRunnerDeps11
            }
        )
    }
    $admissionPath = Join-Path $s11.CaseDir "RESUME_ADMISSION.json"
    ConvertTo-Json -InputObject $admissionObj -Depth 6 | Set-Content -LiteralPath $admissionPath -Encoding UTF8

    # Mutate job1 args in manifest.json (simulating Codex R3-2 reproducer)
    $mutJobs = @((Get-Content -LiteralPath $s11.ManifestPath -Raw | ConvertFrom-Json) | ForEach-Object { $_ })
    $mutJobs[0].args += @("-ExtraFlag", "CHANGED_JOB_ARGS")
    ConvertTo-Json -InputObject $mutJobs -Depth 8 | Set-Content -LiteralPath $s11.ManifestPath -Encoding UTF8

    $run11_bad = Invoke-Batch -ManifestPath $s11.ManifestPath -StateDir $s11.StateDir
    $st11_bad = Get-State -StateDir $s11.StateDir
    $j11_bad = $st11_bad | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.a legacy RESUME_ADMISSION with mutated manifest_sha256 refuses skip as UNVERIFIED" (
        ($run11_bad.ExitCode -eq 1) -and ($j11_bad.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $s11.Art2))
    ) "state=$($j11_bad.state) reason=$($j11_bad.fail_reason)"

    # Restore exact manifest & legacy done state -> positive admission control
    $mutJobs[0].args = @("-MarkerFile", $s11.Art1, "-ExitCode", 0, "-JobId", "job1")
    ConvertTo-Json -InputObject $mutJobs -Depth 8 | Set-Content -LiteralPath $s11.ManifestPath -Encoding UTF8
    $restoredManifestSha = (Get-FileHash -LiteralPath $s11.ManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $admissionObj.manifest_sha256 = $restoredManifestSha
    ConvertTo-Json -InputObject $admissionObj -Depth 6 | Set-Content -LiteralPath $admissionPath -Encoding UTF8
    ConvertTo-Json -InputObject $legacyState11 -Depth 6 | Set-Content -LiteralPath (Join-Path $s11.StateDir "state.json") -Encoding UTF8

    $run11_ok = Invoke-Batch -ManifestPath $s11.ManifestPath -StateDir $s11.StateDir
    $st11_ok = Get-State -StateDir $s11.StateDir
    $j11_2 = $st11_ok | Where-Object { $_.id -eq "job2" } | Select-Object -First 1
    Assert-Case "R11.b legacy RESUME_ADMISSION with exact matching manifest_sha256 + state + raw_sha256 skips job1 and runs job2" (
        ($run11_ok.ExitCode -eq 0) -and ($j11_2.state -eq "done")
    ) "exit=$($run11_ok.ExitCode) j2=$($j11_2.state)"

    # R11.c: Negative control (R4-1 same-path .set content drift) -> refuses skip as UNVERIFIED
    ConvertTo-Json -InputObject $legacyState11 -Depth 6 | Set-Content -LiteralPath (Join-Path $s11.StateDir "state.json") -Encoding UTF8
    Remove-Item -LiteralPath $s11.Art2 -Force -ErrorAction SilentlyContinue
    "PARAM_DRIFTED_BYTES" | Set-Content -LiteralPath $s11.Set1 -Encoding ASCII
    $run11_c = Invoke-Batch -ManifestPath $s11.ManifestPath -StateDir $s11.StateDir
    $st11_c = Get-State -StateDir $s11.StateDir
    $j11_c = $st11_c | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.c legacy RESUME_ADMISSION with same-path .set drift refuses skip as UNVERIFIED" (
        ($run11_c.ExitCode -eq 1) -and ($j11_c.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $s11.Art2))
    ) "state=$($j11_c.state) reason=$($j11_c.fail_reason)"

    # R11.d: Negative control (R4-1 same-path .ex5 binary drift) -> refuses skip as UNVERIFIED
    "PARAM_V1_BYTES" | Set-Content -LiteralPath $s11.Set1 -Encoding ASCII
    "BINARY_DRIFTED_BYTES" | Set-Content -LiteralPath $s11.Bin1 -Encoding ASCII
    ConvertTo-Json -InputObject $legacyState11 -Depth 6 | Set-Content -LiteralPath (Join-Path $s11.StateDir "state.json") -Encoding UTF8
    Remove-Item -LiteralPath $s11.Art2 -Force -ErrorAction SilentlyContinue
    $run11_d = Invoke-Batch -ManifestPath $s11.ManifestPath -StateDir $s11.StateDir
    $st11_d = Get-State -StateDir $s11.StateDir
    $j11_d = $st11_d | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.d legacy RESUME_ADMISSION with same-path .ex5 binary drift refuses skip as UNVERIFIED" (
        ($run11_d.ExitCode -eq 1) -and ($j11_d.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $s11.Art2))
    ) "state=$($j11_d.state) reason=$($j11_d.fail_reason)"

    # R11.e: Negative control (R4-1 unpinned dependency hashes for set/binary job) -> refuses skip as UNVERIFIED
    "BINARY_V1_BYTES" | Set-Content -LiteralPath $s11.Bin1 -Encoding ASCII
    $unpinnedAdm = @{
        manifest_sha256   = $restoredManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $mockRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path   = $s11.Art1
                raw_sha256 = $art11Sha
            }
        )
    }
    ConvertTo-Json -InputObject $unpinnedAdm -Depth 6 | Set-Content -LiteralPath $admissionPath -Encoding UTF8
    ConvertTo-Json -InputObject $legacyState11 -Depth 6 | Set-Content -LiteralPath (Join-Path $s11.StateDir "state.json") -Encoding UTF8
    Remove-Item -LiteralPath $s11.Art2 -Force -ErrorAction SilentlyContinue
    $run11_e = Invoke-Batch -ManifestPath $s11.ManifestPath -StateDir $s11.StateDir
    $st11_e = Get-State -StateDir $s11.StateDir
    $j11_e = $st11_e | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.e unpinned legacy admission lacking set/binary hashes refuses skip as UNVERIFIED" (
        ($run11_e.ExitCode -eq 1) -and ($j11_e.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $s11.Art2))
    ) "state=$($j11_e.state) reason=$($j11_e.fail_reason)"

    # R11.f: Negative control (idempotent repeated refusal on UNVERIFIED legacy admission)
    $run11_f = Invoke-Batch -ManifestPath $s11.ManifestPath -StateDir $s11.StateDir
    $st11_f = Get-State -StateDir $s11.StateDir
    $j11_f = $st11_f | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.f repeated resume over UNVERIFIED state remains refused and does not re-run" (
        ($run11_f.ExitCode -eq 1) -and ($j11_f.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $s11.Art2))
    ) "state=$($j11_f.state) reason=$($j11_f.fail_reason)"

    # R11.g..k: R4-1B/R4-1C native -Expert job without -BinaryPath, authoritative directory, & decoy negative cages
    $s11_nat = New-TestScenario -CaseName "R11_native_expert"
    $natRunner = Join-Path $s11_nat.CaseDir "mt5_run.ps1"
    @"
param(
    [string]`$Terminal = 'D:\Meta 5\terminal64.exe',
    [string]`$DataDir = 'D:\Meta 5'
)
# dummy native runner, never executed on skip
exit 0
"@ | Set-Content -LiteralPath $natRunner -Encoding ASCII

    $natDataDir = Join-Path $s11_nat.CaseDir "data"
    $natTermDir = Join-Path $s11_nat.CaseDir "terminal"
    $natTerminal = Join-Path $natTermDir "terminal64.exe"
    $natExpDir = Join-Path $natDataDir "MQL5\Experts"
    New-Item -ItemType Directory -Force -Path $natExpDir, $natTermDir | Out-Null
    "TERMINAL_STUB" | Set-Content -LiteralPath $natTerminal -Encoding ASCII

    $natSet = Join-Path $s11_nat.CaseDir "param.set"
    "_0_FastMA=20" | Set-Content -LiteralPath $natSet -Encoding ASCII
    $natBin = Join-Path $natExpDir "MyExpert.ex5"
    "BINARY_NAT_V1" | Set-Content -LiteralPath $natBin -Encoding ASCII
    $decoyBin = Join-Path $s11_nat.CaseDir "MyExpert.ex5"
    "DECOY_IN_RUNNER_DIR" | Set-Content -LiteralPath $decoyBin -Encoding ASCII

    $natArt1 = Join-Path $s11_nat.CaseDir "reports\job1_report.htm"
    "REPORT_V1" | Set-Content -LiteralPath $natArt1 -Encoding ASCII
    $natArt2 = Join-Path $s11_nat.CaseDir "reports\job2_report.htm"
    $natExitFile2 = Join-Path $s11_nat.CaseDir "job2_exit.txt"
    "0" | Set-Content -LiteralPath $natExitFile2 -Encoding ASCII

    $natManifestPath = Join-Path $s11_nat.CaseDir "manifest.json"
    $natJobs = @(
        @{
            id              = "job1"
            runner          = $natRunner
            lane            = "ID_TEST_LANE"
            model           = 1
            expect_artifact = $natArt1
            args            = @(
                "-SetFile", $natSet,
                "-Terminal", $natTerminal,
                "-DataDir", $natDataDir,
                "-Expert", "MyExpert"
            )
        },
        @{
            id              = "job2"
            runner          = $mockRunner
            lane            = "ID_TEST_LANE"
            model           = 1
            expect_artifact = $natArt2
            args            = @(
                "-MarkerFile", $natArt2,
                "-ExitCode", 0,
                "-ExitCodeFile", $natExitFile2,
                "-JobId", "job2"
            )
        }
    )
    ConvertTo-Json -InputObject $natJobs -Depth 8 | Set-Content -LiteralPath $natManifestPath -Encoding UTF8

    $origNatManifestSha = (Get-FileHash -LiteralPath $natManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $origNatRunnerSha   = (Get-FileHash -LiteralPath $natRunner -Algorithm SHA256).Hash.ToLowerInvariant()
    $origNatSetSha      = (Get-FileHash -LiteralPath $natSet -Algorithm SHA256).Hash.ToLowerInvariant()
    $origNatBinSha      = (Get-FileHash -LiteralPath $natBin -Algorithm SHA256).Hash.ToLowerInvariant()
    $natArt1Sha         = (Get-FileHash -LiteralPath $natArt1 -Algorithm SHA256).Hash.ToLowerInvariant()

    $legacyNatState = @(
        @{
            id          = "job1"
            runner      = $natRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "done"
            start       = "2026-10-31T01:00:00"
            end         = "2026-10-31T01:05:00"
            exit_code   = 0
            fail_reason = $null
        },
        @{
            id          = "job2"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "pending"
            start       = $null
            end         = $null
            exit_code   = $null
            fail_reason = $null
        }
    )

    $natAdmissionPath = Join-Path $s11_nat.CaseDir "RESUME_ADMISSION.json"

    function Reset-NatState {
        ConvertTo-Json -InputObject $legacyNatState -Depth 6 | Set-Content -LiteralPath (Join-Path $s11_nat.StateDir "state.json") -Encoding UTF8
        Remove-Item -LiteralPath $natArt2 -Force -ErrorAction SilentlyContinue
    }

    # R11.g: Native -Expert job without -BinaryPath where admission lacks binary_sha256 -> UNVERIFIED
    Reset-NatState
    $adm_g = @{
        manifest_sha256   = $origNatManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $natRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path      = $natArt1
                raw_sha256    = $natArt1Sha
                runner_sha256 = $origNatRunnerSha
                set_sha256    = $origNatSetSha
            }
        )
    }
    ConvertTo-Json -InputObject $adm_g -Depth 6 | Set-Content -LiteralPath $natAdmissionPath -Encoding UTF8
    $run11_g = Invoke-Batch -ManifestPath $natManifestPath -StateDir $s11_nat.StateDir
    $st11_g = Get-State -StateDir $s11_nat.StateDir
    $j11_g = $st11_g | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.g native -Expert job lacking binary_sha256 in admission refuses skip as UNVERIFIED" (
        ($run11_g.ExitCode -eq 1) -and ($j11_g.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $natArt2))
    ) "state=$($j11_g.state) reason=$($j11_g.fail_reason)"

    # R11.h: Native -Expert job with drifted .ex5 binary -> UNVERIFIED
    Reset-NatState
    "DRIFTED_BINARY_BYTES" | Set-Content -LiteralPath $natBin -Encoding ASCII
    $adm_h = @{
        manifest_sha256   = $origNatManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $natRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path      = $natArt1
                raw_sha256    = $natArt1Sha
                runner_sha256 = $origNatRunnerSha
                set_sha256    = $origNatSetSha
                binary_sha256 = $origNatBinSha
            }
        )
    }
    ConvertTo-Json -InputObject $adm_h -Depth 6 | Set-Content -LiteralPath $natAdmissionPath -Encoding UTF8
    $run11_h = Invoke-Batch -ManifestPath $natManifestPath -StateDir $s11_nat.StateDir
    $st11_h = Get-State -StateDir $s11_nat.StateDir
    $j11_h = $st11_h | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.h native -Expert job with drifted .ex5 binary refuses skip as UNVERIFIED" (
        ($run11_h.ExitCode -eq 1) -and ($j11_h.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $natArt2))
    ) "state=$($j11_h.state) reason=$($j11_h.fail_reason)"

    # Restore binary for R11.i and R11.j
    "BINARY_NAT_V1" | Set-Content -LiteralPath $natBin -Encoding ASCII

    # R11.i: Legacy admission lacking runner_sha256 -> UNVERIFIED
    Reset-NatState
    $adm_i = @{
        manifest_sha256   = $origNatManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $natRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path      = $natArt1
                raw_sha256    = $natArt1Sha
                set_sha256    = $origNatSetSha
                binary_sha256 = $origNatBinSha
            }
        )
    }
    ConvertTo-Json -InputObject $adm_i -Depth 6 | Set-Content -LiteralPath $natAdmissionPath -Encoding UTF8
    $run11_i = Invoke-Batch -ManifestPath $natManifestPath -StateDir $s11_nat.StateDir
    $st11_i = Get-State -StateDir $s11_nat.StateDir
    $j11_i = $st11_i | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.i legacy admission lacking runner_sha256 refuses skip as UNVERIFIED" (
        ($run11_i.ExitCode -eq 1) -and ($j11_i.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $natArt2))
    ) "state=$($j11_i.state) reason=$($j11_i.fail_reason)"

    # R11.j: Native -Expert job with exact matching runner + set + binary hashes -> skips job1 as done, runs job2
    Reset-NatState
    $adm_j = @{
        manifest_sha256   = $origNatManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $natRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path      = $natArt1
                raw_sha256    = $natArt1Sha
                runner_sha256 = $origNatRunnerSha
                set_sha256    = $origNatSetSha
                binary_sha256 = $origNatBinSha
            }
        )
    }
    ConvertTo-Json -InputObject $adm_j -Depth 6 | Set-Content -LiteralPath $natAdmissionPath -Encoding UTF8
    $run11_j = Invoke-Batch -ManifestPath $natManifestPath -StateDir $s11_nat.StateDir
    $st11_j = Get-State -StateDir $s11_nat.StateDir
    $j11_j_1 = $st11_j | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    $j11_j_2 = $st11_j | Where-Object { $_.id -eq "job2" } | Select-Object -First 1
    Assert-Case "R11.j fully pinned native -Expert legacy admission skips job1 as done and completes job2" (
        ($run11_j.ExitCode -eq 0) -and ($j11_j_1.state -eq "done") -and ($j11_j_2.state -eq "done") -and (Test-Path -LiteralPath $natArt2)
    ) "exit=$($run11_j.ExitCode) j1=$($j11_j_1.state) j2=$($j11_j_2.state)"

    # R11.k: R4-1C negative control -- decoy in runnerDir present, but authoritative DataDir EX5 missing
    Reset-NatState
    Remove-Item -LiteralPath $natBin -Force
    $adm_k = @{
        manifest_sha256   = $origNatManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $natRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path      = $natArt1
                raw_sha256    = $natArt1Sha
                runner_sha256 = $origNatRunnerSha
                set_sha256    = $origNatSetSha
                binary_sha256 = (Get-FileHash -LiteralPath $decoyBin -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        )
    }
    ConvertTo-Json -InputObject $adm_k -Depth 6 | Set-Content -LiteralPath $natAdmissionPath -Encoding UTF8
    $run11_k = Invoke-Batch -ManifestPath $natManifestPath -StateDir $s11_nat.StateDir
    $st11_k = Get-State -StateDir $s11_nat.StateDir
    $j11_k = $st11_k | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.k decoy EX5 in runnerDir with missing authoritative terminal EX5 refuses skip as UNVERIFIED" (
        ($run11_k.ExitCode -eq 1) -and ($j11_k.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $natArt2))
    ) "state=$($j11_k.state) reason=$($j11_k.fail_reason)"

    # Restore real authoritative binary
    "BINARY_NAT_V1" | Set-Content -LiteralPath $natBin -Encoding ASCII

    # R11.l..R11.n: R4-1D runner dependency drift, unpinned dependency, and fully pinned positive cages
    $s11_dep = New-TestScenario -CaseName "R11_dep_cage"
    $depRunner = Join-Path $s11_dep.CaseDir "run_with_lib.ps1"
    @"
param(
    [string]`$MarkerFile,
    [int]`$ExitCode = 0,
    [string]`$ExitCodeFile = "",
    [string]`$JobId = ""
)
. (Join-Path `$PSScriptRoot 'lib\helper.ps1')
exit `$ExitCode
"@ | Set-Content -LiteralPath $depRunner -Encoding ASCII

    $depLibDir = Join-Path $s11_dep.CaseDir "lib"
    New-Item -ItemType Directory -Force -Path $depLibDir | Out-Null
    $depHelper = Join-Path $depLibDir "helper.ps1"
    "function Get-HelperMessage { return 'HELPER_V1' }" | Set-Content -LiteralPath $depHelper -Encoding ASCII

    $depSet = Join-Path $s11_dep.CaseDir "param.set"
    "_0_FastMA=15" | Set-Content -LiteralPath $depSet -Encoding ASCII
    $depBin = Join-Path $s11_dep.CaseDir "EA.ex5"
    "BINARY_DEP_V1" | Set-Content -LiteralPath $depBin -Encoding ASCII
    $depArt1 = Join-Path $s11_dep.CaseDir "reports\job1_report.htm"
    "REPORT_DEP_V1" | Set-Content -LiteralPath $depArt1 -Encoding ASCII
    $depArt2 = Join-Path $s11_dep.CaseDir "reports\job2_report.htm"
    $depExitFile2 = Join-Path $s11_dep.CaseDir "job2_exit.txt"
    "0" | Set-Content -LiteralPath $depExitFile2 -Encoding ASCII

    $depManifestPath = Join-Path $s11_dep.CaseDir "manifest.json"
    $depJobs = @(
        @{
            id              = "job1"
            runner          = $depRunner
            lane            = "ID_TEST_LANE"
            model           = 1
            expect_artifact = $depArt1
            args            = @(
                "-SetFile", $depSet,
                "-BinaryPath", $depBin,
                "-MarkerFile", $depArt1,
                "-JobId", "job1"
            )
            set_file        = $depSet
            binary_path     = $depBin
        },
        @{
            id              = "job2"
            runner          = $mockRunner
            lane            = "ID_TEST_LANE"
            model           = 1
            expect_artifact = $depArt2
            args            = @(
                "-MarkerFile", $depArt2,
                "-ExitCode", 0,
                "-ExitCodeFile", $depExitFile2,
                "-JobId", "job2"
            )
        }
    )
    ConvertTo-Json -InputObject $depJobs -Depth 8 | Set-Content -LiteralPath $depManifestPath -Encoding UTF8

    $origDepManifestSha = (Get-FileHash -LiteralPath $depManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $origDepRunnerSha   = (Get-FileHash -LiteralPath $depRunner -Algorithm SHA256).Hash.ToLowerInvariant()
    $origDepDepsSha     = Get-RunnerDependencySha256-Local -RunnerPath $depRunner
    $origDepSetSha      = (Get-FileHash -LiteralPath $depSet -Algorithm SHA256).Hash.ToLowerInvariant()
    $origDepBinSha      = (Get-FileHash -LiteralPath $depBin -Algorithm SHA256).Hash.ToLowerInvariant()
    $depArt1Sha         = (Get-FileHash -LiteralPath $depArt1 -Algorithm SHA256).Hash.ToLowerInvariant()

    $legacyDepState = @(
        @{
            id          = "job1"
            runner      = $depRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "done"
            start       = "2026-10-31T01:00:00"
            end         = "2026-10-31T01:05:00"
            exit_code   = 0
            fail_reason = $null
        },
        @{
            id          = "job2"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "pending"
            start       = $null
            end         = $null
            exit_code   = $null
            fail_reason = $null
        }
    )

    $depAdmissionPath = Join-Path $s11_dep.CaseDir "RESUME_ADMISSION.json"

    function Reset-DepState {
        ConvertTo-Json -InputObject $legacyDepState -Depth 6 | Set-Content -LiteralPath (Join-Path $s11_dep.StateDir "state.json") -Encoding UTF8
        Remove-Item -LiteralPath $depArt2 -Force -ErrorAction SilentlyContinue
    }

    # R11.l: Runner with imported helper under lib/*.ps1 where helper drifts -> UNVERIFIED
    Reset-DepState
    "function Get-HelperMessage { return 'HELPER_V2_DRIFTED' }" | Set-Content -LiteralPath $depHelper -Encoding ASCII
    $adm_l = @{
        manifest_sha256   = $origDepManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $depRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path           = $depArt1
                raw_sha256         = $depArt1Sha
                runner_sha256      = $origDepRunnerSha
                runner_deps_sha256 = $origDepDepsSha
                set_sha256         = $origDepSetSha
                binary_sha256      = $origDepBinSha
            }
        )
    }
    ConvertTo-Json -InputObject $adm_l -Depth 6 | Set-Content -LiteralPath $depAdmissionPath -Encoding UTF8
    $run11_l = Invoke-Batch -ManifestPath $depManifestPath -StateDir $s11_dep.StateDir
    $st11_l = Get-State -StateDir $s11_dep.StateDir
    $j11_l = $st11_l | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.l legacy admission with drifted runner helper (lib/*.ps1) refuses skip as UNVERIFIED" (
        ($run11_l.ExitCode -eq 1) -and ($j11_l.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $depArt2))
    ) "state=$($j11_l.state) reason=$($j11_l.fail_reason)"

    # Restore helper to V1
    "function Get-HelperMessage { return 'HELPER_V1' }" | Set-Content -LiteralPath $depHelper -Encoding ASCII

    # R11.m: Runner with imported helper where admission lacks runner_deps_sha256 pin -> UNVERIFIED
    Reset-DepState
    $adm_m = @{
        manifest_sha256   = $origDepManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $depRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path      = $depArt1
                raw_sha256    = $depArt1Sha
                runner_sha256 = $origDepRunnerSha
                set_sha256    = $origDepSetSha
                binary_sha256 = $origDepBinSha
            }
        )
    }
    ConvertTo-Json -InputObject $adm_m -Depth 6 | Set-Content -LiteralPath $depAdmissionPath -Encoding UTF8
    $run11_m = Invoke-Batch -ManifestPath $depManifestPath -StateDir $s11_dep.StateDir
    $st11_m = Get-State -StateDir $s11_dep.StateDir
    $j11_m = $st11_m | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.m legacy admission lacking runner_deps_sha256 pin when helper exists refuses skip as UNVERIFIED" (
        ($run11_m.ExitCode -eq 1) -and ($j11_m.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $depArt2))
    ) "state=$($j11_m.state) reason=$($j11_m.fail_reason)"

    # R11.n: Fully pinned legacy admission with runner dependencies skips job1 and completes job2
    Reset-DepState
    ConvertTo-Json -InputObject $adm_l -Depth 6 | Set-Content -LiteralPath $depAdmissionPath -Encoding UTF8
    $run11_n = Invoke-Batch -ManifestPath $depManifestPath -StateDir $s11_dep.StateDir
    $st11_n = Get-State -StateDir $s11_dep.StateDir
    $j11_n_1 = $st11_n | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    $j11_n_2 = $st11_n | Where-Object { $_.id -eq "job2" } | Select-Object -First 1
    Assert-Case "R11.n fully pinned legacy admission with matching runner dependencies skips job1 and completes job2" (
        ($run11_n.ExitCode -eq 0) -and ($j11_n_1.state -eq "done") -and ($j11_n_2.state -eq "done") -and (Test-Path -LiteralPath $depArt2)
    ) "exit=$($run11_n.ExitCode) j1=$($j11_n_1.state) j2=$($j11_n_2.state)"

    # R11.o..R11.q: R4-1D specified source drift, unpinned source, and fully pinned source cages
    $s11_src = New-TestScenario -CaseName "R11_src_cage"
    $srcJobMq5 = Join-Path $s11_src.CaseDir "ExpertSource.mq5"
    "// SOURCE_V1_INITIAL" | Set-Content -LiteralPath $srcJobMq5 -Encoding ASCII
    $srcJobSet = Join-Path $s11_src.CaseDir "source_test.set"
    "_0_FastMA=10" | Set-Content -LiteralPath $srcJobSet -Encoding ASCII
    $srcJobBin = Join-Path $s11_src.CaseDir "ExpertSource.ex5"
    "BINARY_SRC_TEST" | Set-Content -LiteralPath $srcJobBin -Encoding ASCII
    $srcArt1 = Join-Path $s11_src.CaseDir "reports\job1_report.htm"
    "REPORT_SRC_V1" | Set-Content -LiteralPath $srcArt1 -Encoding ASCII
    $srcArt2 = Join-Path $s11_src.CaseDir "reports\job2_report.htm"
    $srcExitFile2 = Join-Path $s11_src.CaseDir "job2_exit.txt"
    "0" | Set-Content -LiteralPath $srcExitFile2 -Encoding ASCII

    $srcManifestPath = Join-Path $s11_src.CaseDir "manifest.json"
    $srcJobs = @(
        @{
            id              = "job1"
            runner          = $mockRunner
            lane            = "ID_TEST_LANE"
            model           = 1
            source_path     = $srcJobMq5
            expect_artifact = $srcArt1
            args            = @(
                "-SetFile", $srcJobSet,
                "-BinaryPath", $srcJobBin,
                "-MarkerFile", $srcArt1,
                "-JobId", "job1"
            )
            set_file        = $srcJobSet
            binary_path     = $srcJobBin
        },
        @{
            id              = "job2"
            runner          = $mockRunner
            lane            = "ID_TEST_LANE"
            model           = 1
            expect_artifact = $srcArt2
            args            = @(
                "-MarkerFile", $srcArt2,
                "-ExitCode", 0,
                "-ExitCodeFile", $srcExitFile2,
                "-JobId", "job2"
            )
        }
    )
    ConvertTo-Json -InputObject $srcJobs -Depth 8 | Set-Content -LiteralPath $srcManifestPath -Encoding UTF8

    $origSrcManifestSha = (Get-FileHash -LiteralPath $srcManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $origSrcRunnerSha   = (Get-FileHash -LiteralPath $mockRunner -Algorithm SHA256).Hash.ToLowerInvariant()
    $origSrcRunnerDeps  = Get-RunnerDependencySha256-Local -RunnerPath $mockRunner
    $origSrcSetSha      = (Get-FileHash -LiteralPath $srcJobSet -Algorithm SHA256).Hash.ToLowerInvariant()
    $origSrcBinSha      = (Get-FileHash -LiteralPath $srcJobBin -Algorithm SHA256).Hash.ToLowerInvariant()
    $origSrcMq5Sha      = (Get-FileHash -LiteralPath $srcJobMq5 -Algorithm SHA256).Hash.ToLowerInvariant()
    $srcArt1Sha         = (Get-FileHash -LiteralPath $srcArt1 -Algorithm SHA256).Hash.ToLowerInvariant()

    $legacySrcState = @(
        @{
            id          = "job1"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "done"
            start       = "2026-10-31T01:00:00"
            end         = "2026-10-31T01:05:00"
            exit_code   = 0
            fail_reason = $null
        },
        @{
            id          = "job2"
            runner      = $mockRunner
            lane        = "ID_TEST_LANE"
            model       = 1
            state       = "pending"
            start       = $null
            end         = $null
            exit_code   = $null
            fail_reason = $null
        }
    )

    $srcAdmissionPath = Join-Path $s11_src.CaseDir "RESUME_ADMISSION.json"

    function Reset-SrcState {
        ConvertTo-Json -InputObject $legacySrcState -Depth 6 | Set-Content -LiteralPath (Join-Path $s11_src.StateDir "state.json") -Encoding UTF8
        Remove-Item -LiteralPath $srcArt2 -Force -ErrorAction SilentlyContinue
    }

    # R11.o: Specified source_path with drifted .mq5 -> UNVERIFIED
    Reset-SrcState
    "// SOURCE_V2_DRIFTED_BYTES" | Set-Content -LiteralPath $srcJobMq5 -Encoding ASCII
    $adm_o = @{
        manifest_sha256   = $origSrcManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $mockRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path           = $srcArt1
                raw_sha256         = $srcArt1Sha
                runner_sha256      = $origSrcRunnerSha
                runner_deps_sha256 = $origSrcRunnerDeps
                set_sha256         = $origSrcSetSha
                binary_sha256      = $origSrcBinSha
                source_sha256      = $origSrcMq5Sha
            }
        )
    }
    ConvertTo-Json -InputObject $adm_o -Depth 6 | Set-Content -LiteralPath $srcAdmissionPath -Encoding UTF8
    $run11_o = Invoke-Batch -ManifestPath $srcManifestPath -StateDir $s11_src.StateDir
    $st11_o = Get-State -StateDir $s11_src.StateDir
    $j11_o = $st11_o | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.o legacy admission with drifted source_path (.mq5) refuses skip as UNVERIFIED" (
        ($run11_o.ExitCode -eq 1) -and ($j11_o.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $srcArt2))
    ) "state=$($j11_o.state) reason=$($j11_o.fail_reason)"

    # Restore source file to V1
    "// SOURCE_V1_INITIAL" | Set-Content -LiteralPath $srcJobMq5 -Encoding ASCII

    # R11.p: Specified source_path lacking source_sha256 in admission -> UNVERIFIED
    Reset-SrcState
    $adm_p = @{
        manifest_sha256   = $origSrcManifestSha
        done_cases_frozen = @(
            @{
                state = @{
                    id        = "job1"
                    state     = "done"
                    exit_code = 0
                    runner    = $mockRunner
                    lane      = "ID_TEST_LANE"
                    model     = 1
                    start     = "2026-10-31T01:00:00"
                    end       = "2026-10-31T01:05:00"
                }
                raw_path           = $srcArt1
                raw_sha256         = $srcArt1Sha
                runner_sha256      = $origSrcRunnerSha
                runner_deps_sha256 = $origSrcRunnerDeps
                set_sha256         = $origSrcSetSha
                binary_sha256      = $origSrcBinSha
            }
        )
    }
    ConvertTo-Json -InputObject $adm_p -Depth 6 | Set-Content -LiteralPath $srcAdmissionPath -Encoding UTF8
    $run11_p = Invoke-Batch -ManifestPath $srcManifestPath -StateDir $s11_src.StateDir
    $st11_p = Get-State -StateDir $s11_src.StateDir
    $j11_p = $st11_p | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R11.p legacy admission lacking source_sha256 pin when source_path exists refuses skip as UNVERIFIED" (
        ($run11_p.ExitCode -eq 1) -and ($j11_p.state -eq "UNVERIFIED") -and (-not (Test-Path -LiteralPath $srcArt2))
    ) "state=$($j11_p.state) reason=$($j11_p.fail_reason)"

    # R11.q: Fully pinned legacy admission with matching source_sha256 skips job1 as done and completes job2
    Reset-SrcState
    ConvertTo-Json -InputObject $adm_o -Depth 6 | Set-Content -LiteralPath $srcAdmissionPath -Encoding UTF8
    $run11_q = Invoke-Batch -ManifestPath $srcManifestPath -StateDir $s11_src.StateDir
    $st11_q = Get-State -StateDir $s11_src.StateDir
    $j11_q_1 = $st11_q | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    $j11_q_2 = $st11_q | Where-Object { $_.id -eq "job2" } | Select-Object -First 1
    Assert-Case "R11.q fully pinned legacy admission with matching source_sha256 skips job1 as done and completes job2" (
        ($run11_q.ExitCode -eq 0) -and ($j11_q_1.state -eq "done") -and ($j11_q_2.state -eq "done") -and (Test-Path -LiteralPath $srcArt2)
    ) "exit=$($run11_q.ExitCode) j1=$($j11_q_1.state) j2=$($j11_q_2.state)"

    # --- R12: Missing required native identity before launch ---
    $s12 = New-TestScenario -CaseName "R12_missing_native_identity"
    $missingSet = Join-Path $s12.CaseDir "nonexistent.set"
    $nativeJobs = @(
        @{
            id              = "job1"
            runner          = (Join-Path $repoRoot "scripts\mt5_run.ps1")
            lane            = "ID_TEST_LANE"
            model           = 1
            expect_artifact = $s12.Art1
            args            = @(
                "-Expert", "EA_LAB_TEST\NonExistentEA",
                "-SetFile", $missingSet,
                "-Symbol", "EURUSD",
                "-Period", "H1"
            )
        }
    )
    ConvertTo-Json -InputObject $nativeJobs -Depth 8 | Set-Content -LiteralPath $s12.ManifestPath -Encoding UTF8
    $run12 = Invoke-Batch -ManifestPath $s12.ManifestPath -StateDir $s12.StateDir
    $st12 = Get-State -StateDir $s12.StateDir
    $j12_1 = $st12 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R12.a native runner with missing set/binary is refused BEFORE launch" (
        ($run12.ExitCode -eq 1) -and ($j12_1.state -eq "failed") -and
        ($j12_1.fail_reason -match "required execution identity unresolved before launch")
    ) "state=$($j12_1.state) reason=$($j12_1.fail_reason)"

    # --- R13: Mutation during execution is caught post-run ---
    $s13 = New-TestScenario -CaseName "R13_during_run_mutation"
    $mutatingRunner = Join-Path $s13.CaseDir "mutating_runner.ps1"
    @"
param([string]`$MarkerFile, [string]`$MutateTarget)
"mutated during run" | Set-Content -LiteralPath `$MutateTarget -Encoding ASCII
"artifact written" | Set-Content -LiteralPath `$MarkerFile -Encoding ASCII
exit 0
"@ | Set-Content -LiteralPath $mutatingRunner -Encoding ASCII
    $mutRunJobs = @(
        @{
            id              = "job1"
            runner          = $mutatingRunner
            lane            = "ID_TEST_LANE"
            model           = 1
            source_path     = $s13.Src1
            expect_artifact = $s13.Art1
            args            = @("-MarkerFile", $s13.Art1, "-MutateTarget", $s13.Src1)
        }
    )
    ConvertTo-Json -InputObject $mutRunJobs -Depth 8 | Set-Content -LiteralPath $s13.ManifestPath -Encoding UTF8
    $run13 = Invoke-Batch -ManifestPath $s13.ManifestPath -StateDir $s13.StateDir
    $st13 = Get-State -StateDir $s13.StateDir
    $j13_1 = $st13 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R13.a source/set mutation DURING execution is rejected post-run and not stamped done" (
        ($run13.ExitCode -eq 1) -and ($j13_1.state -eq "failed") -and
        ($j13_1.fail_reason -match "execution identity changed DURING the run")
    ) "state=$($j13_1.state) reason=$($j13_1.fail_reason)"

    # --- R14: Delimiter collision in args (JSON canonical signature) ---
    $s14 = New-TestScenario -CaseName "R14_delimiter_collision"
    $jobs14 = @((Get-Content -LiteralPath $s14.ManifestPath -Raw | ConvertFrom-Json) | ForEach-Object { $_ })
    $jobs14[0].args = @("-MarkerFile", $s14.Art1, "-ExitCode", 0, "-JobId", "a|b", "c")
    ConvertTo-Json -InputObject $jobs14 -Depth 8 | Set-Content -LiteralPath $s14.ManifestPath -Encoding UTF8
    [void](Invoke-Batch -ManifestPath $s14.ManifestPath -StateDir $s14.StateDir)
    # Shift pipe delimiter across element boundary: ("a|b", "c") -> ("a", "b|c")
    $jobs14[0].args = @("-MarkerFile", $s14.Art1, "-ExitCode", 0, "-JobId", "a", "b|c")
    ConvertTo-Json -InputObject $jobs14 -Depth 8 | Set-Content -LiteralPath $s14.ManifestPath -Encoding UTF8
    "0" | Set-Content -LiteralPath $s14.ExitFile2 -Encoding ASCII
    Remove-Item -LiteralPath $s14.Art2 -Force -ErrorAction SilentlyContinue
    $run14 = Invoke-Batch -ManifestPath $s14.ManifestPath -StateDir $s14.StateDir
    $st14 = Get-State -StateDir $s14.StateDir
    $j14_1 = $st14 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
    Assert-Case "R14.a pipe delimiter boundary shift in args triggers IDENTITY_MISMATCH" (
        ($run14.ExitCode -eq 1) -and ($j14_1.state -eq "IDENTITY_MISMATCH") -and
        ($j14_1.fail_reason -match "args")
    ) "state=$($j14_1.state) reason=$($j14_1.fail_reason)"
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Summary: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }
exit 0
