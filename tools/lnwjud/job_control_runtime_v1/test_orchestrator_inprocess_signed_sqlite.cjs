'use strict';
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {generateKeyPairSync,sign,createHash}=require('node:crypto'),{spawnSync,spawn}=require('node:child_process');
const {messageForEnvelope}=require('./orchestrator_signed_claim_ingress.cjs');
const {createInprocessSignedSQLite}=require('./orchestrator_inprocess_signed_sqlite.cjs');
const H='30600b20969978ff398027b69cfebd2dfac5f4fc',T='5ac6b00032f58d2614e61341e8068e184a31ca74',NOW='2026-10-11T14:00:00Z';
const sha=b=>createHash('sha256').update(b).digest('hex');
function context(){
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'ea-lab-p3-src-'));const db=path.join(root,'proof.sqlite3');
 const kp=generateKeyPairSync('ed25519');
 const anchor={signer_id:'FixtureIssuer',key_id:'FixtureKey',public_key_pem:kp.publicKey.export({type:'spki',format:'pem'}),valid_from_utc:'2026-10-11T13:00:00Z',valid_until_utc:'2026-10-11T15:00:00Z',revoked:false,role:'T3C_P2_ISOLATED_SIGNED_CLAIM'};
 function make({owner='fixture-owner',lease_id='lease-a',resource='resource-a',seq=1,idem='idem-a',body='evidence-one',source_head=H}={}){
  const evidence=Buffer.from(body);
  const claim={schema:'EA_LAB_T3C_P1_SIGNED_CLAIM_V1',source_head,source_tree:T,resource,owner,lease_id,lease_until_utc:'2026-10-11T14:03:00Z',sequence:seq,idempotency_key:idem,signed_proof_sha256:sha(evidence),can_execute:false,can_submit:false};
  const env={schema:'EA_LAB_T3C_P2_SIGNED_CLAIM_ENVELOPE_V1',signer_id:anchor.signer_id,key_id:anchor.key_id,captured_utc:'2026-10-11T13:59:30Z',claim,signature:''};
  env.signature=sign(null,messageForEnvelope(env),kp.privateKey).toString('base64url');
  return {env,evidence};
 }
 const open=()=>createInprocessSignedSQLite({root,db_path:db,source_head:H,source_tree:T,anchor,clock:()=>NOW});
 const cleanup=()=>fs.rmSync(root,{recursive:true,force:true,maxRetries:6,retryDelay:120});
 return {root,db,anchor,kp,open,make,cleanup};
}
function it(name,fn){test(name,()=>{const c=context();try{return fn(c)}finally{c.cleanup()}})}
if(process.argv[2]!=='--worker'){
it('01 signed envelope accepted and stored READONLY',c=>{const x=c.make();const r=c.open().verifyAndRecord(x.env,x.evidence);a.equal(r.status,'VERIFIED_AND_RECORDED_READ_ONLY');a.equal(r.can_execute,false);a.equal(r.can_submit,false);a.equal(c.open().historyCount(),1)});
it('02 no separate public raw-ledger method',c=>{const api=c.open();a.deepEqual(Object.keys(api).sort(),['historyCount','verifyAndRecord']);a.equal(api.record,undefined)});
it('03 authentic replay blocked after reopen',c=>{const x=c.make();c.open().verifyAndRecord(x.env,x.evidence);a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'UNKNOWN');a.equal(c.open().historyCount(),1)});
it('04 forged owner denied before database insert',c=>{const x=c.make();x.env.claim.owner='evil-owner';a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'BLOCKED');a.equal(c.open().historyCount(),0)});
it('05 wrong evidence digest denied',c=>{const x=c.make();a.equal(c.open().verifyAndRecord(x.env,Buffer.from('other')).status,'BLOCKED');a.equal(c.open().historyCount(),0)});
it('06 foreign Ed25519 signing key denied',c=>{const x=c.make();x.env.signature=sign(null,messageForEnvelope(x.env),generateKeyPairSync('ed25519').privateKey).toString('base64url');a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'BLOCKED')});
it('07 execution authorization cannot be signed into ledger',c=>{const x=c.make();x.env.claim.can_execute=true;a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'BLOCKED');a.equal(c.open().historyCount(),0)});
it('08 extra envelope field fails closed',c=>{const x=c.make();x.env.allow_live=true;a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'BLOCKED')});
it('09 changed source HEAD fails closed',c=>{const x=c.make({source_head:'e'.repeat(40)});a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'BLOCKED')});
it('10 unique later same owner sequence committed',c=>{let r=c.open().verifyAndRecord(...Object.values(c.make()));a.equal(r.status,'VERIFIED_AND_RECORDED_READ_ONLY');const y=c.make({seq:2,idem:'idem-b',body:'evidence-two'});r=c.open().verifyAndRecord(y.env,y.evidence);a.equal(r.status,'VERIFIED_AND_RECORDED_READ_ONLY');a.equal(c.open().historyCount(),2)});
it('11 historical signed digest replay blocked across resource',c=>{let x=c.make();c.open().verifyAndRecord(x.env,x.evidence);x=c.make({resource:'resource-b',idem:'idem-b'});a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'UNKNOWN');a.equal(c.open().historyCount(),1)});
it('12 foreign active lease refused',c=>{let x=c.make();c.open().verifyAndRecord(x.env,x.evidence);x=c.make({owner:'another-owner',lease_id:'lease-b',seq:2,idem:'idem-b',body:'evidence-two'});a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'UNKNOWN');a.equal(c.open().historyCount(),1)});
it('13 nonmonotonic sequence refused',c=>{let x=c.make();c.open().verifyAndRecord(x.env,x.evidence);x=c.make({seq:1,idem:'idem-b',body:'evidence-two'});a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'UNKNOWN')});
it('14 replay idempotency even with different proof',c=>{let x=c.make();c.open().verifyAndRecord(x.env,x.evidence);x=c.make({seq:2,idem:'idem-a',body:'evidence-two'});a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'UNKNOWN')});
it('15 unsigned claim alone cannot be persisted',c=>{const x=c.make();a.equal(c.open().verifyAndRecord(x.env.claim,x.evidence).status,'BLOCKED');a.equal(c.open().historyCount(),0)});
it('16 invalid trust anchor rejected',c=>{c.anchor.revoked=true;a.throws(()=>c.open(),/UNQUALIFIED_TRUST_ANCHOR/);});
it('17 path traversal denied',c=>a.throws(()=>createInprocessSignedSQLite({root:c.root,db_path:path.resolve(c.root,'..','outside.sqlite3'),source_head:H,source_tree:T,anchor:c.anchor,clock:()=>NOW}),/ISOLATED_PATH_INVALID/));
it('18 source tree mismatch denied',c=>{const x=c.make();x.env.claim.source_tree='a'.repeat(40);a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'BLOCKED')});
it('19 bad/malformed DB fails UNKNOWN rather than grant',c=>{fs.writeFileSync(c.db,'not-sqlite');const x=c.make();a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'UNKNOWN')});
it('20 same proof signed duplicate in different process persists',c=>{const x=c.make(),blob={root:c.root,db:c.db,anchor:c.anchor,env:x.env,evidence:x.evidence.toString('base64')};const p=spawnSync(process.execPath,[__filename,'--worker'],{input:JSON.stringify(blob),encoding:'utf8',timeout:15000});a.equal(p.status,0,p.stderr);a.equal(JSON.parse(p.stdout).status,'VERIFIED_AND_RECORDED_READ_ONLY');a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'UNKNOWN');a.equal(c.open().historyCount(),1)});
it('21 invalid claimed lease time denied',c=>{const x=c.make();x.env.claim.lease_until_utc='2026-10-11T13:59:59Z';a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'BLOCKED')});
it('22 authority flags constant false after success',c=>{const x=c.make();const r=c.open().verifyAndRecord(x.env,x.evidence);a.equal(r.can_submit,false);a.equal(r.can_execute,false)});
test('23 competing independent OS processes: one accepted same evidence',async()=>{
 const c=context();const x=c.make(),blob={root:c.root,db:c.db,anchor:c.anchor,env:x.env,evidence:x.evidence.toString('base64')};
 // Precreate schema to isolate true concurrent transaction contention.
 c.open().historyCount();
 const start=path.join(c.root,'start.flag');blob.start=start;const children=[];
 try{
  for(let i=0;i<2;i++)children.push(spawn(process.execPath,[__filename,'--worker'],{stdio:['pipe','pipe','pipe']}));
  const all=children.map(child=>new Promise((resolve,reject)=>{let out='',err='';child.stdout.on('data',b=>out+=b);child.stderr.on('data',b=>err+=b);child.on('error',reject);child.on('close',code=>resolve({pid:child.pid,code,out,err}))}));
  for(const child of children){child.stdin.end(JSON.stringify(blob))}
  await new Promise(r=>setTimeout(r,150));fs.writeFileSync(start,'GO');
  const results=await Promise.all(all);
  a.equal(results[0].code,0,results[0].err);a.equal(results[1].code,0,results[1].err);
  const statuses=results.map(x=>JSON.parse(x.out).status);
  a.equal(statuses.filter(x=>x==='VERIFIED_AND_RECORDED_READ_ONLY').length,1,JSON.stringify(statuses));
  a.equal(c.open().historyCount(),1);
  console.error('P3_PROCESS_PROOF='+JSON.stringify({pids:results.map(r=>r.pid),statuses,history:1}));
 }finally{for(const child of children){if(child.exitCode===null)child.kill()}c.cleanup()}
});
it('24 abrupt process exit after verified commit preserves replay tombstone',c=>{
 const x=c.make(),blob={root:c.root,db:c.db,anchor:c.anchor,env:x.env,evidence:x.evidence.toString('base64')};
 const r=spawnSync(process.execPath,[__filename,'--worker-crash-after'],{input:JSON.stringify(blob),encoding:'utf8',timeout:15000});
 a.equal(r.status,19,r.stderr);a.equal(c.open().historyCount(),1);
 a.equal(c.open().verifyAndRecord(x.env,x.evidence).status,'UNKNOWN');
});
it('25 unsigned subprocess cannot bypass verifier or persist any row',c=>{
 const x=c.make();x.env.signature='';
 const blob={root:c.root,db:c.db,anchor:c.anchor,env:x.env,evidence:x.evidence.toString('base64')};
 const r=spawnSync(process.execPath,[__filename,'--worker'],{input:JSON.stringify(blob),encoding:'utf8',timeout:15000});
 a.equal(r.status,0,r.stderr);a.equal(JSON.parse(r.stdout).status,'BLOCKED');a.equal(c.open().historyCount(),0);
});
}
if(process.argv[2]==='--worker'||process.argv[2]==='--worker-crash-after'){
 let s='';process.stdin.on('data',b=>s+=b).on('end',()=>{
  try{
   const x=JSON.parse(s);
   if(x.start){const start=Date.now();while(!fs.existsSync(x.start)){if(Date.now()-start>10000)throw Error('START_TIMEOUT');Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,10)}}
   const api=createInprocessSignedSQLite({root:x.root,db_path:x.db,source_head:H,source_tree:T,anchor:x.anchor,clock:()=>NOW});
   const r=api.verifyAndRecord(x.env,Buffer.from(x.evidence,'base64'));if(process.argv[2]==='--worker-crash-after'&&r.status==='VERIFIED_AND_RECORDED_READ_ONLY')process.exit(19);process.stdout.write(JSON.stringify(r));
  }catch(e){process.stderr.write(String(e));process.exitCode=9}
 });
}
