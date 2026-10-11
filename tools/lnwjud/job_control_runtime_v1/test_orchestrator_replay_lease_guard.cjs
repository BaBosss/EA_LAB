'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const {createReplayLeaseGuard}=require('./orchestrator_replay_lease_guard.cjs');
const H='a'.repeat(40),T='b'.repeat(40),Z='2026-10-11T12:00:00Z';
const base=()=>({schema:'EA_LAB_T3C_REPLAY_CAS_CLAIM_V1',source_head:H,source_tree:T,
 lane_id:'ct-a01',task_id:'task-a01',resource:'resource-a01',owner:'worker-a01',
 lease_id:'lease-a01',lease_until_utc:'2026-10-11T12:02:00Z',
 sequence:1,idempotency_key:'idem-a01',signed_proof_sha256:'c'.repeat(64),
 can_execute:false,can_submit:false});
function setup(){
 let state={version:'v0',record:null},count=0,crash=false;
 const store={
  read:()=>{if(crash)throw Error('DISK_UNAVAILABLE');return JSON.parse(JSON.stringify(state))},
  compareAndSwap:({key,expected_version,next_record})=>{
   count++;
   if(crash)throw Error('IOERR');
   if(key!=='resource-a01'&&key!=='resource-b01')return {applied:false,version:'v0'};
   if(state.version!==expected_version)return {applied:false,version:state.version};
   state={version:'v'+count,record:JSON.parse(JSON.stringify(next_record))};
   return {applied:true,version:state.version};
  }};
 const verifier={verifyClaim:()=>true};
 const guard=()=>createReplayLeaseGuard({store,verifier,clock:()=>Z,source_head:H,source_tree:T});
 return {store,verifier,guard,state:()=>state,fail:()=>{crash=true},change:x=>{state=x},count:()=>count};
}
const run=(e,c=base())=>e.guard().record(c);
test('01 valid evidence records advisory only',()=>{const e=setup(),r=run(e);a.equal(r.status,'RECORDED_READ_ONLY');a.equal(r.can_execute,false);a.equal(e.count(),1)});
test('02 duplicate exact idempotency rejected',()=>{const e=setup();run(e);a.equal(run(e).status,'BLOCKED')});
test('03 no process/scheduler/resource owner mutation by module',()=>{const e=setup();const x=run(e);a.equal(x.can_submit,false);a.equal(x.scope,'EVIDENCE_RECORD_ONLY')});
const fail=(name,change,expected='BLOCKED')=>test(name,()=>{
 const e=setup(),c=base();change(e,c);a.equal(run(e,c).status,expected)
});
fail('04 forbidden can execute',(_e,c)=>{c.can_execute=true});
fail('05 forbidden can submit',(_e,c)=>{c.can_submit=true});
fail('06 wrong head',(_e,c)=>{c.source_head='d'.repeat(40)});
fail('07 wrong tree',(_e,c)=>{c.source_tree='d'.repeat(40)});
fail('08 malformed proof sha',(_e,c)=>{c.signed_proof_sha256='not-a-hash'});
fail('09 no signed identity',e=>{e.verifier.verifyClaim=()=>false});
fail('10 truthy string never grants attestation',e=>{e.verifier.verifyClaim=()=> 'true'});
fail('11 unknown issuer exception',e=>{e.verifier.verifyClaim=()=>{throw Error('NO_KEY')}},'UNKNOWN');
fail('12 sequence zero',(_e,c)=>{c.sequence=0});
fail('13 missing lease id',(_e,c)=>{c.lease_id=null});
fail('14 expired lease',(_e,c)=>{c.lease_until_utc='2026-10-11T11:59:59Z'});
fail('15 huge lease ttl',(_e,c)=>{c.lease_until_utc='2026-10-11T12:25:00Z'});
fail('16 timestamp offset refused',(_e,c)=>{c.lease_until_utc='2026-10-11T19:02:00+07:00'});
fail('17 extra claim field refused',(_e,c)=>{c.owner_verified=true});
fail('18 missing resource refused',(_e,c)=>{delete c.resource});
fail('19 prototype pollution rejected',(_e,c)=>{c.__proto__={x:true}});
fail('20 invalid task identity',(_e,c)=>{c.task_id='a'.repeat(200)});
test('21 conflicting live resource owner waits',()=>{const e=setup();a.equal(run(e).status,'RECORDED_READ_ONLY');const c={...base(),owner:'other-actor',lease_id:'lease-a02',sequence:2,idempotency_key:'idem-a02',signed_proof_sha256:'d'.repeat(64)};a.equal(run(e,c).status,'WAITING_RESOURCE')});
test('22 sequence regression blocked',()=>{const e=setup();run(e);const c={...base(),sequence:1,idempotency_key:'idem-a02'};a.equal(run(e,c).status,'BLOCKED')});
test('23 monotonically new same owner accepted',()=>{const e=setup();run(e);const c={...base(),sequence:2,idempotency_key:'idem-a02',signed_proof_sha256:'d'.repeat(64)};a.equal(run(e,c).status,'RECORDED_READ_ONLY')});
test('24 stale signed proof digest replay rejected',()=>{const e=setup();run(e);const c={...base(),sequence:2,idempotency_key:'idem-a02'};a.equal(run(e,c).status,'BLOCKED')});
test('25 arbitrary CAS version mismatch fails closed',()=>{const e=setup();const orig=e.store.compareAndSwap;e.store.compareAndSwap=()=>({applied:false,version:'v999'});a.equal(run(e).status,'WAITING_RESOURCE')});
test('26 CAS lies about readback must fail closed',()=>{const e=setup();e.store.compareAndSwap=()=>({applied:true,version:'v1'});a.equal(run(e).status,'UNKNOWN')});
test('27 corrupted stored record fails closed',()=>{const e=setup();e.change({version:'v4',record:{garbage:true}});a.equal(run(e).status,'UNKNOWN')});
test('28 storage unavailable fails closed',()=>{const e=setup();e.fail();a.equal(run(e).status,'UNKNOWN')});
test('29 missing store blocked at construction',()=>{a.throws(()=>createReplayLeaseGuard({verifier:{verifyClaim:()=>true},clock:()=>Z,source_head:H,source_tree:T}),/STORE_UNQUALIFIED/)});
test('30 missing verifier blocked at construction',()=>{const e=setup();a.throws(()=>createReplayLeaseGuard({store:e.store,clock:()=>Z,source_head:H,source_tree:T}),/VERIFIER_UNQUALIFIED/)});
test('31 actual two contenders cannot both win same version',()=>{
 const e=setup(),r=e.store.read('resource-a01'),c=base();
 const guard=e.guard();a.equal(guard.record(c).status,'RECORDED_READ_ONLY');
 a.equal(e.store.compareAndSwap({key:'resource-a01',expected_version:r.version,next_record:r.record}).applied,false);
});
test('32 recorded snapshot matches version and owner',()=>{const e=setup();run(e);a.equal(e.state().record.owner,'worker-a01');a.equal(e.state().version,'v1')});
test('33 post-CAS readback mismatch returns UNKNOWN',()=>{const e=setup(),orig=e.store.read;let reads=0;e.store.read=(key)=>{reads++;return reads===1?orig(key):({version:'v4',record:null})};a.equal(run(e).status,'UNKNOWN')});
test('34 failed readback refuses retry without fresh observation',()=>{const e=setup();e.store.compareAndSwap=()=>{throw Error('UNCERTAIN_COMMIT')};a.equal(run(e).status,'UNKNOWN')});
test('35 invalid time blocks',()=>{const e=setup(),v=createReplayLeaseGuard({store:e.store,verifier:e.verifier,clock:()=> '2026-02-30T12:00:00Z',source_head:H,source_tree:T});a.equal(v.record(base()).status,'UNKNOWN')});
test('36 distinct provider/job can never acquire trading rights via evidence',()=>{const e=setup();const r=run(e);a.equal(r.can_execute,false);a.equal(r.can_submit,false)});
test('37 source tree excludes external installed runtime',()=>{const e=setup();a.equal(run(e).scope,'EVIDENCE_RECORD_ONLY')});
