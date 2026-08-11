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
    return @($records)
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
