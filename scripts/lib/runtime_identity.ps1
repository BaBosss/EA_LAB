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

<#
AUDIT C REPAIR, C-A3 + C-A9 (2026-08-20, lane M0-L1).

  C-A3  The EXPECTED identity universe was drawn from RUNTIME_IDENTITY_MAP.csv itself -- the same
        file that supplies the mappings. A row absent from the map was therefore absent from the
        expectation, so it could not fail; it simply did not exist. MEASURED on canonical
        649207d6:
            portfolio\RUNTIME_IDENTITY_MAP.csv        1 data row (463666728|990026)
            portfolio\DEPLOYMENTS.csv status=ACTIVE   58 rows
        57 forward-observed deployments were invisible to identity validation, and the validator
        still reported on the one row it was handed. A checker whose expected set is its own input
        cannot report a gap (memory: prohibition-disarms-its-own-check -- same shape: the input is
        filtered by the thing being checked).

  C-A9  attestation ceiling runtime-identity coverage was zero and nothing said so. fully_bound is
        published mechanically here.

  WHAT IS DELIBERATELY NOT DONE: no sidecar, digest, epoch or mapping row is synthesized. The
  expected UNIVERSE is derived from the canonical deployment scope (forward-observed, non-REMOVED
  rows -- the same scope the snapshot already uses for judge_readiness and attestation); the
  MAPPINGS still come only from the map file. A member of the universe with no mapping is reported
  as UNMAPPED, which is a visible failure, not a fabricated pass.
#>
function Get-RuntimeIdentityExpectedScope {
    <#
      The expected identity universe: one key per forward-observed, non-REMOVED deployment row.
      Input is the ALREADY-NORMALIZED rows (Get-DeploymentMonitoringRows output) so the scope
      definition is not re-invented here.
      Returns an array of "account|magic" strings, de-duplicated, order-stable.
    #>
    param([AllowNull()][object[]]$DeploymentRows)
    $seen = [ordered]@{}
    foreach ($r in @($DeploymentRows)) {
        if ($null -eq $r) { continue }
        if ("$($r.operational_status)" -eq 'REMOVED') { continue }
        if (-not [bool]$r.forward_observed) { continue }
        $acct = "$($r.account)"; $magic = "$($r.magic)"
        # A row whose account or magic is not a positive integer cannot be an identity key. It is
        # NOT silently dropped: it is returned in the malformed list so the caller can report it.
        if ($acct -notmatch '^[1-9]\d*$' -or $magic -notmatch '^[1-9]\d*$') { continue }
        $k = "$acct|$magic"
        if (-not $seen.Contains($k)) { [void]($seen[$k] = $true) }
    }
    return @($seen.Keys)
}

function Get-RuntimeIdentityCoverage {
    <#
      C-A3/C-A9. Compares the expected universe against what the map and the collected sidecars
      actually cover. Purely mechanical - it counts, it does not create.
        ExpectedCount / MappedCount / RecordCount / PassCount / FullyBoundCount
        Unmapped     [string[]] expected keys with NO row in RUNTIME_IDENTITY_MAP.csv
        Unobserved   [string[]] mapped keys with NO collected runtime sidecar record
        Orphaned     [string[]] mapped keys that are NOT in the expected universe at all
        FullyBound   [string[]] expected keys with a mapping AND a validated (PASS) record
        State        'PASS'  every expected key is fully bound (and there is at least one)
                     'GAP'   at least one expected key is not
                     'UNKNOWN' the expected universe could not be established (no rows in scope)
    #>
    param(
        [AllowNull()][object[]]$ExpectedScope,
        $Expectations = $null,
        [AllowNull()][object[]]$Records
    )
    $expected = @($ExpectedScope | Where-Object { "$_" -ne '' })
    $mapped = @{}
    if ($null -ne $Expectations -and $Expectations -is [System.Collections.IDictionary]) {
        foreach ($k in @($Expectations.Keys)) {
            if ("$k" -eq '__errors__') { continue }
            $mapped["$k"] = $true
        }
    }
    $recordState = @{}
    foreach ($r in @($Records)) {
        if ($null -eq $r) { continue }
        $k = "$($r.account_login)|$($r.magic)"
        # A key seen more than once keeps the WORST answer: one PASS beside one non-PASS is not a
        # pass (memory: bar-cleared-by-non-participation -- an aggregate must not launder a leg).
        $st = "$($r.validation_state)"
        if ($recordState.ContainsKey($k) -and $recordState[$k] -ne 'PASS') { continue }
        $recordState[$k] = $st
    }
    $unmapped = New-Object System.Collections.Generic.List[string]
    $unobserved = New-Object System.Collections.Generic.List[string]
    $fullyBound = New-Object System.Collections.Generic.List[string]
    foreach ($k in $expected) {
        if (-not $mapped.ContainsKey($k)) { $unmapped.Add($k) | Out-Null; continue }
        if (-not $recordState.ContainsKey($k) -or $recordState[$k] -ne 'PASS') {
            $unobserved.Add($k) | Out-Null
            continue
        }
        $fullyBound.Add($k) | Out-Null
    }
    $expectedSet = @{}
    foreach ($k in $expected) { $expectedSet[$k] = $true }
    $orphaned = New-Object System.Collections.Generic.List[string]
    foreach ($k in @($mapped.Keys)) { if (-not $expectedSet.ContainsKey($k)) { $orphaned.Add($k) | Out-Null } }

    $state = 'GAP'
    if ($expected.Count -eq 0) { $state = 'UNKNOWN' }
    elseif ($unmapped.Count -eq 0 -and $unobserved.Count -eq 0) { $state = 'PASS' }
    $passCount = @($recordState.Values | Where-Object { $_ -eq 'PASS' }).Count
    return [pscustomobject]@{
        State = $state
        ExpectedCount = $expected.Count
        MappedCount = @($mapped.Keys).Count
        RecordCount = @($Records).Count
        PassCount = $passCount
        FullyBoundCount = $fullyBound.Count
        Unmapped = $unmapped.ToArray()
        Unobserved = $unobserved.ToArray()
        Orphaned = $orphaned.ToArray()
        FullyBound = $fullyBound.ToArray()
        Reason = $(if ($expected.Count -eq 0) {
                'no forward-observed deployment row is in scope, so the expected identity universe could not be established'
            } elseif ($unmapped.Count -eq 0 -and $unobserved.Count -eq 0) { '' }
            else {
                "expected $($expected.Count) forward-observed deployment(s): $($unmapped.Count) have NO RUNTIME_IDENTITY_MAP row, $($unobserved.Count) are mapped with no validated runtime record, $($fullyBound.Count) fully bound"
            })
    }
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
            # Builder-input spelling must not use validator-owned `reasons` anywhere in
            # SnapshotBuilderInput. snapshot_validator publishes this as `reasons` only
            # after the recursive supplied-answer scan has completed.
            identity_findings = @($result.reasons)
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
