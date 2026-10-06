'use strict';
// Windows-side source for the only admitted production bridge. No child_process is
// used here. Actuation and inspection are injected typed dependencies so source tests
// cannot launch a process. The client never supplies any field consumed by this file.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const R = require('./runtime_request_contract.cjs');
const { refuse, hash, stable, clone, freeze, object, id, digest, keys } = R;
function component(c) {
  return !!c && c !== '.' && c !== '..' && !/^ |[. ]$/.test(c) &&
    !/[:?*<>"|\x00-\x1f\x7f]/.test(c) &&
    !/^(?:CON|PRN|AUX|NUL|COM[1-9\u00b9\u00b2\u00b3]|LPT[1-9\u00b9\u00b2\u00b3]|CONIN\$|CONOUT\$)(?:\.|$)/i.test(c);
}
function winAbs(value) {
  if (typeof value !== 'string' || value.trim() !== value) return false;
  const n = value.replaceAll('/','\\');
  if (!/^[A-Za-z]:\\/.test(n) || /^\\\\/.test(n) || /^\\\\[?.]\\/.test(n)) return false;
  return n.slice(3).split('\\').every(component);
}
function profilePayload(profile) {
  const copy = clone(profile); delete copy.profile_sha256; return copy;
}
function profileDigest(profile) { return hash(stable(profilePayload(profile))); }
function runnerArgHash(args) {
  if (!Array.isArray(args) || !args.every(x => typeof x === 'string' && !x.includes('\u0000'))) refuse('INVALID_LAUNCH_PROFILE');
  return crypto.createHash('sha256').update(args.join('\u0000'),'utf8').digest('base64');
}
function validateProfile(profile) {
  keys(profile, ['profile_id','profile_sha256','stage','source_head','runner','target','worktree','base_sha',
    'timeout_sec','heartbeat_sec','postcondition','jobs_root']);
  if (![profile.profile_id,profile.stage].every(id) || !digest(profile.profile_sha256) ||
      !/^[a-f0-9]{40}$/.test(profile.source_head) || !/^[a-f0-9]{40}$/.test(profile.base_sha) ||
      profile.runner !== 'LONG_JOB_RUNNER_V1' || profile.profile_sha256 !== profileDigest(profile)) refuse('LAUNCH_PROFILE_DRIFT');
  keys(profile.target, ['file_path','arguments']);
  if (!winAbs(profile.target.file_path) || !Array.isArray(profile.target.arguments) ||
      !profile.target.arguments.every(x => typeof x === 'string' && !/[\u0000\r\n]/.test(x))) refuse('INVALID_LAUNCH_PROFILE');
  if (!winAbs(profile.worktree) || !winAbs(profile.jobs_root) ||
      !Number.isSafeInteger(profile.timeout_sec) || profile.timeout_sec < 1 || profile.timeout_sec > 604800 ||
      !Number.isSafeInteger(profile.heartbeat_sec) || profile.heartbeat_sec < 1 || profile.heartbeat_sec > 3600)
    refuse('INVALID_LAUNCH_PROFILE');
  if (profile.postcondition !== null) {
    keys(profile.postcondition, ['file_path','arguments']);
    if (!winAbs(profile.postcondition.file_path) || !Array.isArray(profile.postcondition.arguments) ||
        !profile.postcondition.arguments.every(x => typeof x === 'string' && !/[\u0000\r\n]/.test(x))) refuse('INVALID_LAUNCH_PROFILE');
  }
  return freeze(clone(profile));
}
function validateCatalog(catalog) {
  if (!object(catalog) || !Object.keys(catalog).length) refuse('EMPTY_LAUNCH_CATALOG');
  const out = Object.create(null);
  for (const [key, raw] of Object.entries(catalog)) {
    if (!id(key) || !Object.prototype.hasOwnProperty.call(catalog,key)) refuse('INVALID_LAUNCH_PROFILE');
    const p = validateProfile(raw);
    if (p.profile_id !== key) refuse('LAUNCH_PROFILE_DRIFT');
    out[key] = p;
  }
  return freeze(out);
}
function createWindowsLongJobBridge({ repoRoot, catalog, actuator, inspector } = {}) {
  if (!winAbs(repoRoot)) refuse('INVALID_REPO_ROOT');
  const admitted = validateCatalog(catalog);
  if (!actuator || actuator.kind !== 'EXISTING_LONG_JOB_RUNNER_ACTUATOR_V1' || typeof actuator.launch !== 'function')
    refuse('UNQUALIFIED_ACTUATOR');
  if (!inspector || inspector.kind !== 'EXISTING_LONG_JOB_RUNNER_INSPECTOR_V1' || typeof inspector.get !== 'function')
    refuse('UNQUALIFIED_INSPECTOR');
  const runnerScript = path.win32.join(path.win32.normalize(repoRoot), 'scripts', 'long_jobs', 'start_long_job.ps1');
  function resolve(profileId, expectedSha, stage, sourceHead) {
    if (!id(profileId) || !digest(expectedSha)) refuse('UNKNOWN_LAUNCH_PROFILE');
    const p = admitted[profileId];
    if (!p || p.profile_sha256 !== expectedSha) refuse('UNKNOWN_LAUNCH_PROFILE');
    if (p.stage !== stage || p.source_head !== sourceHead || p.base_sha !== sourceHead) refuse('LAUNCH_PROFILE_DRIFT');
    return p;
  }
  function expected(jobId, plan, p) {
    return freeze({ job_id: jobId, runner_script: runnerScript, profile_id: p.profile_id,
      profile_sha256: p.profile_sha256, stage: p.stage, source_head: p.source_head,
      file_path: p.target.file_path, arg_hash: runnerArgHash(p.target.arguments), worktree: p.worktree,
      base_sha: p.base_sha, jobs_root: p.jobs_root, binding_sha256: plan.binding_sha256,
      request_sha256: plan.request_sha256 });
  }
  function findExisting(plan) {
    const p = resolve(plan.profile_id, plan.profile_sha256, plan.stage, plan.source_head);
    const observed = inspector.get(plan.job_id);
    if (observed === null || observed === undefined) return null;
    keys(observed, ['job_id','runner_script','profile_id','profile_sha256','stage','source_head','file_path','arg_hash','worktree',
      'base_sha','jobs_root','binding_sha256','request_sha256','launch_receipt_sha256']);
    const e = expected(plan.job_id, plan, p);
    for (const [k,v] of Object.entries(e)) if (stable(observed[k]) !== stable(v)) refuse('EXISTING_JOB_IDENTITY_MISMATCH');
    if (!digest(observed.launch_receipt_sha256)) refuse('EXISTING_JOB_IDENTITY_MISMATCH');
    return freeze(clone(observed));
  }
  function dispatch(plan) {
    if (!object(plan) || !id(plan.job_id) || !digest(plan.binding_sha256) || !digest(plan.request_sha256)) refuse('INVALID_DISPATCH_PLAN');
    const p = resolve(plan.profile_id, plan.profile_sha256, plan.stage, plan.source_head);
    if (findExisting(plan) !== null) refuse('DUPLICATE_EXECUTION');
    const params = freeze({ FilePath: p.target.file_path, ArgumentList: [...p.target.arguments], JobId: plan.job_id,
      TimeoutSec: p.timeout_sec, HeartbeatSec: p.heartbeat_sec, Worktree: p.worktree, BaseSha: p.base_sha,
      Stage: p.stage, PostconditionFilePath: p.postcondition?.file_path || '',
      PostconditionArgumentList: p.postcondition ? [...p.postcondition.arguments] : [], JobsRoot: p.jobs_root, Json: true });
    let raw;
    try {
      raw = actuator.launch(freeze({ script: runnerScript, parameters: params, expected: expected(plan.job_id, plan, p) }));
    } catch (error) {
      const recovered = findExisting(plan);
      if (recovered) return recovered;
      if (error && (error.launch_not_started === true || error.code === 'ACTUATION_NOT_STARTED')) throw error;
      refuse('ACTUATION_OUTCOME_UNPROVEN');
    }
    if (!object(raw) || raw.job_id !== plan.job_id || !digest(raw.launch_receipt_sha256)) refuse('LAUNCH_RECEIPT_INVALID');
    const readback = findExisting(plan);
    if (!readback || readback.launch_receipt_sha256 !== raw.launch_receipt_sha256) refuse('LAUNCH_RECEIPT_READBACK_MISMATCH');
    return readback;
  }
  const validateProfileBinding = plan => { resolve(plan.profile_id, plan.profile_sha256, plan.stage, plan.source_head); return true; };
  return Object.freeze({ kind: 'WINDOWS_LONG_JOB_BRIDGE_V1', runner: 'scripts/long_jobs/start_long_job.ps1', validateProfileBinding, dispatch, findExisting });
}
function atomicWrite(file, bytes) {
  const temp = file + '.next'; let fd;
  try { fd = fs.openSync(temp, 'wx'); } catch (e) { if (e.code === 'EEXIST') refuse('STORAGE_RECONCILE_REQUIRED'); throw e; }
  try { fs.writeFileSync(fd, bytes); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
  fs.renameSync(temp, file);
}
function createWindowsRuntimeStore({ root } = {}) {
  if (!winAbs(root)) refuse('INVALID_STORE_ROOT');
  if (!fs.existsSync(root)) fs.mkdirSync(root, { recursive: true });
  const stat = fs.lstatSync(root);
  if (!stat.isDirectory() || stat.isSymbolicLink()) refuse('INVALID_STORE_ROOT');
  const recordFile = path.win32.join(root, 'record.json'), lockFile = path.win32.join(root, 'exclusive.lock');
  let held = false;
  function record() {
    let raw;
    try { raw = fs.readFileSync(recordFile); } catch (e) { if (e.code === 'ENOENT') return null; throw e; }
    let r;
    try { r = JSON.parse(raw.toString('utf8')); } catch { refuse('MALFORMED_STATE'); }
    keys(r, ['schema','revision','sha256','state_base64']);
    if (r.schema !== 'LNWJUD_JOB_CONTROL_RUNTIME_RECORD_V1' || !Number.isSafeInteger(r.revision) || r.revision < 1 ||
        !digest(r.sha256) || typeof r.state_base64 !== 'string' ||
        !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(r.state_base64)) refuse('MALFORMED_STATE');
    const state = Buffer.from(r.state_base64,'base64');
    if (state.toString('base64') !== r.state_base64 || hash(state) !== r.sha256) refuse('STALE_RECEIPT');
    const parsed = R.parse(state, 4 * 1024 * 1024);
    if (parsed.revision !== r.revision) refuse('STALE_RECEIPT');
    return { state, anchor:{revision:r.revision,sha256:r.sha256} };
  }
  const read = () => { const r=record(); return r ? Buffer.from(r.state) : null; };
  const anchor = () => { const r=record(); return r ? { ...r.anchor } : { revision:0,sha256:null }; };
  function withLock(fn) {
    let fd;
    try { fd = fs.openSync(lockFile, 'wx'); } catch (e) { if (e.code === 'EEXIST') refuse('STORE_LOCKED'); throw e; }
    held = true;
    try { return fn(); } finally { held = false; fs.closeSync(fd); fs.unlinkSync(lockFile); }
  }
  function compareAndSwap(prior, next) {
    if (!held || !Buffer.isBuffer(next)) refuse('STORE_LOCK_REQUIRED');
    const current = record(), actual = current ? hash(current.state) : null, a = current ? current.anchor : {revision:0,sha256:null};
    if (actual !== prior || a.sha256 !== prior) return false;
    const parsed = R.parse(next, 4 * 1024 * 1024), sha256 = hash(next);
    const envelope = Buffer.from(JSON.stringify({ schema:'LNWJUD_JOB_CONTROL_RUNTIME_RECORD_V1', revision:parsed.revision,
      sha256, state_base64:next.toString('base64') }));
    atomicWrite(recordFile, envelope);
    return true;
  }
  return Object.freeze({ kind: 'WINDOWS_DURABLE_JOB_CONTROL_STORE_V1', serialization: 'EXCLUSIVE_LOCK_CAS_DURABLE_READBACK',
    root, withLock, read, anchor, compareAndSwap, checkpoint: () => {} });
}
module.exports = { winAbs, profileDigest, runnerArgHash, validateProfile, validateCatalog, createWindowsLongJobBridge, createWindowsRuntimeStore };