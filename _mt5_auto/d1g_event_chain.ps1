# ORDER-091C-D1g event-log dogfood driver: register 5 evidence artifacts, then emit
# IDEA_CREATED -> HYPOTHESIS_REGISTERED -> BAR_PREREGISTERED -> RUN_STARTED (pre-run part).
$ErrorActionPreference = 'Stop'
$root = 'D:\EA_LAB'
$util = "$root\scripts\experiment_event_log.ps1"
$exp  = 'exp_93d9457a-4857-438e-99af-370def7a8392'
$eventsFile = "$root\docs\memory_control\experiment_events\events-2026-07.jsonl"

function Util([string[]]$a) { return (& powershell -NoProfile -File $util @a 2>&1 | Out-String) }
function New-Evid([string]$path, [string]$mtype) {
  $out = Util @('-Command','RegisterEvidence','-ArtifactPath',$path,'-CommitOid','HEAD','-MediaType',$mtype)
  if ($out -notmatch '"status":"(appended|already_appended)"') { throw "evidence register failed for $path :`n$out" }
  if ($out -notmatch '"raw_sha256":"([0-9a-f]{64})"') { throw "no raw_sha256 for $path :`n$out" }
  return $Matches[1]
}
function New-EvtId {
  $out = Util @('-Command','NewEventId')
  if ($out -notmatch '"event_id":"(evt_[0-9a-f-]{36})"') { throw "NewEventId failed:`n$out" }
  return $Matches[1]
}
function TailSha {
  $b = [System.IO.File]::ReadAllBytes($eventsFile)
  $end = $b.Length; if ($end -gt 0 -and $b[$end-1] -eq 0x0A) { $end-- }
  $start = $end - 1; while ($start -ge 0 -and $b[$start] -ne 0x0A) { $start-- }; $start++
  $len = $end - $start; $seg = New-Object byte[] $len; [System.Array]::Copy($b,$start,$seg,0,$len)
  $sha = [System.Security.Cryptography.SHA256]::Create(); (($sha.ComputeHash($seg) | ForEach-Object { $_.ToString('x2') }) -join '')
}
function Emit($obj) {
  $req = "$root\_mt5_auto\d1g_req.json"
  [IO.File]::WriteAllText($req, ($obj | ConvertTo-Json -Depth 12 -Compress), (New-Object Text.UTF8Encoding($false)))
  $out = Util @('-Command','Append','-EventJsonPath',$req)
  if ($out -notmatch '"status":"(appended|already_appended)"') { throw "append failed ($($obj.event_type)):`n$out" }
  Write-Output ("  {0,-22} -> {1}" -f $obj.event_type, $Matches[1])
}

Write-Output "=== using already-registered evidence (registered once at commit 668abfb2; re-register would locator-conflict after HEAD moved = RE#7) ==="
$H = @{
  ea     = '73469e1992a33416893d10db7e780e4be4413d6dfd25f59c1578ffb498ae7fea'
  source = '8dc540fa0fc5b053dbb6639eb0b2c19cbf93e6fb05cba8c0d9374b752eef63fe'
  set    = '84224028a2c9b744a7f3421db97d27b448726b8695b7887cf41baec56de67182'
  data   = 'b8de1a0fc8f54e3968d7743f7cd10756b35ee9eadbdf79e65244506bc097ce2e'
  tester = 'a72e5437a05059018fa7ebf83663177b28528682e2232eaaf97943c169c09596'
}
foreach ($k in 'ea','source','set','data','tester') { Write-Output ("  {0,-7} {1}" -f $k, $H[$k]) }

. $util -RepoRoot $root | Out-Null
$commit = (git -C $root rev-parse HEAD).Trim()
$rec = Get-CommittedBlobRecord -Root $root -Commit $commit -Path 'AGENT_TASKBOARD.md' -Anchor 'ORDER-091C-D1g' -RequireAnchor
$owner = [ordered]@{ owner_type='taskboard_order'; path='AGENT_TASKBOARD.md'; commit_oid=$commit; blob_oid=$rec.BlobOid; raw_sha256=$rec.RawSha256; anchor='ORDER-091C-D1g' }

$nullArt = [ordered]@{ ea=$null; source=$null; set=$null; data=$null; tester=$null }
$srcArt  = [ordered]@{ ea=$null; source=$H.source; set=$null; data=$null; tester=$null }
$allArt  = [ordered]@{ ea=$H.ea; source=$H.source; set=$H.set; data=$H.data; tester=$H.tester }

Write-Output "=== emitting chain ==="
$e1 = New-EvtId
Emit ([ordered]@{ schema_version=1; event_id=$e1; experiment_id=$exp; event_type='IDEA_CREATED'; actor='claude'; role='lead_judge'; prior_event_id=$null; prior_event_sha256=$null; artifact_hashes=$nullArt; trial_family=$null; trial_count=$null; evidence_ids=@(); owner_refs=@($owner); reason_code='experiment_initiated'; reason_ref='ORDER-091C-D1g' })
$s1 = TailSha
$e2 = New-EvtId
Emit ([ordered]@{ schema_version=1; event_id=$e2; experiment_id=$exp; event_type='HYPOTHESIS_REGISTERED'; actor='claude'; role='lead_judge'; prior_event_id=$e1; prior_event_sha256=$s1; artifact_hashes=$srcArt; trial_family=$null; trial_count=$null; evidence_ids=@(); owner_refs=@($owner); reason_code='hypothesis_registered'; reason_ref='ORDER-091C-D1g' })
$s2 = TailSha
$e3 = New-EvtId
Emit ([ordered]@{ schema_version=1; event_id=$e3; experiment_id=$exp; event_type='BAR_PREREGISTERED'; actor='claude'; role='lead_judge'; prior_event_id=$e2; prior_event_sha256=$s2; artifact_hashes=$allArt; trial_family=$null; trial_count=$null; evidence_ids=@(); owner_refs=@($owner); reason_code='bar_preregistered'; reason_ref='ORDER-091C-D1g' })
$s3 = TailSha
$e4 = New-EvtId
Emit ([ordered]@{ schema_version=1; event_id=$e4; experiment_id=$exp; event_type='RUN_STARTED'; actor='claude'; role='lead_judge'; prior_event_id=$e3; prior_event_sha256=$s3; artifact_hashes=$allArt; trial_family='d1g_ab_eurgbp'; trial_count=4; evidence_ids=@(); owner_refs=@($owner); reason_code='run_started'; reason_ref='ORDER-091C-D1g' })

Write-Output "=== scan ==="
(Util @('-Command','Scan')).Trim()
Write-Output ("EVENT_IDS idea=$e1 hyp=$e2 bar=$e3 run=$e4")
Write-Output ("EXP=$exp")
