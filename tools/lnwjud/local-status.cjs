#!/usr/bin/env node
'use strict';

const { execFileSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = 'D:\\EA_LAB_CONTROL';
const POLICY_CHECKOUT = path.resolve(__dirname, '..', '..');
const CONTRACT_PATH = path.join(__dirname, 'status-contract.json');
const MAX_ERROR = 180;

function text(value, name) { if (typeof value !== 'string' || value.trim() === '') throw new Error(`${name} is required`); return value; }
function sha(value, name) { value = text(value, name).toLowerCase(); if (!/^[0-9a-f]{40}$/.test(value)) throw new Error(`${name} must be a 40-character SHA`); return value; }
function isoNow(value) { const date = value ? new Date(value) : new Date(); if (Number.isNaN(date.valueOf())) throw new Error('generated_at is invalid'); return date.toISOString().replace(/\.\d{3}Z$/, 'Z'); }
function git(cwd, args) { try { return execFileSync('git', args, { cwd, encoding: 'utf8', windowsHide: true }).trim().toLowerCase(); } catch { return null; } }
function sanitize(value) {
  let output = String(value ?? '').replace(/[\r\n\t]+/g, ' ')
    .replace(/(api[_-]?key|token|secret|password|authorization)\s*[:=]\s*[^\s,;]+/gi, '$1=[REDACTED]')
    .replace(/\b(?:sk|rk|pk)-[A-Za-z0-9_-]+\b/g, '[REDACTED]')
    .replace(/\bBearer\s+[^\s,;]+/gi, 'Bearer [REDACTED]');
  if (output.length > MAX_ERROR) output = `${output.slice(0, MAX_ERROR)}…[TRUNCATED]`;
  return output;
}
function error(code, message) { return { code, message: sanitize(message) }; }
function readJson(file) { return JSON.parse(fs.readFileSync(file, 'utf8')); }
function loadContract(file = CONTRACT_PATH) {
  const value = readJson(file);
  if (value?.schema_version !== 1) throw new Error('unsupported status contract');
  return {
    schema_version: 1,
    canonical_base_sha: sha(value.canonical_base_sha, 'canonical_base_sha'),
    lnwjud: { expected_version: text(value?.lnwjud?.expected_version, 'expected_version'), expected_sha: sha(value?.lnwjud?.expected_sha, 'expected_sha'), source_path: text(value?.lnwjud?.source_path, 'source_path') },
    gateway: { authorized_workspace: text(value?.gateway?.authorized_workspace, 'authorized_workspace'), local_transport: text(value?.gateway?.local_transport, 'local_transport'), runtime_root: text(value?.gateway?.runtime_root, 'runtime_root') },
    milestone: { local_execution_plane: text(value?.milestone?.local_execution_plane, 'local_execution_plane'), secure_tunnel: text(value?.milestone?.secure_tunnel, 'secure_tunnel'), remote_chatgpt: text(value?.milestone?.remote_chatgpt, 'remote_chatgpt') }
  };
}
function safePolicy(file) {
  try {
    const value = readJson(file);
    return { value, error: null };
  } catch { return { value: null, error: error('POLICY_INVALID', 'policy unavailable or malformed') }; }
}
function safeLock(runtimeRoot) {
  const file = path.join(runtimeRoot, 'active-writer.json');
  if (!fs.existsSync(file)) return { state: 'NOT_RUNNING', owner: null, error: null };
  try {
    const value = readJson(file);
    return { state: 'PRESENT', owner: typeof value.task_id === 'string' ? value.task_id : null, pid: Number.isInteger(value.pid) ? value.pid : null, base_sha: typeof value.base_sha === 'string' && /^[0-9a-f]{40}$/i.test(value.base_sha) ? value.base_sha.toLowerCase() : null, error: null };
  } catch { return { state: 'UNKNOWN', owner: null, base_sha: null, error: error('WRITER_LOCK_INVALID', 'writer lock is malformed') }; }
}
function liveProcesses() {
  try {
    const raw = execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', 'Get-CimInstance Win32_Process | Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress'], { encoding: 'utf8', windowsHide: true });
    const rows = JSON.parse(raw || '[]');
    return (Array.isArray(rows) ? rows : [rows]).filter((row) => typeof row?.CommandLine === 'string' && row.CommandLine.includes('ea-lab-gateway.cjs')).map((row) => ({ pid: Number(row.ProcessId), name: String(row.Name || 'unknown') }));
  } catch { return null; }
}
function liveListeners(processes) {
  if (processes === null || processes.length === 0) return [];
  try {
    const raw = execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', 'Get-NetTCPConnection -State Listen | Select-Object OwningProcess,LocalAddress,LocalPort | ConvertTo-Json -Compress'], { encoding: 'utf8', windowsHide: true });
    const pids = new Set(processes.map((row) => row.pid));
    const rows = JSON.parse(raw || '[]');
    return (Array.isArray(rows) ? rows : [rows]).filter((row) => pids.has(Number(row?.OwningProcess))).map((row) => ({ address: String(row.LocalAddress || ''), port: Number(row.LocalPort) }));
  } catch { return null; }
}
function listenerState(processes, listeners) {
  if (processes === null || listeners === null) return 'UNKNOWN';
  if (listeners.some((row) => !['127.0.0.1', '::1', 'localhost'].includes(row.address))) return 'NON_LOOPBACK_LISTENER_OBSERVED';
  if (listeners.length > 0) return 'LOOPBACK_LISTENER_OBSERVED';
  return 'NO_RELEVANT_LISTENER_OBSERVED';
}
function tunnelLifecycle(remote, contract) {
  const state = typeof remote?.state === 'string' ? remote.state : null;
  const allowed = new Set(['NOT_CONFIGURED_OWNER_ACTION_REQUIRED', 'AUTH_FAILED', 'DOCTOR_FAILED', 'ACTIVATING', 'CONNECTED', 'DISCONNECTED', 'UNKNOWN_STALE', 'UNKNOWN_UNBOUND', 'UNKNOWN_NO_CURRENT_EVIDENCE', 'COMPLETED']);
  if (state !== null && allowed.has(state)) return state;
  return contract.milestone.secure_tunnel;
}
function fileSha(file) { try { return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'); } catch { return null; } }
const EVIDENCE_TTL_MS = 10 * 60 * 1000;
const EVIDENCE_FUTURE_SKEW_MS = 60 * 1000;
function evidenceFresh(generatedAt, now = Date.now()) {
  const generated = Date.parse(generatedAt);
  return Number.isFinite(generated) && now - generated <= EVIDENCE_TTL_MS && generated - now <= EVIDENCE_FUTURE_SKEW_MS;
}
function safeTunnelEvidence(runtimeRoot, context = {}) {
  try {
    const value = readJson(path.join(runtimeRoot, 'm3-tunnel-state.json'));
    if (value?.schema_version !== 2 || !['DOCTOR_PASSED', 'AUTH_FAILED', 'DOCTOR_FAILED', 'CONNECTED', 'DISCONNECTED'].includes(value.state)) return { state: 'UNKNOWN_UNBOUND', error: null };
    if (typeof value.checkout_head !== 'string' || value.checkout_head !== context.actual_head || value.profile !== 'ea-lab-lnwjud-m3') return { state: 'UNKNOWN_UNBOUND', error: null };
    if (value.state === 'DOCTOR_PASSED' && (value.artifact !== path.join(runtimeRoot, 'm3-sealed-profile.yaml') || value.profile_sha256 !== fileSha(value.artifact) || !value.launcher_sha256 || value.launcher_sha256 !== fileSha(path.join(context.workspace || '', 'tools', 'lnwjud', 'm3-restricted-launcher.cmd')) || !value.policy_sha256 || value.policy_sha256 !== fileSha(path.join(context.workspace || '', 'tools', 'lnwjud', 'ea-lab-policy.json')) || !value.tunnel_client_sha256 || typeof value.tunnel_client_sha256 !== 'string')) return { state: 'UNKNOWN_UNBOUND', error: null };
    if (!evidenceFresh(value.generated_at)) return { state: 'UNKNOWN_STALE', error: null };
    return { state: value.state, error: null };
  } catch { return { state: 'UNKNOWN_UNBOUND', error: null }; }
}
function tunnelClientCommandMatches(commandLine, runtimeRoot) {
  if (typeof commandLine !== 'string' || typeof runtimeRoot !== 'string' || runtimeRoot === '') return false;
  const prefix = path.join(runtimeRoot, 'm3-launch-').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const pattern = new RegExp(`--profile-file\\s+"?${prefix}[0-9a-f]{64}\\.yaml"?`, 'i');
  return pattern.test(commandLine);
}
function liveTunnelClient(runtimeRoot) {
  try {
    const raw = execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', "Get-CimInstance Win32_Process -Filter \"Name = 'tunnel-client.exe'\" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty CommandLine | ConvertTo-Json -Compress"], { encoding: 'utf8', windowsHide: true });
    const trimmed = raw.trim();
    const rows = trimmed === '' ? [] : JSON.parse(trimmed);
    const lines = Array.isArray(rows) ? rows : [rows];
    return lines.some((line) => tunnelClientCommandMatches(line, runtimeRoot));
  } catch { return false; }
}
function deriveStatus(input) {
  const contract = input.contract;
  const actualHead = input.actual_head || null;
  const policy = input.policy || null;
  const lock = input.lock || { state: 'NOT_RUNNING', owner: null, pid: null, base_sha: null, error: null };
  const policyHead = typeof policy?.base_sha === 'string' && /^[0-9a-f]{40}$/i.test(policy.base_sha) ? policy.base_sha.toLowerCase() : null;
  const dynamicHead = policy?.base_sha === 'WORKTREE_HEAD_AT_START' && /^[0-9a-f]{40}$/i.test(lock.base_sha || '') ? lock.base_sha.toLowerCase() : null;
  const expectedHead = policyHead || dynamicHead;
  const headMatch = expectedHead !== null && actualHead !== null && expectedHead === actualHead;
  const processes = input.processes === undefined ? [] : input.processes;
  const active = Array.isArray(processes) ? processes : [];
  const owned = lock.state === 'PRESENT' && lock.pid !== null ? active.filter((row) => row.pid === lock.pid) : [];
  const gatewayHealth = processes === null ? 'UNKNOWN' : active.length === 0 ? 'OFFLINE' : headMatch ? 'RUNNING' : 'DEGRADED';
  const index = input.index || (gatewayHealth === 'RUNNING' ? { state: 'UNKNOWN', source: 'UNAVAILABLE', coverage: 'PARTIAL', last_known_refresh: null, error: error('INDEX_UNOBSERVED', 'index requires a gateway query') } : { state: 'NOT_READY', source: 'GATEWAY_PROCESS', coverage: 'PARTIAL', last_known_refresh: null, error: error('GATEWAY_OFFLINE', 'index is unavailable while gateway is not running') });
  const lastError = input.last_error ? error(input.last_error.code || 'RUNTIME_ERROR', input.last_error.message || '') : lock.error || index.error || null;
  const reviewFrozen = policy?.review_state === 'FROZEN';
  const reviewState = input.review_state || (reviewFrozen ? 'REVIEW_PENDING' : 'NOT_REVIEWED');
  const securityState = input.security_state || 'UNKNOWN';
  const processState = active.length === 0 ? 'NOT_RUNNING' : owned.length > 0 ? 'OWNED' : 'UNOWNED';
  const listener = input.listener_state || listenerState(processes);
  const remote = input.tunnel || { configured: false, client_detected: false };
  let tunnelState = tunnelLifecycle(remote, contract);
  if (remote.evidence_state === 'AUTH_FAILED' || remote.evidence_state === 'DOCTOR_FAILED') tunnelState = remote.evidence_state;
  else if (remote.evidence_state === 'DOCTOR_PASSED') tunnelState = remote.client_detected ? 'CONNECTED' : 'UNKNOWN_NO_CURRENT_EVIDENCE';
  else if (remote.previous_state === 'CONNECTED' && !remote.client_detected) tunnelState = 'DISCONNECTED';
  const controlState = policy === null || lock.error !== null ? 'ERROR' : !headMatch || listener === 'NON_LOOPBACK_LISTENER_OBSERVED' || index.state === 'ERROR' ? 'DEGRADED' : 'OK';
  const output = {
    schema_version: 1,
    generated_at: isoNow(input.generated_at),
    control_state: controlState,
    lnwjud: { expected_version: contract.lnwjud.expected_version, expected_sha: contract.lnwjud.expected_sha, source_path: contract.lnwjud.source_path, actual_sha: input.actual_source_sha || null, pin_match: input.actual_source_sha === contract.lnwjud.expected_sha },
    ea_lab_gateway: { health: gatewayHealth, policy_version: policy?.schema_version ?? null, authorized_workspace: input.authorized_workspace || contract.gateway.authorized_workspace, expected_head: expectedHead, actual_head: actualHead, head_match: headMatch, writer_owner: lock.owner, writer_state: lock.state, review_frozen: reviewFrozen },
    index: { state: index.state, source: index.source || 'UNAVAILABLE', coverage: index.coverage || 'PARTIAL', last_known_refresh: index.last_known_refresh || null, error: index.error || null },
    processes: { state: processState, task_owned_count: owned.length, relevant_background_tasks: owned.map((row) => ({ pid: row.pid, name: row.name })) },
    network: { local_transport: contract.gateway.local_transport, listener_state: listener, public_listener_detected: listener === 'NON_LOOPBACK_LISTENER_OBSERVED', tunnel_state: tunnelState, tunnel_client_detected: Boolean(remote.client_detected), remote_chatgpt: contract.milestone.remote_chatgpt },
    audit: { available: false, source: 'UNAVAILABLE', coverage: 'PARTIAL', last_error: lastError },
    milestone: { completion: tunnelState === 'COMPLETED' && contract.milestone.local_execution_plane === 'PASS' ? 'COMPLETE' : 'INCOMPLETE', health: gatewayHealth, review: reviewState, security: securityState, local_execution_plane: contract.milestone.local_execution_plane, secure_tunnel: tunnelState, overall: tunnelState === 'COMPLETED' ? contract.milestone.local_execution_plane : 'PARTIAL' }
  };
  return output;
}
function collectLiveStatus(options = {}) {
  const contract = loadContract(options.contract_path || CONTRACT_PATH);
  const policyPath = options.policy_path || path.join(__dirname, 'ea-lab-policy.json');
  const policyResult = safePolicy(policyPath);
  const runtimeRoot = contract.gateway.runtime_root;
  const workspace = contract.gateway.authorized_workspace === 'POLICY_CHECKOUT' ? POLICY_CHECKOUT : contract.gateway.authorized_workspace;
  const processes = liveProcesses();
  const listeners = liveListeners(processes);
  const actualHead = git(workspace, ['rev-parse', 'HEAD']);
  const evidence = safeTunnelEvidence(runtimeRoot, { actual_head: actualHead, workspace });
  return deriveStatus({ contract, generated_at: options.generated_at, actual_source_sha: git(contract.lnwjud.source_path, ['rev-parse', 'HEAD']), actual_head: actualHead, authorized_workspace: workspace, policy: policyResult.value, processes, lock: safeLock(runtimeRoot), listener_state: listenerState(processes, listeners), tunnel: { evidence_state: evidence.state, client_detected: liveTunnelClient(runtimeRoot) }, last_error: policyResult.error });
}
function lane(status) {
  const problem = status.audit.last_error;
  const accepted = status.control_state === 'OK' && status.ea_lab_gateway.health === 'HEALTHY' && status.ea_lab_gateway.head_match && status.milestone.review === 'PASS' && status.milestone.security === 'PASS';
  const statusCode = status.control_state === 'ERROR' ? 'ERROR' : accepted ? 'DONE' : 'BLOCKED';
  return { lane: 'lnwjud-local-execution-plane', status: statusCode, updated_at: status.generated_at, progress: accepted ? 100 : 0, task: 'LNWJUD local execution plane', owner: 'EA_LAB local agent', detail: sanitize(`completion=${status.milestone.completion}; health=${status.milestone.health}; review=${status.milestone.review}; security=${status.milestone.security}; control=${status.control_state}; head_match=${status.ea_lab_gateway.head_match}; index=${status.index.state}/${status.index.coverage}; audit=${status.audit.coverage}; tunnel=${status.network.tunnel_state}; last_error=${problem ? problem.code : 'NONE_OBSERVED'}`) };
}
function writeAtomic(file, content) { fs.mkdirSync(path.dirname(file), { recursive: true }); const temp = `${file}.tmp.${process.pid}`; fs.writeFileSync(temp, content, 'utf8'); fs.renameSync(temp, file); }
function publish(status) { writeAtomic(path.join(ROOT, 'lnwjud-local-status.json'), `${JSON.stringify(status, null, 2)}\n`); writeAtomic(path.join(ROOT, 'lanes', 'lnwjud-local-execution-plane.json'), `${JSON.stringify(lane(status), null, 2)}\n`); }
function parseArgs(argv) { const options = {}; for (let i = 0; i < argv.length; i += 1) { if (argv[i] === '--publish') options.publish = true; else if (argv[i] === '--now') options.generated_at = argv[++i]; else throw new Error('usage: local-status.cjs [--publish] [--now <ISO-8601>]'); } return options; }
if (require.main === module) { const options = parseArgs(process.argv.slice(2)); const status = collectLiveStatus(options); if (options.publish) publish(status); process.stdout.write(`${JSON.stringify(status, null, 2)}\n`); }
module.exports = { loadContract, sanitize, deriveStatus, collectLiveStatus, lane, tunnelLifecycle, safeTunnelEvidence, evidenceFresh, tunnelClientCommandMatches };
