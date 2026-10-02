'use strict';
const assert=require('node:assert/strict');
const T=require('./truth.js');
let passed=0;
function test(name,fn){fn();passed++;console.log('PASS '+name);}
const now=Date.parse('2026-09-24T00:00:00Z');
test('null, blank, boolean, arrays and nonfinite are not numeric zero',()=>{
 for(const v of [null,undefined,'',' ','0',false,true,[],{},NaN,Infinity])assert.equal(T.number(v),null);
 assert.equal(T.number(0),0);assert.equal(T.number(-4.5),-4.5);
});
test('Z and explicit offsets identify the same instant',()=>{
 assert.equal(T.timestamp('2026-09-24T07:00:00+07:00'),now);
 assert.equal(T.timestamp('2026-09-23T19:00:00-05:00'),now);
 assert.equal(T.timestamp('2026-09-24T00:00:00.123456Z'),now+123);
});
test('strict timezone and calendar negatives',()=>{
 for(const v of [null,{},[],true,'2026-09-24','2026-09-24T00:00:00','2026-02-29T00:00:00Z','2026-02-30T00:00:00Z','2026-09-24T24:00:00Z','2026-09-24T00:00:60Z','2026-09-24T00:00:00+24:00','2026-09-24T00:00:00+07:99','2026-09-24X00:00:00Z'])assert.equal(T.timestamp(v),null,String(v));
 assert.notEqual(T.timestamp('2024-02-29T00:00:00Z'),null);
});
test('freshness ages and any future timestamp is disqualified',()=>{
 assert.equal(T.freshness('2026-09-24T00:00:00Z',now).state,'CURRENT');
 assert.equal(T.freshness('2026-09-24T00:00:00Z',now+27*36e5).state,'STALE');
 assert.equal(T.freshness('2026-09-24T00:00:01Z',now).state,'FUTURE');
});
test('missing invalid and timezone-unqualified projection are never zero findings',()=>{
 for(const s of [{status:'MISSING'},{status:'INVALID'},{status:'AVAILABLE',generated_at:'2026-09-24T00:00:00',findings:[]}]){
   const v=T.view({schema:'ea-lab-owner-view/1',safe_projection:s},now);
   assert.equal(v.finding_count,null);assert.equal(v.safe_projection.status,s.status);
 }
 assert.equal(T.view({schema:'ea-lab-owner-view/1',safe_projection:{status:'AVAILABLE',generated_at:'2026-09-24T00:00:00Z',findings:[]}},now).finding_count,0);
});
test('source age is independent of transport and cannot be reset by repeated view',()=>{
 const raw={schema:'ea-lab-owner-view/1',observed_at:'2026-09-24T00:00:00Z',monitoring:{status:'CURRENT',sources:[],generated_at_utc:'2026-09-20T00:00:00Z'},transport:{cache_hit:false,cache_age_seconds:0}};
 for(const hit of [false,true]){raw.transport.cache_hit=hit;assert.equal(T.view(raw,now).source_freshness.state,'STALE');}
 assert.equal(T.view(raw,now+36e5).source_freshness.age_hours,97);
 assert.equal(raw.monitoring.freshness,undefined);
});
test('process observations expire without fabricated identity or progress',()=>{
 const raw={schema:'ea-lab-owner-view/1',work:{rows:[{updated_at:'2026-09-24T00:00:00Z',process_checked_utc:'2026-09-24T00:00:00Z',display_state:'ACTIVE_PROCESS',runner_alive:true,progress:100}]}};
 assert.equal(T.view(raw,now).work.rows[0].display_state,'OBSERVED_ACTIVE_PROCESS');
 const later=T.view(raw,now+31000).work.rows[0];assert.equal(later.runner_alive,null);assert.equal(later.process_state,'UNKNOWN');assert.equal(later.progress,'UNKNOWN');assert.equal(later.expected_process_start,undefined);
});
test('schema mismatch fails closed',()=>assert.equal(T.view({schema:'future',accounts:{rows:[{balance:0}]}},now).truth_error,'VERSION_MISMATCH'));
test('malformed monitoring source collections fail visible',()=>{
 for(const monitoring of [null,[],{}, {status:'CURRENT',sources:'bad'}, {status:'CURRENT',sources:[null]}, {status:'UNAVAILABLE',sources:[],generated_at_utc:'2026-09-24T00:00:00Z'}]){
   const v=T.view({schema:'ea-lab-owner-view/1',monitoring},now);
   assert.equal(v.monitoring.status,'UNAVAILABLE');assert.equal(v.source_freshness.state,'UNKNOWN');
 }
});
const captured='2026-09-24T00:00:00Z';
const processRow=(id='proof-live')=>({id,source_class:'LANE_REGISTRY',job_id:id+'-job',state:'RUNNING',
 freshness:'CURRENT',updated_at:captured,process_checked_utc:captured,process_freshness:'CURRENT',
 process_health:'ACTIVE',process_state:'RUNNING',runner_alive:true,child_alive:false,postcondition_alive:false,
 actual_live:true,bucket:'ACTUAL LIVE JOBS',display_state:'ACTIVE_PROCESS',progress:'UNKNOWN'});
const proofSnapshot=(rows=[processRow()],count=1)=>({schema:'ea-lab-owner-view/1',work:{status:'AVAILABLE',
 observed_at:captured,rows,process_probe_complete:true,process_eligible_count:rows.length,process_proven_count:rows.length,
 counts:{actual_live_jobs:count,by_bucket:{'ACTUAL LIVE JOBS':count}}}});
test('complete capture becomes unknown at display-time expiration without mutating RAW',()=>{
 const raw=proofSnapshot(),frozen=JSON.stringify(raw),fresh=T.view(raw,now+30000).work;
 assert.equal(fresh.process_probe_complete,true);assert.equal(fresh.counts.actual_live_jobs,1);
 for(const time of [now+30001,now+60000,now+25*36e5]){
  const aged=T.view(raw,time).work;assert.equal(aged.process_probe_complete,false);
  assert.equal(aged.counts.actual_live_jobs,null);assert.equal(aged.counts.by_bucket['ACTUAL LIVE JOBS'],null);
  assert.equal(aged.rows[0].actual_live,false);assert.equal(aged.rows[0].bucket,'HISTORICAL UNRESOLVED / UNKNOWN');
  assert.equal(aged.rows[0].runner_alive,null);assert.equal(aged.rows[0].progress,'UNKNOWN');
  assert.equal(JSON.stringify(raw),frozen);
 }
});
test('expired non-live eligible job invalidates zero and fresh-live partial totals',()=>{
 const terminal={...processRow('proof-terminal'),actual_live:false,bucket:'WAITING / BLOCKED',
  process_health:'COMPLETE',process_state:'COMPLETE',runner_alive:false};
 const zero=proofSnapshot([terminal],0);assert.equal(T.view(zero,now).work.counts.actual_live_jobs,0);
 assert.equal(T.view(zero,now+31000).work.counts.actual_live_jobs,null);
 const mixed=proofSnapshot([processRow(),{...terminal,process_checked_utc:'2026-09-23T23:59:00Z'}],1);
 const got=T.view(mixed,now).work;assert.equal(got.process_probe_complete,false);
 assert.equal(got.counts.actual_live_jobs,null);assert.equal(got.rows[0].actual_live,true);
 assert.equal(got.process_proven_count,1);assert.equal(got.process_eligible_count,2);
});
test('13-lane population requires the unknown or expired thirteenth proof',()=>{
 const rows=Array.from({length:13},(_,i)=>processRow('proof-'+i)),raw=proofSnapshot(rows,13);
 assert.equal(T.view(raw,now).work.counts.actual_live_jobs,13);
 for(const changes of [{process_health:'UNKNOWN'}, {process_health:'UNAVAILABLE'},
  {process_checked_utc:'2026-09-23T23:59:00Z'}, {process_checked_utc:null}]){
  const input=structuredClone(raw);Object.assign(input.work.rows[12],changes);
  const got=T.view(input,now).work;assert.equal(got.process_probe_complete,false);
  assert.equal(got.counts.actual_live_jobs,null);assert.equal(got.process_proven_count,12);
 }
});
test('unqualified and future process proof and incoherent ACTIVE never qualify membership',()=>{
 for(const changes of [{process_checked_utc:null}, {process_checked_utc:'2026-09-24T00:00:00'},
  {process_checked_utc:'2026-02-30T00:00:00Z'}, {process_checked_utc:'2026-09-24T00:00:01Z'},
  {process_health:'UNKNOWN'}, {process_state:'UNKNOWN'}, {runner_alive:false}, {runner_alive:'true'},
  {process_health:'COMPLETE'}, {process_state:'COMPLETE'}]){
  const raw=proofSnapshot([Object.assign(processRow(),changes)]),got=T.view(raw,now).work;
  assert.equal(got.counts.actual_live_jobs,null,JSON.stringify(changes));
  assert.equal(got.rows[0].actual_live,false,JSON.stringify(changes));
 }
});
test('population and numeric metadata ambiguity cannot fabricate complete zero or total',()=>{
 for(const changes of [{process_eligible_count:0},{process_eligible_count:null},
  {process_probe_complete:false},{process_probe_complete:'true'},{status:'UNAVAILABLE'}]){
  const raw=proofSnapshot();Object.assign(raw.work,changes);assert.equal(T.view(raw,now).work.counts.actual_live_jobs,null);
 }
 for(const count of [null,undefined,'1',false,-1,0,2,1.5]){
  const raw=proofSnapshot();raw.work.counts.actual_live_jobs=count;
  assert.equal(T.view(raw,now).work.counts.actual_live_jobs,null,String(count));
 }
});
test('zero eligible lanes requires a fresh population observation; unavailable is not zero',()=>{
 const raw=proofSnapshot([],0);assert.equal(T.view(raw,now).work.counts.actual_live_jobs,0);
 assert.equal(T.view(raw,now+31000).work.counts.actual_live_jobs,null);
 for(const value of [null,'2026-09-24T00:00:00','2026-09-24T00:00:01Z']){
  const input=structuredClone(raw);input.work.observed_at=value;
  assert.equal(T.view(input,now).work.counts.actual_live_jobs,null);
 }
});
test('repeated views cannot refresh proof or infer a new live identity',()=>{
 const raw=proofSnapshot(),aged=T.view(raw,now+31000);
 assert.equal(T.view(aged,now+60000).work.counts.actual_live_jobs,null);
 const noLive=proofSnapshot([{...processRow(),actual_live:false,bucket:'WAITING / BLOCKED'}],0);
 const got=T.view(noLive,now).work;assert.equal(got.rows[0].actual_live,false);
 assert.equal(got.counts.actual_live_jobs,0);assert.equal(noLive.work.rows[0].actual_live,false);
});
console.log(`${passed} truth tests passed`);
