#!/usr/bin/env node
'use strict';

/*
 * EA_LAB's narrow-authority MCP façade for stock lnwjud v4.
 *
 * Stock stdio/tunnel intentionally uses the full profile and assumes E:\ is
 * trusted.  This process keeps the upstream service implementation but exposes
 * only a single registered clean worktree and a small, task-bound tool surface.
 * It is deliberately a local adapter, not an upstream fork.
 */

const crypto = require('node:crypto');
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const { createRequire } = require('node:module');

const TRUSTED_SOURCE_ROOT = 'D:\\EA_LAB_TOOLS\\lnwjud-v4-src';
if (process.env.LNWJUD_SOURCE_ROOT !== undefined
  && path.resolve(process.env.LNWJUD_SOURCE_ROOT).toLowerCase() !== path.resolve(TRUSTED_SOURCE_ROOT).toLowerCase()) {
  throw new Error('LNWJUD_SOURCE_ROOT override is forbidden');
}
const sourceRoot = TRUSTED_SOURCE_ROOT;

const SELECTED_WORKTREE = process.env.EA_LAB_APPROVED_WORKTREE;
const sourceRequire = createRequire(path.join(sourceRoot, 'packages', 'mcp-server', 'package.json'));
const { McpServer } = sourceRequire('@modelcontextprotocol/server');
const { serveStdio } = sourceRequire('@modelcontextprotocol/server/stdio');

const toolRegistryUrl = pathToFileUrl(path.join(sourceRoot, 'packages', 'mcp-server', 'dist', 'tool-registry.js'));
const runtimeUrl = pathToFileUrl(path.join(sourceRoot, 'apps', 'cli', 'dist', 'runtime', 'stdio-mcp-runtime.js'));
const storageUrl = pathToFileUrl(path.join(sourceRoot, 'packages', 'storage', 'dist', 'index.js'));
const workspaceUrl = pathToFileUrl(path.join(sourceRoot, 'packages', 'workspace', 'dist', 'index.js'));
const permissionsUrl = pathToFileUrl(path.join(sourceRoot, 'packages', 'permissions', 'dist', 'index.js'));

const READ_TOOLS = new Set([
  'workspace_info', 'workspace_tree', 'project_snapshot',
  'read_file', 'read_files', 'search_files', 'search_text',
  'git_status', 'git_diff', 'git_log',
  'workspace_context', 'workspace_context_continue', 'workspace_full_scan',
  'workspace_full_scan_continue', 'read_many_files',
  'workspace_index', 'workspace_index_status', 'symbol_search',
  'find_references', 'import_graph', 'module_graph', 'type_search',
  'process_status', 'process_logs', 'health',
  'context_economy_stats', 'telemetry_dashboard',
  'route_intent', 'tool_search', 'tool_dynamic_filter'
]);
const MUTATING_TOOLS = new Set(['write_file', 'apply_patch']);
const PROCESS_TOOLS = new Set(['process_start', 'process_stop']);
const METADATA_TOOLS = new Set(['health', 'context_economy_stats', 'telemetry_dashboard', 'route_intent', 'tool_search', 'tool_dynamic_filter']);

function pathToFileUrl(value) {
  return new URL(`file:///${value.replaceAll('\\', '/')}`).href;
}

function failure(code, message) {
  return {
    isError: true,
    content: [{ type: 'text', text: `${code}: ${message}` }],
    structuredContent: { error: { code, message } }
  };
}

function parseArgs(argv) {
  const index = argv.indexOf('--policy');
  if (index < 0 || typeof argv[index + 1] !== 'string') throw new Error('usage: ea-lab-gateway.cjs --policy <path>');
  return { policyPath: path.resolve(argv[index + 1]) };
}

function mustString(record, key) {
  if (typeof record[key] !== 'string' || record[key].trim() === '') throw new Error(`policy ${key} is required`);
  return record[key];
}

function loadPolicy(policyPath) {
  const value = JSON.parse(fs.readFileSync(policyPath, 'utf8'));
  if (value === null || typeof value !== 'object' || Array.isArray(value)) throw new Error('policy must be an object');
  if (value.schema_version !== 1) throw new Error('unsupported policy schema_version');
  const policy = {
    taskId: mustString(value, 'task_id'),
    canonicalBaseSha: mustString(value, 'canonical_base_sha').toLowerCase(),
    baseSha: mustString(value, 'base_sha').toLowerCase(),
    worktree: mustString(value, 'worktree'),
    role: mustString(value, 'role'),
    reviewState: mustString(value, 'review_state'),
    allowedPaths: Array.isArray(value.allowed_paths) ? value.allowed_paths.map(String) : [],
    forbiddenPaths: Array.isArray(value.forbidden_paths) ? value.forbidden_paths.map(String) : [],
    allowedProcess: value.allowed_process,
    executionProfiles: value.execution_profiles
  };
  policy.protectedWorktreeRoots = Array.isArray(value.protected_worktree_roots) ? value.protected_worktree_roots.map(String) : [];
  if (policy.worktree !== 'POLICY_CHECKOUT') throw new Error('policy worktree must be POLICY_CHECKOUT');
  if (!/^[0-9a-f]{40}$/.test(policy.canonicalBaseSha)) throw new Error('policy canonical_base_sha must be a 40-character SHA');
  if (policy.baseSha !== 'worktree_head_at_start' && !/^[0-9a-f]{40}$/.test(policy.baseSha)) throw new Error('policy base_sha must be a 40-character SHA or WORKTREE_HEAD_AT_START');
  if (!['EA-OBSERVE', 'EA-WORKER', 'EA-INTEGRATION'].includes(policy.role)) throw new Error('policy role is not allowed');
  if (!['OPEN', 'FROZEN'].includes(policy.reviewState)) throw new Error('policy review_state is not allowed');
  if (policy.allowedPaths.length === 0) throw new Error('policy allowed_paths is required');
  if (policy.executionProfiles === null || typeof policy.executionProfiles !== 'object' || Array.isArray(policy.executionProfiles)) throw new Error('policy execution_profiles is required');
  for (const [name, profile] of Object.entries(policy.executionProfiles)) {
    if (!['build', 'test', 'check', 'state_check'].includes(name) || profile === null || typeof profile !== 'object' || Array.isArray(profile)
      || typeof profile.executable !== 'string' || !Array.isArray(profile.args) || !profile.args.every((arg) => typeof arg === 'string')
      || typeof profile.mutation_capable !== 'boolean' || profile.args.includes('-Command')) {
      throw new Error(`invalid execution profile: ${name}`);
    }
  }
  return policy;
}

function normalizedRelative(candidate) {
  if (typeof candidate !== 'string' || candidate.trim() === '') return null;
  const normalized = candidate.replaceAll('\\', '/');
  if (path.win32.isAbsolute(candidate) || normalized.startsWith('/') || normalized.split('/').includes('..')) return null;
  return normalized.replace(/^\.\//, '');
}

function matchesPrefix(candidate, prefix) {
  const normalizedPrefix = prefix.replaceAll('\\', '/').replace(/^\.\//, '');
  return candidate === normalizedPrefix.replace(/\/$/, '') || candidate.startsWith(normalizedPrefix);
}

function isSecretPath(candidate) {
  const lower = candidate.toLowerCase();
  return lower === '.env' || lower.endsWith('/.env') || lower.includes('/.env.') || /(^|\/)(id_rsa|id_ed25519|credentials|secrets?)(\.|\/|$)/.test(lower);
}

function assertWorkspace(input, workspaceId) {
  return input !== null && typeof input === 'object' && input.workspaceId === workspaceId;
}

function pathsFromInput(toolName, input) {
  if (input === null || typeof input !== 'object') return [];
  if (toolName === 'read_files' || toolName === 'read_many_files' || toolName === 'apply_patch') {
    return Array.isArray(input.files) ? input.files.map((file) => file && file.path) : [];
  }
  if (['read_file', 'write_file', 'git_diff', 'workspace_context'].includes(toolName) && input.path !== undefined) return [input.path];
  return [];
}

function enforcePathList(paths, policy, mutation) {
  for (const rawPath of paths) {
    const relative = normalizedRelative(rawPath);
    if (relative === null) return 'absolute/traversal path denied';
    if (isSecretPath(relative)) return 'secret path denied';
    if (policy.forbiddenPaths.some((prefix) => matchesPrefix(relative, prefix))) return 'forbidden path denied';
    if (mutation && !policy.allowedPaths.some((prefix) => matchesPrefix(relative, prefix))) return 'path is outside this task contract';
  }
  return null;
}

function gitHead(worktree) {
  const { execFileSync } = require('node:child_process');
  return execFileSync('git', ['rev-parse', 'HEAD'], { cwd: worktree, encoding: 'utf8', windowsHide: true }).trim().toLowerCase();
}

function policyCheckout() { return path.resolve(__dirname, '..', '..'); }

function samePath(left, right) {
  return path.resolve(left).replaceAll('/', '\\').toLowerCase() === path.resolve(right).replaceAll('/', '\\').toLowerCase();
}

function gitText(worktree, args) {
  const { execFileSync } = require('node:child_process');
  return execFileSync('git', args, { cwd: worktree, encoding: 'utf8', windowsHide: true }).trim();
}

async function bindTrustedWorktree(policy) {
  const trusted = await fsp.realpath(policyCheckout());
  const selected = await fsp.realpath(SELECTED_WORKTREE || trusted);
  const protectedRoots = await Promise.all(policy.protectedWorktreeRoots.map(async (item) => fsp.realpath(item).catch(() => path.resolve(item))));
  if (protectedRoots.some((item) => samePath(item, selected))) throw new Error('selected worktree is a protected preservation root');
  if (!samePath(selected, trusted)) throw new Error('selected worktree is not authorized by the policy checkout');
  if (!samePath(gitText(selected, ['rev-parse', '--show-toplevel']), selected)) throw new Error('selected worktree is not its Git checkout root');
  if (gitText(selected, ['status', '--porcelain', '--untracked-files=no']) !== '') throw new Error('selected worktree has tracked mutations');
  try { gitText(selected, ['merge-base', '--is-ancestor', policy.canonicalBaseSha, 'HEAD']); }
  catch { throw new Error('selected worktree is not on the policy canonical-base lineage'); }
  policy.realWorktree = selected;
}

function bindExpectedHead(policy) {
  if (policy.baseSha === 'worktree_head_at_start') policy.baseSha = gitHead(policy.realWorktree);
}

function assertExpectedHead(policy) {
  try {
    if (gitHead(policy.realWorktree) !== policy.baseSha) return 'expected HEAD mismatch';
  } catch {
    return 'unable to verify expected HEAD';
  }
  return null;
}

function assertMutationAuthority(policy) {
  const headError = assertExpectedHead(policy);
  if (headError !== null) return headError;
  if (policy.role === 'EA-OBSERVE') return 'observe role cannot mutate';
  if (policy.reviewState !== 'OPEN') return 'review freeze is active';
  return null;
}

async function acquireWriterLock(runtimePath, policy) {
  const lockPath = path.join(runtimePath, 'active-writer.json');
  const body = JSON.stringify({ task_id: policy.taskId, pid: process.pid, base_sha: policy.baseSha, created_at: new Date().toISOString() });
  try {
    await fsp.writeFile(lockPath, body, { encoding: 'utf8', flag: 'wx' });
  } catch (error) {
    if (error && error.code === 'EEXIST') {
      const existing = await fsp.readFile(lockPath, 'utf8').catch(() => 'unreadable');
      throw new Error(`one-writer guard: another EA_LAB gateway owns this runtime (${existing})`);
    }
    throw error;
  }
  const release = async () => { await fsp.rm(lockPath, { force: true }).catch(() => undefined); };
  process.once('exit', () => { try { fs.unlinkSync(lockPath); } catch {} });
  process.once('SIGINT', () => { void release().finally(() => process.exit(0)); });
  process.once('SIGTERM', () => { void release().finally(() => process.exit(0)); });
  return release;
}

async function main() {
  const { policyPath } = parseArgs(process.argv);
  const policy = loadPolicy(policyPath);
  await bindTrustedWorktree(policy);
  bindExpectedHead(policy);
  const runtimePath = path.resolve(process.env.LNWJUD_DATA_PATH || 'D:\\EA_LAB_CONTROL\\lnwjud-v4');
  if (!path.resolve(runtimePath).toLowerCase().startsWith('d:\\ea_lab_control\\')) throw new Error('runtime path must stay under D:\\EA_LAB_CONTROL');
  await fsp.mkdir(runtimePath, { recursive: true });
  process.stderr.write(`ea-lab-lnwjud-gateway starting runtime=${runtimePath}\n`);
  let releaseLock;
  const ensureWriterLock = async () => {
    if (releaseLock === undefined) releaseLock = await acquireWriterLock(runtimePath, policy);
  };

  const [{ ToolRegistry }, { createStdioMcpRuntime }, storage, workspace, permissions] = await Promise.all([
    import(toolRegistryUrl), import(runtimeUrl), import(storageUrl), import(workspaceUrl), import(permissionsUrl)
  ]);
  const database = new storage.SqliteDatabase(path.join(runtimePath, 'lnwjud.sqlite'));
  const workspaceRepository = new storage.SqliteWorkspaceRepository(database);
  const workspaceService = new workspace.WorkspaceService(workspaceRepository);
  const existing = await workspaceService.list();
  let registered = existing.find((entry) => path.resolve(entry.realRootPath).toLowerCase() === policy.realWorktree.toLowerCase());
  if (registered === undefined) {
    const added = await workspaceService.add('EA_LAB clean execution worktree', policy.realWorktree);
    if (!added.ok) throw new Error(`workspace registration failed: ${added.error.message}`);
    registered = added.value;
  }
  database.close();

  // The gateway constrains the exposed tools and validates their arguments;
  // unrestricted here only permits its one explicitly allowed shell-host call.
  const runtime = createStdioMcpRuntime(runtimePath, registered, true);
  const registry = new ToolRegistry(runtime.services, runtime.actor, {
    activityTracker: runtime.activityTracker,
    profileProvider: () => permissions.permissionProfiles.full
  });
  const server = new McpServer({ name: 'ea-lab-lnwjud-gateway', version: '1.0.0' }, { capabilities: { tools: {} } });
  const z = sourceRequire('zod');
  const ownedProcessIds = new Set();
  server.registerTool('ea_lab_status', {
    description: 'Return the exact bounded EA_LAB gateway contract and registered clean worktree.',
    inputSchema: z.object({}).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async () => {
    process.stderr.write('ea-lab-lnwjud-gateway status requested\n');
    return {
      isError: false,
      content: [{ type: 'text', text: `task=${policy.taskId} workspace=${registered.id} head=${policy.baseSha}` }],
      structuredContent: {
        task_id: policy.taskId,
        workspace_id: registered.id,
        worktree: policy.realWorktree,
        base_sha: policy.baseSha,
        role: policy.role,
        review_state: policy.reviewState
      }
    };
  });
  server.registerTool('ea_lab_execute', {
    description: 'Run one named, policy-bound BUILD, TEST, CHECK, or state-check profile in the exact clean worktree.',
    inputSchema: z.object({ workspaceId: z.string(), profile: z.string() }).strict(),
    annotations: { readOnlyHint: false, destructiveHint: false },
  }, async (input) => {
    if (!assertWorkspace(input, registered.id)) return failure('WORKSPACE_DENIED', 'exact clean worktree workspaceId is required');
    const profile = policy.executionProfiles[input.profile];
    if (profile === undefined) return failure('POLICY_DENIED', 'execution profile is not authorized');
    const authorityError = profile.mutation_capable ? assertMutationAuthority(policy) : assertExpectedHead(policy);
    if (authorityError !== null) return failure('POLICY_DENIED', authorityError);
    if (profile.mutation_capable) {
      try {
        await ensureWriterLock();
      } catch (error) {
        return failure('POLICY_DENIED', error instanceof Error ? error.message : 'one-writer guard denied execution');
      }
    }
    const result = await registry.invoke('process_start', {
      workspaceId: registered.id,
      executable: profile.executable,
      args: profile.args,
    });
    if (result.isError !== true) {
      const processId = result.structuredContent && result.structuredContent.processId;
      if (typeof processId === 'string') ownedProcessIds.add(processId);
    }
    return result;
  });
  const definitions = registry.list().filter((tool) => READ_TOOLS.has(tool.name) || MUTATING_TOOLS.has(tool.name) || PROCESS_TOOLS.has(tool.name));
  for (const tool of definitions) {
    server.registerTool(tool.name, { description: tool.description, inputSchema: tool.inputSchema, annotations: tool.annotations }, async (input) => {
      if (!METADATA_TOOLS.has(tool.name) && !assertWorkspace(input, registered.id)) return failure('WORKSPACE_DENIED', 'exact clean worktree workspaceId is required');
      const mutation = MUTATING_TOOLS.has(tool.name);
      const pathError = enforcePathList(pathsFromInput(tool.name, input), policy, mutation);
      if (pathError !== null) return failure('POLICY_DENIED', pathError);
      if ((tool.name === 'search_files' || tool.name === 'search_text') && (input.includeIgnored === true || input.glob !== undefined)) {
        return failure('POLICY_DENIED', 'search overrides are denied; the gateway enforces secret-file exclusion');
      }
      if (tool.name === 'workspace_context' && (input.includeIgnored === true || input.mode === 'exhaustive' || (typeof input.responseTargetBytes === 'number' && input.responseTargetBytes > 65_536) || (typeof input.pageSize === 'number' && input.pageSize > 50))) {
        return failure('POLICY_DENIED', 'context request exceeds the bounded optimized profile');
      }
      if (mutation) {
        const authorityError = assertMutationAuthority(policy);
        if (authorityError !== null) return failure('POLICY_DENIED', authorityError);
        try {
          await ensureWriterLock();
        } catch (error) {
          return failure('POLICY_DENIED', error instanceof Error ? error.message : 'one-writer guard denied mutation');
        }
      }
      if (tool.name === 'process_start') {
        const expected = policy.allowedProcess;
        if (!expected || input.executable.toLowerCase() !== expected.executable.toLowerCase() || JSON.stringify(input.args) !== JSON.stringify(expected.args) || input.cwd !== undefined) {
          return failure('POLICY_DENIED', 'process command is not the task-bound acceptance command');
        }
        const executionError = assertMutationAuthority(policy);
        if (executionError !== null) return failure('POLICY_DENIED', executionError);
      }
      if (tool.name === 'process_stop' && !ownedProcessIds.has(String(input.processId))) {
        return failure('POLICY_DENIED', 'unowned process termination denied');
      }
      const safeInput = tool.name === 'search_files' || tool.name === 'search_text'
        ? { ...input, includeIgnored: false, glob: '!**/.env' }
        : input;
      process.stderr.write(`ea-lab-lnwjud-gateway invoke ${tool.name}\n`);
      const result = await registry.invoke(tool.name, safeInput);
      process.stderr.write(`ea-lab-lnwjud-gateway complete ${tool.name}\n`);
      if (tool.name === 'process_start' && result.isError !== true) {
        const processId = result.structuredContent && result.structuredContent.processId;
        if (typeof processId === 'string') ownedProcessIds.add(processId);
      }
      return result;
    });
  }
  process.stderr.write(`ea-lab-lnwjud-gateway ready task=${policy.taskId} workspace=${registered.id} root=${policy.realWorktree}\n`);
  const handle = serveStdio(() => server, { legacy: 'reject', onerror: (error) => process.stderr.write(`ea-lab-lnwjud-gateway error: ${error.message}\n`) });
  const close = async () => {
    await handle.close().catch(() => undefined);
    await runtime.close().catch(() => undefined);
    if (releaseLock !== undefined) await releaseLock();
  };
  const shutdown = () => { void close().finally(() => process.exit(0)); };
  process.stdin.once('end', shutdown);
  process.stdin.once('close', shutdown);
}

main().catch((error) => {
  process.stderr.write(`ea-lab-lnwjud-gateway failed: ${error instanceof Error ? error.message : 'unknown'}\n`);
  process.exitCode = 1;
});
