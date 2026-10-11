'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { reconcile } = require('./orchestrator_read_only_reconciler.cjs');
const HEAD='a'.repeat(40), TREE='b'.repeat(40), NEXT='c'.repeat(40);
const NOW='2026-10-11T09:00:00Z';
const seal = data => ({data,sha256:createHash('sha256').update(JSON.stringify(data)).digest('hex')});
function task(id='a01', extra={}) {
  return {task_id:id,lane_id:'lane-'+id,owner:'worker-'+id,stage:'DISPATCH',
    action:'SOURCE_TEST',source_head:HEAD,source_tree:TREE,worktree:'D:\\work\\'+id,
    resources:['resource-'+id],dependency_ids:[],idempotency_key:'idem-'+id,repair_remaining:0,
    author_id:'worker-'+id,reviewer_id:'independent-reviewer',provider:null,review:null,
    test_receipt:null,...extra};
}
function fixture(tasks=[task()]) {
  return {schema:'EA_LAB_ORCHESTRATOR_READ_ONLY_INPUT_V1',now_utc:NOW,
    source:{head:HEAD,tree:TREE,origin_master:HEAD,ls_remote:HEAD,
      checkout_head:HEAD,checkout_tree:TREE,clean:true,captured_utc:'2026-10-11T08:59:00Z'},
    registry:{validated:true,main_ct_ids:['existing-main-ct'],
      lanes:tasks.map(t=>({lane_id:t.lane_id,owner:t.owner,state:'READY',
        worktree:t.worktree,critical_paths:[t.worktree.replace(/\\/g,'/')+'/target.cjs']}))},
    leases:tasks.flatMap(t=>t.resources.map(resource=>({
      resource,owner:t.owner,lease_id:'lease-'+resource,expires_utc:'2026-10-11T09:10:00Z',
      receipt:seal({resource,owner:t.owner,lease_id:'lease-'+resource,source_head:HEAD})}))),
    jobs:[],tasks};
}
const decision=(s,id='a01')=>reconcile(s).decisions.find(x=>x.task_id===id);
const check=(s,status,id='a01')=>assert.equal(decision(s,id).status,status,JSON.stringify(decision(s,id)));
const alter=(s)=>structuredClone(s);
test('01 independent ready dispatch',()=>check(fixture(),'READY'));
test('02 duplicate idempotency blocks both',()=>{
  const s=fixture([task('a01'),task('b02',{idempotency_key:'idem-a01'})]);
  check(s,'BLOCKED','a01');check(s,'BLOCKED','b02');
});
test('03 existing active owner prevents duplicate',()=>{
  const s=fixture();s.registry.lanes.push({lane_id:'foreign',owner:'worker-a01',state:'RUNNING',
    worktree:'D:\\work\\foreign',critical_paths:['d:/work/a01/target.cjs']});
  check(s,'WAITING_RESOURCE');
});
test('04 stale snapshot is unknown',()=>{const s=fixture();s.source.captured_utc='2026-10-11T08:40:00Z';check(s,'UNKNOWN')});
test('05 future source snapshot is unknown',()=>{const s=fixture();s.source.captured_utc='2026-10-11T09:00:01Z';check(s,'UNKNOWN')});
test('06 mismatched remote HEAD fail closed',()=>{const s=fixture();s.source.ls_remote=NEXT;check(s,'UNKNOWN')});
test('07 wrong source TREE fail closed',()=>{const s=fixture();s.tasks[0].source_tree=NEXT;check(s,'UNKNOWN')});
test('08 dirty checkout fail closed',()=>{const s=fixture();s.source.clean=false;check(s,'BLOCKED')});
test('09 wrong worktree fail closed',()=>{const s=fixture();s.registry.lanes[0].worktree='D:\\different';check(s,'BLOCKED')});
test('10 missing lease',()=>{const s=fixture();s.leases=[];check(s,'WAITING_RESOURCE')});
test('11 foreign lease owner',()=>{const s=fixture();s.leases[0].owner='intruder';check(s,'WAITING_RESOURCE')});
test('12 expired lease',()=>{const s=fixture();s.leases[0].expires_utc='2026-10-11T08:59:00Z';check(s,'WAITING_RESOURCE')});
test('13 unknown PID and creation fail closed',()=>{
  const s=fixture();s.jobs=[job(s.tasks[0])];s.jobs[0].identity.pid=null;s.jobs[0].identity.creation_utc=null;check(s,'UNKNOWN');
});
test('14 missing terminal postcondition never proven',()=>{
  const s=fixture([task('a01',{stage:'OBSERVE'})]);s.jobs=[job(s.tasks[0],true)];s.jobs[0].terminal.postcondition=null;check(s,'UNKNOWN');
});
test('15 terminal exact evidence is PROVEN_TERMINAL',()=>{
  const s=fixture([task('a01',{stage:'OBSERVE'})]);s.jobs=[job(s.tasks[0],true)];check(s,'PROVEN_TERMINAL');
});
test('16 forged terminal receipt sha rejected',()=>{
  const s=fixture([task('a01',{stage:'OBSERVE'})]);s.jobs=[job(s.tasks[0],true)];s.jobs[0].terminal.receipt.sha256='0'.repeat(64);check(s,'UNKNOWN');
});
test('17 exhausted historical repair budget blocks retry',()=>{
  const s=fixture([task('a01',{action:'RETRY',repair_remaining:0})]);check(s,'BLOCKED');
});
test('18 author reviewer conflict blocks review',()=>{
  const s=fixture([task('a01',{stage:'REVIEW',reviewer_id:'worker-a01',test_receipt:testsReceipt('a01')})]);check(s,'BLOCKED');
});
test('19 auth unverified blocks AI provider',()=>{
  const s=fixture([task('a01',{provider:{name:'Gemini',model:'gemini-3.8-flash-high',
    auth:'UNVERIFIED',cost_ceiling_usd:1,max_cost_usd:0.5,authenticated_at:NOW}})]);check(s,'BLOCKED');
});
test('20 uncapped AI cost blocks provider',()=>{
  const s=fixture([task('a01',{provider:{name:'Gemini',model:'gemini-3.8-flash-high',
    auth:'VERIFIED',cost_ceiling_usd:null,max_cost_usd:0.5,authenticated_at:NOW}})]);check(s,'BLOCKED');
});
test('21 T3 forbidden means block',()=>{const s=fixture([task('a01',{action:'MT5_TESTER'})]);check(s,'BLOCKED')});
test('22 simultaneous same resource blocks both',()=>{
  const ts=[task('a01',{resources:['mt5']}),task('b02',{resources:['mt5']})];
  const s=fixture(ts);check(s,'WAITING_RESOURCE','a01');check(s,'WAITING_RESOURCE','b02');
});
test('23 system blocker does not block EA independent lane',()=>{
  const s=fixture([task('a01',{action:'T3_DEPLOY'}),task('b02')]);
  check(s,'BLOCKED','a01');check(s,'READY','b02');
});
test('24 duplicate observation remains deterministically blocked',()=>{
  const s=fixture();s.jobs=[job(s.tasks[0])];const a=reconcile(s),b=reconcile(s);
  assert.deepEqual(a,b);check(s,'WAITING_RESOURCE');
});
test('25 tampered hash lease fails closed',()=>{
  const s=fixture();s.leases[0].receipt.data.owner='other';check(s,'UNKNOWN');
});
test('26 malformed UTC offset fails closed',()=>{
  const s=fixture();s.source.captured_utc='2026-10-11T15:59:00+07:00';check(s,'UNKNOWN');
});
test('27 malformed input schema fails closed',()=>{
  const s=fixture();s.schema='UNTRUSTED';check(s,'UNKNOWN');
});
test('28 isolated dependency satisfied terminal proceeds',()=>{
  const s=fixture([task('a01',{stage:'OBSERVE'}),task('b02',{dependency_ids:['a01']})]);
  s.jobs=[job(s.tasks[0],true)];check(s,'PROVEN_TERMINAL','a01');check(s,'READY','b02');
});
test('29 failed dependency blocks child, independent third remains ready',()=>{
  const s=fixture([task('a01',{action:'T3_DEPLOY'}),task('b02',{dependency_ids:['a01']}),task('c03')]);
  check(s,'BLOCKED','a01');check(s,'BLOCKED','b02');check(s,'READY','c03');
});
test('30 circular dependencies fail closed',()=>{
  const s=fixture([task('a01',{dependency_ids:['b02']}),task('b02',{dependency_ids:['a01']})]);
  check(s,'BLOCKED','a01');check(s,'BLOCKED','b02');
});
test('31 exact frozen reviewed receipt qualifies integration',()=>{
  const s=fixture([task('a01',{stage:'INTEGRATE',reviewer_id:'external-reviewer',
    test_receipt:testsReceipt('a01'),review:reviewReceipt('a01')})]);check(s,'READY_FOR_CT_INTEGRATION');
});
test('32 review evidence absent blocks integration',()=>{
  const s=fixture([task('a01',{stage:'INTEGRATE',test_receipt:testsReceipt('a01')})]);check(s,'BLOCKED');
});
test('33 reviewed head mismatch blocks integration',()=>{
  const s=fixture([task('a01',{stage:'INTEGRATE',test_receipt:testsReceipt('a01'),
    review:reviewReceipt('a01',{source_head:NEXT})})]);check(s,'BLOCKED');
});
test('34 green tests enable review, without publishing',()=>{
  const s=fixture([task('a01',{stage:'REVIEW',test_receipt:testsReceipt('a01')})]);check(s,'READY_FOR_REVIEW');
});
test('35 malformed negative test receipt cannot trigger review',()=>{
  const s=fixture([task('a01',{stage:'REVIEW',test_receipt:testsReceipt('a01')})]);s.tasks[0].test_receipt.sha256='1'.repeat(64);check(s,'UNKNOWN');
});
test('36 no Main CT identity blocks all',()=>{
  const s=fixture();s.registry.main_ct_ids=[];check(s,'BLOCKED');
});
test('37 Registry invalid blocks all',()=>{
  const s=fixture();s.registry.validated=false;check(s,'UNKNOWN');
});
test('38 malformed jobs do not silently clear resource',()=>{
  const s=fixture();s.jobs=[job(s.tasks[0])];s.jobs[0].identity.creation_utc='bad';check(s,'UNKNOWN');
});
test('39 frozen reviewer must be independent',()=>{
  const s=fixture([task('a01',{stage:'INTEGRATE',reviewer_id:'worker-a01',
    test_receipt:testsReceipt('a01'),review:reviewReceipt('a01')})]);check(s,'BLOCKED');
});
test('40 extra root keys rejected',()=>{const s=fixture();s.extra='surprise';check(s,'UNKNOWN')});
function testsReceipt(id) {return seal({task_id:id,source_head:HEAD,source_tree:TREE,
  passed:true,positive:20,negative:20,exit_code:0});}
function reviewReceipt(id,override={}){const data={task_id:id,source_head:HEAD,source_tree:TREE,
    reviewed_by:'external-reviewer',verdict:'SCRUTINY_PASS',independent:true,...override};return seal(data);}
function job(t,terminal=false){
  const receipt=seal({job_id:'job-'+t.task_id,task_id:t.task_id,lane_id:t.lane_id,
    source_head:HEAD,exit_code:0,postcondition:'PASS'});
  return {job_id:'job-'+t.task_id,task_id:t.task_id,lane_id:t.lane_id,source_head:HEAD,
    state:terminal?'COMPLETE':'RUNNING',identity:{pid:12345,creation_utc:'2026-10-11T08:55:00Z',
      executable:'C:\\tools\\node.exe',worktree:t.worktree,source_head:HEAD,heartbeat_utc:'2026-10-11T08:59:00Z'},
    terminal:terminal?{exit_code:0,postcondition:'PASS',receipt}:null};
}

test('41 incumbent WAITING lane blocks dispatch',()=>{const s=fixture();s.registry.lanes[0].state='WAITING';check(s,'WAITING_RESOURCE')});
