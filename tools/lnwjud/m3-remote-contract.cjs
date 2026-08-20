#!/usr/bin/env node
'use strict';

// M3 never opens a listener. It only validates the local half of an outbound
// tunnel launch; the owner must supply and activate the external tunnel.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..', '..');
const CONTRACT_PATH = path.join(__dirname, 'm3-remote-contract.json');
const SHA = /^[0-9a-f]{40}$/i;
const SECRET_NAME = /^[A-Z][A-Z0-9_]{2,127}$/;
const EXACT_GATEWAY = ['node', 'tools/lnwjud/ea-lab-gateway.cjs', '--policy', 'tools/lnwjud/ea-lab-policy.json'];

function fail(message) { throw new Error(`M3 contract refused: ${message}`); }
function object(value, name) { if (value === null || typeof value !== 'object' || Array.isArray(value)) fail(`${name} must be an object`); return value; }
function text(value, name) { if (typeof value !== 'string' || value.trim() === '') fail(`${name} is required`); return value; }
function relative(value, name) {
  const item = text(value, name).replaceAll('\\', '/');
  if (path.win32.isAbsolute(value) || item.startsWith('/') || item.split('/').includes('..')) fail(`${name} must be a relative non-traversal path`);
  return item.replace(/^\.\//, '');
}
function readJson(file) { try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { fail(`cannot read JSON ${path.basename(file)}`); } }
function sameArray(left, right) { return Array.isArray(left) && left.length === right.length && left.every((value, index) => value === right[index]); }
function git(worktree, args) { return execFileSync('git', args, { cwd: worktree, encoding: 'utf8', windowsHide: true }).trim(); }

function loadContract(file = CONTRACT_PATH) {
  const value = object(readJson(file), 'contract');
  const allowed = new Set(['schema_version', 'canonical_base_sha', 'transport', 'listener', 'gateway_policy', 'gateway_command', 'tunnel_profile', 'credential_environment', 'activation']);
  if (Object.keys(value).some((key) => !allowed.has(key))) fail('unknown contract field');
  if (value.schema_version !== 1) fail('unsupported schema_version');
  const canonicalBaseSha = text(value.canonical_base_sha, 'canonical_base_sha').toLowerCase();
  if (!SHA.test(canonicalBaseSha)) fail('canonical_base_sha must be a SHA');
  if (value.transport !== 'OUTBOUND_STDIO_TUNNEL') fail('only outbound stdio transport is allowed');
  if (value.listener !== 'NONE') fail('listeners are forbidden');
  const gatewayPolicy = relative(value.gateway_policy, 'gateway_policy');
  if (!sameArray(value.gateway_command, EXACT_GATEWAY)) fail('gateway_command must be the exact restricted gateway command');
  const tunnelProfile = text(value.tunnel_profile, 'tunnel_profile');
  if (!/^[a-z0-9-]{3,64}$/.test(tunnelProfile)) fail('tunnel_profile is invalid');
  const credentialEnvironment = text(value.credential_environment, 'credential_environment');
  if (!SECRET_NAME.test(credentialEnvironment)) fail('credential_environment is invalid');
  if (value.activation !== 'OWNER_REQUIRED') fail('activation must remain owner-required');
  return Object.freeze({ canonicalBaseSha, gatewayPolicy, tunnelProfile, credentialEnvironment });
}

function validateLocalReadiness({ contract = loadContract(), worktree = ROOT, env = process.env } = {}) {
  const root = path.resolve(worktree);
  if (git(root, ['rev-parse', '--show-toplevel']).replaceAll('/', '\\').toLowerCase() !== root.replaceAll('/', '\\').toLowerCase()) fail('worktree must be its Git checkout root');
  if (git(root, ['status', '--porcelain', '--untracked-files=no']) !== '') fail('worktree has tracked mutations');
  try { git(root, ['merge-base', '--is-ancestor', contract.canonicalBaseSha, 'HEAD']); }
  catch { fail('worktree is outside canonical-base lineage'); }
  if (env.LNWJUD_UNRESTRICTED !== undefined) fail('unrestricted upstream mode is forbidden');
  const policyPath = path.join(root, contract.gatewayPolicy);
  const policy = object(readJson(policyPath), 'gateway policy');
  if (String(policy.canonical_base_sha || '').toLowerCase() !== contract.canonicalBaseSha) fail('gateway policy canonical base mismatch');
  if (policy.worktree !== 'POLICY_CHECKOUT') fail('gateway policy must bind its own checkout');
  if (!Array.isArray(policy.protected_worktree_roots) || !policy.protected_worktree_roots.some((item) => String(item).replaceAll('/', '\\').toLowerCase() === 'd:\\ea_lab')) fail('dirty primary protection is missing');
  const present = typeof env[contract.credentialEnvironment] === 'string' && env[contract.credentialEnvironment].trim().length >= 24;
  return Object.freeze({
    state: present ? 'READY_FOR_OWNER_ACTIVATION' : 'BLOCKED(E)',
    transport: 'OUTBOUND_STDIO_TUNNEL',
    listener: 'NONE',
    credential_environment: contract.credentialEnvironment,
    credential_present: present,
    canonical_base_sha: contract.canonicalBaseSha,
    gateway_command: [...EXACT_GATEWAY],
    owner_action: `Owner must configure and activate the external outbound tunnel profile ${contract.tunnelProfile} with ${contract.credentialEnvironment} for canonical build ${git(root, ['rev-parse', 'HEAD'])}; it launches only the restricted stdio gateway and creates no EA_LAB public listener.`
  });
}

if (require.main === module) {
  const result = validateLocalReadiness();
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  process.exitCode = result.state === 'READY_FOR_OWNER_ACTIVATION' ? 0 : 2;
}

module.exports = { loadContract, validateLocalReadiness };
