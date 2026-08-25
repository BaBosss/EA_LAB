param([switch]$Integration)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$module=Join-Path $root 'TraycerPilot.psm1'
Import-Module $module -Force
$passed=0; $failed=0
function T([string]$name,[scriptblock]$body){ try { & $body; Write-Host "PASS $name"; $script:passed++ } catch { Write-Host "FAIL $name :: $($_.Exception.Message)"; $script:failed++ } }
T 'reject dirty primary root' { try { Assert-TraycerPilotSafePath 'D:\EA_LAB'; throw 'expected rejection' } catch { if($_.Exception.Message -eq 'expected rejection'){ throw } } }
T 'reject dirty primary descendant' { try { Assert-TraycerPilotSafePath 'D:\EA_LAB\subdir'; throw 'expected rejection' } catch { if($_.Exception.Message -eq 'expected rejection'){ throw } } }
T 'accept isolated control cage' { Assert-TraycerPilotSafePath 'D:\EA_LAB_CONTROL\traycer-pilot\cages\unit' | Out-Null }
T 'discover required coding CLIs' { $p=Get-TraycerPilotPreflight; foreach($n in @('git','claude','codex','qwen')){ if(-not $p.tools.$n.found){ throw "$n missing" } } }
T 'detect installed Traycer signature and version' { $i=Get-TraycerInstallation; if(-not $i.found){ throw 'Traycer missing' }; if($i.signature_status -ne 'Valid'){ throw "signature=$($i.signature_status)" }; if($i.signer_subject -notmatch 'TRAYCER AI INC'){ throw 'unexpected signer' }; if($i.version -notmatch '^1\.2\.0'){ throw "version=$($i.version)" } }
T 'create bounded disposable cage' { $base='D:\EA_LAB_CONTROL\traycer-pilot\test-fixtures'; $target=Join-Path $base 'unit-cage'; if(Test-Path $target){ Remove-Item $target -Recurse -Force }; $c=New-TraycerPilotCage -Root $base -Name 'unit-cage'; if(-not (Test-Path (Join-Path $c.path '.git'))){ throw 'git repo missing' }; if(-not $c.clean){ throw 'new cage not clean' } }
T 'refuse cage under protected checkout' { try { New-TraycerPilotCage -Root 'D:\EA_LAB' -Name 'bad'; throw 'expected rejection' } catch { if($_.Exception.Message -eq 'expected rejection'){ throw } } }
if($Integration){ T 'bundled Traycer CLI answers version' { $i=Get-TraycerInstallation; $v=& $i.cli_path --version; if($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($v|Out-String))){ throw 'traycer cli version failed' } } }
Write-Host "RESULT passed=$passed failed=$failed"
if($failed -gt 0){ exit 1 }
