# -*- coding: utf-8 -*-
"""run_registry_tests.py -- ORDER-630 (slice S5) acceptance: R1 R2 R3 R4 R5, each with a negative.

WHY THE FIXTURES ARE SYNTHETIC
  Three of the five stores carry no content rows, and that is a recorded block rather than an
  omission: Core Universe v1 membership is an OWNER decision, a Hypothesis registration asserts a
  causal claim, and a ParameterBinding names a hypothesis revision that does not exist yet. So the
  mechanism is exercised against SYNTHETIC registries in a temp root. Populating the real stores to
  make the suite look busy would be inventing owner-owned content, which the design forbids by
  name -- and a fixture built out of invented content proves nothing about the real store anyway.

  What that costs, stated rather than hidden: these fixtures prove the RULES hold, not that the
  real stores exercise them. `check_registries.py` prints how many NOT_APPLICABLE cells it
  examined on each real run, and prints 0 as "UNTESTED by this run", so the two are never confused.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_registry_tests.py
"""
import copy
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import check_registries as chk  # noqa: E402
import registry as reg          # noqa: E402

PASS, FAIL = [], []


def check(name, ok, detail=''):
    (PASS if ok else FAIL).append(name)
    print('  [%s] %s%s' % ('OK ' if ok else 'BAD', name,
                           ('  -> ' + detail) if detail and not ok else ''))


def refuses(name, fn, must_contain):
    try:
        fn()
    except reg.RegistryRefusal as exc:
        if must_contain in str(exc):
            check(name, True)
        else:
            check(name, False, 'refused for a different reason: %s' % str(exc)[:150])
        return
    check(name, False, 'it was ACCEPTED')


def seed(root, **content):
    """Write a full set of synthetic stores; `content[key] = [rows]` overrides one of them."""
    os.makedirs(os.path.join(root, 'factory'), exist_ok=True)
    for rel in reg.STORES:
        rows = content.get(os.path.basename(rel).replace('.jsonl', ''), [])
        with io.open(os.path.join(root, rel.replace('/', os.sep)), 'w',
                     encoding='utf-8', newline='\n') as fh:
            fh.write(reg.canonical_line({'_comment': 'synthetic fixture'}) + '\n')
            for r in rows:
                fh.write(reg.canonical_line(r) + '\n')
    return root


def binding(rev='B14-H01-r1', param='SL_ATR', role='TUNABLE', surface='RESEARCH', **extra):
    r = {'entity': 'ParameterBinding', 'hypothesis_revision': rev, 'parameter': param,
         'role': role, 'surface': surface,
         'definition_ref': {'entity': 'OwnerRef', 'owner_type': 'param_registry',
                            'path': 'docs/PARAM_REGISTRY.csv', 'commit_oid': '0' * 40,
                            'blob_oid': '0' * 40, 'raw_sha256': '0' * 64}}
    r.update(extra)
    return r


def main():
    root = tempfile.mkdtemp(prefix='s5_')
    try:
        print('\n--- THE RESOLVER: one answer, and no answer by silence ---')
        seed(root, parameter_bindings=[binding(),
                                       binding(param='MaxOpen', role='SAFETY', surface='OPERATOR'),
                                       binding(param='LotBase', role='LOCKED', surface='HIDDEN',
                                               locked_value=0.01)])
        st = reg.load_all(root=root)
        t = reg.resolve('B14-H01-r1', 'SL_ATR', stores=st)
        check('a TUNABLE binding resolves optimizable=True',
              t['optimizable'] is True and t['source'] == 'BOUND', json.dumps(t))
        s = reg.resolve('B14-H01-r1', 'MaxOpen', stores=st)
        check('a SAFETY binding resolves optimizable=False', s['optimizable'] is False)
        lk = reg.resolve('B14-H01-r1', 'LotBase', stores=st)
        check('a LOCKED binding carries its locked_value through',
              lk['optimizable'] is False and lk['locked_value'] == 0.01)
        # THE ONE THAT MATTERS: an unbound parameter must not be granted permission by silence.
        u = reg.resolve('B14-H01-r1', 'NeverBound', stores=st)
        check('an UNBOUND parameter resolves optimizable=None, never True',
              u['optimizable'] is None and u['role'] is None and u['source'] == 'UNBOUND',
              json.dumps(u))
        # The per-hypothesis point of the whole entity: same parameter, other revision.
        o = reg.resolve('B14-H02-r1', 'SL_ATR', stores=st)
        check('the SAME parameter is UNBOUND in a different revision (bindings are per-revision)',
              o['source'] == 'UNBOUND')
        check('resolve_all returns exactly the parameters bound in that revision',
              sorted(reg.resolve_all('B14-H01-r1', stores=st)) == ['LotBase', 'MaxOpen', 'SL_ATR'])

        dup = seed(tempfile.mkdtemp(prefix='s5dup_'),
                   parameter_bindings=[binding(), binding(role='LOCKED', locked_value=1)])
        try:
            refuses('NEG two bindings for one (revision, parameter) are REFUSED, not last-wins',
                    lambda: reg.resolve('B14-H01-r1', 'SL_ATR', root=dup),
                    'a store with two answers cannot be a resolver')
        finally:
            shutil.rmtree(dup, ignore_errors=True)

        bad = seed(tempfile.mkdtemp(prefix='s5bad_'),
                   parameter_bindings=[binding(role='SORT-OF-TUNABLE')])
        try:
            refuses('NEG a role outside the closed vocabulary is REFUSED',
                    lambda: reg.resolve('B14-H01-r1', 'SL_ATR', root=bad),
                    'not in the closed vocabulary')
        finally:
            shutil.rmtree(bad, ignore_errors=True)

        gone = tempfile.mkdtemp(prefix='s5gone_')
        try:
            refuses('NEG an ABSENT store is REFUSED, never read as an empty one',
                    lambda: reg.load_all(root=gone),
                    'An absent registry is not an empty registry')
        finally:
            shutil.rmtree(gone, ignore_errors=True)

        print('\n--- R1: round-trip deterministic ---')
        rel = 'factory/parameter_bindings.jsonl'
        check('R1 a canonically-written store round-trips with zero differing lines',
              reg.round_trip(rel, root=root) == [])
        # NEGATIVE: re-serialise one line with different key order and spacing. Nothing about the
        # CONTENT changed, which is the point -- R1 exists so that a read-write cycle cannot
        # change bytes no edit changed.
        p = os.path.join(root, rel.replace('/', os.sep))
        lines = io.open(p, encoding='utf-8').read().splitlines()
        rec = json.loads(lines[1])
        lines[1] = json.dumps(rec, sort_keys=False, separators=(',', ':'))
        io.open(p, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
        check('R1 NEG a non-canonical line is reported, by line number',
              reg.round_trip(rel, root=root) == [2], str(reg.round_trip(rel, root=root)))
        n = reg.rewrite_canonical(rel, root=root)
        check('R1 canonicalize repairs it and the store round-trips again',
              reg.round_trip(rel, root=root) == [] and n == 4, 'rewrote %d' % n)

        print('\n--- R2: NOT_APPLICABLE refused without a reason ---')
        # These drive check_registries directly against a synthetic root, so the criterion is
        # exercised rather than merely named.
        for label, cell, expect_problem in [
                ('a NOT_APPLICABLE cell WITH a real reason', {
                    'cell': 'EURUSD H1', 'status': 'NOT_APPLICABLE',
                    'not_applicable_reason': 'no tick data before 2019 on this lane'}, False),
                ('a NOT_APPLICABLE cell with NO reason', {
                    'cell': 'EURUSD H1', 'status': 'NOT_APPLICABLE'}, True),
                ('a NOT_APPLICABLE cell with a token reason', {
                    'cell': 'EURUSD H1', 'status': 'NOT_APPLICABLE',
                    'not_applicable_reason': 'n/a'}, True)]:
            r2root = seed(tempfile.mkdtemp(prefix='s5r2_'), coverage=[{'cells': [cell]}])
            try:
                chk.problems[:] = []
                fired = chk.check_r2(reg.load_all(root=r2root))
                got = any(p.startswith('R2') for p in chk.problems)
                check('R2 %s -> %s' % (label, 'REFUSED' if expect_problem else 'accepted'),
                      got is expect_problem and fired == 1,
                      'problems=%s fired=%d' % (chk.problems, fired))
            finally:
                shutil.rmtree(r2root, ignore_errors=True)

        print('\n--- R3: no verdict field -- KEYS and VALUES, both ends ---')
        for label, row, expect in [
                ('a plain fact row', {'entity': 'TestUniverse', 'universe_version': 'v1'}, False),
                ('a row with a `verdict` KEY', {'entity': 'TestUniverse', 'verdict': 'x'}, True),
                ('a row with a verdict key NESTED three deep',
                 {'entity': 'TestUniverse', 'a': {'b': {'outcome': 'x'}}}, True),
                # THE A3 CASE, VERBATIM: a neutral key carrying a verdict VALUE. A name-only check
                # passes this, and that is how "status": "DEAD-STRUCTURAL" reached a store whose
                # whole acceptance forbids a verdict.
                ('a NEUTRAL key carrying the value DEAD-STRUCTURAL',
                 {'entity': 'TestUniverse', 'state': 'DEAD-STRUCTURAL'}, True),
                ('a neutral key carrying BUILD-ON',
                 {'entity': 'TestUniverse', 'label': 'BUILD-ON'}, True),
                ('a verdict value inside an ARRAY',
                 {'entity': 'TestUniverse', 'tags': ['fine', 'DEMO']}, True)]:
            r3root = seed(tempfile.mkdtemp(prefix='s5r3_'), universe=[row])
            try:
                chk.problems[:] = []
                chk.check_r3(reg.load_all(root=r3root))
                got = any(p.startswith('R3') for p in chk.problems)
                check('R3 %s -> %s' % (label, 'REFUSED' if expect else 'accepted'),
                      got is expect, str(chk.problems))
            finally:
                shutil.rmtree(r3root, ignore_errors=True)
        # The exemption must be NARROW. coverage.jsonl's `status: LIVE` is excused; the same value
        # under a different key, or in a different store, is not.
        for label, rel_store, row, expect in [
                ('the declared exemption (coverage `status: LIVE`)', 'coverage',
                 {'cells': [{'cell': 'X', 'status': 'LIVE'}]}, False),
                ('the SAME value under a different key in the same store', 'coverage',
                 {'cells': [{'cell': 'X', 'verdict_label': 'LIVE'}]}, True),
                ('the SAME value in a DIFFERENT store', 'universe',
                 {'entity': 'TestUniverse', 'status': 'LIVE'}, True)]:
            exroot = seed(tempfile.mkdtemp(prefix='s5ex_'), **{rel_store: [row]})
            try:
                chk.problems[:] = []
                chk.check_r3(reg.load_all(root=exroot))
                got = any(p.startswith('R3') for p in chk.problems)
                check('R3 exemption scope: %s -> %s' % (label, 'REFUSED' if expect else 'accepted'),
                      got is expect, str(chk.problems))
            finally:
                shutil.rmtree(exroot, ignore_errors=True)

        # ROUND-1 FINDINGS, fixtured. Both were found by ATTACKING R3 and the resolver, not by
        # re-reading them.
        for label, row, expect in [
                ('a verdict word used as a KEY (probed: walked past the value check)',
                 {'entity': 'TestUniverse', 'DEMO': 1}, True),
                ('a verdict value LOWERCASED',
                 {'entity': 'TestUniverse', 'state': 'dead-structural'}, True),
                ('a verdict value padded with whitespace',
                 {'entity': 'TestUniverse', 'state': ' DEMO '}, True),
                ('a verdict inside a NESTED array',
                 {'entity': 'TestUniverse', 'a': [{'b': ['DEMO']}]}, True),
                # THE STATED LIMIT, asserted so it is a documented gap and not a surprise. A value
                # list cannot catch a verdict expressed as a number or in words nobody listed. The
                # allowlist for that is the schema's closed object, not this check.
                ('a verdict word NOT in the list -- the blacklist limit, asserted as a gap',
                 {'entity': 'TestUniverse', 'state': 'APPROVED'}, False)]:
            lroot = seed(tempfile.mkdtemp(prefix='s5lim_'), universe=[row])
            try:
                chk.problems[:] = []
                chk.check_r3(reg.load_all(root=lroot))
                got = any(p.startswith('R3') for p in chk.problems)
                check('R3 %s -> %s' % (label, 'REFUSED' if expect else 'NOT caught (stated limit)'),
                      got is expect, str(chk.problems))
            finally:
                shutil.rmtree(lroot, ignore_errors=True)

        lk = seed(tempfile.mkdtemp(prefix='s5lock_'),
                  parameter_bindings=[{'entity': 'ParameterBinding',
                                       'hypothesis_revision': 'B14-H01-r1', 'parameter': 'Z',
                                       'role': 'LOCKED', 'surface': 'HIDDEN'}])
        try:
            refuses('NEG role=LOCKED with NO locked_value is REFUSED (probed: it resolved to None)',
                    lambda: reg.resolve('B14-H01-r1', 'Z', root=lk),
                    'is not a lock')
        finally:
            shutil.rmtree(lk, ignore_errors=True)
        lk2 = seed(tempfile.mkdtemp(prefix='s5lock2_'),
                   parameter_bindings=[binding(param='Z', role='LOCKED', surface='HIDDEN',
                                               locked_value=0)])
        try:
            # SPECIFICITY, and it has to be `0`: a check written as `if not locked_value` would
            # refuse a legitimate lock-to-zero, which is a real value for a lot size or a flag.
            check('SPECIFICITY role=LOCKED with locked_value=0 is ACCEPTED, not refused as falsy',
                  reg.resolve('B14-H01-r1', 'Z', root=lk2)['locked_value'] == 0)
        finally:
            shutil.rmtree(lk2, ignore_errors=True)

        print('\n--- R4: one resolver, and the sweep can tell code from prose ---')
        chk.problems[:] = []
        chk.check_r4()
        check('R4 holds against the real tree', not any(p.startswith('R4') for p in chk.problems),
              str(chk.problems))
        # NEG (a): a declared consumer that does not reach the resolver.
        saved = dict(chk.RESOLVER_CONSUMERS)
        try:
            chk.RESOLVER_CONSUMERS['scripts/check_state.ps1'] = 'factory_os/registry.py'
            chk.problems[:] = []
            chk.check_r4()
            check('R4 NEG a declared consumer that never references the resolver is REFUSED',
                  any('never references' in p or 'does not reference' in p
                      for p in chk.problems), str(chk.problems))
        finally:
            chk.RESOLVER_CONSUMERS.clear()
            chk.RESOLVER_CONSUMERS.update(saved)
        # NEG (b) + the CONTROL that matters: the sweep must catch a second vocabulary in CODE and
        # must NOT catch it in a COMMENT. The first version of this sweep flagged the declared
        # consumer for a comment explaining why it consults the resolver.
        check('R4 the sweep IGNORES the pair in a PowerShell comment',
              not (chk.ROLE_PAIR.search(chk.strip_comments(
                  '# a TUNABLE input can be LOCKED per hypothesis\n$x = 1\n', 'x.ps1'))))
        code = chk.strip_comments("$r = 'TUNABLE'\nif ($r -eq 'LOCKED') { }\n", 'x.ps1')
        check('R4 the sweep CATCHES the pair in PowerShell code',
              bool(chk.ROLE_PAIR.search(code) and chk.ROLE_PAIR2.search(code)))
        check('R4 the sweep IGNORES the pair in a python docstring',
              not chk.ROLE_PAIR.search(chk.strip_comments(
                  '"""TUNABLE vs LOCKED, explained"""\nx = 1\n', 'x.py')))

        print('\n--- R5: one entity per store ---')
        chk.problems[:] = []
        chk.check_r5(reg.load_all(root=root))
        check('R5 holds for a correctly-typed synthetic set',
              not any(p.startswith('R5') for p in chk.problems), str(chk.problems))
        wrong = seed(tempfile.mkdtemp(prefix='s5r5_'),
                     universe=[{'entity': 'Hypothesis', 'hypothesis_id': 'B14-H01'}])
        try:
            chk.problems[:] = []
            chk.check_r5(reg.load_all(root=wrong))
            check('R5 NEG a row of the wrong entity in a store is REFUSED',
                  any('this store holds' in p for p in chk.problems), str(chk.problems))
        finally:
            shutil.rmtree(wrong, ignore_errors=True)

        # ROUND-3: the allowlist is exhaustive over the WHOLE role enum, not just the two roles
        # the other cases happen to use. This is what makes "a role added to the enum later is
        # refused until somebody decides" a fact rather than an intention.
        allroot = tempfile.mkdtemp(prefix='s5roles_')
        try:
            rows = []
            for i, r in enumerate(reg.ROLES):
                extra = {'locked_value': 1} if r == 'LOCKED' else {}
                rows.append(binding(param='P%d' % i, role=r, surface='RESEARCH', **extra))
            seed(allroot, parameter_bindings=rows)
            res = reg.resolve_all('B14-H01-r1', root=allroot)
            check('every one of the %d roles resolves, and exactly the ones in OPTIMIZABLE_ROLES '
                  'are True' % len(reg.ROLES),
                  all(res['P%d' % i]['optimizable'] is (r in reg.OPTIMIZABLE_ROLES)
                      for i, r in enumerate(reg.ROLES)),
                  json.dumps({k: v['optimizable'] for k, v in res.items()}))
            check('and OPTIMIZABLE_ROLES is a strict subset, so the enum cannot grant itself '
                  'permission by growing',
                  set(reg.OPTIMIZABLE_ROLES) < set(reg.ROLES))
        finally:
            shutil.rmtree(allroot, ignore_errors=True)

        print("\n--- R6: a BLOCKED store must be absent, and its block must still hold ---")
        chk.problems[:] = []
        chk.check_r6()
        check('R6 holds against the real tree (universe.jsonl is blocked and absent)',
              not any(p.startswith('R6') for p in chk.problems), str(chk.problems))
        # NEG: a blocked store that has APPEARED. load_all() skips it, so nothing would validate
        # it -- "skipped" must never quietly become "there but unchecked".
        blocked_rel = sorted(reg.STORES_BLOCKED)[0]
        real = os.path.join(reg.REPO_ROOT, blocked_rel.replace('/', os.sep))
        created = False
        try:
            if not os.path.isfile(real):
                with io.open(real, 'w', encoding='utf-8') as fh:
                    fh.write('{"_comment": "run_registry_tests.py R6 NEG fixture"}' + chr(10))
                created = True
            chk.problems[:] = []
            chk.check_r6()
            check('R6 NEG a BLOCKED store that has appeared is REFUSED',
                  any('is declared BLOCKED but EXISTS' in p for p in chk.problems),
                  str(chk.problems))
            check('R6 and load_all() picks it up once present, so R6 is the only thing standing '
                  'between "blocked" and "unchecked"',
                  blocked_rel in reg.load_all())
        finally:
            if created:
                os.remove(real)
        # NEG: the block's PREMISE expiring. Driven by pointing the checker at a D1 that no longer
        # declares the two states, rather than by editing the real D1 -- which is inside the
        # owner's attestation bundle and may not be touched to make a test pass.
        saved_root = chk.ROOT
        empty_d1 = tempfile.mkdtemp(prefix='s5d1_')
        try:
            os.makedirs(os.path.join(empty_d1, '_triage', 'factory_os'))
            with io.open(os.path.join(empty_d1, '_triage', 'factory_os', 's2a_migration.jsonl'),
                         'w', encoding='utf-8') as fh:
                fh.write(json.dumps({'entity': 'TestUniverse', 'proposed': 'factory/universe.jsonl',
                                     'owner': 'OWNED_ELSEWHERE'}) + chr(10))
            chk.ROOT = empty_d1
            chk.problems[:] = []
            chk.check_r6()
            check('R6 NEG a block whose PREMISE has expired is reported, not inherited',
                  any('has EXPIRED' in p for p in chk.problems), str(chk.problems))
        finally:
            chk.ROOT = saved_root
            shutil.rmtree(empty_d1, ignore_errors=True)

        # ROUND-2 FINDINGS, fixtured.
        saved_blocked = dict(reg.STORES_BLOCKED)
        try:
            reg.STORES_BLOCKED.clear()
            chk.problems[:] = []
            chk.check_r6()
            check('R6 NEG DELETING the block while its premise holds is REFUSED '
                  '(probed: it was silently green)',
                  any('must be recorded, not dropped' in p for p in chk.problems),
                  str(chk.problems))
        finally:
            reg.STORES_BLOCKED.clear()
            reg.STORES_BLOCKED.update(saved_blocked)

        # R4's consumer half must read CODE, not prose. Probed: it read the raw source, so a
        # consumer that only MENTIONED the resolver in a comment satisfied it.
        consumer = 'scripts/optimize_guard.ps1'
        with io.open(os.path.join(reg.REPO_ROOT, consumer.replace('/', os.sep)),
                     encoding='utf-8') as fh:
            csrc = fh.read()
        token = chk.RESOLVER_CONSUMERS[consumer]
        check('R4 the declared consumer carries the resolver token in CODE, not only in a comment',
              chk.strip_comments(csrc, consumer).count(token) >= 1,
              'stripped occurrences=%d, raw=%d'
              % (chk.strip_comments(csrc, consumer).count(token), csrc.count(token)))
        # ...and the check itself must reject a consumer whose ONLY reference is a comment.
        fake = tempfile.mkdtemp(prefix='s5cons_')
        try:
            os.makedirs(os.path.join(fake, 'scripts'))
            with io.open(os.path.join(fake, 'scripts', 'fake.ps1'), 'w', encoding='utf-8') as fh:
                fh.write('# we consult factory_os/registry.py, honest\n$x = 1\n')
            saved_root, saved_cons = chk.ROOT, dict(chk.RESOLVER_CONSUMERS)
            try:
                chk.ROOT = fake
                chk.RESOLVER_CONSUMERS.clear()
                chk.RESOLVER_CONSUMERS['scripts/fake.ps1'] = 'factory_os/registry.py'
                chk.problems[:] = []
                chk.check_r4()
                check('R4 NEG a consumer whose ONLY reference is a COMMENT is REFUSED',
                      any('does not reference' in p for p in chk.problems), str(chk.problems))
            finally:
                chk.ROOT = saved_root
                chk.RESOLVER_CONSUMERS.clear()
                chk.RESOLVER_CONSUMERS.update(saved_cons)
        finally:
            shutil.rmtree(fake, ignore_errors=True)

        print("\n--- BLIND AUDIT ROUND 2: every finding, as a fixture ---")
        # P2-9: canonicalize left a PARTIAL MUTATION -- it rewrote four stores then raised on the
        # fifth, and ignored the --root it had parsed. Driven through the CLI, which is where the
        # audit found it.
        part = seed(tempfile.mkdtemp(prefix='s5can2_'))
        try:
            os.remove(os.path.join(part, 'factory', 'coverage.jsonl'))
            before = dict((r, io.open(os.path.join(part, r.replace('/', os.sep)),
                                      encoding='utf-8').read())
                          for r in reg.STORES
                          if os.path.isfile(os.path.join(part, r.replace('/', os.sep))))
            py = os.path.join(reg.REPO_ROOT, 'tools', 'python312', 'python.exe')
            pr = subprocess.run([py, os.path.join(HERE, 'registry.py'), 'canonicalize',
                                 '--root=' + part], capture_output=True, text=True)
            check('AUDIT P2-9 canonicalize with an unreadable store exits non-zero',
                  pr.returncode != 0, pr.stdout[-160:])
            after = dict((r, io.open(os.path.join(part, r.replace('/', os.sep)),
                                     encoding='utf-8').read())
                         for r in before)
            check('AUDIT P2-9 and NOTHING was mutated (probed: it rewrote 4 stores then raised)',
                  before == after)
        finally:
            shutil.rmtree(part, ignore_errors=True)
        # SPECIFICITY: a complete tree canonicalizes, honours --root, and leaves no temp file.
        good = seed(tempfile.mkdtemp(prefix='s5can3_'))
        try:
            py = os.path.join(reg.REPO_ROOT, 'tools', 'python312', 'python.exe')
            pr = subprocess.run([py, os.path.join(HERE, 'registry.py'), 'canonicalize',
                                 '--root=' + good], capture_output=True, text=True)
            leftovers = [f for f in os.listdir(os.path.join(good, 'factory'))
                         if f.endswith('.tmp')]
            check('AUDIT P2-9 SPECIFICITY a complete tree canonicalizes under --root, exit 0, '
                  'no temp file left', pr.returncode == 0 and not leftovers,
                  '%s %s' % (pr.returncode, leftovers))
        finally:
            shutil.rmtree(good, ignore_errors=True)

        # P1-4: a metadata key must not hide a row.
        hid = seed(tempfile.mkdtemp(prefix='s5hid_'))
        try:
            with io.open(os.path.join(hid, 'factory', 'parameter_bindings.jsonl'),
                         'a', encoding='utf-8', newline='\n') as fh:
                fh.write(reg.canonical_line(
                    {'_comment': 'looks like a note', 'entity': 'ParameterBinding',
                     'hypothesis_revision': 'B14-H01-r1', 'parameter': 'X', 'role': 'LOCKED',
                     'surface': 'HIDDEN', 'locked_value': 1, 'verdict': 'DEMO'}) + '\n')
            refuses('AUDIT P1-4 a row carrying BOTH a metadata key and `entity` is REFUSED '
                    '(probed: meta=2 rows=0, a LOCKED binding and a verdict both invisible)',
                    lambda: reg.read_store('factory/parameter_bindings.jsonl', root=hid),
                    'ambiguous whether this is a row or a note')
        finally:
            shutil.rmtree(hid, ignore_errors=True)
        # SPECIFICITY: a genuine metadata line, with no `entity`, is still metadata.
        okmeta = seed(tempfile.mkdtemp(prefix='s5meta_'))
        try:
            meta, rows = reg.read_store('factory/parameter_bindings.jsonl', root=okmeta)
            check('AUDIT P1-4 SPECIFICITY a metadata line with no `entity` is still metadata',
                  len(meta) == 1 and len(rows) == 0)
        finally:
            shutil.rmtree(okmeta, ignore_errors=True)

        # P1-5: an overlay may ADD a refusal and may never REMOVE one.
        can = seed(tempfile.mkdtemp(prefix='s5can_'),
                   parameter_bindings=[binding(param='P', role='LOCKED', surface='HIDDEN',
                                               locked_value=1)])
        emptyo = seed(tempfile.mkdtemp(prefix='s5ov_'))
        addo = seed(tempfile.mkdtemp(prefix='s5ov2_'),
                    parameter_bindings=[binding(param='Q', role='SAFETY', surface='OPERATOR')])
        try:
            base = reg.resolve('B14-H01-r1', 'P', root=can)
            check('AUDIT P1-5 CONTROL the canonical LOCKED binding refuses on its own',
                  base['optimizable'] is False)
            over = reg.resolve('B14-H01-r1', 'P', root=can, overlay_root=emptyo)
            check('AUDIT P1-5 an EMPTY overlay cannot remove the canonical refusal '
                  '(probed: --root replaced the store and turned this into ALLOW)',
                  over['optimizable'] is False and over['role'] == 'LOCKED', json.dumps(over))
            relax = seed(tempfile.mkdtemp(prefix='s5ov3_'),
                         parameter_bindings=[binding(param='P', role='TUNABLE')])
            try:
                still = reg.resolve('B14-H01-r1', 'P', root=can, overlay_root=relax)
                check('AUDIT P1-5 an overlay that RELAXES a canonical binding is ignored '
                      '- canonical wins every key it defines',
                      still['role'] == 'LOCKED' and still['optimizable'] is False,
                      json.dumps(still))
            finally:
                shutil.rmtree(relax, ignore_errors=True)
            added = reg.resolve('B14-H01-r1', 'Q', root=can, overlay_root=addo)
            check('AUDIT P1-5 SPECIFICITY an overlay CAN still add a binding canonical lacks',
                  added['role'] == 'SAFETY' and added['optimizable'] is False)
        finally:
            for d in (can, emptyo, addo):
                shutil.rmtree(d, ignore_errors=True)

        # P1-3: R5 must check required fields, not just the discriminator.
        thin = seed(tempfile.mkdtemp(prefix='s5thin_'),
                    instrument_profiles=[{'entity': 'InstrumentProfile'}])
        try:
            chk.problems[:] = []
            chk.check_r5(reg.load_all(root=thin))
            check('AUDIT P1-3 a row with the right entity and NO required fields is REFUSED '
                  '(probed: R3 and R5 both reported [])',
                  any('missing required field' in p for p in chk.problems), str(chk.problems))
        finally:
            shutil.rmtree(thin, ignore_errors=True)
        full = seed(tempfile.mkdtemp(prefix='s5full_'),
                    instrument_profiles=[{'entity': 'InstrumentProfile', 'profile_id': 'x',
                                          'profile_version': 1, 'content_hash': 'h',
                                          'layer': 'broker'}])
        try:
            chk.problems[:] = []
            chk.check_r5(reg.load_all(root=full))
            check('AUDIT P1-3 SPECIFICITY a row WITH its required fields is accepted',
                  not chk.problems, str(chk.problems))
        finally:
            shutil.rmtree(full, ignore_errors=True)

        print('\n--- the CLI both consumers go through ---')
        py = os.path.join(reg.REPO_ROOT, 'tools', 'python312', 'python.exe')
        p = subprocess.run([py, os.path.join(HERE, 'registry.py'), 'resolve', 'B14-H01-r1'],
                           capture_output=True, text=True, cwd=reg.REPO_ROOT)
        check('the resolve CLI exits 0 and emits JSON against the REAL (empty) store',
              p.returncode == 0 and json.loads(p.stdout) == {}, p.stdout[:120])
        p = subprocess.run([py, os.path.join(HERE, 'registry.py')],
                           capture_output=True, text=True, cwd=reg.REPO_ROOT)
        check('a bad invocation exits 2 (usage), never 0', p.returncode == 2)

        print('\n=== %d passed, %d failed ===' % (len(PASS), len(FAIL)))
        for f in FAIL:
            print('   FAILED: %s' % f)
        return 1 if FAIL else 0
    finally:
        shutil.rmtree(root, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
