'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {createTrustedReadOnlyAdapter}=require('./orchestrator_trusted_snapshot_adapter.cjs');
const H='a'.repeat(40),T='b'.repeat(40),Z='2026-10-11T10:00:00Z',CAP='2026-10-11T09:59:00Z';
const hash=b=>createHash('sha256').update(b).digest('hex');
const clone=x=>JSON.parse(JSON.stringify(x));
const t=(id='aa1',o={})=>({task_id:id,lane_id:'lane-'+id,owner:'worker-'+id,stage:'DISPATCH',action:'SOURCE_TEST',
 source_head:H,source_tree:T,worktree:'D:\\src\\'+id,resources:['resource-'+id],
 dependency_ids:[],idempotency_key:'idem-'+id,repair_remaining:0,
 author_id:'worker-'+id,reviewer_id:'reader-'+id,provider:null,review:null,test_receipt:null,...o});
const proof=(kind,b)=>({schema:'EA_LAB_TRUSTED_SNAPSHOT_PROOF_V1',producer_id:'read-'+kind,
 source_type:kind,source_head:H,source_tree:T,sha256:hash(b),captured_utc:CAP,attestation:'signed-sample-'+kind});
function env(tasks=[t()]){
 const docs={
  git:{head:H,tree:T,origin_master:H,ls_remote:H,checkout_head:H,checkout_tree:T,clean:true,captured_utc:CAP},
  registry:{validated:true,main_ct_ids:['single-main-ct'],lanes:tasks.map(x=>({lane_id:x.lane_id,owner:x.owner,state:'READY',
   worktree:x.worktree,critical_paths:['D:/src/'+x.task_id+'/file.cjs']}))},
  leases:tasks.flatMap(x=>x.resources.map(resource=>({resource,owner:x.owner,lease_id:'lease-'+resource,
   expires_utc:'2026-10-11T10:10:00Z',receipt:{data:{resource,owner:x.owner,lease_id:'lease-'+resource,source_head:H},
   sha256:hash(JSON.stringify({resource,owner:x.owner,lease_id:'lease-'+resource,source_head:H}))}}))),
  jobs:[],tasks
 };
 const state={docs,corrupt:{},verified:new Set(),seen:[],now:Z};
 function pack(k){
  if(state.corrupt[k]?.missing)throw Error('READER_NOT_AVAILABLE');
  const raw=state.corrupt[k]?.raw!==undefined?state.corrupt[k].raw:JSON.stringify(state.docs[k]);
  const bytes=Buffer.from(raw,'utf8');
  const p=proof(k,bytes);
  Object.assign(p,state.corrupt[k]?.proof||{});
  return {bytes,proof:p};
 }
 const readers=Object.fromEntries(Object.keys(docs).map(k=>[k,()=>pack(k)]));
 const verifier={verify:({source_type,bytes,proof:p})=>{
  state.seen.push(source_type);
  return !state.corrupt[source_type]?.rejectVerification&&
   p.attestation==='signed-sample-'+source_type&&p.producer_id==='read-'+source_type&&
   bytes.equals(Buffer.from(state.corrupt[source_type]?.raw!==undefined?state.corrupt[source_type].raw:JSON.stringify(state.docs[source_type])));
 }};
 return {state,readers,verifier};
}
const run=e=>createTrustedReadOnlyAdapter({readers:e.readers,verifier:e.verifier,clock:()=>e.state.now}).assess();
const get=e=>run(e).decisions[0];
const ready=e=>{const v=get(e);assert.equal(v.status,'READY',JSON.stringify(v))};
const closed=e=>{const v=get(e);assert.notEqual(v.status,'READY',JSON.stringify(v))};
test('01 authenticated bounded five-sources READY',()=>{const e=env();ready(e);assert.equal(e.state.seen.length,5)});
test('02 no side effect: repeat assessment deterministic',()=>{const e=env();assert.deepEqual(run(e),run(e))});
test('03 missing Git reader remains UNKNOWN',()=>{const e=env();e.state.corrupt.git={missing:true};closed(e)});
test('04 missing Registry reader remains UNKNOWN',()=>{const e=env();e.state.corrupt.registry={missing:true};closed(e)});
test('05 missing lease reader never invents availability',()=>{const e=env();e.state.corrupt.leases={missing:true};closed(e)});
test('06 missing process reader never clears job',()=>{const e=env();e.state.corrupt.jobs={missing:true};closed(e)});
test('07 missing task reader does not invent READY',()=>{const e=env();e.state.corrupt.tasks={missing:true};closed(e)});
test('08 verifier rejects attestation',()=>{const e=env();e.state.corrupt.registry={rejectVerification:true};closed(e)});
test('09 forged checksum blocked',()=>{const e=env();e.state.corrupt.leases={proof:{sha256:'0'.repeat(64)}};closed(e)});
test('10 forged issuer blocked even with correct hash',()=>{const e=env();e.state.corrupt.jobs={proof:{producer_id:'impostor'}};closed(e)});
test('11 cross-bound foreign source blocked',()=>{const e=env();e.state.corrupt.tasks={proof:{source_head:'c'.repeat(40)}};closed(e)});
test('12 stale proof time blocked',()=>{const e=env();e.state.corrupt.git={proof:{captured_utc:'2026-10-11T09:40:00Z'}};closed(e)});
test('13 future proof time blocked',()=>{const e=env();e.state.corrupt.tasks={proof:{captured_utc:'2026-10-11T10:00:01Z'}};closed(e)});
test('14 bad timezone offset blocked',()=>{const e=env();e.state.corrupt.git={proof:{captured_utc:'2026-10-11T16:59:00+07:00'}};closed(e)});
test('15 duplicate JSON keys rejected by strict parser',()=>{const e=env();e.state.corrupt.tasks={raw:'{"x":1,"x":2}'};closed(e)});
test('16 unexpected JSON schema fields cannot be trusted',()=>{const e=env();e.state.docs.git.extra='oops';closed(e)});
test('17 corrupt UTF-8/invalid bytes rejected',()=>{const e=env();e.state.corrupt.jobs={raw:'{"message":"\\ud800"}'};closed(e)});
test('18 Git origin head mismatch blocked',()=>{const e=env();e.state.docs.git.ls_remote='d'.repeat(40);closed(e)});
test('19 dirty worktree blocked',()=>{const e=env();e.state.docs.git.clean=false;closed(e)});
test('20 Registry validation missing blocked',()=>{const e=env();e.state.docs.registry.validated=false;closed(e)});
test('21 duplicate CT is blocked',()=>{const e=env();e.state.docs.registry.main_ct_ids.push('second-main-ct');closed(e)});
test('22 foreign or stale lease blocked',()=>{const e=env();e.state.docs.leases[0].owner='intruder';closed(e)});
test('23 expired lease blocked',()=>{const e=env();e.state.docs.leases[0].expires_utc='2026-10-11T09:59:30Z';closed(e)});
test('24 process PID unknown blocked when job observed',()=>{const e=env();e.state.docs.jobs.push({job_id:'job-aa1',task_id:'aa1',lane_id:'lane-aa1',source_head:H,
 state:'RUNNING',identity:{pid:null,creation_utc:null}});closed(e)});
test('25 duplicate resource request blocks contenders',()=>{const e=env([t(),t('bb2',{resources:['resource-aa1']})]);for(const q of run(e).decisions)assert.notEqual(q.status,'READY')});
test('26 duplicate task identity blocked',()=>{const e=env([t(),t('aa1')]);closed(e)});
test('27 repair budget exhausted blocked',()=>{const e=env([t('aa1',{action:'RETRY',repair_remaining:0})]);closed(e)});
test('28 author reviewer same blocked',()=>{const e=env([t('aa1',{reviewer_id:'worker-aa1'})]);closed(e)});
test('29 uncapped provider blocked',()=>{const e=env([t('aa1',{provider:{name:'Gemini',model:'gemini-high',auth:'VERIFIED',cost_ceiling_usd:null}})]);closed(e)});
test('30 forbidden MT5 and runtime activation blocked',()=>{const e=env([t('aa1',{action:'T3_RUNTIME_INSTALL'})]);closed(e)});
test('31 independent EA READY if SYSTEM T3 blocked',()=>{const e=env([t('sys',{action:'T3_DEPLOY'}),t('ea2')]);const a=run(e).decisions;assert.equal(a[0].status,'BLOCKED');assert.equal(a[1].status,'READY')});
test('32 missing dependent job blocked, sibling ready',()=>{const e=env([t('aa1',{dependency_ids:['missing']}),t('bb2')]);const a=run(e).decisions;assert.notEqual(a[0].status,'READY');assert.equal(a[1].status,'READY')});
test('33 exception from producer does not dispatch',()=>{const e=env();e.readers.git=()=>{throw Error('DOWN')};closed(e)});
test('34 missing verifier blocked',()=>{const e=env();assert.throws(()=>createTrustedReadOnlyAdapter({readers:e.readers,clock:()=>Z}),/UNQUALIFIED_VERIFIER/)});
test('35 invalid source clock fails closed',()=>{const e=env();e.state.now='2026-02-30T10:00:00Z';closed(e)});
test('36 extra proof property denied',()=>{const e=env();e.state.corrupt.git={proof:{unexpected:true}};closed(e)});
test('37 digest replay with mutated payload denied',()=>{const e=env();e.state.docs.tasks[0].lane_id='lane-other';closed(e)});
test('38 stale producer observed time against current clock blocked',()=>{const e=env();e.state.now='2026-10-11T10:20:00Z';closed(e)});
test('39 unknown JSON value type blocked',()=>{const e=env();e.state.corrupt.registry={raw:'[1,2,3]'};closed(e)});
test('40 contradictory required owner blocked',()=>{const e=env();e.state.docs.registry.lanes[0].owner='foreign';closed(e)});
