# Emit AMENDMENT_ADDED: Model-4 -> Model-1 (tooling constraint), targeting the BAR_PREREGISTERED event.
$ErrorActionPreference = 'Stop'
$root = 'D:\EA_LAB'; $util = "$root\scripts\experiment_event_log.ps1"
$exp  = 'exp_93d9457a-4857-438e-99af-370def7a8392'
$eventsFile = "$root\docs\memory_control\experiment_events\events-2026-07.jsonl"
$barId = 'evt_179c7f16-6389-4f3f-b7f1-716490d21891'   # BAR_PREREGISTERED
$runId = 'evt_8924bbe6-d384-40f5-b4ed-55e992bfaf79'   # RUN_STARTED (current tail)

function Util([string[]]$a) { return (& powershell -NoProfile -File $util @a 2>&1 | Out-String) }
function Sha([byte[]]$b) { $s=[System.Security.Cryptography.SHA256]::Create(); (($s.ComputeHash($b)|%{$_.ToString('x2')}) -join '') }
# per-line sha256 of a specific event_id (canonical line bytes, no trailing LF)
function LineShaOf([string]$id) {
  $b=[System.IO.File]::ReadAllBytes($eventsFile); $start=0
  for ($i=0;$i -lt $b.Length;$i++){ if($b[$i] -eq 0x0A){ $len=$i-$start; $seg=New-Object byte[] $len; [Array]::Copy($b,$start,$seg,0,$len)
      $txt=[Text.Encoding]::UTF8.GetString($seg); if($txt -match [regex]::Escape($id)){ return (Sha $seg) }; $start=$i+1 } }
  throw "line for $id not found"
}
$priorSha = LineShaOf $runId
$barSha   = LineShaOf $barId

. $util -RepoRoot $root | Out-Null
$commit = (git -C $root rev-parse HEAD).Trim()
$rec = Get-CommittedBlobRecord -Root $root -Commit $commit -Path 'AGENT_TASKBOARD.md' -Anchor 'ORDER-091C-D1g' -RequireAnchor
$owner = [ordered]@{ owner_type='taskboard_order'; path='AGENT_TASKBOARD.md'; commit_oid=$commit; blob_oid=$rec.BlobOid; raw_sha256=$rec.RawSha256; anchor='ORDER-091C-D1g' }

$evid = (( Util @('-Command','NewEventId') ) -match '"event_id":"(evt_[0-9a-f-]{36})"'); $eid=$Matches[1]
$req = [ordered]@{ schema_version=1; event_id=$eid; experiment_id=$exp; event_type='AMENDMENT_ADDED'; actor='claude'; role='lead_judge';
  prior_event_id=$runId; prior_event_sha256=$priorSha; artifact_hashes=[ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null};
  trial_family=$null; trial_count=$null; evidence_ids=@(); owner_refs=@($owner); reason_code='logical_correction'; reason_ref='ORDER-091C-D1g';
  target_event_id=$barId; target_event_sha256=$barSha }
$reqPath="$root\_mt5_auto\d1g_amend_req.json"
[IO.File]::WriteAllText($reqPath, ($req|ConvertTo-Json -Depth 12 -Compress), (New-Object Text.UTF8Encoding($false)))
$out = Util @('-Command','Append','-EventJsonPath',$reqPath)
if ($out -notmatch '"status":"(appended|already_appended)"') { throw "amend append failed:`n$out" }
Write-Output "AMENDMENT_ADDED -> $($Matches[1]) (id=$eid target=$barId)"
(Util @('-Command','Scan')).Trim()
