'use strict';
// SOURCE/OFFLINE ONLY. No fs, subprocess, timer, network, Registry or runtime adapter.
const C=require('./request_contract.cjs');
const {refuse,hash,stable,clone,id,digest,time,parse,keys,validate,bindingHash}=C;
const PHASES=['PREPARED','DISPATCH_INTENT','BOUND','PAUSE_REQUESTED','RESUME_INTENT'];
function createJobControl({store,environment,observer,stageConsumer,mode}){
 if(mode!=='SYNTHETIC_FIXTURE'||store?.kind!=='SYNTHETIC_FIXTURE'||
 observer?.kind!=='SYNTHETIC_FIXTURE')refuse('SOURCE_OFFLINE_ONLY');
 const env=()=>environment();
 const empty=()=>({schema:'LNWJUD_JOB_CONTROL_FIXTURE_STORE_V1',revision:0,previous_sha256:null,requests:{},jobs:{}});
 function load(){
  const bytes=store.read();if(bytes===null)return {data:empty(),bytes:null};
  const data=parse(bytes,4*1024*1024);
  keys(data,['schema','revision','previous_sha256','requests','jobs']);
  if(data.schema!=='LNWJUD_JOB_CONTROL_FIXTURE_STORE_V1'||!Number.isSafeInteger(data.revision)||data.revision<1||
   (data.revision>1&&!digest(data.previous_sha256)))refuse('MALFORMED_STATE');
  const e=env();
  if(!Number.isSafeInteger(e.minimum_revision)||e.minimum_revision<0||data.revision<e.minimum_revision)refuse('STALE_RECEIPT');
  if(!data.requests||Array.isArray(data.requests)||!data.jobs||Array.isArray(data.jobs))refuse('MALFORMED_STATE');
  const seen=new Set();
  for(const [key,record] of Object.entries(data.requests)){
   keys(record,['bytes_base64','receipt','receipt_sha256']);
   if(typeof record.bytes_base64!=='string'||!(/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/).test(record.bytes_base64))refuse('MALFORMED_STATE');
   const b=Buffer.from(record.bytes_base64,'base64'),r=parse(b),p=record.receipt;
   keys(p,['schema','evidence_kind','request_id','idempotency_key','request_sha256','request_bytes','job_id','binding_sha256','operation','created_utc','prepared_revision','parent_receipt_sha256']);
   if(!id(key)||r.idempotency_key!==key||p.idempotency_key!==key||r.request_id!==p.request_id||
    seen.has(p.request_id)||p.schema!=='LNWJUD_JOB_CONTROL_RECEIPT_V1'||p.evidence_kind!=='SYNTHETIC_FIXTURE'||
    p.request_sha256!==hash(b)||p.request_bytes!==b.length||p.binding_sha256!==bindingHash(r)||
    !C.OPS.includes(p.operation)||p.operation!==r.operation||!id(p.job_id)||
    !Number.isSafeInteger(p.prepared_revision)||p.prepared_revision<1||p.prepared_revision>data.revision||
    p.parent_receipt_sha256!==r.checkpoint?.parent_receipt_sha256||
    p.created_utc!==r.created_utc||time(p.created_utc)===null||time(e.now_utc)===null||
    time(p.created_utc)>time(e.now_utc)||record.receipt_sha256!==hash(stable(p)))refuse('MALFORMED_STATE');
   seen.add(p.request_id);
  }
  for(const [jobId,j] of Object.entries(data.jobs)){
   keys(j,['job_id','binding_sha256','submission_key','latest_key','stage','index','phase','intent_key','checkpoint_sha256']);
   const origin=data.requests[j.submission_key],latest=data.requests[j.latest_key];
   if(jobId!==j.job_id||!id(jobId)||!PHASES.includes(j.phase)||!Number.isSafeInteger(j.index)||j.index<0||
    !id(j.stage)||!digest(j.binding_sha256)||!origin||!latest||origin.receipt.job_id!==jobId||
    latest.receipt.job_id!==jobId||origin.receipt.operation!=='submit_existing_contract_job'||
    origin.receipt.binding_sha256!==j.binding_sha256||latest.receipt.binding_sha256!==j.binding_sha256||
    (j.intent_key!==null&&!data.requests[j.intent_key])||
    (j.checkpoint_sha256!==null&&!digest(j.checkpoint_sha256)))refuse('MALFORMED_STATE');
  }
  for(const record of Object.values(data.requests))if(!data.jobs[record.receipt.job_id])refuse('MALFORMED_STATE');
  return {data:clone(data),bytes};
 }
 function save(frame,label){
  const prior=frame.bytes===null?null:hash(frame.bytes);
  frame.data.revision++;frame.data.previous_sha256=prior;
  const next=Buffer.from(stable(frame.data));
  store.checkpoint('before_'+label);
  store.compareAndSwap(prior,next); // Must hold the same exclusive store lock.
  store.checkpoint('after_'+label);
  const readback=store.read();
  if(!Buffer.isBuffer(readback)||!readback.equals(next))refuse('RECEIPT_READBACK_MISMATCH');
  frame.bytes=next;store.checkpoint('readback_'+label);
 }
 function evidence(j,frame){
  const e=env(),o=observer.observe(j.job_id),now=time(e.now_utc),observed=time(o?.observation_utc);
  const origin=frame.data.requests[j.submission_key].receipt;
  if(!o||now===null||observed===null||time(e.observed_utc)===null||observed<time(e.observed_utc)||observed>now||
   o.job_id!==j.job_id||o.binding_sha256!==j.binding_sha256||o.request_sha256!==origin.request_sha256||
   o.stage!==j.stage||o.index!==j.index||o.current!==true||!digest(o.evidence_sha256)||
   !['PROVEN_RUNNING','PROVEN_TERMINAL'].includes(o.identity)||!digest(o.checkpoint_sha256))return null;
  return clone(o);
 }
 function current(j,frame){
  const o=evidence(j,frame);
  let protocol=j.phase;
  if(j.phase==='DISPATCH_INTENT'||j.phase==='RESUME_INTENT')protocol='RECONCILE_REQUIRED';
  if(j.phase==='PAUSE_REQUESTED'&&o?.identity==='PROVEN_TERMINAL'&&o.stage_complete===true)protocol='PAUSED_AFTER_STAGE';
  return {protocol_state:protocol,execution_state:o?.identity||'UNKNOWN',
   reason:o?'QUALIFIED_SYNTHETIC_OBSERVATION':'CURRENT_IDENTITY_UNPROVEN',
   evidence_kind:'SYNTHETIC_FIXTURE',job_id:j.job_id,stage:j.stage,index:j.index,
   checkpoint_sha256:o?.checkpoint_sha256??null,progress:'UNKNOWN',runtime_supported:false};
 }
 function result(record,j,frame){return {receipt:clone(record.receipt),receipt_sha256:record.receipt_sha256,current:current(j,frame)};}
 function reconcile(j,frame){
  if(['DISPATCH_INTENT','RESUME_INTENT'].includes(j.phase)&&evidence(j,frame)){
   j.phase='BOUND';j.intent_key=null;save(frame,'reconcile');
  }
 }
 function consumer(){
  if(stageConsumer?.kind!=='SYNTHETIC_FIXTURE'||stageConsumer.qualified!==true)refuse('UNSUPPORTED_STAGE_CONSUMER');
 }
 function dispatch(j,frame,key,resume=false){
  consumer();
  j.phase=resume?'RESUME_INTENT':'DISPATCH_INTENT';j.intent_key=key;save(frame,'intent');
  store.checkpoint('before_dispatch');
  // Fixture counter/record only. This module ships no adapter capable of launching.
  stageConsumer.dispatch({job_id:j.job_id,stage:j.stage,index:j.index,binding_sha256:j.binding_sha256,
   request_sha256:frame.data.requests[j.submission_key].receipt.request_sha256});
  store.checkpoint('after_dispatch');
  if(!evidence(j,frame))return;
  j.phase='BOUND';j.intent_key=null;save(frame,'ack');
 }
 function run(operation,bytes){
  return store.withLock(()=>{
   const e=env(),r=validate(bytes,e,operation),frame=load();
   const existing=frame.data.requests[r.idempotency_key];
   if(existing){
    if(!Buffer.from(existing.bytes_base64,'base64').equals(bytes))refuse('IDEMPOTENCY_DRIFT');
    const j=frame.data.jobs[existing.receipt.job_id];
    if(j.phase==='PREPARED'&&j.submission_key===r.idempotency_key){
     if(observer.observe(j.job_id)!==null)refuse('DUPLICATE_EXECUTION');
     dispatch(j,frame,r.idempotency_key);
    }else reconcile(j,frame);
    return result(existing,j,frame);
   }
   if(Object.values(frame.data.requests).some(x=>x.receipt.request_id===r.request_id))refuse('REQUEST_ID_REUSE');
   const bind=bindingHash(r);let j;
   if(operation==='submit_existing_contract_job'){
    consumer();
    // Conservative: one admitted execution per lane+contract binding; never automatic rerun.
    if(Object.values(frame.data.jobs).some(x=>x.binding_sha256===bind)||observer.findExisting(bind)!==null)refuse('DUPLICATE_EXECUTION');
    const jobId='jc-'+hash(r.lane_id+'\0'+r.idempotency_key).slice(0,40);
    j={job_id:jobId,binding_sha256:bind,submission_key:r.idempotency_key,latest_key:r.idempotency_key,
     stage:r.checkpoint.stage,index:0,phase:'PREPARED',intent_key:null,checkpoint_sha256:null};
   }else{
    j=frame.data.jobs[r.checkpoint.target_job_id];
    if(!j||j.binding_sha256!==bind)refuse('UNKNOWN_JOB');
    const latest=frame.data.requests[j.latest_key];
    if(latest.receipt_sha256!==r.checkpoint.parent_receipt_sha256)refuse('STALE_RECEIPT');
    const o=evidence(j,frame);if(!o)refuse('CURRENT_IDENTITY_UNPROVEN');
    if(o.checkpoint_sha256!==r.checkpoint.sha256)refuse('CHECKPOINT_MISMATCH');
    if(operation==='resume_existing_job'){
     consumer();
     if(current(j,frame).protocol_state!=='PAUSED_AFTER_STAGE'||r.checkpoint.index!==j.index+1||
      e.remaining_retry!==r.budget.retry||e.remaining_repair!==r.budget.repair)refuse('RESUME_REFUSED');
    }else{
     if(r.checkpoint.stage!==j.stage||r.checkpoint.index!==j.index)refuse('CHECKPOINT_MISMATCH');
     if(operation==='request_pause_after_stage'){
      consumer();if(j.phase!=='BOUND'||o.identity!=='PROVEN_RUNNING')refuse('PAUSE_REFUSED');
     }
     if(operation==='adopt_existing_job'&&!['BOUND','PAUSE_REQUESTED'].includes(j.phase))refuse('ADOPTION_UNPROVEN');
    }
   }
   const p={schema:'LNWJUD_JOB_CONTROL_RECEIPT_V1',evidence_kind:'SYNTHETIC_FIXTURE',
    request_id:r.request_id,idempotency_key:r.idempotency_key,request_sha256:hash(bytes),request_bytes:bytes.length,
    job_id:j.job_id,binding_sha256:bind,operation,created_utc:r.created_utc,
    prepared_revision:frame.data.revision+1,parent_receipt_sha256:r.checkpoint.parent_receipt_sha256};
   const record={bytes_base64:bytes.toString('base64'),receipt:p,receipt_sha256:hash(stable(p))};
   frame.data.requests[r.idempotency_key]=record;frame.data.jobs[j.job_id]=j;
   j.latest_key=r.idempotency_key;
   if(operation==='request_pause_after_stage')j.phase='PAUSE_REQUESTED';
   if(operation==='resume_existing_job'){
    // Persist a resume intent in the SAME atomic update as its immutable request.
    // Never leave a replayable resume PREPARED state that might redispatch.
    j.stage=r.checkpoint.stage;j.index=r.checkpoint.index;j.phase='RESUME_INTENT';j.intent_key=r.idempotency_key;
   }
   if(operation!=='submit_existing_contract_job')j.checkpoint_sha256=r.checkpoint.sha256;
   save(frame,'prepared');
   if(operation==='submit_existing_contract_job')dispatch(j,frame,r.idempotency_key);
   if(operation==='resume_existing_job'){
    store.checkpoint('before_dispatch');
    stageConsumer.dispatch({job_id:j.job_id,stage:j.stage,index:j.index,binding_sha256:bind,
     request_sha256:frame.data.requests[j.submission_key].receipt.request_sha256});
    store.checkpoint('after_dispatch');reconcile(j,frame);
   }
   return result(record,j,frame);
  });
 }
 const api=Object.fromEntries(C.OPS.map(operation=>[operation,bytes=>run(operation,bytes)]));
 api.get_job_current=key=>store.withLock(()=>{
  if(!id(key))refuse('INVALID_ID');
  const frame=load(),record=frame.data.requests[key];if(!record)refuse('UNKNOWN_RECEIPT');
  return result(record,frame.data.jobs[record.receipt.job_id],frame);
 });
 return Object.freeze(api);
}
module.exports={createJobControl};
