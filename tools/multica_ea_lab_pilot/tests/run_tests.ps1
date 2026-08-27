param([switch]$Integration)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'MulticaPilot.psm1') -Force
$passed=0; $failed=0
function T([string]$name,[scriptblock]$body){ try { & $body; Write-Host "PASS $name"; $script:passed++ } catch { Write-Host "FAIL $name :: $($_.Exception.Message)"; $script:failed++ } }
$base='165c999d4b91421bbd78d844d5388c3cc6c5bef6'
$wt='D:\EA_LAB_worktrees\multica-ea-lab-pilot-20260826'
T 'reject dirty primary root' { try { Assert-MulticaPilotSafePath 'D:\EA_LAB'; throw 'expected rejection' } catch { if($_.Exception.Message -eq 'expected rejection'){ throw } } }
T 'reject dirty primary descendant' { try { Assert-MulticaPilotSafePath 'D:\EA_LAB\subdir'; throw 'expected rejection' } catch { if($_.Exception.Message -eq 'expected rejection'){ throw } } }
T 'reject EA_LAB local-directory resource' { try { Assert-MulticaPilotResource -ResourceType local_directory -Location $wt -Ref $base; throw 'expected rejection' } catch { if($_.Exception.Message -eq 'expected rejection'){ throw } } }
T 'accept disposable local cage' { Assert-MulticaPilotResource -ResourceType local_directory -Location 'D:\EA_LAB_CONTROL\multica-pilot\cages\unit' | Out-Null }
T 'accept EA_LAB github exact ref' { Assert-MulticaPilotResource -ResourceType github_repo -Location 'https://github.com/BaBosss/EA_LAB' -Ref $base | Out-Null }
T 'reject symbolic EA_LAB ref' { try { Assert-MulticaPilotResource -ResourceType github_repo -Location 'https://github.com/BaBosss/EA_LAB' -Ref 'master'; throw 'expected rejection' } catch { if($_.Exception.Message -eq 'expected rejection'){ throw } } }
T 'policy is non-authoritative and inert' { $p=Get-MulticaPilotPolicy; if($p.authority -ne 'NON_AUTHORITATIVE_SIDECAR'){throw 'bad authority'}; foreach($n in @('setup_authorized','auth_authorized','daemon_start_authorized','runtime_activation_authorized','deployment_authorized','trading_authorized','live_promotion_authorized','risk_default_change_authorized','owner_attestation_authorized','force_push_authorized','history_rewrite_authorized')){if($p.$n -ne $false){throw "$n must be false"}} }
T 'installed binary is pinned' { $i=Get-MulticaInstallation; if(-not $i.found){throw 'multica missing'}; if($i.version -ne '0.4.34'){throw "version=$($i.version)"}; if($i.sha256 -ne 'E43833C124F9986C0BEB3B323DE856A98F7BCAA0238ADAA093675D5E92D60980'){throw "sha=$($i.sha256)"} }
T 'required coding CLIs detected' { $p=Get-MulticaPilotPreflight; foreach($n in @('git','claude','codex','qwen','agy')){if(-not $p.tools.$n.found){throw "$n missing"}} }
T 'repo identity is exact branch' { $r=Get-MulticaPilotRepoIdentity -Path $wt; if($r.head -ne $base){throw 'wrong head'}; if($r.branch -ne 'module/multica-ea-lab-pilot-20260826'){throw 'wrong branch'} }
T 'wrapper status is read-only' { $w=(& (Join-Path $root 'Invoke-MulticaPilot.ps1') -Action Status | Out-String | ConvertFrom-Json); if($w.policy.authority -ne 'NON_AUTHORITATIVE_SIDECAR'){throw 'wrapper policy drift'}; if($w.daemon.state -ne 'STOPPED'){throw "wrapper daemon=$($w.daemon.state)"} }
T 'wrapper validates exact-ref resource' { $w=(& (Join-Path $root 'Invoke-MulticaPilot.ps1') -Action ValidateResource -ResourceType github_repo -Location 'https://github.com/BaBosss/EA_LAB' -Ref $base | Out-String | ConvertFrom-Json); if($w.mode -ne 'EXACT_REF_ONLY'){throw 'wrapper resource drift'} }
if($Integration){ T 'daemon remains stopped' { $s=Get-MulticaDaemonState; if($s.state -ne 'STOPPED'){throw "daemon=$($s.state)"} } }
Write-Host "RESULT passed=$passed failed=$failed"
if($failed -gt 0){ exit 1 }
