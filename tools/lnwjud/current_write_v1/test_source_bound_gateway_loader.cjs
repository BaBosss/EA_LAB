'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const childProcess = require('node:child_process');

const loader = path.join(__dirname, 'source_bound_gateway_loader.cjs');
const sha = (buffer) => crypto.createHash('sha256').update(buffer).digest('hex');
const requestJson = (port, requestPath) => new Promise((resolve, reject) => {
  const req = http.get({host:'127.0.0.1', port, path:requestPath, timeout:3000}, (res) => {
    const chunks = [];
    res.on('data', (chunk) => chunks.push(chunk));
    res.on('end', () => {
      try {
        assert.equal(res.statusCode, 200);
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8')));
      } catch (error) { reject(error); }
    });
  });
  req.on('error', reject);
  req.on('timeout', () => req.destroy(new Error('request timeout')));
});

async function waitForPort(child) {
  return await new Promise((resolve, reject) => {
    let stderr = '';
    const timer = setTimeout(() => reject(new Error('fixture port timeout: ' + stderr)), 5000);
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
      const match = stderr.match(/FIXTURE_PORT=(\d+)/);
      if (match) { clearTimeout(timer); resolve(Number(match[1])); }
    });
    child.once('exit', (code) => {
      clearTimeout(timer);
      reject(new Error(`fixture exited before ready rc=${code}: ${stderr}`));
    });
  });
}

async function main() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lnwjud loader space '));
  const target = path.join(root, 'gateway fixture.cjs');
  const v1 = Buffer.from(
    "'use strict';const http=require('node:http');const s=http.createServer((q,r)=>r.end('fixture-v1'));" +
    "s.listen(0,'127.0.0.1',()=>process.stderr.write('FIXTURE_PORT='+s.address().port+'\\n'));\n",
    'utf8'
  );
  const v2 = Buffer.from(v1.toString('utf8').replace('fixture-v1', 'fixture-v2'), 'utf8');
  let child;
  try {
    fs.writeFileSync(target, v1);
    child = childProcess.spawn(process.execPath, [loader, target, sha(v1)], {
      stdio:['ignore','ignore','pipe'], windowsHide:true
    });
    const port = await waitForPort(child);
    const first = await requestJson(port, '/__ea_lab_loaded_source_identity_v1');
    assert.equal(first.source_path.toLowerCase(), path.resolve(target).toLowerCase());
    assert.equal(first.source_sha256, sha(v1));
    assert.equal(first.source_bytes, v1.length);

    fs.writeFileSync(target, v2);
    const staleStillListening = await requestJson(port, '/__ea_lab_loaded_source_identity_v1');
    assert.equal(staleStillListening.source_sha256, sha(v1));
    assert.notEqual(staleStillListening.source_sha256, sha(v2));

    const mismatch = childProcess.spawnSync(process.execPath, [loader, target, sha(v1)], {
      encoding:'utf8', windowsHide:true
    });
    assert.notEqual(mismatch.status, 0);
    assert.match(mismatch.stderr, /target SHA256 mismatch/);

    console.log(JSON.stringify({
      result:'PASS',
      suite:'source-bound-gateway-loader',
      quote_space_path:true,
      stale_script_still_listening_refused:true,
      exact_byte_hash_drift_refused:true,
      runtime_activation:'NOT_RUN'
    }));
  } finally {
    if (child && child.exitCode === null) {
      child.kill();
      await new Promise((resolve) => child.once('exit', resolve));
    }
    fs.rmSync(root, {recursive:true, force:true});
  }
}

main().catch((error) => {
  process.stderr.write((error.stack || error.message) + '\n');
  process.exitCode = 1;
});
