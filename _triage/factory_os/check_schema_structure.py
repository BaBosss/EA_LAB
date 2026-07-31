"""
SUPERSEDED AS THE DESIGN<->SCHEMA BINDING (2026-07-30, BACKLOG-D31). Read this before
trusting a green run from it.

This file was built to bind the design to the schema and was believed to be the cure.
Audit 3 measured it against the 7 REGRESSED findings and it would have caught 0 of 7: it
compares storage paths and greps a hardcoded list of banned sentences, while every one of
those defects was semantic. It printed STRUCTURE OK on a commit where the design described
`attempts[]`, a lease with `pid`, and `launched_at` and the schema said the opposite.

The binding now lives in gen_design_contracts.py (the design's normative tables are
GENERATED from schemas.json) and run_contract_binding_tests.py (all 7 regressions
re-applied as mutations, all 7 caught, three controls green). Those two run in the
pre-commit fast tier via scripts/_test/run_contract_binding_tests.ps1.

What is still useful here: root/discriminator/branch shape checks and the
unevaluatedProperties inventory. It is kept as a lint, NOT as evidence that the design and
the schema agree. (An earlier version of this header said it was "deliberately not wired
into any hook" -- that stopped being true on 2026-07-30 when /scrutinize wired it into
run_contract_binding_tests.ps1, and the sentence outlived the fact.)

ORDER-670: every judged read goes through the evidence source -- the index in hook mode,
the worktree on a manual run. Existence probes on enforcer paths go the same way: "the
enforcer exists" is a claim about the commit when a commit is being judged.
"""
import json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import evidence as ev  # noqa: E402

try:
    src = ev.EvidenceSource.for_run()
    print(src.marker('check_schema_structure.py'))
    d = json.loads(src.read_committed('_triage/factory_os/schemas.json'))
except ev.ToolFailure as exc:
    print('[TOOL FAILURE] %s' % exc)
    sys.exit(2)
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
# Exemptions from the closed-object rule. ControlRoomSnapshotV5 used to be the one entry, on the
# argument that the snapshot versions additively so a closed root would reject the next legitimate
# addition. ORDER-601 part 2 rejected that argument -- additive means no field is REMOVED or
# RENAMED, which declaring each new domain satisfies -- and closed the root. The set is now empty.
#
# /scrutinize 2026-07-30: an exemption left behind after the thing it exempted was fixed is worse
# than no exemption, because it silently covers the REGRESSION. This script would have kept
# printing "all routed entities except ['ControlRoomSnapshotV5'] set unevaluatedProperties:false"
# -- a sentence asserting something false -- and if anyone re-opened that root, it would have
# passed. So the list is now self-policing: an entry that is no longer needed is a FAILURE.
OPEN_ROOT_BY_DESIGN = set()
no_unev, no_const = [], []
for name in sorted(br):
    s = d['$defs'][name]
    if s.get('unevaluatedProperties') is not False and name not in OPEN_ROOT_BY_DESIGN:
        no_unev.append(name)
    if s.get('properties', {}).get('entity', {}).get('const') != name:
        no_const.append(name)
stale_exemptions = sorted(n for n in OPEN_ROOT_BY_DESIGN
                          if d['$defs'].get(n, {}).get('unevaluatedProperties') is False)
chk(not stale_exemptions,
    "no exemption outlives what it exempted (stale=%s) -- an exemption for an entity that is "
    "now closed would silently permit re-opening it" % stale_exemptions)
chk(not no_unev, "all routed entities%s set unevaluatedProperties:false (missing=%s)"
    % (' except %s' % sorted(OPEN_ROOT_BY_DESIGN) if OPEN_ROOT_BY_DESIGN else '', no_unev))
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
def deref(node):
    """Follow one hop of a local $ref.

    /scrutinize 2026-07-30: ORDER-601 part 1 (`c8d03d4b`) split ReconciliationEvidence into its
    own $def and made `meta.reconciliation` a `$ref`. This line indexed ['required'] on it and
    raised KeyError, so THIS SCRIPT HAS CRASHED ON EVERY RUN SINCE -- which means the check below
    and the entire DESIGN <-> SCHEMA BINDING section at the bottom have not executed since that
    commit. Nothing noticed, because nothing runs this script: it is in no suite and no hook. It
    is wired into the fast tier as of this fix, which is the only reason a crash here would ever
    be seen again.
    """
    if isinstance(node, dict) and '$ref' in node:
        return d['$defs'][node['$ref'].split('/')[-1]]
    return node


rec = deref(sm['reconciliation'])['required']
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
design = src.read_committed('_triage/EA_LAB_FACTORY_OS_DESIGN.md')
# The generated tables -- including the __STORAGE__ ownership table these checks read -- moved out
# of the design into CONTRACTS.md (`87af43fd`). Both files together are the document, so the
# storage-path and refuted-claim scans read the pair. Reading only the design would have made the
# storage check vacuously fail and the banned-phrase scan blind to half the prose.
contracts = src.read_committed('_triage/factory_os/CONTRACTS.md')
both = design + '\n' + contracts

owner_paths = []
for name in sorted(d['$defs']):
    of = d['$defs'][name].get('x-owner-file', '')
    m = re.match(r'^([A-Za-z0-9_./<>-]+\.(?:jsonl|json|csv|md))', of)
    if m and not d['$defs'][name].get('x-derived'):
        owner_paths.append((name, m.group(1)))
missing = [(n, p) for n, p in owner_paths if p not in both]
chk(not missing,
    "every non-derived entity's storage path also appears in the design or CONTRACTS.md "
    "(drifted=%s)" % [f"{n}->{p}" for n, p in missing])

banned = {
    "the same snapshot and the same event ids":
        "would put Telegram back on the full snapshot and reinstate the leak SafeProjection exists to stop",
    "13 lines": "Boss_14_GridLog.mq5 is 12 lines",
    "the eleven unowned facts": "refuted by the first audit - two are unowned, three partly new",
    "§11 — six": "section 11 holds nine open decisions",
}
stale = [(p, why) for p, why in banned.items() if p in both]
chk(not stale, "no refuted claim survives in the design or CONTRACTS.md (found=%s)"
    % [p for p, _ in stale])

print("\nENFORCEMENT STATUS (Codex audit 7 MAJOR 7: x-enforced-by was false governance state)")
# The schema used to say every x-enforced-by name MUST exist as validator code. SEVEN of the ten
# named had no implementation at all, so the field asserted enforcement that did not exist. Splitting
# it into PLANNED/BUILT/WIRED only helps if the labels are CHECKED -- an unchecked label is the same
# false claim with more syllables. So each one is verified against the repo here:
#   PLANNED  the constraint is enforced by NOTHING today; must not name an existing enforcer
#   BUILT    x-enforcer exists as a real tracked file, but nothing calls it in production
#   WIRED    BUILT, and the enforcer is actually invoked by a hook or the pre-commit tier
_STATUSES = ("PLANNED", "BUILT", "WIRED")
def _invocation_text():
    """Text where a name appearing means it is RUN -- not merely mentioned.

    First version searched the tier files whole, and that was wrong in the way this whole slice keeps
    being wrong: `snapshot_validator.py` is listed in run_fast_cages.ps1's $SUITE_GUARDS map as an
    INPUT that triggers the tier, so a bogus WIRED claim pointing at it passed. Being named in a
    dependency list is not being invoked. The $SUITE_GUARDS block is therefore cut out before
    searching, leaving the parts that actually execute things.
    """
    text = ""
    # .githooks/pre-commit is an invocation script end to end -- everything named there is run.
    if src.exists_committed(".githooks/pre-commit"):
        text += src.read_committed(".githooks/pre-commit", errors="replace")
    # For the tier files, take ONLY the arrays that are executed. Cutting the $SUITE_GUARDS map out
    # and keeping the rest was tried first and still passed a bogus WIRED claim, because the same
    # filename reappears further down in another declaration block. Whitelisting the executed arrays
    # is decidable; blacklisting prose is not.
    for path, marker in (("scripts/_test/run_fast_cages.ps1", "$FAST_SUITES"),
                         ("scripts/_test/run_contract_binding_tests.ps1", "$scripts")):
        if not src.exists_committed(path):
            continue
        body = src.read_committed(path, errors="replace")
        m = re.search(re.escape(marker) + r"\s*=\s*@\((.*?)\n\)", body, re.S)
        if m:
            text += m.group(1)
    return text


_wiring = _invocation_text()

_counts = {s: 0 for s in _STATUSES}
for _name, _body in sorted(d["$defs"].items()):
    if not isinstance(_body, dict) or not _body.get("x-enforced-by"):
        continue
    _st = _body.get("x-enforcement-status")
    _enf = _body.get("x-enforcer")
    chk(_st in _STATUSES,
        "%s declares x-enforcement-status=%r" % (_name, _st))
    if _st not in _STATUSES:
        continue
    _counts[_st] += 1
    if _st == "PLANNED":
        chk(not _enf or not src.exists_committed(_enf),
            "%s is PLANNED and names no existing enforcer (a real one would understate it)" % _name)
    else:
        chk(bool(_enf) and src.exists_committed(_enf),
            "%s is %s and its x-enforcer %r exists" % (_name, _st, _enf))
        if _st == "WIRED":
            chk(bool(_enf) and os.path.basename(_enf) in _wiring,
                "%s is WIRED and %s is actually invoked by a hook or the tier"
                % (_name, os.path.basename(_enf or "")))
print("  PLANNED=%d BUILT=%d WIRED=%d -- only WIRED means the constraint is enforced today"
      % (_counts["PLANNED"], _counts["BUILT"], _counts["WIRED"]))

print("\n=== %s ===" % ("STRUCTURE OK" if fail == 0 else "%d STRUCTURAL FAILURES" % fail))
sys.exit(1 if fail else 0)
