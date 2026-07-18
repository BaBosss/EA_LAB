# ORDER-091C-D1g event-log tail: RESULT_LINKED -> REVIEW_LINKED -> DECISION_LINKED.
$ErrorActionPreference = 'Stop'
$root = 'D:\EA_LAB'; $util = "$root\scripts\experiment_event_log.ps1"
$exp  = 'exp_93d9457a-4857-438e-99af-370def7a8392'
$eventsFile = "$root\docs\memory_control\experiment_events\events-2026-07.jsonl"
$H = @{ ea='73469e1992a33416893d10db7e780e4be4413d6dfd25f59c1578ffb498ae7fea'
  source='8dc540fa0fc5b053dbb6639eb0b2c19cbf93e6fb05cba8c0d9374b752eef63fe'
  set='84224028a2c9b744a7f3421db97d27b448726b8695b7887cf41baec56de67182'
  data='b8de1a0fc8f54e3968d7743f7cd10756b35ee9eadbdf79e65244506bc097ce2e'
  tester='a72e5437a05059018fa7ebf83663177b28528682e2232eaaf97943c169c09596' }
$allArt = [ordered]@{ ea=$H.ea; source=$H.source; set=$H.set; data=$H.data; tester=$H.tester }

function Util([string[]]$a) { return (& powershell -NoProfile -File $util @a 2>&1 | Out-String) }
function Sha([byte[]]$b){ $s=[Security.Cryptography.SHA256]::Create(); (($s.ComputeHash($b)|%{$_.ToString('x2')}) -join '') }
function TailSha { $b=[IO.File]::ReadAllBytes($eventsFile); $e=$b.Length; if($e -gt 0 -and $b[$e-1] -eq 0x0A){$e--}; $s=$e-1; while($s -ge 0 -and $b[$s] -ne 0x0A){$s--}; $s++; $l=$e-$s; $seg=New-Object byte[] $l; [Array]::Copy($b,$s,$seg,0,$l); Sha $seg }
function New-EvtId { $o=Util @('-Command','NewEventId'); if($o -notmatch '"event_id":"(evt_[0-9a-f-]{36})"'){throw "NewEventId:`n$o"}; $Matches[1] }
function Reg([string]$p,[string]$mt,[string]$commit){ $o=Util @('-Command','RegisterEvidence','-ArtifactPath',$p,'-CommitOid',$commit,'-MediaType',$mt); if($o -notmatch '"status":"(appended|already_appended)"'){throw "reg ${p}:`n$o"}; if($o -notmatch '"raw_sha256":"([0-9a-f]{64})"'){throw "no sha ${p}"}; 'evd_sha256_'+$Matches[1] }
function Emit($obj){ $req="$root\_mt5_auto\d1g_tail_req.json"; [IO.File]::WriteAllText($req,($obj|ConvertTo-Json -Depth 12 -Compress),(New-Object Text.UTF8Encoding($false))); $o=Util @('-Command','Append','-EventJsonPath',$req); if($o -notmatch '"status":"(appended|already_appended)"'){throw "append $($obj.event_type):`n$o"}; Write-Output ("  {0,-16} -> {1}" -f $obj.event_type,$Matches[1]) }

$evCommit = (git -C $root rev-parse '0dee7ef2').Trim()   # full 40-hex of the evidence commit
$evidResults = Reg '_mt5_auto/D1G_AB_RESULTS.csv'      'text/csv'      $evCommit
$evidVerdict = Reg '_triage/ORDER091C_D1G_VERDICT.md'  'text/markdown' $evCommit
Write-Output "evid results=$evidResults verdict=$evidVerdict"

. $util -RepoRoot $root | Out-Null
$commit = (git -C $root rev-parse HEAD).Trim()
$tb  = Get-CommittedBlobRecord -Root $root -Commit $commit -Path 'AGENT_TASKBOARD.md' -Anchor 'ORDER-091C-D1g' -RequireAnchor
$ps  = Get-CommittedBlobRecord -Root $root -Commit $commit -Path 'PROJECT_STATE.md'   -Anchor 'ORDER-091C-D1g' -RequireAnchor
$ownerTb = [ordered]@{ owner_type='taskboard_order';  path='AGENT_TASKBOARD.md'; commit_oid=$commit; blob_oid=$tb.BlobOid; raw_sha256=$tb.RawSha256; anchor='ORDER-091C-D1g' }
$ownerPs = [ordered]@{ owner_type='project_decision'; path='PROJECT_STATE.md';   commit_oid=$commit; blob_oid=$ps.BlobOid; raw_sha256=$ps.RawSha256; anchor='ORDER-091C-D1g' }

$prior = 'evt_02049ea3-d5c5-4e7d-b960-95d836d20fe7'   # AMENDMENT_ADDED (current tail)
$priorSha = TailSha
$e1 = New-EvtId
Emit ([ordered]@{ schema_version=1; event_id=$e1; experiment_id=$exp; event_type='RESULT_LINKED'; actor='claude'; role='lead_judge'; prior_event_id=$prior; prior_event_sha256=$priorSha; artifact_hashes=$allArt; trial_family='d1g_ab'; trial_count=14; evidence_ids=@($evidResults); owner_refs=@($ownerTb); reason_code='result_available'; reason_ref='ORDER-091C-D1g' })
$s1 = TailSha
$e2 = New-EvtId
Emit ([ordered]@{ schema_version=1; event_id=$e2; experiment_id=$exp; event_type='REVIEW_LINKED'; actor='claude'; role='lead_judge'; prior_event_id=$e1; prior_event_sha256=$s1; artifact_hashes=$allArt; trial_family='d1g_ab'; trial_count=14; evidence_ids=@($evidVerdict); owner_refs=@($ownerTb); reason_code='review_recorded'; reason_ref='ORDER-091C-D1g' })
$s2 = TailSha
$e3 = New-EvtId
Emit ([ordered]@{ schema_version=1; event_id=$e3; experiment_id=$exp; event_type='DECISION_LINKED'; actor='claude'; role='lead_judge'; prior_event_id=$e2; prior_event_sha256=$s2; artifact_hashes=$allArt; trial_family='d1g_ab'; trial_count=14; evidence_ids=@($evidVerdict); owner_refs=@($ownerPs); reason_code='decision_recorded'; reason_ref='ORDER-091C-D1g' })

Write-Output "=== scan ==="; (Util @('-Command','Scan')).Trim()
Write-Output "TAIL result=$e1 review=$e2 decision=$e3"
