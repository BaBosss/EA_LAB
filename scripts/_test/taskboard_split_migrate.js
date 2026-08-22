// One-shot deterministic migration writer for the AGENT_TASKBOARD.md active split.
// Reads AGENT_TASKBOARD.md, packs whole ORDER blocks into taskboards/active/P0N.md
// part files (never splitting a block), and writes a manifest root file.
// Idempotent given identical input bytes. Read + write only; no git operations.
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = process.cwd();
const SRC = path.join(ROOT, 'AGENT_TASKBOARD.md');
const PARTS_DIR = path.join(ROOT, 'taskboards', 'active');
const TARGET_BYTES = 450 * 1024; // pack target ~450 KiB/part

const buf = fs.readFileSync(SRC);
const marker = Buffer.from('## ORDER-');
const lineStarts = [0];
for (let i = 0; i < buf.length; i++) {
  if (buf[i] === 0x0a) lineStarts.push(i + 1);
}
const orderLineStarts = [];
for (const off of lineStarts) {
  if (off < buf.length && buf.slice(off, off + marker.length).equals(marker)) {
    orderLineStarts.push(off);
  }
}
if (orderLineStarts.length === 0) throw new Error('no ORDER blocks found');

const prefixEnd = orderLineStarts[0];
const prefix = buf.slice(0, prefixEnd);

const blocks = [];
for (let i = 0; i < orderLineStarts.length; i++) {
  const start = orderLineStarts[i];
  const end = i + 1 < orderLineStarts.length ? orderLineStarts[i + 1] : buf.length;
  const blockBuf = buf.slice(start, end);
  const headerLineEnd = blockBuf.indexOf(0x0a);
  const header = blockBuf.slice(0, headerLineEnd === -1 ? blockBuf.length : headerLineEnd).toString('utf8');
  const idMatch = header.match(/^## (ORDER-[A-Za-z0-9_.-]+)/);
  blocks.push({
    ordinal: i + 1,
    id: idMatch ? idMatch[1] : header,
    header,
    buf: blockBuf,
    length: blockBuf.length,
    sha256: crypto.createHash('sha256').update(blockBuf).digest('hex'),
  });
}

// Greedy sequential pack: never split a block; start a new part when adding the
// next block would exceed TARGET_BYTES (except a part must always get at least
// one block, so an oversized single block still gets its own part).
const parts = [];
let cur = [];
let curBytes = 0;
for (const b of blocks) {
  if (cur.length > 0 && curBytes + b.length > TARGET_BYTES) {
    parts.push(cur);
    cur = [];
    curBytes = 0;
  }
  cur.push(b);
  curBytes += b.length;
}
if (cur.length > 0) parts.push(cur);

fs.mkdirSync(PARTS_DIR, { recursive: true });

const partFiles = [];
const manifestRows = [];
for (let i = 0; i < parts.length; i++) {
  const partBlocks = parts[i];
  const partName = `P${String(i + 1).padStart(2, '0')}.md`;
  const relPath = `taskboards/active/${partName}`;
  const partBuf = Buffer.concat(partBlocks.map((b) => b.buf));
  fs.writeFileSync(path.join(PARTS_DIR, partName), partBuf);
  partFiles.push(relPath);
  manifestRows.push({
    relPath,
    firstId: partBlocks[0].id,
    lastId: partBlocks[partBlocks.length - 1].id,
    blockCount: partBlocks.length,
    bytes: partBuf.length,
  });
}

// New root manifest: original prefix (byte-identical) + appended manifest section.
// The manifest section uses NO '## ' (H2) lines so it is never misread as an
// ORDER/H2 block by any block-oriented parser (Get-Blocks in
// scripts/check_taskboard_archive.ps1 splits strictly on column-zero '## ').
const manifestLines = [];
manifestLines.push('');
manifestLines.push('---');
manifestLines.push('');
manifestLines.push('### 📂 ACTIVE QUEUE — split across parts (mechanical, semantic NO-OP)');
manifestLines.push('');
manifestLines.push('> This file is the canonical entry point/manifest. Every ORDER block that used to live');
manifestLines.push('> directly below now lives in one of the ordered part files below — whole blocks only,');
manifestLines.push('> never split, global order preserved. Read them in the declared order to reconstruct');
manifestLines.push('> the full active queue; `scripts/lib/taskboard_source.ps1` does this for every script.');
manifestLines.push('> Do not hand-edit the marker block below — it is the machine-read source of truth for');
manifestLines.push('> which parts exist and in what order.');
manifestLines.push('');
for (const row of manifestRows) {
  manifestLines.push(`- \`${row.relPath}\` — ${row.blockCount} orders (${row.firstId} … ${row.lastId}), ${row.bytes} bytes`);
}
manifestLines.push('');
manifestLines.push('<!-- TASKBOARD-ACTIVE-PARTS');
for (const row of manifestRows) {
  manifestLines.push(row.relPath);
}
manifestLines.push('-->');
manifestLines.push('');

const manifestSection = Buffer.from(manifestLines.join('\n'), 'utf8');
const newRoot = Buffer.concat([prefix, manifestSection]);
fs.writeFileSync(SRC, newRoot);

console.log('prefix bytes:', prefix.length);
console.log('parts:', parts.length);
for (const row of manifestRows) console.log(' ', row.relPath, row.blockCount, 'orders', row.bytes, 'bytes');
console.log('new root bytes:', newRoot.length);
console.log(JSON.stringify({ blocks: blocks.map(b => ({ ordinal: b.ordinal, id: b.id, length: b.length, sha256: b.sha256 })), parts: manifestRows }, null, 0));
