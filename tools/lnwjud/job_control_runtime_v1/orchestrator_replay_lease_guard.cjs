'use strict';
// Inert replay/fencing decision boundary. Store and verifier are injected trusted
// interfaces: no filesystem, process, scheduler, secrets, broker, or network I/O.
// No production durability/atomicity guarantee can be inferred from these hooks.
const SCHEMA='EA_LAB_T3C_REPLAY_CAS_CLAIM_V1';
const RECORD='EA_LAB_T3C_REPLAY_CAS_RECORD_V1';
const CLAIM_FIELDS=['schema','source_head','source_tree','lane_id','task_id','resource',
 'owner','lease_id','lease_until_utc','sequence','idempotency_key','signed_proof_sha256','can_execute','can_submit'];
const RECORD_FIELDS=['schema','source_head','source_tree','lane_id','task_id','resource','owner',
 'lease_id','lease_until_utc','sequence','idempotency_key','signed_proof_sha256','can_execute','can_submit'];
const plain=x=>x!==null&&typeof x==='object'&&!Array.isArray(x)&&Object.getPrototypeOf(x)===Object.prototype;
const exact=(x,fields)=>plain(x)&&Object.keys(x).sort().join('|')===[...fields].sort().join('|');
const id=x=>typeof x==='string'&&/^[A-Za-z][A-Za-z0-9._-]{2,127}$/.test(x);
const hex40=x=>typeof x==='string'&&/^[0-9a-f]{40}$/.test(x);
const hex64=x=>typeof x==='string'&&/^[0-9a-f]{64}$/.test(x);
const ver=x=>typeof x==='string'&&/^v(?:0|[1-9][0-9]{0,17})$/.test(x);
function utc(s){
 if(typeof s!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(s))return null;
 const v=Date.parse(s);
 return Number.isFinite(v)&&new Date(v).toISOString().slice(0,19)===s.slice(0,19)?v:null;
}
function response(status,reason,version=null){
 return Object.freeze({schema:'EA_LAB_T3C_CAS_ADVISORY_V1',status,reason,version,can_execute:false,
  can_submit:false,scope:'EVIDENCE_RECORD_ONLY'});
}
function createReplayLeaseGuard({store,verifier,clock,source_head,source_tree}={}){
 if(!plain(store)||typeof store.read!=='function'||typeof store.compareAndSwap!=='function')
  throw new Error('STORE_UNQUALIFIED');
 if(!plain(verifier)||typeof verifier.verifyClaim!=='function')throw new Error('VERIFIER_UNQUALIFIED');
 if(typeof clock!=='function'||!hex40(source_head)||!hex40(source_tree))
  throw new Error('SOURCE_OR_CLOCK_UNQUALIFIED');
 function record(claim){
  try{
   const now=utc(clock());
   if(now===null)return response('UNKNOWN','CLOCK_UNKNOWN');
   if(!exact(claim,CLAIM_FIELDS)||claim.schema!==SCHEMA||!hex40(claim.source_head)||
      !hex40(claim.source_tree)||claim.source_head!==source_head||claim.source_tree!==source_tree||
      !id(claim.lane_id)||!id(claim.task_id)||!id(claim.resource)||!id(claim.owner)||
      !id(claim.lease_id)||!id(claim.idempotency_key)||!hex64(claim.signed_proof_sha256)||
      !Number.isSafeInteger(claim.sequence)||claim.sequence<1||
      claim.can_execute!==false||claim.can_submit!==false)
    return response('BLOCKED','CLAIM_OR_SOURCE_INVALID');
   const until=utc(claim.lease_until_utc);
   if(until===null||until<=now||until-now>300000)
    return response('BLOCKED','LEASE_TIME_INVALID');
   // A verified claim is mandatory. The injected verifier is not authenticated
   // by this source; actual issuer trust/role and nonce freshness are T3-C gates.
   if(verifier.verifyClaim(Object.freeze({...claim}))!==true)
    return response('BLOCKED','SIGNED_CLAIM_NOT_QUALIFIED');
   const original=store.read(claim.resource);
   if(!exact(original,['version','record'])||!ver(original.version))
    return response('UNKNOWN','STORE_READ_UNVERIFIED');
   const prior=original.record;
   if(prior!==null){
    if(!exact(prior,RECORD_FIELDS)||prior.schema!==RECORD||prior.resource!==claim.resource||
       !id(prior.owner)||!id(prior.lease_id)||!id(prior.idempotency_key)||
       !hex64(prior.signed_proof_sha256)||!hex40(prior.source_head)||
       !hex40(prior.source_tree)||!Number.isSafeInteger(prior.sequence)||
       prior.sequence<1||prior.can_execute!==false||prior.can_submit!==false||
       utc(prior.lease_until_utc)===null)
      return response('UNKNOWN','PREVIOUS_RECORD_UNVERIFIED');
    if(prior.source_head!==source_head||prior.source_tree!==source_tree)
      return response('UNKNOWN','STORED_CANONICAL_DRIFT');
    if(prior.idempotency_key===claim.idempotency_key||
       prior.signed_proof_sha256===claim.signed_proof_sha256)
      return response('BLOCKED','REPLAY_OR_DUPLICATE_PROOF');
    if(claim.sequence<=prior.sequence)
      return response('BLOCKED','SEQUENCE_NOT_MONOTONIC');
    if(prior.owner!==claim.owner&&utc(prior.lease_until_utc)>now)
      return response('WAITING_RESOURCE','FOREIGN_ACTIVE_LEASE');
    if(prior.owner===claim.owner && prior.lease_id!==claim.lease_id &&
       utc(prior.lease_until_utc)>now)
      return response('WAITING_RESOURCE','OWNER_CHANGED_ACTIVE_LEASE');
   }
   const next=Object.freeze({schema:RECORD,source_head,source_tree,
     lane_id:claim.lane_id,task_id:claim.task_id,resource:claim.resource,
     owner:claim.owner,lease_id:claim.lease_id,lease_until_utc:claim.lease_until_utc,
     sequence:claim.sequence,idempotency_key:claim.idempotency_key,
     signed_proof_sha256:claim.signed_proof_sha256,can_execute:false,can_submit:false});
   const result=store.compareAndSwap({
     key:claim.resource,expected_version:original.version,next_record:next});
   if(!exact(result,['applied','version'])||typeof result.applied!=='boolean'||!ver(result.version))
     return response('UNKNOWN','CAS_RESULT_UNVERIFIED');
   if(!result.applied)return response('WAITING_RESOURCE','CAS_CONTENTION',result.version);
   const readback=store.read(claim.resource);
   if(!exact(readback,['version','record'])||readback.version!==result.version||
      !exact(readback.record,RECORD_FIELDS)||
      JSON.stringify(readback.record)!==JSON.stringify(next))
     return response('UNKNOWN','CAS_READBACK_MISMATCH');
   return response('RECORDED_READ_ONLY','CAS_READBACK_MATCH',result.version);
  }catch{return response('UNKNOWN','OBSERVATION_OR_STORAGE_UNAVAILABLE')}
 }
 return Object.freeze({record});
}
module.exports={createReplayLeaseGuard};
