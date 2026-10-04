'use strict';
const path = require('node:path');
const childProcess = require('node:child_process');
const HOST='bbb88aa0-1598-43f6-b56c-a7db22af086a';
const JOB_ID=/^[A-Za-z][A-Za-z0-9._-]{2,79}$/;
const LANE_ID=/^[A-Za-z][A-Za-z0-9._-]{0,127}$/;
const SHA=/^[0-9a-f]{40}$/;
const TERMINAL=new Set(['COMPLETE','FAILED','POSTCONDITION_FAILED','TIMED_OUT','CANCELLED','LOST_PROCESS']);
const MAX_JOBS=1000; // Existing Current Read V2 inventory cap.
const LIST_LIMIT=10; // Sequential one-shot query budget, not a freshness TTL.
const text=x=>typeof x==='string' && x.trim() ? x : null;
const pidOK=x=>Number.isInteger(x) && x>0 && x<=2147483647;
const samePath=(a,b)=>text(a)!==null && text(b)!==null && path.win32.isAbsolute(a) &&
  path.win32.isAbsolute(b) && path.win32.normalize(a).toLowerCase()===path.win32.normalize(b).toLowerCase();
function precise(value){
  if(typeof value!=='string') return null;
  const m=/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})(?:\.(\d{1,7}))?(Z|[+-]\d{2}:\d{2})$/.exec(value);
  if(!m) return null;
  const local=Date.parse(m[1]+'T'+m[2]+'Z'), base=Date.parse(m[1]+'T'+m[2]+m[4]);
  if(!Number.isFinite(base)||!Number.isFinite(local)||new Date(local).toISOString().slice(0,19)!==m[1]+'T'+m[2])return null;
  return BigInt(base)*10000n+BigInt((m[3]||'').padEnd(7,'0')||'0');
}
const validPath=v=>typeof v==='string'&&v.trim()===v&&v.length>0&&
  !/[\x00-\x1f*?"<>|]/.test(v)&&(/^[A-Za-z]:[\\/]/.test(v)||/^\\\\[^\\/]+\\[^\\/]+(?:\\|$)/.test(v));
function project(binding,raw,requestUtc,nowUtc){
  const row={job_id:binding?.job_id??null,lane_id:binding?.lane_id??null,execution_type:null,state:'UNKNOWN',
    reason:'OBSERVATION_UNAVAILABLE',pid:null,process_creation_utc:null,executable_path:null,
    worktree:binding?.worktree??null,source_head:binding?.base_sha??null,config_identity:null,
    started_utc:null,last_heartbeat_utc:null,heartbeat_age_seconds:null,observation_utc:null,
    host_id:HOST,terminal_install_identity:null,checkpoint_pointer:null,result_pointer:null,
    progress:'UNKNOWN',evidence_kind:'REQUEST_PROCESS_OBSERVATION'};
  const unknown=reason=>({...row,state:'UNKNOWN',reason});
  const mismatch=reason=>({...row,state:'IDENTITY_MISMATCH',reason});
  const object=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);
  const id=(v,re)=>typeof v==='string'&&re.test(v);
  const stamp=(v,upper)=>precise(v)!==null&&precise(v)<=upper;
  if(!object(raw)||raw.error)return unknown(text(raw?.error)||'OBSERVATION_UNAVAILABLE');
  const request=precise(requestUtc),now=precise(nowUtc),observed=precise(raw.observation_utc);
  if(request===null||now===null||observed===null||request>now||observed<request||observed>now)return unknown('STALE_OR_INVALID_OBSERVATION');
  row.observation_utc=raw.observation_utc;
  if(raw.host_id!==HOST||raw.stable!==true)return unknown('HOST_OR_SOURCE_STABILITY_UNPROVEN');
  const {job,state,heartbeat,result,lane}=raw;
  if(!object(binding)||!object(job)||!object(state)||!object(lane))return unknown('BINDING_UNPROVEN');
  // Validate all expected/current durable identity fields before any comparison.
  if(!id(binding.job_id,JOB_ID)||!id(binding.lane_id,LANE_ID)||!id(binding.base_sha,SHA)||!validPath(binding.worktree)||
     !id(job.job_id,JOB_ID)||!id(state.job_id,JOB_ID)||!id(lane.lane_id,LANE_ID)||
     !id(job.base_sha,SHA)||!id(lane.head_sha,SHA)||!validPath(job.worktree)||!validPath(lane.worktree)||
     !validPath(job.file_path)||typeof job.postcondition_file_path!=='string'||
     (job.postcondition_file_path!==''&&!validPath(job.postcondition_file_path)))return unknown('BINDING_UNPROVEN');
  const configured=job.postcondition_file_path!=='';
  const terminal=TERMINAL.has(state.state),waiting=['QUEUED','WAITING_RESOURCE','BLOCKED'].includes(state.state);
  if(!terminal&&!waiting&&!['RUNNING','POSTCONDITION_RUNNING'].includes(state.state))return unknown('UNSUPPORTED_DURABLE_STATE');
  if(!stamp(job.created_utc,observed)||(!waiting&&!stamp(state.started_utc,observed))||
     (state.started_utc!=null&&!stamp(state.started_utc,observed)))return unknown('INVALID_OR_FUTURE_START_TIME');
  if(heartbeat!=null){
    if(!object(heartbeat)||!id(heartbeat.job_id,JOB_ID)||!stamp(heartbeat.updated_utc,observed))return unknown('INVALID_OR_FUTURE_HEARTBEAT');
    row.last_heartbeat_utc=heartbeat.updated_utc;
    row.heartbeat_age_seconds=Number(observed-precise(heartbeat.updated_utc))/10000000;
    if(!Number.isFinite(row.heartbeat_age_seconds))return unknown('INVALID_HEARTBEAT_AGE');
  }
  if(result!=null&&(!object(result)||!id(result.job_id,JOB_ID)))return unknown('BINDING_UNPROVEN');
  if(!terminal&&result!=null)return unknown('ACTIVE_STATE_WITH_TERMINAL_RESULT');
  row.execution_type=text(job.stage);
  row.config_identity=typeof job.arg_hash==='string'&&(/^[0-9a-f]{64}$/.test(job.arg_hash)||/^[A-Za-z0-9+/]{43}=$/.test(job.arg_hash))?
    {kind:'runner_argument_hash',value:job.arg_hash}:null;
  row.started_utc=text(state.started_utc);
  row.checkpoint_pointer={job_id:binding.job_id,record:'state.json'};
  row.result_pointer=result?{job_id:binding.job_id,record:'result.json'}:null;
  const differences=[];
  const differ=(condition,reason)=>{if(condition)differences.push(reason);};
  differ(job.job_id!==binding.job_id||state.job_id!==binding.job_id||lane.lane_id!==binding.lane_id||
    (heartbeat!=null&&heartbeat.job_id!==binding.job_id)||(result!=null&&result.job_id!==binding.job_id),'JOB_OR_LANE_MISMATCH');
  differ(job.base_sha!==binding.base_sha||lane.head_sha!==binding.base_sha||
    !samePath(job.worktree,binding.worktree)||!samePath(lane.worktree,binding.worktree),'SOURCE_OR_WORKTREE_MISMATCH');
  if(waiting){
    if(state.child_pid!=null||state.postcondition_pid!=null)return unknown('UNRESOLVED_PROCESS_FOR_WAIT_STATE');
    return differences.length?mismatch(differences[0]):{...row,state:state.state,reason:'DURABLE_NONRUNNING_STATE_ONLY'};
  }
  if(!configured&&(state.postcondition_pid!=null||state.postcondition_start_utc!=null||state.state==='POSTCONDITION_RUNNING'))
    return unknown('POSTCONDITION_IDENTITY_UNPROVEN');
  const validateCheck=role=>{
    const c=raw.checks?.[role],pid=state[role+'_pid'],creation=precise(state[role+'_start_utc']);
    if(!object(c)||!id(c.job_id,JOB_ID)||!id(c.lane_id,LANE_ID)||!['runner','child','postcondition'].includes(c.role))
      return {unknown:'BINDING_UNPROVEN'};
    const checked=precise(c.checked_utc),expected=precise(c.expected_creation_utc),current=precise(c.current_creation_utc);
    if(checked===null||checked<request||checked>observed)return {unknown:'INVALID_CHECK_TIME'};
    if(!pidOK(pid)||creation===null||creation>checked||!pidOK(c.pid)||expected===null||expected>checked)
      return {unknown:'MISSING_PROCESS_IDENTITY'};
    const absent=c.identity==='RECORDED_PROCESS_NOT_PRESENT'&&c.query_status==='NOT_PRESENT'&&c.current_creation_utc===null;
    const present=c.query_status==='PRESENT'&&['MATCHING_RECORDED_PROCESS','DIFFERENT_CREATION_IDENTITY'].includes(c.identity);
    if(!absent&&(!present||current===null||current>checked))return {unknown:'MISSING_PROCESS_IDENTITY'};
    if(present&&c.identity==='DIFFERENT_CREATION_IDENTITY'&&current===expected)return {unknown:'UNKNOWN_PROCESS'};
    // No comparison result escapes until every applicable stage/image is qualified.
    differ(c.job_id!==binding.job_id||c.lane_id!==binding.lane_id||c.role!==role||c.pid!==pid||expected!==creation,'CHECK_BINDING_MISMATCH');
    if(present)differ(current!==creation,'IDENTITY_MISMATCH');
    return {status:absent?'ABSENT':'PRESENT',checked};
  };
  const role=state.state==='POSTCONDITION_RUNNING'?'postcondition':'child';
  row.pid=pidOK(state[role+'_pid'])?state[role+'_pid']:null;
  row.process_creation_utc=stamp(state[role+'_start_utc'],observed)?state[role+'_start_utc']:null;
  const roles=terminal?['child',...(configured?['postcondition']:[])]:
    ['runner','child',...(role==='postcondition'?['postcondition']:[])];
  const checks=Object.fromEntries(roles.map(r=>[r,validateCheck(r)]));
  if(checks.postcondition?.unknown)return unknown('POSTCONDITION_IDENTITY_UNPROVEN');
  const unproven=roles.find(r=>checks[r].unknown);
  if(unproven)return unknown(checks[unproven].unknown);
  if(terminal){
    if(!object(result)||result.state!==state.state||!Number.isInteger(result.exit_code)||
       !stamp(result.ended_utc,observed)||precise(result.ended_utc)<precise(state.started_utc))
      return unknown('TERMINAL_RESULT_UNPROVEN');
    if(configured&&!Number.isInteger(result.postcondition_exit_code))return unknown('TERMINAL_POSTCONDITION_UNPROVEN');
    if(('exit_code' in state&&state.exit_code!==result.exit_code)||
       ('postcondition_exit_code' in state&&state.postcondition_exit_code!==result.postcondition_exit_code)||
       (state.state==='COMPLETE'&&(result.exit_code!==0||(configured&&result.postcondition_exit_code!==0))))
      return unknown('TERMINAL_RESULT_CONFLICT');
    if(differences.length)return mismatch(differences[0]);
    if(roles.some(r=>checks[r].status!=='ABSENT'))return unknown('TERMINAL_PROCESS_NOT_PROVEN_ABSENT');
    return {...row,state:'PROVEN_TERMINAL',reason:'BOUND_RESULT_AND_CURRENT_PROCESS_ABSENCE'};
  }
  if(checks[role].status!=='PRESENT'||checks.runner.status!=='PRESENT')return unknown('RUNNING_PROCESS_UNPROVEN');
  if(role==='postcondition'&&checks.child.status!=='ABSENT')return unknown('CHILD_TERMINAL_IDENTITY_UNPROVEN');
  if(role==='child'&&(state.postcondition_pid!=null||state.postcondition_start_utc!=null))return unknown('POSTCONDITION_IDENTITY_UNPROVEN');
  const image=raw.images?.[role],expectedImage=role==='child'?job.file_path:job.postcondition_file_path;
  if(!object(image)||!validPath(image.executable_path)||!validPath(expectedImage)||!pidOK(image.pid))return unknown('BINDING_UNPROVEN');
  const imageChecked=precise(image.checked_utc),imageCreation=precise(image.creation_utc);
  if(imageChecked===null||imageChecked<request||imageChecked>observed||imageChecked>checks[role].checked||
     imageCreation===null||imageCreation>imageChecked)return unknown('INVALID_IMAGE_TIME');
  differ(image.pid!==state[role+'_pid']||imageCreation!==precise(state[role+'_start_utc'])||
    !samePath(image.executable_path,expectedImage),'EXECUTABLE_OR_CREATION_MISMATCH');
  if(differences.length)return mismatch(differences[0]);
  row.executable_path=image.executable_path;
  return {...row,state:'PROVEN_RUNNING',reason:'CURRENT_PID_CREATION_IMAGE_AND_JOB_LANE_BOUND'};
}
// This fixed read-only command reuses the accepted Get-IdentityEvidence observer.
// It starts no observed job, has no watcher/timer and accepts only server bindings.
const OBSERVE_PS="\n$ErrorActionPreference='Stop'\nif([Environment]::MachineName -ine 'BABOSS' -or [Security.Principal.WindowsIdentity]::GetCurrent().Name -ine 'BABOSS\\patip'){throw 'HOST_OWNER_BINDING'}\n$lib='D:\\EA_LAB_CONTROL\\lnwjud-write-v1-20260928\\canonical\\scripts\\long_jobs\\_long_job_runner_lib.ps1'\nif((Get-FileHash -LiteralPath $lib -Algorithm SHA256).Hash.ToLowerInvariant() -cne '13fc33f017fabaceb7aea302497adddecaf1b39d7871864ddbe49cc7dcaaceef'){throw 'OBSERVER_SOURCE_HASH'}\n. $lib\n$txt=[Console]::In.ReadToEnd()\nAssert-StrictJsonSyntaxAndUniqueKeys $txt 'server binding'\n$b=$txt | ConvertFrom-Json\nif($b.job_id -cnotmatch '^[A-Za-z][A-Za-z0-9._-]{2,79}$' -or $b.lane_id -cnotmatch '^[A-Za-z][A-Za-z0-9._-]{0,127}$'){throw 'BINDING_ID'}\n$files=@{}\nfunction Read-Bound($p,$optional){\n  $current=[IO.Path]::GetPathRoot($p)\n  foreach($part in $p.Substring($current.Length).Split('\\')){\n    if(!$part){continue}; $current=Join-Path $current $part\n    if((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'REPARSE_SOURCE'}\n  }\n  if(!(Test-Path -LiteralPath $p -PathType Leaf)){\n    if(!$optional){throw 'MISSING_SOURCE'}; $files[$p]=$null; return $null\n  }\n  if((Get-Item -LiteralPath $p).Length -gt 1048576){throw 'SOURCE_SIZE'}\n  $bytes=[IO.File]::ReadAllBytes($p)\n  if($bytes.Length -gt 1048576){throw 'SOURCE_SIZE'}\n  $text=(New-Object Text.UTF8Encoding($false,$true)).GetString($bytes).TrimStart([char]0xFEFF)\n  Assert-StrictJsonSyntaxAndUniqueKeys $text 'durable source'\n  $sha=[Security.Cryptography.SHA256]::Create()\n  try {$files[$p]=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')} finally {$sha.Dispose()}\n  return ($text | ConvertFrom-Json)\n}\n$root=Join-Path 'D:\\EA_LAB_CONTROL\\jobs' $b.job_id\n$job=Read-Bound (Join-Path $root 'job.json') $false\n$state=Read-Bound (Join-Path $root 'state.json') $false\n$heartbeat=Read-Bound (Join-Path $root 'heartbeat.json') $true\n$result=Read-Bound (Join-Path $root 'result.json') $true\n$lane=Read-Bound (Join-Path 'D:\\EA_LAB_CONTROL\\lanes\\registry-v1' ($b.lane_id+'.json')) $false\n$checks=@{}; $images=@{}\nforeach($role in @('runner','child','postcondition')){\n  $pv=$state.($role+'_pid'); $creation=$state.($role+'_start_utc')\n  $first=Get-IdentityEvidence -LaneId $b.lane_id -JobId $b.job_id -Role $role -PidValue $pv -ExpectedCreationUtc $creation\n  if($first.identity -ceq 'MATCHING_RECORDED_PROCESS'){\n    try {\n      $proc=Get-Process -Id $pv -ErrorAction Stop\n      $images[$role]=@{pid=$proc.Id;creation_utc=$proc.StartTime.ToUniversalTime().ToString('o');executable_path=$proc.Path;checked_utc=[DateTime]::UtcNow.ToString('o')}\n    } catch { $images[$role]=$null }\n    $checks[$role]=Get-IdentityEvidence -LaneId $b.lane_id -JobId $b.job_id -Role $role -PidValue $pv -ExpectedCreationUtc $creation\n  } else { $checks[$role]=$first }\n}\n$stable=$true\nforeach($p in @($files.Keys)){\n  if($null -eq $files[$p]){if(Test-Path -LiteralPath $p){$stable=$false}}\n  elseif(!(Test-Path -LiteralPath $p -PathType Leaf) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -cne $files[$p]){$stable=$false}\n}\n@{host_id='bbb88aa0-1598-43f6-b56c-a7db22af086a';observation_utc=[DateTime]::UtcNow.ToString('o');stable=$stable;job=$job;state=$state;heartbeat=$heartbeat;result=$result;lane=$lane;checks=$checks;images=$images} | ConvertTo-Json -Depth 12 -Compress\n";
function serverBindings(ctx){
  const bindings=new Map();
  for(const job of (Array.isArray(ctx.jobs)?ctx.jobs:[]).slice(0,MAX_JOBS)){
    if(!job||typeof job.job_id!=='string'||!JOB_ID.test(job.job_id))continue;
    if(typeof job.base_sha!=='string'||!SHA.test(job.base_sha)||!validPath(job.worktree)){bindings.set(job.job_id,{job_id:job.job_id,binding_error:'BINDING_UNPROVEN'});continue;}
    const lanes=(ctx.lanes||[]).filter(l=>LANE_ID.test(l.lane_id||'')&&samePath(l.worktree,job.worktree)&&l.head_sha===job.base_sha);
    if(lanes.length!==1||bindings.has(job.job_id))bindings.set(job.job_id,{job_id:job.job_id,binding_error:'AMBIGUOUS_JOB_LANE_BINDING'});
    else bindings.set(job.job_id,{job_id:job.job_id,lane_id:lanes[0].lane_id,base_sha:job.base_sha,worktree:job.worktree});
  }
  return bindings;
}
function systemObserve(binding){
  const output=childProcess.execFileSync('C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    ['-NoLogo','-NoProfile','-NonInteractive','-Command',OBSERVE_PS],
    {input:JSON.stringify(binding),encoding:'utf8',windowsHide:true,timeout:10000,maxBuffer:1024*1024});
  return JSON.parse(output.replace(/^\uFEFF/,''));
}
function createService(ctx,observe=systemObserve,clock=()=>new Date().toISOString()){
  const bindings=serverBindings(ctx);
  return {
    get(jobId){
      if(typeof jobId!=='string'||!JOB_ID.test(jobId))throw new Error('INVALID_JOB_ID');
      const binding=bindings.get(jobId);
      if(!binding)throw new Error('JOB_NOT_SERVER_BOUND');
      const started=clock();
      if(binding.binding_error)return project(binding,{error:binding.binding_error},started,clock());
      let raw;
      try{raw=observe(binding);}catch{raw={error:'OBSERVER_UNAVAILABLE_OR_INVALID'};}
      return project(binding,raw,started,clock());
    },
    list(){
      const ids=[...bindings.keys()].slice(0,LIST_LIMIT);
      return {scope:'SERVER_BOUND_INVENTORY_CURRENT_PER_REQUEST_OBSERVATIONS',complete_inventory:false,
        inventory_limit:MAX_JOBS,observation_limit:LIST_LIMIT,unobserved_count:bindings.size-ids.length,
        executions:ids.map(id=>this.get(id)).filter(x=>x.state!=='PROVEN_TERMINAL')};
    }
  };
}
function registerTools(server,z,ctx,service=createService(ctx)){
  const wrap=fn=>async input=>{
    try{const value=fn(input);return {content:[{type:'text',text:JSON.stringify(value)}],structuredContent:value};}
    catch(error){return {isError:true,content:[{type:'text',text:error.message}],
      structuredContent:{error:{code:'EXECUTION_IDENTITY_REFUSED',message:error.message}}};}
  };
  server.registerTool('list_active_executions',{
    description:'Bounded server-bound inventory with current request observations; UNKNOWN is not liveness. No control.',
    inputSchema:z.object({}).strict()
  },wrap(()=>service.list()));
  server.registerTool('get_execution_identity',{
    description:'Current PID/creation/image identity for one server-bound job. Snapshot binding is not running proof.',
    inputSchema:z.object({job_id:z.string().regex(JOB_ID)}).strict()
  },wrap(input=>service.get(input.job_id)));
}
module.exports={project,precise,createService,serverBindings,registerTools,OBSERVE_PS};
