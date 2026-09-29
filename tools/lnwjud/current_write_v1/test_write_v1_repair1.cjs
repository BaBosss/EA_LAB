'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const childProcess = require('node:child_process');
const gateway = require('./EA_LAB_CurrentWrite_V1_HTTP_Gateway.cjs');

const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lnwjud-write-r1-'));
try {
  const target = path.join(root, 'tracked.txt');
  fs.writeFileSync(target, 'alpha', 'utf8');
  const alphaSha = sha(Buffer.from('alpha'));
  gateway.atomicReplaceExpected(target, Buffer.from('beta'), alphaSha);
  assert.equal(fs.readFileSync(target, 'utf8'), 'beta');

  fs.writeFileSync(target, 'external-change', 'utf8');
  assert.throws(
    () => gateway.atomicReplaceExpected(target, Buffer.from('lost-update'), alphaSha),
    /stale file SHA256 at replacement boundary/
  );
  assert.equal(fs.readFileSync(target, 'utf8'), 'external-change');

  const lock = path.join(root, 'mutation.lock');
  gateway.withMutationLock(() => {
    assert.throws(
      () => gateway.withMutationLock(() => {}, lock),
      /mutation already in progress/
    );
  }, lock);
  assert.equal(fs.existsSync(lock), false);

  const created = path.join(root, 'new.md');
  gateway.atomicCreateNew(created, Buffer.from('# one\n'));
  assert.equal(fs.readFileSync(created, 'utf8'), '# one\n');
  assert.throws(() => gateway.atomicCreateNew(created, Buffer.from('# two\n')), /EEXIST/);
  assert.equal(fs.readFileSync(created, 'utf8'), '# one\n');

  const here = __dirname;
  const supervisor = fs.readFileSync(path.join(here, 'start_write_v1.ps1'), 'utf8');
  assert.match(supervisor, /function Get-ExactProcessIdentity/);
  assert.match(supervisor, /function Stop-ExactOwnedProcess/);
  assert.match(supervisor, /function Get-ExactTunnelProcesses/);
  assert.match(supervisor, /function Get-ExactOwnedListenerIdentity/);
  assert.match(supervisor, /function Assert-SameListenerIdentity/);
  assert.doesNotMatch(supervisor, /Get-Process\s+-Name\s+tunnel-client/i);
  assert.doesNotMatch(supervisor, /\$Pid\b/i);
  assert.doesNotMatch(supervisor, /ExpectedCommandToken/);
  assert.match(supervisor, /ExpectedTunnelSha/);
  assert.match(supervisor, /ExpectedNodeSha/);

  const installer = fs.readFileSync(path.join(here, 'install_tasks.ps1'), 'utf8');
  assert.doesNotMatch(installer, /\/Create[^\r\n]*\/F/i);
  assert.match(installer, /existing WriteV1 Scheduled Task requires explicit ownership reconciliation/);
  assert.match(installer, /Remove-CreatedTask/);
  assert.match(installer, /rollback absence verification failed/);
  assert.match(installer, /task installation failed:.*rollback failed:/);
  assert.match(installer, /createdRefresh/);
  assert.match(installer, /createdStart/);

  const refresh = fs.readFileSync(path.join(here, 'refresh_write_v1_snapshot.ps1'), 'utf8');
  assert.match(refresh, /\.write-mutation\.lock/);
  assert.match(refresh, /FileMode\]::CreateNew/);
  assert.match(refresh, /Remove-Item -LiteralPath \$LockPath/);

  const safety = childProcess.spawnSync(
    'powershell.exe',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(here, 'test_write_v1_safety_s1.ps1')],
    {encoding: 'utf8', windowsHide: true}
  );
  assert.equal(
    safety.status,
    0,
    `Safety S1 behavioral test failed rc=${safety.status}: ${safety.stderr || safety.stdout}`
  );
  const safetyReceipt = JSON.parse(safety.stdout.trim().split(/\r?\n/).at(-1));
  assert.equal(safetyReceipt.result, 'PASS');
  assert.equal(safetyReceipt.runtime_activation, 'NOT_RUN');
  assert.equal(safetyReceipt.checks, 37);

  console.log(JSON.stringify({
    result:'PASS',
    checks:'repair1-cas-plus-s1-process-listener-task-rollback',
    behavioral_checks:safetyReceipt.checks,
    runtime_activation:'NOT_RUN'
  }, null, 2));
} finally {
  fs.rmSync(root, {recursive:true, force:true});
}
