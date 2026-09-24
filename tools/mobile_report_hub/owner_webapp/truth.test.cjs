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
console.log(`${passed} truth tests passed`);
