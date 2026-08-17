# compile_zeus.ps1 -- Zeus XAU Template-precondition validation compile harness.
#
# Stages the frozen source + its two local includes into the target lane's Experts root and
# compiles with MetaEditor64, asserting "0 errors, 0 warnings" and that the .ex5 exists.
# Flat layout in the Experts ROOT (subdirectory creation is blocked in this environment).
param(
    [Parameter(Mandatory)][string]$TargetName,
    [string]$DataDir = 'D:\Meta 5c',
    [string]$MetaEditor = 'D:\Meta 5c\MetaEditor64.exe'
)
$ErrorActionPreference = 'Stop'

$laneRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcDir   = Join-Path $laneRoot 'src'
if (-not (Test-Path -LiteralPath $MetaEditor)) { throw "MetaEditor not found: $MetaEditor" }

$laneExperts = Join-Path $DataDir 'MQL5\Experts'
if (-not (Test-Path -LiteralPath $laneExperts)) { throw "tester Experts dir not found: $laneExperts" }

$target   = Join-Path $laneExperts $TargetName
$artifact = [IO.Path]::ChangeExtension($target, '.ex5')
$log      = Join-Path $laneExperts ([IO.Path]::GetFileNameWithoutExtension($TargetName) + '_compile.log')

if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact -Force }
if (Test-Path -LiteralPath $log)      { Remove-Item -LiteralPath $log -Force }

Copy-Item -LiteralPath (Join-Path $srcDir 'ZeusInspired_GridLog_rev01.mq5') -Destination $target -Force
Copy-Item -LiteralPath (Join-Path $srcDir 'STANDALONE_RISK_BUNDLE.mqh') -Destination $laneExperts -Force
Copy-Item -LiteralPath (Join-Path $srcDir 'Regime_Standalone.mqh') -Destination $laneExperts -Force

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
