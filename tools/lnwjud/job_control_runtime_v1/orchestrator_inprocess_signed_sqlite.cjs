'use strict';
// T3-C-P3 SOURCE-ONLY: isolated signed evidence, single-process verification+DB.
// No producer key creation/custody, real runtime activation, scheduled tasks,
// credential installation, network IPC, broker, dispatch, MT5 or Factory.
const fs=require('node:fs'),path=require('node:path');
const {DatabaseSync}=require('node:sqlite');
const {createSignedClaimIngress}=require('./orchestrator_signed_claim_ingress.cjs');
const HEX=/^[a-f0-9]{40}$/;
function createInprocessSignedSQLite({root,db_path,source_head,source_tree,anchor,clock}={}){
 if(typeof root!=='string'||typeof db_path!=='string'||!path.isAbsolute(root)||
    !path.isAbsolute(db_path)||path.extname(db_path)!=='.sqlite3'||
    path.resolve(path.dirname(db_path))!==path.resolve(root)||
    !HEX.test(source_head||'')||!HEX.test(source_tree||''))
  throw new Error('ISOLATED_PATH_INVALID');
 const real=fs.realpathSync(root);
 if(path.resolve(root)!==real||!fs.statSync(root).isDirectory()||
    fs.lstatSync(root).isSymbolicLink()||
    (fs.existsSync(db_path)&&fs.lstatSync(db_path).isSymbolicLink()))
   throw new Error('ISOLATED_PATH_INVALID');
 // Fresh closure copy; no external code can mutate the pinned signer identity.
 const pinned=Object.freeze({...anchor});
 function connect(){
  // Recheck path before every operation. TOCTOU remains a production gate.
  if(fs.realpathSync(root)!==real||fs.lstatSync(root).isSymbolicLink()||
     (fs.existsSync(db_path)&&fs.lstatSync(db_path).isSymbolicLink()))
   throw new Error('ISOLATION_DRIFT');
  const db=new DatabaseSync(db_path);
  try{
   db.exec('PRAGMA busy_timeout=5000');
   const mode=db.prepare('PRAGMA journal_mode=WAL').get().journal_mode;
   if(String(mode).toLowerCase()!=='wal')throw Error('SQLITE_NOT_WAL');
   db.exec('PRAGMA synchronous=FULL');
   if(db.prepare('PRAGMA synchronous').get().synchronous!==2)throw Error('SQLITE_NOT_FULL');
   return db;
  }catch(e){db.close();throw e}
 }
 function ensureTables(db){
  db.exec('CREATE TABLE IF NOT EXISTS p3_current(resource TEXT PRIMARY KEY, owner TEXT NOT NULL, lease TEXT NOT NULL, expires_ms INTEGER NOT NULL, seq INTEGER NOT NULL, proof TEXT NOT NULL, head TEXT NOT NULL, tree TEXT NOT NULL)');
  db.exec('CREATE TABLE IF NOT EXISTS p3_history(proof TEXT PRIMARY KEY, idem TEXT NOT NULL UNIQUE, resource TEXT NOT NULL, seq INTEGER NOT NULL)');
 }
 const ledger=Object.freeze({record(claim){
   let db,tx=false;
   const blocked=(status,reason)=>({status,reason});
   try{
    db=connect();
    // Serialize schema initialization, replay tombstone lookup and insert
    // inside one exclusive write transaction.
    db.exec('BEGIN IMMEDIATE');tx=true;
    ensureTables(db);
    const prior=db.prepare('SELECT 1 AS found FROM p3_history WHERE proof=? OR idem=? LIMIT 1').get(claim.signed_proof_sha256,claim.idempotency_key);
    if(prior)return blocked('BLOCKED','REPLAY_HISTORY');
    const last=db.prepare('SELECT owner,lease,expires_ms,seq,head,tree FROM p3_current WHERE resource=?').get(claim.resource);
    const nowMs=Date.parse(clock());
    const expiresMs=Date.parse(claim.lease_until_utc);
    if(!Number.isFinite(nowMs)||!Number.isFinite(expiresMs)||expiresMs<=nowMs||expiresMs-nowMs>300000)
      return blocked('UNKNOWN','CLOCK_LEASE_DRIFT');
    if(last){
     if(last.head!==source_head||last.tree!==source_tree)return blocked('UNKNOWN','STORED_SOURCE_DRIFT');
     if(claim.sequence<=last.seq)return blocked('BLOCKED','NONMONOTONIC_SEQUENCE');
     if(last.expires_ms>nowMs&&(last.owner!==claim.owner||last.lease!==claim.lease_id))
       return blocked('WAITING_RESOURCE','FOREIGN_ACTIVE_LEASE');
    }
    db.prepare('INSERT INTO p3_history(proof,idem,resource,seq) VALUES(?,?,?,?)').run(
      claim.signed_proof_sha256,claim.idempotency_key,claim.resource,claim.sequence);
    db.prepare('INSERT INTO p3_current(resource,owner,lease,expires_ms,seq,proof,head,tree) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(resource) DO UPDATE SET owner=excluded.owner,lease=excluded.lease,expires_ms=excluded.expires_ms,seq=excluded.seq,proof=excluded.proof,head=excluded.head,tree=excluded.tree').run(
      claim.resource,claim.owner,claim.lease_id,expiresMs,claim.sequence,claim.signed_proof_sha256,source_head,source_tree);
    db.exec('COMMIT');tx=false;
    const r=db.prepare('SELECT owner,lease,seq,proof FROM p3_current WHERE resource=?').get(claim.resource);
    const h=db.prepare('SELECT idem FROM p3_history WHERE proof=?').get(claim.signed_proof_sha256);
    if(!r||!h||r.owner!==claim.owner||r.lease!==claim.lease_id||
       r.seq!==claim.sequence||r.proof!==claim.signed_proof_sha256||
       h.idem!==claim.idempotency_key)
      return blocked('UNKNOWN','POST_COMMIT_READBACK_MISMATCH');
    return {status:'RECORDED_READ_ONLY',scope:'ISOLATED_EVIDENCE_ONLY',can_execute:false,can_submit:false};
   }catch{return blocked('UNKNOWN','SQLITE_CAS_UNAVAILABLE')}
   finally{
    if(db){if(tx){try{db.exec('ROLLBACK')}catch{}}try{db.close()}catch{}}
   }
 }});
 const verifier=createSignedClaimIngress({anchor:pinned,source_head,source_tree,clock,ledger});
 function historyCount(){
  let db,tx=false;
  try{db=connect();db.exec('BEGIN IMMEDIATE');tx=true;ensureTables(db);
   const n=db.prepare('SELECT COUNT(*) AS n FROM p3_history').get().n;
   db.exec('COMMIT');tx=false;return n;
  }finally{if(db){if(tx){try{db.exec('ROLLBACK')}catch{}}db.close()}}
 }
 return Object.freeze({verifyAndRecord:verifier.verifyAndRecord,historyCount});
}
module.exports={createInprocessSignedSQLite};
