'use strict';
// SOURCE_ONLY_READONLY_EVIDENCE: no fs, process, network, scheduler, broker,
// key generation, private-key custody, real Registry or installed JobControl.
const {createPublicKey,createHash,verify:verifyEd25519}=require('node:crypto');
const ENVELOPE_SCHEMA='EA_LAB_T3C_P2_SIGNED_CLAIM_ENVELOPE_V1';
const CLAIM_SCHEMA='EA_LAB_T3C_P1_SIGNED_CLAIM_V1';
const DOMAIN='EA_LAB_T3C_P2_SIGNED_CLAIM_ENVELOPE_V1\n';
const CLAIM_KEYS=['schema','source_head','source_tree','resource','owner','lease_id',
 'lease_until_utc','sequence','idempotency_key','signed_proof_sha256','can_execute','can_submit'];
const ENVELOPE_KEYS=['schema','signer_id','key_id','captured_utc','claim','signature'];
const ANCHOR_KEYS=['signer_id','key_id','public_key_pem','valid_from_utc','valid_until_utc','revoked','role'];
const PLAIN=x=>x!==null&&typeof x==='object'&&!Array.isArray(x)&&Object.getPrototypeOf(x)===Object.prototype;
const EXACT=(x,fields)=>PLAIN(x)&&Object.keys(x).sort().join('|')===fields.slice().sort().join('|');
const ID=x=>typeof x==='string'&&/^[A-Za-z][A-Za-z0-9._-]{2,127}$/.test(x);
const KEY=x=>typeof x==='string'&&/^[A-Za-z][A-Za-z0-9_-]{2,31}$/.test(x);
const SHA40=x=>typeof x==='string'&&/^[a-f0-9]{40}$/.test(x);
const SHA64=x=>typeof x==='string'&&/^[a-f0-9]{64}$/.test(x);
const HASH=b=>createHash('sha256').update(b).digest('hex');
function utc(s){
 if(typeof s!=='string'||!/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,3})?Z$/.test(s))return null;
 const n=Date.parse(s);
 return Number.isFinite(n)&&new Date(n).toISOString().slice(0,19)===s.slice(0,19)?n:null;
}
function isClaim(c){
 return EXACT(c,CLAIM_KEYS)&&c.schema===CLAIM_SCHEMA&&SHA40(c.source_head)&&SHA40(c.source_tree)
 &&ID(c.resource)&&ID(c.owner)&&ID(c.lease_id)&&ID(c.idempotency_key)
 &&Number.isSafeInteger(c.sequence)&&c.sequence>=1&&SHA64(c.signed_proof_sha256)
 &&utc(c.lease_until_utc)!==null&&c.can_execute===false&&c.can_submit===false;
}
function messageForEnvelope(e){
 if(!EXACT(e,ENVELOPE_KEYS)||e.schema!==ENVELOPE_SCHEMA||!KEY(e.signer_id)||!KEY(e.key_id)
 ||utc(e.captured_utc)===null||typeof e.signature!=='string'||!isClaim(e.claim))
 throw new TypeError('UNQUALIFIED_ENVELOPE');
 const c=e.claim;
 const tuple=[e.schema,e.signer_id,e.key_id,e.captured_utc,c.schema,c.source_head,
 c.source_tree,c.resource,c.owner,c.lease_id,c.lease_until_utc,c.sequence,
 c.idempotency_key,c.signed_proof_sha256,c.can_execute,c.can_submit];
 return Buffer.from(DOMAIN+JSON.stringify(tuple)+'\n','utf8');
}
function result(status,reason){return Object.freeze({schema:'EA_LAB_T3C_P2_SOURCE_ADVISORY_V1',
 status,reason,can_execute:false,can_submit:false,scope:'SOURCE_EVIDENCE_ONLY'});}
function createSignedClaimIngress({anchor,source_head,source_tree,clock,ledger}={}){
 if(!EXACT(anchor,ANCHOR_KEYS)||!KEY(anchor.signer_id)||!KEY(anchor.key_id)
 ||anchor.role!=='T3C_P2_ISOLATED_SIGNED_CLAIM'||anchor.revoked!==false
 ||typeof anchor.public_key_pem!=='string'||anchor.public_key_pem.length>4096
 ||!/^-----BEGIN PUBLIC KEY-----\r?\n[\s\S]+-----END PUBLIC KEY-----\r?\n?$/.test(anchor.public_key_pem)
 ||utc(anchor.valid_from_utc)===null||utc(anchor.valid_until_utc)===null
 ||utc(anchor.valid_from_utc)>=utc(anchor.valid_until_utc))throw new Error('UNQUALIFIED_TRUST_ANCHOR');
 if(!SHA40(source_head)||!SHA40(source_tree)||typeof clock!=='function')throw new Error('UNQUALIFIED_SOURCE_OR_CLOCK');
 if(!PLAIN(ledger)||typeof ledger.record!=='function')throw new Error('UNQUALIFIED_LEDGER');
 let publicKey;
 try{publicKey=createPublicKey(anchor.public_key_pem)}catch{throw new Error('UNQUALIFIED_TRUST_ANCHOR')}
 if(publicKey.asymmetricKeyType!=='ed25519')throw new Error('UNQUALIFIED_TRUST_ANCHOR');
 const from=utc(anchor.valid_from_utc),until=utc(anchor.valid_until_utc);
 function verifyAndRecord(envelope,evidenceBytes){
  try{
   if(!EXACT(envelope,ENVELOPE_KEYS)||!isClaim(envelope.claim)||!Buffer.isBuffer(evidenceBytes)
    ||evidenceBytes.length===0||evidenceBytes.length>4*1024*1024)return result('BLOCKED','ENVELOPE_OR_EVIDENCE_INVALID');
   // Freeze primitive claim values before signature verification and ledger callback.
   const claim=Object.freeze({...envelope.claim});
   const signed=Object.freeze({...envelope,claim});
   const evidence=Buffer.from(evidenceBytes);
   const now=utc(clock()),capture=utc(signed.captured_utc),lease=utc(claim.lease_until_utc);
   if(now===null||capture===null||lease===null)return result('UNKNOWN','CLOCK_UNVERIFIED');
   if(claim.source_head!==source_head||claim.source_tree!==source_tree
    ||signed.signer_id!==anchor.signer_id||signed.key_id!==anchor.key_id
    ||now<from||now>until||capture<from||capture>until
    ||capture>now||now-capture>120000||lease<=now||lease-now>300000)
    return result('BLOCKED','SOURCE_ROLE_OR_FRESHNESS_INVALID');
   if(HASH(evidence)!==claim.signed_proof_sha256)return result('BLOCKED','EVIDENCE_DIGEST_MISMATCH');
   if(typeof signed.signature!=='string'||!/^[A-Za-z0-9_-]{86}$/.test(signed.signature))
    return result('BLOCKED','SIGNATURE_ENCODING_INVALID');
   const sig=Buffer.from(signed.signature,'base64url');
   if(sig.length!==64||sig.toString('base64url')!==signed.signature)
    return result('BLOCKED','SIGNATURE_NONCANONICAL');
   if(verifyEd25519(null,messageForEnvelope(signed),publicKey,sig)!==true)
    return result('BLOCKED','SIGNATURE_VERIFICATION_FAILED');
   // Injected ledger is NOT itself authenticated by this source.
   const rec=ledger.record(claim);
   if(!EXACT(rec,['status','scope','can_execute','can_submit'])||rec.status!=='RECORDED_READ_ONLY'
    ||rec.scope!=='ISOLATED_EVIDENCE_ONLY'||rec.can_execute!==false||rec.can_submit!==false)
    return result('UNKNOWN','LEDGER_RECEIPT_UNQUALIFIED');
   return result('VERIFIED_AND_RECORDED_READ_ONLY','SIGNED_CLAIM_BOUND_TO_EVIDENCE');
  }catch{return result('UNKNOWN','VERIFIER_OR_LEDGER_UNAVAILABLE')}
 }
 return Object.freeze({verifyAndRecord});
}
module.exports={createSignedClaimIngress,messageForEnvelope};
