'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const {TextDecoder} = require('node:util');

const receiptRelative = 'tools/lnwjud/current_write_v1/CURRENT_SOURCE_SHA256.json';
const legacyContract = 'LNWJUD-S1-AMENDMENT-A2-20260930';
const successorContract = 'LNWJUD-EXECUTION-IDENTITY-READ-V1-20261004';
const successorDoc = 'docs/workflows/LNWJUD_EXECUTION_IDENTITY_SOURCE_V1.md';
const predecessorReceiptSha = 'ade1b32549b91db9c81a7a402c3e7ec7ab51cfeae6ae4b813cbe6bbeeae5558f';
const successorFiles = [
  'docs/handoffs/LNWJUD_WRITE_V1_20260928.md', successorDoc,
  ...[
    'EA_LAB_CurrentWrite_V1_HTTP_Gateway.cjs','README.md','build_snapshot.py',
    'install_tasks.ps1','refresh_write_v1_snapshot.ps1','source_bound_gateway_loader.cjs',
    'start_write_v1.ps1','test_source_bound_gateway_loader.cjs','test_write_v1.cjs',
    'test_write_v1_a1.ps1','test_write_v1_repair1.cjs','test_write_v1_safety_s1.ps1',
    'verify_current_source_hashes.cjs','execution_identity.cjs','test_execution_identity.cjs'
  ].map(name => 'tools/lnwjud/current_write_v1/' + name)
].sort();

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function walkFiles(root) {
  const out = [];
  for (const entry of fs.readdirSync(root, {withFileTypes: true})) {
    const full = path.join(root, entry.name);
    if (entry.isSymbolicLink()) throw new Error('symlink denied in source receipt scope: ' + full);
    if (entry.isDirectory() && entry.name === '__pycache__') continue;
    if (entry.isDirectory()) out.push(...walkFiles(full));
    else if (entry.isFile()) out.push(full);
    else throw new Error('non-file entry denied in source receipt scope: ' + full);
  }
  return out;
}

// Root injection is a local deterministic-test seam, not a CLI or MCP parameter.
// Production entry point always uses its own repository root, as before.
function verify(repoRoot = path.resolve(__dirname, '..', '..', '..')) {
  const here = path.join(repoRoot, 'tools', 'lnwjud', 'current_write_v1');
  const receiptPath = path.join(repoRoot, ...receiptRelative.split('/'));
  const excluded = new Set([receiptRelative]);
  const receiptBytes = fs.readFileSync(receiptPath);
  const receipt = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(receiptBytes));
  assert.equal(receipt.schema, 'lnwjud_write_v1_current_source_hashes/1');
  const v2 = receipt.contract_id === 'LNWJUD-EXECUTION-IDENTITY-READ-V2-20261004';
  const successor = receipt.contract_id === successorContract || v2;
  if (receipt.contract_id === legacyContract) {
    // Historical A2 pins deliberately unchanged.
    assert.equal(receipt.contract_id, 'LNWJUD-S1-AMENDMENT-A2-20260930');
    assert.equal(receipt.parent_contract, 'LNWJUD-WRITE-V1-SAFETY-CLOSURE-S1-20260929');
    assert.equal(receipt.parent_amendment, 'LNWJUD-S1-AMENDMENT-A1-20260929');
    assert.equal(receipt.base_head, '88d6767178e1230e370372ddb8a8ed7974aff6e4');
    assert.equal(receipt.base_tree, 'fcb406f4ca53c0094868c4054d84a7d22e2a95ce');
  } else if (receipt.contract_id === successorContract) {
    assert.equal(receipt.parent_contract, legacyContract);
    assert.equal(receipt.predecessor_manifest_sha256, predecessorReceiptSha);
    assert.equal(receipt.base_head, '471a94d6d65fc86882ac7a4bbb882e280edbe98d');
    assert.equal(receipt.base_tree, 'bb1dbea90d1de8097db9e1b50736722b13211257');
    assert.equal(receipt.scope_amendment_authority_sha256,
      'fb8d850c87872683d503972d1bd89faf55458d55123ad73fb45cf314a8007012');
  } else if (v2) {
    assert.equal(receipt.parent_contract, successorContract);
    assert.equal(receipt.parent_candidate, '1c66f77f96a88816c21f957cadd7569778e48feb');
    assert.equal(receipt.predecessor_manifest_sha256, '022bb2a734b643cff3391299e493506ca825541ff1b295d827c42e4f6a6310d8');
    assert.equal(receipt.base_head, '471a94d6d65fc86882ac7a4bbb882e280edbe98d');
    assert.equal(receipt.base_tree, 'bb1dbea90d1de8097db9e1b50736722b13211257');
    assert.equal(receipt.scope_amendment_authority_sha256, 'f4084d2583090020c2ef4efadb1d2472005a2a5a6f962514c10fad268e943fca');
  } else {
    throw new Error('unknown source receipt contract profile');
  }
  assert.equal(receipt.algorithm, 'SHA256');
  assert.equal(receipt.self_hash_excluded, receiptRelative);
  assert.ok(Array.isArray(receipt.files));
  const actualScope = [
    path.join(repoRoot, 'docs', 'handoffs', 'LNWJUD_WRITE_V1_20260928.md'),
    ...(successor ? [path.join(repoRoot, ...successorDoc.split('/'))] : []),
    ...walkFiles(here),
  ].map(file => path.relative(repoRoot, file).replaceAll('\\', '/'))
    .filter(file => !excluded.has(file)).sort();
  const listedScope = receipt.files.map(entry => entry.path).sort();
  assert.deepEqual(listedScope, actualScope, 'receipt scope must match exact current source/doc file set');
  if (successor) assert.deepEqual(listedScope, successorFiles, 'successor scope must match exact admitted file set');

  const strictUtf8 = new TextDecoder('utf-8', {fatal: true});
  for (const entry of receipt.files) {
    if (successor && entry.path === successorDoc) {
      // Sole extra documentation path, no broader docs prefix permission.
    } else {
      assert.match(entry.path, /^(docs\/handoffs\/LNWJUD_WRITE_V1_20260928\.md|tools\/lnwjud\/current_write_v1\/[^/]+)$/);
    }
    assert.match(entry.sha256, /^[0-9a-f]{64}$/);
    assert.ok(Number.isSafeInteger(entry.bytes) && entry.bytes >= 0);
    const file = path.join(repoRoot, ...entry.path.split('/'));
    const bytes = fs.readFileSync(file);
    strictUtf8.decode(bytes);
    assert.equal(bytes.length, entry.bytes, 'byte length mismatch: ' + entry.path);
    assert.equal(sha256(bytes), entry.sha256, 'SHA256 mismatch: ' + entry.path);
  }
  return {result:'PASS',contract_id:receipt.contract_id,files:receipt.files.length,
    receipt_path:receiptRelative,receipt_sha256:sha256(receiptBytes),
    utf8:'STRICT_PASS',runtime_activation:'NOT_RUN'};
}

if (require.main === module) console.log(JSON.stringify(verify(), null, 2));
module.exports = {verify};
