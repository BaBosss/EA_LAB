'use strict';
const crypto=require('node:crypto');
class Refusal extends Error{constructor(code,message=code){super(message);this.name='Refusal';this.code=code;}}
const refuse=(code,message)=>{throw new Refusal(code,message||code)};
const object=v=>v!==null&&typeof v==='object'&&!Array.isArray(v)&&Object.getPrototypeOf(v)===Object.prototype;
const id=v=>typeof v==='string'&&/^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(v);
const sha=v=>typeof v==='string'&&/^[0-9a-f]{40}$/.test(v);
const digest=v=>typeof v==='string'&&/^[0-9a-f]{64}$/.test(v);
const hash=v=>crypto.createHash('sha256').update(Buffer.isBuffer(v)?v:Buffer.from(String(v),'utf8')).digest('hex');
function stable(v){if(Array.isArray(v))return '['+v.map(stable).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+stable(v[k])).join(',')+'}';return JSON.stringify(v);}
function strict(o,keys){if(!object(o))refuse('MALFORMED_REQUEST');const got=Object.keys(o);if(got.length!==keys.length||got.some(k=>!keys.includes(k)))refuse('MALFORMED_REQUEST');}
const COMMON=['schema','request_id','idempotency_key','actor','contract_sha256','lane_id','expected_state','expected_head','created_utc'];
const MUTATION_KEYS=[...COMMON,'operation','resource_id','target_state'];
const READ_KEYS={lane:['lane_id'],resource:['resource_id']};
const SAFE_TRANSITIONS=new Set(['READY>RUNNING','WAITING>RUNNING','PAUSED>RUNNING','RUNNING>WAITING','RUNNING>PAUSED','RUNNING>BLOCKED','RUNNING>DONE','WAITING>BLOCKED','WAITING>DONE','PAUSED>BLOCKED','PAUSED>DONE']);
function time(v){const t=typeof v==='string'?Date.parse(v):NaN;return Number.isFinite(t)?t:null;}
function validateRead(kind,input){const keys=READ_KEYS[kind];if(!keys)refuse('UNSUPPORTED_OPERATION');strict(input,keys);const value=input[keys[0]];if(!id(value))refuse('INVALID_ID');return Object.freeze({...input});}
function validateMutation(input,nowUtc){strict(input,MUTATION_KEYS);if(input.schema!=='LNWJUD_RESOURCE_REGISTRY_REQUEST_V1')refuse('MALFORMED_REQUEST');
 if(!['request_resource_lease','release_resource_lease','request_lane_transition'].includes(input.operation))refuse('UNSUPPORTED_OPERATION');
 if(![input.request_id,input.idempotency_key,input.actor,input.lane_id].every(id)||!digest(input.contract_sha256)||!sha(input.expected_head))refuse('INVALID_IDENTITY');
 if(typeof input.expected_state!=='string'||typeof input.target_state!=='string')refuse('INVALID_STATE');
 const created=time(input.created_utc),now=time(nowUtc);if(created===null||now===null||created>now)refuse('INVALID_OR_FUTURE_TIME');
 if(input.resource_id!==null&&!id(input.resource_id))refuse('INVALID_RESOURCE');
 if(input.operation==='request_resource_lease'){if(!input.resource_id||input.target_state!=='RUNNING'||!['READY','WAITING','PAUSED'].includes(input.expected_state))refuse('LEASE_TRANSITION_REFUSED');}
 if(input.operation==='release_resource_lease'){if(!input.resource_id||input.expected_state!=='RUNNING'||!['WAITING','PAUSED'].includes(input.target_state))refuse('LEASE_TRANSITION_REFUSED');}
 if(input.operation==='request_lane_transition'){
   if(input.resource_id!==null)refuse('RESOURCE_FIELD_NOT_ALLOWED');
   if(!SAFE_TRANSITIONS.has(input.expected_state+'>'+input.target_state))refuse('TRANSITION_NOT_ALLOWED');
 }
 return Object.freeze(JSON.parse(JSON.stringify(input)));
}
module.exports={Refusal,refuse,object,id,sha,digest,hash,stable,strict,time,SAFE_TRANSITIONS,validateRead,validateMutation};
