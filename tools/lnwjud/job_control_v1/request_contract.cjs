'use strict';
const crypto=require('node:crypto');
const {TextDecoder}=require('node:util');
class Refusal extends Error { constructor(code){super(code);this.code=code;} }
const refuse=code=>{throw new Refusal(code);};
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const stable=v=>JSON.stringify(v,(_,x)=>x&&typeof x==='object'&&!Array.isArray(x)?
 Object.fromEntries(Object.keys(x).sort().map(k=>[k,x[k]])):x);
const clone=x=>JSON.parse(JSON.stringify(x));
const id=x=>typeof x==='string'&&/^[A-Za-z][A-Za-z0-9._-]{2,79}$/.test(x);
const digest=x=>typeof x==='string'&&/^[a-f0-9]{64}$/.test(x);
const head=x=>typeof x==='string'&&/^[a-f0-9]{40}$/.test(x);
function time(v){
 if(typeof v!=='string')return null;
 const m=/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})(?:\.(\d{1,7}))?Z$/.exec(v);
 if(!m)return null;
 const n=Date.parse(m[1]+'T'+m[2]+'Z');
 if(!Number.isFinite(n)||new Date(n).toISOString().slice(0,19)!==m[1]+'T'+m[2])return null;
 return BigInt(n)*10000n+BigInt((m[3]||'').padEnd(7,'0')||'0');
}
function keys(o,names){
 if(!o||typeof o!=='object'||Array.isArray(o)||stable(Object.keys(o).sort())!==stable([...names].sort()))refuse('MALFORMED_SCHEMA');
}
// Duplicate keys must be rejected before conversion; raw bytes remain idempotency identity.
function parse(bytes,max=65536){
 if(!Buffer.isBuffer(bytes)||bytes.length===0||bytes.length>max)refuse('INVALID_REQUEST_BYTES');
 let s;try{s=new TextDecoder('utf-8',{fatal:true,ignoreBOM:true}).decode(bytes);}catch{refuse('INVALID_UTF8');}
 let i=0;const ws=()=>{while(/[ \t\r\n]/.test(s[i]||'!'))i++;};
 function str(){
  const start=i++;let escaped=false;
  while(i<s.length){const c=s[i++];if(!escaped&&c==='"'){try{return JSON.parse(s.slice(start,i));}catch{refuse('MALFORMED_JSON');}}
   if(!escaped&&c==='\\')escaped=true;else escaped=false;}
  refuse('MALFORMED_JSON');
 }
 function value(depth){
  if(depth>24)refuse('JSON_DEPTH');ws();const c=s[i];
  if(c==='"')return str();
  if(c==='{'){
   i++;ws();const out=Object.create(null),seen=new Set();if(s[i]==='}'){i++;return out;}
   while(i<s.length){ws();if(s[i]!=='"')refuse('MALFORMED_JSON');const k=str();
    if(seen.has(k)||['__proto__','constructor','prototype'].includes(k))refuse('DUPLICATE_OR_UNSAFE_KEY');
    seen.add(k);ws();if(s[i++]!==':')refuse('MALFORMED_JSON');out[k]=value(depth+1);ws();
    const next=s[i++];if(next==='}')return out;if(next!==',')refuse('MALFORMED_JSON');
   }
  }else if(c==='['){
   i++;ws();const out=[];if(s[i]===']'){i++;return out;}
   while(i<s.length){out.push(value(depth+1));ws();const next=s[i++];if(next===']')return out;if(next!==',')refuse('MALFORMED_JSON');}
  }else{
   const m=/^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/.exec(s.slice(i));
   if(m){i+=m[0].length;const x=JSON.parse(m[0]);if(typeof x==='number'&&(!Number.isFinite(x)||!Number.isSafeInteger(x)))refuse('UNSAFE_NUMBER');return x;}
  }
  refuse('MALFORMED_JSON');
 }
 const result=value(0);ws();if(i!==s.length)refuse('MALFORMED_JSON');return result;
}
function abs(v){
 if(typeof v!=='string'||v.trim()!==v||/[\x00-\x1f*?"<>|]/.test(v))return false;
 const n=v.replaceAll('/','\\');if(!/^[A-Za-z]:\\/.test(n))return false;
 const parts=n.slice(3).split('\\');if(parts.at(-1)==='')parts.pop();
 return parts.every(c=>c&&c!=='.'&&c!=='..'&&!c.includes(':')&&!/[. ]$/.test(c)&&
 !/^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)/i.test(c));
}
function relative(v){
 return typeof v==='string'&&v.length>0&&!v.includes('\\')&&!v.includes(':')&&!v.startsWith('/')&&
 v.split('/').every(c=>c&&c!=='.'&&c!=='..'&&!/[. ]$/.test(c)&&!/[?*<>"|\x00-\x1f]/.test(c));
}
const OPS=['submit_existing_contract_job','adopt_existing_job','request_pause_after_stage','resume_existing_job'];
const BOUND=['lane_id','contract_id','contract_sha256','source','allowlisted_paths','worktree','resource_owner','acceptance_criteria','budget','direct_consumer','route','runtime_resource','host_id'];
function bindingHash(r){return hash(stable(Object.fromEntries(BOUND.map(k=>[k,r[k]]))));}
function validate(bytes,env,operation){
 const r=parse(bytes);
 keys(r,['schema','request_id','idempotency_key','operation',...BOUND,'checkpoint','created_utc']);
 if(r.schema!=='LNWJUD_JOB_CONTROL_REQUEST_V1'||!OPS.includes(r.operation)||r.operation!==operation)refuse('UNSUPPORTED_OPERATION');
 if(!id(r.request_id)||!id(r.idempotency_key)||!id(r.lane_id)||!id(r.contract_id))refuse('INVALID_ID');
 const now=time(env.now_utc),created=time(r.created_utc),observed=time(env.observed_utc);
 if(now===null||created===null||observed===null||created>now||observed<created||observed>now)refuse('INVALID_OR_FUTURE_TIME');
 if(!env.binding||env.binding.lane_id!==r.lane_id)refuse('UNKNOWN_LANE');
 if(!Buffer.isBuffer(env.contract_bytes))refuse('MISSING_CONTRACT');
 if(!digest(r.contract_sha256)||hash(env.contract_bytes)!==r.contract_sha256)refuse('CONTRACT_MISMATCH');
 keys(r.source,['head','tree','config_sha256']);
 if(!head(r.source.head)||!head(r.source.tree)||!digest(r.source.config_sha256))refuse('WRONG_SOURCE');
 if(stable(r.source)!==stable(env.binding.source))refuse('WRONG_SOURCE');
 keys(r.worktree,['path','branch','git_common_root','identity_sha256']);
 if(!abs(r.worktree.path)||!abs(r.worktree.git_common_root)||typeof r.worktree.branch!=='string'||
 !/^[A-Za-z0-9._/-]+$/.test(r.worktree.branch)||r.worktree.branch.includes('..')||!digest(r.worktree.identity_sha256))refuse('ARBITRARY_PATH');
 if(!Array.isArray(r.allowlisted_paths)||!r.allowlisted_paths.length||!r.allowlisted_paths.every(relative)||
 new Set(r.allowlisted_paths).size!==r.allowlisted_paths.length)refuse('ARBITRARY_PATH');
 if(env.clean!==true)refuse('DIRTY_WORKTREE');
 if(env.path_identity_verified!==true)refuse('PATH_IDENTITY_UNPROVEN');
 if(!Array.isArray(r.acceptance_criteria)||!r.acceptance_criteria.length||!r.acceptance_criteria.every(id))refuse('MISSING_ACCEPTANCE');
 keys(r.budget,['repair','retry']);
 if(!Number.isSafeInteger(r.budget.repair)||r.budget.repair<0||!Number.isSafeInteger(r.budget.retry)||r.budget.retry<0)refuse('INVALID_BUDGET');
 keys(r.route,['tool','provider']);
 if(r.route.tool!=='EXISTING_RUNNER'||r.route.provider!=='SYNTHETIC_FIXTURE')refuse('DISALLOWED_PROVIDER');
 if(!id(r.resource_owner)||!id(r.direct_consumer)||!id(r.host_id)||r.runtime_resource!=='NOT_APPLICABLE_OFFLINE')refuse('BINDING_MISMATCH');
 if(env.resource_owner!==r.resource_owner||env.resource_available!==true)refuse('LEASED_RESOURCE');
 for(const k of BOUND)if(stable(r[k])!==stable(env.binding[k]))refuse('BINDING_MISMATCH');
 keys(r.checkpoint,['stage','index','sha256','parent_receipt_sha256','target_job_id']);
 const q=r.checkpoint;
 if(!id(q.stage)||!Number.isSafeInteger(q.index)||q.index<0||!Array.isArray(env.stages)||env.stages[q.index]!==q.stage)refuse('INVALID_STAGE');
 if(operation==='submit_existing_contract_job'){
  if(q.index!==0||q.sha256!==null||q.parent_receipt_sha256!==null||q.target_job_id!==null)refuse('INVALID_CHECKPOINT');
 }else if(!digest(q.sha256)||!digest(q.parent_receipt_sha256)||!id(q.target_job_id))refuse('INVALID_CHECKPOINT');
 return clone(r);
}
module.exports={Refusal,refuse,hash,stable,clone,id,digest,time,parse,keys,abs,relative,OPS,BOUND,bindingHash,validate};
