'use strict';
const {test}=require('node:test');
const a=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {createInprocessSignedSQLite}=require('./orchestrator_inprocess_signed_sqlite.cjs');
const {generateKeyPairSync,sign,createHash}=require('node:crypto');
const {messageForEnvelope}=require('./orchestrator_signed_claim_ingress.cjs');
const HEAD='63fa8f2d38571c1283f02f382ba989dacf65f96d';
const TREE='aa6c7ec45736507f942f3eeb799073f8d2472e37';
const NOW='2026-10-11T14:00:00Z';
const ROLE='T3C_P2_ISOLATED_SIGNED_CLAIM';

function createTestOnlyProducer(){
 const pair=generateKeyPairSync('ed25519');
 const anchor=Object.freeze({signer_id:'FixtureIssuer',key_id:'FixtureKey',public_key_pem:pair.publicKey.export({type:'spki',format:'pem'}),valid_from_utc:'2026-10-11T13:00:00Z',valid_until_utc:'2026-10-11T15:00:00Z',revoked:false,role:ROLE});
 function observe({evidence='synthetic observation only',source_head=HEAD,source_tree=TREE,resource='fixture-resource',owner='fixture-owner',lease_id='fixture-lease',lease_until_utc='2026-10-11T14:03:00Z',sequence=1,idempotency_key='fixture-idem-default',captured_utc='2026-10-11T13:59:30Z'}={}){
  const evidenceBytes=Buffer.from(evidence);
  const claim={schema:'EA_LAB_T3C_P1_SIGNED_CLAIM_V1',source_head,source_tree,resource,owner,lease_id,lease_until_utc,sequence,idempotency_key,signed_proof_sha256:createHash('sha256').update(evidenceBytes).digest('hex'),can_execute:false,can_submit:false};
  const envelope={schema:'EA_LAB_T3C_P2_SIGNED_CLAIM_ENVELOPE_V1',signer_id:anchor.signer_id,key_id:anchor.key_id,captured_utc,claim,signature:''};
  envelope.signature=sign(null,messageForEnvelope(envelope),pair.privateKey).toString('base64url');
  return {envelope,evidence:evidenceBytes};
 }
 return Object.freeze({anchor,observe});
}
function context(){
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'ea-lab-t3-test-producer-'));
 try{
  const producer=createTestOnlyProducer();
  const db_path=path.join(root,'producer.sqlite3');
  const open=(anchor=producer.anchor)=>createInprocessSignedSQLite({root,db_path,source_head:HEAD,source_tree:TREE,anchor,clock:()=>NOW});
  return {root,db_path,producer,open,cleanup:()=>fs.rmSync(root,{recursive:true,force:true,maxRetries:6,retryDelay:120}) };
 }catch(e){fs.rmSync(root,{recursive:true,force:true,maxRetries:6,retryDelay:120});throw e;}
}
function withContext(fn){const c=context();try{return fn(c)}finally{c.cleanup()}}

test('01 ephemeral producer signs a complete read-only observation accepted by P3',()=>withContext(c=>{
 a.deepEqual(Object.keys(c.producer).sort(),['anchor','observe']);
 a.equal(c.producer.anchor.role,ROLE);
 const x=c.producer.observe({evidence:'synthetic observation only'});
 a.equal(x.envelope.claim.source_head,HEAD);
 a.equal(x.envelope.claim.source_tree,TREE);
 a.equal(x.envelope.claim.can_execute,false);
 a.equal(x.envelope.claim.can_submit,false);
 const api=c.open();const r=api.verifyAndRecord(x.envelope,x.evidence);
 a.equal(r.status,'VERIFIED_AND_RECORDED_READ_ONLY');
 a.equal(r.can_execute,false);a.equal(r.can_submit,false);
 a.equal(api.historyCount(),1);
}));

test('02 post-sign owner mutation fails closed without a history write',()=>withContext(c=>{
 const x=c.producer.observe();x.envelope.claim.owner='foreign-owner';
 const api=c.open();a.equal(api.verifyAndRecord(x.envelope,x.evidence).status,'BLOCKED');
 a.equal(api.historyCount(),0);
}));

test('03 evidence bytes are bound to the signed digest',()=>withContext(c=>{
 const x=c.producer.observe();
 const api=c.open();a.equal(api.verifyAndRecord(x.envelope,Buffer.from('substituted evidence')).status,'BLOCKED');
 a.equal(api.historyCount(),0);
}));

test('04 a signed claim for a different source HEAD is rejected',()=>withContext(c=>{
 const x=c.producer.observe({source_head:'e'.repeat(40)});
 const api=c.open();a.equal(api.verifyAndRecord(x.envelope,x.evidence).status,'BLOCKED');
 a.equal(api.historyCount(),0);
}));

test('05 expired lease is rejected before persistence',()=>withContext(c=>{
 const x=c.producer.observe({lease_until_utc:'2026-10-11T13:59:59Z'});
 const api=c.open();a.equal(api.verifyAndRecord(x.envelope,x.evidence).status,'BLOCKED');
 a.equal(api.historyCount(),0);
}));

test('06 exact proof replay remains blocked after reopening P3',()=>withContext(c=>{
 const x=c.producer.observe();a.equal(c.open().verifyAndRecord(x.envelope,x.evidence).status,'VERIFIED_AND_RECORDED_READ_ONLY');
 a.equal(c.open().verifyAndRecord(x.envelope,x.evidence).status,'UNKNOWN');
 a.equal(c.open().historyCount(),1);
}));

test('07 sequence regression and foreign active lease cannot replace the current owner',()=>withContext(c=>{
 const first=c.producer.observe({sequence:3,idempotency_key:'fixture-idem-first',evidence:'first'});
 a.equal(c.open().verifyAndRecord(first.envelope,first.evidence).status,'VERIFIED_AND_RECORDED_READ_ONLY');
 const regress=c.producer.observe({sequence:3,idempotency_key:'fixture-idem-regress',evidence:'regress'});
 a.equal(c.open().verifyAndRecord(regress.envelope,regress.evidence).status,'UNKNOWN');
 const foreign=c.producer.observe({owner:'foreign-owner',lease_id:'foreign-lease',sequence:4,idempotency_key:'fixture-idem-foreign',evidence:'foreign'});
 a.equal(c.open().verifyAndRecord(foreign.envelope,foreign.evidence).status,'UNKNOWN');
 a.equal(c.open().historyCount(),1);
}));

test('08 revoked fixture key is unqualified',()=>withContext(c=>{
 a.throws(()=>c.open({...c.producer.anchor,revoked:true}),/UNQUALIFIED_TRUST_ANCHOR/);
}));

test('09 wrong signer role is unqualified',()=>withContext(c=>{
 a.throws(()=>c.open({...c.producer.anchor,role:'PRODUCTION'}),/UNQUALIFIED_TRUST_ANCHOR/);
}));

test('10 extra envelope field is rejected before persistence',()=>withContext(c=>{
 const x=c.producer.observe();x.envelope.can_submit_real=true;
 const api=c.open();a.equal(api.verifyAndRecord(x.envelope,x.evidence).status,'BLOCKED');
 a.equal(api.historyCount(),0);
}));
