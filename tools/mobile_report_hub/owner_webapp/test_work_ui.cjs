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
 setSource(value){RAW.source_observations=value;DATA=truth.view(RAW,Date.now());return this.renderRuntime()},
 setFilter(value){workFilter=value;return this.render()},
 setQuery(value){workQuery=value;return this.render()},
 open(id){openWork(id);return drawerRoot.innerHTML},
 refreshData
};
renderRoute();`);
const rows=Array.from({length:126},(_,i)=>({
 id:'lane-'+i,title:'title-'+i,owner:'owner-'+i,worker:'worker-'+i,
 state:i%2?'DONE':'BLOCKED',display_state:i%2?'RECORDED_SCOPE_CLOSURE':'OWNER_OR_SOURCE_GATE',
 category:i%2?'RECORDED_SCOPE_CLOSURE':'OWNER_OR_SOURCE_GATE',unresolved:!(i%2),
 blocker:'blocker-'+i,reason_th:'reason-'+i,next_action_th:'action-'+i,
 job_state:'FAILED',freshness:i%2?'STALE':'CURRENT',updated_at:'2000-01-01T00:00:00Z',
 dependencies:[],acceptance:'UNKNOWN',canonical:'NOT_ASSESSED',consumption:'UNKNOWN'
}));
rows[124].blocker='<img src=x onerror=alert(1)>';
function element(){return {innerHTML:'',textContent:'',value:'',dataset:{},classList:{add(){},remove(){},toggle(){}},setAttribute(){},addEventListener(){},querySelector(){return element()},querySelectorAll(){return []},cloneNode(){return element()}}}
const elements=new Map();
const document={hidden:false,activeElement:null,getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id)},querySelectorAll(){return []},querySelector(){return null}};
let fetches=0;
const truth={view:x=>x,number:v=>Number.isFinite(Number(v))?Number(v):null,timestamp:v=>Date.parse(v)};
const sourceObservation={status:'AVAILABLE',schema:'ea_observation_adapters/1',canonical_ref:'a'.repeat(40),read_at_utc:'2026-09-24T13:35:13Z',overall:'PARTIAL',budget_usage:{files:334,bytes:39765892,rows:429067},sections:{
 accounts:{availability:'PARTIAL',account_count:6,sample_count:144,conflict_count:0,qualified_series_count:0},
 ledger:{availability:'PARTIAL',account_count:6,accounts_with_ledger:4,missing_ledger_count:2,deal_events:11152,stream_count:69,all_costs_complete:false,latest_broker_time:'2026-09-24T13:34:09',clock_basis:'BROKER_TIME_UNQUALIFIED'},
 deployments:{availability:'PARTIAL',deployment_count:64,expected_identity_present:1,fields_match_only:0,producer_identity_state:'FAIL',canonical_binding:'DIFFERENT_REPO_HEAD',generated_at:'2026-09-24T13:35:13Z'},
 guards:{availability:'PARTIAL',effective:null,effective_state:'UNKNOWN',contexts:[{kind:'NEWS_CALENDAR',availability:'PARTIAL',observed_at:null,reason:'CONTEXT_NOT_EFFECTIVE_EVIDENCE'},{kind:'MRIS',availability:'PARTIAL',observed_at:'2026-09-24T13:35:09Z',reason:'CONTEXT_NOT_EFFECTIVE_EVIDENCE'}]},
 access_provenance:{availability:'UNAVAILABLE'}},finding_count:3,findings:[{code:'ACCOUNT_METADATA_MISSING_OR_AMBIGUOUS',finding_id:'finding-'+'d'.repeat(64),next_action:'INSPECT_DECLARED_SOURCE_EVIDENCE'},{code:'<img src=x onerror=alert(1)>',finding_id:'finding-'+'e'.repeat(64),next_action:'INSPECT'}]};
const window={__EA_LAB_DATA__:{work:{status:'AVAILABLE',rows},source_observations:sourceObservation},EALabTruth:truth,addEventListener(){},scrollTo(){},scrollX:0,scrollY:0};
const context={document,window,location:{protocol:'file:',hash:'#work'},setTimeout(){},clearTimeout(){},setInterval(){},fetch(){fetches++;throw Error('unexpected fetch')}};
vm.createContext(context);vm.runInContext(source,context);
const api=context.window.workFixture;
let html=api.render();
assert.equal((html.match(/<tr data-work=/g)||[]).length,63,'UNRESOLVED default');
html=api.setFilter('ALL');assert.equal((html.match(/<tr data-work=/g)||[]).length,126,'ALL has no 100-row cutoff');
assert.match(html,/Showing 126 of 126/);
html=api.setFilter('HISTORY');assert.equal((html.match(/<tr data-work=/g)||[]).length,63);
html=api.setFilter('DONE');assert.equal((html.match(/<tr data-work=/g)||[]).length,63);
html=api.setFilter('UNRESOLVED');assert.equal((html.match(/<tr data-work=/g)||[]).length,63);
for(const [query,id] of [['lane-125','lane-125'],['title-123','lane-123'],['owner-125','lane-125'],['worker-123','lane-123'],['reason-122','lane-122'],['action-120','lane-120']]){
 html=api.setFilter('ALL');html=api.setQuery(query);assert.match(html,new RegExp(`data-work="${id}"`),query);
}
html=api.setQuery('onerror');assert.match(html,/data-work="lane-124"/,'raw blocker is searchable');
const drawer=api.open('lane-124');assert.match(drawer,/&lt;img/);assert.doesNotMatch(drawer,/<img src=x/);
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
console.log('PASS: 18 Work UI assertions (search, filters, history, counts, escaping, offline no-fetch); 12 source-observation Runtime assertions');
