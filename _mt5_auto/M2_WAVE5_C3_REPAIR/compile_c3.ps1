# compile_c3.ps1 -- Wave5 Candidate 3 (ExpertMACD) compile harness.
#
# Stages one lane source into the pinned tester Experts tree and compiles it with the same
# MetaEditor invocation scripts\generate_tpl_baseline.ps1 uses, then asserts the house bar
# of "0 errors, 0 warnings" AND that the .ex5 artifact actually exists.
#
# The compile log is UTF-16 (Unicode) -- reading it as UTF-8 yields a byte soup in which the
# success regex can never match, which is the `prove-the-instrument-can-see-the-file` lesson.
# -Encoding Unicode is therefore load-bearing, not cosmetic.
#
# Emits the resolved Expert= path (relative to MQL5\Experts) so the caller does not have to
# reconstruct it by hand.
param(
    [Parameter(Mandatory)][string]$SourceName,          # e.g. ExpertMACD_original.mq5
    [Parameter(Mandatory)][string]$TargetName,          # e.g. M2W5C3_ORIGINAL.mq5
    [string]$DataDir = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
    [string]$MetaEditor = 'D:\Meta 5\MetaEditor64.exe'
)
$ErrorActionPreference = 'Stop'

$laneRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$src      = Join-Path $laneRoot "src\$SourceName"
if (-not (Test-Path -LiteralPath $src)) { throw "lane source not found: $src" }
if (-not (Test-Path -LiteralPath $MetaEditor)) { throw "MetaEditor not found: $MetaEditor" }

# Flat layout in the Experts ROOT on purpose: creating a subdirectory under this data dir is
# blocked in this environment (New-Item reports success and the directory does not appear), and
# a lane that silently compiles nothing is worse than a lane with a long file name. The repo
# already stages EAs flat here (EA_RUNNER.mq5, EA_SUPERTREND.mq5, ...), so this matches house
# practice. The M2W5C3_ prefix is what keeps this lane's files identifiable.
$laneExperts = Join-Path $DataDir 'MQL5\Experts'
if (-not (Test-Path -LiteralPath $laneExperts)) { throw "tester Experts dir not found: $laneExperts" }

$target   = Join-Path $laneExperts $TargetName
$artifact = [IO.Path]::ChangeExtension($target, '.ex5')
$log      = Join-Path $laneExperts ([IO.Path]::GetFileNameWithoutExtension($TargetName) + '_compile.log')

# Remove prior artifact+log so a failed compile cannot be read as a pass off stale files
# (the ORDER-372 "existence is not freshness" rule, applied to compilation).
if (Test-Path -LiteralPath $artifact) { Remove-Item -LiteralPath $artifact -Force }
if (Test-Path -LiteralPath $log)      { Remove-Item -LiteralPath $log -Force }

Copy-Item -LiteralPath $src -Destination $target -Force

# Stage every local .mqh the lane owns next to the source, because `#include "..."` resolves
# relative to the compiled file. Staging the .mq5 alone compiles an EA whose stop arithmetic
# came from whatever stale copy happened to be sitting in the Experts folder.
foreach ($inc in Get-ChildItem -LiteralPath (Join-Path $laneRoot 'src') -Filter '*.mqh') {
    Copy-Item -LiteralPath $inc.FullName -Destination (Join-Path $laneExperts $inc.Name) -Force
}

Start-Process -FilePath $MetaEditor -ArgumentList @('/compile:"' + $target + '"', '/log:"' + $log + '"') -Wait

if (-not (Test-Path -LiteralPath $log)) { throw "$TargetName compile log missing" }
$text = Get-Content -LiteralPath $log -Raw -Encoding Unicode

# Keep a copy of the raw log inside the lane as the durable evidence artifact.
$laneLog = Join-Path $laneRoot ('compile\' + [IO.Path]::GetFileNameWithoutExtension($TargetName) + '_compile.log')
Copy-Item -LiteralPath $log -Destination $laneLog -Force

$resultLine = ($text -split "`r?`n" | Where-Object { $_ -match 'Result:' }) -join ' | '
Write-Output "compile log : $laneLog"
Write-Output "result line : $resultLine"

if ($text -notmatch 'Result:\s*0\s+errors,\s*0\s+warnings') { throw "$TargetName did not compile 0 errors / 0 warnings" }
if (-not (Test-Path -LiteralPath $artifact)) { throw "$TargetName produced no .ex5 artifact" }

Write-Output "COMPILE OK  : $TargetName -> 0 errors, 0 warnings"
Write-Output "Expert=     : $([IO.Path]::GetFileNameWithoutExtension($TargetName))"
