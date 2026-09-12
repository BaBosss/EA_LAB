// Rebuild deterministic static fixtures using only Git blobs from the pinned base.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const baseSha = '74dac79aadd1210c09b77e644f507a42bae1f570';
const observedAt = '2026-09-12T07:00:00Z';
const authority = 'PRESENTATION_ONLY_NO_AUTHORITY';
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const blob = name => execFileSync('git', ['show', `${baseSha}:${name}`], {cwd:root,maxBuffer:20*1024*1024});
const sourcePaths = ['START_HERE.md','PROJECT_STATE.md','AGENTS.md','AGENT_TASKBOARD.md','taskboards/active/P03.md','tools/mobile_report_hub/README.md','tools/mobile_report_hub/control_tower.py','mobile_report_hub/app.js','docs/workflows/EA_LAB_MONITOR_AGENT_GRAPH_V31.md','docs/workflows/EA_LAB_MONITOR_V3_OPERATIONALIZATION.md','docs/research/EA_REPORT_SCHEMA.md','docs/research/EA_REPORT_LADDER.md','docs/architecture/EA_TEMPLATE_XX00_BACKTEST_READINESS_V1.md','scripts/lane_registry.ps1','docs/research/B15_COUNTBARS_SENS_01_RESULTS.md'];
const sources = sourcePaths.map(p => ({path:p,refSha:baseSha,sha256:hash(blob(p)),observedAt,status:'PINNED_HISTORICAL',freshness:'PINNED_NOT_LIVE',authority,href:`https://github.com/BaBosss/EA_LAB/blob/${baseSha}/${p}`}));
function row(group,id,title,data,extra={}) {return {id,title,data,source:`fixtures.json#/${group}/${id}`,refSha:baseSha,observedAt,status:'OBSERVED',authority,...extra};}
const research = [
  row('research','FX-13','Mean reversion · study A',{family:'B13 / illustrative',setup:'EURUSD · H1 · Model1',state:'READY',stage:'Template',evidence:'Build + complete set fixture present',main:'PENDING',bwd:'NOT RUN',optimization:'NOT STARTED',model4:'GATED',next:'Review the preregistered Model1 plan',blocker:'None declared in this fixture',blockerClass:null}),
  row('research','FX-16','Kangaroo · study B',{family:'B16 / illustrative',setup:'USDJPY · H1 · Model1',state:'RUNNING',stage:'Optimize',evidence:'Search receipt fixture · 12 of 20 cells',main:'SEARCH / IS ONLY',bwd:'NOT RUN',optimization:'REGION SELECT',model4:'GATED',next:'Map stable neighbors before freezing a center',blocker:'Execution incomplete',blockerClass:'D'}),
  row('research','FX-17','Wave5 · study C',{family:'B17 / illustrative',setup:'Home / timeframe UNKNOWN',state:'BLOCKED',stage:'Template',evidence:'Source-review fixture remains pending',main:'NOT RUN',bwd:'NOT RUN',optimization:'LOCKED',model4:'GATED',next:'Resolve the structural SL / TP coupling contract',blocker:'A · Product semantics unresolved',blockerClass:'A'}),
  row('research','FX-15','ST03 · study D',{family:'B15 / illustrative',setup:'GBPUSD · H4 · Model1',state:'PARKED',stage:'Report',evidence:'Parent comparison fixture packaged',main:'PACKAGED',bwd:'PACKAGED',optimization:'NONE',model4:'NOT RUN',next:'Await a separately contracted research question',blocker:'Parked path; no automatic optimizer rescue',blockerClass:null}),
  row('research','FX-14','GridLog · study E',{family:'B14 / illustrative',setup:'Identity incomplete',state:'READY',stage:'Model1',evidence:'Unbound fixture',next:'This must never be actionable'}, {refSha:null,status:'PENDING'}),
  row('research','FX-18','JumStoch · study F',{family:'B18 / illustrative',state:'READY',stage:'Template',next:'Expired readiness must never be actionable'}, {observedAt:'2026-09-09T07:00:00Z'})
];
const lanes = [row('lanes','FX-L01','Research worker',{state:'RUNNING',activity:'Region mapping · sample receipt 12/20',process:'UNKNOWN',runtime:'Fixture lane only',next:'Package remaining cell receipts'}),row('lanes','FX-L02','Packaging worker',{state:'BLOCKED',activity:'Native graph binding incomplete',process:'UNKNOWN',runtime:'Fixture lane only',next:'Repair report asset identity'}),row('lanes','FX-L03','Old lane observation',{state:'RUNNING',activity:'Old worker observation'}, {observedAt:'2026-09-09T07:00:00Z'})];
const templates = [
  ['B11','GridTrend','PENDING','PENDING','PASS','PENDING','Entry values + Home not bound'],
  ['B12','Breakout','PASS','PASS','PASS','PASS','None in fixture'],
  ['B13','MeanRev','PASS','PASS','PASS','PASS','None in fixture'],
  ['B14','GridLog','PENDING','PENDING','PENDING','UNKNOWN','Native numeric semantics missing'],
  ['B15','ST03','PASS','PASS','PASS','PASS','None in fixture'],
  ['B16','Kangaroo','PASS','PASS','PASS','BLOCKED','Evidence manifest closure incomplete'],
  ['B17','Wave5','BLOCKED','PENDING','BLOCKED','PENDING','Structural SL / TP coupling + review'],
  ['B18','JumStoch','UNKNOWN','UNKNOWN','PENDING','UNKNOWN','Home and source identity unbound']
].map(([id,title,semantics,build,review,packaging,missing])=>row('templates',`FX-${id}`,`${id} · ${title}`,{state: [semantics,build,review,packaging].every(x=>x==='PASS')?'READY':'BLOCKED',semantics,build,review,packaging,missing}));
const optimizations = [row('optimizations','FX-OPT16','Kangaroo · study B',{state:'RUNNING',prerequisites:'PASS',search:'12 / 20 fixture cells',region:'PENDING',center:'NOT FROZEN',bwd:'NOT SPENT',holdout:'UNTOUCHED',model4:'GATED',next:'Finish MAIN map; then assess the preregistered region'}),row('optimizations','FX-OPT13','Mean reversion · study A',{state:'BLOCKED',prerequisites:'PENDING',search:'NOT STARTED',region:'UNKNOWN',center:'NOT FROZEN',bwd:'NOT SPENT',holdout:'UNTOUCHED',model4:'GATED',next:'Model1 and evidence package prerequisites remain open'})];
const blockers = [
 ['A','Product','Structural SL / TP coupling','FX-17','Separate semantic contract and source review'],
 ['B','Harness','Package manifest has a mismatched asset hash','FX-L02','Repair binding; retain REFUSED graph state'],
 ['C','Environment','No qualified current runtime observation','FX-L03','Obtain fresh, bound telemetry through an authorized lane'],
 ['D','Execution incomplete','Remaining search receipts are not packaged','FX-16','Complete the contracted receipt bundle'],
 ['E','Owner / external','Fixture Home choice needs an explicit answer','FX-A01','Owner chooses a Home for this fictional preregistration']
].map(([category,title,reason,affected,next])=>row('blockers',`FX-B${category}`,title,{state:'BLOCKED',category,reason,affected,next}));
const actions = [
 row('actions','FX-A01','Choose a research Home · sample action',{state:'BLOCKED',blockerClass:'E',explicit:true,qualified:true,boundTo:baseSha,expiresAt:'2026-09-13T07:00:00Z',action:'Specify the symbol and timeframe for fictional study A before its preregistration is frozen.',scope:'Research planning only. No tester launch or default change.'}),
 row('actions','FX-A02','Expired owner request',{state:'BLOCKED',blockerClass:'E',explicit:true,qualified:true,boundTo:baseSha,expiresAt:'2026-09-11T07:00:00Z',action:'EXPIRED_ACTION_MUST_NOT_APPEAR'}, {observedAt:'2026-09-09T07:00:00Z'}),
 row('actions','FX-A03','Attention without a qualified action',{state:'BLOCKED',blockerClass:'E',attentionRequired:true,explicit:false,qualified:false,action:'GENERIC_ATTENTION_MUST_NOT_APPEAR'}),
 row('actions','FX-A04','Unbound owner request',{state:'BLOCKED',blockerClass:'E',explicit:true,qualified:true,boundTo:baseSha,expiresAt:'2026-09-13T07:00:00Z',action:'UNBOUND_ACTION_MUST_NOT_APPEAR'}, {refSha:null})
];
const nativePath='factory/runs/b15_countbars_sens01_20260831/visuals/native/B15_COUNTBARS_SENS01_COUNT3_GBPUSD_H4_MAIN_M1.png';
const bytes=blob(nativePath); fs.mkdirSync(path.join(__dirname,'assets'),{recursive:true});fs.writeFileSync(path.join(__dirname,'assets/b15-native-main.png'),bytes);
const native = {id:'B15_COUNTBARS_SENS01_COUNT3_GBPUSD_H4_MAIN_M1',title:'B15 CountBars=3 · GBPUSD / H4',source:nativePath,refSha:baseSha,observedAt,status:'PINNED_HISTORICAL',freshness:'PINNED_NOT_LIVE',authority,sha256:hash(bytes),href:'assets/b15-native-main.png',role:'MAIN',lane:'Meta5c',model:'Model1',window:'2023–2025',reportSource:sources.find(s=>s.path==='docs/research/B15_COUNTBARS_SENS_01_RESULTS.md')};
for(const [group,values] of Object.entries({research,lanes,templates,optimizations,blockers,actions})) values.forEach((r,i)=>r.source=`fixtures.json#/${group}/${i}`);
const pack={schemaVersion:1,authority,baseSha,observedAt,description:'Fictional UX fixture observations. baseSha binds the design snapshot, not project facts. The native artifact alone is copied from pinned Git.',sources,research,lanes,templates,optimizations,blockers,actions,native};
fs.writeFileSync(path.join(__dirname,'fixtures.json'),JSON.stringify(pack,null,2)+'\n');
console.log('Wrote static fixture and exact native asset; no accepted-system writes.');
