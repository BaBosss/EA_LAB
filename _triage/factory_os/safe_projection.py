"""
safe_projection.py - ORDER-1131 (slice S11). The ONLY document an online or Telegram surface
may read, and the scanner that proves it carries nothing it must not.

WHY THIS EXISTS
  design 7.1 says the online projection is "safe by construction: masked accounts, no
  credentials, no strategy logic, no exact lots, percentages instead of money amounts".
  The Codex blind audit measured that no construction existed - the phrase was a promise, and
  the real snapshot carries `account`, `balance`, `equity`, `floating_pl`, `margin_level`,
  per-magic `open_lots` and EA names two fields away from the sentence promising it did not.
  schemas.json answered with an ALLOWLIST-ONLY DTO. This file is that allowlist made real,
  plus the two things an allowlist alone cannot do:

    scan_forbidden()   a RECURSIVE scan - keys at any depth, values at any depth. An allowlist
                       stops a new FIELD; it does not stop an account number typed into a field
                       that is allowed. Both leaks have to be closed by different mechanisms.
    read_for_sender()  the sender boundary. design 7.1 (rev 3): "Telegram and the online page
                       read only the SafeProjection, and the sender has no path to the full
                       snapshot at all." A sentence is not a boundary; a function that refuses
                       every path except the pinned one is.

WHAT "THE SENDER HAS NO PATH" MEANS HERE, EXACTLY
  It means: the only reader this module offers refuses to open anything but PROJECTION_REL, and
  refuses a document that is not entity=SafeProjection, and re-scans what it is about to hand
  back. It does NOT mean the operating system has been stopped from opening the snapshot file -
  no python module can claim that. The claim is scoped to what is driven:
  run_s11_tests.py hands read_for_sender() the real snapshot path and requires a refusal.
  (memory: name-it-honestly-when-you-cannot-prove-it)

THREE RULES THIS FILE IS WRITTEN AGAINST, each paid for elsewhere in this repo
  1. An unreadable or UNRECOGNISED input REFUSES. It never becomes a benign default. A
     `floating_risk.state` this module does not know is a ProjectionRefusal, not `UNKNOWN` -
     "map what you do not recognise onto the safe-looking value" is how a future state that
     means BREACH renders as OK. (memory: unreadable-input-must-refuse-not-skip)
  2. An exemption is a CLOSED DECLARATION, never a rule. There is no "skip fields that look
     like timestamps" here. (memory: citation-guard-satisfied-by-a-universal-file)
  3. This module computes NO threshold. design 7.1: "Risk authority stays with the existing
     detectors. The dashboard creates no competing threshold." A drawdown band is therefore
     PASSED THROUGH from a detector or it is UNKNOWN - deriving one from `equity` and `balance`
     would be a second risk opinion wearing a dashboard's clothes. Today no detector in
     control_room_snapshot.json publishes one, so every band is UNKNOWN and the local page says
     so out loud. run_s11_tests.py drives a detector-supplied band through as well, so the
     UNKNOWN is a measurement rather than a constant.

USAGE   tools\\python312\\python.exe _triage/factory_os/safe_projection.py build
        tools\\python312\\python.exe _triage/factory_os/safe_projection.py check
TESTS   tools\\python312\\python.exe _triage/factory_os/run_s11_tests.py
"""
import hashlib
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import snapshot_validator  # noqa: E402  - the ONE reader boundary for the full snapshot

# The full snapshot is named here ONCE, and only so that build() can obtain a VERIFIED copy
# through snapshot_validator.load_verified(). read_for_sender() does not use it: see
# SENDER_ALLOWED_PATHS below, which is the closed declaration that boundary is built from.
SNAPSHOT_REL = 'portfolio/control_room_snapshot.json'
PROJECTION_REL = 'build/safe_projection.json'

ENTITY = 'SafeProjection'

# A stable salt, NOT a secret and not sold as one. Its job is opacity, not resistance: it keeps
# the internal finding id - which may embed an account, a magic or an EA name - off the wire,
# while keeping the public id STABLE across builds, which design 7.3 requires so Telegram dedupe
# and the dashboard can be pinned to the same ids. A per-build salt would break that; a longer
# salt would not make a 6-digit magic un-guessable. Say what it does and no more.
PUBLIC_ID_SALT = 'ea-lab-safe-projection-v1'


class ProjectionRefusal(Exception):
    """The projection could not be built, or the document handed over is not one."""


class ProjectionLeak(ProjectionRefusal):
    """The scan found something that must never reach an online or Telegram surface."""


def _refuse(msg):
    raise ProjectionRefusal(msg)


# ---------------------------------------------------------------------------------------
# The closed maps. Every one of them refuses an unrecognised input rather than defaulting it.
# ---------------------------------------------------------------------------------------

# system_health[].state -> SafeProjection.accounts[].sensor_state. Identity for the states the
# snapshot builder can emit; the schema's enum is the closed target vocabulary.
SENSOR_STATE_MAP = {
    'FRESH': 'FRESH',
    'STALE': 'STALE',
    'BLIND': 'BLIND',
    'MISSING': 'MISSING',
    'NO_SENSOR': 'MISSING',
    'UNKNOWN': 'UNKNOWN',
}

# A detector-supplied drawdown BAND, passed through. There is deliberately no arithmetic here.
DD_BAND_MAP = {
    'OK': 'OK',
    'WATCH': 'WATCH',
    'BREACH': 'BREACH',
    'UNKNOWN': 'UNKNOWN',
}

# snapshot verdict reason code -> the severity the projection publishes. This is a ROUTING
# table, not a threshold: every code below is already a refusal the validator computed, and this
# map only says how loudly it travels. A code that is not here REFUSES the build - a new reason
# code that silently routed as INFO is exactly the escalation-swallowing shape design 7.3
# rejects for the dedupe key.
REASON_SEVERITY = {
    'MANDATORY_SOURCE_MISSING': 'CRITICAL',
    'MANDATORY_SOURCE_UNREADABLE': 'CRITICAL',
    'MANDATORY_SOURCE_STALE': 'WARN',
    'SOURCE_REGISTRY_MISMATCH': 'WARN',
    'DUPLICATE_SOURCE_NAME': 'WARN',
    'SOURCE_MANDATORY_FLAG_CONTRADICTS_REGISTRY': 'WARN',
    'DISCOVERED_CATEGORIZED_MISMATCH': 'WARN',
    'CATEGORY_SUM_MISMATCH': 'WARN',
    'COVERAGE_SUM_MISMATCH': 'WARN',
    'DUPLICATES_PRESENT': 'INFO',
    'CONFLICTS_PRESENT': 'WARN',
    'UNCLASSIFIED_PRESENT': 'WARN',
    'ACTIONABLE_PRESENT': 'INFO',
}


# ---------------------------------------------------------------------------------------
# The scan. Recursive on purpose, and the recursion is what run_s11_tests.py drives: a
# top-level-only scan passes a document whose account number is three levels down, which is
# the exact attack the acceptance names.
# ---------------------------------------------------------------------------------------

# Keys that may never appear at ANY depth of a projected document. Matched EXACTLY, never as a
# substring: `account_masked` is the field the schema requires, and a substring rule would make
# the safe field indistinguishable from the unsafe one it replaces.
FORBIDDEN_KEYS = {
    'account': 'the raw account number is the thing masking exists to remove',
    'account_name': 'names the broker account',
    'accounts_total': 'a fleet size is not in the allowlist; it is here to keep the map closed',
    'balance': 'money amount',
    'equity': 'money amount',
    'floating_pl': 'money amount',
    'margin_level': 'a margin level plus a known deposit reconstructs the money',
    'open_lots': 'exact lot size',
    'lots': 'exact lot size',
    'volume': 'exact lot size',
    'magic': 'a magic identifies a strategy on an account',
    'magics': 'a magic identifies a strategy on an account',
    'ea': 'strategy identity',
    'ea_name': 'strategy identity',
    'symbol': 'strategy identity',
    'symbols': 'strategy identity',
    'set': 'a .set name leaks the configuration',
    'ex5': 'a binary name leaks the strategy',
    'host': 'infrastructure identity',
    'latest_file': 'a local path leaks the machine layout',
    'path': 'a local path leaks the machine layout',
    'finding_id': 'the internal id may embed an account, a magic or a strategy name',
    'token': 'credential',
    'bot_token': 'credential',
    'api_key': 'credential',
    'apikey': 'credential',
    'password': 'credential',
    'secret': 'credential',
    'chat_id': 'a chat id is a delivery credential',
}

# Value shapes that are a leak wherever they appear. Deliberately NOT a bare long-digit rule:
# `build_id` and `generated_at` legitimately carry long digit runs, and a rule that had to be
# exempted for them would be an exemption large enough to hide an account. Raw account numbers
# are caught by the known-secret layer below instead, which cannot false-positive.
FORBIDDEN_VALUE_RULES = (
    ('TELEGRAM_BOT_TOKEN', re.compile(r'\d{6,}:[A-Za-z0-9_\-]{30,}'),
     'a Telegram bot token'),
    ('WINDOWS_ABSOLUTE_PATH', re.compile(r'(?i)[a-z]:[\\/]'),
     'a local filesystem path'),
    ('UNC_PATH', re.compile(r'\\\\[A-Za-z0-9._-]+\\'),
     'a network path'),
    ('PEM_BLOCK', re.compile(r'-----BEGIN [A-Z ]*(KEY|CERTIFICATE)'),
     'an embedded key or certificate'),
    ('CREDENTIAL_ASSIGNMENT', re.compile(r'(?i)\b(api[_-]?key|password|secret|bearer)\b\s*[:=]'),
     'a credential written into a value'),
)


def _walk(node, path='$'):
    """Yield (path, key_or_None, value) for every node, at every depth. Keys AND leaves."""
    if isinstance(node, dict):
        for k in node:
            child = '%s.%s' % (path, k)
            yield child, k, node[k]
            for item in _walk(node[k], child):
                yield item
    elif isinstance(node, (list, tuple)):
        for i, v in enumerate(node):
            child = '%s[%d]' % (path, i)
            yield child, None, v
            for item in _walk(v, child):
                yield item


def scan_forbidden(doc, known_secrets=()):
    """
    Return a list of (path, rule, detail) - EVERY hit, not the first.

    Three layers, because each catches what the others cannot:
      FORBIDDEN_KEY     a field that must not exist at any depth.
      KNOWN_SECRET      a literal that came out of the source snapshot (an account number, an
                        EA name, a planted test token). This is the layer that catches an
                        account number typed into a field the allowlist permits, and it cannot
                        false-positive on a timestamp because it only looks for values that
                        actually are secrets in this document.
      VALUE_SHAPE       a shape that is a leak wherever it appears.

    Reporting every hit rather than raising on the first is deliberate: a fixture that plants
    three leaks and is told about one teaches the author to fix one.
    """
    hits = []
    secrets = [str(s) for s in known_secrets if str(s) != '']
    for path, key, value in _walk(doc):
        if key is not None and key in FORBIDDEN_KEYS:
            hits.append((path, 'FORBIDDEN_KEY', '%s: %s' % (key, FORBIDDEN_KEYS[key])))
        if isinstance(value, (dict, list, tuple)):
            continue
        if value is None or isinstance(value, bool):
            continue
        text = value if isinstance(value, str) else repr(value)
        for secret in secrets:
            if secret in text:
                hits.append((path, 'KNOWN_SECRET',
                             'carries a literal taken from the full snapshot: %s' % secret))
        for name, rx, why in FORBIDDEN_VALUE_RULES:
            if rx.search(text):
                hits.append((path, name, why))
    return hits


def assert_safe(doc, known_secrets=()):
    """Raise ProjectionLeak naming every hit. The scan is useless if callers may ignore it."""
    hits = scan_forbidden(doc, known_secrets)
    if hits:
        raise ProjectionLeak(
            'the projection carries %d forbidden item(s): %s'
            % (len(hits), '; '.join('%s [%s] %s' % h for h in hits)))
    return doc


def secrets_of(snapshot):
    """
    Every literal in the full snapshot that must never reach the projection, as strings.

    This is what makes the KNOWN_SECRET layer a measurement instead of a guess: the list is
    read out of the document being projected, so a fixture that plants a secret automatically
    plants the thing the scan looks for.
    """
    out = set()

    def add(v):
        if v is None or isinstance(v, bool):
            return
        s = str(v)
        # One-character and two-character literals are not secrets; they are substrings of
        # everything and would make the scan fire on its own output.
        if len(s) >= 4:
            out.add(s)

    for row in snapshot.get('system_health', []) or []:
        add(row.get('account'))
        add(row.get('latest_file'))
    for row in snapshot.get('floating_risk', []) or []:
        add(row.get('account'))
        for m in ('balance', 'equity', 'floating_pl', 'margin_level'):
            add(row.get(m))
        for mg in row.get('magics', []) or []:
            add(mg.get('magic'))
            add(mg.get('open_lots'))
    for row in (snapshot.get('deployments', {}) or {}).get('rows', []) or []:
        for k in ('account', 'account_name', 'ea_name', 'magic', 'symbol', 'host'):
            add(row.get(k))
    for row in snapshot.get('attestation', []) or []:
        for k in ('account', 'ea', 'magic', 'set', 'ex5'):
            add(row.get(k))
    for row in snapshot.get('judge_readiness', []) or []:
        for k in ('account', 'ea', 'magic', 'symbol'):
            add(row.get(k))
    for row in snapshot.get('unknown_magics', []) or []:
        add(row.get('account'))
        add(row.get('magic'))
    return sorted(out)


# ---------------------------------------------------------------------------------------
# The build. ALLOWLIST-ONLY: every field of the output is written by a line below, so a field
# added to the snapshot cannot appear here by being copied.
# ---------------------------------------------------------------------------------------

def mask_account(account):
    """`***123` - the last three digits and nothing else. Refuses anything it cannot mask."""
    if account is None:
        _refuse('an account row carries no account, so it cannot be masked '
                '(an unmaskable account is a refusal, never an omitted row)')
    digits = re.sub(r'\D', '', str(account))
    if len(digits) < 3:
        _refuse('account %r has fewer than three digits, so `***NNN` cannot be produced' % account)
    return '***' + digits[-3:]


def public_id(internal_id):
    """`FP-` + 10 hex, stable across builds. See PUBLIC_ID_SALT for what this does and does not."""
    if internal_id is None or str(internal_id) == '':
        _refuse('a finding with no internal id cannot be given a stable public id')
    digest = hashlib.sha256((PUBLIC_ID_SALT + '|' + str(internal_id)).encode('utf-8')).hexdigest()
    return 'FP-' + digest[:10]


def _mapped(table, value, what, where):
    if value in table:
        return table[value]
    _refuse('%s %r at %s is not in this module\'s closed %s map. Refusing rather than '
            'defaulting it: an unrecognised state mapped onto a safe-looking value is how a '
            'future state that means BREACH renders as OK.' % (what, value, where, what))


def build(snapshot):
    """
    SafeProjection from a VERIFIED ControlRoomSnapshotV5. Never from an unverified one -
    callers get the document from snapshot_validator.load_verified().
    """
    if not isinstance(snapshot, dict):
        _refuse('the snapshot is %s, not an object' % type(snapshot).__name__)
    if snapshot.get('entity') != snapshot_validator.OUTPUT_ENTITY:
        _refuse('build() was handed entity=%r, not %s'
                % (snapshot.get('entity'), snapshot_validator.OUTPUT_ENTITY))
    meta = snapshot.get('meta') or {}

    # accounts: sensor state from the health detector, drawdown band from a detector that
    # publishes one. Joined on account so a health row and a risk row for one account produce
    # ONE projected row.
    bands = {}
    for row in snapshot.get('floating_risk', []) or []:
        acct = row.get('account')
        if 'dd_band' in row:
            bands[acct] = _mapped(DD_BAND_MAP, row.get('dd_band'), 'dd_band',
                                  'floating_risk[%s]' % acct)

    # ROUND-1 BLOCKER FIX. This walked system_health ALONE and joined the rest onto it, so an
    # account the health detector had never seen was absent from the masked list entirely -
    # not UNKNOWN, ABSENT. The probe used an account with a BLIND sensor and 9.9 open lots and
    # it produced no row at all, on either surface. The account set is now the UNION of every
    # detector that speaks about accounts, and a detector that is silent about one produces
    # UNKNOWN rather than an omission. (memory: instrument-what-the-guard-actually-reads)
    health = {}
    for row in snapshot.get('system_health', []) or []:
        health[row.get('account')] = row
    order = []
    for source in ('system_health', 'floating_risk'):
        for row in snapshot.get(source, []) or []:
            if row.get('account') not in order:
                order.append(row.get('account'))
    accounts = []
    for acct in order:
        row = health.get(acct)
        accounts.append({
            'account_masked': mask_account(acct),
            'sensor_state': (_mapped(SENSOR_STATE_MAP, row.get('state'), 'sensor_state',
                                     'system_health[%s]' % acct)
                             if row is not None else 'UNKNOWN'),
            # No detector in this document publishes a drawdown band today, so this is UNKNOWN
            # for every account - and it is UNKNOWN by MEASUREMENT (the dict lookup above),
            # not by a constant, which is why a supplied band travels.
            'dd_pct_band': bands.get(acct, 'UNKNOWN'),
        })

    # findings: the verdict's own refusal reasons, as opaque public ids. The internal id is
    # built from the code and detail and then hashed away; the detail itself never travels,
    # because a detail like `attestation_map` is fine and a detail carrying an account is not,
    # and the projection is not the place to start telling those apart.
    findings = []
    for reason in (snapshot.get('verdict') or {}).get('reasons', []) or []:
        code = reason.get('code')
        severity = _mapped(REASON_SEVERITY, code, 'reason code', 'verdict.reasons')
        findings.append({
            'public_id': public_id('%s|%s' % (code, reason.get('detail'))),
            'severity': severity,
            'state': 'OPEN',
        })

    projection = {
        'entity': ENTITY,
        'build_id': str(meta.get('build_id') or ''),
        'generated_at': str(meta.get('generated_at') or ''),
        'accounts': accounts,
        'findings': findings,
    }
    # Scan our own output before anybody sees it. The allowlist above should make this
    # impossible to fail - which is the point: if it ever fails, the allowlist was edited.
    return assert_safe(projection, secrets_of(snapshot))


# ---------------------------------------------------------------------------------------
# The sender boundary.
# ---------------------------------------------------------------------------------------

# CLOSED DECLARATION, and the whole boundary. Not a prefix rule, not a directory rule: a
# one-element set of the repo-relative paths a sender may read. Widening it is an edit here.
SENDER_ALLOWED_PATHS = (PROJECTION_REL,)


def _rel(path, repo_root):
    try:
        rel = os.path.relpath(os.path.abspath(path), os.path.abspath(repo_root))
    except ValueError:
        return None
    return rel.replace('\\', '/')


def _schema_of(entity, repo_root='.'):
    """The declared shape, READ FROM schemas.json. Never a hand-copied mirror of it."""
    path = os.path.join(repo_root, snapshot_validator.SCHEMA_PATH)
    try:
        with io.open(path, 'r', encoding='utf-8-sig') as fh:
            schema = json.load(fh)
    except (IOError, OSError, ValueError) as exc:
        # The instrument, not the document. A sender that cannot check the shape sends nothing.
        _refuse('the shape of %s could not be read from %s, so nothing can be checked against '
                'it: %s' % (entity, path, exc))
    try:
        return schema['$defs'][entity]
    except KeyError:
        _refuse('%s is not declared in %s' % (entity, path))


def _check_shape(node, schema, path, hits):
    """
    ALLOWLIST structural check against the schema's own declaration. Not a blacklist.

    FOUND BY THE CAGE (case SB03, red on the first run): read_for_sender used to hand back
    anything that carried entity=SafeProjection and survived scan_forbidden(). That scan cannot
    see a raw account number on the sender's side, BECAUSE THE SENDER HAS NO SNAPSHOT to derive
    the known-secret list from - which is the prohibition working exactly as designed and
    disarming the check at the same time. Adding `source_account` to FORBIDDEN_KEYS would have
    made that one fixture pass and taught nothing: a blacklist of field names has no end.
    The shape is the thing that can be closed, so the shape is what is checked.
    """
    if 'const' in schema:
        if node != schema['const']:
            hits.append((path, 'SHAPE', 'must be %r' % (schema['const'],)))
        return
    if 'enum' in schema:
        if node not in schema['enum']:
            hits.append((path, 'SHAPE', 'must be one of %s' % (schema['enum'],)))
        return
    stype = schema.get('type')
    if stype == 'array':
        if not isinstance(node, list):
            hits.append((path, 'SHAPE', 'must be an array'))
            return
        for i, item in enumerate(node):
            _check_shape(item, schema.get('items', {}), '%s[%d]' % (path, i), hits)
        return
    if stype == 'object' or 'properties' in schema:
        if not isinstance(node, dict):
            hits.append((path, 'SHAPE', 'must be an object'))
            return
        props = schema.get('properties', {})
        for key in schema.get('required', []):
            if key not in node:
                hits.append(('%s.%s' % (path, key), 'SHAPE', 'is required and missing'))
        closed = schema.get('unevaluatedProperties') is False or \
            schema.get('additionalProperties') is False
        for key in node:
            if key in props:
                _check_shape(node[key], props[key], '%s.%s' % (path, key), hits)
            elif closed:
                hits.append(('%s.%s' % (path, key), 'SHAPE',
                             'is not declared, and this object is closed - an undeclared field '
                             'is exactly where a nested account number travels'))
        return
    if stype == 'string':
        if not isinstance(node, str):
            hits.append((path, 'SHAPE', 'must be a string'))
            return
        pattern = schema.get('pattern')
        if pattern and not re.match(pattern, node):
            hits.append((path, 'SHAPE', 'does not match %s' % pattern))
        return
    # ROUND-3 FIX. Everything above is a construct this checker implements; anything else used
    # to fall off the end and produce NO HITS -- `type: integer`, `type: boolean`, `$ref` and
    # `oneOf` were all silently accepted, whatever the value was. SafeProjection's schema uses
    # none of them TODAY, which is precisely why nobody would have noticed: the first field
    # added with an integer type would have been unchecked, inside the function whose entire
    # job is checking. An unimplemented construct is now a REFUSAL naming itself, so extending
    # the schema forces extending the checker instead of quietly losing coverage.
    hits.append((path, 'SHAPE_UNCHECKED',
                 'this checker does not implement the schema construct %r, so it cannot verify '
                 'this node - refusing rather than passing it'
                 % sorted(k for k in schema if not k.startswith('x-') and k != 'description')))


def assert_shape(doc, repo_root='.'):
    """Raise ProjectionLeak unless `doc` is exactly the shape schemas.json declares."""
    hits = []
    _check_shape(doc, _schema_of(ENTITY, repo_root), '$', hits)
    if hits:
        raise ProjectionLeak(
            'the document is not the declared %s shape (%d problem(s)): %s'
            % (ENTITY, len(hits), '; '.join('%s [%s] %s' % h for h in hits)))
    return doc


def read_for_sender(path, repo_root='.'):
    """
    The ONLY reader offered to a notification sender. Refuses:
      - any path that is not SENDER_ALLOWED_PATHS (so the full snapshot is refused by PATH,
        before its bytes are opened),
      - a document that is not entity=SafeProjection,
      - a document that is not the declared SHAPE (the allowlist - see _check_shape),
      - a document that does not survive the scan (defence in depth, on top of the shape).
    """
    rel = _rel(path, repo_root)
    if rel not in SENDER_ALLOWED_PATHS:
        _refuse('a sender may read only %s; %r is refused. This is the design 7.1 prohibition '
                '("the sender has no path to the full snapshot") as a code path rather than a '
                'sentence.' % (', '.join(SENDER_ALLOWED_PATHS), rel if rel else path))
    if not os.path.exists(path):
        _refuse('no projection at %s - the sender has nothing to send, which is a refusal and '
                'not an empty message' % path)
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        try:
            doc = json.load(fh)
        except ValueError as exc:
            _refuse('the projection at %s does not parse: %s' % (path, exc))
    if not isinstance(doc, dict) or doc.get('entity') != ENTITY:
        _refuse('the document at %s is not a %s (entity=%r)'
                % (path, ENTITY, doc.get('entity') if isinstance(doc, dict) else None))
    assert_shape(doc, repo_root)
    return assert_safe(doc)


# ---------------------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------------------

def _load_snapshot(repo_root):
    return snapshot_validator.load_verified(os.path.join(repo_root, SNAPSHOT_REL))


def main(argv):
    if len(argv) < 2 or argv[1] not in ('build', 'check'):
        sys.stderr.write('usage: safe_projection.py build|check [--repo-root DIR]\n')
        return 2
    repo_root = '.'
    if '--repo-root' in argv:
        repo_root = argv[argv.index('--repo-root') + 1]
    try:
        snapshot = _load_snapshot(repo_root)
    except Exception as exc:                                   # noqa: BLE001 - reported, not swallowed
        sys.stderr.write('the full snapshot could not be verified, so no projection was built: '
                         '%s: %s\n' % (type(exc).__name__, exc))
        return 3
    try:
        projection = build(snapshot)
    except ProjectionRefusal as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 1
    out = os.path.join(repo_root, PROJECTION_REL)
    if argv[1] == 'check':
        if not os.path.exists(out):
            sys.stderr.write('no projection at %s (run `build`)\n' % out)
            return 1
        with io.open(out, 'r', encoding='utf-8-sig') as fh:
            on_disk = json.load(fh)
        if on_disk != projection:
            sys.stderr.write('the projection on disk is not what this snapshot produces\n')
            return 1
        print('safe_projection: %s matches the snapshot (%d account(s), %d finding(s))'
              % (PROJECTION_REL, len(projection['accounts']), len(projection['findings'])))
        return 0
    d = os.path.dirname(out)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(json.dumps(projection, indent=2, sort_keys=True, ensure_ascii=False))
        fh.write('\n')
    print('safe_projection: wrote %s (%d account(s), %d finding(s))'
          % (PROJECTION_REL, len(projection['accounts']), len(projection['findings'])))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
