'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const api=require('./execution_identity.cjs');
let count=0;
function test(name,fn){fn();count++;console.log('PASS '+name);}
const B={job_id:'fixture-job',lane_id:'fixture-lane',base_sha:'471a94d6d65fc86882ac7a4bbb882e280edbe98d',worktree:'D:\\fixture\\worktree'};
const START='2026-10-04T02:00:00.0000000Z',OBS='2026-10-04T02:00:01.0000000Z',END='2026-10-04T02:00:02.0000000Z';
const CREATED='2026-10-04T01:00:00.1234567Z';
function fixture(){
 const check=role=>({job_id:B.job_id,lane_id:B.lane_id,role,pid:role==='runner'?123:456,
   expected_creation_utc:CREATED,current_creation_utc:CREATED,identity:'MATCHING_RECORDED_PROCESS',query_status:'PRESENT',checked_utc:OBS});
 return {host_id:'bbb88aa0-1598-43f6-b56c-a7db22af086a',observation_utc:OBS,stable:true,
   job:{job_id:B.job_id,base_sha:B.base_sha,worktree:B.worktree,stage:'SYNTHETIC_FIXTURE',
    file_path:'C:\\fixture\\node.exe',postcondition_file_path:'',created_utc:CREATED,arg_hash:'a'.repeat(64)},
   state:{job_id:B.job_id,state:'RUNNING',child_pid:456,runner_pid:123,child_start_utc:CREATED,runner_start_utc:CREATED,started_utc:CREATED},
   lane:{lane_id:B.lane_id,head_sha:B.base_sha,worktree:B.worktree,state:'RUNNING'},
   heartbeat:{job_id:B.job_id,updated_utc:START},result:null,
   checks:{child:check('child'),runner:check('runner')},
   images:{child:{pid:456,creation_utc:CREATED,executable_path:'C:\\fixture\\node.exe',checked_utc:OBS}}};
}
const project=f=>api.project(B,f,START,END);
test('synthetic bound live -> PROVEN_RUNNING',()=>{const r=project(fixture());assert.equal(r.state,'PROVEN_RUNNING');assert.equal(r.pid,456);assert.equal(r.progress,'UNKNOWN');});
test('terminal durable result and absent process',()=>{const f=fixture();f.state.state='COMPLETE';f.result={job_id:B.job_id,state:'COMPLETE',exit_code:0,ended_utc:START,postcondition_exit_code:null};Object.assign(f.checks.child,{identity:'RECORDED_PROCESS_NOT_PRESENT',query_status:'NOT_PRESENT',current_creation_utc:null});assert.equal(project(f).state,'PROVEN_TERMINAL');});
test('stale Registry RUNNING no process',()=>{const f=fixture();Object.assign(f.checks.child,{identity:'RECORDED_PROCESS_NOT_PRESENT',query_status:'NOT_PRESENT',current_creation_utc:null});assert.equal(project(f).state,'UNKNOWN');});
test('PID reused',()=>{const f=fixture();f.checks.child.identity='DIFFERENT_CREATION_IDENTITY';f.checks.child.current_creation_utc=START;assert.equal(project(f).state,'IDENTITY_MISMATCH');});
test('100ns creation mismatch preserved',()=>{const f=fixture();f.checks.child.current_creation_utc='2026-10-04T01:00:00.1234568Z';assert.equal(project(f).state,'IDENTITY_MISMATCH');});
for(const field of ['pid','creation_utc','executable_path'])test('missing image '+field,()=>{const f=fixture();f.images.child[field]=null;assert.equal(project(f).state,'UNKNOWN');});
for(const field of ['child_pid','child_start_utc'])test('missing state '+field,()=>{const f=fixture();f.state[field]=null;assert.equal(project(f).state,'UNKNOWN');});
test('wrong executable',()=>{const f=fixture();f.images.child.executable_path='C:\\other.exe';assert.equal(project(f).state,'IDENTITY_MISMATCH');});
test('job mismatch',()=>{const f=fixture();f.job.job_id='other-job';assert.equal(project(f).state,'IDENTITY_MISMATCH');});
test('lane mismatch',()=>{const f=fixture();f.lane.lane_id='other-lane';assert.equal(project(f).state,'IDENTITY_MISMATCH');});
test('source mismatch',()=>{const f=fixture();f.job.base_sha='b'.repeat(40);assert.equal(project(f).state,'IDENTITY_MISMATCH');});
test('stale heartbeat is not progress',()=>{const f=fixture();f.heartbeat.updated_utc='2026-10-01T00:00:00Z';const r=project(f);assert.equal(r.progress,'UNKNOWN');assert.ok(r.heartbeat_age_seconds>86400);});
test('future heartbeat UNKNOWN never zero',()=>{const f=fixture();f.heartbeat.updated_utc=END;const r=project(f);assert.equal(r.state,'UNKNOWN');assert.equal(r.heartbeat_age_seconds,null);});
test('missing heartbeat age remains null',()=>{const f=fixture();f.heartbeat=null;assert.equal(project(f).heartbeat_age_seconds,null);});
test('cached process observation refused',()=>{const f=fixture();f.observation_utc=CREATED;assert.equal(project(f).state,'UNKNOWN');});
test('cached individual check refused',()=>{const f=fixture();f.checks.child.checked_utc=CREATED;assert.equal(project(f).state,'UNKNOWN');});
test('future observation refused',()=>{const f=fixture();f.observation_utc='2026-10-05T00:00:00Z';assert.equal(project(f).state,'UNKNOWN');});
test('unknown host refused',()=>{const f=fixture();f.host_id='other-host';assert.equal(project(f).state,'UNKNOWN');});
test('source changed while observing',()=>{const f=fixture();f.stable=false;assert.equal(project(f).state,'UNKNOWN');});
test('missing process data',()=>{const f=fixture();f.checks={};assert.equal(project(f).state,'UNKNOWN');});
test('terminal null exit is not zero',()=>{const f=fixture();f.state.state='COMPLETE';f.result={job_id:B.job_id,state:'COMPLETE',exit_code:null,ended_utc:START};Object.assign(f.checks.child,{identity:'RECORDED_PROCESS_NOT_PRESENT',query_status:'NOT_PRESENT',current_creation_utc:null});assert.equal(project(f).state,'UNKNOWN');});
for(const state of ['QUEUED','WAITING_RESOURCE','BLOCKED'])test('explicit durable '+state,()=>{const f=fixture();f.state.state=state;f.state.child_pid=null;assert.equal(project(f).state,state);});
test('invalid calendar date',()=>assert.equal(api.precise('2026-02-30T00:00:00Z'),null));
test('precise timezone equivalence',()=>assert.equal(api.precise(CREATED),api.precise('2026-10-04T08:00:00.1234567+07:00')));
const ctx={jobs:[{job_id:B.job_id,base_sha:B.base_sha,worktree:B.worktree}],lanes:[{lane_id:B.lane_id,head_sha:B.base_sha,worktree:B.worktree}]};
test('service binds only server job ids',()=>{let calls=0;const service=api.createService(ctx,()=>{calls++;return fixture();},()=>END);assert.throws(()=>service.get('../evil'));assert.throws(()=>service.get('unbound-job'));assert.equal(calls,0);});
test('ambiguous lane -> UNKNOWN no observer call',()=>{let calls=0;const c={...ctx,lanes:[...ctx.lanes,{...ctx.lanes[0],lane_id:'other-lane'}]};const service=api.createService(c,()=>calls++);assert.equal(service.get(B.job_id).state,'UNKNOWN');assert.equal(calls,0);});
test('observer error -> UNKNOWN',()=>{const service=api.createService(ctx,()=>{throw Error('fixture');});assert.equal(service.get(B.job_id).state,'UNKNOWN');});
test('old 14 tool implementations byte-equivalent after removing two integration lines',()=>{
 const current=fs.readFileSync(path.join(__dirname,'EA_LAB_CurrentWrite_V1_HTTP_Gateway.cjs'),'utf8');
 const baseline=fs.readFileSync('D:\\EA_LAB_CONTROL\\lnwjud-write-v1-20260928\\canonical\\tools\\lnwjud\\current_write_v1\\EA_LAB_CurrentWrite_V1_HTTP_Gateway.cjs','utf8');
 const stripped=current.replace("const executionIdentity = require('./execution_identity.cjs');\n\n",'')
 .replace("  executionIdentity.registerTools(server, z, ctx);\n\n",'');
 assert.equal(stripped,baseline);
 assert.equal((baseline.match(/server\.registerTool\(/g)||[]).length,14);
});
test('gateway registers old 14 plus two typed tools without running observer',()=>{
 const registrations=[];
 class FakeServer{constructor(){} registerTool(...args){registrations.push(args);} }
 const schema={strict(){return this;},regex(){return this;},optional(){return this;},int(){return this;},min(){return this;},max(){return this;}};
 const z=new Proxy({}, {get:()=>()=>schema});
 const source=fs.readFileSync(path.join(__dirname,'EA_LAB_CurrentWrite_V1_HTTP_Gateway.cjs'),'utf8');
 const sandbox={module:{exports:{}},require: name=>name.includes('@modelcontextprotocol')?{McpServer:FakeServer}:name.includes('zod')?z:name==='./execution_identity.cjs'?api:require(name),process:{env:{}},Buffer,console};
 vm.runInNewContext(source+'\nmodule.exports._testBuild=buildServer;',sandbox);
 sandbox.module.exports._testBuild({...ctx,seal:{},canonical:{},evidence:[],monitor:{}});
 assert.equal(registrations.length,16);
 assert.deepEqual(registrations.slice(0,2).map(x=>x[0]),['list_active_executions','get_execution_identity']);
});
console.log(JSON.stringify({status:'PASS',tests:count,evidence:'SYNTHETIC_FIXTURE',real_live_proof:false,runtime_activated:false}));


// Targeted repair 1/1: incomplete process evidence is not observed disagreement.
for(const role of ['child','runner'])for(const field of ['pid','expected_creation_utc','current_creation_utc'])
 for(const value of [null,undefined,'',false,'malformed'])test('incomplete check '+role+' '+field+' '+String(value),()=>{
  const f=fixture();f.checks[role][field]=value;assert.equal(project(f).state,'UNKNOWN');
 });
for(const field of ['expected_creation_utc','current_creation_utc'])test('future check '+field,()=>{
 const f=fixture();f.checks.child[field]=END;assert.equal(project(f).state,'UNKNOWN');
});
for(const field of ['pid','expected_creation_utc','current_creation_utc'])test('valid observed disagreement '+field,()=>{
 const f=fixture();f.checks.child[field]=field==='pid'?457:START;assert.equal(project(f).state,'IDENTITY_MISMATCH');
});
for(const query of ['INACCESSIBLE','ERROR',null])test('unobservable query '+query,()=>{
 const f=fixture();f.checks.child.query_status=query;assert.equal(project(f).state,'UNKNOWN');
});
test('different-creation label without observed creation remains unknown',()=>{
 const f=fixture();f.checks.child.identity='DIFFERENT_CREATION_IDENTITY';f.checks.child.current_creation_utc=null;
 assert.equal(project(f).state,'UNKNOWN');
});
test('different-creation label alone is not material observed disagreement',()=>{
 const f=fixture();f.checks.child.identity='DIFFERENT_CREATION_IDENTITY';assert.equal(project(f).state,'UNKNOWN');
});
test('missing observed creation takes precedence over differing expected pid',()=>{
 const f=fixture();f.checks.child.pid=457;f.checks.child.current_creation_utc=null;assert.equal(project(f).state,'UNKNOWN');
});

// V2 contract: unknown evidence dominates all comparisons and every applicable stage.
function terminalFixture(){
 const f=fixture();f.state.state='COMPLETE';
 f.job.postcondition_file_path='C:\\fixture\\verify.exe';
 f.state.postcondition_pid=789;f.state.postcondition_start_utc=CREATED;
 f.result={job_id:B.job_id,state:'COMPLETE',exit_code:0,postcondition_exit_code:0,ended_utc:START};
 f.checks.postcondition={...f.checks.child,role:'postcondition',pid:789};
 for(const role of ['child','postcondition'])Object.assign(f.checks[role],{identity:'RECORDED_PROCESS_NOT_PRESENT',query_status:'NOT_PRESENT',current_creation_utc:null});
 return f;
}
for(const field of ['postcondition_pid','postcondition_start_utc'])test('V2 configured postcondition missing '+field,()=>{
 const f=terminalFixture();f.state[field]=null;const r=project(f);assert.equal(r.state,'UNKNOWN');assert.equal(r.reason,'POSTCONDITION_IDENTITY_UNPROVEN');
});
for(const kind of ['unknown','missing','stale','future'])test('V2 postcondition '+kind+' evidence stays unproven',()=>{
 const f=terminalFixture();
 if(kind==='unknown')Object.assign(f.checks.postcondition,{identity:'UNKNOWN',query_status:'ERROR'});
 if(kind==='missing')delete f.checks.postcondition;
 if(kind==='stale')f.checks.postcondition.checked_utc=CREATED;
 if(kind==='future')f.checks.postcondition.checked_utc=END;
 assert.equal(project(f).state,'UNKNOWN');assert.equal(project(f).reason,'POSTCONDITION_IDENTITY_UNPROVEN');
});
test('V2 qualified child AND postcondition terminal',()=>assert.equal(project(terminalFixture()).state,'PROVEN_TERMINAL'));
test('V2 live postcondition cannot be terminal',()=>{
 const f=terminalFixture();Object.assign(f.checks.postcondition,{identity:'MATCHING_RECORDED_PROCESS',query_status:'PRESENT',current_creation_utc:CREATED});
 assert.equal(project(f).state,'UNKNOWN');
});
test('V2 future image creation is UNKNOWN',()=>{const f=fixture();f.images.child.creation_utc=END;assert.equal(project(f).state,'UNKNOWN');});
test('V2 stale image AND wrong executable is UNKNOWN first',()=>{
 const f=fixture();f.images.child.checked_utc=CREATED;f.images.child.executable_path='C:\\other.exe';assert.equal(project(f).state,'UNKNOWN');
});
for(const [object,field] of [['job','job_id'],['job','base_sha'],['lane','worktree'],['job','file_path'],['check','job_id']])
 for(const value of [null,undefined,'',false,{}])test('V2 unproven binding '+object+'.'+field+' '+String(value),()=>{
  const f=fixture();(object==='check'?f.checks.child:f[object])[field]=value;assert.equal(project(f).state,'UNKNOWN');
 });
for(const role of ['runner','child','postcondition'])for(const field of ['job_id','lane_id','role','pid','expected_creation_utc','checked_utc'])
 test('V2 terminal/active missing check '+role+'.'+field,()=>{
  const f=role==='postcondition'?terminalFixture():fixture();f.checks[role][field]=null;assert.equal(project(f).state,'UNKNOWN');
 });
test('V2 valid executable disagreement is mismatch',()=>{const f=fixture();f.images.child.executable_path='C:\\other.exe';assert.equal(project(f).state,'IDENTITY_MISMATCH');});
test('V2 valid creation disagreement is mismatch',()=>{const f=fixture();f.checks.child.current_creation_utc=START;assert.equal(project(f).state,'IDENTITY_MISMATCH');});
test('V2 missing postcondition wins over valid child disagreement',()=>{
 const f=terminalFixture();f.checks.child.pid=999;f.state.postcondition_pid=null;assert.equal(project(f).state,'UNKNOWN');
});
test('V2 missing image wins over valid job disagreement',()=>{const f=fixture();f.job.job_id='other-job';f.images.child=null;assert.equal(project(f).state,'UNKNOWN');});
test('V2 relative expected executable is unknown',()=>{const f=fixture();f.job.file_path='node.exe';assert.equal(project(f).state,'UNKNOWN');});
test('V2 relative observed executable is unknown',()=>{const f=fixture();f.images.child.executable_path='node.exe';assert.equal(project(f).state,'UNKNOWN');});
test('V2 valid postcondition running',()=>{
 const f=terminalFixture();f.state.state='POSTCONDITION_RUNNING';f.result=null;
 Object.assign(f.checks.postcondition,{identity:'MATCHING_RECORDED_PROCESS',query_status:'PRESENT',current_creation_utc:CREATED});
 f.images.postcondition={pid:789,creation_utc:CREATED,executable_path:f.job.postcondition_file_path,checked_utc:OBS};
 assert.equal(project(f).state,'PROVEN_RUNNING');
});
test('V2 postcondition running missing child evidence',()=>{
 const f=terminalFixture();f.state.state='POSTCONDITION_RUNNING';f.result=null;delete f.checks.child;
 assert.equal(project(f).state,'UNKNOWN');
});
test('V2 unknown and mismatch remain active; only proven terminal excluded',()=>{
 for(const [make,expected] of [
  [()=>{const f=terminalFixture();f.state.postcondition_pid=null;return f;},'UNKNOWN'],
  [()=>{const f=fixture();f.images.child.executable_path='C:\\other.exe';return f;},'IDENTITY_MISMATCH'],
  [terminalFixture,'PROVEN_TERMINAL']]){
   let tick=0;const service=api.createService(ctx,make,()=>tick++%2===0?START:END);
   const rows=service.list().executions;assert.equal(rows.length,expected==='PROVEN_TERMINAL'?0:1);
   if(rows.length)assert.equal(rows[0].state,expected);
 }
});
test('V2 malformed server source binding remains inventory UNKNOWN without observation',()=>{
 let calls=0;const service=api.createService({...ctx,jobs:[{...ctx.jobs[0],base_sha:null}]},()=>calls++);
 const r=service.list().executions;assert.equal(r.length,1);assert.equal(r[0].state,'UNKNOWN');assert.equal(calls,0);
});

// Verifier contract fixtures: original A2 bytes copied into isolated temporary roots.
const os=require('node:os');
const crypto=require('node:crypto');
const verifier=require('./verify_current_source_hashes.cjs');
const canonical='D:\\EA_LAB_CONTROL\\lnwjud-write-v1-20260928\\canonical';
const receiptRel='tools/lnwjud/current_write_v1/CURRENT_SOURCE_SHA256.json';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const originalReceipt=fs.readFileSync(path.join(canonical,receiptRel));
assert.equal(sha(originalReceipt),'ade1b32549b91db9c81a7a402c3e7ec7ab51cfeae6ae4b813cbe6bbeeae5558f');
const legacyReceipt=JSON.parse(originalReceipt);
const verifierRel='tools/lnwjud/current_write_v1/verify_current_source_hashes.cjs';
const oldVerifier=fs.readFileSync(path.join(canonical,verifierRel),'utf8');
assert.equal(sha(Buffer.from(oldVerifier)),'6a662f9b2a188f169f1b543bae15ed682fe2da3e518dbc740b30717128440cf1');
const newVerifier=fs.readFileSync(path.join(__dirname,'verify_current_source_hashes.cjs'),'utf8');
function writeFixture(root,rel,bytes){const f=path.join(root,rel);fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,bytes);}
function executeVerifier(root,old=false,fakeFs=fs){
  if(!old && fakeFs===fs)return verifier.verify(root);
  const sandbox={__dirname:path.join(root,'tools/lnwjud/current_write_v1'),module:{exports:{}},
    require:name=>name==='node:fs'?fakeFs:require(name),console:{log(){}},Buffer};
  vm.runInNewContext(old?oldVerifier:newVerifier,sandbox);
  if(!old)return sandbox.module.exports.verify(root);
}
function withVerifierFixture(successor,action){
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'lnwjud-source-contract-'));
 try{
  for(const entry of legacyReceipt.files)writeFixture(root,entry.path,fs.readFileSync(path.join(canonical,entry.path)));
  writeFixture(root,receiptRel,originalReceipt);
  if(successor){
   for(const name of fs.readdirSync(__dirname)){
    if(name===path.basename(receiptRel))continue;
    const f=path.join(__dirname,name);
    if(fs.statSync(f).isFile())writeFixture(root,'tools/lnwjud/current_write_v1/'+name,fs.readFileSync(f));
   }
   const doc='docs/workflows/LNWJUD_EXECUTION_IDENTITY_SOURCE_V1.md';
   writeFixture(root,doc,fs.readFileSync(path.resolve(__dirname,'../../..',doc)));
   const receipt={schema:'lnwjud_write_v1_current_source_hashes/1',
    contract_id:'LNWJUD-EXECUTION-IDENTITY-READ-V1-20261004',
    parent_contract:'LNWJUD-S1-AMENDMENT-A2-20260930',
    predecessor_manifest_sha256:sha(originalReceipt),
    base_head:B.base_sha,base_tree:'bb1dbea90d1de8097db9e1b50736722b13211257',
    scope_amendment_authority_sha256:'fb8d850c87872683d503972d1bd89faf55458d55123ad73fb45cf314a8007012',
    algorithm:'SHA256',self_hash_excluded:receiptRel,files:[]};
   const rels=[...legacyReceipt.files.map(x=>x.path),
     'tools/lnwjud/current_write_v1/execution_identity.cjs',
     'tools/lnwjud/current_write_v1/test_execution_identity.cjs',doc];
   if(successor==='v2')Object.assign(receipt,{contract_id:'LNWJUD-EXECUTION-IDENTITY-READ-V2-20261004',parent_contract:'LNWJUD-EXECUTION-IDENTITY-READ-V1-20261004',parent_candidate:'1c66f77f96a88816c21f957cadd7569778e48feb',predecessor_manifest_sha256:'022bb2a734b643cff3391299e493506ca825541ff1b295d827c42e4f6a6310d8',scope_amendment_authority_sha256:'f4084d2583090020c2ef4efadb1d2472005a2a5a6f962514c10fad268e943fca'});
   receipt.files=rels.map(rel=>{const b=fs.readFileSync(path.join(root,rel));return {path:rel,sha256:sha(b),bytes:b.length};});
   writeFixture(root,receiptRel,JSON.stringify(receipt));
  }
  action(root);
 }finally{
  const resolved=path.resolve(root), parent=path.resolve(os.tmpdir())+path.sep;
  assert.ok(resolved.startsWith(parent)&&path.basename(resolved).startsWith('lnwjud-source-contract-'));
  fs.rmSync(resolved,{recursive:true,force:true});
 }
}
function mutateReceipt(root,fn){const f=path.join(root,receiptRel);const r=JSON.parse(fs.readFileSync(f));fn(r);fs.writeFileSync(f,JSON.stringify(r));}
function bothReject(root){assert.throws(()=>executeVerifier(root,true));assert.throws(()=>executeVerifier(root,false));}
test('original exact A2 bytes pass original and successor-aware verifier',()=>withVerifierFixture(false,root=>{
 executeVerifier(root,true);assert.equal(executeVerifier(root).contract_id,'LNWJUD-S1-AMENDMENT-A2-20260930');
}));
for(const field of ['schema','contract_id','parent_contract','parent_amendment','base_head','base_tree','algorithm','self_hash_excluded'])
 test('legacy pin tamper rejected by both: '+field,()=>withVerifierFixture(false,root=>{mutateReceipt(root,r=>r[field]='TAMPER');bothReject(root);}));
for(const kind of ['missing','extra','duplicate','length','hash'])
 test('legacy manifest '+kind+' rejected by both',()=>withVerifierFixture(false,root=>{
  mutateReceipt(root,r=>{
   if(kind==='missing')r.files.pop();
   if(kind==='extra')r.files.push({path:'tools/lnwjud/current_write_v1/missing.txt',bytes:0,sha256:sha(Buffer.alloc(0))});
   if(kind==='duplicate')r.files.push({...r.files[0]});
   if(kind==='length')r.files[0].bytes++;
   if(kind==='hash')r.files[0].sha256='0'.repeat(64);
  });bothReject(root);
 }));
test('legacy invalid UTF8 rejected by both even with matching digest',()=>withVerifierFixture(false,root=>{
 const rel=legacyReceipt.files[0].path,bytes=Buffer.from([0xff]);
 writeFixture(root,rel,bytes);mutateReceipt(root,r=>{r.files[0].bytes=1;r.files[0].sha256=sha(bytes);});bothReject(root);
}));
test('legacy nested path rejected by both even when sealed',()=>withVerifierFixture(false,root=>{
 const rel='tools/lnwjud/current_write_v1/nested/escape.txt',bytes=Buffer.from('x');
 writeFixture(root,rel,bytes);mutateReceipt(root,r=>r.files.push({path:rel,bytes:1,sha256:sha(bytes)}));bothReject(root);
}));
test('legacy junction/reparse rejected by both',()=>withVerifierFixture(false,root=>{
 const target=path.join(root,'link-target');fs.mkdirSync(target);
 fs.symlinkSync(target,path.join(root,'tools/lnwjud/current_write_v1/link'),'junction');bothReject(root);
}));
test('legacy non-file directory entry rejected by both',()=>withVerifierFixture(false,root=>{
 const fake=Object.create(fs);fake.readdirSync=(p,opts)=>[
  ...fs.readdirSync(p,opts),{name:'nonfile',isSymbolicLink:()=>false,isDirectory:()=>false,isFile:()=>false}];
 assert.throws(()=>executeVerifier(root,true,fake));assert.throws(()=>executeVerifier(root,false,fake));
}));
test('legacy A2 manifest plus successor files remains rejected',()=>withVerifierFixture(false,root=>{
 writeFixture(root,'tools/lnwjud/current_write_v1/execution_identity.cjs',Buffer.from('fixture'));
 bothReject(root);
}));
test('successor exact profile passes',()=>withVerifierFixture(true,root=>assert.equal(executeVerifier(root).files,17)));
for(const field of ['schema','contract_id','parent_contract','predecessor_manifest_sha256','base_head','base_tree','scope_amendment_authority_sha256','algorithm','self_hash_excluded'])
 test('successor binding tamper rejected: '+field,()=>withVerifierFixture(true,root=>{
  mutateReceipt(root,r=>r[field]='TAMPER');assert.throws(()=>executeVerifier(root));
 }));
for(const kind of ['missing','extra','duplicate','length','hash'])
 test('successor '+kind+' rejected',()=>withVerifierFixture(true,root=>{
  mutateReceipt(root,r=>{
   if(kind==='missing')r.files.pop();
   if(kind==='duplicate')r.files.push({...r.files[0]});
   if(kind==='length')r.files[0].bytes++;
   if(kind==='hash')r.files[0].sha256='0'.repeat(64);
   if(kind==='extra'){const rel='tools/lnwjud/current_write_v1/unadmitted.txt';writeFixture(root,rel,Buffer.from('x'));r.files.push({path:rel,bytes:1,sha256:sha(Buffer.from('x'))});}
  });assert.throws(()=>executeVerifier(root));
 }));
test('successor cannot downgrade to legacy profile',()=>withVerifierFixture(true,root=>{
 mutateReceipt(root,r=>Object.assign(r,{contract_id:legacyReceipt.contract_id,parent_contract:legacyReceipt.parent_contract,
 parent_amendment:legacyReceipt.parent_amendment,base_head:legacyReceipt.base_head,base_tree:legacyReceipt.base_tree}));
 assert.throws(()=>executeVerifier(root));
}));
test('V2 explicit exact profile passes',()=>withVerifierFixture('v2',root=>{
 assert.equal(executeVerifier(root).contract_id,'LNWJUD-EXECUTION-IDENTITY-READ-V2-20261004');
 assert.equal(executeVerifier(root).files,17);
}));
for(const field of ['schema','contract_id','parent_contract','parent_candidate','predecessor_manifest_sha256','base_head','base_tree','scope_amendment_authority_sha256','algorithm','self_hash_excluded'])
 test('V2 pin tamper refuses '+field,()=>withVerifierFixture('v2',root=>{
  mutateReceipt(root,r=>r[field]='TAMPER');assert.throws(()=>executeVerifier(root));
 }));
for(const kind of ['missing','extra','duplicate','length','hash'])
 test('V2 scope/bytes tamper refuses '+kind,()=>withVerifierFixture('v2',root=>{
  mutateReceipt(root,r=>{
   if(kind==='missing')r.files.pop();
   if(kind==='extra')r.files.push({path:'tools/lnwjud/current_write_v1/extra.txt',bytes:0,sha256:sha(Buffer.alloc(0))});
   if(kind==='duplicate')r.files.push({...r.files[0]});
   if(kind==='length')r.files[0].bytes++;
   if(kind==='hash')r.files[0].sha256='0'.repeat(64);
  });assert.throws(()=>executeVerifier(root));
 }));
test('V2 cannot masquerade as historical V1',()=>withVerifierFixture('v2',root=>{
 mutateReceipt(root,r=>r.contract_id='LNWJUD-EXECUTION-IDENTITY-READ-V1-20261004');assert.throws(()=>executeVerifier(root));
}));
test('exact preserved V1 source manifest still accepted unchanged',()=>withVerifierFixture(true,root=>{
 const frozen='D:\\EA_LAB_CONTROL\\evidence\\lnwjud-execution-identity-v1-20261004\\candidate-repair1-frozen-v2\\source';
 const b=fs.readFileSync(path.join(frozen,receiptRel));assert.equal(sha(b),'022bb2a734b643cff3391299e493506ca825541ff1b295d827c42e4f6a6310d8');
 const r=JSON.parse(b);for(const f of r.files)writeFixture(root,f.path,fs.readFileSync(path.join(frozen,f.path)));
 writeFixture(root,receiptRel,b);assert.equal(executeVerifier(root).contract_id,'LNWJUD-EXECUTION-IDENTITY-READ-V1-20261004');
}));

console.log(JSON.stringify({status:'PASS',tests:count,evidence:'SYNTHETIC_IDENTITY_AND_ISOLATED_VERIFIER_FIXTURES',real_live_proof:false,runtime_activated:false}));


async function existingHandlerBehaviorRegression(){
 const gatewayRel='tools/lnwjud/current_write_v1/EA_LAB_CurrentWrite_V1_HTTP_Gateway.cjs';
 const originals=fs.readFileSync(path.join(canonical,gatewayRel),'utf8');
 const candidate=fs.readFileSync(path.join(__dirname,'EA_LAB_CurrentWrite_V1_HTTP_Gateway.cjs'),'utf8');
 const names=['ea_lab_current_status','read_canonical_file','list_lanes','get_lane','list_jobs','get_job',
  'list_evidence','read_evidence','monitor_summary','ea_lab_write_status','refresh_write_workspace',
  'read_workspace_file','edit_workspace_file','workspace_diff'];
 async function run(source){
  const root=fs.mkdtempSync(path.join(os.tmpdir(),'lnwjud-handler-fixture-'));
  const write=path.join(root,'workspace'),can=path.join(root,'canonical'),ev=path.join(root,'evidence');
  for(const d of [write,can,ev])fs.mkdirSync(d);
  const initial=Buffer.from('alpha\n');
  fs.writeFileSync(path.join(write,'README.md'),initial);
  fs.writeFileSync(path.join(can,'fixture.md'),initial);
  fs.writeFileSync(path.join(ev,'fixture.txt'),initial);
  const virtual='D:\\EA_LAB_CONTROL\\lnwjud-write-v1-20260928';
  const map=p=>{
   if(typeof p!=='string')return p;
   if(p.toLowerCase()===virtual.toLowerCase())return root;
   if(p.toLowerCase().startsWith(virtual.toLowerCase()+'\\'))return path.join(root,p.slice(virtual.length+1));
   const full=path.resolve(p);
   if(full===root||full.startsWith(root+path.sep))return full;
   throw Error('fixture filesystem escaped: '+p);
  };
  const fakeFs=Object.create(fs);
  for(const method of ['readFileSync','statSync','existsSync','openSync','unlinkSync','writeFileSync'])
   fakeFs[method]=(p,...args)=>fs[method](map(p),...args);
  fakeFs.renameSync=(a,b)=>fs.renameSync(map(a),map(b));
  fakeFs.linkSync=(a,b)=>fs.linkSync(map(a),map(b));
  fakeFs.realpathSync=Object.assign(p=>fs.realpathSync(map(p)),{native:p=>fs.realpathSync.native(map(p))});
  let badOrigin=false;
  const effects=[];
  const fakeChild={spawnSync(exe,args){
   assert.equal(exe,'C:\\Program Files\\Git\\cmd\\git.exe');
   effects.push(args);
   let stdout='',status=0;
   if(args[0]==='remote')stdout=badOrigin?'https://invalid.example/foreign.git\n':'https://github.com/BaBosss/EA_LAB.git\n';
   else if(args[0]==='rev-parse')stdout=args.includes('--abbrev-ref')?'lnwjud/write-runtime-20260928\n':B.base_sha+'\n';
   else if(args[0]==='status')stdout=fs.readFileSync(path.join(write,'README.md')).equals(initial)?'':' M README.md\n';
   else if(args[0]==='ls-files')stdout='README.md\n';
   else if(args[0]==='ls-remote')stdout=B.base_sha+'\trefs/heads/master\n';
   else if(args[0]==='diff')stdout=fs.readFileSync(path.join(write,'README.md')).equals(initial)?'':'fixture diff\n';
   else if(args[0]==='check-ignore')status=1;
   else if(!['fetch','merge-base','merge'].includes(args[0]))throw Error('unadmitted fixture git operation');
   return {status,stdout,stderr:''};
  }};
  const registrations=new Map();
  class FakeServer{registerTool(name,meta,fn){registrations.set(name,{meta,fn});}}
  class FixedDate extends Date{constructor(...args){super(...(args.length?args:[END]));}static now(){return Date.parse(END);}}
  const sandbox={module:{exports:{}},process:{env:{},pid:123},Buffer,console,Date:FixedDate,
    require:n=>n==='node:fs'?fakeFs:n==='node:child_process'?fakeChild:
    n.includes('@modelcontextprotocol')?{McpServer:FakeServer}:n==='./execution_identity.cjs'?api:require(n)};
  try{
   vm.runInNewContext(source+'\nmodule.exports._testBuild=buildServer;',sandbox);
   const entry=p=>({path:p,path_key:p,sha256:sha(initial),bytes:initial.length});
   const context={seal:{snapshot_id:'fixture-snapshot',captured_at_utc:START,canonical_head:B.base_sha,
    origin_master_at_capture:B.base_sha,ls_remote_at_capture:B.base_sha,authority:'READ_ONLY_CURRENT_SNAPSHOT_V2',counts:{},limitations:[]},
    canonical:{},lanes:[{lane_id:B.lane_id,state:'RUNNING',writer:true}],jobs:[{job_id:B.job_id,state:'RUNNING'}],
    evidence:[entry('fixture.txt')],monitor:{delivery_receipt:{fixture:true},inventory_summary:{fixture:true}},
    canonicalRootReal:can,evidenceRootReal:ev,writeRootReal:write,
    canonicalMap:new Map([['fixture.md',entry('fixture.md')]]),evidenceMap:new Map([['fixture.txt',entry('fixture.txt')]])};
   sandbox.module.exports._testBuild(context);
   const output=[];
   const call=async(name,input,ok)=>{
    const registration=registrations.get(name);assert.ok(registration);
    const value=await registration.fn(registration.meta.inputSchema.parse(input));
    assert.equal(value.isError===true,!ok,name+' expected result polarity');
    output.push([name,JSON.parse(JSON.stringify(value))]);
   };
   const snap={snapshotId:'fixture-snapshot'};
   await call(names[0],{},true);
   await call(names[1],{...snap,path:'fixture.md'},true);
   await call(names[2],{...snap,states:['RUNNING'],writerOnly:true,limit:1},true);
   await call(names[3],{...snap,laneId:B.lane_id},true);
   await call(names[4],{...snap,states:['RUNNING'],limit:1},true);
   await call(names[5],{...snap,jobId:B.job_id},true);
   await call(names[6],{...snap,query:'fixture',limit:1},true);
   await call(names[7],{...snap,path:'fixture.txt'},true);
   await call(names[8],snap,true);
   await call(names[9],{},true);
   await call(names[10],{expectedHead:B.base_sha},true); // Git backend simulated; no fetch.
   await call(names[11],{path:'README.md'},true);
   await call(names[12],{operation:'replace_exact',path:'README.md',expectedSha256:sha(initial),oldText:'alpha',newText:'beta'},true);
   await call(names[13],{path:'README.md'},true);
   await call(names[10],{expectedHead:B.base_sha},false);
   await call(names[12],{operation:'replace_exact',path:'README.md',expectedSha256:sha(initial),oldText:'beta',newText:'gamma'},false);
   await call(names[12],{operation:'create_new',path:'new.txt',newText:'fixture new'},true);
   await call(names[12],{operation:'create_new',path:'new.txt',newText:'again'},false);
   await call(names[11],{path:'../escape'},false);
   await call(names[13],{path:'.git/config'},false);
   await call(names[1],{snapshotId:'wrong',path:'fixture.md'},false);
   await call(names[7],{...snap,path:'../escape'},false);
   await call(names[3],{...snap,laneId:'absent-lane'},false);
   await call(names[5],{...snap,jobId:'absent-job'},false);
   fs.writeFileSync(path.join(can,'fixture.md'),'drift\n');
   await call(names[1],{...snap,path:'fixture.md'},false);
   badOrigin=true;
   await call(names[9],{},false);
   for(const name of names)assert.throws(()=>registrations.get(name).meta.inputSchema.parse({unexpected:true}));
   return {output,effects,bytes:fs.readFileSync(path.join(write,'README.md')).toString()};
  }finally{
   const full=path.resolve(root);
   assert.ok(full.startsWith(path.resolve(os.tmpdir())+path.sep)&&path.basename(full).startsWith('lnwjud-handler-fixture-'));
   fs.rmSync(full,{recursive:true,force:true});
  }
 }
 const old=await run(originals),fresh=await run(candidate);
 // Temporary root identity is fixture-local; normalize only these generated roots.
 const normalize=x=>JSON.stringify(x).replace(/[A-Za-z]:\\\\[^"]*?lnwjud-handler-fixture-[^\\"]+/g,'FIXTURE_ROOT');
 assert.equal(normalize(fresh),normalize(old));
 console.log(JSON.stringify({suite:'EXISTING_14_HANDLER_BEHAVIOR',result:'PASS',handlers:14,
   cases_per_version:old.output.length,strict_schema_cases_per_version:14,real_git:false,
   actual_runtime_workspace_touched:false,client_write_acceptance:false,runtime_activation:'NOT_RUN'}));
}
existingHandlerBehaviorRegression().catch(error=>{console.error(error);process.exitCode=1;});
