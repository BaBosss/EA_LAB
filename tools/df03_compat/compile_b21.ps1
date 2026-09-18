[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $root 'scripts/use_python.ps1')
$b21Python = Assert-PortablePython -Root $root -Provision
& $b21Python -B (Join-Path $PSScriptRoot 'template_engine.py') --check
if ($LASTEXITCODE -ne 0) { throw 'B21 generated dependency check failed' }
$stage = Join-Path ([IO.Path]::GetTempPath()) ('df03-b21-compile-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'ea_template') -Destination $stage -Recurse
$editor = 'D:\Meta 5\metaeditor64.exe'
$evidence = Join-Path $PSScriptRoot 'evidence'
$receipts = @()
foreach ($item in @(
    @{Name='b21_wrapper'; Relative='ea_template/Boss_21_GridFibo.mq5'},
    @{Name='b21_test'; Relative='ea_template/tests/GridFibo_B21_Test.mq5'},
    @{Name='b21_raw_probe'; Relative='ea_template/tests/GridFibo_AdapterCompile.mq5'}
)) {
    $source = Join-Path $stage $item.Relative
    $product = [IO.Path]::ChangeExtension($source, '.ex5')
    if (Test-Path -LiteralPath $product) { throw 'Compile stage contains a pre-existing product' }
    $log = Join-Path $stage ($item.Name + '.log')
    $started = (Get-Date).ToUniversalTime().ToString('o')
    $process = Start-Process -FilePath $editor -ArgumentList @('/compile:"' + $source + '"', '/log:"' + $log + '"') -WindowStyle Hidden -PassThru
    while (-not $process.WaitForExit(1000)) { }
    if (-not (Test-Path -LiteralPath $log)) { throw "Missing compiler log: $log" }
    $text = Get-Content -LiteralPath $log -Raw -Encoding Unicode
    $retained = Join-Path $evidence ($item.Name + '.log')
    Copy-Item -LiteralPath $log -Destination $retained
    $match = [regex]::Match($text, 'Result:\s*(\d+) errors?,\s*(\d+) warnings?')
    if (-not $match.Success) { throw "Missing compiler summary: $log" }
    $receipts += [ordered]@{
        name=$item.Name; source=$source; source_sha256=(Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant()
        log=$retained; log_sha256=(Get-FileHash -LiteralPath $retained).Hash.ToLowerInvariant()
        started_utc=$started; exit_code=$process.ExitCode
        errors=[int]$match.Groups[1].Value; warnings=[int]$match.Groups[2].Value
        ex5=$product; ex5_exists=(Test-Path -LiteralPath $product)
        warning_lines=@(($text -split "`r?`n") | Where-Object { $_ -match 'warning \d+:' })
    }
    [ordered]@{
        classification='AUTHOR_COMPILE_ONLY_NO_RUNTIME_OR_DIFFERENT_FAMILY_ACCEPTANCE'
        metaeditor=$editor; metaeditor_version=(Get-Item -LiteralPath $editor).VersionInfo.FileVersion
        metaeditor_sha256=(Get-FileHash -LiteralPath $editor).Hash.ToLowerInvariant()
        stage=$stage; compiles=$receipts
    } | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $evidence 'b21_compile_receipt.json') -Encoding UTF8
    Write-Output ($item.Name + ': ' + $match.Value)
    if ([int]$match.Groups[1].Value -ne 0 -or -not (Test-Path -LiteralPath $product)) {
        Write-Output $text
        throw 'B21 compile failed; inspect exact diagnostics'
    }
}
