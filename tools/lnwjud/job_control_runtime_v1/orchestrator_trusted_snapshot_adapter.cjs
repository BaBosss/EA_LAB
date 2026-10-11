'use strict';
// Inert trusted-read-only *injected* snapshot boundary, not an I/O or crypto-authority provider.
// No filesystem, provider, process, HTTP, Registry mutation, runtime install or scheduler calls.
// The caller MUST supply actually trusted, scoped, authenticated read-only readers and verifier.
const {createHash}=require('node:crypto');
const R=require('../job_control_v1/request_contract.cjs');
const {reconcile}=require('./orchestrator_read_only_reconciler.cjs');
const TYPES=Object.freeze(['git','registry','leases','jobs','tasks']);
const OUTPUT='EA_LAB_ORCHESTRATOR_READ_ONLY_DECISION_V1';
const PROOF='EA_LAB_TRUSTED_SNAPSHOT_PROOF_V1';
const digest=b=>createHash('sha256').update(b).digest('hex');
const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x)&&Object.getPrototypeOf(x)===Object.prototype;
const id=x=>typeof x==='string'&&/^[A-Za-z][A-Za-z0-9._-]{2,127}$/.test(x);
const sha40=x=>typeof x==='string'&&/^[0-9a-f]{40}$/.test(x);
const sha64=x=>typeof x==='string'&&/^[0-9a-f]{64}$/.test(x);
const exact=(v,fields)=>object(v)&&Object.keys(v).sort().join('|')===[...fields].sort().join('|');
function utc(s){
 if(typeof s!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(s))return null;
 const n=Date.parse(s);
 return Number.isFinite(n)&&new Date(n).toISOString().slice(0,19)===s.slice(0,19)?n:null;
}
function unknown(code) {
 const item=Object.freeze({task_id:'UNVERIFIED',status:'UNKNOWN',reason:code});
 return Object.freeze({schema:OUTPUT,decisions:Object.freeze([item]),summary:Object.freeze({UNKNOWN:1})});
}
function fail(code){const e=new Error(code);e.code=code;throw e}
function createTrustedReadOnlyAdapter({readers,verifier,clock}={}){
 if(!object(readers)||!TYPES.every(x=>typeof readers[x]==='function')||
    Object.keys(readers).sort().join('|')!==TYPES.slice().sort().join('|'))
  throw new Error('UNQUALIFIED_READERS');
 if(!object(verifier)||typeof verifier.verify!=='function')throw new Error('UNQUALIFIED_VERIFIER');
 if(typeof clock!=='function')throw new Error('UNQUALIFIED_CLOCK');
 function assess(){
  try{
   const now=clock(),ms=utc(now);
   if(ms===null)fail('CLOCK_UNVERIFIED');
   const docs={};
   let canonical=null;
   for(const kind of TYPES){
    const frame=readers[kind]();
    if(!exact(frame,['bytes','proof'])||!Buffer.isBuffer(frame.bytes))fail('READER_FRAME_UNVERIFIED');
    const bytes=Buffer.from(frame.bytes);
    if(bytes.length===0||bytes.length>4*1024*1024)fail('SOURCE_BYTES_INVALID');
    const p=frame.proof;
    if(!exact(p,['schema','producer_id','source_type','source_head','source_tree',
         'sha256','captured_utc','attestation'])||p.schema!==PROOF||!id(p.producer_id)||
       p.source_type!==kind||!sha40(p.source_head)||!sha40(p.source_tree)||
       !sha64(p.sha256)||p.sha256!==digest(bytes)||typeof p.attestation!=='string'||
       p.attestation.length<8||p.attestation.length>2048)fail('SOURCE_PROOF_MALFORMED');
    const when=utc(p.captured_utc);
    if(when===null||when>ms||ms-when>15*60*1000)fail('SOURCE_PROOF_STALE_OR_FUTURE');
    // No "VERIFIED" flags from payload are accepted as attestation; the independent
    // verifier MUST recheck proof using a privileged producer trust anchor.
    const verdict=verifier.verify(Object.freeze({
      source_type:kind,bytes:Buffer.from(bytes),proof:Object.freeze({...p}),now_utc:now
    }));
    if(verdict!==true)fail('ATTESTATION_NOT_AUTHENTICATED');
    if(digest(bytes)!==p.sha256)fail('SOURCE_MUTATED_AFTER_VERIFY');
    if(kind==='git') {
     let parsed;
     try{parsed=R.clone(R.parse(bytes))}catch{fail('STRICT_GIT_PARSE_REJECTED')}
     if(!exact(parsed,['head','tree','origin_master','ls_remote','checkout_head',
                        'checkout_tree','clean','captured_utc'])||
       ![parsed.head,parsed.tree,parsed.origin_master,parsed.ls_remote,
         parsed.checkout_head,parsed.checkout_tree].every(sha40)||
       parsed.head!==parsed.origin_master||parsed.head!==parsed.ls_remote||
       parsed.head!==parsed.checkout_head||parsed.tree!==parsed.checkout_tree||
       parsed.clean!==true||utc(parsed.captured_utc)===null||
       utc(parsed.captured_utc)>ms||ms-utc(parsed.captured_utc)>15*60*1000)
      fail('GIT_IDENTITY_UNPROVEN');
     canonical={head:parsed.head,tree:parsed.tree,when:parsed.captured_utc};
     docs.git=parsed;
    }else{
     if(!canonical||p.source_head!==canonical.head||p.source_tree!==canonical.tree)
       fail('CROSS_SOURCE_HEAD_TREE_UNBOUND');
     if(Math.abs(when-utc(canonical.when))>120000)fail('CROSS_SNAPSHOT_TIME_SKEW');
     let payload;
     try{payload=R.clone(R.parse(bytes))}catch{fail('STRICT_SOURCE_PARSE_REJECTED')}
     if(kind==='registry'){
      if(!exact(payload,['validated','main_ct_ids','lanes'])||payload.validated!==true||
        !Array.isArray(payload.main_ct_ids)||payload.main_ct_ids.length!==1||
        !id(payload.main_ct_ids[0])||!Array.isArray(payload.lanes))
       fail('REGISTRY_IDENTITY_UNPROVEN');
     }else if(!Array.isArray(payload))fail('SOURCE_COLLECTION_SCHEMA_INVALID');
     docs[kind]=payload;
    }
    if(p.source_head!==canonical.head||p.source_tree!==canonical.tree)
      fail('SOURCE_PROOF_CROSS_BINDING_INVALID');
   }
   // Parser and verifier are distinct requirements: even verified, syntactically
   // well-formed source rows still pass through the fail-closed pure reconciler.
   const result=reconcile({
    schema:'EA_LAB_ORCHESTRATOR_READ_ONLY_INPUT_V1',now_utc:now,
    source:docs.git,registry:docs.registry,leases:docs.leases,
    jobs:docs.jobs,tasks:docs.tasks
   });
   if(result?.schema!==OUTPUT||!Array.isArray(result.decisions))
     fail('RECONCILER_OUTPUT_INVALID');
   return result;
  }catch(error){
   const code=typeof error?.code==='string'&&/^[A-Z0-9_]+$/.test(error.code)
     ?error.code:'PROVENANCE_OR_READER_UNKNOWN';
   return unknown(code);
  }
 }
 return Object.freeze({assess});
}
module.exports={createTrustedReadOnlyAdapter};
