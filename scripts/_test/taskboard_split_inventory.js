// Deterministic inventory/parse of AGENT_TASKBOARD.md ORDER blocks.
// Read-only: does not modify any files. Used to build migration evidence.
'use strict';
const fs = require('fs');
const crypto = require('crypto');

const SRC = process.argv[2] || 'AGENT_TASKBOARD.md';
const buf = fs.readFileSync(SRC);

// Find byte offsets of every line that starts with "## ORDER-" at column 0
// (i.e. immediately after a '\n', or at offset 0).
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

if (orderLineStarts.length === 0) {
  console.error('No ORDER blocks found');
  process.exit(1);
}

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
    start,
    end,
    length: blockBuf.length,
    sha256: crypto.createHash('sha256').update(blockBuf).digest('hex'),
  });
}

const out = {
  srcPath: SRC,
  totalBytes: buf.length,
  prefixBytes: prefix.length,
  blockCount: blocks.length,
  prefixSha256: crypto.createHash('sha256').update(prefix).digest('hex'),
  blocks,
};

if (process.argv[3] === '--json') {
  console.log(JSON.stringify(out));
} else {
  console.log('total bytes:', out.totalBytes);
  console.log('prefix bytes:', out.prefixBytes);
  console.log('block count:', out.blockCount);
  const ids = new Set();
  let dup = 0;
  for (const b of blocks) {
    if (ids.has(b.id)) dup++;
    ids.add(b.id);
  }
  console.log('unique ids:', ids.size, 'dup ids:', dup);
  console.log('first block:', blocks[0].id, blocks[0].length, 'bytes');
  console.log('last block:', blocks[blocks.length - 1].id, blocks[blocks.length - 1].length, 'bytes');
}

module.exports = { parse: () => out };
