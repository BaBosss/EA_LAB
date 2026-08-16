# Runtime identity collection/validation bridge.
# The canonical comparison logic lives in _triage/factory_os/runtime_identity.py;
# PowerShell only transports records into that validator and returns its result.

function Get-RuntimeIdentityRecords {
    param([Parameter(Mandatory)][string]$DealsRoot)
    $files = @(Get-ChildItem -LiteralPath $DealsRoot -Filter 'EA_LAB_identity_*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object Name)
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($f in $files) {
        if ($f.Name -notmatch '^EA_LAB_identity_[1-9]\d*_[1-9]\d*_\d{8}\.json$') { continue }
        try {
            $doc = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
            $key = "$($doc.account_login)|$($doc.magic)"
            if ($doc.schema -eq 'runtime_identity/1' -and $key -ne '|') { $records.Add($doc) }
        } catch {
            # A malformed sidecar is represented by the absence of a valid record. The
            # summary is therefore LEGACY_UNVERIFIED rather than silently healthy.
        }
    }
    # Do not collapse account|magic to the newest file here. The validator owns current-epoch
    # partitioning; keeping every dated archive is what lets it distinguish a legitimate prior
    # epoch from duplicate current evidence or a mixed current unit.
    # PowerShell 5.1's enumerable binder can throw "Argument types do not match"
    # when an empty generic List is wrapped directly in @(...). Materialise the
    # list explicitly so an empty identity store is a valid LEGACY_UNVERIFIED
    # result instead of aborting the whole control-room snapshot.
    return $records.ToArray()
}

function Get-RuntimeIdentityExpectations {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @{} }
    $out = [ordered]@{}
    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($row in @(Import-Csv -LiteralPath $Path)) {
        if (-not $row.account -or -not $row.magic) {
            $errors.Add('row is missing account or magic') | Out-Null
            continue
        }
        if ($row.account -notmatch '^[1-9]\d*$' -or $row.magic -notmatch '^[1-9]\d*$') {
            $errors.Add("invalid expected key account=$($row.account) magic=$($row.magic)") | Out-Null
            continue
        }
        $key = "$($row.account)|$($row.magic)"
        if ($out.Contains($key)) {
            $errors.Add("duplicate expected key $key") | Out-Null
            continue
        }
        if ($row.PSObject.Properties.Name -notcontains 'attach_epoch' -or
            $row.PSObject.Properties.Name -notcontains 'source_sha256' -or
            $row.PSObject.Properties.Name -notcontains 'artifact_sha256') {
            $errors.Add("expected mapping schema missing binding columns for $key") | Out-Null
        }
        if ($row.account -and $row.magic) {
            [void]($out[$key] = [ordered]@{
                account_login = "$($row.account)"
                magic = "$($row.magic)"
                ea_logical_identity = "$($row.ea_logical_identity)"
                build_receipt = "$($row.build_receipt)"
                config_fingerprint = "$($row.config_fingerprint)"
                config_fingerprint_version = "$($row.config_fingerprint_version)"
                symbol = "$($row.symbol)"
                timeframe = "$($row.timeframe)"
                attach_epoch = "$($row.attach_epoch)"
                source_sha256 = "$($row.source_sha256)"
                artifact_sha256 = "$($row.artifact_sha256)"
            })
        }
    }
    if ($errors.Count -gt 0) { [void]($out['__errors__'] = @($errors)) }
    return ,$out
}

function Get-RuntimeIdentityValidation {
    param([Parameter(Mandatory)][string]$RepoRoot,
          [object[]]$Records = @(),
          [string]$ExpectedPath = '',
          [string]$RegistryPath = '',
          [string]$PythonPath = '')
    $work = Join-Path ([IO.Path]::GetTempPath()) ('runtime_identity_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        $recordsJsonPath = Join-Path $work 'records.json'
        $expectedJsonPath = Join-Path $work 'expected.json'
        if ($ExpectedPath -eq '') { $ExpectedPath = Join-Path $RepoRoot 'portfolio\RUNTIME_IDENTITY_MAP.csv' }
        if ($RegistryPath -eq '') { $RegistryPath = Join-Path $RepoRoot 'portfolio\build_receipts.jsonl' }
        $expected = Get-RuntimeIdentityExpectations -Path $ExpectedPath
        $recordJson = if (@($Records).Count -eq 0) { '[]' } else { @($Records) | ConvertTo-Json -Depth 12 }
        $expectedJson = if ($expected.Count -eq 0) { '{}' } else { $expected | ConvertTo-Json -Depth 12 }
        [IO.File]::WriteAllText($recordsJsonPath, $recordJson, (New-Object Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText($expectedJsonPath, $expectedJson, (New-Object Text.UTF8Encoding($false)))
        if ($PythonPath -eq '') { $PythonPath = Join-Path $RepoRoot 'tools\python312\python.exe' }
        $py = $PythonPath
        $validator = Join-Path $RepoRoot '_triage\factory_os\runtime_identity.py'
        $out = & $py $validator verify-batch $recordsJsonPath $expectedJsonPath $RegistryPath 2>&1
        $json = @($out) | Where-Object { "$($_)" -match '^\{' } | Select-Object -Last 1
        if (-not $json) { throw "runtime identity validator produced no JSON result: $($out -join ' ')" }
        return ($json | ConvertFrom-Json)
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-RuntimeIdentityFirstTrade {
    param([Parameter(Mandatory)][string]$RepoRoot,
          [Parameter(Mandatory)][object]$Identity,
          [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Deals,
          [bool]$DealsFresh = $true,
          [string]$PythonPath = '')
    if ($PythonPath -eq '') { $PythonPath = Join-Path $RepoRoot 'tools\python312\python.exe' }
    $work = Join-Path ([IO.Path]::GetTempPath()) ('runtime_first_trade_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        $identityPath = Join-Path $work 'identity.json'
        $dealsPath = Join-Path $work 'deals.json'
        [IO.File]::WriteAllText($identityPath, ($Identity | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
        $dealArray = @($Deals)
        $dealJson = if ($dealArray.Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject $dealArray -Depth 12 }
        [IO.File]::WriteAllText($dealsPath, $dealJson, (New-Object Text.UTF8Encoding($false)))
        $validator = Join-Path $RepoRoot '_triage\factory_os\runtime_identity.py'
        $args = @($validator, 'derive-first-trade', $identityPath, $dealsPath)
        if (-not $DealsFresh) { $args += '--stale' }
        $out = & $PythonPath @args 2>&1
        $json = @($out) | Where-Object { "$($_)" -match '^\{' } | Select-Object -Last 1
        if (-not $json) { throw "first-trade verifier produced no JSON result: $($out -join ' ')" }
        return ($json | ConvertFrom-Json)
    } catch {
        return [pscustomobject]@{
            state = 'FORWARD_TEST_UNTRUSTED'
            reasons = @([pscustomobject]@{ code = 'FIRST_TRADE_VERIFIER_UNAVAILABLE'; detail = "$($_.Exception.Message)" })
            identity = $Identity
            first_trade_epoch = $null
            qualifying_deal = $null
        }
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-RuntimeIdentityForwardStates {
    param([Parameter(Mandatory)][string]$RepoRoot,
          [Parameter(Mandatory)][string]$DealsRoot,
          [object[]]$RuntimeRecords = @(),
          [string]$PythonPath = '')
    $findings = New-Object System.Collections.Generic.List[object]
    foreach ($record in @($RuntimeRecords)) {
        $account = "$($record.account_login)"
        $magic = "$($record.magic)"
        $result = $null
        if ("$($record.validation_state)" -ne 'PASS') {
            $result = [pscustomobject]@{
                state = 'INVALID_RUNTIME_IDENTITY'
                reasons = @([pscustomobject]@{ code = 'RUNTIME_IDENTITY_NOT_VALIDATED'; detail = "$($record.validation_state)" })
                first_trade_epoch = $null; qualifying_deal = $null
            }
        } else {
            $latest = @(Get-ChildItem -LiteralPath $DealsRoot -Filter ("EA_LAB_deals_" + $account + "_*.csv") -File -ErrorAction SilentlyContinue |
                        Sort-Object Name | Select-Object -Last 1)
            $fresh = $false
            $deals = @()
            if ($latest.Count -gt 0) {
                $ageH = ((Get-Date) - $latest[0].LastWriteTime).TotalHours
                if ($ageH -le 30) {
                    $fresh = $true
                    try {
                        foreach ($row in @(Import-Csv -LiteralPath $latest[0].FullName)) {
                            $deals += [ordered]@{
                                account_login = $account
                                ticket = "$($row.ticket)"
                                time_unix = "$($row.time_unix)"
                                symbol = "$($row.symbol)"
                                magic = "$($row.magic)"
                                entry = "$($row.entry)"
                            }
                        }
                    } catch {
                        $fresh = $true
                        $deals = @([ordered]@{ account_login = $account })
                    }
                }
            }
            $result = Invoke-RuntimeIdentityFirstTrade -RepoRoot $RepoRoot -Identity $record `
                -Deals $deals -DealsFresh:$fresh -PythonPath $PythonPath
        }
        $findings.Add([ordered]@{
            account_login = $account
            magic = $magic
            state = "$($result.state)"
            first_trade_epoch = $result.first_trade_epoch
            qualifying_deal = $result.qualifying_deal
            reasons = @($result.reasons)
        }) | Out-Null
    }

    $states = @($findings | ForEach-Object { $_.state })
    $overall = 'NO_VALID_RUNTIME_IDENTITY'
    if ($findings.Count -gt 0) {
        if (@($states | Where-Object { $_ -notin @('AWAITING_FIRST_TRADE','VERIFIED') }).Count -gt 0) {
            $overall = 'FORWARD_TEST_UNTRUSTED'
        } elseif ($states -contains 'VERIFIED') {
            $overall = 'FORWARD_TEST_EVIDENCE_STARTED'
        } else {
            $overall = 'DEMO_DEPLOYED_AWAITING_FIRST_TRADE'
        }
    }
    return [pscustomobject]@{ state = $overall; findings = $findings.ToArray() }
}
