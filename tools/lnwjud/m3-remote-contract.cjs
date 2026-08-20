#!/usr/bin/env node
'use strict';

// M3 is outbound stdio only. This validates the local half but never starts a
// tunnel or reads an external credential.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const ROOT = path.resolve(__dirname, '..', '..');
const CONTRACT_PATH = path.join(__dirname, 'm3-remote-contract.json');
const SHA = /^[0-9a-f]{40}$/i;
const SECRET_NAME = /^[A-Z][A-Z0-9_]{2,127}$/;
const TRUSTED_SOURCE_ROOT = 'D:\\EA_LAB_TOOLS\\lnwjud-v4-src';

function fail(message) { throw new Error(`M3 contract refused: ${message}`); }
function object(value, name) { if (value === null || typeof value !== 'object' || Array.isArray(value)) fail(`${name} must be an object`); return value; }
function text(value, name) { if (typeof value !== 'string' || value.trim() === '') fail(`${name} is required`); return value; }
function relative(value, name) { const item = text(value, name).replaceAll('\\', '/'); if (path.win32.isAbsolute(value) || item.startsWith('/') || item.split('/').includes('..')) fail(`${name} must be a relative non-traversal path`); return item.replace(/^\.\//, ''); }
function absolute(value, name) { const item = text(value, name); if (!path.win32.isAbsolute(item)) fail(`${name} must be an absolute Windows path`); return path.resolve(item); }
function readJson(file) { try { return JSON.parse(fs.readFileSync(file, 'utf8')); } catch { fail(`cannot read JSON ${path.basename(file)}`); } }
function git(worktree, args) { return execFileSync('git', args, { cwd: worktree, encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] }).trim(); }
function samePath(left, right) { return path.resolve(left).replaceAll('/', '\\').toLowerCase() === path.resolve(right).replaceAll('/', '\\').toLowerCase(); }
function inside(root, candidate) { const item = path.relative(root, candidate); return item !== '' && !item.startsWith('..') && !path.isAbsolute(item); }
function displayPath(value) { return value.replaceAll('\\', '/'); }

function loadContract(file = CONTRACT_PATH) {
  const value = object(readJson(file), 'contract');
  const allowed = new Set(['schema_version', 'canonical_base_sha', 'transport', 'listener', 'launcher', 'gateway_policy', 'upstream_source_root', 'runtime_root', 'tunnel_profile', 'credential_environment', 'activation']);
  if (Object.keys(value).some((key) => !allowed.has(key))) fail('unknown contract field');
  if (value.schema_version !== 1) fail('unsupported schema_version');
  const canonicalBaseSha = text(value.canonical_base_sha, 'canonical_base_sha').toLowerCase(); if (!SHA.test(canonicalBaseSha)) fail('canonical_base_sha must be a SHA');
  if (value.transport !== 'OUTBOUND_STDIO_TUNNEL') fail('only outbound stdio transport is allowed');
  if (value.listener !== 'NONE') fail('listeners are forbidden');
  const launcher = relative(value.launcher, 'launcher');
  const gatewayPolicy = relative(value.gateway_policy, 'gateway_policy');
  const upstreamSourceRoot = absolute(value.upstream_source_root, 'upstream_source_root');
  if (!samePath(upstreamSourceRoot, TRUSTED_SOURCE_ROOT)) fail('upstream_source_root must be the approved source root');
  const runtimeRoot = absolute(value.runtime_root, 'runtime_root');
  if (!samePath(path.dirname(runtimeRoot), 'D:\\EA_LAB_CONTROL')) fail('runtime_root must be a direct child of D:\\EA_LAB_CONTROL');
  const tunnelProfile = text(value.tunnel_profile, 'tunnel_profile'); if (!/^[a-z0-9-]{3,64}$/.test(tunnelProfile)) fail('tunnel_profile is invalid');
  const credentialEnvironment = text(value.credential_environment, 'credential_environment'); if (!SECRET_NAME.test(credentialEnvironment)) fail('credential_environment is invalid');
  if (value.activation !== 'OWNER_REQUIRED') fail('activation must remain owner-required');
  return Object.freeze({ canonicalBaseSha, launcher, gatewayPolicy, upstreamSourceRoot, runtimeRoot, tunnelProfile, credentialEnvironment });
}
function buildRestrictedLaunch({ contract = loadContract(), worktree = ROOT } = {}) {
  const root = path.resolve(worktree);
  const launcherPath = path.resolve(root, contract.launcher);
  const policyPath = path.resolve(root, contract.gatewayPolicy);
  if (!inside(root, launcherPath) || !inside(root, policyPath) || !fs.existsSync(launcherPath) || !fs.existsSync(policyPath)) fail('launcher and policy must exist inside this checkout');
  return Object.freeze({ command: launcherPath, cwd: root, launcher_path: launcherPath, policy_path: policyPath, upstream_source_root: contract.upstreamSourceRoot, runtime_root: contract.runtimeRoot });
}
function renderTunnelInit({ contract = loadContract(), worktree = ROOT, tunnelId = '<OWNER_TUNNEL_ID>' } = {}) { return `& $tc init --sample sample_mcp_stdio_local --profile ${contract.tunnelProfile} --tunnel-id '${tunnelId}' --mcp-command '${displayPath(buildRestrictedLaunch({ contract, worktree }).command)}'`; }
function validateLocalReadiness({ contract = loadContract(), worktree = ROOT, env = process.env } = {}) {
  const root = path.resolve(worktree);
  if (!samePath(git(root, ['rev-parse', '--show-toplevel']), root)) fail('worktree must be its Git checkout root');
  if (git(root, ['status', '--porcelain', '--untracked-files=no']) !== '') fail('worktree has tracked mutations');
  try { git(root, ['merge-base', '--is-ancestor', contract.canonicalBaseSha, 'HEAD']); } catch { fail('worktree is outside canonical-base lineage'); }
  if (env.LNWJUD_UNRESTRICTED !== undefined || (env.LNWJUD_SOURCE_ROOT !== undefined && !samePath(env.LNWJUD_SOURCE_ROOT, contract.upstreamSourceRoot))) fail('unsafe upstream environment is forbidden');
  const launch = buildRestrictedLaunch({ contract, worktree: root });
  const policy = object(readJson(launch.policy_path), 'gateway policy');
  if (String(policy.canonical_base_sha || '').toLowerCase() !== contract.canonicalBaseSha || policy.worktree !== 'POLICY_CHECKOUT') fail('gateway policy is not coupled to this M3 contract');
  if (!Array.isArray(policy.protected_worktree_roots) || !policy.protected_worktree_roots.some((item) => samePath(item, 'D:\\EA_LAB'))) fail('dirty primary protection is missing');
  const status = object(readJson(path.join(root, 'tools', 'lnwjud', 'status-contract.json')), 'status contract');
  if (!samePath(status?.lnwjud?.source_path || '', contract.upstreamSourceRoot) || !samePath(status?.gateway?.runtime_root || '', contract.runtimeRoot)) fail('status contract is not coupled to M3 launch paths');
  return Object.freeze({ state: 'LOCAL_READY_OWNER_PREFLIGHT_REQUIRED', external_state: 'BLOCKED(E)', transport: 'OUTBOUND_STDIO_TUNNEL', listener: 'NONE', credential_environment: contract.credentialEnvironment, credential_present: typeof env[contract.credentialEnvironment] === 'string' && env[contract.credentialEnvironment].trim().length > 0, canonical_base_sha: contract.canonicalBaseSha, launch, owner_preflight: renderTunnelInit({ contract, worktree: root }), owner_action: `Owner must use OpenAI tunnel-client with the owner-controlled tunnel ID and ${contract.credentialEnvironment} to initialize profile ${contract.tunnelProfile} from this restricted launcher, run doctor, and then run that profile; it uses outbound stdio only and creates no EA_LAB public listener.` });
}
if (require.main === module) { const result = validateLocalReadiness(); process.stdout.write(`${JSON.stringify(result, null, 2)}\n`); process.exitCode = 2; }
module.exports = { loadContract, buildRestrictedLaunch, renderTunnelInit, validateLocalReadiness };
