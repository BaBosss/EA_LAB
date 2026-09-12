// This model projects fixture observations only. No execution or authority output exists.
export const AUTHORITY = 'PRESENTATION_ONLY_NO_AUTHORITY';
export const STAGES = ['Idea','Template','Model1','Report','Optimize','BWD','Model4','Candidate','Demo'];
const sha = /^[a-f0-9]{40}$/;
export function freshness(stamp, now = Date.now()) {
  if (typeof stamp !== 'string' || !/T.*(?:Z|[+-]\d{2}:\d{2})$/.test(stamp)) return 'UNKNOWN';
  const age = now - Date.parse(stamp);
  if (!Number.isFinite(age) || age < -300000) return 'UNKNOWN';
  return age > 86400000 ? 'STALE' : 'FRESH';
}
export function qualify(pack, row, {now = Date.now(), scenario = 'normal', online = true} = {}) {
  if (!online || scenario === 'offline') return 'OFFLINE';
  if (scenario === 'unbound' || !sha.test(pack.baseSha) || row.refSha !== pack.baseSha || row.authority !== AUTHORITY || !row.source) return 'UNBOUND';
  if (scenario === 'stale') return 'STALE';
  const envelope = freshness(pack.observedAt, now);
  return envelope === 'FRESH' ? freshness(row.observedAt, now) : envelope;
}
export function project(pack, rows, options) {
  const ids = rows.map(r => r.id);
  return rows.map(row => {
    const fresh = qualify(pack, row, options);
    const conflict = ids.filter(id => id === row.id).length !== 1;
    const known = fresh === 'FRESH' && !conflict && row.status === 'OBSERVED';
    return {...row, freshness: conflict ? 'CONFLICT' : fresh, known, display: known ? row.data : {}, state: known ? row.data.state || 'UNKNOWN' : 'UNKNOWN'};
  });
}
export function ownerActions(pack, options) {
  // An attention flag, generic E blocker or historical prose is insufficient.
  return project(pack, pack.actions, options).filter(r => r.known && r.data.state === 'BLOCKED' && r.data.blockerClass === 'E' && r.data.explicit === true && r.data.qualified === true && r.data.boundTo === r.refSha && typeof r.data.action === 'string' && r.data.action.trim() && r.data.expiresAt && Date.parse(r.data.expiresAt) > (options?.now ?? Date.now()));
}
export function validatePack(pack) {
  if (pack?.authority !== AUTHORITY || !sha.test(pack.baseSha) || pack.schemaVersion !== 1) throw new Error('Invalid fixture envelope / authority binding');
  for (const key of ['research','lanes','templates','optimizations','blockers','actions']) {
    if (!Array.isArray(pack[key])) throw new Error(`Missing collection: ${key}`);
    for (const r of pack[key]) if (!r || typeof r.id !== 'string' || !r.data || typeof r.data !== 'object' || !r.source || !r.status || r.authority !== AUTHORITY) throw new Error(`Invalid observation: ${key}`);
  }
  return pack;
}
