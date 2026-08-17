# compile_mama.ps1 -- ExpertMAMA (next candidate after ExpertMAPSAR Wave5 C4) compile harness.
#
# Fresh compile of the vendor source copied into src/ExpertMAMA_original.mq5. Same house
# convention as the ExpertMAPSAR lane (M2_WAVE5_C4_MAPSAR/compile_c4.ps1): UTF-16 log, assert
# "0 errors, 0 warnings" AND that the .ex5 artifact exists.
#
# Flat layout in the Experts ROOT on purpose: creating a subdirectory under this data dir is
# blocked in this environment (New-Item reports success and the directory does not appear), and
# the repo already stages EAs flat here (EA_RUNNER.mq5, EA_SUPERTREND.mq5, ...).
param(
    [Parameter(Mandatory)][string]$SourceName,
    [Parameter(Mandatory)][string]$TargetName,
    [string]$DataDir = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
    [string]$MetaEditor = 'D:\Meta 5\MetaEditor64.exe'
)
$ErrorActionPreference = 'Stop'

$laneRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$src      = Join-Path $laneRoot "src\$SourceName"
if (-not (Test-Path -LiteralPath $src)) { throw "lane source not found: $src" }
if (-not (Test-Path -LiteralPath $MetaEditor)) { throw "MetaEditor not found: $MetaEditor" }

$laneExperts = Join-Path $DataDir 'MQL5\Experts'
if (-not (Test-Path -LiteralPath $laneExperts)) { throw "tester Experts dir not found: $laneExperts" }

$target   = Join-Path $laneExperts $TargetName
$artifact = [IO.Path]::ChangeExtension($target, '.ex5')
$log      = Join-Path $laneExperts ([IO.Path]::GetFileNameWithoutExtension($TargetName) + '_compile.log')

if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact -Force }
if (Test-Path -LiteralPath $log)      { Remove-Item -LiteralPath $log -Force }

Copy-Item -LiteralPath $src -Destination $target -Force

Start-Process -FilePath $MetaEditor -ArgumentList @('/compile:"' + $target + '"', '/log:"' + $log + '"') -Wait

if (-not (Test-Path -LiteralPath $log)) { throw "$TargetName compile log missing" }
$text = Get-Content -LiteralPath $log -Raw -Encoding Unicode

$laneLog = Join-Path $laneRoot ('compile\' + [IO.Path]::GetFileNameWithoutExtension($TargetName) + '_compile.log')
Copy-Item -LiteralPath $log -Destination $laneLog -Force

$resultLine = ($text -split "`r?`n" | Where-Object { $_ -match 'Result:' }) -join ' | '
Write-Output "compile log : $laneLog"
Write-Output "result line : $resultLine"

if ($text -notmatch 'Result:\s*0\s+errors,\s*0\s+warnings') { throw "$TargetName did not compile 0 errors / 0 warnings" }
if (-not (Test-Path -LiteralPath $artifact)) { throw "$TargetName produced no .ex5 artifact" }

Write-Output "COMPILE OK  : $TargetName -> 0 errors, 0 warnings"
Write-Output "Expert=     : $([IO.Path]::GetFileNameWithoutExtension($TargetName))"
