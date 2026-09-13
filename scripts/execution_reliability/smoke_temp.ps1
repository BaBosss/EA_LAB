# Harmless acceptance probe: exit zero only for the actual trusted attempt root.
$ErrorActionPreference = 'Stop'
$expected = 'D:\EA_LAB_CONTROL\trusted_exec\temp'
if ($env:TEMP -cne $env:TMP -or $env:TEMP -cne $env:TMPDIR) { exit 31 }
if ([IO.Path]::GetDirectoryName($env:TEMP) -cne $expected) { exit 32 }
if (-not [IO.Path]::GetFileName($env:TEMP).StartsWith('attempt-')) { exit 33 }
if ([IO.Path]::GetTempPath().TrimEnd('\') -cne $env:TEMP) { exit 34 }
[IO.File]::WriteAllText((Join-Path $env:TEMP 'smoke.txt'), 'trusted temp probe')
Write-Output 'TEMP_TMP_TMPDIR_INHERITANCE_PASS'
exit 0
