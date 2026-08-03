# -*- coding: utf-8 -*-
"""ORDER-1100 (slice S10) -- Candidate identity. design 4.5, design 10's S10 row.

THE ONE ACCEPTANCE THIS FILE OWNS
  `candidate_digest` is RECOMPUTED AND COMPARED ON EVERY READ, and the payload it is computed
  over does not contain it.

WHY THE PAYLOAD MUST NOT CONTAIN THE ID (design 4.5, rev 1's mistake, stated so it cannot recur)
  Rev 1 required `candidate_id` inside the object whose hash the id was defined to be. That has no
  normal construction -- you cannot hash an object that contains its own hash -- so the only way
  to ship it is to stop checking, and a check that was disabled to make the writer work is
  indistinguishable from no check at all. Here the payload is a CLOSED set of fifteen fields, the
  id fields are refused INSIDE it by name, and the manifest carries them outside.

WHY THERE IS NO SECOND SERIALIZER
  design 4.5 leaves `candidate_digest`'s canonical form owed and names the cost in the same
  sentence: "two serializers that disagree produce two digests for one candidate". S9 already
  earned an answer to that -- `scheduler.canonical()` plus the numeric normalization a probe
  forced into existence when `10000` and `10000.0` produced two ExecutionKey digests for one
  deposit. This module IMPORTS both. It does not define a serialization of its own, and
  `run_s10_tests.py` asserts that the digest changes when the imported one changes, so the
  dependency is measured rather than declared.

  The one thing that IS this module's own is the FIELD SELECTION, because a digest over a shape
  that is not the contract is a digest of something else -- the same argument
  `execution_key_digest` makes for its fifteen fields, one level along.

WHAT THIS FILE DELIBERATELY DOES NOT DO
  It does not write verdicts. The verdict TEXT lives in `EA_SCORECARD_AND_REGISTRY.md` and the
  manifest carries an `OwnerRef` to it, never a copy (CONTRACTS.md says so on the field). It does
  not read the scorecard, the taskboard or DEPLOYMENTS.csv. Everything except the two functions in
  the DISK section is PURE and is driven by the cage with no filesystem at all.

USAGE  tools\\python312\\python.exe _triage/factory_os/candidate.py <command> [args]
       commands: digest | read | --self-test
EXIT   0 = ok  -  1 = a REFUSAL (the reasons are on stdout as JSON)  -  2 = unreadable input
"""

import hashlib
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scheduler as S                                                      # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
CANDIDATES_DIR_REL = 'factory/candidates'

# THE CONTRACT'S SHAPE, not this module's. `assert_vocabulary_matches_schema()` re-reads
# schemas.json and the cage calls it, for the reason scheduler.py states: a writer with a private
# field list produces a manifest its own validator rejects, at the moment it is needed most.
PAYLOAD_FIELDS = ('hypothesis_revision', 'module_set', 'experimental', 'logical_symbol', 'tf',
                  'parameters', 'profiles', 'evidence', 'ex5_sha256', 'source_sha256',
                  'allowlist_sha256', 'generator_version', 'effective_config_hash',
                  'universe_version', 'trial_count')
MANIFEST_FIELDS = ('entity', 'candidate_id', 'candidate_digest', 'payload', 'scorecard_ref')
PROFILE_KEYS = ('instrument', 'exit', 'sizing', 'safety', 'execution')
HEX64_PAYLOAD_FIELDS = ('ex5_sha256', 'source_sha256', 'allowlist_sha256', 'effective_config_hash')
# ORDER-1250: `pf_state` joined MetricRef's required set when `pf` became nullable. This list is
# held to schemas.json by run_s10_tests ("candidate's vocabulary IS schemas.json's, re-read from
# the file"), which is what caught the omission the moment the schema moved -- exactly the drift
# the comment above this block exists to prevent.
METRIC_FIELDS = ('window', 'pf', 'pf_state', 'trades', 'dd_pct', 'run_id', 'lane',
                 'data_fingerprint', 'model')
MODULE_FIELDS = ('token', 'module_version', 'stability')
OWNER_REF_FIELDS = ('entity', 'owner_type', 'path', 'commit_oid', 'blob_oid', 'raw_sha256')
WINDOWS = ('MAIN', 'BWD', 'HOLDOUT', 'OTHER')
STABILITIES = ('EXPERIMENTAL', 'CERTIFIABLE')
MODELS = (1, 2, 4)

# The id fields, named here so the construction rule is a LIST the code reads rather than a
# sentence the reader is trusted to remember.
ID_FIELDS = ('candidate_id', 'candidate_digest')

HEX64_RE = re.compile(r'^[0-9a-f]{64}$')
HEX40_RE = re.compile(r'^[0-9a-f]{40}$')
CAND_ID_RE = re.compile(r'^CAND-[0-9a-f]{12}$')
MODULE_TOKEN_RE = re.compile(r'^LAB_CAP_[A-Z0-9_]+$')

# DISPLAY LENGTH. CONTRACTS.md: "DISPLAY id = first 12 hex of candidate_digest. Never the hash
# input." The second half of that sentence is what `C2` below enforces.
ID_HEX_LEN = 12


class DigestMismatch(Exception):
    """Raised by `read_manifest`. A TYPE, not a return code, because the acceptance is that a
    tampered manifest cannot be read -- and a caller that ignores a return value would read one."""


# ---------------------------------------------------------------------------------------------
# IDENTITY
# ---------------------------------------------------------------------------------------------
def canonical_payload(payload):
    """The bytes the digest is taken over. Refuses any shape that is not the contract.

    Both directions are refused on purpose. A MISSING field would let two candidates that differ
    only in the field nobody supplied share a digest; an UNKNOWN field would let a candidate carry
    information the digest does not cover, which is the same hole facing the other way.
    """
    if not isinstance(payload, dict):
        raise ValueError('CandidatePayload must be an object, got %s' % type(payload).__name__)
    inside = [f for f in ID_FIELDS if f in payload]
    if inside:
        # THE RULE THAT KEEPS THE CHECK ALIVE. See the module docstring: rev 1 put the id inside
        # the hashed object, which has no construction, and the only way to ship that is to stop
        # comparing. Refusing it here means the impossible object cannot be built in the first
        # place.
        raise ValueError('CandidatePayload carries %s -- the payload is the INPUT to the digest '
                         'and cannot contain it (design 4.5). Those fields belong on the manifest.'
                         % sorted(inside))
    missing = [f for f in PAYLOAD_FIELDS if f not in payload]
    extra = [f for f in payload if f not in PAYLOAD_FIELDS]
    if missing or extra:
        raise ValueError('CandidatePayload missing %s / unknown %s -- a digest over a payload '
                         'whose shape is not the contract is a digest of something else'
                         % (sorted(missing), sorted(extra)))
    ordered = dict((f, payload[f]) for f in PAYLOAD_FIELDS)
    return S.canonical(S.normalize_numbers(ordered))


def candidate_digest(payload):
    """sha256 over `canonical_payload`. The full 64 hex; the id is a display prefix of it."""
    return hashlib.sha256(canonical_payload(payload).encode('utf-8')).hexdigest()


def candidate_id_for(digest):
    if not HEX64_RE.match(str(digest)):
        raise ValueError('%r is not a sha256 digest' % (digest,))
    return 'CAND-' + digest[:ID_HEX_LEN]


# ---------------------------------------------------------------------------------------------
# THE VALIDATOR. Criterion ids C1-C9 so the cage can be checked for naming each one -- the L2
# idea applied to a module L2 does not reach (it globs `check_*.py`).
# ---------------------------------------------------------------------------------------------
def owner_ref_problems(ref, where):
    """PUBLIC because `attestation.py` validates the same object for the same reason -- an
    authorization ref that is not a real OwnerRef is a citation, and one implementation of that
    rule is the difference between two guards and two opinions."""
    problems = []
    if not isinstance(ref, dict):
        return ['%s must be an OwnerRef object, got %s' % (where, type(ref).__name__)]
    missing = [f for f in OWNER_REF_FIELDS if f not in ref]
    extra = [f for f in ref if f not in OWNER_REF_FIELDS + ('anchor',)]
    if missing or extra:
        problems.append('%s missing %s / unknown %s' % (where, sorted(missing), sorted(extra)))
        return problems
    if ref['entity'] != 'OwnerRef':
        problems.append('%s entity must be OwnerRef, got %r' % (where, ref['entity']))
    for f in ('commit_oid', 'blob_oid'):
        if not HEX40_RE.match(str(ref[f])):
            problems.append('%s %s %r is not a 40-hex oid' % (where, f, ref[f]))
    if not HEX64_RE.match(str(ref['raw_sha256'])):
        problems.append('%s raw_sha256 %r is not a sha256' % (where, ref['raw_sha256']))
    return problems


def validate_payload(payload):
    """Shape rules that live BELOW the digest: the digest proves the payload has not changed, it
    proves nothing about whether the payload was ever right."""
    problems = []
    try:
        canonical_payload(payload)
    except ValueError as exc:
        return ['C1 %s' % exc]

    # -- C3 module_set. `experimental` and stability are one rule read from two sides, and
    #    schemas.json states the promotion-path half on the field itself.
    mods = payload['module_set']
    if not isinstance(mods, list) or not mods:
        problems.append('C3 module_set must be a non-empty array')
    else:
        for i, m in enumerate(mods):
            if not isinstance(m, dict) or sorted(m) != sorted(MODULE_FIELDS):
                problems.append('C3 module_set[%d] is not a ModuleUse (%s)' % (i, MODULE_FIELDS))
                continue
            if not MODULE_TOKEN_RE.match(str(m['token'])):
                problems.append('C3 module_set[%d] token %r does not match %s'
                                % (i, m['token'], MODULE_TOKEN_RE.pattern))
            if m['stability'] not in STABILITIES:
                problems.append('C3 module_set[%d] stability %r is not one of %s'
                                % (i, m['stability'], list(STABILITIES)))

    # -- C4 the promotion-path rule, both halves. schemas.json: "MUST be false for any candidate on
    #    a promotion path; the validator additionally resolves every evidence -> run -> module set
    #    and fails if any module is not CERTIFIABLE". A candidate that declares itself
    #    non-experimental while standing on an EXPERIMENTAL module is claiming a certification its
    #    own parts do not have -- and `capability.py` records why that default is never granted by
    #    omission.
    if payload['experimental'] is not False:
        problems.append('C4 experimental is %r -- a CandidateManifest is written at verdict time '
                        'and only a non-experimental candidate has a promotion path'
                        % (payload['experimental'],))
    elif isinstance(mods, list):
        weak = [m.get('token') for m in mods
                if isinstance(m, dict) and m.get('stability') != 'CERTIFIABLE']
        if weak:
            problems.append('C4 experimental=false but %s is/are not CERTIFIABLE -- the candidate '
                            'claims a certification its own module set does not hold' % sorted(weak))

    # -- C5 profiles are CONTENT HASHES, closed. design 4.6's rationale on the field: mutable
    #    string ids would let instrument_profiles change under a fixed id while the candidate
    #    still looked valid.
    prof = payload['profiles']
    if not isinstance(prof, dict) or sorted(prof) != sorted(PROFILE_KEYS):
        problems.append('C5 profiles must be exactly %s' % list(PROFILE_KEYS))
    else:
        for k in PROFILE_KEYS:
            if not HEX64_RE.match(str(prof[k])):
                problems.append('C5 profiles.%s %r is not a content hash' % (k, prof[k]))

    # -- C6 evidence. One MetricRef per window, each carrying its OWN lane and fingerprint. design
    #    4.4: rev 1 put one lane beside MAIN and BWD together, which would have let a MAIN from
    #    lane 5c and a BWD from lane 1 render as a same-lane pair.
    ev = payload['evidence']
    if not isinstance(ev, list) or not ev:
        problems.append('C6 evidence must be a non-empty array of MetricRef')
    else:
        for i, m in enumerate(ev):
            if not isinstance(m, dict) or sorted(m) != sorted(METRIC_FIELDS):
                problems.append('C6 evidence[%d] is not a MetricRef (%s)' % (i, METRIC_FIELDS))
                continue
            if m['window'] not in WINDOWS:
                problems.append('C6 evidence[%d] window %r is not one of %s'
                                % (i, m['window'], list(WINDOWS)))
            if m['model'] not in MODELS:
                problems.append('C6 evidence[%d] model %r is not one of %s'
                                % (i, m['model'], list(MODELS)))
            if not isinstance(m['trades'], int) or isinstance(m['trades'], bool) or m['trades'] < 0:
                problems.append('C6 evidence[%d] trades %r is not an integer >= 0'
                                % (i, m['trades']))
            if not S.RUN_ID_RE.match(str(m['run_id'])):
                problems.append('C6 evidence[%d] run_id %r does not match %s -- a metric that '
                                'names no run cannot be resolved to the modules that produced it'
                                % (i, m['run_id'], S.RUN_ID_RE.pattern))
            if not str(m['lane'] or '').strip():
                problems.append('C6 evidence[%d] records no lane. ORDER-371: numbers do not '
                                'transfer across installs, so a metric without its lane is a '
                                'number about nothing.' % i)

    # -- C7 the remaining content hashes and the counter.
    for f in HEX64_PAYLOAD_FIELDS:
        if not HEX64_RE.match(str(payload[f])):
            problems.append('C7 %s %r is not a sha256' % (f, payload[f]))
    if not isinstance(payload['trial_count'], int) or isinstance(payload['trial_count'], bool) \
            or payload['trial_count'] < 0:
        problems.append('C7 trial_count %r is not an integer >= 0 -- it is how many configurations '
                        'were tried before this one, and an absent count reads as one'
                        % (payload['trial_count'],))
    if not isinstance(payload['parameters'], dict) or not payload['parameters']:
        problems.append('C7 parameters must be the FULL effective surface. A partial set lets '
                        'unlisted inputs be filled from the per-terminal tester cache -- the '
                        'documented root cause of the ORDER-165 8/8 false drift.')
    return problems


def validate_manifest(manifest, run_lookup=None):
    """Every problem with `manifest`. Empty list = a manifest that may be read.

    `run_lookup` is INJECTED rather than read from disk so this function stays pure: the cage
    drives it with a dict and the CLI passes `scheduler.load_all_runs`. When it is None the
    resolution criterion (C9) is SKIPPED and says so -- a check that silently passes when its
    input is absent is the shape memory `guard-disarmed-by-prose-reported-as-note` is about, so
    the skip is a returned note, not a silent pass.
    """
    problems = []
    if not isinstance(manifest, dict):
        return ['C1 CandidateManifest must be an object, got %s' % type(manifest).__name__]

    # -- C1 the manifest's own shape.
    missing = [f for f in MANIFEST_FIELDS if f not in manifest]
    extra = [f for f in manifest if f not in MANIFEST_FIELDS]
    if missing or extra:
        problems.append('C1 CandidateManifest missing %s / unknown %s'
                        % (sorted(missing), sorted(extra)))
        return problems
    if manifest['entity'] != 'CandidateManifest':
        problems.append('C1 entity must be CandidateManifest, got %r' % manifest['entity'])
    if not CAND_ID_RE.match(str(manifest['candidate_id'])):
        problems.append('C1 candidate_id %r does not match %s'
                        % (manifest['candidate_id'], CAND_ID_RE.pattern))
    if not HEX64_RE.match(str(manifest['candidate_digest'])):
        problems.append('C1 candidate_digest %r is not a sha256' % manifest['candidate_digest'])
    problems.extend('C1 %s' % p for p in owner_ref_problems(manifest['scorecard_ref'],
                                                             'scorecard_ref'))

    # -- C2 THE ACCEPTANCE: recompute and compare. Everything else in this file exists so that
    #    this line has something well-defined to compare.
    try:
        recomputed = candidate_digest(manifest['payload'])
    except ValueError as exc:
        problems.append('C2 the payload cannot be canonicalized, so no digest can be recomputed '
                        'for it: %s' % exc)
        recomputed = None
    if recomputed is not None:
        if recomputed != manifest['candidate_digest']:
            problems.append('C2 candidate_digest is %s but the payload hashes to %s -- the stored '
                            'digest describes bytes this manifest no longer holds'
                            % (manifest['candidate_digest'][:12], recomputed[:12]))
        # -- C8 the display id is derived, never independent. Two fields that can disagree are two
        #    identities; the id is checked against the DIGEST rather than against the payload so a
        #    single edit cannot satisfy both.
        elif manifest['candidate_id'] != candidate_id_for(recomputed):
            problems.append('C8 candidate_id %s is not the first %d hex of the digest (%s)'
                            % (manifest['candidate_id'], ID_HEX_LEN,
                               candidate_id_for(recomputed)))

    problems.extend(validate_payload(manifest['payload']))

    # -- C9 resolve every metric to the run that produced it. A candidate PINS the run it came
    #    from (decision 42), and a pin nothing checks is a citation. Three facts must agree with
    #    the run's own ExecutionKey, and each one has a way of being wrong that this catches:
    #    lane (ORDER-371, numbers do not transfer across installs), data_fingerprint (a metric
    #    quoted from a different window), model (a Model-2 number quoted as if it were Model-4 --
    #    the 2026-07-17 grid precedent, where M2 manufactured a plateau M4 scored 0.61).
    if run_lookup is None:
        problems.append('C9 SKIPPED: no run store was supplied, so no metric was resolved to its '
                        'run. This manifest has been checked for INTEGRITY, not for PROVENANCE.')
    elif isinstance(manifest['payload'], dict) and isinstance(manifest['payload'].get('evidence'), list):
        for i, m in enumerate(manifest['payload']['evidence']):
            if not isinstance(m, dict) or 'run_id' not in m:
                continue
            journal = run_lookup.get(m['run_id'])
            if not journal:
                problems.append('C9 evidence[%d] cites %s and no such run exists in the store'
                                % (i, m['run_id']))
                continue
            key = journal.get('execution_key') or {}
            if not key:
                # 🔴 /scrutinize round 3: THE `if f in key` GUARD BELOW TURNED "I CANNOT CHECK"
                # INTO "CHECKED, FINE". A journal whose QUEUED line carries no ExecutionKey made
                # every field comparison vacuous, and the manifest validated CLEAN -- probed by
                # blanking the key on the cited runs: zero problems, while the metric still
                # claimed a lane, a fingerprint and a model that nothing compared. That is the
                # pin C9 exists to check, silently unchecked. A run that records no key cannot
                # license a claim about the lane it ran on.
                problems.append('C9 evidence[%d] cites %s, whose journal records no ExecutionKey '
                                'at all -- there is nothing to compare the lane, fingerprint and '
                                'model against, and an unverifiable pin is not a pin'
                                % (i, m['run_id']))
                continue
            states = [a.get('transition') for a in journal.get('attempts') or []]
            if 'EVIDENCE_REGISTERED' not in states:
                problems.append('C9 evidence[%d] cites %s, which never reached '
                                'EVIDENCE_REGISTERED (last: %s) -- a metric read off a run whose '
                                'artifact was never registered has no committed artifact behind it'
                                % (i, m['run_id'], states[-1] if states else 'nothing'))
            for f in ('lane', 'data_fingerprint', 'model'):
                if f not in key:
                    # Same rule as the blanket case above, one field down: a key that is present
                    # but silent about `lane` still cannot license a claim about it.
                    problems.append('C9 evidence[%d] cites %s, whose ExecutionKey records no %s'
                                    % (i, m['run_id'], f))
                elif S.normalize_numbers(key[f]) != S.normalize_numbers(m.get(f)):
                    problems.append('C9 evidence[%d] claims %s=%r but run %s recorded %r'
                                    % (i, f, m.get(f), m['run_id'], key[f]))
    return problems


# ---------------------------------------------------------------------------------------------
# DISK. Kept thin and at the edge, exactly as scheduler.py keeps it, so that everything above is
# drivable with no filesystem -- and so that there is ONE reader, which is what makes "recomputed
# on every read" a property of the module rather than a habit of its callers.
# ---------------------------------------------------------------------------------------------
def candidates_dir(root=None):
    return os.path.join(root or ROOT, CANDIDATES_DIR_REL.replace('/', os.sep))


def manifest_path(candidate_id, root=None):
    return os.path.join(candidates_dir(root), candidate_id + '.json')


def read_manifest(path, run_lookup):
    """THE ONLY READER, and it RAISES rather than returning problems.

    🔴 `run_lookup` IS REQUIRED, /scrutinize round 3. It had a `None` default, and that default
    could never succeed: with no store, C9 returns its SKIPPED finding, `problems` is non-empty
    and this raises -- every time. A parameter whose documented default always fails is a
    signature telling the caller something untrue. Passing `None` explicitly is still allowed and
    still refuses; what is gone is the impression that omitting it is a normal way to read.

    This is the acceptance in one function. A reader that returned `(manifest, problems)` would be
    a reader whose caller can ignore the second value, and the first caller in a hurry would --
    which is the whole failure mode design 4.5 describes for rev 1's un-constructible id.

    utf-8-sig, because PowerShell's `Set-Content -Encoding UTF8` writes a BOM that `json.loads`
    refuses; this repo has paid for that trap twice.
    """
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        raw = fh.read()
    try:
        manifest = json.loads(raw)
    except ValueError as exc:
        raise DigestMismatch('%s is not JSON: %s' % (path, exc))
    problems = validate_manifest(manifest, run_lookup=run_lookup)
    if problems:
        raise DigestMismatch('%s: %s' % (path, '; '.join(problems)))
    return manifest


def build_manifest(payload, scorecard_ref):
    """Compute the identity from the payload. The ONLY constructor, so a manifest whose id and
    digest disagree cannot be produced by this module at all -- only by editing a file, which is
    exactly what `read_manifest` refuses."""
    digest = candidate_digest(payload)
    return {
        'entity': 'CandidateManifest',
        'candidate_id': candidate_id_for(digest),
        'candidate_digest': digest,
        'payload': dict((f, payload[f]) for f in PAYLOAD_FIELDS),
        'scorecard_ref': scorecard_ref,
    }


def write_manifest(manifest, root=None, run_lookup=None):
    """Write once. CONTRACTS.md's x-writer is "claude, once, at verdict time", and this refuses
    the second write rather than trusting that sentence: a candidate whose manifest can be
    rewritten is a candidate whose digest describes whatever was written last."""
    problems = validate_manifest(manifest, run_lookup=run_lookup)
    if problems:
        raise DigestMismatch('refusing to write an invalid manifest: %s' % '; '.join(problems))
    path = manifest_path(manifest['candidate_id'], root)
    if os.path.exists(path):
        raise DigestMismatch('%s already exists -- a CandidateManifest is written ONCE, at verdict '
                             'time (CONTRACTS.md x-writer). Rewriting it would silently move the '
                             'identity every other record pins.' % path)
    d = os.path.dirname(path)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(S.canonical(manifest) + '\n')
    return path


# ---------------------------------------------------------------------------------------------
# The vocabulary must be the SCHEMA's.
# ---------------------------------------------------------------------------------------------
def assert_vocabulary_matches_schema(root=None):
    path = os.path.join(root or ROOT, '_triage', 'factory_os', 'schemas.json')
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        schema = json.load(fh)
    defs = schema['$defs']
    problems = []
    checks = (
        ('PAYLOAD_FIELDS', PAYLOAD_FIELDS, defs['CandidatePayload']['required']),
        ('MANIFEST_FIELDS', MANIFEST_FIELDS, defs['CandidateManifest']['required']),
        ('METRIC_FIELDS', METRIC_FIELDS, defs['MetricRef']['required']),
        ('MODULE_FIELDS', MODULE_FIELDS, defs['ModuleUse']['required']),
        ('OWNER_REF_FIELDS', OWNER_REF_FIELDS, defs['OwnerRef']['required']),
        ('PROFILE_KEYS', PROFILE_KEYS, defs['CandidatePayload']['properties']['profiles']['required']),
    )
    for name, mine, theirs in checks:
        if tuple(sorted(mine)) != tuple(sorted(theirs)):
            problems.append('%s %s != schema required %s' % (name, sorted(mine), sorted(theirs)))
    got = tuple(defs['MetricRef']['properties']['window']['enum'])
    if got != WINDOWS:
        problems.append('WINDOWS %s != schema %s' % (list(WINDOWS), list(got)))
    got = tuple(defs['ModuleUse']['properties']['stability']['enum'])
    if got != STABILITIES:
        problems.append('STABILITIES %s != schema %s' % (list(STABILITIES), list(got)))
    # The id pattern is the schema's too: a display prefix of a different length would still match
    # a hand-written regex here while failing the contract.
    if defs['CandidateManifest']['properties']['candidate_id']['pattern'] != CAND_ID_RE.pattern:
        problems.append('CAND_ID_RE %s != schema %s'
                        % (CAND_ID_RE.pattern,
                           defs['CandidateManifest']['properties']['candidate_id']['pattern']))
    return problems


# ---------------------------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------------------------
def _emit(obj, code=0):
    sys.stdout.write(S.canonical(obj) + '\n')
    return code


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        sys.stdout.write(__doc__)
        return 0
    cmd = argv[0]
    args = {}
    for a in argv[1:]:
        if a.startswith('--') and '=' in a:
            k, v = a[2:].split('=', 1)
            args[k.replace('-', '_')] = v
    root = args.get('root') or ROOT

    if cmd == '--self-test':
        return _selftest()

    if cmd == 'digest':
        # JSON arrives by FILE for the reason scheduler.py states: PowerShell 5.1 re-parses a
        # quoted argument on its way to a native process, and the failure is blamed on the caller
        # that wrote the object correctly.
        with io.open(args['payload_file'], 'r', encoding='utf-8-sig') as fh:
            payload = json.load(fh)
        try:
            digest = candidate_digest(payload)
        except ValueError as exc:
            return _emit({'action': 'REFUSE', 'why': str(exc)}, 1)
        return _emit({'action': 'DIGEST', 'candidate_digest': digest,
                      'candidate_id': candidate_id_for(digest)})

    if cmd == 'read':
        # `--no-runs` is gone with the default it went with: it produced a read that always
        # refused, which is a mode nobody should be offered. Reading a manifest resolves its pins.
        lookup = S.load_all_runs(root)
        try:
            manifest = read_manifest(args['path'], run_lookup=lookup)
        except DigestMismatch as exc:
            return _emit({'action': 'REFUSE', 'why': str(exc)}, 1)
        except (IOError, OSError) as exc:
            sys.stderr.write('%s\n' % exc)
            return 2
        return _emit({'action': 'READ', 'candidate_id': manifest['candidate_id'],
                      'candidate_digest': manifest['candidate_digest']})

    sys.stderr.write('unknown command %r\n' % cmd)
    return 2


def _selftest():
    problems = assert_vocabulary_matches_schema()
    for p in problems:
        sys.stdout.write('  [FAIL] %s\n' % p)
    sys.stdout.write('candidate self-test: %s\n' % ('FAILED' if problems else 'ok'))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
