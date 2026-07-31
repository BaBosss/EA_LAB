# -*- coding: utf-8 -*-
"""run_s2a_conformance.py -- ORDER-614 rev 2. The conformance RUNNER.

WHAT THIS IS FOR, in one sentence: so that repairing `check_s2a_attestation.py` stops costing
the repo owner a signature. Five signatures were spent in two sessions, FOUR of them on repairs
that changed no rule, because the checker is a member of its own `bundle_sha256`.

Rev 2's answer (adopted after rev 1 was refuted by a one-line `if False`): bind a versioned
POLICY and a frozen corpus of CONFORMANCE VECTORS instead of the implementation. A behavioural
change that matters shows up as a vector that stops reproducing; a repair that changes no rule
reproduces every vector and owes nothing.

THE LIMIT, STATED BECAUSE IT IS THE REASON THE DESIGN IS ACCEPTABLE: full semantic equivalence
between two implementations is NOT achievable without binding the implementation itself or
possessing a complete executable spec. **Vectors bound what is TESTED, not what is POSSIBLE.**
That is a weaker guarantee than rev 1 pretended to give and a stronger one than rev 1 gave.

HOW IT RUNS THE CHECKER. `check_s2a_attestation.check()` is a pure function of
(rows, problems, digest, d1_owners, vintage_notes) -- that is the seam, and it already existed.
The only git-dependent calls inside it resolve HEAD blobs, so the runner substitutes a synthetic
`head_blobs` resolver for the duration of a vector. NOTHING about the real repo, the real D1 or
the real bundle is read while vectors run: a corpus that had to be regenerated when HEAD moved
would re-create the signature loop under a new name.

USAGE
  tools\\python312\\python.exe _triage/factory_os/run_s2a_conformance.py
  ... --mutate            run the PERMANENT `if False` mutation harness (acceptance E1)
  ... --vector V-F7-001   run one vector, printing its full problem list
EXIT 0 = every CANONICAL vector reproduced - 1 = at least one did not - 2 = the runner could
not read its own corpus (never confused with a failing vector)
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import check_s2a_attestation as att   # noqa: E402
import check_s2a_migration as chk     # noqa: E402

POLICY_VERSION = 's2a-attestation/1'
VECTORS_REL = '_triage/factory_os/S2A_ATTESTATION_VECTORS.jsonl'
REPO_ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))


class CorpusError(Exception):
    """The runner could not read its own inputs. Exit 2 -- never a failing vector."""


# --------------------------------------------------------------------------------------
# The synthetic world.

class World(object):
    """A vector's `context`, in the shape the checker's git calls expect.

    `head_blobs` IS git as far as a vector is concerned: a path absent from the map does not
    exist at HEAD. That is what makes a vector hermetic -- and hermetic is the whole point,
    because a corpus pinned to real blobs would need re-signing every time HEAD moved.
    """

    def __init__(self, ctx):
        self.head_blobs = dict(ctx.get('head_blobs') or {})
        self.d1_rows = list(ctx.get('d1_rows') or [])
        self.d1_present = ctx.get('d1_present', True)
        self.ao = ctx.get('append_only')  # corpus contract 6: modelled independently

    def rev_parse_cached(self, spec):
        # spec is '<head>:<path>'; the head half is synthetic and ignored on purpose.
        path = spec.split(':', 1)[1] if ':' in spec else spec
        ent = self.head_blobs.get(path)
        if not ent:
            return 128, '', 'fatal: path %r does not exist in HEAD' % path
        return 0, ent.get('oid', ''), ''

    def git(self, *args):
        if args and args[0] == 'cat-file' and len(args) >= 3:
            spec = args[2]
            path = spec.split(':', 1)[1] if ':' in spec else spec
            ent = self.head_blobs.get(path)
            if not ent:
                return 128, '', 'fatal: not a valid object name'
            return 0, ent.get('kind', 'blob'), ''
        if args and args[0] == 'rev-parse' and self.ao:
            # check_append_only asks whether the log is committed at HEAD (G6's silence).
            if self.ao.get('committed') is not None:
                return 0, 'a' * 40, ''
            return 128, '', 'fatal: not in HEAD'
        if args and args[0] == 'ls-files' and self.ao:
            return (0, '', '') if self.ao.get('tracked') else (1, '', '')
        # Anything else a vector does not model is a runner failure, not a silent pass:
        # a checker reaching git through an unmodelled route must be noticed.
        raise CorpusError('vector world has no answer for git %s -- the corpus does not model '
                          'this call, so a verdict over it would be meaningless' % (args,))

    def subprocess_run(self, cmd, **kw):
        """check_append_only reaches git through RAW subprocess for BYTES (its own comment says
        chk._git decodes and is the wrong tool there), so the world must answer at that layer
        too -- an unmodelled route raising is what keeps a vector from quietly running real git.
        """
        class R(object):
            def __init__(self, rc, out, err=b''):
                self.returncode, self.stdout, self.stderr = rc, out, err
        if not self.ao:
            raise CorpusError('append-only subprocess reached with no append_only context')
        if cmd[:2] == ['git', 'cat-file']:
            c = self.ao.get('committed')
            return R(0, (c or '').encode('utf-8')) if c is not None else R(128, b'', b'no blob')
        if cmd[:2] == ['git', 'show']:
            if self.ao.get('index_readable', True) and self.ao.get('staged') is not None:
                return R(0, self.ao['staged'].encode('utf-8'))
            return R(128, b'', b'fatal: index unreadable')
        raise CorpusError('vector world has no answer for subprocess %s' % (cmd,))


def install_world(world):
    """Swap the checker's git touchpoints for the vector's world. Returns a restore callable."""
    saved = (chk._git, chk.head_oid, chk._rev_parse_cached, att._D1_ROWS[:], att.subprocess)

    class _SubShim(object):
        run = staticmethod(world.subprocess_run)
    chk._git = world.git
    chk.head_oid = lambda: 'f' * 40
    chk._rev_parse_cached = world.rev_parse_cached
    att._D1_ROWS[:] = world.d1_rows
    att.subprocess = _SubShim

    def restore():
        chk._git, chk.head_oid, chk._rev_parse_cached = saved[0], saved[1], saved[2]
        att._D1_ROWS[:] = saved[3]
        att.subprocess = saved[4]
    return restore


# --------------------------------------------------------------------------------------
# Vector execution.

_REASON_ID = re.compile(r'^\s*([A-Z][A-Z0-9-]*)\b')


def reason_id(text):
    """The criterion id a problem line reports, or '' when it names none.

    A problem with no id is NOT silently tolerated: `expected_reasons` cannot match it, so a
    checker that stops naming its criteria fails conformance rather than passing quietly.
    """
    m = _REASON_ID.match(text or '')
    return m.group(1) if m else ''


def digest_of(ctx):
    """The bundle digest: supplied, or COMPUTED from synthetic bundle_files by the policy rule."""
    if 'current_bundle_sha256' in ctx and 'bundle_files' in ctx:
        raise CorpusError('a vector supplies BOTH current_bundle_sha256 and bundle_files; the '
                          'corpus contract says exactly one, because two sources for one digest '
                          'is the drift the policy exists to remove')
    if 'current_bundle_sha256' in ctx:
        return ctx['current_bundle_sha256']
    files = ctx.get('bundle_files')
    if files is None:
        raise CorpusError('a vector supplies neither current_bundle_sha256 nor bundle_files')
    # Policy section 2.3, EXACTLY -- the first version of this function sorted by path and
    # skipped the inner hash, i.e. it implemented a different algorithm than the one the
    # policy declares and the B-vectors pin. DECLARED order is load-bearing (B2), the inner
    # sha256 of CRLF-normalised content is load-bearing (B3), and a runner with its own
    # private digest algorithm is a second implementation of a bound rule.
    import hashlib
    h = hashlib.sha256()
    for f in files:
        h.update(f['path'].encode('utf-8'))
        h.update(b'\0')
        content = f.get('content', '').replace('\r\n', '\n').encode('utf-8')
        h.update(hashlib.sha256(content).digest())
    return h.hexdigest()


def materialize_rows(entries):
    """`attestations` -> (rows, load_problems), through the REAL `load_records()`.

    The first version of this function re-implemented the loader and dropped its `_comment`
    rule, so R3's positive vector reported a missing-fields problem on a metadata line. That
    is the defect this whole repo keeps paying for -- a second implementation of a rule -- and
    it appeared inside the runner written to stop rules from drifting. So: write the lines to
    a private temp file, point the checker's own path at it, and let the loader be the loader.

    A `_raw_line` entry is written verbatim, which is how R1 and R2 are expressible at all: a
    line that is not a valid JSON object cannot be expressed as one.
    """
    import tempfile
    fd, path = tempfile.mkstemp(prefix='s2aconf_', suffix='.jsonl')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8', newline='\n') as fh:
            for e in entries:
                if isinstance(e, dict) and set(e.keys()) == {'_raw_line'}:
                    fh.write(e['_raw_line'] + '\n')
                else:
                    fh.write(json.dumps(e, sort_keys=True) + '\n')
        saved = att.ATTESTATION_PATH
        att.ATTESTATION_PATH = path
        try:
            return att.load_records()
        finally:
            att.ATTESTATION_PATH = saved
    finally:
        try:
            os.remove(path)
        except OSError:
            pass


def run_vector(vec):
    """-> (exit_code, reason_ids, current_map). Never raises for a vector's own content."""
    ctx = vec['input'].get('context') or {}
    world = World(ctx)
    if not world.d1_present:
        return 2, ['X1'], {}
    rows, problems = materialize_rows(vec['input'].get('attestations') or [])
    d1_owners = sorted({r['current_owner'] for r in world.d1_rows if r.get('current_owner')})
    vintage_notes = att.derive_vintage_notes(world.d1_rows, world.rev_parse_cached) \
        if hasattr(att, 'derive_vintage_notes') else _derive_notes(world)
    restore = install_world(world)
    try:
        current = att.check(rows, problems, digest_of(ctx), d1_owners, vintage_notes)
        if world.ao:
            # corpus contract 6: append-only judged from its own synthetic context, through
            # the checker's REAL function -- committed/working stay None so every branch
            # (G5 prefix, G6 silence, G7 tool-failure, G8 CRLF) runs the code under test.
            # The untracked-fallback branch reads the DISK by design, so the vector's
            # `worktree` bytes are materialised as a real temp file -- the code path stays
            # the real one and the file stays synthetic.
            import tempfile
            ao_path = world.ao.get('path')
            tmp_ao = None
            if world.ao.get('worktree') is not None and not world.ao.get('tracked'):
                fd, tmp_ao = tempfile.mkstemp(prefix='s2aconf_ao_')
                with os.fdopen(fd, 'w', encoding='utf-8', newline='') as fh:
                    fh.write(world.ao['worktree'])
                ao_path = tmp_ao
            try:
                att.check_append_only(problems, path=ao_path)
            finally:
                if tmp_ao:
                    try:
                        os.remove(tmp_ao)
                    except OSError:
                        pass
    finally:
        restore()
    ids = []
    for p in problems:
        rid = reason_id(p)
        line = re.search(r'\bline (\d+)', p)
        ids.append('%s@%s' % (rid, line.group(1)) if line else rid)
    cur = {}
    if isinstance(current, dict):
        for owner, row in current.items():
            if isinstance(row, dict):
                cur[owner] = {'line': row.get('_line'), 'decision': row.get('decision')}
    return (1 if problems else 0), ids, cur


def _derive_notes(world):
    """N1-N4: the vintage notes, DERIVED from D1 + head_blobs rather than supplied.

    Supplying them would let a vector assert the conclusion it is meant to test -- the same
    'authenticity is derived, never claimed' rule the snapshot slice is built on.
    """
    notes = []
    for r in world.d1_rows:
        ref = r.get('owner_ref') or {}
        path, pinned = ref.get('path'), ref.get('blob_oid')
        if not path or not pinned:
            continue
        rc, live, _ = world.rev_parse_cached('HEAD:%s' % path)
        if rc != 0:
            notes.append({'path': path, 'kind': 'MISSING', 'pinned_blob': pinned,
                          'current_blob': None})
        elif live != pinned:
            notes.append({'path': path, 'kind': 'STALE', 'pinned_blob': pinned,
                          'current_blob': live})
    return notes


def compare(vec, got_exit, got_ids, got_cur):
    """-> [failure strings]. Extra AND missing reasons both fail (policy contract 4)."""
    out = []
    if got_exit != vec['expected_exit']:
        out.append('exit %s, expected %s' % (got_exit, vec['expected_exit']))
    want = list(vec.get('expected_reasons') or [])
    have = list(got_ids)
    for w in want:
        match = None
        for h in have:
            if h == w or ('@' not in w and h.split('@')[0] == w):
                match = h
                break
        if match is None:
            out.append('missing expected reason %r (got %s)' % (w, have))
        else:
            have.remove(match)
    if have:
        out.append('unexpected reason(s) %s -- the right verdict for the wrong reason does not '
                   'conform' % have)
    exp_cur = vec.get('expected_current')
    if exp_cur:
        for owner, want_row in exp_cur.items():
            got_row = got_cur.get(owner)
            if got_row is None:
                out.append('expected %s in force for %r, got none' % (want_row, owner))
            elif (want_row.get('line') != got_row.get('line')
                  or want_row.get('decision') != got_row.get('decision')):
                out.append('in-force row for %r is %s, expected %s' % (owner, got_row, want_row))
    exp_dig = vec.get('expected_bundle_sha256')
    if exp_dig:
        got_dig = digest_of(vec['input'].get('context') or {})
        if got_dig != exp_dig:
            out.append('bundle digest %s, expected %s' % (got_dig[:16], exp_dig[:16]))
    return out


def load_corpus():
    path = os.path.join(REPO_ROOT, VECTORS_REL.replace('/', os.sep))
    if not os.path.isfile(path):
        raise CorpusError('%s does not exist' % VECTORS_REL)
    vectors, seen = [], set()
    for n, line in enumerate(io.open(path, encoding='utf-8'), 1):
        line = line.strip()
        if not line:
            continue
        try:
            v = json.loads(line)
        except ValueError as exc:
            raise CorpusError('%s line %d is not JSON: %s' % (VECTORS_REL, n, exc))
        if set(v.keys()) == {'_comment'}:
            continue
        vid = v.get('vector_id')
        if not vid:
            raise CorpusError('%s line %d has no vector_id' % (VECTORS_REL, n))
        if vid in seen:
            raise CorpusError('duplicate vector_id %r -- a corpus that can hold two vectors '
                              'under one id cannot report which one failed' % vid)
        seen.add(vid)
        vectors.append(v)
    if not vectors:
        raise CorpusError('the corpus is empty -- zero vectors is not zero failures')
    return vectors


def mutation_harness(vectors):
    """Acceptance E1/E2, executable: is every vector LOAD-BEARING for the criterion it isolates?

    `if False` on a predicate makes that criterion stop firing. This simulates exactly that,
    without editing the implementation, by deleting the criterion's problems from a vector's
    result and asserting the comparison then FAILS. A vector that still passes with its own
    criterion neutralized proves nothing about that criterion -- which is the executable form
    of "a vector no criterion uniquely explains is a vector that proves nothing".

    It is a PERMANENT fixture and not a one-off probe: a future edit that makes a criterion
    unreachable (the way R8 already is) turns its vector into a passenger, and this is what
    notices.
    """
    print('\n=== MUTATION HARNESS (E1): every vector must be load-bearing ===')
    inert, checked, controls, already_red = [], 0, [], []
    for v in vectors:
        crit = v.get('isolates')
        want = [w.split('@')[0] for w in (v.get('expected_reasons') or [])]
        if not crit or crit not in want:
            # A green vector expects no reasons, so there is nothing to neutralize -- it is a
            # CONTROL, not a criterion probe. Named rather than silently counted as covered.
            controls.append(v['vector_id'])
            continue
        try:
            got_exit, got_ids, got_cur = run_vector(v)
        except Exception:                              # noqa: BLE001
            continue
        # ONLY a vector that currently CONFORMS can be probed. Neutralising a criterion in a
        # vector that already fails proves nothing -- "red because I neutralised it" and "red
        # already" are indistinguishable, and the first version of this harness counted the
        # second as evidence for the first. That is shape 3 inside the fixture written to
        # prove criteria can fail, so the two are separated and both are printed.
        if compare(v, got_exit, got_ids, got_cur):
            already_red.append(v['vector_id'])
            continue
        checked += 1
        surviving = [i for i in got_ids if i.split('@')[0] != crit]
        mutated_exit = 1 if surviving else 0
        if not compare(v, mutated_exit, surviving, got_cur):
            inert.append((v['vector_id'], crit))
    print('  %d vector(s) probed, %d control(s) with nothing to neutralize, %d NOT PROBED '
          'because they do not currently conform' % (checked, len(controls), len(already_red)))
    if already_red:
        print('  not probed: %s%s' % (', '.join(already_red[:8]),
                                      '...' if len(already_red) > 8 else ''))
    if checked == 0:
        print('  [UNTESTED] 0 vectors were probed -- this harness proves NOTHING about this run')
        return 1
    for vid, crit in inert:
        print('  [INERT] %s still passes with %s neutralized -- it does not bind that criterion'
              % (vid, crit))
    if inert:
        return 1
    print('  every probed vector goes red when its own criterion stops firing')
    return 0


def main(argv):
    try:
        vectors = load_corpus()
    except CorpusError as exc:
        print('[CORPUS FAILURE] %s' % exc)
        return 2

    only = None
    if '--vector' in argv:
        only = argv[argv.index('--vector') + 1]

    print('=== ORDER-614 rev 2 conformance: policy %s ===' % POLICY_VERSION)
    print('corpus : %s' % VECTORS_REL)

    canonical = [v for v in vectors if v.get('status', 'CANONICAL') == 'CANONICAL']
    provisional = [v for v in vectors if v.get('status') == 'PROVISIONAL']

    failed, ran = [], 0
    for v in canonical:
        if only and v['vector_id'] != only:
            continue
        ran += 1
        try:
            got = run_vector(v)
        except CorpusError:
            raise
        except Exception as exc:                       # noqa: BLE001 -- a vector must not kill the run
            failed.append((v['vector_id'], ['runner raised %s: %s' % (type(exc).__name__, exc)]))
            continue
        diffs = compare(v, *got)
        if diffs:
            failed.append((v['vector_id'], diffs))
        if only:
            print('  isolates=%s  exit=%s  reasons=%s' % (v.get('isolates'), got[0], got[1]))

    print('  %d canonical vector(s) run, %d failed' % (ran, len(failed)))
    if provisional:
        # A PROVISIONAL vector is one whose criterion could not be isolated. Printing the count
        # is the guard rule applied to this corpus: a criterion nothing can isolate is UNBOUND,
        # and saying so out loud is the difference between a limit and a hole.
        print('  %d PROVISIONAL vector(s) NOT gating: %s'
              % (len(provisional), ', '.join(v['vector_id'] for v in provisional)))
    for vid, diffs in failed:
        print('\n  [FAIL] %s' % vid)
        for d in diffs:
            print('         - %s' % d)
    if '--mutate' in argv:
        rc = mutation_harness([v for v in canonical if not only or v['vector_id'] == only])
        if rc:
            return rc
    if failed:
        return 1
    print('\n=== every canonical vector reproduced under policy %s ===' % POLICY_VERSION)
    print('    What this proves: the implementation still satisfies the bound policy, so a')
    print('    repair that changes no rule owes the owner NO signature. What it does NOT prove:')
    print('    semantic equivalence -- vectors bound what is TESTED, not what is POSSIBLE.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
