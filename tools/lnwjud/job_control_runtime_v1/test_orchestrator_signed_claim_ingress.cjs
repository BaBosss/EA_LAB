'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const {generateKeyPairSync,sign,createHash}=require('node:crypto');
const {createSignedClaimIngress,messageForEnvelope}=require('./orchestrator_signed_claim_ingress.cjs');
const HEAD='a2abe3a7dd51f0576bc3d57d06ed23cb31016c82';
const TREE='94592df52a4e44d592296f4b6c21ee6294c666b2';
const NOW='2026-10-11T14:00:00Z';
const DATA=Buffer.from('{"evidence":"synthetic-only"}','utf8');
const sha=b=>createHash('sha256').update(b).digest('hex');
function fixture(){
 const k=generateKeyPairSync('ed25519');
 const anchor={signer_id:'FixtureIssuer',key_id:'FixtureKey',public_key_pem:k.publicKey.export({type:'spki',format:'pem'}),valid_from_utc:'2026-10-11T13:00:00Z',valid_until_utc:'2026-10-11T15:00:00Z',revoked:false,role:'T3C_P2_ISOLATED_SIGNED_CLAIM'};
 const claim={schema:'EA_LAB_T3C_P1_SIGNED_CLAIM_V1',source_head:HEAD,source_tree:TREE,resource:'resource-a',owner:'fixture-owner',lease_id:'lease-a',lease_until_utc:'2026-10-11T14:03:00Z',sequence:1,idempotency_key:'once-a',signed_proof_sha256:sha(DATA),can_execute:false,can_submit:false};
 function envelope(c=claim){const p={schema:'EA_LAB_T3C_P2_SIGNED_CLAIM_ENVELOPE_V1',signer_id:'FixtureIssuer',key_id:'FixtureKey',captured_utc:'2026-10-11T13:59:45Z',claim:structuredClone(c),signature:''};p.signature=sign(null,messageForEnvelope(p),k.privateKey).toString('base64url');return p}
 const store={records:[],record(c){this.records.push(c);return {status:'RECORDED_READ_ONLY',scope:'ISOLATED_EVIDENCE_ONLY',can_execute:false,can_submit:false}}};
 const ingress=()=>createSignedClaimIngress({anchor,source_head:HEAD,source_tree:TREE,clock:()=>NOW,ledger:store});
 return {k,anchor,claim,envelope,store,ingress};
}
test('01 authentic signed envelope advisory only',()=>{const f=fixture(),r=f.ingress().verifyAndRecord(f.envelope(),DATA);a.equal(r.status,'VERIFIED_AND_RECORDED_READ_ONLY');a.equal(r.can_execute,false);a.equal(r.can_submit,false);a.equal(f.store.records.length,1)});
test('02 original input unchanged',()=>{const f=fixture(),p=f.envelope();f.ingress().verifyAndRecord(p,DATA);a.equal(p.claim.owner,'fixture-owner')});
function bad(name,alter){test(name,()=>{const f=fixture(),e=f.envelope(),ingress=f.ingress();alter(f,e);const r=ingress.verifyAndRecord(e,DATA);a.notEqual(r.status,'VERIFIED_AND_RECORDED_READ_ONLY');a.equal(f.store.records.length,0)})}
bad('03 forged issuer',(_,e)=>{e.signer_id='FakeIssuer'});
bad('04 changed owner',(_,e)=>{e.claim.owner='foreign-owner'});
bad('05 changed resource',(_,e)=>{e.claim.resource='another'});
bad('06 changed source tree',(_,e)=>{e.claim.source_tree='b'.repeat(40)});
bad('07 extra claim field',(_,e)=>{e.claim.approved=true});
bad('08 changed signed proof digest',(_,e)=>{e.claim.signed_proof_sha256='0'.repeat(64)});
bad('09 signature truncated',(_,e)=>{e.signature=e.signature.slice(0,-3)});
bad('10 wrong key id',(_,e)=>{e.key_id='OtherKey'});
bad('11 forbidden execution',(_,e)=>{e.claim.can_execute=true});
bad('12 future capture',(_,e)=>{e.captured_utc='2026-10-11T14:10:00Z'});
bad('13 stale capture',(_,e)=>{e.captured_utc='2026-10-11T13:40:00Z'});
bad('14 extra envelope key',(_,e)=>{e.allow_live=true});
bad('15 bad scheme prefix',(_,e)=>{e.signature='ed25519:'+e.signature});
test('16 altered evidence blocked',()=>{const f=fixture();a.equal(f.ingress().verifyAndRecord(f.envelope(),Buffer.from('other')).status,'BLOCKED');a.equal(f.store.records.length,0)});
test('17 revoked anchor cannot construct',()=>{const f=fixture();f.anchor.revoked=true;a.throws(()=>f.ingress(),/UNQUALIFIED_TRUST_ANCHOR/)});
test('18 private PEM cannot be anchor',()=>{const f=fixture();f.anchor.public_key_pem=f.k.privateKey.export({type:'pkcs8',format:'pem'});a.throws(()=>f.ingress(),/UNQUALIFIED_TRUST_ANCHOR/)});
test('19 foreign signed key denied',()=>{const f=fixture(),evil=generateKeyPairSync('ed25519'),e=f.envelope();e.signature=sign(null,messageForEnvelope(e),evil.privateKey).toString('base64url');a.equal(f.ingress().verifyAndRecord(e,DATA).status,'BLOCKED')});
test('20 missing ledger cannot construct',()=>{const f=fixture();a.throws(()=>createSignedClaimIngress({anchor:f.anchor,source_head:HEAD,source_tree:TREE,clock:()=>NOW}),/UNQUALIFIED_LEDGER/)});
test('21 thrown ledger becomes UNKNOWN',()=>{const f=fixture();f.store.record=()=>{throw Error('offline')};a.equal(f.ingress().verifyAndRecord(f.envelope(),DATA).status,'UNKNOWN')});
test('22 misleading execution READY denied',()=>{const f=fixture();f.store.record=()=>({status:'READY_TO_EXECUTE',can_execute:true,can_submit:true});const r=f.ingress().verifyAndRecord(f.envelope(),DATA);a.equal(r.status,'UNKNOWN');a.equal(r.can_execute,false)});
test('23 missing receipt field denied',()=>{const f=fixture();f.store.record=()=>({status:'RECORDED_READ_ONLY',scope:'ISOLATED_EVIDENCE_ONLY',can_execute:false});a.equal(f.ingress().verifyAndRecord(f.envelope(),DATA).status,'UNKNOWN')});
test('24 noncanonical signature rejected',()=>{const f=fixture(),e=f.envelope();e.signature=e.signature.slice(0,-1)+(e.signature.endsWith('A')?'B':'A');a.equal(f.ingress().verifyAndRecord(e,DATA).status,'BLOCKED')});
test('25 caller mutation during callback cannot alter frozen claim',()=>{const f=fixture(),e=f.envelope();f.store.record=(c)=>{a.equal(c.owner,'fixture-owner');e.claim.owner='foreign-owner';a.equal(c.owner,'fixture-owner');return {status:'RECORDED_READ_ONLY',scope:'ISOLATED_EVIDENCE_ONLY',can_execute:false,can_submit:false}};a.equal(f.ingress().verifyAndRecord(e,DATA).status,'VERIFIED_AND_RECORDED_READ_ONLY')});
test('26 UNKNOWN receipt cannot grant execution',()=>{const f=fixture();f.store.record=()=>({status:'UNKNOWN',scope:'ISOLATED_EVIDENCE_ONLY',can_execute:false,can_submit:false});a.equal(f.ingress().verifyAndRecord(f.envelope(),DATA).status,'UNKNOWN')});

const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const PY=process.env.EA_LAB_PYTHON_TEST_EXECUTABLE||'python';
const PY_MOD=path.join(__dirname,'orchestrator_sqlite_replay_store.py');
const PY_ISOLATED=String.raw`import json,sys,pathlib
sys.path.insert(0,str(pathlib.Path(sys.argv[3])))
from orchestrator_sqlite_replay_store import SQLiteReplayLedger
claim=json.loads(sys.stdin.read())
ledger=SQLiteReplayLedger(pathlib.Path(sys.argv[1]),pathlib.Path(sys.argv[2]),claim["source_head"],claim["source_tree"],clock=lambda:"2026-10-11T14:00:00Z",verify_claim=lambda _:True)
print(json.dumps(ledger.record(claim),sort_keys=True))
`;
test('27 actual isolated P1 SQLite process receives verified signed claim; historical replay blocked',()=>{
 const f=fixture(),root=fs.mkdtempSync(path.join(os.tmpdir(),'ea-lab-t3c-p2-'));
 const db=path.join(root,'p2-fixture.sqlite3');
 const store={record(c){
   const proc=spawnSync(PY,['-c',PY_ISOLATED,db,root,__dirname],{input:JSON.stringify(c),encoding:'utf8',timeout:12000});
   if(proc.status!==0)console.error('P1_SUBPROCESS_ERROR',JSON.stringify({status:proc.status,stderr:proc.stderr,stdout:proc.stdout,error:String(proc.error||'')}));
   a.equal(proc.status,0,String(proc.stderr||proc.error||''));
   const receipt=JSON.parse(proc.stdout.trim());
   a.equal(receipt.schema,'EA_LAB_T3C_P1_ISOLATED_LEDGER_RESULT_V1');
   a.equal(receipt.scope,'ISOLATED_EVIDENCE_ONLY');
   return {status:receipt.status,scope:receipt.scope,can_execute:receipt.can_execute,can_submit:receipt.can_submit};
 }};
 try{
   const ingress=createSignedClaimIngress({anchor:f.anchor,source_head:HEAD,source_tree:TREE,clock:()=>NOW,ledger:store});
   const p=f.envelope();
   const first=ingress.verifyAndRecord(p,DATA);
   a.equal(first.status,'VERIFIED_AND_RECORDED_READ_ONLY');
   const replay=ingress.verifyAndRecord(p,DATA);
   a.equal(replay.status,'UNKNOWN');
   const dbBytes=fs.statSync(db).size;
   a.ok(dbBytes>0);
 }finally{fs.rmSync(root,{recursive:true,force:true,maxRetries:5,retryDelay:100})}
});
test('28 no accepted signed claim can switch can_execute in actual P1 bridge',()=>{
 const f=fixture(),e=f.envelope();e.claim.can_execute=true;
 a.equal(f.ingress().verifyAndRecord(e,DATA).status,'BLOCKED');
 a.equal(f.store.records.length,0);
});
