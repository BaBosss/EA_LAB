'use strict';
// Deterministic Work rendering fixtures; full browser/layout coverage remains in inherited suites.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
let source=fs.readFileSync(__dirname+'/owner_webapp.js','utf8');
source=source.replace('\nrenderRoute();',`
window.workFixture={
 render(){workPage();return main.innerHTML},
 renderRuntime(){runtimePage();return main.innerHTML},
 renderOverview(){overview();return main.innerHTML},
 graph(){return compactGraph()},
 setWork(value){RAW.work=value;DATA=truth.view(RAW,Date.now());return this.render()},
 setSource(value){RAW.source_observations=value;DATA=truth.view(RAW,Date.now());return this.renderRuntime()},
 setFilter(value){workFilter=value;return this.render()},
 setQuery(value){workQuery=value;return this.render()},
 setDimension(name,value){if(name==='track')workTrack=value;else if(name==='freshness')workFreshness=value;else if(name==='owner')workOwner=value;else if(name==='family')workFamily=value;return this.render()},
 resetDimensions(){workTrack='ALL';workFreshness='ALL';workOwner='ALL';workFamily='ALL';return this.render()},
 open(id){openWork(id);return drawerRoot.innerHTML},
 handoff(id){return workHandoffText((DATA.work?.rows||[]).find(x=>x.id===id))},
 copy(id){return copyWorkHandoff(id)},
 refreshData
};
renderRoute();`);
const rows=Array.from({length:126},(_,i)=>({
 id:'lane-'+i,title:'title-'+i,owner:'owner-'+i,worker:'worker-'+i,
 state:i%2?'DONE':'BLOCKED',display_state:i%2?'RECORDED_SCOPE_CLOSURE':'OWNER_OR_SOURCE_GATE',
 category:i%2?'RECORDED_SCOPE_CLOSURE':'OWNER_OR_SOURCE_GATE',unresolved:!(i%2),
 blocker:'blocker-'+i,reason_th:'reason-'+i,next_action_th:'action-'+i,
 next:'action-'+i,bucket:i%2?'RECENTLY DONE':'WAITING / BLOCKED',track:i%3?'SYSTEM':'RESEARCH',
 ea_family:i%4?'UNKNOWN':'Family-'+i,lane_owner:'owner-'+i,known_aliases:['alias-'+i],
 objective:'objective-'+i,direct_consumer:'consumer-'+i,source_class:'LANE_REGISTRY',
 source_locator:'registry-v1/lane-'+i+'.json',canonical_relation:'UNKNOWN',
 prohibited_actions:'NO MUTATION FROM MONITOR',acceptance_boundary:'ACCEPTED EVIDENCE REQUIRED',
 raw_state:i%2?'DONE':'BLOCKED',last_seen:'2000-01-01T00:00:00Z',actual_live:false,
 job_state:'FAILED',freshness:i%2?'STALE':'CURRENT',updated_at:'2000-01-01T00:00:00Z',
 dependencies:[],acceptance:'UNKNOWN',canonical:'NOT_ASSESSED',consumption:'UNKNOWN'
}));
rows[124].blocker='<img src=x onerror=alert(1)>';
rows[124].source_locator='<svg onload=alert(2)>';
rows[125].work_id='ORDER-SEARCH-555';
function element(){return {innerHTML:'',textContent:'',value:'',dataset:{},classList:{add(){},remove(){},toggle(){}},setAttribute(){},addEventListener(){},querySelector(){return element()},querySelectorAll(){return []},cloneNode(){return element()}}}
const elements=new Map();
const document={hidden:false,activeElement:null,getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id)},querySelectorAll(){return []},querySelector(){return null}};
let fetches=0,clipboardWrites=0;
const truth={view:x=>x,number:v=>Number.isFinite(Number(v))?Number(v):null,timestamp:v=>Date.parse(v)};
const sourceObservation={status:'AVAILABLE',schema:'ea_observation_adapters/1',canonical_ref:'a'.repeat(40),read_at_utc:'2026-09-24T13:35:13Z',overall:'PARTIAL',budget_usage:{files:334,bytes:39765892,rows:429067},sections:{
 accounts:{availability:'PARTIAL',account_count:6,sample_count:144,conflict_count:0,qualified_series_count:0},
 ledger:{availability:'PARTIAL',account_count:6,accounts_with_ledger:4,missing_ledger_count:2,deal_events:11152,stream_count:69,all_costs_complete:false,latest_broker_time:'2026-09-24T13:34:09',clock_basis:'BROKER_TIME_UNQUALIFIED'},
 deployments:{availability:'PARTIAL',deployment_count:64,expected_identity_present:1,fields_match_only:0,producer_identity_state:'FAIL',canonical_binding:'DIFFERENT_REPO_HEAD',generated_at:'2026-09-24T13:35:13Z'},
 guards:{availability:'PARTIAL',effective:null,effective_state:'UNKNOWN',contexts:[{kind:'NEWS_CALENDAR',availability:'PARTIAL',observed_at:null,reason:'CONTEXT_NOT_EFFECTIVE_EVIDENCE'},{kind:'MRIS',availability:'PARTIAL',observed_at:'2026-09-24T13:35:09Z',reason:'CONTEXT_NOT_EFFECTIVE_EVIDENCE'}]},
 access_provenance:{availability:'UNAVAILABLE'}},finding_count:3,findings:[{code:'ACCOUNT_METADATA_MISSING_OR_AMBIGUOUS',finding_id:'finding-'+'d'.repeat(64),next_action:'INSPECT_DECLARED_SOURCE_EVIDENCE'},{code:'<img src=x onerror=alert(1)>',finding_id:'finding-'+'e'.repeat(64),next_action:'INSPECT'}]};
const window={__EA_LAB_DATA__:{work:{status:'AVAILABLE',rows},source_observations:sourceObservation},EALabTruth:truth,addEventListener(){},scrollTo(){},scrollX:0,scrollY:0};
const context={document,window,navigator:{clipboard:{writeText(){clipboardWrites++;return Promise.resolve()}}},location:{protocol:'file:',hash:'#work'},setTimeout(){},clearTimeout(){},setInterval(){},fetch(){fetches++;throw Error('unexpected fetch')}};
vm.createContext(context);vm.runInContext(source,context);
const api=context.window.workFixture;
let html=api.render();
assert.equal((html.match(/<tr data-work=/g)||[]).length,63,'UNRESOLVED default');
html=api.setFilter('ALL');assert.equal((html.match(/<tr data-work=/g)||[]).length,126,'ALL has no 100-row cutoff');
assert.match(html,/Showing 126 of 126/);
for(const bucket of ['CURRENT ACTIONABLE','READY','WAITING / BLOCKED','OWNER DECISION NEEDED','PARKED','HISTORICAL UNRESOLVED / UNKNOWN','ACTUAL LIVE JOBS','RECENTLY DONE'])assert.match(html,new RegExp(bucket.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')));
html=api.setFilter('HISTORY');assert.equal((html.match(/<tr data-work=/g)||[]).length,63);
html=api.setFilter('DONE');assert.equal((html.match(/<tr data-work=/g)||[]).length,63);
html=api.setFilter('UNRESOLVED');assert.equal((html.match(/<tr data-work=/g)||[]).length,63);
for(const [query,id] of [['ORDER-SEARCH-555','lane-125'],['lane-125','lane-125'],['title-123','lane-123'],['owner-125','lane-125'],['worker-123','lane-123'],['reason-122','lane-122'],['action-120','lane-120']]){
 html=api.setFilter('ALL');html=api.setQuery(query);assert.match(html,new RegExp(`data-work="${id}"`),query);
}
for(const [query,id] of [['Family-124','lane-124'],['objective-124','lane-124'],['consumer-124','lane-124'],['registry-v1/lane-123.json','lane-123'],['alias-124','lane-124']]){
 html=api.setFilter('ALL');html=api.setQuery(query);assert.match(html,new RegExp(`data-work="${id}"`),query);
}
api.setQuery('');
for(const [dimension,value,expected] of [['track','RESEARCH','lane-0'],['freshness','STALE','lane-1'],['owner','owner-125','lane-125'],['family','Family-124','lane-124']]){
 api.resetDimensions();html=api.setDimension(dimension,value);assert.match(html,new RegExp(`data-work="${expected}"`),dimension);
}
api.resetDimensions();html=api.setFilter('WAITING / BLOCKED');assert.equal((html.match(/<tr data-work=/g)||[]).length,63,'bucket filter');
html=api.setQuery('onerror');assert.match(html,/data-work="lane-124"/,'raw blocker is searchable');
const drawer=api.open('lane-124');assert.match(drawer,/&lt;img/);assert.doesNotMatch(drawer,/<img src=x/);
assert.equal(clipboardWrites,0,'opening drawer must not touch clipboard');
const handoff=api.handoff('lane-124');
for(const field of ['work ID:','source class/locator:','displayed/raw state:','lane owner:','blocker:','NEXT:','prohibited actions:','acceptance boundary:','freshness:','canonical relation:'])assert.match(handoff,new RegExp(field.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')));
assert.doesNotMatch(handoff,/<img|<svg/,'handoff hostile text is escaped');
assert.equal(fetches,0,'handoff generation must not fetch');assert.equal(clipboardWrites,0,'handoff generation must not copy');
api.copy('lane-124');assert.equal(clipboardWrites,1,'clipboard is touched only by the copy control');assert.equal(fetches,0,'copy must not fetch');
html=api.setQuery('no-such-work-row');assert.match(html,/ไม่พบงานที่ตรงกับตัวกรองหรือคำค้นนี้/);assert.match(html,/ALL \/ HISTORY/);
api.refreshData();assert.equal(fetches,0,'offline snapshot must not fetch');
html=api.renderRuntime();
assert.match(html,/Source observations \/ data coverage/);
assert.match(html,/DEAL EVENTS observed/);
assert.match(html,/11,152/);
assert.match(html,/DIFFERENT_REPO_HEAD/);
assert.match(html,/Producer identity state[\s\S]*FAIL/);
assert.match(html,/effective state UNKNOWN/);
assert.match(html,/ACCOUNT_METADATA_MISSING_OR_AMBIGUOUS/);
assert.match(html,/&lt;img src=x onerror=alert\(1\)&gt;/);
assert.doesNotMatch(html,/<img src=x onerror=alert\(1\)>/);
html=api.setSource({status:'UNAVAILABLE',overall:'UNAVAILABLE',sections:{},findings:[]});
assert.match(html,/Source observations are UNAVAILABLE/);
assert.match(html,/Existing Runtime panels remain usable/);
html=api.setSource(undefined);assert.match(html,/Adapter source[\s\S]*UNAVAILABLE/);
console.log('PASS: 53 Work UI assertions (buckets, multidimensional search/filters, handoff copy, history, counts, escaping, offline no-fetch); 12 source-observation Runtime assertions');

// MON-LOC-001-UI: every live aggregate obeys global proof, even in filtered views.
const liveRows=Array.from({length:13},(_,i)=>({...rows[i],id:'proof-'+i,title:'proof-'+i,
 bucket:i===12?'HISTORICAL UNRESOLVED / UNKNOWN':'ACTUAL LIVE JOBS',actual_live:i!==12,
 process_health:i===12?'UNKNOWN':'ACTIVE',process_freshness:'CURRENT',unresolved:true}));
const workProof=(complete,count,status='AVAILABLE',fixtureRows=liveRows)=>({status,rows:fixtureRows,
 process_probe_complete:complete,process_eligible_count:13,process_proven_count:complete?13:12,
 counts:{actual_live_jobs:count,by_bucket:{'ACTUAL LIVE JOBS':count}}});
api.resetDimensions();api.setQuery('');api.setFilter('ALL');
function unknownLiveAggregates(label){
 const rendered=api.render();
 assert.match(rendered,/<label>Actual live jobs<\/label><strong>UNKNOWN<\/strong>/,label);
 assert.doesNotMatch(rendered,/<h3>ACTUAL LIVE JOBS \(\d+\)<\/h3>/,label);
 assert.match(api.renderOverview(),/<label>Actual live jobs<\/label><strong>UNKNOWN<\/strong>/,label);
 assert.match(api.graph(),/PARTIAL process proof[\s\S]*total ACTUAL LIVE JOBS are UNKNOWN/,label);
 assert.doesNotMatch(api.graph(),/Process proof is complete/,label);
}
for(const [label,health] of [['13-lane incomplete','UNKNOWN'],['unavailable','UNAVAILABLE'],['stale','STALE']]){
 const fixtureRows=liveRows.map(r=>({...r,process_health:r.id==='proof-12'?health:r.process_health}));
 api.setWork(workProof(false,null,'AVAILABLE',fixtureRows));unknownLiveAggregates(label);
 assert.match(api.render(),/<h3>ACTUAL LIVE JOBS \(UNKNOWN\)<\/h3>/,label);
 assert.match(api.graph(),/subset, not a complete execution graph/,label);
 api.setQuery('proof-0');unknownLiveAggregates(label+' filtered');
 assert.match(api.render(),/Showing 1 of 13/);api.setQuery('');
}
// A stray numeric field cannot override incomplete or unavailable proof.
for(const status of ['AVAILABLE','UNAVAILABLE','UNKNOWN']){
 api.setWork(workProof(false,12,status));unknownLiveAggregates(status+' numeric count');
}
api.setWork(workProof(true,12));html=api.render();
assert.match(html,/<label>Actual live jobs<\/label><strong>12<\/strong>/);
assert.match(html,/<h3>ACTUAL LIVE JOBS \(12\)<\/h3>/);
assert.match(api.graph(),/Process proof is complete/);
assert.match(api.graph(),/Display shows a subset of observed identities/,'capped graph remains partial presentation');
api.setQuery('proof-0');html=api.render();
assert.match(html,/<label>Actual live jobs<\/label><strong>12<\/strong>/,'filter does not change global count');
assert.match(html,/<h3>ACTUAL LIVE JOBS \(1\)<\/h3>/,'complete filtered bucket counts rows in view');
api.setQuery('');api.setWork(workProof(true,0,'AVAILABLE',[]));html=api.render();
assert.match(html,/<label>Actual live jobs<\/label><strong>0<\/strong>/,'legitimate complete zero');
assert.match(api.graph(),/Process proof is complete[\s\S]*No process-proven live identities shown/);
api.setWork(workProof(false,null,'AVAILABLE',[]));unknownLiveAggregates('incomplete empty view');
assert.equal(fetches,0,'proof and graph fixtures remain offline');
console.log('PASS: FinalClosure live aggregate and partial graph fixtures');
