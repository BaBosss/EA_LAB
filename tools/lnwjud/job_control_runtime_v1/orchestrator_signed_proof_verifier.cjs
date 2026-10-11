'use strict';
// SOURCE-ONLY cryptographic verification. Does not fetch keys, read disk, dispatch,
// mutate Registry/lease, persist a replay ledger or install a scheduler.
const { createHash, createPublicKey, verify: verifySignature } = require('node:crypto');
const TYPES = Object.freeze(['git', 'registry', 'leases', 'jobs', 'tasks']);
const DOMAIN = 'EA_LAB_ORCHESTRATOR_SIGNED_PROOF_V1\n';
const PROOF_SCHEMA = 'EA_LAB_TRUSTED_SNAPSHOT_PROOF_V1';
const KEYS = ['schema', 'producer_id', 'source_type', 'source_head', 'source_tree', 'sha256', 'captured_utc', 'attestation'];
const ANCHOR_KEYS = ['producer_id','key_id','public_key_pem','valid_from_utc','valid_until_utc','revoked'];
const plain = x => x !== null && typeof x === 'object' && !Array.isArray(x) && Object.getPrototypeOf(x) === Object.prototype;
const exact = (x,k) => plain(x) && Object.keys(x).sort().join('|') === k.slice().sort().join('|');
const sha = x => typeof x === 'string' && /^[a-f0-9]{64}$/.test(x);
const hex40 = x => typeof x === 'string' && /^[a-f0-9]{40}$/.test(x);
const id = x => typeof x === 'string' && /^[A-Za-z][A-Za-z0-9._-]{2,127}$/.test(x);
const keyId = x => typeof x === 'string' && /^[A-Za-z][A-Za-z0-9_-]{2,31}$/.test(x);
function utc(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(value)) return null;
  const t = Date.parse(value);
  return Number.isFinite(t) && new Date(t).toISOString().slice(0,19) === value.slice(0,19) ? t : null;
}
const digest = b => createHash('sha256').update(b).digest('hex');
function messageForProof(proof,key_id) {
  if (!exact(proof,KEYS) || !keyId(key_id) || !TYPES.includes(proof.source_type) ||
      !id(proof.producer_id) || !hex40(proof.source_head) || !hex40(proof.source_tree) ||
      !sha(proof.sha256) || utc(proof.captured_utc) === null || proof.schema !== PROOF_SCHEMA)
    throw new TypeError('INVALID_SIGNED_PROOF_FIELDS');
  // Frozen, order-fixed tuple prevents ambiguity and replacement of proof fields.
  const tuple=[proof.schema,proof.source_type,proof.producer_id,proof.source_head,
    proof.source_tree,proof.sha256,proof.captured_utc,key_id];
  return Buffer.from(DOMAIN+JSON.stringify(tuple)+'\n','utf8');
}
function createSignedProofVerifier({ anchors, maxAgeMs = 120000 } = {}) {
  if (!plain(anchors) || Object.keys(anchors).sort().join('|') !== TYPES.slice().sort().join('|') ||
      !Number.isSafeInteger(maxAgeMs) || maxAgeMs < 1000 || maxAgeMs > 900000)
    throw new TypeError('UNQUALIFIED_TRUST_ANCHORS');
  const verifiedAnchors = new Map();
  for (const type of TYPES) {
    const a = anchors[type];
    if (!exact(a,ANCHOR_KEYS) || !id(a.producer_id) || !keyId(a.key_id) ||
      typeof a.public_key_pem !== 'string' || a.public_key_pem.length > 4096 ||
      !/^-----BEGIN PUBLIC KEY-----\r?\n[\s\S]+-----END PUBLIC KEY-----\r?\n?$/.test(a.public_key_pem) ||
      a.revoked !== false || utc(a.valid_from_utc) === null || utc(a.valid_until_utc) === null ||
      utc(a.valid_from_utc) >= utc(a.valid_until_utc)) throw new TypeError('UNQUALIFIED_TRUST_ANCHOR_'+type);
    let key;
    try { key=createPublicKey(a.public_key_pem); } catch { throw new TypeError('INVALID_PUBLIC_KEY_'+type); }
    if (key.asymmetricKeyType !== 'ed25519') throw new TypeError('KEY_NOT_ED25519_'+type);
    verifiedAnchors.set(type,Object.freeze({producer_id:a.producer_id,key_id:a.key_id,
      valid_from_ms:utc(a.valid_from_utc),valid_until_ms:utc(a.valid_until_utc),key}));
  }
  function verify({ source_type, bytes, proof, now_utc }={}) {
    try {
      if (!TYPES.includes(source_type) || !Buffer.isBuffer(bytes) || bytes.length===0 ||
        bytes.length>4*1024*1024 || !exact(proof,KEYS) || proof.source_type !== source_type) return false;
      const anchor=verifiedAnchors.get(source_type), now=utc(now_utc), captured=utc(proof.captured_utc);
      if (!anchor || now===null || captured===null || captured > now || now-captured > maxAgeMs ||
        captured < anchor.valid_from_ms || captured > anchor.valid_until_ms ||
        now < anchor.valid_from_ms || now > anchor.valid_until_ms ||
        proof.producer_id !== anchor.producer_id || !sha(proof.sha256) ||
        digest(bytes)!==proof.sha256 || typeof proof.attestation!=='string') return false;
      const parts=/^ed25519:([A-Za-z][A-Za-z0-9_-]{2,31}):([A-Za-z0-9_-]{86})$/.exec(proof.attestation);
      if (!parts || parts[1]!==anchor.key_id) return false;
      const signature=Buffer.from(parts[2],'base64url');
      if (signature.length!==64 || signature.toString('base64url')!==parts[2]) return false;
      return verifySignature(null,messageForProof(proof,anchor.key_id),anchor.key,signature)===true;
    } catch {return false;}
  }
  return Object.freeze({verify});
}
module.exports={createSignedProofVerifier,messageForProof};
