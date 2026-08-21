#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const execFileAsync = promisify(execFile);
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');

const root = path.resolve(__dirname, '..', '..');
const cli = path.join(__dirname, 'lnwjudctl.cjs');
const policyPath = path.join(__dirname, 'lnwjudctl-policy.json');

let passed = 0;
function pass(name) {
  passed += 1;
  process.stdout.write(`[PASS] ${name}\n`);
}

async function run(args, env = {}) {
  try {
    const { stdout } = await execFileAsync(process.execPath, [cli, ...args], {
      cwd: root,
      env: { ...process.env, ...env },
      windowsHide: true,
      maxBuffer: 16 * 1024 * 1024,
    });
    return { code: 0, stdout, json: JSON.parse(stdout) };
  } catch (error) {
    const stdout = typeof error.stdout === 'string' ? error.stdout : '';
    let json = null;
    try { json = JSON.parse(stdout); } catch { /* leave null */ }
    return { code: typeof error.code === 'number' ? error.code : 1, stdout, json, raw: error };
  }
}

async function main() {
  // --- positive path ---

  const status = await run(['status']);
  assert.equal(status.code, 0, `status must exit 0: ${status.stdout}`);
  assert.equal(status.json.ok, true);
  assert.equal(typeof status.json.data.workspace_id, 'string');
  pass('status returns parseable structured data');

  const workspaceInfo = await run(['workspace-info']);
  assert.equal(workspaceInfo.code, 0);
  assert.equal(workspaceInfo.json.ok, true);
  const rootPathReported = workspaceInfo.json.data.realRootPath || workspaceInfo.json.data.rootPath;
  assert.equal(path.resolve(rootPathReported).toLowerCase(), path.resolve(root).toLowerCase());
  pass('workspace-info returns the expected authorized checkout');

  const gitStatus = await run(['git-status']);
  assert.equal(gitStatus.code, 0);
  assert.equal(gitStatus.json.ok, true);
  assert.ok(Array.isArray(gitStatus.json.data.entries));
  pass('git-status returns data for the exact checkout');

  const gitLog = await run(['git-log']);
  assert.equal(gitLog.code, 0);
  assert.equal(gitLog.json.ok, true);
  assert.ok(Array.isArray(gitLog.json.data.entries) && gitLog.json.data.entries.length > 0);
  pass('bounded git-log works');

  const read = await run(['read', 'tools/lnwjud/fixtures/README.md']);
  assert.equal(read.code, 0, `read must exit 0: ${read.stdout}`);
  assert.equal(read.json.ok, true);
  assert.match(String(read.json.data.content || read.json.data), /lnwjud acceptance fixture/i);
  pass('read of a known repository-relative fixture works');

  const search = await run(['search', 'ControlTowerRelay']);
  if (search.code === 0) {
    assert.equal(search.json.ok, true);
    pass('search of a known repository fixture/string works');
  } else if (search.json && search.json.error && search.json.error.code === 'EXECUTABLE_NOT_FOUND') {
    pass('search reports BLOCKED(C) cleanly when rg is absent from this environment (not an adapter defect)');
  } else {
    throw new Error(`unexpected search failure: ${search.stdout}`);
  }

  const executeCheck = await run(['execute', 'check']);
  assert.equal(executeCheck.code, 0, `execute check must exit 0: ${executeCheck.stdout}`);
  assert.equal(executeCheck.json.ok, true);
  assert.equal(executeCheck.json.data.status.state, 'exited');
  assert.equal(executeCheck.json.data.status.exitCode, 0);
  assert.match(executeCheck.json.data.logs, /\[PASS\] M2 CHECK/);
  pass('existing approved execute profile (check) runs against a safe fixture');

  for (const result of [status, workspaceInfo, gitStatus, gitLog, read, executeCheck]) {
    assert.doesNotThrow(() => JSON.parse(result.stdout), 'output must be valid JSON');
  }
  pass('output is valid JSON for every successful command');

  // one-shot cleanup: the gateway child must not linger after the CLI exits
  const before = countLnwjudGatewayProcesses();
  await run(['status']);
  await new Promise((resolve) => setTimeout(resolve, 500));
  const after = countLnwjudGatewayProcesses();
  assert.ok(after <= before, `gateway process count must not grow after a one-shot call (before=${before}, after=${after})`);
  pass('child restricted gateway exits/cleans up after one-shot call');

  // --- adversarial / negative path ---

  const unknown = await run(['delete']);
  assert.notEqual(unknown.code, 0);
  assert.equal(unknown.json.error.code, 'UNKNOWN_COMMAND');
  pass('unknown command refused');

  const absolutePath = await run(['read', 'D:\\EA_LAB\\PROJECT_STATE.md']);
  assert.notEqual(absolutePath.code, 0);
  assert.equal(absolutePath.json.error.code, 'PATH_DENIED');
  pass('absolute read path refused');

  const traversal = await run(['read', '../AGENTS.md']);
  assert.notEqual(traversal.code, 0);
  assert.equal(traversal.json.error.code, 'PATH_DENIED');
  pass('traversal read path refused');

  const unc = await run(['read', '\\\\server\\share\\file.txt']);
  assert.notEqual(unc.code, 0);
  assert.equal(unc.json.error.code, 'PATH_DENIED');
  pass('UNC read path refused');

  for (const bad of ['shell', 'powershell', 'cmd', 'bash']) {
    const result = await run([bad]);
    assert.notEqual(result.code, 0);
    assert.equal(result.json.error.code, 'UNKNOWN_COMMAND');
  }
  pass('arbitrary shell/powershell/cmd/bash command names refused');

  for (const bad of ['call-tool', 'write_file', 'apply_patch']) {
    const result = await run([bad, 'x']);
    assert.notEqual(result.code, 0);
    assert.equal(result.json.error.code, 'UNKNOWN_COMMAND');
  }
  pass('arbitrary MCP tool name / write_file / apply_patch refused (no such commands exist)');

  const unauthorizedProfile = await run(['execute', 'release']);
  assert.notEqual(unauthorizedProfile.code, 0);
  assert.equal(unauthorizedProfile.json.error.code, 'POLICY_DENIED');
  pass('arbitrary/unauthorized execute profile refused');

  const mutationProfile = await run(['execute', 'build']);
  assert.notEqual(mutationProfile.code, 0);
  assert.equal(mutationProfile.json.error.code, 'POLICY_DENIED');
  assert.match(mutationProfile.json.error.message, /observe role cannot mutate/);
  pass('mutation-capable execute profile refused under EA-OBSERVE role (no mutation exposed)');

  const unrestricted = await run(['status'], { LNWJUD_UNRESTRICTED: '1' });
  assert.notEqual(unrestricted.code, 0);
  assert.equal(unrestricted.json.error.code, 'UNSAFE_ENVIRONMENT');
  pass('unsafe LNWJUD_UNRESTRICTED environment fails closed');

  const malformed = await run(['read']);
  assert.notEqual(malformed.code, 0);
  assert.equal(malformed.json.error.code, 'MALFORMED_INPUT');
  const malformedExtra = await run(['status', 'unexpected-arg']);
  assert.notEqual(malformedExtra.code, 0);
  assert.equal(malformedExtra.json.error.code, 'MALFORMED_INPUT');
  pass('malformed CLI input (missing/extra args) refused');

  // dirty tracked checkout must be refused
  const trackedFile = path.join(root, 'tools', 'lnwjud', 'fixtures', 'README.md');
  const original = await fsp.readFile(trackedFile, 'utf8');
  try {
    await fsp.writeFile(trackedFile, `${original}\n<!-- lnwjudctl dirty-checkout test -->\n`, 'utf8');
    const dirty = await run(['status']);
    assert.notEqual(dirty.code, 0);
    assert.equal(dirty.json.error.code, 'GATEWAY_CONNECTION_FAILED');
    pass('dirty tracked checkout refused');
  } finally {
    await fsp.writeFile(trackedFile, original, 'utf8');
  }

  // non-canonical lineage (wrong canonical_base_sha) must be refused
  const originalPolicy = await fsp.readFile(policyPath, 'utf8');
  try {
    const mutated = JSON.parse(originalPolicy);
    mutated.canonical_base_sha = '0000000000000000000000000000000000000000';
    await fsp.writeFile(policyPath, JSON.stringify(mutated), 'utf8');
    const wrongLineage = await run(['status']);
    assert.notEqual(wrongLineage.code, 0);
    assert.equal(wrongLineage.json.error.code, 'GATEWAY_CONNECTION_FAILED');
    pass('non-canonical lineage (wrong canonical_base_sha) refused');
  } finally {
    await fsp.writeFile(policyPath, originalPolicy, 'utf8');
  }

  // secret-like environment values must never be echoed
  const secretValue = ['SYNTHETIC', 'LNWJUDCTL', 'SECRET', 'DO', 'NOT', 'LOG'].join('_');
  const withSecrets = await run(['status'], {
    CONTROL_PLANE_API_KEY: secretValue,
    OPENAI_API_KEY: secretValue,
  });
  assert.ok(!withSecrets.stdout.includes(secretValue), 'secret-like environment values must never be emitted');
  pass('secret-like environment values are never emitted');

  process.stdout.write(`RESULT: ${passed} PASS\n`);
}

function countLnwjudGatewayProcesses() {
  try {
    const { execSync } = require('node:child_process');
    const output = execSync(
      'powershell -NoProfile -Command "(Get-CimInstance Win32_Process -Filter \\"Name=\'node.exe\'\\" | Where-Object { $_.CommandLine -like \'*ea-lab-gateway.cjs*lnwjudctl-policy.json*\' } | Measure-Object).Count"',
      { encoding: 'utf8', windowsHide: true },
    );
    return Number.parseInt(output.trim(), 10) || 0;
  } catch {
    return 0;
  }
}

main().catch((error) => {
  process.stderr.write(`RESULT: FAIL ${error instanceof Error ? error.stack : String(error)}\n`);
  process.exitCode = 1;
});
