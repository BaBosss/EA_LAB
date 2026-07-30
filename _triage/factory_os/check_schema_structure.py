import json, re, sys

d = json.load(open('_triage/factory_os/schemas.json', encoding='utf-8'))
fail = 0

def chk(ok, msg):
    global fail
    print(("  [PASS] " if ok else "  [FAIL] ") + msg)
    if not ok:
        fail += 1

print("ROOT")
chk(d.get('type') == 'object', "root declares type=object (rev1 had none -> any instance validated)")
chk(d.get('required') == ['entity'], "root requires the `entity` discriminator")
chk('oneOf' in d, "root has a oneOf union")
chk('properties' in d and 'entity' in d['properties'], "root constrains `entity`")

enum = set(d['properties']['entity']['enum'])
defs = set(d['$defs'].keys())
branches = [b['properties']['entity']['const'] for b in d['oneOf']]
br = set(branches)

print("\nDISCRIMINATOR CONSISTENCY (realistic failure: add an entity, forget its branch)")
chk(len(branches) == len(br), "no duplicate oneOf branches")
chk(enum == br, "every enum value has exactly one branch (enum-only=%s branch-only=%s)"
    % (sorted(enum - br), sorted(br - enum)))
chk(br <= defs, "every branch resolves to a $defs entity (missing=%s)" % sorted(br - defs))

print("\nPER-ENTITY")
# ControlRoomSnapshotV5 is the ONE deliberate exemption, and it is named here rather than
# silently skipped. The real snapshot document versions additively - v3 gained fields, v4
# gained more - so a closed root would reject the next legitimate addition. The guarantee is
# preserved where it matters: its `meta` is a $ref to SnapshotMeta, which IS closed.
OPEN_ROOT_BY_DESIGN = {'ControlRoomSnapshotV5'}
no_unev, no_const = [], []
for name in sorted(br):
    s = d['$defs'][name]
    if s.get('unevaluatedProperties') is not False and name not in OPEN_ROOT_BY_DESIGN:
        no_unev.append(name)
    if s.get('properties', {}).get('entity', {}).get('const') != name:
        no_const.append(name)
chk(not no_unev, "all routed entities except %s set unevaluatedProperties:false (missing=%s)"
    % (sorted(OPEN_ROOT_BY_DESIGN), no_unev))
chk(d['$defs']['SnapshotMeta'].get('unevaluatedProperties') is False,
    "the exempted document's `meta` schema is itself closed, so the exemption does not leak")
chk(not no_const, "all routed entities pin entity const to their own name (missing=%s)" % no_const)
print("  helper $defs (referenced only from inside entities): %s" % sorted(defs - br))

print("\nAUDIT P1 SPOT-CHECKS")
c = d['$defs']['CandidatePayload']
chk('candidate_id' not in c.get('properties', {}),
    "CandidatePayload does NOT contain candidate_id -> self-referential hash fixed")
m = d['$defs']['CandidateManifest']['properties']
chk('candidate_digest' in m and 'payload' in m,
    "CandidateManifest separates the digest from the hashed payload")
# look the rule up rather than indexing allOf - inserting a new rule at position 0 silently
# repointed this assertion at a different contract, which it did on the very next edit
_wait = [a for a in d['$defs']['WorkReceipt']['allOf']
         if a.get('if', {}).get('properties', {}).get('status', {}).get('const') == 'WAITING']
chk(len(_wait) == 1 and set(_wait[0]['then'].get('required', [])) == {'waiting_for', 'wake_condition'},
    "WAITING requires BOTH fields (rev1 used anyOf, so one sufficed)")
sm = d['$defs']['SnapshotMeta']['properties']
chk(sm['version'].get('minimum') == 5, "snapshot version floor is v5 (v4 already exists at HEAD)")
chk('mandatory_sources' in sm, "mandatory-source registry kept separate from discovered sources")
srcreq = sm['sources']['items']['required']
chk('fresh' in srcreq and 'read_ok' in srcreq, "every source must declare read_ok AND fresh")
rec = sm['reconciliation']['required']
chk('categories' in rec and 'coverage' in rec, "category and coverage totals are encoded, not implied in prose")

print("\nRE-AUDIT FIXES")
# the schema of the FILE must match the shape the file actually has
snap = d['$defs']['ControlRoomSnapshotV5']
chk(snap['properties']['meta'].get('$ref', '').endswith('SnapshotMeta'),
    "the whole-document schema exists and uses SnapshotMeta for its `meta` property only")
chk({'meta', 'system_health', 'summary'} <= set(snap['required']),
    "the whole-document schema requires the keys the real snapshot actually has")
wr = d['$defs']['WorkReceipt']
chk(set(wr['required']) == {'entity', 'receipt_id', 'source_agent', 'requested_at'},
    "WorkReceipt no longer unconditionally requires taskboard-owned fields")
order_rule = [a for a in wr['allOf'] if a.get('if', {}).get('required') == ['order_ref']]
chk(bool(order_rule) and 'not' in order_rule[0]['then'],
    "a Receipt carrying order_ref is FORBIDDEN from duplicating title/owner/status/acceptance")
sf = d['$defs']['SystemFinding']
chk('detector_ref' in sf['required'], "SystemFinding pins the snapshot that owns the detector state")
chk('material_revision' in sf['required'], "material_revision is required, so escalation cannot be deduped away")
chk('public_id' in sf['required'], "SystemFinding carries an opaque public_id")
proj = d['$defs']['SafeProjection']['properties']['findings']['items']
chk('public_id' in proj['required'] and 'finding_id' not in proj.get('properties', {}),
    "SafeProjection exposes only the opaque id - the raw finding_id can embed an account or magic")
ma = d['$defs']['MagicAllocation']
legacy = [a for a in ma['allOf'] if a.get('if', {}).get('properties', {}).get('scope', {}).get('const') == 'LEGACY_ACCOUNT_SCOPED']
chk(bool(legacy) and 'legacy_accounts' in legacy[0]['then']['required'],
    "a legacy magic exception must name its accounts and is a closed imported set")
rj = d['$defs']['RunJournal']['properties']
chk(rj['attempts']['type'] == 'array', "RunJournal keeps an ARRAY of attempts (rev1 had one mutable state)")
ek = set(d['$defs']['ExecutionKey']['required'])
chk({'deposit', 'leverage', 'currency', 'data_fingerprint', 'effective_config_hash'} <= ek,
    "ExecutionKey requires deposit/leverage/currency/fingerprint/effective-config")
dae = d['$defs']['DeploymentAttestationEvent']['allOf'][0]['then']
chk('authorization_ref' in dae.get('required', []),
    "any non-OBSERVED attestation event requires a human authorization ref")

print("\nSELF-REVIEW FIXES (2026-07-30 /scrutinize)")
chk('RunTransition' in br, "the PERSISTED run entity is one-transition-per-line, not an object holding an array")
chk(d['$defs']['RunJournal'].get('x-derived') is True,
    "RunJournal is marked derived - a .jsonl path cannot hold an object you rewrite to append")
lease = d['$defs']['RunAttempt']['properties']['lease']
chk('pid' not in lease['required'],
    "the lease does not demand a pid at LEASED, which happens before any process exists")
chk('process_observed' in d['$defs']['RunAttempt']['properties'] and
    'launch_intent_at' in d['$defs']['RunAttempt']['properties'],
    "launch intent and process observation are separate records, so crash-before-spawn is decidable")

# --- design <-> schema binding -------------------------------------------------
# Every recurring defect in two audits plus this self-review had ONE shape: the schema
# said one thing and the design document said another, because nothing checked the seam.
# This is that check. It is cheap and it is the only thing here that would have caught
# all three of today's blockers.
print("\nDESIGN <-> SCHEMA BINDING (the seam every regression came through)")
design = open('_triage/EA_LAB_FACTORY_OS_DESIGN.md', encoding='utf-8').read()

owner_paths = []
for name in sorted(d['$defs']):
    of = d['$defs'][name].get('x-owner-file', '')
    m = re.match(r'^([A-Za-z0-9_./<>-]+\.(?:jsonl|json|csv|md))', of)
    if m and not d['$defs'][name].get('x-derived'):
        owner_paths.append((name, m.group(1)))
missing = [(n, p) for n, p in owner_paths if p not in design]
chk(not missing,
    "every non-derived entity's storage path also appears in the design (drifted=%s)"
    % [f"{n}->{p}" for n, p in missing])

banned = {
    "the same snapshot and the same event ids":
        "would put Telegram back on the full snapshot and reinstate the leak SafeProjection exists to stop",
    "13 lines": "Boss_14_GridLog.mq5 is 12 lines",
    "the eleven unowned facts": "refuted by the first audit - two are unowned, three partly new",
    "§11 — six": "section 11 holds nine open decisions",
}
stale = [(p, why) for p, why in banned.items() if p in design]
chk(not stale, "no refuted claim survives anywhere in the design (found=%s)" % [p for p, _ in stale])

print("\n=== %s ===" % ("STRUCTURE OK" if fail == 0 else "%d STRUCTURAL FAILURES" % fail))
sys.exit(1 if fail else 0)
