<#
Generate the eight canonical Boss regression .set files as declared full surfaces.

The existing regression files are the source of intended values.  This command only
adds the generator's provenance header and fills any newly exposed input with the
source-declared default.  It refuses an existing-value delta, so a set regeneration
cannot become a strategy/configuration change by accident.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$PythonExe = '',
    [string]$GeneratorPath = '',
    [switch]$CheckOnly,
    [switch]$TestOnly
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$py = if ($PythonExe) { $PythonExe } else { Join-Path $RepoRoot 'tools\python312\python.exe' }
$pyLib = Join-Path (Split-Path $py -Parent) 'Lib\encodings'
if ((-not (Test-Path -LiteralPath $py -PathType Leaf) -or -not (Test-Path -LiteralPath $pyLib -PathType Container)) -and (Test-Path -LiteralPath 'D:\EA_LAB\tools\python312\python.exe' -PathType Leaf)) { $py = 'D:\EA_LAB\tools\python312\python.exe' }
if (-not (Test-Path -LiteralPath $py -PathType Leaf)) { throw "portable Python not found: $py" }
$generator = if ($GeneratorPath) { $GeneratorPath } else { Join-Path $RepoRoot '_triage\factory_os\gen_default_preset.py' }
$setDir = Join-Path $RepoRoot 'ea_template\sets\regression'
$tmpDir = Join-Path ([IO.Path]::GetTempPath()) ('tpl_declared_' + [guid]::NewGuid().ToString('N'))
$bosses = @(
    @{ Tag = 'LAB_ENTRY_11'; Name = 'Boss_11_GridTrend'; Source = 'Boss_11_GridTrend_defaults.set' },
    @{ Tag = 'LAB_ENTRY_12'; Name = 'Boss_12_Breakout'; Source = 'Boss_12_Breakout_defaults.set' },
    @{ Tag = 'LAB_ENTRY_13'; Name = 'Boss_13_MeanRev'; Source = 'Boss_13_MeanRev_defaults.set' },
    @{ Tag = 'LAB_ENTRY_14'; Name = 'Boss_14_GridLog'; Source = 'Boss_14_GridLog_regression_full.set' },
    @{ Tag = 'LAB_ENTRY_15'; Name = 'Boss_15_ST03'; Source = 'Boss_15_ST03_defaults.set' },
    @{ Tag = 'LAB_ENTRY_16'; Name = 'Boss_16_KangarooGrid'; Source = 'Boss_16_KangarooGrid_regression_full.set' },
    @{ Tag = 'LAB_ENTRY_17'; Name = 'Boss_17_Wave5'; Source = 'Boss_17_Wave5_defaults.set' },
    @{ Tag = 'LAB_ENTRY_18'; Name = 'Boss_18_JumStoch'; Source = 'Boss_18_JumStoch_defaults.set' }
)

function Read-SetMap([string]$Path) {
    $map = [ordered]@{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $text = $line.Trim()
        if (-not $text -or $text.StartsWith(';') -or -not $text.Contains('=')) { continue }
        $pair = $text -split '=', 2
        if ($map.Contains($pair[0])) { throw "duplicate set key '$($pair[0])' in $Path" }
        $map[$pair[0]] = $pair[1]
    }
    return $map
}

function Test-EquivalentValue([string]$A, [string]$B) {
    if ($A -eq $B) { return $true }
    $da = 0.0; $db = 0.0
    $okA = [double]::TryParse($A, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$da)
    $okB = [double]::TryParse($B, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$db)
    return ($okA -and $okB -and $da -eq $db)
}

function Get-SetByteProfile([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $bomLength = 0
    $encodingName = 'UTF-8'
    $encoding = New-Object System.Text.UTF8Encoding($false)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bomLength = 3
        $encodingName = 'UTF-8 BOM'
        $encoding = New-Object System.Text.UTF8Encoding($true)
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $bomLength = 2
        $encodingName = 'UTF-16 LE BOM'
        $encoding = New-Object System.Text.UnicodeEncoding($false, $true)
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $bomLength = 2
        $encodingName = 'UTF-16 BE BOM'
        $encoding = New-Object System.Text.UnicodeEncoding($true, $true)
    }
    $text = $encoding.GetString($bytes, $bomLength, $bytes.Length - $bomLength)
    $hasCrlf = $text.Contains("`r`n")
    $withoutCrlf = $text.Replace("`r`n", '')
    $hasLf = $withoutCrlf.Contains("`n")
    $hasCr = $withoutCrlf.Contains("`r")
    $newline = if ($hasCrlf -and -not $hasLf -and -not $hasCr) { 'CRLF' }
               elseif ($hasLf -and -not $hasCrlf -and -not $hasCr) { 'LF' }
               elseif ($hasCr -and -not $hasCrlf -and -not $hasLf) { 'CR' }
               elseif (-not $hasCrlf -and -not $hasLf -and -not $hasCr) { 'NONE' }
               else { 'MIXED' }
    return [pscustomobject]@{
        Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        Newline = $newline
        EncodingName = $encodingName
        Encoding = $encoding
        BomLength = $bomLength
        Text = $text
    }
}

function Get-NormalizedSetText([string]$Path) {
    $text = (Get-SetByteProfile $Path).Text
    return (($text -replace "`r`n", "`n") -replace "`r", "`n")
}

function Assert-NoExistingValueChanges([hashtable]$Old, [hashtable]$New, [string]$Label) {
    $changed = @($Old.Keys | Where-Object { -not $New.Contains($_) -or -not (Test-EquivalentValue $Old[$_] $New[$_]) })
    if ($changed.Count -gt 0) {
        $detail = $changed | ForEach-Object { "$_=[$($Old[$_])] -> [$($New[$_])]" }
        throw "effective parameter delta for ${Label}: $($detail -join '; ')"
    }
}

function Write-SetIfSemanticallyChanged([string]$GeneratedPath, [string]$TargetPath, [bool]$SemanticallyIdentical = $false) {
    # gen_default_preset.py intentionally emits LF. Preserve an existing set byte-for-byte
    # when the generated text is otherwise identical; line-ending normalization is not a
    # semantic/configuration change and must not churn the repository's canonical bytes.
    if (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
        $profile = Get-SetByteProfile $TargetPath
        if ($SemanticallyIdentical -or (Get-NormalizedSetText $GeneratedPath) -ceq (Get-NormalizedSetText $TargetPath)) {
            Write-Host ("PRESERVED existing bytes: {0} sha256={1} newline={2} encoding={3}" -f $TargetPath, $profile.Sha256, $profile.Newline, $profile.EncodingName) -ForegroundColor DarkGreen
            return $false
        }
        if ($profile.Newline -eq 'MIXED') { throw "cannot materialize changed set with mixed newline convention: $TargetPath" }
        $normalized = Get-NormalizedSetText $GeneratedPath
        $newline = if ($profile.Newline -eq 'CRLF') { "`r`n" } elseif ($profile.Newline -eq 'CR') { "`r" } else { "`n" }
        $materialized = $normalized.Replace("`n", $newline)
        $payload = $profile.Encoding.GetBytes($materialized)
        $preamble = $profile.Encoding.GetPreamble()
        $bytes = New-Object byte[] ($preamble.Length + $payload.Length)
        [Array]::Copy($preamble, 0, $bytes, 0, $preamble.Length)
        [Array]::Copy($payload, 0, $bytes, $preamble.Length, $payload.Length)
        [IO.File]::WriteAllBytes($TargetPath, $bytes)
        Write-Host ("WROTE changed set using existing bytes convention: {0} newline={1} encoding={2}" -f $TargetPath, $profile.Newline, $profile.EncodingName) -ForegroundColor Yellow
        return $true
    }
    if (-not (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
        Copy-Item -LiteralPath $GeneratedPath -Destination $TargetPath
        Write-Host "WROTE new set: $TargetPath" -ForegroundColor Yellow
        return $true
    }
}

function Invoke-Generator([hashtable]$Boss, [string]$OutPath, [string]$OverlayPath) {
    $args = @($generator, '--root', $RepoRoot, '--build', $Boss.Tag, '--out', $OutPath, '--overlay-set', $OverlayPath)
    & $py @args
    if ($LASTEXITCODE -ne 0) { throw "declared set generation failed for $($Boss.Name)" }
}

if ($TestOnly) { return }

New-Item -ItemType Directory -Force $tmpDir | Out-Null
try {
    foreach ($boss in $bosses) {
        $oldPath = Join-Path $setDir $boss.Source
        if (-not (Test-Path -LiteralPath $oldPath -PathType Leaf)) { throw "source regression set missing: $oldPath" }
        $old = Read-SetMap $oldPath
        $outPath = Join-Path $tmpDir ($boss.Name + '.set')
        Invoke-Generator $boss $outPath $oldPath
        $new = Read-SetMap $outPath

        Assert-NoExistingValueChanges $old $new $boss.Name
        $missing = @($new.Keys | Where-Object { -not $old.Contains($_) })
        if ($boss.Tag -eq 'LAB_ENTRY_16' -and -not $new.Contains('_16_BaseLotMode')) {
            throw 'Boss_16 regeneration did not add the newly exposed _16_BaseLotMode default'
        }
        $target = Join-Path $setDir ($boss.Name + '_defaults.set')
        if ($boss.Tag -eq 'LAB_ENTRY_14') { $target = Join-Path $setDir 'Boss_14_GridLog_regression_full.set' }
        if ($boss.Tag -eq 'LAB_ENTRY_16') { $target = Join-Path $setDir 'Boss_16_KangarooGrid_regression_full.set' }
        Write-Host ("{0}: old={1} generated={2} added={3} target={4}" -f $boss.Name, $old.Count, $new.Count, ($missing -join ','), $target)
        if (-not $CheckOnly) {
            [void](Write-SetIfSemanticallyChanged $outPath $target ($missing.Count -eq 0))
        }
    }
    $summary = 'DECLARED SETS REGENERATED'
    if ($CheckOnly) { $summary = 'DECLARED SET CHECK CLEAN' }
    Write-Host $summary -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
