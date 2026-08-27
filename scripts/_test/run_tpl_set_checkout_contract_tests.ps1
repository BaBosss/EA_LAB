<#
Deterministic checkout-byte contract cage for the versioned TPL regression sets.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$wrapper = Join-Path $PSScriptRoot '..\generate_tpl_regression_sets.ps1'
. $wrapper -RepoRoot $RepoRoot -TestOnly

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Get-ByteSha([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Read-GitEolAttribute([string]$RepoRelativePath) {
    $line = (& git -C $RepoRoot check-attr eol -- $RepoRelativePath | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $line) { throw "git check-attr failed for $RepoRelativePath" }
    return (($line -split ':')[-1]).Trim()
}

function Read-ParameterMap([string[]]$Lines) {
    $map = [ordered]@{}
    foreach ($line in $Lines) {
        $text = ([string]$line).Trim()
        if (-not $text -or $text.StartsWith(';') -or -not $text.Contains('=')) { continue }
        $pair = $text -split '=', 2
        if ($map.Contains($pair[0])) { throw "duplicate parameter '$($pair[0])'" }
        $map[$pair[0]] = $pair[1]
    }
    return $map
}

function Convert-LfToCrlf([byte[]]$Bytes) {
    $out = New-Object 'System.Collections.Generic.List[byte]'
    for ($i = 0; $i -lt $Bytes.Length; $i++) {
        if ($Bytes[$i] -eq 10 -and ($i -eq 0 -or $Bytes[$i - 1] -ne 13)) { [void]$out.Add(13) }
        [void]$out.Add($Bytes[$i])
    }
    return $out.ToArray()
}

function Get-ParameterMapFromUtf8Bytes([byte[]]$Bytes) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    return Read-ParameterMap (($encoding.GetString($Bytes)) -split "`r?`n")
}

function Assert-MapsEqual([System.Collections.IDictionary]$Expected, [System.Collections.IDictionary]$Actual, [string]$Message) {
    Assert-True ($Expected.Count -eq $Actual.Count) "${Message}: count differs"
    foreach ($key in $Expected.Keys) {
        Assert-True ($Actual.Contains($key) -and $Actual[$key] -ceq $Expected[$key]) "${Message}: $key differs"
    }
}

$manifestPath = Join-Path $RepoRoot 'ea_template\regression_baseline_build6090.manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$regressionPaths = @(& git -C $RepoRoot ls-files -- 'ea_template/sets/regression/*.set' | Where-Object { $_ })
Assert-True ($regressionPaths.Count -gt 0) 'regression set inventory is non-empty'

foreach ($relative in $regressionPaths) {
    Assert-True ((Read-GitEolAttribute $relative) -eq 'lf') "$relative has eol=lf"
    $path = Join-Path $RepoRoot ($relative -replace '/', '\')
    $profile = Get-SetByteProfile $path
    Assert-True ($profile.Newline -eq 'LF') "$relative checks out as LF"
}
Write-Host ("[PASS] all {0} versioned regression sets check out as LF" -f $regressionPaths.Count)

$boss11Case = @($manifest.cases | Where-Object { $_.ea -eq 'Boss_11_GridTrend' })[0]
Assert-True ($null -ne $boss11Case) 'Boss_11 case exists in active Build-6090 manifest'
$boss11Path = Join-Path $RepoRoot (([string]$boss11Case.declared_set_path) -replace '/', '\')
$boss11Bytes = [IO.File]::ReadAllBytes($boss11Path)
$boss11Hash = Get-ByteSha $boss11Bytes
$expectedBoss11Hash = ([string]$boss11Case.declared_set_sha256).ToLowerInvariant()
Assert-True ($boss11Hash -eq $expectedBoss11Hash) 'Boss_11 working-tree hash matches manifest'
$crlfBytes = Convert-LfToCrlf $boss11Bytes
$crlfHash = Get-ByteSha $crlfBytes
Assert-True ($crlfHash -ne $boss11Hash) 'CRLF conversion produces a distinct hash'
Assert-MapsEqual (Get-ParameterMapFromUtf8Bytes $boss11Bytes) (Get-ParameterMapFromUtf8Bytes $crlfBytes) 'Boss_11 logical map'
Assert-True ((Get-ParameterMapFromUtf8Bytes $boss11Bytes).Count -eq 113) 'Boss_11 has 113 parameters'
Write-Host ("[PASS] Boss_11 hash {0}; CRLF hash {1}; logical map unchanged" -f $boss11Hash, $crlfHash)

$manifestCases = @($manifest.cases)
Assert-True ($manifestCases.Count -eq 9) 'active Build-6090 manifest has nine cases'
foreach ($case in $manifestCases) {
    $path = Join-Path $RepoRoot (([string]$case.declared_set_path) -replace '/', '\')
    Assert-True ((Get-ByteSha ([IO.File]::ReadAllBytes($path))) -eq ([string]$case.declared_set_sha256).ToLowerInvariant()) "manifest hash matches: $($case.ea)"
}
Write-Host '[PASS] all eight active-manifest set hashes match'

$unrelatedPaths = @(& git -C $RepoRoot ls-files -- '*.set' | Where-Object { $_ -and $_ -notlike 'ea_template/sets/regression/*.set' })
Assert-True ($unrelatedPaths.Count -gt 0) 'unrelated set inventory is non-empty'
$unrelatedAttrs = @($unrelatedPaths | & git -C $RepoRoot check-attr eol --stdin)
Assert-True ($LASTEXITCODE -eq 0 -and $unrelatedAttrs.Count -eq $unrelatedPaths.Count) 'unrelated set attributes are readable'
foreach ($line in $unrelatedAttrs) {
    Assert-True ((($line -split ':')[-1]).Trim() -ne 'lf') "unrelated .set unexpectedly governed: $line"
}
Write-Host ("[PASS] {0} unrelated .set paths remain outside the narrow eol rule" -f $unrelatedPaths.Count)

Write-Host 'TPL SET CHECKOUT-BYTE CONTRACT: 5/5 PASS' -ForegroundColor Green
