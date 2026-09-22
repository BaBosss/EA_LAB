$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hook=Join-Path $root '.githooks\pre-commit'
$win=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if(-not(Test-Path $win)){throw 'Windows PowerShell missing'}
if((Get-Content $hook -Raw) -notmatch 'powershell\.exe\) unset PSModulePath'){throw 'hook normalization missing'}
$orig=$env:PSModulePath; $origTarget=$env:EA_LAB_HOOK_TEST_TARGET
$target=$PSCommandPath; $env:EA_LAB_HOOK_TEST_TARGET=$target
$dotnet=[BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($target))).Replace('-','').ToLowerInvariant()
function Enc([string]$s){[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($s))}
$probe='$c=Get-Command Get-FileHash -ErrorAction SilentlyContinue; if($null -eq $c){"MISSING"}else{$h=(Get-FileHash -LiteralPath $env:EA_LAB_HOOK_TEST_TARGET -Algorithm SHA256).Hash.ToLower();"GOOD|"+$c.CommandType+"|"+$c.Source+"|"+$h}'
try {
  $env:PSModulePath='C:\Users\patip\OneDrive\Documents\PowerShell\Modules;C:\Program Files\PowerShell\Modules;c:\users\patip\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\Modules;C:\Users\patip\OneDrive\Documents\WindowsPowerShell\Modules;C:\Program Files\WindowsPowerShell\Modules;C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules'
  $bad=& $win -NoProfile -EncodedCommand (Enc $probe) 2>$null
  if(($bad -join '') -notmatch '^MISSING$'){throw ('poisoned path did not reproduce: '+($bad -join ';'))}
  Remove-Item Env:PSModulePath -ErrorAction SilentlyContinue
  $good=& $win -NoProfile -EncodedCommand (Enc $probe)
  if(($good -join '') -notmatch ('^GOOD\|Function\|Microsoft\.PowerShell\.Utility\|'+$dotnet+'$')){throw ('native recovery failed: '+($good -join ';'))}
  $childEnc=Enc $probe; $parent='& powershell.exe -NoProfile -EncodedCommand "'+$childEnc+'"'
  $child=& $win -NoProfile -EncodedCommand (Enc $parent)
  if(($child -join '') -notmatch ('^GOOD\|Function\|Microsoft\.PowerShell\.Utility\|'+$dotnet+'$')){throw ('child recovery failed: '+($child -join ';'))}
  Write-Host '[PASS] poisoned Core PSModulePath reproduced; native parent+child recovered genuine Get-FileHash'
} finally {
  if($null -eq $orig){Remove-Item Env:PSModulePath -ErrorAction SilentlyContinue}else{$env:PSModulePath=$orig}
  if($null -eq $origTarget){Remove-Item Env:EA_LAB_HOOK_TEST_TARGET -ErrorAction SilentlyContinue}else{$env:EA_LAB_HOOK_TEST_TARGET=$origTarget}
}
if($env:PSModulePath -ne $orig){throw 'process environment not restored'}
Write-Host '[PASS] no persistent PSModulePath change'