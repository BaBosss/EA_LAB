[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $root 'scripts\use_python.ps1')
$py = Assert-PortablePython -Root $root -Provision
$prepared = & $py -B (Join-Path $PSScriptRoot 'prepare_compile.py')
if ($LASTEXITCODE -ne 0) { throw 'compile preparation failed; inspect before retry' }
$prepared = $prepared | ConvertFrom-Json
$editor = 'D:\Meta 5\metaeditor64.exe'
if (-not (Test-Path -LiteralPath $editor)) { throw 'required MetaEditor missing' }
$evidence = Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$receipts = @()
foreach ($item in @(
    @{ Name='parent'; Relative='DF03_RepairedParent.mq5' },
    @{ Name='adapter'; Relative='ea_template\tests\GridFibo_AdapterCompile.mq5' }
)) {
    $source = Join-Path $prepared.stage $item.Relative
    $log = Join-Path $prepared.stage ($item.Name + '.log')
    $args = @('/compile:"' + $source + '"', '/log:"' + $log + '"')
    $started = (Get-Date).ToUniversalTime().ToString('o')
    $process = Start-Process -FilePath $editor -ArgumentList $args -WindowStyle Hidden -PassThru -Wait
    if (-not (Test-Path -LiteralPath $log)) { throw "compiler log missing: $log" }
    $text = Get-Content -LiteralPath $log -Raw -Encoding Unicode
    Copy-Item -LiteralPath $log -Destination (Join-Path $evidence ($item.Name + '.log'))
    Write-Output $text
    $match = [regex]::Match($text, 'Result:\s*(\d+) errors?,\s*(\d+) warnings?')
    if (-not $match.Success) { throw "compiler summary missing: $log" }
    $product = [IO.Path]::ChangeExtension($source, '.ex5')
    $receipts += [ordered]@{
        name=$item.Name; source=$source; source_sha256=(Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant()
        log=$log; retained_log=(Join-Path $evidence ($item.Name + '.log'))
        log_sha256=(Get-FileHash -LiteralPath $log).Hash.ToLowerInvariant()
        started_utc=$started; exit_code=$process.ExitCode
        errors=[int]$match.Groups[1].Value; warnings=[int]$match.Groups[2].Value
        ex5=$product; ex5_exists=(Test-Path -LiteralPath $product)
        warning_lines=@(($text -split "`r?`n") | Where-Object { $_ -match 'warning \d+:' })
    }
    if ([int]$match.Groups[1].Value -ne 0 -or -not (Test-Path -LiteralPath $product)) {
        $receipts | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $evidence 'failed_compile.json') -Encoding UTF8
        throw 'compile failed; inspect HEAD/files/logs before any bounded repair'
    }
}
[ordered]@{
    classification='LOCAL_ADAPTER_COMPILE_ONLY_PENDING_DIFFERENT_FAMILY_REVIEW'
    metaeditor=$editor; metaeditor_sha256=(Get-FileHash -LiteralPath $editor).Hash.ToLowerInvariant()
    metaeditor_version=(Get-Item -LiteralPath $editor).VersionInfo.FileVersion
    inputs=$prepared; compiles=$receipts
} | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $evidence 'compile_receipt.json') -Encoding UTF8
