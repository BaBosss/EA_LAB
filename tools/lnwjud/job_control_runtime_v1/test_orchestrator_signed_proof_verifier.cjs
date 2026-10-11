'use strict';
const { test }=require('node:test');
const a=require('node:assert/strict');
const {generateKeyPairSync,sign,createHash}=require('node:crypto');
const {createSignedProofVerifier,messageForProof}=require('./orchestrator_signed_proof_verifier.cjs');
const types=['git','registry','leases','jobs','tasks'];
const now='2026-10-11T12:00:00Z',at='2026-10-11T11:59:00Z';
const sha=b=>createHash('sha256').update(b).digest('hex');
function fixture(){
 const keys=Object.fromEntries(types.map(type=>[type,generateKeyPairSync('ed25519')]));
 const anchors=Object.fromEntries(types.map(type=>[type,{
  producer_id:'reader-'+type,key_id:'Key_'+type,public_key_pem:keys[type].publicKey.export({type:'spki',format:'pem'}),
  valid_from_utc:'2026-10-11T11:00:00Z',valid_until_utc:'2026-10-11T13:00:00Z',revoked:false
 }]));
 const bytes=Buffer.from('{"source":"fixture"}','utf8');
 const proof=type=>({schema:'EA_LAB_TRUSTED_SNAPSHOT_PROOF_V1',producer_id:'reader-'+type,source_type:type,
  source_head:'a'.repeat(40),source_tree:'b'.repeat(40),sha256:sha(bytes),captured_utc:at,attestation:''});
 function signed(type,override={}){
  const p={...proof(type),...override};
  const signature=sign(null,messageForProof(p,anchors[type].key_id),keys[type].privateKey).toString('base64url');
  return {...p,attestation:'ed25519:'+anchors[type].key_id+':'+signature};
 }
 return {keys,anchors,bytes,signed};
}
test('01 Ed25519 real signature accepted for git',()=>{const f=fixture();a.equal(createSignedProofVerifier({anchors:f.anchors}).verify({source_type:'git',bytes:f.bytes,proof:f.signed('git'),now_utc:now}),true)});
for(const [i,type] of types.entries())test('02+'+i+' authentic signed source '+type,()=>{const f=fixture();a.equal(createSignedProofVerifier({anchors:f.anchors}).verify({source_type:type,bytes:f.bytes,proof:f.signed(type),now_utc:now}),true)});
const falseCase=(name,modify)=>test(name,()=>{const f=fixture(),proof=f.signed('git');const args={source_type:'git',bytes:f.bytes,proof,now_utc:now};modify(f,args);a.equal(createSignedProofVerifier({anchors:f.anchors}).verify(args),false)});
falseCase('07 bad payload digest',(_f,x)=>{x.bytes=Buffer.from('modified')});
falseCase('08 forged hash',(_f,x)=>{x.proof={...x.proof,sha256:'0'.repeat(64)}});
falseCase('09 forged signature',(_f,x)=>{{const q=x.proof.attestation;const mid=q.indexOf(':',10)+8;x.proof={...x.proof,attestation:q.slice(0,mid)+(q[mid]==='A'?'B':'A')+q.slice(mid+1)}}});
falseCase('10 wrong issuer',(_f,x)=>{x.proof={...x.proof,producer_id:'other'}});
falseCase('11 head substitution',(_f,x)=>{x.proof={...x.proof,source_head:'c'.repeat(40)}});
falseCase('12 tree substitution',(_f,x)=>{x.proof={...x.proof,source_tree:'d'.repeat(40)}});
falseCase('13 source type mismatch',(_f,x)=>{x.source_type='jobs'});
falseCase('14 future timestamp',(_f,x)=>{x.now_utc='2026-10-11T11:58:00Z'});
falseCase('15 stale over two minutes',(_f,x)=>{x.now_utc='2026-10-11T12:02:01Z'});
falseCase('16 offset timestamp invalid',(_f,x)=>{x.now_utc='2026-10-11T19:00:00+07:00'});
falseCase('17 calendar invalid',(_f,x)=>{x.now_utc='2026-02-30T12:00:00Z'});
falseCase('18 null bytes',(_f,x)=>{x.bytes=null});
falseCase('19 zero bytes',(_f,x)=>{x.bytes=Buffer.alloc(0)});
falseCase('20 extra proof key',(_f,x)=>{x.proof={...x.proof,authenticated:true}});
falseCase('21 unknown attestation scheme',(_f,x)=>{x.proof={...x.proof,attestation:x.proof.attestation.replace('ed25519','none')}});
falseCase('22 bad key id',(_f,x)=>{x.proof={...x.proof,attestation:x.proof.attestation.replace('Key_git','Key_foo')}});
falseCase('23 empty attestation',(_f,x)=>{x.proof={...x.proof,attestation:''}});
falseCase('24 signature truncation',(_f,x)=>{x.proof={...x.proof,attestation:x.proof.attestation.slice(0,-5)}});
falseCase('25 proof source missing',(_f,x)=>{delete x.proof.source_tree});
falseCase('26 unsigned data cannot authenticate',(_f,x)=>{x.proof={...x.proof,attestation:'TRUE'}});
test('27 revoked key refuses construction',()=>{const f=fixture();f.anchors.git.revoked=true;a.throws(()=>createSignedProofVerifier({anchors:f.anchors}),/UNQUALIFIED_TRUST_ANCHOR/)});
test('28 unknown source anchor refuses construction',()=>{const f=fixture();delete f.anchors.tasks;a.throws(()=>createSignedProofVerifier({anchors:f.anchors}),/UNQUALIFIED_TRUST_ANCHORS/)});
test('29 private key not accepted as public trust anchor',()=>{const f=fixture();f.anchors.git.public_key_pem=f.keys.git.privateKey.export({type:'pkcs8',format:'pem'});a.throws(()=>createSignedProofVerifier({anchors:f.anchors}),/UNQUALIFIED_TRUST_ANCHOR/)});
test('30 wrong key family denied',()=>{const f=fixture();const rsa=generateKeyPairSync('rsa',{modulusLength:2048});f.anchors.git.public_key_pem=rsa.publicKey.export({type:'spki',format:'pem'});a.throws(()=>createSignedProofVerifier({anchors:f.anchors}),/KEY_NOT_ED25519/)});
test('31 excessive max-age denied',()=>{const f=fixture();a.throws(()=>createSignedProofVerifier({anchors:f.anchors,maxAgeMs:Infinity}),/UNQUALIFIED_TRUST_ANCHORS/)});
test('32 expired anchor rejects genuine signature',()=>{const f=fixture();f.anchors.git.valid_until_utc='2026-10-11T11:59:59Z';const verifier=createSignedProofVerifier({anchors:f.anchors});a.equal(verifier.verify({source_type:'git',bytes:f.bytes,proof:f.signed('git'),now_utc:now}),false)});
test('33 future anchor refuses signature',()=>{const f=fixture();f.anchors.git.valid_from_utc='2026-10-11T12:00:30Z';const verifier=createSignedProofVerifier({anchors:f.anchors});a.equal(verifier.verify({source_type:'git',bytes:f.bytes,proof:f.signed('git'),now_utc:now}),false)});
test('34 key substitution with same key ID fails verification',()=>{const f=fixture(),old=f.signed('git');const g=generateKeyPairSync('ed25519');f.anchors.git.public_key_pem=g.publicKey.export({type:'spki',format:'pem'});a.equal(createSignedProofVerifier({anchors:f.anchors}).verify({source_type:'git',bytes:f.bytes,proof:old,now_utc:now}),false)});
test('35 valid proof can be replayed within 2 minutes: production replay ledger required',()=>{const f=fixture(),v=createSignedProofVerifier({anchors:f.anchors}),args={source_type:'git',bytes:f.bytes,proof:f.signed('git'),now_utc:now};a.equal(v.verify(args),true);a.equal(v.verify(args),true)});

const {createTrustedReadOnlyAdapter}=require('./orchestrator_trusted_snapshot_adapter.cjs');
function sourceFixture(action='READ_ONLY',gitCaptured='2026-10-11T09:59:00Z',otherCaptured='2026-10-11T09:59:00Z'){
 const H='a'.repeat(40),T='b'.repeat(40),utc='2026-10-11T10:00:00Z';
 const payload={resource:'resource-aa1',owner:'worker-aa1',lease_id:'lease-resource-aa1',source_head:H};
 const task={task_id:'aa1',lane_id:'lane-aa1',owner:'worker-aa1',stage:'DISPATCH',action,
  source_head:H,source_tree:T,worktree:'D:\\src\\aa1',resources:['resource-aa1'],
  dependency_ids:[],idempotency_key:'idem-aa1',repair_remaining:0,author_id:'worker-aa1',
  reviewer_id:'reader-aa1',provider:null,review:null,test_receipt:null};
 const docs={
  git:{head:H,tree:T,origin_master:H,ls_remote:H,checkout_head:H,checkout_tree:T,clean:true,captured_utc:gitCaptured},
  registry:{validated:true,main_ct_ids:['single-main-ct'],lanes:[{lane_id:'lane-aa1',owner:'worker-aa1',state:'READY',worktree:'D:\\src\\aa1',critical_paths:['D:/src/aa1/file.cjs']}]},
  leases:[{resource:'resource-aa1',owner:'worker-aa1',lease_id:'lease-resource-aa1',expires_utc:'2026-10-11T10:10:00Z',
    receipt:{data:payload,sha256:sha(Buffer.from(JSON.stringify(payload)))}}],
  jobs:[],tasks:[task]
 };
 const readers=Object.fromEntries(Object.keys(docs).map(kind=>[kind,()=>{
  const bytes=Buffer.from(JSON.stringify(docs[kind]),'utf8');
  return {bytes,proof:{schema:'EA_LAB_TRUSTED_SNAPSHOT_PROOF_V1',producer_id:'reader-'+kind,
   source_type:kind,source_head:H,source_tree:T,sha256:sha(bytes),
   captured_utc:kind==='git'?gitCaptured:otherCaptured,attestation:'signed-sample-'+kind}};
 }]));
 return {readers,utc};
}
test('36 injected verifier may not mutate assessed task bytes after hash',()=>{
 const f=sourceFixture('T3_DEPLOY'),verifier={verify:({source_type,bytes})=>{
  if(source_type==='tasks'){
   const i=bytes.indexOf('T3_DEPLOY');
   a.ok(i>0);bytes.write('READ_ONLY',i,'utf8');
  }
  return true;
 }};
 const result=createTrustedReadOnlyAdapter({readers:f.readers,verifier,clock:()=>f.utc}).assess();
 a.notEqual(result.decisions[0].status,'READY','post-verification mutation must fail closed');
});
test('37 Git and Registry snapshot skew over two minutes must fail closed',()=>{
 const f=sourceFixture('READ_ONLY','2026-10-11T09:49:00Z','2026-10-11T09:59:00Z');
 const result=createTrustedReadOnlyAdapter({readers:f.readers,verifier:{verify:()=>true},clock:()=>f.utc}).assess();
 a.notEqual(result.decisions[0].status,'READY','cross-snapshot skew cannot be treated as one atomic read');
});
