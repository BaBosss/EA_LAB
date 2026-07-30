import json, sys

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
no_unev, no_const = [], []
for name in sorted(br):
    s = d['$defs'][name]
    if s.get('unevaluatedProperties') is not False:
        no_unev.append(name)
    if s.get('properties', {}).get('entity', {}).get('const') != name:
        no_const.append(name)
chk(not no_unev, "all %d routed entities set unevaluatedProperties:false (missing=%s)" % (len(br), no_unev))
chk(not no_const, "all routed entities pin entity const to their own name (missing=%s)" % no_const)
print("  helper $defs (referenced only from inside entities): %s" % sorted(defs - br))

print("\nAUDIT P1 SPOT-CHECKS")
c = d['$defs']['CandidatePayload']
chk('candidate_id' not in c.get('properties', {}),
    "CandidatePayload does NOT contain candidate_id -> self-referential hash fixed")
m = d['$defs']['CandidateManifest']['properties']
chk('candidate_digest' in m and 'payload' in m,
    "CandidateManifest separates the digest from the hashed payload")
w = d['$defs']['WorkReceipt']['allOf'][0]['then']
chk(set(w.get('required', [])) == {'waiting_for', 'wake_condition'},
    "WAITING requires BOTH fields (rev1 used anyOf, so one sufficed)")
sm = d['$defs']['SnapshotMeta']['properties']
chk(sm['version'].get('minimum') == 5, "snapshot version floor is v5 (v4 already exists at HEAD)")
chk('mandatory_sources' in sm, "mandatory-source registry kept separate from discovered sources")
srcreq = sm['sources']['items']['required']
chk('fresh' in srcreq and 'read_ok' in srcreq, "every source must declare read_ok AND fresh")
rec = sm['reconciliation']['required']
chk('categories' in rec and 'coverage' in rec, "category and coverage totals are encoded, not implied in prose")
rj = d['$defs']['RunJournal']['properties']
chk(rj['attempts']['type'] == 'array', "RunJournal keeps an ARRAY of attempts (rev1 had one mutable state)")
ek = set(d['$defs']['ExecutionKey']['required'])
chk({'deposit', 'leverage', 'currency', 'data_fingerprint', 'effective_config_hash'} <= ek,
    "ExecutionKey requires deposit/leverage/currency/fingerprint/effective-config")
dae = d['$defs']['DeploymentAttestationEvent']['allOf'][0]['then']
chk('authorization_ref' in dae.get('required', []),
    "any non-OBSERVED attestation event requires a human authorization ref")

print("\n=== %s ===" % ("STRUCTURE OK" if fail == 0 else "%d STRUCTURAL FAILURES" % fail))
sys.exit(1 if fail else 0)
