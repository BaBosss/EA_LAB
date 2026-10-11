'use strict';
// Inert T0-T2 eligibility classifier. No I/O, process launch, Registry writes, or provider calls.
// Input MUST come from separately trusted canonical/Registry/process/receipt adapters. Hashes are
// tamper detectors, not signatures or a substitute for provenance/lease authority.
const { createHash } = require('node:crypto');
const SCHEMA='EA_LAB_ORCHESTRATOR_READ_ONLY_INPUT_V1';
const OUTPUT='EA_LAB_ORCHESTRATOR_READ_ONLY_DECISION_V1';
const SHA40=/^[0-9a-f]{40}$/;
const SHA64=/^[0-9a-f]{64}$/;
const ID=/^[A-Za-z][A-Za-z0-9._-]{2,127}$/;
const SAFE_ACTIONS=new Set(['SOURCE_TEST','READ_ONLY','EVIDENCE_RECONCILE','DRY_RUN','RETRY']);
const KNOWN_STAGES=new Set(['DISPATCH','OBSERVE','REVIEW','INTEGRATE']);
const ACTIVE=new Set(['READY','RUNNING','REVIEW','FROZEN','INTEGRATING','WAITING']);
const TERMINAL=new Set(['COMPLETE','PROVEN_TERMINAL']);
const exact=(o,keys)=>obj(o)&&Object.keys(o).sort().join('|')===[...keys].sort().join('|');
const obj=x=>x!==null&&typeof x==='object'&&!Array.isArray(x)&&Object.getPrototypeOf(x)===Object.prototype;
const sha40=x=>typeof x==='string'&&SHA40.test(x);
const nonblank=x=>typeof x==='string'&&x.length>0&&x.trim()===x;
const id=x=>nonblank(x)&&ID.test(x);
const validPath=x=>nonblank(x)&&/^[A-Za-z]:\\[^:*?"<>|\x00-\x1f]+/.test(x)&&!/(?:^|\\)\.\.?(?:\\|$)/.test(x);
const digest=x=>createHash('sha256').update(JSON.stringify(x)).digest('hex');
const sealOK=r=>obj(r)&&exact(r,['data','sha256'])&&obj(r.data)&&
  typeof r.sha256==='string'&&SHA64.test(r.sha256)&&digest(r.data)===r.sha256;
const immutable=x=>{if(x&&typeof x==='object'){Object.values(x).forEach(immutable);Object.freeze(x)}return x};
function utc(s) {
  if(typeof s!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(s))return null;
  const n=Date.parse(s);
  if(!Number.isFinite(n))return null;
  if(new Date(n).toISOString().slice(0,19)!==s.slice(0,19))return null;
  return n;
}
function reason(status,code){return {status,reason:code}}
function verifyJob(j,t,now) {
  if(!obj(j)||j.task_id!==t.task_id||j.lane_id!==t.lane_id||j.source_head!==t.source_head||!id(j.job_id))
    return reason('UNKNOWN','JOB_BINDING_UNVERIFIED');
  const i=j.identity;
  if(!obj(i)||!Number.isSafeInteger(i.pid)||i.pid<=0||utc(i.creation_utc)===null||
    !validPath(i.executable)||i.worktree!==t.worktree||i.source_head!==t.source_head)
    return reason('UNKNOWN','PROCESS_IDENTITY_UNVERIFIED');
  const created=utc(i.creation_utc),beat=utc(i.heartbeat_utc);
  if(created>now||beat===null||beat>now||beat<created)
    return reason('UNKNOWN','PROCESS_TIME_INVALID');
  if(TERMINAL.has(j.state)) {
    const p=j.terminal;
    if(!obj(p)||p.exit_code!==0||p.postcondition!=='PASS'||!sealOK(p.receipt))
      return reason('UNKNOWN','TERMINAL_POSTCONDITION_UNPROVEN');
    const b=p.receipt.data;
    if(!exact(b,['job_id','task_id','lane_id','source_head','exit_code','postcondition'])||
       b.job_id!==j.job_id||b.task_id!==t.task_id||b.lane_id!==t.lane_id||
       b.source_head!==t.source_head||b.exit_code!==0||b.postcondition!=='PASS')
      return reason('UNKNOWN','TERMINAL_RECEIPT_BINDING_INVALID');
    return reason('PROVEN_TERMINAL','JOB_TERMINAL_POSTCONDITION_PROVEN');
  }
  if(!['RUNNING','QUEUED','WAITING_RESOURCE'].includes(j.state))
    return reason('UNKNOWN','JOB_STATE_UNRECOGNIZED');
  if(now-beat>300000)return reason('UNKNOWN','JOB_HEARTBEAT_STALE');
  return reason('WAITING_RESOURCE','JOB_EXISTS_NO_DUPLICATE_DISPATCH');
}
function validTestReceipt(r,t) {
  if(!sealOK(r))return false;
  const d=r.data;
  return exact(d,['task_id','source_head','source_tree','passed','positive','negative','exit_code'])&&
    d.task_id===t.task_id&&d.source_head===t.source_head&&d.source_tree===t.source_tree&&
    d.passed===true&&d.exit_code===0&&Number.isSafeInteger(d.positive)&&d.positive>0&&
    Number.isSafeInteger(d.negative)&&d.negative>0;
}
function validReviewReceipt(r,t) {
  if(!sealOK(r))return false;
  const v=r.data;
  return exact(v,['task_id','source_head','source_tree','reviewed_by','verdict','independent'])&&
    v.task_id===t.task_id&&v.source_head===t.source_head&&v.source_tree===t.source_tree&&
    v.reviewed_by===t.reviewer_id&&t.author_id!==t.reviewer_id&&
    v.independent===true&&v.verdict==='SCRUTINY_PASS';
}
function overlap(a,b) {
  const x=String(a).replaceAll('\\','/').toLowerCase().replace(/\/+$/,'');
  const y=String(b).replaceAll('\\','/').toLowerCase().replace(/\/+$/,'');
  return x===y||x.startsWith(y+'/')||y.startsWith(x+'/');
}
function reconcile(input) {
  const tasks=Array.isArray(input?.tasks)?input.tasks:[];
  const output=(states)=>immutable({schema:OUTPUT,
    decisions:tasks.map((t,n)=>({task_id:id(t?.task_id)?t.task_id:'INVALID_'+n,
      status:states[n].status,reason:states[n].reason})),
    summary:tasks.reduce((a,t,n)=>{const k=states[n].status;a[k]=(a[k]||0)+1;return a},{} )});
  const allUnknown=code=>output(tasks.map(()=>reason('UNKNOWN',code)));
  if(!exact(input,['schema','now_utc','source','registry','leases','jobs','tasks'])||input.schema!==SCHEMA||
     !Array.isArray(input.tasks)||!Array.isArray(input.jobs)||!Array.isArray(input.leases))
     return allUnknown('INPUT_SCHEMA_INVALID');
  const now=utc(input.now_utc),source=input.source,reg=input.registry;
  if(now===null||!obj(source)||!obj(reg)||!Array.isArray(reg.lanes)||!Array.isArray(reg.main_ct_ids))
    return allUnknown('GLOBAL_INPUT_MALFORMED');
  if(!exact(source,['head','tree','origin_master','ls_remote','checkout_head','checkout_tree','clean','captured_utc'])||
    ![source.head,source.tree,source.origin_master,source.ls_remote,source.checkout_head,source.checkout_tree].every(sha40))
    return allUnknown('SOURCE_IDENTITY_MALFORMED');
  const captured=utc(source.captured_utc);
  if(captured===null||captured>now||now-captured>900000)
    return allUnknown('SOURCE_SNAPSHOT_STALE_OR_FUTURE');
  if(source.head!==source.origin_master||source.head!==source.ls_remote||
    source.head!==source.checkout_head||source.tree!==source.checkout_tree)
    return allUnknown('SOURCE_GIT_IDENTITY_DRIFT');
  if(source.clean!==true)return output(tasks.map(()=>reason('BLOCKED','WORKTREE_NOT_CLEAN')));
  if(reg.validated!==true)return allUnknown('REGISTRY_NOT_VALIDATED');
  if(reg.main_ct_ids.length!==1||!id(reg.main_ct_ids[0]))
    return output(tasks.map(()=>reason('BLOCKED','MAIN_CT_SINGLETON_UNVERIFIED')));
  if(!exact(reg,['validated','main_ct_ids','lanes']))return allUnknown('REGISTRY_SCHEMA_INVALID');
  const indexes=new Map(),idem=new Map(),resOwners=new Map(),results=new Map(),visiting=new Set();
  for(const t of tasks){
    if(id(t?.task_id)){indexes.set(t.task_id,(indexes.get(t.task_id)||0)+1)}
    if(nonblank(t?.idempotency_key))idem.set(t.idempotency_key,(idem.get(t.idempotency_key)||0)+1);
    if(Array.isArray(t?.resources))for(const k of t.resources){
      if(nonblank(k))resOwners.set(k,(resOwners.get(k)||0)+1);
    }
  }
  const byId=new Map(tasks.filter(t=>id(t?.task_id)).map(t=>[t.task_id,t]));
  function assess(t){
    if(!obj(t)||!id(t.task_id)||!id(t.lane_id)||!id(t.owner)||!id(t.idempotency_key)||
       !KNOWN_STAGES.has(t.stage)||!Array.isArray(t.resources)||!Array.isArray(t.dependency_ids)||
       !sha40(t.source_head)||!sha40(t.source_tree)||!validPath(t.worktree)||
       !Number.isSafeInteger(t.repair_remaining)||t.repair_remaining<0||!id(t.author_id)||!id(t.reviewer_id))
      return reason('UNKNOWN','TASK_SCHEMA_OR_IDENTITY_INVALID');
    if(indexes.get(t.task_id)>1||idem.get(t.idempotency_key)>1)
      return reason('BLOCKED','DUPLICATE_TASK_OR_IDEMPOTENCY');
    if(t.source_head!==source.head||t.source_tree!==source.tree)
      return reason('UNKNOWN','TASK_SOURCE_MISMATCH');
    if(!SAFE_ACTIONS.has(t.action))return reason('BLOCKED','ACTION_NOT_T0_T2_ALLOWED');
    if(t.action==='RETRY'&&t.repair_remaining===0)return reason('BLOCKED','REPAIR_BUDGET_EXHAUSTED');
    if(t.author_id===t.reviewer_id)return reason('BLOCKED','AUTHOR_REVIEWER_CONFLICT');
    const owners=reg.lanes.filter(l=>obj(l)&&l.lane_id===t.lane_id);
    if(owners.length!==1||owners[0].owner!==t.owner||owners[0].worktree!==t.worktree)
      return reason('BLOCKED','REGISTRY_OWNER_WORKTREE_CONFLICT');
    if(owners[0].state==='WAITING'||owners[0].state==='PAUSED')
      return reason('WAITING_RESOURCE','INCUMBENT_LANE_WAITING');
    if(!ACTIVE.has(owners[0].state)||!Array.isArray(owners[0].critical_paths))
      return reason('BLOCKED','REGISTRY_LANE_NOT_ADMITTED');
    for(const l of reg.lanes){
      if(!obj(l)||l.lane_id===t.lane_id||!['RUNNING','REVIEW','FROZEN','INTEGRATING'].includes(l.state))continue;
      if(l.owner===t.owner||(
        Array.isArray(l.critical_paths)&&l.critical_paths.some(p=>
          owners[0].critical_paths.some(q=>overlap(p,q)))))
        return reason('WAITING_RESOURCE','EXISTING_ACTIVE_OWNER_OR_PATH');
    }
    if(t.provider!==null){
      const p=t.provider;
      if(!obj(p)||!nonblank(p.name)||!nonblank(p.model)||p.auth!=='VERIFIED'||
         !Number.isFinite(p.cost_ceiling_usd)||p.cost_ceiling_usd<=0||
         !Number.isFinite(p.max_cost_usd)||p.max_cost_usd<0||
         p.max_cost_usd>p.cost_ceiling_usd||
         utc(p.authenticated_at)===null||utc(p.authenticated_at)>now||
         now-utc(p.authenticated_at)>3600000)
        return reason('BLOCKED','AI_AUTH_OR_COST_NOT_PROVEN');
    }
    if(t.resources.length!==new Set(t.resources).size)
      return reason('BLOCKED','DUPLICATE_RESOURCE_IN_TASK');
    for(const resource of t.resources){
      if(!nonblank(resource))return reason('UNKNOWN','RESOURCE_INVALID');
      if(resOwners.get(resource)>1)return reason('WAITING_RESOURCE','RESOURCE_CONCURRENT_REQUEST');
      const candidates=input.leases.filter(l=>obj(l)&&l.resource===resource);
      if(candidates.length!==1)return reason('WAITING_RESOURCE','LEASE_MISSING_OR_DUPLICATE');
      const l=candidates[0];
      if(l.owner!==t.owner)return reason('WAITING_RESOURCE','LEASE_FOREIGN_OWNER');
      if(!id(l.lease_id)||utc(l.expires_utc)===null||utc(l.expires_utc)<=now)
        return reason('WAITING_RESOURCE','LEASE_EXPIRED_OR_UNQUALIFIED');
      if(!sealOK(l.receipt)||!exact(l.receipt.data,['resource','owner','lease_id','source_head'])||
         l.receipt.data.resource!==resource||l.receipt.data.owner!==t.owner||
         l.receipt.data.lease_id!==l.lease_id||l.receipt.data.source_head!==source.head)
        return reason('UNKNOWN','LEASE_RECEIPT_TAMPERED_OR_UNBOUND');
    }
    const existing=input.jobs.filter(j=>obj(j)&&(j.task_id===t.task_id||
      (j.lane_id===t.lane_id&&j.state==='RUNNING')));
    if(existing.length>1)return reason('BLOCKED','DUPLICATE_EXISTING_JOBS');
    if(existing.length===1)return verifyJob(existing[0],t,now);
    for(const dep of t.dependency_ids){
      if(!id(dep)||dep===t.task_id||!byId.has(dep))
        return reason('BLOCKED','DEPENDENCY_UNRESOLVED');
      if(visiting.has(dep))return reason('BLOCKED','DEPENDENCY_CYCLE');
      const res=evalId(dep);
      if(res.status!=='PROVEN_TERMINAL')return reason('BLOCKED','DEPENDENCY_NOT_PROVEN_TERMINAL');
    }
    if(t.stage==='REVIEW'||t.stage==='INTEGRATE'){
      if(!validTestReceipt(t.test_receipt,t))
        return reason(t.test_receipt?'UNKNOWN':'BLOCKED','TEST_EVIDENCE_NOT_ACCEPTED');
      if(t.stage==='REVIEW')return reason('READY_FOR_REVIEW','OFFLINE_TESTS_ACCEPTED');
      if(!validReviewReceipt(t.review,t))
        return reason(t.review?'BLOCKED':'BLOCKED','INDEPENDENT_EXACT_HEAD_REVIEW_MISSING_OR_FAIL');
      return reason('READY_FOR_CT_INTEGRATION','FROZEN_ACCEPTED_FOR_CT_ONLY');
    }
    if(t.stage==='OBSERVE')return reason('UNKNOWN','TERMINAL_JOB_NOT_OBSERVED');
    return reason('READY','DRY_RUN_ELIGIBLE_NO_DISPATCH');
  }
  function evalId(key){
    if(results.has(key))return results.get(key);
    if(visiting.has(key))return reason('BLOCKED','DEPENDENCY_CYCLE');
    visiting.add(key);
    const v=assess(byId.get(key));
    visiting.delete(key);results.set(key,v);return v;
  }
  return output(tasks.map(t=>id(t?.task_id)&&byId.get(t.task_id)===t?evalId(t.task_id):assess(t)));
}
module.exports={reconcile};
