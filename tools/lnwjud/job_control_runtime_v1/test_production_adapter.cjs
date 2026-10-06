'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const R = require('./runtime_request_contract.cjs');
const W = require('./windows_long_job_bridge.cjs');
const { createProductionAdapter } = require('./production_adapter.cjs');
const bytes = x => Buffer.from(JSON.stringify(x));
class MemoryStore {
  constructor(events) { this.events=events; this.serialization='EXCLUSIVE_LOCK_CAS_DURABLE_READBACK'; this.state=null; this.a={revision:0,sha256:null}; this.held=false; this.faultAt=null; }
  withLock(fn){ if(this.held) throw new R.Refusal('STORE_LOCKED'); this.held=true; try{return fn();} finally{this.held=false;} }
  read(){ return this.state===null?null:Buffer.from(this.state); }
  anchor(){ return { ...this.a }; }
  checkpoint(x){ this.events.push(x); if(this.faultAt===x){this.faultAt=null; throw new R.Refusal('INJECTED_FAULT:'+x);} }
  compareAndSwap(prior,next){ assert.equal(this.held,true); const actual=this.state===null?null:R.hash(this.state); if(actual!==prior||this.a.sha256!==prior)return false; this.state=Buffer.from(next); const parsed=R.parse(next,4*1024*1024); this.a={revision:parsed.revision,sha256:R.hash(next)}; this.events.push('cas'); return true; }
}
function makeProfile(id,stage,head) {
  const p={ profile_id:id, profile_sha256:'', stage, source_head:head, runner:'LONG_JOB_RUNNER_V1',
    target:{file_path:'C:\\EA_LAB_CONTROL\\profiles\\node.exe',arguments:['--fixture-profile',id]},
    worktree:'D:\\EA_LAB_CONTROL\\w\\fixture-runtime',base_sha:head,timeout_sec:600,heartbeat_sec:5,
    postcondition:{file_path:'C:\\EA_LAB_CONTROL\\profiles\\postcondition.exe',arguments:['--stage',stage]},
    jobs_root:'D:\\EA_LAB_CONTROL\\jobs' };
  p.profile_sha256=W.profileDigest(p); return p;
}
function fixture({ fileStore=false }={}) {
  const events=[], contract=Buffer.from('runtime adapter fixture contract\n');
  const source={head:'a'.repeat(40),tree:'b'.repeat(40),config_sha256:R.hash('config')};
  const stages=['stage-alpha','stage-beta','stage-gamma'];
  const profiles=Object.fromEntries(stages.map((s,i)=>['profile-'+(i+1),makeProfile('profile-'+(i+1),s,source.head)]));
  const binding={lane_id:'fixture-lane',contract_id:'fixture-contract',contract_sha256:R.hash(contract),source,
    allowlisted_paths:['tools/fixture/source.cjs'],worktree_identity_sha256:R.hash('worktree-identity'),
    resource_owner:'fixture-owner',runtime_resource:'fixture-runtime',acceptance_criteria:['FIXTURE_ONLY','NO_REAL_PROCESS'],
    budget:{repair:1,retry:2},direct_consumer:'fixture-consumer',host_id:'fixture-host',stages:[...stages],
    profile_by_stage:Object.fromEntries(stages.map((s,i)=>[s,{profile_id:'profile-'+(i+1),profile_sha256:profiles['profile-'+(i+1)].profile_sha256}]))};
  const env={binding:R.clone(binding),contract_bytes:contract,lane_current:true,clean:true,path_identity_verified:true,
    worktree_identity_sha256:binding.worktree_identity_sha256,resource_owner:binding.resource_owner,
    runtime_resource:binding.runtime_resource,resource_available:true,remaining_repair:1,remaining_retry:2,
    budget_available:true,now_utc:'2026-10-06T12:00:02.0000000Z',observed_utc:'2026-10-06T12:00:01.0000000Z'};
  const existing={}, identities={}, runners={}; let launches=0, faultAfterLaunch=false, faultBeforeLaunch=false, skipInspectorPersist=false;
  const actuator={kind:'EXISTING_LONG_JOB_RUNNER_ACTUATOR_V1',launch(call){
    if(faultBeforeLaunch){faultBeforeLaunch=false;const e=new R.Refusal('ACTUATION_NOT_STARTED');e.launch_not_started=true;throw e;}
    events.push('actuator_launch'); launches++;
    const receipt=R.hash(R.stable({job_id:call.expected.job_id,launches}));
    if(!skipInspectorPersist) existing[call.expected.job_id]={...R.clone(call.expected),launch_receipt_sha256:receipt};
    identities[call.expected.job_id]={job_id:call.expected.job_id,state:'PROVEN_RUNNING',observed_utc:env.observed_utc};
    runners[call.expected.job_id]={job_id:call.expected.job_id,state:'RUNNING',checkpoint_sha256:R.hash('running:'+call.expected.job_id)};
    if(faultAfterLaunch){ faultAfterLaunch=false; throw new R.Refusal('INJECTED_LOST_ACK'); }
    return {job_id:call.expected.job_id,launch_receipt_sha256:receipt};
  }};
  const inspector={kind:'EXISTING_LONG_JOB_RUNNER_INSPECTOR_V1',get:jobId=>existing[jobId]?R.clone(existing[jobId]):null};
  const bridge=W.createWindowsLongJobBridge({repoRoot:'D:\\EA_LAB_CONTROL\\w\\fixture-repo',catalog:profiles,actuator,inspector});
  const executionIdentity={kind:'LNWJUD_EXECUTION_IDENTITY_READER_V1',get:jobId=>identities[jobId]?R.clone(identities[jobId]):null};
  const runnerStatus={kind:'EXISTING_LONG_JOB_RUNNER_STATUS_V1',get:jobId=>runners[jobId]?R.clone(runners[jobId]):null};
  let root=null, store;
  if(fileStore){ root=fs.mkdtempSync(path.join(os.tmpdir(),'lnwjud-runtime-adapter-')); store=W.createWindowsRuntimeStore({root}); }
  else store=new MemoryStore(events);
  const f={events,contract,source,stages,profiles,binding,env,existing,identities,runners,bridge,executionIdentity,runnerStatus,store,root,sequence:0};
  f.restart=()=>{ f.api=createProductionAdapter({store:f.store,environment:()=>({...R.clone(env),contract_bytes:Buffer.from(contract)}),bridge,executionIdentity,runnerStatus}); return f.api; };
  f.restart();
  f.request=(operation='submit_existing_contract_job',previous=null,overrides={})=>{
    const n=++f.sequence, index=previous?(operation==='resume_existing_job'?previous.current.index+1:previous.current.index):0;
    const base={schema:'LNWJUD_JOB_CONTROL_RUNTIME_REQUEST_V1',request_id:'fixture-request-'+n,idempotency_key:'fixture-key-'+n,
      operation,lane_id:binding.lane_id,contract_id:binding.contract_id,contract_sha256:binding.contract_sha256,source:R.clone(source),
      stage:stages[index],stage_index:index,checkpoint_sha256:previous?.current.checkpoint_sha256??null,
      parent_receipt_sha256:previous?.receipt_sha256??null,target_job_id:previous?.receipt.job_id??null,created_utc:'2026-10-06T12:00:00.0000000Z'};
    return {...base,...R.clone(overrides)};
  };
  f.submit=()=>{ const request=f.request(); const raw=bytes(request); return {request,bytes:raw,result:f.api.submit_existing_contract_job(raw)}; };
  f.call=(operation,previous,overrides={})=>{const request=f.request(operation,previous,overrides),raw=bytes(request);return{request,bytes:raw,result:f.api[operation](raw)};};
  f.setTerminal=result=>{const id=result.current.runner_job_id; identities[id]={job_id:id,state:'PROVEN_TERMINAL',observed_utc:env.observed_utc}; runners[id]={job_id:id,state:'COMPLETE',checkpoint_sha256:R.hash('complete:'+id)};};
  f.snapshot=()=>({state:f.store.read()?.toString('base64')??null,anchor:f.store.anchor(),launches,existing:R.clone(existing)});
  f.launches=()=>launches; f.faultAfterLaunch=()=>{faultAfterLaunch=true;}; f.faultBeforeLaunch=()=>{faultBeforeLaunch=true;}; f.skipInspectorPersist=()=>{skipInspectorPersist=true;}; f.faultStoreAt=x=>{f.store.faultAt=x;};
  f.destroy=()=>{if(root)fs.rmSync(root,{recursive:true,force:true});};
  return f;
}
function expectRefusal(fn,code){assert.throws(fn,e=>e instanceof R.Refusal&&(!code||e.code===code),'expected '+code);}
function unchanged(f,fn,code){const before=f.snapshot();expectRefusal(fn,code);assert.deepEqual(f.snapshot(),before,'refusal must have zero durable/dispatch side effects');}
function run(cases,name){let passed=0;const failures=[];for(const [n,t] of cases){const f=fixture();try{t(f);passed++;console.log('PASS '+n);}catch(e){failures.push(n);console.error('FAIL '+n+'\n'+e.stack);}finally{f.destroy();}}console.log(JSON.stringify({suite:name,total:cases.length,passed,failed:failures.length,failures,real_process_launches:0,runtime_activated:false}));if(failures.length)process.exitCode=1;}
const cases=[]; const add=(n,t)=>cases.push([n,t]);
add('API exposes only typed Job Control operations',f=>assert.deepEqual(Object.keys(f.api).sort(),[...R.OPS,'get_job_current'].sort()));
add('client request has no executable path args PID provider command or filesystem target',f=>{const r=f.request();for(const k of ['file_path','arguments','pid','command','provider','worktree','jobs_root'])assert.equal(Object.hasOwn(r,k),false);assert.doesNotThrow(()=>R.validate(bytes(r),f.env,r.operation));});
add('server profile resolves exact stage and frozen hash',f=>{const r=f.request();const v=R.validate(bytes(r),f.env,r.operation);const s=R.resolvedStage(f.binding,v.stage);assert.equal(s.profile_id,'profile-1');assert.equal(s.profile_sha256,f.profiles['profile-1'].profile_sha256);});
add('submit persists receipt and intent before one typed bridge dispatch',f=>{const s=f.submit();assert.equal(f.launches(),1);assert.equal(s.result.current.execution_state,'PROVEN_RUNNING');const readbacks=f.events.filter(x=>String(x).startsWith('readback_'));assert.ok(readbacks.length>=2);assert.ok(f.events.indexOf('readback_dispatch_intent')<f.events.indexOf('actuator_launch'));});
add('same idempotency key and exact bytes returns same receipt with no redispatch',f=>{const s=f.submit(),n=f.launches(),r=f.api.submit_existing_contract_job(s.bytes);assert.equal(f.launches(),n);assert.equal(r.receipt_sha256,s.result.receipt_sha256);assert.equal(r.current.runner_job_id,s.result.current.runner_job_id);});
add('restart replays durable state without redispatch',f=>{const s=f.submit();f.restart();const r=f.api.submit_existing_contract_job(s.bytes);assert.equal(f.launches(),1);assert.equal(r.receipt_sha256,s.result.receipt_sha256);});
add('lost acknowledgement after launch reconciles deterministic existing job without duplicate dispatch',f=>{const r=f.request(),raw=bytes(r);f.faultAfterLaunch();const recovered=f.api.submit_existing_contract_job(raw);assert.equal(f.launches(),1);assert.equal(recovered.current.protocol_state,'BOUND');f.restart();const replay=f.api.submit_existing_contract_job(raw);assert.equal(f.launches(),1);assert.equal(replay.current.protocol_state,'BOUND');});
add('adopt requires and accepts current execution identity proof',f=>{const s=f.submit();const a=f.call('adopt_existing_job',s.result);assert.equal(a.result.current.execution_state,'PROVEN_RUNNING');assert.equal(f.launches(),1);});
add('pause-after-stage blocks progression and becomes paused only after proven terminal COMPLETE',f=>{const s=f.submit();const p=f.call('request_pause_after_stage',s.result);assert.equal(p.result.current.protocol_state,'PAUSE_REQUESTED');f.setTerminal(p.result);const now=f.api.get_job_current(p.request.idempotency_key);assert.equal(now.current.protocol_state,'PAUSED_AFTER_STAGE');assert.equal(now.current.stage_complete,true);});
add('resume launches exactly one next admitted stage',f=>{const s=f.submit();const p=f.call('request_pause_after_stage',s.result);f.setTerminal(p.result);const paused=f.api.get_job_current(p.request.idempotency_key);const r=f.call('resume_existing_job',paused);assert.equal(r.result.current.index,1);assert.equal(r.result.current.stage,'stage-beta');assert.equal(f.launches(),2);const replay=f.api.resume_existing_job(r.bytes);assert.equal(f.launches(),2);assert.equal(replay.current.runner_job_id,r.result.current.runner_job_id);});
add('runner RUNNING cannot prove execution when Execution Identity is missing',f=>{const s=f.submit();delete f.identities[s.result.current.runner_job_id];const c=f.api.get_job_current(s.request.idempotency_key);assert.equal(c.current.execution_state,'UNKNOWN');assert.equal(c.current.durable_runner_state,'RUNNING');});
add('stale Execution Identity fails closed to UNKNOWN',f=>{const s=f.submit(),id=s.result.current.runner_job_id;f.identities[id].observed_utc='2026-10-06T11:59:59.0000000Z';const c=f.api.get_job_current(s.request.idempotency_key);assert.equal(c.current.execution_state,'UNKNOWN');assert.equal(c.current.reason,'EXECUTION_IDENTITY_STALE_OR_FUTURE');});
add('IDENTITY_MISMATCH remains explicit and never becomes running',f=>{const s=f.submit(),id=s.result.current.runner_job_id;f.identities[id].state='IDENTITY_MISMATCH';const c=f.api.get_job_current(s.request.idempotency_key);assert.equal(c.current.execution_state,'IDENTITY_MISMATCH');assert.notEqual(c.current.execution_state,'PROVEN_RUNNING');});
add('server bridge uses only canonical existing Long Job Runner script',f=>{const s=f.submit();const e=f.existing[s.result.current.runner_job_id];assert.equal(e.runner_script,'D:\\EA_LAB_CONTROL\\w\\fixture-repo\\scripts\\long_jobs\\start_long_job.ps1');assert.equal(e.profile_id,'profile-1');});
add('production file store survives adapter reconstruction without a process launch',_=>{const f=fixture({fileStore:true});try{const s=f.submit();f.restart();const r=f.api.get_job_current(s.request.idempotency_key);assert.equal(r.receipt_sha256,s.result.receipt_sha256);assert.equal(f.launches(),1);}finally{f.destroy();}});
add('durable PREPARED crash resumes exact request once without duplicate dispatch',f=>{f.faultStoreAt('readback_prepared');const r=f.request(),raw=bytes(r);expectRefusal(()=>f.api.submit_existing_contract_job(raw),'INJECTED_FAULT:readback_prepared');assert.equal(f.launches(),0);f.restart();const resumed=f.api.submit_existing_contract_job(raw);assert.equal(f.launches(),1);assert.equal(resumed.current.protocol_state,'BOUND');const replay=f.api.submit_existing_contract_job(raw);assert.equal(f.launches(),1);assert.equal(replay.receipt_sha256,resumed.receipt_sha256);});
add('read-only current survives dirty unavailable resource and exhausted admission budget',f=>{const s=f.submit();f.env.clean=false;f.env.resource_available=false;f.env.budget_available=false;const c=f.api.get_job_current(s.request.idempotency_key);assert.equal(c.receipt_sha256,s.result.receipt_sha256);assert.equal(c.current.execution_state,'PROVEN_RUNNING');});
add('budget replenishment never bricks reads and durable ledger never increases',f=>{f.env.remaining_repair=0;const s=f.submit();assert.equal(s.result.receipt.budget_observation.remaining_repair,0);f.env.remaining_repair=1;const read=f.api.get_job_current(s.request.idempotency_key);assert.equal(read.receipt_sha256,s.result.receipt_sha256);const a=f.call('adopt_existing_job',read);assert.equal(a.result.receipt.budget_observation.remaining_repair,0);assert.equal(f.launches(),1);});
add('pause uses current server checkpoint when client checkpoint became stale in same bound stage',f=>{const s=f.submit();const id=s.result.current.runner_job_id;const stale=s.result.current.checkpoint_sha256;f.runners[id].checkpoint_sha256=R.hash('newer-checkpoint');const p=f.call('request_pause_after_stage',s.result,{checkpoint_sha256:stale});assert.equal(p.result.current.protocol_state,'PAUSE_REQUESTED');assert.equal(p.result.receipt.checkpoint_sha256,f.runners[id].checkpoint_sha256);assert.equal(p.result.current.checkpoint_sha256,f.runners[id].checkpoint_sha256);});
add('pre-launch actuation failure leaves replayable intent and exact replay dispatches once',f=>{const r=f.request(),raw=bytes(r);f.faultBeforeLaunch();expectRefusal(()=>f.api.submit_existing_contract_job(raw),'ACTUATION_NOT_STARTED');assert.equal(f.launches(),0);f.restart();const recovered=f.api.submit_existing_contract_job(raw);assert.equal(f.launches(),1);assert.equal(recovered.current.protocol_state,'BOUND');});
add('production file store uses one authenticated atomic record and survives orphan temp',_=>{const f=fixture({fileStore:true});try{const s=f.submit();assert.equal(fs.existsSync(path.join(f.root,'record.json')),true);assert.equal(fs.existsSync(path.join(f.root,'state.json')),false);assert.equal(fs.existsSync(path.join(f.root,'anchor.json')),false);fs.writeFileSync(path.join(f.root,'record.json.next'),'orphan');f.restart();const read=f.api.get_job_current(s.request.idempotency_key);assert.equal(read.receipt_sha256,s.result.receipt_sha256);const a=f.request('adopt_existing_job',read);expectRefusal(()=>f.api.adopt_existing_job(bytes(a)),'STORAGE_RECONCILE_REQUIRED');assert.equal(f.launches(),1);}finally{f.destroy();}});
if (require.main === module) run(cases,'LNWJUD_JOB_CONTROL_RUNTIME_ADAPTER_V1_POSITIVE');
module.exports = { fixture, expectRefusal, unchanged, bytes };