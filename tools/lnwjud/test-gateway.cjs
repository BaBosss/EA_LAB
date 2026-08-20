#!/usr/bin/env node
'use strict';

const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const root = path.resolve(__dirname, '..', '..');
const sourceRoot = process.env.LNWJUD_SOURCE_ROOT || 'D:\\EA_LAB_TOOLS\\lnwjud-v4-src';
const sourceRequire = require('node:module').createRequire(path.join(sourceRoot, 'packages', 'mcp-server', 'package.json'));
const { Client } = sourceRequire('@modelcontextprotocol/client');
const { StdioClientTransport } = sourceRequire('@modelcontextprotocol/client/stdio');
const gateway = path.join(__dirname, 'ea-lab-gateway.cjs');
const policyPath = path.join(__dirname, 'ea-lab-policy.json');
const fixtureRoot = path.join(__dirname, 'fixtures');
const secret = ['SYNTHETIC', 'LNWJUD', 'SECRET', 'DO', 'NOT', 'LOG'].join('_');
let passed = 0;
let lastDiagnostics = '';
const openClients = new Set();

function pass(name) {
  passed += 1;
  process.stdout.write(`[PASS] ${name}\n`);
}

function clonePolicy(overrides = {}) {
  const policy = JSON.parse(fs.readFileSync(policyPath, 'utf8'));
  Object.assign(policy, overrides);
  const target = path.join(os.tmpdir(), `lnwjud-policy-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}.json`);
  fs.writeFileSync(target, JSON.stringify(policy), 'utf8');
  return target;
}

async function connect(policy, runtime, selectedWorktree = root) {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [gateway, '--policy', policy],
    env: { ...process.env, LNWJUD_SOURCE_ROOT: sourceRoot, LNWJUD_DATA_PATH: runtime, EA_LAB_APPROVED_WORKTREE: selectedWorktree },
    stderr: 'pipe',
    cwd: root,
  });
  let diagnostics = '';
  transport.stderr?.on('data', (chunk) => { diagnostics += chunk.toString('utf8'); lastDiagnostics = diagnostics; });
  const client = new Client(
    { name: 'ea-lab-gateway-acceptance', version: '1.0.0' },
    { versionNegotiation: { mode: { pin: '2026-07-28' } } },
  );
  try { await client.connect(transport); }
  catch (error) {
    await client.close().catch(() => undefined);
    throw new Error(`gateway connection failed: ${error instanceof Error ? error.message : String(error)}; diagnostics=${diagnostics}`);
  }
  openClients.add(client);
  return { client, diagnostics: () => diagnostics };
}

async function closeClient(client) {
  openClients.delete(client);
  await client.close();
}

async function call(client, name, args) {
  return client.callTool({ name, arguments: args });
}

function responseText(response) {
  return JSON.stringify(response);
}

function assertDenied(response, name) {
  assert.equal(response.isError, true, `${name} must be an MCP error`);
  pass(name);
}

function assertAllowed(response, name) {
  assert.notEqual(response.isError, true, `${name} must not be an MCP error: ${responseText(response)}`);
}

async function waitForProcess(client, workspaceId, processId) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const status = await call(client, 'process_status', { workspaceId, processId });
    const state = status.structuredContent?.state;
    if (['exited', 'failed', 'stopped', 'timed_out'].includes(state)) return status;
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error('owned acceptance process did not terminate');
}

async function executeProfile(client, workspaceId, profile) {
  const started = await call(client, 'ea_lab_execute', { workspaceId, profile });
  assertAllowed(started, `${profile} execution start`);
  const processId = started.structuredContent?.processId;
  assert.equal(typeof processId, 'string', `${profile} must return an owned process id`);
  const status = await waitForProcess(client, workspaceId, processId);
  assert.equal(status.structuredContent?.state, 'exited', `${profile} must exit successfully`);
  assert.equal(status.structuredContent?.exitCode, 0, `${profile} must exit 0`);
  const logs = await call(client, 'process_logs', { workspaceId, processId, tailLines: 40 });
  assertAllowed(logs, `${profile} execution logs`);
  const entries = logs.structuredContent?.entries;
  return { processId, logs: Array.isArray(entries) ? entries.map((entry) => entry.text).join('') : responseText(logs) };
}

async function main() {
  const testRuntime = path.join('D:\\EA_LAB_CONTROL', `lnwjud-v4-test-${process.pid}`);
  const outputDir = path.join(fixtureRoot, 'runtime');
  const m2OutputDir = path.join(fixtureRoot, 'm2-exec', 'runtime');
  const secretPath = path.join(fixtureRoot, '.env');
  const normalPolicy = clonePolicy();
  const mismatchPolicy = clonePolicy({ base_sha: '0000000000000000000000000000000000000000' });
  const frozenPolicy = clonePolicy({ review_state: 'FROZEN' });
  await fsp.mkdir(testRuntime, { recursive: true });
  await fsp.mkdir(outputDir, { recursive: true });
  await fsp.writeFile(secretPath, `${secret}=value\n`, 'utf8');
  try {
    const primary = await connect(normalPolicy, testRuntime);
    const tools = await primary.client.listTools();
    const names = new Set(tools.tools.map((tool) => tool.name));
    assert(names.has('ea_lab_status'));
    assert(names.has('ea_lab_execute'));
    for (const required of ['context_economy_stats', 'telemetry_dashboard', 'route_intent', 'tool_search', 'tool_dynamic_filter']) assert(names.has(required), `${required} must be exposed`);
    for (const forbidden of ['git', 'delete_file', 'workspace_register', 'workspace_list', 'codex_run', 'shell_exec', 'tool_batch', 'parallel_delegate']) assert(!names.has(forbidden), `${forbidden} must not be exposed`);
    pass('bounded tool catalog');

    const status = await call(primary.client, 'ea_lab_status', {});
    assertAllowed(status, 'status');
    const workspaceId = status.structuredContent.workspace_id;
    assert.equal(typeof workspaceId, 'string');
    pass('exact workspace binding');

    const health = await call(primary.client, 'health', { operation: 'check_all' });
    assertAllowed(health, 'health');
    pass('health');

    const economy = await call(primary.client, 'context_economy_stats', {});
    const telemetry = await call(primary.client, 'telemetry_dashboard', {});
    const route = await call(primary.client, 'route_intent', { prompt: 'find relevant tests for the lnwjud gateway' });
    const searchMetadata = await call(primary.client, 'tool_search', { query: 'delete a workspace file' });
    const dynamicFilter = await call(primary.client, 'tool_dynamic_filter', { query: 'read gateway files', limit: 8 });
    for (const [name, result] of Object.entries({ economy, telemetry, route, searchMetadata, dynamicFilter })) assertAllowed(result, `M5 ${name}`);
    pass('M5 economy telemetry and router metadata');

    const build = await executeProfile(primary.client, workspaceId, 'build');
    assert.match(build.logs, /\[PASS\] M2 BUILD cwd=.*artifact=/i);
    assert.equal((await fsp.readFile(path.join(m2OutputDir, 'build-artifact.txt'), 'utf8')).toLowerCase(), `m2-build cwd=${root}`.toLowerCase());
    pass('M2 BUILD exact cwd and fixture artifact');

    const test = await executeProfile(primary.client, workspaceId, 'test');
    assert.match(test.logs, /\[PASS\] M2 TEST cwd=.* assertions=passed/i);
    pass('M2 TEST exact cwd and assertions');

    const check = await executeProfile(primary.client, workspaceId, 'check');
    assert.match(check.logs, /\[PASS\] M2 CHECK cwd=.* fixture=present/i);
    pass('M2 CHECK exact cwd');

    const stateCheck = await executeProfile(primary.client, workspaceId, 'state_check');
    assert.match(stateCheck.logs, /PASS|CLEAN|no-op/i);
    pass('real EA_LAB state check');

    const read = await call(primary.client, 'read_file', { workspaceId, path: 'tools/lnwjud/fixtures/README.md', startLine: 1, endLine: 4 });
    assertAllowed(read, 'authorized read');
    pass('authorized read');

    const search = await call(primary.client, 'search_text', { workspaceId, query: 'ControlTowerRelay', maxResults: 5 });
    assertAllowed(search, 'authorized search');
    pass('authorized search');

    const index = await call(primary.client, 'workspace_index', { workspaceId, rebuild: true, includeIgnored: false });
    assertAllowed(index, 'workspace index');
    const indexStatus = await call(primary.client, 'workspace_index_status', { workspaceId });
    assertAllowed(indexStatus, 'workspace index status');
    pass('persistent index');

    for (const tool of ['git_status', 'git_diff', 'git_log']) {
      const result = await call(primary.client, tool, { workspaceId });
      assertAllowed(result, tool);
    }
    pass('git status diff log');

    const write = await call(primary.client, 'write_file', { workspaceId, path: 'tools/lnwjud/fixtures/runtime/pilot.txt', content: 'before\n' });
    assertAllowed(write, 'bounded write');
    const patch = await call(primary.client, 'apply_patch', { workspaceId, files: [{ path: 'tools/lnwjud/fixtures/runtime/pilot.txt', content: 'after\n' }] });
    assertAllowed(patch, 'bounded apply_patch');
    assert.equal(await fsp.readFile(path.join(outputDir, 'pilot.txt'), 'utf8'), 'after\n');
    pass('bounded write apply_patch');

    const processStart = await call(primary.client, 'process_start', { workspaceId, executable: 'powershell.exe', args: ['-NoProfile', '-File', 'tools/lnwjud/run-acceptance-fixture.ps1'] });
    assertAllowed(processStart, 'owned process start');
    const processId = processStart.structuredContent.processId;
    assert.equal(typeof processId, 'string');
    await waitForProcess(primary.client, workspaceId, processId);
    const logs = await call(primary.client, 'process_logs', { workspaceId, processId, tailLines: 20 });
    assert.match(responseText(logs), /lnwjud bounded process fixture/);
    pass('owned process lifecycle');

    const secondWriter = await connect(normalPolicy, testRuntime);
    const secondStatus = await call(secondWriter.client, 'ea_lab_status', {});
    assertDenied(await call(secondWriter.client, 'write_file', { workspaceId: secondStatus.structuredContent.workspace_id, path: 'tools/lnwjud/fixtures/runtime/second-writer.txt', content: 'no' }), 'deny second writer mutation');
    assertDenied(await call(secondWriter.client, 'ea_lab_execute', { workspaceId: secondStatus.structuredContent.workspace_id, profile: 'build' }), 'deny second writer BUILD');
    await closeClient(secondWriter.client);
    pass('one writer guard');

    assertDenied(await call(primary.client, 'write_file', { workspaceId, path: 'D:\\EA_LAB\\blocked.txt', content: 'no' }), 'deny dirty master mutation');
    assertDenied(await call(primary.client, 'write_file', { workspaceId, path: 'docs/blocked.txt', content: 'no' }), 'deny outside allowed paths');
    assertDenied(await call(primary.client, 'read_file', { workspaceId, path: 'tools/lnwjud/fixtures/.env' }), 'deny secret read');
    assertDenied(await call(primary.client, 'search_text', { workspaceId, query: 'anything', includeIgnored: true }), 'deny search override');
    assertDenied(await call(primary.client, 'process_start', { workspaceId, executable: 'shutdown.exe', args: ['/r'] }), 'deny shutdown reboot');
    await assert.rejects(call(primary.client, 'delete_file', { workspaceId, path: 'tools/lnwjud/fixtures/runtime/pilot.txt' }), /Tool delete_file not found/);
    pass('M5 deny router-discovered delete tool invocation');
    await assert.rejects(call(primary.client, 'tool_batch', { parallel: true, calls: [{ tool: 'write_file', arguments: { workspaceId, path: 'tools/lnwjud/fixtures/runtime/batch.txt', content: 'no' } }] }), /Tool tool_batch not found/);
    pass('M5 deny mutation batch invocation');
    assertDenied(await call(primary.client, 'workspace_context', { workspaceId, query: 'dirty root', path: 'D:\\EA_LAB' }), 'M5 deny dirty root context');
    assertDenied(await call(primary.client, 'workspace_context', { workspaceId, query: 'secret fixture', path: 'tools/lnwjud/fixtures/.env' }), 'M5 deny secret context');
    assertDenied(await call(primary.client, 'workspace_context', { workspaceId, query: 'traversal', path: '..\\AGENTS.md' }), 'M5 deny context traversal');
    assertDenied(await call(primary.client, 'workspace_context', { workspaceId, query: 'large response', responseTargetBytes: 65_537 }), 'M5 deny oversized context');
    assertDenied(await call(primary.client, 'process_start', { workspaceId, executable: 'powershell.exe', args: ['-NoProfile', '-File', 'tools/lnwjud/fixtures/m2-exec/run.ps1', '-Profile', 'build'], cwd: 'D:\\EA_LAB' }), 'deny CWD escape');
    assertDenied(await call(primary.client, 'process_start', { workspaceId, executable: 'powershell.exe', args: ['-NoProfile', '-File', 'tools/lnwjud/fixtures/m2-exec/../m2-exec/run.ps1', '-Profile', 'build'] }), 'deny path traversal');
    assertDenied(await call(primary.client, 'ea_lab_execute', { workspaceId, profile: 'release' }), 'deny unauthorized execution profile');
    assertDenied(await call(primary.client, 'process_start', { workspaceId, executable: 'powershell.exe', args: ['-NoProfile', '-File', 'tools/lnwjud/fixtures/m2-exec/run.ps1', '-Profile', 'build', ';', 'Write-Output', 'injected'] }), 'deny shell injection argv');
    assertDenied(await call(primary.client, 'process_start', { workspaceId, executable: 'powershell.exe', args: ['-NoProfile', '-File', 'tools/lnwjud/fixtures/m2-exec/run.ps1', '-Profile', 'build', '-OutputPath', '..\\outside.txt'] }), 'deny outside-fixture side effect');
    assertDenied(await call(primary.client, 'process_start', { workspaceId, executable: 'git.exe', args: ['push', '--force'] }), 'deny force push');
    assertDenied(await call(primary.client, 'process_start', { workspaceId, executable: 'git.exe', args: ['reset', '--hard'] }), 'deny history rewrite');
    assertDenied(await call(primary.client, 'process_start', { workspaceId, executable: 'powershell.exe', args: ['-NoProfile', '-Command', 'Remove-Item -LiteralPath . -Recurse'] }), 'deny workspace-root deletion');
    assertDenied(await call(primary.client, 'process_stop', { workspaceId, processId: 'unowned-process' }), 'deny unowned process termination');

    const secretSearch = await call(primary.client, 'search_text', { workspaceId, query: 'fixture private setting', maxResults: 10 });
    assertAllowed(secretSearch, 'secret search');
    assert(!responseText(secretSearch).includes(secret), `automatic search leaked synthetic secret: ${responseText(secretSearch)}`);
    const context = await call(primary.client, 'workspace_context', { workspaceId, query: 'lnwjud gateway' });
    assertAllowed(context, 'workspace context');
    assert(!responseText(context).includes(secret), 'context leaked synthetic secret');
    pass('automatic search and context do not leak fixture secret');

    await closeClient(primary.client);

    const mismatch = await connect(mismatchPolicy, testRuntime);
    const mismatchStatus = await call(mismatch.client, 'ea_lab_status', {});
    const mismatchWorkspace = mismatchStatus.structuredContent.workspace_id;
    assertDenied(await call(mismatch.client, 'write_file', { workspaceId: mismatchWorkspace, path: 'tools/lnwjud/fixtures/runtime/mismatch.txt', content: 'no' }), 'deny expected HEAD mismatch');
    assertDenied(await call(mismatch.client, 'ea_lab_execute', { workspaceId: mismatchWorkspace, profile: 'check' }), 'deny expected HEAD mismatch execution');
    assertDenied(await call(mismatch.client, 'process_start', { workspaceId: mismatchWorkspace, executable: 'powershell.exe', args: ['-NoProfile', '-File', 'tools/lnwjud/run-acceptance-fixture.ps1'] }), 'deny expected HEAD mismatch direct process start');
    await closeClient(mismatch.client);

    const frozen = await connect(frozenPolicy, testRuntime);
    const frozenStatus = await call(frozen.client, 'ea_lab_status', {});
    const frozenWorkspace = frozenStatus.structuredContent.workspace_id;
    assertDenied(await call(frozen.client, 'write_file', { workspaceId: frozenWorkspace, path: 'tools/lnwjud/fixtures/runtime/frozen.txt', content: 'no' }), 'deny review freeze mutation');
    assertDenied(await call(frozen.client, 'process_start', { workspaceId: frozenWorkspace, executable: 'powershell.exe', args: ['-NoProfile', '-File', 'tools/lnwjud/run-acceptance-fixture.ps1'] }), 'deny review freeze direct process start');
    assertDenied(await call(frozen.client, 'ea_lab_execute', { workspaceId: frozenWorkspace, profile: 'build' }), 'deny review freeze BUILD');
    const frozenCheck = await executeProfile(frozen.client, frozenWorkspace, 'check');
    assert.match(frozenCheck.logs, /\[PASS\] M2 CHECK/);
    pass('review freeze permits read-only CHECK');
    await closeClient(frozen.client);

    await assert.rejects(connect(normalPolicy, testRuntime, 'D:\\EA_LAB'), /gateway connection failed/);
    pass('deny protected master execution root');
    await assert.rejects(connect(normalPolicy, testRuntime, path.resolve(root, '..', 'lnwjud-execution-plane-20260820')), /gateway connection failed/);
    pass('deny unauthorized sibling execution root');
    const wrongLineagePolicy = clonePolicy({ canonical_base_sha: '0000000000000000000000000000000000000000' });
    await assert.rejects(connect(wrongLineagePolicy, testRuntime), /gateway connection failed/);
    pass('deny repository lineage mismatch');
    await fsp.rm(wrongLineagePolicy, { force: true });

    const activity = await fsp.readFile(path.join(testRuntime, 'mcp-activity.log'), 'utf8');
    assert(!activity.includes(secret), 'audit activity leaked synthetic secret');
    const runtimeBytes = await fsp.readFile(path.join(testRuntime, 'lnwjud.sqlite'));
    assert(!runtimeBytes.includes(Buffer.from(secret, 'utf8')), 'SQLite audit leaked synthetic secret');
    pass('audit and SQLite secret sanitation');

    process.stdout.write(`RESULT: ${passed} PASS\n`);
  } finally {
    await Promise.all([...openClients].map((client) => closeClient(client).catch(() => undefined)));
    await fsp.rm(outputDir, { recursive: true, force: true });
    await fsp.rm(m2OutputDir, { recursive: true, force: true });
    await fsp.rm(secretPath, { force: true });
    await fsp.rm(testRuntime, { recursive: true, force: true });
    for (const policy of [normalPolicy, mismatchPolicy, frozenPolicy]) await fsp.rm(policy, { force: true });
  }
}

main().catch((error) => {
  process.stderr.write(`RESULT: FAIL ${error instanceof Error ? error.stack : String(error)} diagnostics=${lastDiagnostics}\n`);
  process.exitCode = 1;
});
