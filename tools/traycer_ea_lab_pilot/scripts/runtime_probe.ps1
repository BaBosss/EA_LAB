$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'TraycerPilot.psm1') -Force
$p=Get-TraycerPilotPreflight
$i=$p.traycer
$result=[ordered]@{
  timestamp=(Get-Date).ToString('o')
  tools=[ordered]@{}
  traycer=[ordered]@{found=$i.found;version=$i.version;signature_status=$i.signature_status;signer_subject=$i.signer_subject}
  host=[ordered]@{running=$false;version=$null;service_registered=$false}
  doctor=[ordered]@{status=$null;issue_codes=@()}
  harness_probe=[ordered]@{status=$null;code=$null}
}
foreach($name in @('git','claude','codex','qwen','gemini')){ $result.tools[$name]=[bool]$p.tools.$name.found }
if($i.found -and (Test-Path $i.cli_path)){
  $hostStatus=(& $i.cli_path --json --no-bootstrap host status | Select-Object -Last 1 | ConvertFrom-Json)
  $result.host.running=[bool]$hostStatus.data.running
  if($hostStatus.data.pidMetadata){ $result.host.version=[string]$hostStatus.data.pidMetadata.version }
  if($hostStatus.data.bootstrap){ $result.host.service_registered=[bool]$hostStatus.data.bootstrap.serviceRegistered }
  $savedEap=$ErrorActionPreference; $ErrorActionPreference='SilentlyContinue'
  $doctorRaw=@(& $i.cli_path --json --no-bootstrap host doctor 2>&1)
  $ErrorActionPreference=$savedEap
  $doctorLine=@($doctorRaw | ForEach-Object { $_.ToString() } | Where-Object { $_.TrimStart().StartsWith('{') }) | Select-Object -Last 1
  if($doctorLine){ $d=$doctorLine|ConvertFrom-Json; $result.doctor.status=[string]$d.status; $result.doctor.issue_codes=@($d.data.issues|ForEach-Object{[string]$_.code}) }
  $harnessRaw=@(& $i.cli_path --json --no-bootstrap agent list-harnesses 2>&1)
  $harnessLine=@($harnessRaw | ForEach-Object { $_.ToString() } | Where-Object { $_.TrimStart().StartsWith('{') }) | Select-Object -Last 1
  if($harnessLine){ $h=$harnessLine|ConvertFrom-Json; $result.harness_probe.status=[string]$h.status; if($h.error){$result.harness_probe.code=[string]$h.error.code} }
}
[pscustomobject]$result | ConvertTo-Json -Depth 8
