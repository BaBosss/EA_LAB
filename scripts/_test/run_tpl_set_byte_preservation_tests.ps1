<#
Deterministic regression-set byte-preservation cage.

Exercises the generator's byte-profile/materialization seam without MT5.
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

function Write-Fixture([string]$Path, [string]$Text, [object]$Encoding) {
    $payload = $Encoding.GetBytes($Text)
    $preamble = $Encoding.GetPreamble()
    $bytes = New-Object byte[] ($preamble.Length + $payload.Length)
    [Array]::Copy($preamble, 0, $bytes, 0, $preamble.Length)
    [Array]::Copy($payload, 0, $bytes, $preamble.Length, $payload.Length)
    [IO.File]::WriteAllBytes($Path, $bytes)
}

function Read-Sha([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$root = Join-Path ([IO.Path]::GetTempPath()) ('tpl_set_bytes_' + [guid]::NewGuid().ToString('N'))
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
New-Item -ItemType Directory -Path $root | Out-Null
try {
    # A: CRLF existing set + semantically identical LF candidate -> no rewrite.
    $a = Join-Path $root 'a.set'; $aCandidate = Join-Path $root 'a.candidate.set'
    Write-Fixture $a "a=1`r`ncomment=stable`r`n" $utf8NoBom
    Write-Fixture $aCandidate "a=1`ncomment=stable`n" $utf8NoBom
    $aBefore = Read-Sha $a; $aChanged = Write-SetIfSemanticallyChanged $aCandidate $a
    $aProfile = Get-SetByteProfile $a
    Assert-True (-not $aChanged -and (Read-Sha $a) -eq $aBefore -and $aProfile.Newline -eq 'CRLF' -and $aProfile.BomLength -eq 0) 'A CRLF no-op preservation'
    Write-Host '[PASS] A CRLF identical generation preserves bytes'

    # B: LF existing set + semantically identical LF candidate -> no rewrite.
    $b = Join-Path $root 'b.set'; $bCandidate = Join-Path $root 'b.candidate.set'
    Write-Fixture $b "a=1`ncomment=stable`n" $utf8NoBom
    Write-Fixture $bCandidate "a=1`ncomment=stable`n" $utf8NoBom
    $bBefore = Read-Sha $b; $bChanged = Write-SetIfSemanticallyChanged $bCandidate $b
    $bProfile = Get-SetByteProfile $b
    Assert-True (-not $bChanged -and (Read-Sha $b) -eq $bBefore -and $bProfile.Newline -eq 'LF' -and $bProfile.BomLength -eq 0) 'B LF no-op preservation'
    Write-Host '[PASS] B LF identical generation preserves bytes'

    # C: UTF-8 BOM convention -> no-op preserves the BOM and bytes.
    $c = Join-Path $root 'c.set'; $cCandidate = Join-Path $root 'c.candidate.set'
    Write-Fixture $c "a=1`r`n" $utf8Bom
    Write-Fixture $cCandidate "a=1`n" $utf8NoBom
    $cBefore = Read-Sha $c; $cChanged = Write-SetIfSemanticallyChanged $cCandidate $c
    $cProfile = Get-SetByteProfile $c
    Assert-True (-not $cChanged -and (Read-Sha $c) -eq $cBefore -and $cProfile.Newline -eq 'CRLF' -and $cProfile.EncodingName -eq 'UTF-8 BOM') 'C UTF-8 BOM preservation'
    Write-Host '[PASS] C UTF-8 BOM convention is preserved'

    # D: legitimate additive generation -> existing CRLF/no-BOM convention is materialized.
    $d = Join-Path $root 'd.set'; $dCandidate = Join-Path $root 'd.candidate.set'
    Write-Fixture $d "a=1`r`n" $utf8Bom
    Write-Fixture $dCandidate "a=1`nb=2`n" $utf8NoBom
    $dChanged = Write-SetIfSemanticallyChanged $dCandidate $d
    $dProfile = Get-SetByteProfile $d
    Assert-True ($dChanged -and $dProfile.Newline -eq 'CRLF' -and $dProfile.EncodingName -eq 'UTF-8 BOM' -and $dProfile.BomLength -eq 3 -and $dProfile.Text -eq "a=1`r`nb=2`r`n") 'D additive materialization'
    Write-Host '[PASS] D additive generation preserves target convention'

    # E: an existing value change remains refused by the shared semantic guard.
    $old = @{ a = '1' }; $new = @{ a = '2' }; $refused = $false
    try { Assert-NoExistingValueChanges $old $new 'fixture' } catch { $refused = $true }
    Assert-True $refused 'E changed existing parameter must refuse'
    Write-Host '[PASS] E changed existing parameter remains refused'

    # F: the second identical generation is a byte-identical no-op.
    $fBefore = Read-Sha $d; $fChanged = Write-SetIfSemanticallyChanged $dCandidate $d
    Assert-True (-not $fChanged -and (Read-Sha $d) -eq $fBefore) 'F second generation idempotence'
    Write-Host '[PASS] F repeated generation is idempotent'

    Write-Host 'TPL SET BYTE PRESERVATION: 6/6 PASS' -ForegroundColor Green
    exit 0
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
