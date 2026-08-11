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
