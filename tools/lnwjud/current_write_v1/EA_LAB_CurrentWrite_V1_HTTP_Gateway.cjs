'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const childProcess = require('node:child_process');

const {
  McpServer,
  createMcpHandler,
  hostHeaderValidationResponse,
  originValidationResponse,
  localhostAllowedHostnames,
  localhostAllowedOrigins
} = require('D:/EA_LAB_TOOLS/lnwjud-v4-src/node_modules/.pnpm/@modelcontextprotocol+server@2.0.0/node_modules/@modelcontextprotocol/server/dist/index.cjs');
const z = require('D:/EA_LAB_TOOLS/lnwjud-v4-src/node_modules/.pnpm/zod@4.2.0/node_modules/zod/index.cjs');

const ROOT = 'D:\\EA_LAB_CONTROL\\lnwjud-write-v1-20260928';
const SNAPSHOT_ROOT = path.join(ROOT, 'snapshot');
const EXPECTED_CANONICAL_ROOT = 'D:\\EA_LAB_CONTROL\\lnwjud-write-v1-20260928\\canonical';
const EXPECTED_EVIDENCE_ROOT = 'D:\\EA_LAB_CONTROL\\evidence';
const EXPECTED_NODE = 'C:\\Program Files\\nodejs\\node.exe';
const EXPECTED_NODE_SHA256 = '3602f2bb1a10f2cbab4c36886218a33c1ab3db87290e73b033c46c77147d0237';
const MAX_FILE_BYTES = 1024 * 1024;
const MAX_RETURN_LINES = 2000;
const WRITE_ROOT = 'D:\\EA_LAB_CONTROL\\lnwjud-write-v1-20260928\\workspace';
const WRITE_BRANCH = 'lnwjud/write-runtime-20260928';
const MUTATION_LOCK = path.join(ROOT, '.write-mutation.lock');
const EXPECTED_ORIGIN_URL = 'https://github.com/BaBosss/EA_LAB.git';
const EXPECTED_GIT = 'C:\\Program Files\\Git\\cmd\\git.exe';
const EXPECTED_GIT_SHA256 = '78211c7ed73988da93a6d8a33d47ec6187f464d7ea2a9a00c182bbd7a1ecf30f';
const MAX_WRITE_BYTES = 1024 * 1024;
const MAX_DIFF_CHARS = 120000;
const HTTP_HOST = '127.0.0.1';
const HTTP_PORT = 18768;
const HTTP_PATH = '/mcp';

function sha256Buffer(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function sha256File(file) {
  return sha256Buffer(fs.readFileSync(file));
}

function sameWindowsPath(a, b) {
  return path.win32.resolve(a).toLowerCase() === path.win32.resolve(b).toLowerCase();
}

function isForbiddenEnvName(name) {
  const upper = String(name).toUpperCase();
  if (['OPENAI_API_KEY','OPENAI_ADMIN_KEY','NODE_OPTIONS','NODE_PATH'].includes(upper)) return true;
  if (
    upper.startsWith('CONTROL_PLANE_') ||
    upper.startsWith('MCP_') ||
    upper.startsWith('TUNNEL_CLIENT_') ||
    upper.startsWith('CLOUDFLARED_') ||
    upper.startsWith('GIT_')
  ) return true;
  return /(TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL|PRIVATE_KEY|ACCESS_KEY|API_KEY)/.test(upper);
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
}

function verifyComponent(seal, name) {
  const file = path.join(SNAPSHOT_ROOT, name);
  const expected = seal.component_hashes?.[name];
  if (typeof expected !== 'string' || !/^[0-9a-f]{64}$/.test(expected)) {
    throw new Error('snapshot seal component hash missing/malformed: ' + name);
  }
  const actual = sha256File(file);
  if (actual !== expected) throw new Error('snapshot component hash mismatch: ' + name);
  return readJson(file);
}

function normalizeRawRelative(inputPath) {
  if (typeof inputPath !== 'string' || inputPath.length === 0 || inputPath.includes('\0')) {
    throw new Error('invalid path');
  }
  if (path.win32.isAbsolute(inputPath) || inputPath.startsWith('/') || inputPath.startsWith('\\')) {
    throw new Error('absolute path denied');
  }
  const normalized = inputPath.replaceAll('\\', '/').replace(/^\.\//, '');
  const segments = normalized.split('/').filter(Boolean);
  if (segments.length === 0 || segments.some((s) => s === '.' || s === '..')) {
    throw new Error('traversal/empty path denied');
  }
  if (segments.some((s) => s.includes(':'))) {
    throw new Error('alternate data stream/colon path denied');
  }
  return segments.join('/');
}

function forbiddenRepoRelative(relativePath) {
  const lower = relativePath.replaceAll('\\', '/').toLowerCase();
  const segs = lower.split('/').filter(Boolean);
  const base = segs.at(-1) || '';
  if (base.startsWith('.env')) return true;
  if (segs.includes('.git') || segs.includes('.ssh') || segs.includes('credentials') || segs.includes('secrets')) return true;
  if (lower === 'portfolio/accounts.csv') return true;
  if (lower === 'portfolio/live_deals' || lower.startsWith('portfolio/live_deals/')) return true;
  return false;
}

function forbiddenEvidenceRelative(relativePath) {
  const lower = relativePath.replaceAll('\\', '/').toLowerCase();
  const segs = lower.split('/').filter(Boolean);
  if (segs.includes('.git') || segs.includes('.ssh') || segs.includes('credentials') || segs.includes('secrets')) return true;
  const sensitive = /(^|[-_.])(secret|credential|password|passwd|private[-_]?key|api[-_]?key|auth[-_]?token|access[-_]?token)([-_.]|$)/i;
  return segs.some((s) => sensitive.test(s));
}

function buildManifestMap(entries, label) {
  if (!Array.isArray(entries)) throw new Error(label + ' entries must be an array');
  const map = new Map();
  for (const entry of entries) {
    if (
      !entry ||
      typeof entry.path !== 'string' ||
      typeof entry.path_key !== 'string' ||
      typeof entry.sha256 !== 'string' ||
      !Number.isSafeInteger(entry.bytes)
    ) throw new Error(label + ' entry malformed');
    const key = entry.path.replaceAll('\\','/').toLowerCase();
    if (key !== entry.path_key) throw new Error(label + ' path_key mismatch');
    if (map.has(key)) throw new Error(label + ' duplicate path');
    map.set(key, entry);
  }
  return map;
}

function assertLaunchIdentity() {
  for (const name of Object.keys(process.env)) {
    if (isForbiddenEnvName(name)) throw new Error('forbidden execution/secret environment reached gateway: ' + name);
  }
  if (!sameWindowsPath(process.execPath, EXPECTED_NODE)) throw new Error('unexpected Node executable: ' + process.execPath);
  if (sha256File(process.execPath) !== EXPECTED_NODE_SHA256) throw new Error('Node executable hash mismatch');

  const seal = readJson(path.join(SNAPSHOT_ROOT, 'snapshot_seal.json'));
  if (seal.schema_version !== 1 || seal.authority !== 'READ_ONLY_CURRENT_SNAPSHOT_V2') {
    throw new Error('snapshot seal identity mismatch');
  }
  if (!sameWindowsPath(seal.canonical_root, EXPECTED_CANONICAL_ROOT)) throw new Error('canonical root mismatch');
  if (!sameWindowsPath(seal.evidence_root, EXPECTED_EVIDENCE_ROOT)) throw new Error('evidence root mismatch');
  if (typeof seal.snapshot_id !== 'string' || !/^[0-9a-f]{32}$/.test(seal.snapshot_id)) {
    throw new Error('snapshot id malformed');
  }
  if (
    seal.canonical_head !== seal.origin_master_at_capture ||
    seal.canonical_head !== seal.ls_remote_at_capture
  ) throw new Error('snapshot canonical binding was not exact at capture');

  const canonical = verifyComponent(seal, 'canonical_manifest.json');
  const lanes = verifyComponent(seal, 'lanes.json');
  const jobs = verifyComponent(seal, 'jobs.json');
  const evidence = verifyComponent(seal, 'evidence_manifest.json');
  const monitor = verifyComponent(seal, 'monitor.json');

  if (!sameWindowsPath(canonical.root, EXPECTED_CANONICAL_ROOT)) throw new Error('canonical manifest root mismatch');
  if (canonical.head !== seal.canonical_head) throw new Error('canonical manifest head mismatch');
  if (!Array.isArray(lanes) || !Array.isArray(jobs) || !Array.isArray(evidence)) {
    throw new Error('snapshot component shape mismatch');
  }

  const canonicalRootReal = fs.realpathSync.native(EXPECTED_CANONICAL_ROOT);
  const evidenceRootReal = fs.realpathSync.native(EXPECTED_EVIDENCE_ROOT);
  if (sha256File(EXPECTED_GIT) !== EXPECTED_GIT_SHA256) throw new Error('Git executable hash mismatch');
  const writeRootReal = fs.realpathSync.native(WRITE_ROOT);
  return {
    seal,
    canonical,
    lanes,
    jobs,
    evidence,
    monitor,
    canonicalRootReal,
    evidenceRootReal,
    writeRootReal,
    canonicalMap: buildManifestMap(canonical.entries, 'canonical'),
    evidenceMap: buildManifestMap(evidence, 'evidence'),
  };
}

function resultError(code, message) {
  return {
    isError: true,
    content: [{ type: 'text', text: code + ': ' + message }],
    structuredContent: { error: { code, message } }
  };
}

function assertSnapshot(input, seal) {
  return input && typeof input === 'object' && input.snapshotId === seal.snapshot_id;
}

function resolveManifestRead(rootReal, manifestMap, inputPath, forbidFn) {
  const raw = normalizeRawRelative(inputPath);
  if (forbidFn(raw)) throw new Error('forbidden path denied');
  const requested = path.win32.resolve(rootReal, raw);
  let targetReal;
  try {
    targetReal = fs.realpathSync.native(requested);
  } catch {
    throw new Error('file not found');
  }
  const rel = path.win32.relative(rootReal, targetReal);
  if (
    rel === '' ||
    rel === '.' ||
    path.win32.isAbsolute(rel) ||
    rel === '..' ||
    rel.startsWith('..\\') ||
    rel.startsWith('../')
  ) throw new Error('path outside approved root denied');
  const canonicalRel = rel.replaceAll('\\', '/');
  if (forbidFn(canonicalRel)) throw new Error('forbidden path denied');
  const key = canonicalRel.toLowerCase();
  const entry = manifestMap.get(key);
  if (!entry) throw new Error('path not present in bound snapshot manifest');
  const st = fs.statSync(targetReal);
  if (!st.isFile()) throw new Error('file path required');
  if (st.size > MAX_FILE_BYTES || entry.bytes > MAX_FILE_BYTES) throw new Error('file too large for bounded read');
  return { targetReal, relativePath: entry.path, entry };
}

function readBoundFile(resolved, startLine, endLine) {
  const buf = fs.readFileSync(resolved.targetReal);
  if (buf.length !== resolved.entry.bytes) throw new Error('file size drift from snapshot manifest');
  if (sha256Buffer(buf) !== resolved.entry.sha256) throw new Error('file hash drift from snapshot manifest');
  if (buf.includes(0)) throw new Error('binary file denied');
  const text = buf.toString('utf8').replace(/^\uFEFF/, '');
  const lines = text.split(/\r?\n/);
  const start = startLine === undefined ? 1 : startLine;
  const requestedEnd = endLine === undefined ? Math.min(lines.length, start + MAX_RETURN_LINES - 1) : endLine;
  if (
    !Number.isInteger(start) ||
    start < 1 ||
    !Number.isInteger(requestedEnd) ||
    requestedEnd < start
  ) throw new Error('invalid line range');
  if (requestedEnd - start + 1 > MAX_RETURN_LINES) throw new Error('line range exceeds bounded read cap');
  const actualEnd = Math.min(requestedEnd, lines.length);
  return {
    body: lines.slice(start - 1, actualEnd).join('\n'),
    startLine: start,
    endLine: actualEnd,
    totalLines: lines.length,
  };
}

function normalizeStateFilter(states) {
  if (!Array.isArray(states) || states.length === 0) return null;
  const out = new Set();
  for (const s of states) {
    if (typeof s === 'string' && s.length <= 64) out.add(s.toUpperCase());
  }
  return out.size ? out : null;
}


function safeChildEnv() {
  const env = {};
  for (const name of ['APPDATA','COMSPEC','HOMEDRIVE','HOMEPATH','HOME','LOCALAPPDATA','SystemRoot','TEMP','TMP','USERPROFILE','WINDIR']) {
    const value = process.env[name];
    if (value) env[name] = value;
  }
  return env;
}

function runGit(args, options = {}) {
  const cp = childProcess.spawnSync(EXPECTED_GIT, args, {
    cwd: WRITE_ROOT,
    env: safeChildEnv(),
    encoding: 'utf8',
    windowsHide: true,
    shell: false,
    maxBuffer: options.maxBuffer || 1024 * 1024
  });
  if (cp.error) throw cp.error;
  const status = Number.isInteger(cp.status) ? cp.status : -1;
  if (!options.allowFailure && status !== 0) {
    throw new Error('git ' + args[0] + ' failed rc=' + status + ': ' + String(cp.stderr || '').trim().slice(0, 1000));
  }
  return { status, stdout: String(cp.stdout || ''), stderr: String(cp.stderr || '') };
}

function assertWriteWorkspaceIdentity(writeRootReal) {
  const origin = runGit(['remote','get-url','origin']).stdout.trim();
  const branch = runGit(['rev-parse','--abbrev-ref','HEAD']).stdout.trim();
  if (origin !== EXPECTED_ORIGIN_URL) throw new Error('write workspace origin mismatch');
  if (branch !== WRITE_BRANCH) throw new Error('write workspace branch mismatch: ' + branch);
  const actual = fs.realpathSync.native(WRITE_ROOT);
  if (!sameWindowsPath(actual, writeRootReal)) throw new Error('write workspace realpath mismatch');
}

function forbiddenWriteRepoRelative(relativePath) {
  if (forbiddenRepoRelative(relativePath)) return true;
  const lower = relativePath.replaceAll('\\', '/').toLowerCase();
  if (lower === '.githooks' || lower.startsWith('.githooks/')) return true;
  if (lower === 'scripts/lane_registry.ps1') return true;
  return false;
}

function ensureInsideRoot(rootReal, candidate) {
  const rel = path.win32.relative(rootReal, candidate);
  if (rel === '' || rel === '.') return;
  if (path.win32.isAbsolute(rel) || rel === '..' || rel.startsWith('..\\') || rel.startsWith('../')) {
    throw new Error('path outside write workspace denied');
  }
}

function resolveWorkspaceExisting(writeRootReal, inputPath) {
  const raw = normalizeRawRelative(inputPath);
  if (forbiddenWriteRepoRelative(raw)) throw new Error('forbidden write path denied');
  const requested = path.win32.resolve(writeRootReal, raw);
  ensureInsideRoot(writeRootReal, requested);
  let targetReal;
  try { targetReal = fs.realpathSync.native(requested); }
  catch { throw new Error('file not found'); }
  ensureInsideRoot(writeRootReal, targetReal);
  const st = fs.statSync(targetReal);
  if (!st.isFile()) throw new Error('file path required');
  if (st.size > MAX_WRITE_BYTES) throw new Error('file too large for bounded write');
  const rel = path.win32.relative(writeRootReal, targetReal).replaceAll('\\','/');
  if (forbiddenWriteRepoRelative(rel)) throw new Error('forbidden write path denied');
  const tracked = runGit(['ls-files','--error-unmatch','--',rel], {allowFailure:true});
  if (tracked.status !== 0) throw new Error('replace_exact requires a tracked file');
  return { targetReal, relativePath: rel, size: st.size };
}

function resolveWorkspaceCreate(writeRootReal, inputPath) {
  const raw = normalizeRawRelative(inputPath);
  if (forbiddenWriteRepoRelative(raw)) throw new Error('forbidden write path denied');
  const requested = path.win32.resolve(writeRootReal, raw);
  ensureInsideRoot(writeRootReal, requested);
  if (fs.existsSync(requested)) throw new Error('target already exists');
  const parentReal = fs.realpathSync.native(path.dirname(requested));
  ensureInsideRoot(writeRootReal, parentReal);
  const ignored = runGit(['check-ignore','-q','--',raw], {allowFailure:true});
  if (ignored.status === 0) throw new Error('ignored path denied');
  const ext = path.extname(raw).toLowerCase();
  const allowed = new Set(['.md','.txt','.csv','.json','.jsonl','.yaml','.yml','.ps1','.psm1','.psd1','.py','.js','.cjs','.css','.html','.xml','.ini','.toml','.mq4','.mq5','.mqh','.set','.patch','.diff']);
  if (!allowed.has(ext)) throw new Error('new-file extension not allowlisted');
  return { targetReal: requested, relativePath: raw };
}

function decodeUtf8(buf) {
  let bom = false;
  let payload = buf;
  if (buf.length >= 3 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf) {
    bom = true;
    payload = buf.subarray(3);
  }
  if (payload.includes(0)) throw new Error('binary file denied');
  const text = payload.toString('utf8');
  if (!Buffer.from(text, 'utf8').equals(payload)) throw new Error('non-UTF8 text denied');
  return { text, bom };
}

function encodeUtf8(text, bom) {
  const body = Buffer.from(text, 'utf8');
  return bom ? Buffer.concat([Buffer.from([0xef,0xbb,0xbf]), body]) : body;
}

function normalizeEditText(text) {
  if (typeof text !== 'string') throw new Error('edit text must be a string');
  if (text.includes('\0')) throw new Error('NUL denied');
  return text.replaceAll('\r\n','\n');
}

function detectEol(text) {
  const crlf = (text.match(/\r\n/g) || []).length;
  const bareLf = (text.replaceAll('\r\n','').match(/\n/g) || []).length;
  if (crlf > 0 && bareLf > 0) throw new Error('mixed EOL file denied');
  return crlf > 0 ? '\r\n' : '\n';
}

function withMutationLock(fn, lockPath = MUTATION_LOCK) {
  let fd = null;
  try {
    fd = fs.openSync(lockPath, 'wx');
    fs.writeFileSync(fd, JSON.stringify({pid:process.pid, created_at:new Date().toISOString()}));
    fs.fsyncSync(fd);
    return fn();
  } catch (e) {
    if (e && e.code === 'EEXIST') throw new Error('write workspace mutation already in progress or stale lock requires reconciliation');
    throw e;
  } finally {
    if (fd !== null) {
      try { fs.closeSync(fd); } catch {}
      try { fs.unlinkSync(lockPath); } catch {}
    }
  }
}

function writeSyncedTemp(target, buf) {
  if (buf.length > MAX_WRITE_BYTES) throw new Error('result exceeds bounded write cap');
  const tmp = path.join(path.dirname(target), '.lnwjud-write-' + process.pid + '-' + crypto.randomBytes(6).toString('hex') + '.tmp');
  const fd = fs.openSync(tmp, 'wx');
  try {
    fs.writeFileSync(fd, buf);
    fs.fsyncSync(fd);
  } finally {
    fs.closeSync(fd);
  }
  return tmp;
}

function atomicReplaceExpected(target, buf, expectedSha256) {
  const tmp = writeSyncedTemp(target, buf);
  try {
    const immediatelyBefore = fs.readFileSync(target);
    if (sha256Buffer(immediatelyBefore) !== expectedSha256) {
      throw new Error('stale file SHA256 at replacement boundary; re-read before editing');
    }
    fs.renameSync(tmp, target);
    const readback = fs.readFileSync(target);
    if (!readback.equals(buf)) throw new Error('replacement readback mismatch');
  } finally {
    if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
  }
}

function atomicCreateNew(target, buf) {
  const tmp = writeSyncedTemp(target, buf);
  try {
    fs.linkSync(tmp, target);
    const readback = fs.readFileSync(target);
    if (!readback.equals(buf)) throw new Error('create-new readback mismatch');
  } finally {
    if (fs.existsSync(tmp)) fs.unlinkSync(tmp);
  }
}

function boundedDiff(relativePath) {
  const out = runGit(['diff','--no-ext-diff','--unified=3','--',relativePath], {maxBuffer: 2 * 1024 * 1024}).stdout;
  if (out.length <= MAX_DIFF_CHARS) return {text: out, truncated: false};
  return {text: out.slice(0, MAX_DIFF_CHARS) + '\n...DIFF_TRUNCATED...\n', truncated: true};
}

function writeWorkspaceStatus(writeRootReal) {
  assertWriteWorkspaceIdentity(writeRootReal);
  const head = runGit(['rev-parse','HEAD']).stdout.trim();
  const originMaster = runGit(['rev-parse','origin/master']).stdout.trim();
  const status = runGit(['status','--porcelain=v1','--untracked-files=all']).stdout.trimEnd();
  const rows = status ? status.split(/\r?\n/) : [];
  return {
    authority: 'BOUNDED_ISOLATED_WORKTREE_TEXT_WRITE_V1',
    workspace_root: WRITE_ROOT,
    branch: WRITE_BRANCH,
    head,
    origin_master_observed: originMaster,
    clean: rows.length === 0,
    change_count: rows.length,
    changes: rows.slice(0,100),
    limitations: [
      'Writes only the isolated lnwjud workspace; never the dirty primary D:\\EA_LAB worktree.',
      'No arbitrary shell/process, Registry transition, MT5, deployment or trading authority.',
      'No commit/push tool is exposed in V1.',
      'replace_exact requires current file SHA256 plus exactly one matching oldText.'
    ]
  };
}

function buildServer(ctx) {
  const { seal, canonical, lanes, jobs, evidence, monitor, canonicalRootReal, evidenceRootReal, writeRootReal, canonicalMap, evidenceMap } = ctx;
  const server = new McpServer(
    { name: 'ea-lab-current-write-v1', version: '0.1.0-preview' },
    { capabilities: { tools: {} } }
  );

  server.registerTool('ea_lab_current_status', {
    description: 'Return the exact point-in-time CURRENT READ V2 snapshot identity, canonical binding at capture, freshness age, counts, authority, and limitations.',
    inputSchema: z.object({}).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async () => {
    const capturedMs = Date.parse(seal.captured_at_utc);
    const ageSeconds = Number.isFinite(capturedMs) ? Math.max(0, Math.floor((Date.now() - capturedMs) / 1000)) : null;
    const freshness = ageSeconds === null ? 'UNKNOWN' : ageSeconds <= 900 ? 'FRESH_15M' : ageSeconds <= 3600 ? 'AGING_1H' : 'STALE_BY_AGE';
    const structured = {
      snapshot_id: seal.snapshot_id,
      captured_at_utc: seal.captured_at_utc,
      snapshot_age_seconds: ageSeconds,
      freshness,
      canonical_head: seal.canonical_head,
      origin_master_at_capture: seal.origin_master_at_capture,
      ls_remote_at_capture: seal.ls_remote_at_capture,
      canonical_match_at_capture: (
        seal.canonical_head === seal.origin_master_at_capture &&
        seal.canonical_head === seal.ls_remote_at_capture
      ),
      authority: seal.authority,
      snapshot_authority: seal.authority,
      server_authority: 'READ_SNAPSHOT_PLUS_BOUNDED_ISOLATED_WORKTREE_TEXT_WRITE_V1',
      write_workspace: {
        root: WRITE_ROOT,
        branch: WRITE_BRANCH,
        no_commit_push: true
      },
      counts: seal.counts,
      snapshot_limitations: seal.limitations,
      limitations: [
        'Canonical reads remain point-in-time and are bounded to captured_at_utc plus the exact snapshot manifest.',
        'File mutation is limited to the isolated lnwjud write workspace with path guards, UTF-8/text caps and compare-and-swap checks.',
        'No arbitrary shell/process, Lane Registry transition, MT5, deployment or trading authority is exposed.',
        'No commit or push tool is exposed in Write V1.'
      ],
      note: 'Read currentness is point-in-time; write tools operate only on the separate isolated workspace and report its Git identity independently.'
    };
    return {
      isError: false,
      content: [{ type: 'text', text: JSON.stringify(structured) }],
      structuredContent: structured
    };
  });

  server.registerTool('read_canonical_file', {
    description: 'Read one bounded UTF-8 tracked canonical file from the exact snapshot manifest. Sensitive/untracked/binary/drifted paths are denied.',
    inputSchema: z.object({
      snapshotId: z.string(),
      path: z.string(),
      startLine: z.number().int().min(1).optional(),
      endLine: z.number().int().min(1).optional()
    }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    if (!assertSnapshot(input, seal)) return resultError('SNAPSHOT_DENIED', 'exact snapshotId is required');
    try {
      const resolved = resolveManifestRead(canonicalRootReal, canonicalMap, input.path, forbiddenRepoRelative);
      const lines = readBoundFile(resolved, input.startLine, input.endLine);
      return {
        isError: false,
        content: [{ type: 'text', text: lines.body }],
        structuredContent: {
          snapshot_id: seal.snapshot_id,
          canonical_head: seal.canonical_head,
          relative_path: resolved.relativePath,
          file_sha256: resolved.entry.sha256,
          start_line: lines.startLine,
          end_line: lines.endLine,
          total_lines: lines.totalLines,
          size_bytes: resolved.entry.bytes
        }
      };
    } catch (e) {
      return resultError('POLICY_DENIED', e instanceof Error ? e.message : 'canonical read denied');
    }
  });

  server.registerTool('list_lanes', {
    description: 'List bounded Lane Registry snapshot records captured by CURRENT READ V2. This is observation only, not liveness or transition authority.',
    inputSchema: z.object({
      snapshotId: z.string(),
      states: z.array(z.string()).max(16).optional(),
      writerOnly: z.boolean().optional(),
      limit: z.number().int().min(1).max(100).optional()
    }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    if (!assertSnapshot(input, seal)) return resultError('SNAPSHOT_DENIED', 'exact snapshotId is required');
    const states = normalizeStateFilter(input.states);
    const limit = input.limit ?? 50;
    const rows = lanes.filter((x) => {
      if (states && !states.has(String(x.state || '').toUpperCase())) return false;
      if (input.writerOnly === true && x.writer !== true) return false;
      return true;
    }).slice(0, limit);
    return {
      isError: false,
      content: [{ type: 'text', text: JSON.stringify(rows) }],
      structuredContent: { snapshot_id: seal.snapshot_id, count: rows.length, lanes: rows }
    };
  });

  server.registerTool('get_lane', {
    description: 'Return one exact Lane Registry snapshot record by lane_id.',
    inputSchema: z.object({ snapshotId: z.string(), laneId: z.string().min(1).max(128) }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    if (!assertSnapshot(input, seal)) return resultError('SNAPSHOT_DENIED', 'exact snapshotId is required');
    const row = lanes.find((x) => x.lane_id === input.laneId);
    if (!row) return resultError('NOT_FOUND', 'lane not present in snapshot');
    return {
      isError: false,
      content: [{ type: 'text', text: JSON.stringify(row) }],
      structuredContent: { snapshot_id: seal.snapshot_id, lane: row }
    };
  });

  server.registerTool('list_jobs', {
    description: 'List bounded durable-job metadata captured by CURRENT READ V2. No logs, command arguments, or process control are exposed.',
    inputSchema: z.object({
      snapshotId: z.string(),
      states: z.array(z.string()).max(16).optional(),
      limit: z.number().int().min(1).max(100).optional()
    }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    if (!assertSnapshot(input, seal)) return resultError('SNAPSHOT_DENIED', 'exact snapshotId is required');
    const states = normalizeStateFilter(input.states);
    const limit = input.limit ?? 50;
    const rows = jobs.filter((x) => !states || states.has(String(x.state || '').toUpperCase())).slice(0, limit);
    return {
      isError: false,
      content: [{ type: 'text', text: JSON.stringify(rows) }],
      structuredContent: { snapshot_id: seal.snapshot_id, count: rows.length, jobs: rows }
    };
  });

  server.registerTool('get_job', {
    description: 'Return one durable-job metadata record from the bound snapshot by exact job_id.',
    inputSchema: z.object({ snapshotId: z.string(), jobId: z.string().min(1).max(256) }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    if (!assertSnapshot(input, seal)) return resultError('SNAPSHOT_DENIED', 'exact snapshotId is required');
    const row = jobs.find((x) => x.job_id === input.jobId);
    if (!row) return resultError('NOT_FOUND', 'job not present in snapshot');
    return {
      isError: false,
      content: [{ type: 'text', text: JSON.stringify(row) }],
      structuredContent: { snapshot_id: seal.snapshot_id, job: row }
    };
  });

  server.registerTool('list_evidence', {
    description: 'Search the bounded recent evidence manifest by path substring. Returns metadata only; sensitive/binary/large/old evidence is not indexed.',
    inputSchema: z.object({
      snapshotId: z.string(),
      query: z.string().max(256).optional(),
      limit: z.number().int().min(1).max(100).optional()
    }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    if (!assertSnapshot(input, seal)) return resultError('SNAPSHOT_DENIED', 'exact snapshotId is required');
    const q = String(input.query || '').toLowerCase();
    const limit = input.limit ?? 50;
    const rows = evidence.filter((x) => !q || x.path_key.includes(q)).slice(0, limit);
    return {
      isError: false,
      content: [{ type: 'text', text: JSON.stringify(rows) }],
      structuredContent: { snapshot_id: seal.snapshot_id, count: rows.length, evidence: rows }
    };
  });

  server.registerTool('read_evidence', {
    description: 'Read one bounded UTF-8 evidence file from the exact recent evidence manifest. Drifted/sensitive/unindexed paths are denied.',
    inputSchema: z.object({
      snapshotId: z.string(),
      path: z.string(),
      startLine: z.number().int().min(1).optional(),
      endLine: z.number().int().min(1).optional()
    }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    if (!assertSnapshot(input, seal)) return resultError('SNAPSHOT_DENIED', 'exact snapshotId is required');
    try {
      const resolved = resolveManifestRead(evidenceRootReal, evidenceMap, input.path, forbiddenEvidenceRelative);
      const lines = readBoundFile(resolved, input.startLine, input.endLine);
      return {
        isError: false,
        content: [{ type: 'text', text: lines.body }],
        structuredContent: {
          snapshot_id: seal.snapshot_id,
          relative_path: resolved.relativePath,
          file_sha256: resolved.entry.sha256,
          start_line: lines.startLine,
          end_line: lines.endLine,
          total_lines: lines.totalLines,
          size_bytes: resolved.entry.bytes,
          mtime_utc: resolved.entry.mtime_utc
        }
      };
    } catch (e) {
      return resultError('POLICY_DENIED', e instanceof Error ? e.message : 'evidence read denied');
    }
  });

  server.registerTool('monitor_summary', {
    description: 'Return the captured read-only Monitor delivery receipt and inventory summary. Monitor content may itself report older/stale bindings.',
    inputSchema: z.object({ snapshotId: z.string() }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    if (!assertSnapshot(input, seal)) return resultError('SNAPSHOT_DENIED', 'exact snapshotId is required');
    const structured = {
      snapshot_id: seal.snapshot_id,
      delivery_receipt: monitor.delivery_receipt ?? null,
      inventory_summary: monitor.inventory_summary ?? null
    };
    return {
      isError: false,
      content: [{ type: 'text', text: JSON.stringify(structured) }],
      structuredContent: structured
    };
  });


  server.registerTool('ea_lab_write_status', {
    description: 'Return bounded lnwjud write-workspace identity and dirty state. This is an isolated Git worktree, never the dirty primary D:\\EA_LAB workspace.',
    inputSchema: z.object({}).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async () => {
    try {
      const structured = writeWorkspaceStatus(writeRootReal);
      return { isError:false, content:[{type:'text',text:JSON.stringify(structured)}], structuredContent:structured };
    } catch (e) {
      return resultError('WRITE_STATUS_DENIED', e instanceof Error ? e.message : 'write status denied');
    }
  });

  server.registerTool('refresh_write_workspace', {
    description: 'Refresh the isolated lnwjud write workspace to current origin/master using fetch plus fast-forward only. Refuses any dirty, ahead, or divergent workspace.',
    inputSchema: z.object({ expectedHead: z.string().regex(/^[0-9a-f]{40}$/).optional() }).strict(),
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true }
  }, async (input) => {
    try {
      const structured = withMutationLock(() => {
        const before = writeWorkspaceStatus(writeRootReal);
        if (!before.clean) throw new Error('workspace dirty; refresh refused');
        if (input.expectedHead && input.expectedHead !== before.head) throw new Error('expectedHead mismatch');
        runGit(['fetch','origin','master']);
        const originMaster = runGit(['rev-parse','origin/master']).stdout.trim();
        const remoteLine = runGit(['ls-remote','origin','refs/heads/master']).stdout.trim();
        const remote = remoteLine.split(/\s+/)[0] || '';
        if (!/^[0-9a-f]{40}$/.test(originMaster) || originMaster !== remote) throw new Error('origin/master != ls-remote after fetch');
        let head = runGit(['rev-parse','HEAD']).stdout.trim();
        if (head !== originMaster) {
          const anc = runGit(['merge-base','--is-ancestor',head,originMaster], {allowFailure:true});
          if (anc.status !== 0) throw new Error('workspace is ahead/divergent; ff-only refresh refused');
          runGit(['merge','--ff-only','origin/master']);
          head = runGit(['rev-parse','HEAD']).stdout.trim();
        }
        if (head !== originMaster) throw new Error('post-refresh head mismatch');
        return { result:'REFRESHED_FF_ONLY', previous_head:before.head, head, origin_master:originMaster, remote_head:remote };
      });
      return { isError:false, content:[{type:'text',text:JSON.stringify(structured)}], structuredContent:structured };
    } catch (e) {
      return resultError('REFRESH_DENIED', e instanceof Error ? e.message : 'refresh denied');
    }
  });

  server.registerTool('read_workspace_file', {
    description: 'Read a bounded UTF-8 tracked file from the isolated lnwjud write workspace, including current SHA256 after any edits.',
    inputSchema: z.object({
      path: z.string(),
      startLine: z.number().int().min(1).optional(),
      endLine: z.number().int().min(1).optional()
    }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    try {
      assertWriteWorkspaceIdentity(writeRootReal);
      const resolved = resolveWorkspaceExisting(writeRootReal, input.path);
      const buf = fs.readFileSync(resolved.targetReal);
      const decoded = decodeUtf8(buf);
      const lines = decoded.text.replaceAll('\r\n','\n').split('\n');
      const start = input.startLine ?? 1;
      const requestedEnd = input.endLine ?? Math.min(lines.length, start + MAX_RETURN_LINES - 1);
      if (requestedEnd < start || requestedEnd - start + 1 > MAX_RETURN_LINES) throw new Error('invalid/bounded line range');
      const end = Math.min(requestedEnd, lines.length);
      const structured = {
        relative_path: resolved.relativePath,
        file_sha256: sha256Buffer(buf),
        start_line:start,
        end_line:end,
        total_lines:lines.length,
        size_bytes:buf.length
      };
      return { isError:false, content:[{type:'text',text:lines.slice(start-1,end).join('\n')}], structuredContent:structured };
    } catch (e) {
      return resultError('WORKSPACE_READ_DENIED', e instanceof Error ? e.message : 'workspace read denied');
    }
  });

  server.registerTool('edit_workspace_file', {
    description: 'Bounded text mutation in the isolated lnwjud write workspace. operation=replace_exact requires expectedSha256 and exactly one oldText match; operation=create_new only creates a new allowlisted text file under an existing directory.',
    inputSchema: z.object({
      operation: z.enum(['replace_exact','create_new']),
      path: z.string(),
      expectedSha256: z.string().regex(/^[0-9a-f]{64}$/).optional(),
      oldText: z.string().optional(),
      newText: z.string()
    }).strict(),
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: false }
  }, async (input) => {
    try {
      const outcome = withMutationLock(() => {
        assertWriteWorkspaceIdentity(writeRootReal);
        if (input.operation === 'replace_exact') {
          if (!input.expectedSha256) throw new Error('expectedSha256 required');
          if (typeof input.oldText !== 'string' || input.oldText.length === 0) throw new Error('non-empty oldText required');
          const resolved = resolveWorkspaceExisting(writeRootReal, input.path);
          const buf = fs.readFileSync(resolved.targetReal);
          const currentSha = sha256Buffer(buf);
          if (currentSha !== input.expectedSha256) throw new Error('stale file SHA256; re-read before editing');
          const decoded = decodeUtf8(buf);
          const eol = detectEol(decoded.text);
          const normalized = decoded.text.replaceAll('\r\n','\n');
          const oldNorm = normalizeEditText(input.oldText);
          const newNorm = normalizeEditText(input.newText);
          const first = normalized.indexOf(oldNorm);
          if (first < 0) throw new Error('oldText not found');
          const second = normalized.indexOf(oldNorm, first + oldNorm.length);
          if (second >= 0) throw new Error('oldText is not unique');
          let next = normalized.slice(0,first) + newNorm + normalized.slice(first + oldNorm.length);
          if (eol === '\r\n') next = next.replaceAll('\n','\r\n');
          const nextBuf = encodeUtf8(next, decoded.bom);
          atomicReplaceExpected(resolved.targetReal, nextBuf, input.expectedSha256);
          const newBuf = fs.readFileSync(resolved.targetReal);
          const diff = boundedDiff(resolved.relativePath);
          return {
            responseText: diff.text,
            structured: {
              result:'REPLACED_EXACT_ONCE_GATEWAY_SERIALIZED',
              relative_path:resolved.relativePath,
              previous_sha256:currentSha,
              file_sha256:sha256Buffer(newBuf),
              size_bytes:newBuf.length,
              diff_truncated:diff.truncated
            }
          };
        }
        if (input.expectedSha256 || input.oldText !== undefined) throw new Error('create_new does not accept expectedSha256/oldText');
        const resolved = resolveWorkspaceCreate(writeRootReal, input.path);
        const content = normalizeEditText(input.newText);
        const buf = Buffer.from(content,'utf8');
        atomicCreateNew(resolved.targetReal, buf);
        const status = runGit(['status','--porcelain=v1','--',resolved.relativePath]).stdout;
        return {
          responseText: status,
          structured: {
            result:'CREATED_NEW_TEXT_FILE_NO_REPLACE',
            relative_path:resolved.relativePath,
            file_sha256:sha256Buffer(fs.readFileSync(resolved.targetReal)),
            size_bytes:buf.length
          }
        };
      });
      return { isError:false, content:[{type:'text',text:outcome.responseText}], structuredContent:outcome.structured };
    } catch (e) {
      return resultError('WRITE_DENIED', e instanceof Error ? e.message : 'write denied');
    }
  });

  server.registerTool('workspace_diff', {
    description: 'Return bounded git status and diff for the isolated lnwjud write workspace. No commit or push is performed.',
    inputSchema: z.object({ path: z.string().optional() }).strict(),
    annotations: { readOnlyHint: true, destructiveHint: false }
  }, async (input) => {
    try {
      assertWriteWorkspaceIdentity(writeRootReal);
      let rel = null;
      if (input.path !== undefined) {
        const raw = normalizeRawRelative(input.path);
        if (forbiddenWriteRepoRelative(raw)) throw new Error('forbidden path denied');
        rel = raw;
      }
      const statusArgs = ['status','--porcelain=v1','--untracked-files=all'];
      const diffArgs = ['diff','--no-ext-diff','--unified=3'];
      if (rel) { statusArgs.push('--',rel); diffArgs.push('--',rel); }
      const status = runGit(statusArgs).stdout;
      let diff = runGit(diffArgs, {maxBuffer:2*1024*1024}).stdout;
      let truncated = false;
      if (diff.length > MAX_DIFF_CHARS) { diff = diff.slice(0,MAX_DIFF_CHARS) + '\n...DIFF_TRUNCATED...\n'; truncated = true; }
      const structured = { path:rel, diff_truncated:truncated, status_lines:status.trim()?status.trimEnd().split(/\r?\n/):[] };
      return { isError:false, content:[{type:'text',text:(status ? 'STATUS\n'+status+'\n' : 'STATUS clean\n') + 'DIFF\n' + diff}], structuredContent:structured };
    } catch (e) {
      return resultError('DIFF_DENIED', e instanceof Error ? e.message : 'diff denied');
    }
  });

  return server;
}

function isLoopbackRemote(address) {
  return address === '127.0.0.1' || address === '::1' || address === '::ffff:127.0.0.1';
}

async function nodeRequestToWeb(req) {
  const chunks = [];
  let bytes = 0;
  for await (const chunk of req) {
    const b = Buffer.from(chunk);
    bytes += b.length;
    if (bytes > 2 * 1024 * 1024) throw new Error('HTTP request body exceeds 2 MiB cap');
    chunks.push(b);
  }
  const headers = new Headers();
  for (const [name, value] of Object.entries(req.headers)) {
    if (Array.isArray(value)) {
      for (const v of value) headers.append(name, v);
    } else if (value !== undefined) {
      headers.set(name, String(value));
    }
  }
  const init = { method: req.method, headers };
  if (!['GET','HEAD'].includes(req.method || 'GET')) init.body = Buffer.concat(chunks);
  return new Request('http://' + HTTP_HOST + ':' + HTTP_PORT + (req.url || HTTP_PATH), init);
}

async function writeWebResponse(res, response) {
  res.statusCode = response.status;
  response.headers.forEach((value, name) => res.setHeader(name, value));
  const body = Buffer.from(await response.arrayBuffer());
  res.setHeader('content-length', String(body.length));
  res.end(body);
}

async function main() {
  const startupCtx = assertLaunchIdentity();
  const handler = createMcpHandler(
    () => buildServer(assertLaunchIdentity()),
    {
      legacy: 'stateless',
      responseMode: 'json',
      onerror: (error) => process.stderr.write('ea-lab-current-write-v1 error: ' + error.message + '\n')
    }
  );

  const httpServer = http.createServer(async (req, res) => {
    try {
      if (!isLoopbackRemote(req.socket.remoteAddress)) {
        res.writeHead(403, {'content-type':'text/plain'}).end('loopback only');
        return;
      }
      if (req.url === '/healthz' && req.method === 'GET') {
        res.writeHead(200, {'content-type':'text/plain','cache-control':'no-store'}).end('ready');
        return;
      }
      const pathOnly = (req.url || '').split('?', 1)[0];
      if (pathOnly !== HTTP_PATH) {
        res.writeHead(404, {'content-type':'text/plain'}).end('not found');
        return;
      }
      const request = await nodeRequestToWeb(req);
      const rejected =
        hostHeaderValidationResponse(request, localhostAllowedHostnames()) ??
        originValidationResponse(request, localhostAllowedOrigins());
      const response = rejected ?? await handler.fetch(request);
      await writeWebResponse(res, response);
    } catch (error) {
      process.stderr.write(
        'ea-lab-current-write-v1 request error: ' +
        (error instanceof Error ? error.message : String(error)) +
        '\n'
      );
      if (!res.headersSent) res.writeHead(500, {'content-type':'application/json'});
      res.end(JSON.stringify({error:'internal_error'}));
    }
  });

  httpServer.keepAliveTimeout = 5000;
  httpServer.headersTimeout = 10000;
  await new Promise((resolve, reject) => {
    httpServer.once('error', reject);
    httpServer.listen(HTTP_PORT, HTTP_HOST, resolve);
  });

  process.stderr.write(
    'ea-lab-current-write-v1 ready url=http://' + HTTP_HOST + ':' + HTTP_PORT + HTTP_PATH +
    ' snapshot=' + startupCtx.seal.snapshot_id +
    ' head=' + startupCtx.seal.canonical_head +
    '\n'
  );

  const shutdown = async () => {
    try { await handler.close(); } catch {}
    httpServer.close(() => process.exit(0));
  };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(
      'ea-lab-current-write-v1 failed: ' +
      (error instanceof Error ? error.stack || error.message : String(error)) +
      '\n'
    );
    process.exitCode = 1;
  });
}

module.exports = {
  withMutationLock,
  atomicReplaceExpected,
  atomicCreateNew,
  sha256Buffer
};
