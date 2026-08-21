#!/usr/bin/env node
'use strict';

/*
 * lnwjudctl -- narrow one-shot CLI adapter over the existing EA_LAB LNWJUD
 * gateway (ea-lab-gateway.cjs). It is the A-PATH transport for
 * ChatGPT Plus -> Desktop Commander control of this repository: it spawns
 * the existing restricted gateway with a dedicated read-mostly policy,
 * speaks MCP over stdio, invokes one explicitly allowed tool, prints
 * normalized JSON, and exits. It implements no independent authority --
 * every allow/deny decision still comes from ea-lab-gateway.cjs and this
 * policy file.
 */

const path = require('node:path');
const fs = require('node:fs');
const fsp = require('node:fs/promises');

const ROOT = path.resolve(__dirname, '..', '..');
const SOURCE_ROOT = 'D:\\EA_LAB_TOOLS\\lnwjud-v4-src';
const GATEWAY_PATH = path.join(__dirname, 'ea-lab-gateway.cjs');
const POLICY_PATH = path.join(__dirname, 'lnwjudctl-policy.json');
const RUNTIME_BASE = 'D:\\EA_LAB_CONTROL\\lnwjudctl';

const NO_ARG_COMMANDS = new Set(['status', 'workspace-info', 'git-status', 'git-log']);
const ONE_ARG_COMMANDS = new Set(['read', 'search', 'execute']);
const KNOWN_COMMANDS = new Set([...NO_ARG_COMMANDS, ...ONE_ARG_COMMANDS]);

const ENV_KEYS_TO_STRIP = [
  'LNWJUD_UNRESTRICTED',
  'LNWJUD_SOURCE_ROOT',
  'EA_LAB_APPROVED_WORKTREE',
  'LNWJUD_DATA_PATH',
  'CONTROL_PLANE_API_KEY',
  'OPENAI_API_KEY',
];

function emit(payload, isError) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
  process.exitCode = isError ? 1 : 0;
}

function ok(command, data) {
  emit({ ok: true, command, data }, false);
}

function refuse(code, message) {
  emit({ ok: false, error: { code, message } }, true);
}

function refuseToolDenied(command, result) {
  const structured = result && result.structuredContent && result.structuredContent.error;
  emit({
    ok: false,
    command,
    error: structured || { code: 'DENIED', message: 'gateway denied the request' },
  }, true);
}

// Repo-relative, non-absolute, non-traversal, non-UNC path check used for
// both `read` and any path-shaped argument before the gateway ever sees it.
function normalizeRepoRelativePath(candidate) {
  if (typeof candidate !== 'string' || candidate.trim() === '') return null;
  if (candidate.includes('\0')) return null;
  if (/^[a-zA-Z]:[\\/]/.test(candidate)) return null; // C:\... D:\...
  if (candidate.startsWith('\\\\') || candidate.startsWith('//')) return null; // UNC / protocol-relative
  if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(candidate)) return null; // file://, etc URL schemes
  const normalized = candidate.replaceAll('\\', '/');
  if (normalized.startsWith('/')) return null;
  if (normalized.split('/').some((segment) => segment === '..')) return null;
  const cleaned = normalized.replace(/^\.\//, '');
  if (cleaned.trim() === '') return null;
  return cleaned;
}

function textOf(result) {
  if (!result || !Array.isArray(result.content)) return undefined;
  return result.content.map((item) => (item && typeof item.text === 'string' ? item.text : '')).join('');
}

function dataOf(result) {
  return result.structuredContent !== undefined ? result.structuredContent : textOf(result);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function connect() {
  const sourceRequire = require('node:module').createRequire(path.join(SOURCE_ROOT, 'packages', 'mcp-server', 'package.json'));
  const { Client } = sourceRequire('@modelcontextprotocol/client');
  const { StdioClientTransport } = sourceRequire('@modelcontextprotocol/client/stdio');

  const runtimeDir = path.join(RUNTIME_BASE, `run-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}`);
  await fsp.mkdir(runtimeDir, { recursive: true });

  const childEnv = { ...process.env };
  for (const key of ENV_KEYS_TO_STRIP) delete childEnv[key];
  childEnv.LNWJUD_DATA_PATH = runtimeDir;

  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [GATEWAY_PATH, '--policy', POLICY_PATH],
    env: childEnv,
    stderr: 'pipe',
    cwd: ROOT,
  });
  let diagnostics = '';
  transport.stderr?.on('data', (chunk) => { diagnostics += chunk.toString('utf8'); });

  const client = new Client(
    { name: 'lnwjudctl', version: '1.0.0' },
    { versionNegotiation: { mode: { pin: '2026-07-28' } } },
  );
  try {
    await client.connect(transport);
  } catch (error) {
    await client.close().catch(() => undefined);
    await fsp.rm(runtimeDir, { recursive: true, force: true }).catch(() => undefined);
    const message = error instanceof Error ? error.message : String(error);
    const trimmedDiagnostics = diagnostics.slice(0, 2000);
    throw Object.assign(new Error(`gateway connection refused: ${message}`), { diagnostics: trimmedDiagnostics });
  }
  return {
    client,
    async close() {
      await client.close().catch(() => undefined);
      await fsp.rm(runtimeDir, { recursive: true, force: true }).catch(() => undefined);
    },
  };
}

async function call(client, name, args) {
  return client.callTool({ name, arguments: args });
}

async function getWorkspaceId(client) {
  const status = await call(client, 'ea_lab_status', {});
  if (status.isError) return { status, workspaceId: null };
  return { status, workspaceId: status.structuredContent && status.structuredContent.workspace_id };
}

async function runExecute(client, workspaceId, profile) {
  const started = await call(client, 'ea_lab_execute', { workspaceId, profile });
  if (started.isError) return started;
  const processId = started.structuredContent && started.structuredContent.processId;
  if (typeof processId !== 'string') {
    return { isError: true, structuredContent: { error: { code: 'UNEXPECTED', message: 'execute did not return a process id' } } };
  }
  let statusResult;
  for (let attempt = 0; attempt < 400; attempt += 1) {
    statusResult = await call(client, 'process_status', { workspaceId, processId });
    const state = statusResult.structuredContent && statusResult.structuredContent.state;
    if (['exited', 'failed', 'stopped', 'timed_out'].includes(state)) break;
    await sleep(50);
  }
  const logs = await call(client, 'process_logs', { workspaceId, processId, tailLines: 200 });
  const entries = logs.structuredContent && logs.structuredContent.entries;
  return {
    isError: false,
    structuredContent: {
      profile,
      processId,
      status: statusResult && statusResult.structuredContent,
      logs: Array.isArray(entries) ? entries.map((entry) => entry.text).join('') : textOf(logs),
    },
  };
}

async function main() {
  if (process.env.LNWJUD_UNRESTRICTED !== undefined) {
    refuse('UNSAFE_ENVIRONMENT', 'LNWJUD_UNRESTRICTED override is forbidden');
    return;
  }
  const [command, ...rest] = process.argv.slice(2);
  if (!command || !KNOWN_COMMANDS.has(command)) {
    refuse('UNKNOWN_COMMAND', `unknown command: ${command || '<none>'}`);
    return;
  }
  if (NO_ARG_COMMANDS.has(command) && rest.length !== 0) {
    refuse('MALFORMED_INPUT', `${command} takes no arguments`);
    return;
  }
  if (ONE_ARG_COMMANDS.has(command) && rest.length !== 1) {
    refuse('MALFORMED_INPUT', `${command} takes exactly one argument`);
    return;
  }

  let relPath = null;
  let query = null;
  let profile = null;
  if (command === 'read') {
    relPath = normalizeRepoRelativePath(rest[0]);
    if (relPath === null) {
      refuse('PATH_DENIED', 'path must be repository-relative with no traversal, drive letter, or UNC prefix');
      return;
    }
  } else if (command === 'search') {
    query = rest[0];
    if (typeof query !== 'string' || query.trim() === '') {
      refuse('MALFORMED_INPUT', 'search requires a non-empty query');
      return;
    }
  } else if (command === 'execute') {
    profile = rest[0];
    if (typeof profile !== 'string' || !/^[a-z][a-z0-9_-]{0,63}$/.test(profile)) {
      refuse('MALFORMED_INPUT', 'profile must be a plain lowercase identifier');
      return;
    }
  }

  if (!fs.existsSync(GATEWAY_PATH) || !fs.existsSync(POLICY_PATH)) {
    refuse('SETUP_ERROR', 'gateway or policy file is missing next to lnwjudctl.cjs');
    return;
  }

  let session;
  try {
    session = await connect();
  } catch (error) {
    refuse('GATEWAY_CONNECTION_FAILED', error instanceof Error ? error.message : String(error));
    return;
  }
  const { client } = session;
  try {
    const { status, workspaceId } = await getWorkspaceId(client);
    if (command === 'status') {
      if (status.isError) { refuseToolDenied(command, status); return; }
      ok(command, status.structuredContent);
      return;
    }
    if (status.isError) { refuseToolDenied(command, status); return; }
    if (typeof workspaceId !== 'string') {
      refuse('UNEXPECTED', 'gateway did not return a workspace id');
      return;
    }

    let result;
    if (command === 'workspace-info') result = await call(client, 'workspace_info', { workspaceId });
    else if (command === 'git-status') result = await call(client, 'git_status', { workspaceId });
    else if (command === 'git-log') result = await call(client, 'git_log', { workspaceId, maxCommits: 20 });
    else if (command === 'read') result = await call(client, 'read_file', { workspaceId, path: relPath });
    else if (command === 'search') result = await call(client, 'search_text', { workspaceId, query, maxResults: 20 });
    else if (command === 'execute') result = await runExecute(client, workspaceId, profile);

    if (result.isError) { refuseToolDenied(command, result); return; }
    ok(command, dataOf(result));
  } finally {
    await session.close();
  }
}

main().catch((error) => {
  refuse('INTERNAL_ERROR', error instanceof Error ? error.message : String(error));
});
