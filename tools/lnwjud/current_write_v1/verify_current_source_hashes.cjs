'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const {TextDecoder} = require('node:util');

const here = __dirname;
const repoRoot = path.resolve(here, '..', '..', '..');
const receiptRelative = 'tools/lnwjud/current_write_v1/CURRENT_SOURCE_SHA256.json';
const receiptPath = path.join(repoRoot, ...receiptRelative.split('/'));
const excluded = new Set([receiptRelative]);

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function walkFiles(root) {
  const out = [];
  for (const entry of fs.readdirSync(root, {withFileTypes: true})) {
    const full = path.join(root, entry.name);
    if (entry.isSymbolicLink()) throw new Error(`symlink denied in source receipt scope: ${full}`);
    if (entry.isDirectory() && entry.name === '__pycache__') continue;
    if (entry.isDirectory()) out.push(...walkFiles(full));
    else if (entry.isFile()) out.push(full);
    else throw new Error(`non-file entry denied in source receipt scope: ${full}`);
  }
  return out;
}

function relative(file) {
  return path.relative(repoRoot, file).replaceAll('\\', '/');
}

const receiptBytes = fs.readFileSync(receiptPath);
const receipt = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(receiptBytes));
assert.equal(receipt.schema, 'lnwjud_write_v1_current_source_hashes/1');
assert.equal(receipt.contract_id, 'LNWJUD-S1-AMENDMENT-A2-20260930');
assert.equal(receipt.parent_contract, 'LNWJUD-WRITE-V1-SAFETY-CLOSURE-S1-20260929');
assert.equal(receipt.parent_amendment, 'LNWJUD-S1-AMENDMENT-A1-20260929');
assert.equal(receipt.base_head, '88d6767178e1230e370372ddb8a8ed7974aff6e4');
assert.equal(receipt.base_tree, 'fcb406f4ca53c0094868c4054d84a7d22e2a95ce');
assert.equal(receipt.algorithm, 'SHA256');
assert.equal(receipt.self_hash_excluded, receiptRelative);
assert.ok(Array.isArray(receipt.files));

const actualScope = [
  path.join(repoRoot, 'docs', 'handoffs', 'LNWJUD_WRITE_V1_20260928.md'),
  ...walkFiles(here),
].map(relative).filter((file) => !excluded.has(file)).sort();
const listedScope = receipt.files.map((entry) => entry.path).sort();
assert.deepEqual(listedScope, actualScope, 'receipt scope must match exact current source/doc file set');

const strictUtf8 = new TextDecoder('utf-8', {fatal: true});
for (const entry of receipt.files) {
  assert.match(entry.path, /^(docs\/handoffs\/LNWJUD_WRITE_V1_20260928\.md|tools\/lnwjud\/current_write_v1\/[^/]+)$/);
  assert.match(entry.sha256, /^[0-9a-f]{64}$/);
  assert.ok(Number.isSafeInteger(entry.bytes) && entry.bytes >= 0);
  const file = path.join(repoRoot, ...entry.path.split('/'));
  const bytes = fs.readFileSync(file);
  strictUtf8.decode(bytes);
  assert.equal(bytes.length, entry.bytes, `byte length mismatch: ${entry.path}`);
  assert.equal(sha256(bytes), entry.sha256, `SHA256 mismatch: ${entry.path}`);
}

console.log(JSON.stringify({
  result: 'PASS',
  contract_id: receipt.contract_id,
  files: receipt.files.length,
  receipt_path: receiptRelative,
  receipt_sha256: sha256(receiptBytes),
  utf8: 'STRICT_PASS',
  runtime_activation: 'NOT_RUN'
}, null, 2));
