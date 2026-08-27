$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ModuleRoot = Split-Path -Parent $PSScriptRoot
$PolicyScript = Join-Path $ModuleRoot 'ponytail_policy.ps1'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        $script:Passed++
        Write-Output "PASS $Name"
    } else {
        $script:Failed++
        Write-Output "FAIL $Name :: $Detail"
    }
}

function New-Contract {
    param([string]$Mode, [string]$WorkType, [string[]]$Paths)
    return [ordered]@{
        task_id = 'PONYTAIL-TEST'
        requested_mode = $Mode
        work_type = $WorkType
        paths = @($Paths)
    }
}

function Invoke-Policy {
    param($Contract)
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("ea_lab_ponytail_" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        [IO.File]::WriteAllText($tmp, ($Contract | ConvertTo-Json -Depth 6), $Utf8NoBom)
        $raw = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PolicyScript -InputPath $tmp 2>&1)
        $exitCode = $LASTEXITCODE
        $text = ($raw | ForEach-Object { $_.ToString() }) -join "`n"
        $obj = $null
        if ($exitCode -eq 0 -or $exitCode -eq 2) {
            try { $obj = $text | ConvertFrom-Json } catch { }
        }
        return [pscustomobject]@{ ExitCode=$exitCode; Text=$text; Result=$obj }
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

$tooling = Invoke-Policy (New-Contract 'auto' 'tooling' @('tools/example/checker.ps1'))
Assert-True 'auto tooling exits 0' ($tooling.ExitCode -eq 0) $tooling.Text
Assert-True 'auto tooling selects full' ($null -ne $tooling.Result -and $tooling.Result.decision -eq 'ALLOW' -and $tooling.Result.effective_mode -eq 'full') $tooling.Text

$docs = Invoke-Policy (New-Contract 'auto' 'docs' @('docs/research/example.md'))
Assert-True 'auto docs selects full' ($null -ne $docs.Result -and $docs.Result.decision -eq 'ALLOW' -and $docs.Result.effective_mode -eq 'full') $docs.Text

$core = Invoke-Policy (New-Contract 'auto' 'tooling' @('ea_template/core/RiskControl.mqh'))
Assert-True 'protected core downgrades to review' ($null -ne $core.Result -and $core.Result.decision -eq 'DOWNGRADE' -and $core.Result.effective_mode -eq 'review') $core.Text

$risk = Invoke-Policy (New-Contract 'full' 'risk' @('tools/example.ps1'))
Assert-True 'risk work type downgrades to review' ($null -ne $risk.Result -and $risk.Result.decision -eq 'DOWNGRADE' -and $risk.Result.effective_mode -eq 'review') $risk.Text

$mq5 = Invoke-Policy (New-Contract 'lite' 'tooling' @('ea_projects/Test/Test.mq5'))
Assert-True 'EA source downgrades to review' ($null -ne $mq5.Result -and $mq5.Result.decision -eq 'DOWNGRADE' -and $mq5.Result.effective_mode -eq 'review') $mq5.Text

$nestedLauncher = Invoke-Policy (New-Contract 'auto' 'tooling' @('scripts/lib/deployment_status.ps1'))
Assert-True 'nested deploy launcher downgrades to review' ($null -ne $nestedLauncher.Result -and $nestedLauncher.Result.decision -eq 'DOWNGRADE' -and $nestedLauncher.Result.effective_mode -eq 'review') $nestedLauncher.Text

$protectedDirectoryPaths = @('scripts/deploy/run.ps1','scripts/a/live/start.ps1','scripts/a/b/risk/check.ps1','scripts/a/mt4/bridge.ps1','scripts/a/b/mt5/bridge.ps1','scripts/a/deployment/status.ps1')
foreach ($protectedDirectoryPath in $protectedDirectoryPaths) {
    $directoryProtected = Invoke-Policy (New-Contract 'auto' 'tooling' @($protectedDirectoryPath))
    Assert-True "protected directory segment downgrades to review: $protectedDirectoryPath" ($null -ne $directoryProtected.Result -and $directoryProtected.Result.decision -eq 'DOWNGRADE' -and $directoryProtected.Result.effective_mode -eq 'review') $directoryProtected.Text
}
$ordinaryScript = Invoke-Policy (New-Contract 'auto' 'tooling' @('scripts/lib/format_status.ps1'))
Assert-True 'ordinary low-risk nested script remains full' ($null -ne $ordinaryScript.Result -and $ordinaryScript.Result.decision -eq 'ALLOW' -and $ordinaryScript.Result.effective_mode -eq 'full') $ordinaryScript.Text

$review = Invoke-Policy (New-Contract 'review' 'risk' @('ea_template/core/Money.mqh'))
Assert-True 'explicit review is allowed on protected code' ($null -ne $review.Result -and $review.Result.decision -eq 'ALLOW' -and $review.Result.effective_mode -eq 'review') $review.Text

$off = Invoke-Policy (New-Contract 'off' 'tooling' @('tools/example.ps1'))
Assert-True 'off is allowed' ($null -ne $off.Result -and $off.Result.decision -eq 'ALLOW' -and $off.Result.effective_mode -eq 'off') $off.Text

$ultra = Invoke-Policy (New-Contract 'ultra' 'tooling' @('tools/example.ps1'))
Assert-True 'ultra is refused in v1' ($ultra.ExitCode -eq 2 -and $null -ne $ultra.Result -and $ultra.Result.decision -eq 'REFUSE') $ultra.Text

$mixed = Invoke-Policy (New-Contract 'full' 'tooling' @('tools/example.ps1','_vps_deploy/live.set'))
Assert-True 'mixed protected paths downgrade to review' ($null -ne $mixed.Result -and $mixed.Result.decision -eq 'DOWNGRADE' -and $mixed.Result.effective_mode -eq 'review') $mixed.Text

$unknown = Invoke-Policy (New-Contract 'auto' 'mystery' @('misc/unknown.file'))
Assert-True 'unknown classification fails closed to review' ($null -ne $unknown.Result -and $unknown.Result.decision -eq 'DOWNGRADE' -and $unknown.Result.effective_mode -eq 'review') $unknown.Text

$traversal = Invoke-Policy (New-Contract 'full' 'tooling' @('../outside.ps1'))
Assert-True 'path traversal fails closed to review' ($null -ne $traversal.Result -and $traversal.Result.decision -eq 'DOWNGRADE' -and $traversal.Result.effective_mode -eq 'review') $traversal.Text

$missingMode = Invoke-Policy ([ordered]@{work_type='tooling';paths=@('tools/example.ps1')})
Assert-True 'missing mode refuses as structured JSON' ($missingMode.ExitCode -eq 2 -and $null -ne $missingMode.Result -and $missingMode.Result.decision -eq 'REFUSE' -and $missingMode.Result.reasons -contains 'unknown_requested_mode') $missingMode.Text

if ($null -ne $tooling.Result) {
    $preserve = @($tooling.Result.preserve)
    Assert-True 'authority is never granted' ($tooling.Result.authority_granted -eq $false) ($tooling.Result | ConvertTo-Json -Depth 8)
    Assert-True 'safety and evidence are preserved' (($preserve -contains 'validation') -and ($preserve -contains 'error_handling') -and ($preserve -contains 'security') -and ($preserve -contains 'observability_and_diagnostics') -and ($preserve -contains 'deterministic_fail_closed_behavior') -and ($preserve -contains 'tests_cages_and_negative_tests') -and ($preserve -contains 'evidence_and_auditability') -and ($preserve -contains 'owner_hard_stop_guards')) (($preserve -join ','))
    Assert-True 'optimization target is complexity not LOC' ($tooling.Result.optimization_target -eq 'minimum_necessary_complexity') ($tooling.Result.optimization_target)
    Assert-True 'upstream pin is exact' ($tooling.Result.upstream.commit -eq '2ed6c52c9d7e5e56942508591085fd45dea277d3' -and $tooling.Result.upstream.version -eq '4.9.0') ($tooling.Result.upstream | ConvertTo-Json -Compress)
}

Write-Output ("RESULT passed={0} failed={1}" -f $script:Passed,$script:Failed)
if ($script:Failed -gt 0) { exit 1 }
exit 0