# Build receipt helpers. A receipt is generated before compilation and recorded only after
# MetaEditor produced the artifact successfully. The artifact hash is the independently
# verifiable binding; the runtime may emit the receipt but cannot read its own EX5 hash.

function New-BuildReceiptToken {
    return 'br-' + ([guid]::NewGuid().ToString('N'))
}

function Write-BuildReceiptHeader {
    param([Parameter(Mandatory)][string]$HeaderPath,
          [Parameter(Mandatory)][string]$Receipt)
    $text = "// Generated immediately before compilation.`r`n#ifndef LAB_BUILD_RECEIPT`r`n#define LAB_BUILD_RECEIPT `"$Receipt`" // @CFG_METADATA`r`n#endif`r`n"
    [IO.File]::WriteAllText($HeaderPath, $text, (New-Object Text.UTF8Encoding($false)))
}

function Write-BuildReceiptRecord {
    param([Parameter(Mandatory)][string]$RegistryPath,
          [Parameter(Mandatory)][string]$Receipt,
          [Parameter(Mandatory)][string]$ArtifactPath,
          [Parameter(Mandatory)][string]$SourcePath,
          [Parameter(Mandatory)][string]$EaLogicalIdentity)
    if (-not [IO.File]::Exists($ArtifactPath)) { throw "build receipt artifact is missing: $ArtifactPath" }
    if (-not [IO.File]::Exists($SourcePath)) { throw "build receipt source is missing: $SourcePath" }
    $artifactHash = (Get-FileHash -LiteralPath $ArtifactPath -Algorithm SHA256).Hash.ToLower()
    $sourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToLower()
    if ($artifactHash -notmatch '^[0-9a-f]{64}$' -or $sourceHash -notmatch '^[0-9a-f]{64}$') {
        throw 'build receipt hash calculation did not produce a SHA-256 digest'
    }
    $record = [ordered]@{
        schema = 'build_receipt/1'
        build_receipt = $Receipt
        ea_logical_identity = $EaLogicalIdentity
        artifact_path = [IO.Path]::GetFullPath($ArtifactPath)
        artifact_sha256 = $artifactHash
        source_path = [IO.Path]::GetFullPath($SourcePath)
        source_sha256 = $sourceHash
        generated_at = (Get-Date).ToUniversalTime().ToString('o')
    }
    $parent = Split-Path -Parent $RegistryPath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $line = ($record | ConvertTo-Json -Compress -Depth 5) + [Environment]::NewLine
    [IO.File]::AppendAllText($RegistryPath, $line, (New-Object Text.UTF8Encoding($false)))
}

function New-BuildIdentityResult {
    param([string]$State, [string]$Reason, [string]$ArtifactPath = '',
          [string]$ArtifactSha256 = '', [string]$BuildReceipt = '', [object]$Record = $null)
    return [pscustomobject]@{
        State = $State
        Valid = ($State -eq 'PASS')
        Reason = $Reason
        ArtifactPath = $ArtifactPath
        ArtifactSha256 = $ArtifactSha256
        BuildReceipt = $BuildReceipt
        Record = $Record
    }
}

function Get-BuildReceiptStatus {
    <#
      Bind the exact EX5 the tester will load to an append-only stamped build receipt.

      MQL5 does not expose the embedded receipt to PowerShell, so the registry's artifact SHA
      is the executable identity. A missing/ambiguous/mismatched record is a refusal, never a
      warning that can be separated from a successful run by a caller.
    #>
    param(
        [Parameter(Mandatory)][string]$Expert,
        [Parameter(Mandatory)][string]$ExpertsDir,
        [Parameter(Mandatory)][string]$RegistryPath
    )
    try {
        $expertRel = $Expert -replace '\.ex5$', ''
        if ($expertRel -match '(?i)(^|\\)Boss_14_GridLog_OLD\d*$') {
            return New-BuildIdentityResult 'LEGACY_REFUSED' "legacy Boss_14_GridLog spelling is not an active executable identity: '$Expert'"
        }
        $artifactPath = [IO.Path]::GetFullPath((Join-Path $ExpertsDir ($expertRel + '.ex5')))
        if (-not [IO.File]::Exists($artifactPath)) {
            return New-BuildIdentityResult 'MISSING' "no EX5 at '$artifactPath'" $artifactPath
        }
        if (-not [IO.File]::Exists($RegistryPath)) {
            return New-BuildIdentityResult 'UNVERIFIABLE' "build receipt registry is missing: '$RegistryPath'" $artifactPath
        }
        $artifactSha = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $records = @()
        foreach ($line in @(Get-Content -LiteralPath $RegistryPath -ErrorAction Stop)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try { $record = $line | ConvertFrom-Json -ErrorAction Stop }
            catch { return New-BuildIdentityResult 'INVALID_REGISTRY' "malformed build receipt registry line" $artifactPath $artifactSha }
            if ($record.schema -ne 'build_receipt/1' -or
                ("$($record.build_receipt)" -ne 'UNSTAMPED' -and "$($record.build_receipt)" -notmatch '^br-[0-9a-f]{32}$')) {
                return New-BuildIdentityResult 'INVALID_REGISTRY' "registry contains an invalid build receipt record" $artifactPath $artifactSha
            }
            if ("$($record.artifact_sha256)" -ieq $artifactSha) { $records += $record }
        }
        $matches = $records
        if ($matches.Count -eq 0) {
            return New-BuildIdentityResult 'MISMATCH' "EX5 SHA256 $artifactSha is not bound to a stamped build receipt" $artifactPath $artifactSha
        }
        $exact = @($matches | Where-Object {
            $_.artifact_path -and ([IO.Path]::GetFullPath([string]$_.artifact_path) -ieq $artifactPath)
        })
        if ($exact.Count -eq 1) { $record = $exact[0] }
        elseif ($matches.Count -eq 1) { $record = $matches[0] }
        else {
            return New-BuildIdentityResult 'AMBIGUOUS' "EX5 SHA256 matches multiple build receipts" $artifactPath $artifactSha
        }
        $receipt = "$($record.build_receipt)"
        if ($receipt -eq 'UNSTAMPED' -or $receipt -notmatch '^br-[0-9a-f]{32}$') {
            return New-BuildIdentityResult 'UNSTAMPED' "EX5 is bound to an unstamped receipt" $artifactPath $artifactSha $receipt $record
        }
        if ("$($record.artifact_sha256)" -notmatch '^[0-9a-f]{64}$' -or
            "$($record.source_sha256)" -notmatch '^[0-9a-f]{64}$' -or
            -not $record.source_path) {
            return New-BuildIdentityResult 'INVALID_RECORD' "receipt $receipt lacks complete source/artifact identity" $artifactPath $artifactSha $receipt $record
        }
        if (-not [IO.File]::Exists([string]$record.source_path)) {
            return New-BuildIdentityResult 'UNVERIFIABLE' "receipt $receipt source is unavailable: $($record.source_path)" $artifactPath $artifactSha $receipt $record
        }
        $sourceSha = (Get-FileHash -LiteralPath $record.source_path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($sourceSha -ine "$($record.source_sha256)") {
            return New-BuildIdentityResult 'STALE' "receipt $receipt source SHA256 differs from the recorded build" $artifactPath $artifactSha $receipt $record
        }
        return New-BuildIdentityResult 'PASS' "stamped receipt $receipt" $artifactPath $artifactSha $receipt $record
    }
    catch {
        return New-BuildIdentityResult 'UNVERIFIABLE' $_.Exception.Message
    }
}

function Sync-ManagedCompatibilityArtifact {
    <#
      Refresh the one approved compatibility output from the canonical executable.
      This is a byte copy, never a second compile path. Callers must invoke it only after
      the canonical compile and receipt record have succeeded.
    #>
    param(
        [Parameter(Mandatory)][string]$CanonicalArtifactPath,
        [Parameter(Mandatory)][string]$CompatibilityArtifactPath
    )
    if (-not [IO.File]::Exists($CanonicalArtifactPath)) {
        throw "canonical executable is missing: $CanonicalArtifactPath"
    }
    $parent = Split-Path -Parent $CompatibilityArtifactPath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::Copy($CanonicalArtifactPath, $CompatibilityArtifactPath, $true)
    $canonicalSha = (Get-FileHash -LiteralPath $CanonicalArtifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $compatibilitySha = (Get-FileHash -LiteralPath $CompatibilityArtifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($canonicalSha -ne $compatibilitySha) {
        throw "managed compatibility copy differs from canonical executable: $CompatibilityArtifactPath"
    }
    return [pscustomobject]@{
        State = 'PASS'
        CanonicalArtifactPath = [IO.Path]::GetFullPath($CanonicalArtifactPath)
        CompatibilityArtifactPath = [IO.Path]::GetFullPath($CompatibilityArtifactPath)
        CanonicalSha256 = $canonicalSha
        CompatibilitySha256 = $compatibilitySha
    }
}

function Get-ManagedCompatibilityStatus {
    <#
      Validate Boss_14_GridLog's root compatibility spelling against the exact canonical
      EALabTpl artifact. The canonical artifact remains the receipt-bearing source of truth;
      the root file is valid only when it is an exact byte copy of that artifact.
    #>
    param(
        [Parameter(Mandatory)][string]$ExpertsDir,
        [Parameter(Mandatory)][string]$RegistryPath
    )
    try {
        $canonicalExpert = 'EALabTpl\Boss_14_GridLog'
        $canonical = Get-BuildReceiptStatus -Expert $canonicalExpert -ExpertsDir $ExpertsDir -RegistryPath $RegistryPath
        if (-not $canonical.Valid) {
            return New-BuildIdentityResult $canonical.State ("canonical identity is not valid: {0}" -f $canonical.Reason) $canonical.ArtifactPath $canonical.ArtifactSha256 $canonical.BuildReceipt $canonical.Record
        }
        $rootPath = [IO.Path]::GetFullPath((Join-Path $ExpertsDir 'Boss_14_GridLog.ex5'))
        if (-not [IO.File]::Exists($rootPath)) {
            return New-BuildIdentityResult 'MISSING' "managed compatibility executable is missing: '$rootPath'" $rootPath '' $canonical.BuildReceipt $canonical.Record
        }
        $rootSha = (Get-FileHash -LiteralPath $rootPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($rootSha -ne $canonical.ArtifactSha256) {
            return New-BuildIdentityResult 'MISMATCH' "managed compatibility SHA256 $rootSha differs from canonical SHA256 $($canonical.ArtifactSha256)" $rootPath $rootSha $canonical.BuildReceipt $canonical.Record
        }
        return New-BuildIdentityResult 'PASS' 'managed compatibility executable is an exact copy of the stamped canonical executable' $rootPath $rootSha $canonical.BuildReceipt $canonical.Record
    }
    catch {
        return New-BuildIdentityResult 'UNVERIFIABLE' $_.Exception.Message
    }
}

function Get-SetConfigIdentity {
    param([string]$Path, [object]$Surface)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [pscustomobject]@{ State = 'MISSING'; Valid = $false; Reason = 'no -SetFile supplied'; BuildTag = ''; ConfigFingerprint = ''; ConfigScope = ''; SetSha256 = '' }
    }
    if (-not $Surface -or "$($Surface.State)" -ne 'FULL') {
        return [pscustomobject]@{ State = 'UNDECLARED'; Valid = $false; Reason = 'the .set is not a full declared surface'; BuildTag = ''; ConfigFingerprint = ''; ConfigScope = ''; SetSha256 = '' }
    }
    try {
        $header = @(Get-Content -LiteralPath $Path -ErrorAction Stop | Where-Object {
            $_.Trim() -match '^;\s*build=\S+\s+surface=\d+\s+effective_config_hash='
        } | Select-Object -First 1)
        $m = if ($header.Count -eq 1) { [regex]::Match($header[0].Trim(), '^;\s*build=(\S+)\s+surface=(\d+)\s+effective_config_hash=([0-9a-f]{64})\s*\(([^)]+)\)') } else { $null }
        if (-not $m -or -not $m.Success) {
            return [pscustomobject]@{ State = 'INVALID'; Valid = $false; Reason = 'full .set has no valid config fingerprint header'; BuildTag = ''; ConfigFingerprint = ''; ConfigScope = ''; SetSha256 = '' }
        }
        if ($m.Groups[1].Value -ne "$($Surface.BuildTag)" -or [int]$m.Groups[2].Value -ne [int]$Surface.Declared) {
            return [pscustomobject]@{ State = 'MISMATCH'; Valid = $false; Reason = 'config header disagrees with the parsed surface'; BuildTag = $m.Groups[1].Value; ConfigFingerprint = $m.Groups[3].Value; ConfigScope = $m.Groups[4].Value; SetSha256 = '' }
        }
        $setSha = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        return [pscustomobject]@{ State = 'PASS'; Valid = $true; Reason = 'full surface and config fingerprint are declared'; BuildTag = $m.Groups[1].Value; ConfigFingerprint = $m.Groups[3].Value; ConfigScope = $m.Groups[4].Value; SetSha256 = $setSha }
    }
    catch {
        return [pscustomobject]@{ State = 'UNVERIFIABLE'; Valid = $false; Reason = $_.Exception.Message; BuildTag = ''; ConfigFingerprint = ''; ConfigScope = ''; SetSha256 = '' }
    }
}

function Format-LaunchIdentityLine {
    param([object]$Build, [object]$Config)
    return ("identity: PASS -- build_receipt={0} ex5_sha256={1} build={2} config_fingerprint={3} config_scope={4} set_sha256={5}" -f
        $Build.BuildReceipt, $Build.ArtifactSha256, $Config.BuildTag, $Config.ConfigFingerprint, $Config.ConfigScope, $Config.SetSha256)
}
