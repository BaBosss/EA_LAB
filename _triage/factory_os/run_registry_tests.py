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


# A SYNTHETIC docs/PARAM_REGISTRY.csv, written into every fixture root. The resolver now combines
# the per-hypothesis role with that file's PERMANENT classification (a blind audit found it did
# not, and returned optimizable=True for an input the registry calls INACTIVE), so a fixture root
# without one resolves every parameter to "not in the registry" -- which is correct behaviour and
# useless for testing roles. Positional, index 0 = name and index 10 = classification, matching the
# real file, which has no header row at all.
SYNTHETIC_PARAMS = (
    ('SL_ATR', 'ACTIVE'),
    ('MaxOpen', 'ACTIVE'),
    ('LotBase', 'ACTIVE'),
    ('P', 'ACTIVE'),
    ('Q', 'ACTIVE'),
    ('X', 'ACTIVE'),
    ('Y', 'ACTIVE'),
    ('Z', 'ACTIVE'),
    ('P0', 'ACTIVE'),
    ('P1', 'ACTIVE'),
    ('P2', 'ACTIVE'),
    ('P3', 'ACTIVE'),
    ('P4', 'ACTIVE'),
    ('P5', 'ACTIVE'),
    ('DeadParam', 'INACTIVE'),
    ('SplitMode[BUILD_A]', 'ACTIVE'),
    ('SplitMode[BUILD_B]', 'INACTIVE'),
)


def _write_param_registry(root):
    os.makedirs(os.path.join(root, 'docs'), exist_ok=True)
    with io.open(os.path.join(root, 'docs', 'PARAM_REGISTRY.csv'), 'w',
                 encoding='utf-8', newline='\n') as fh:
        fh.write('> synthetic fixture registry'+chr(10))
        for name, cls in SYNTHETIC_PARAMS:
            cells = [name] + [''] * 9 + [cls, '']
            fh.write(','.join('"%s"' % c for c in cells) + chr(10))
    # ORDER-670 migration: the cache is keyed on (root, MODE), so popping `root` alone stopped
    # clearing anything the moment the mode half was added. A fixture helper that silently
    # stops resetting state is how a later case passes on an earlier case's answer.
    for k in [k for k in reg._CLASSIFICATION_CACHE if k[0] == root]:
        reg._CLASSIFICATION_CACHE.pop(k, None)


def seed(root, **content):
    """Write a full set of synthetic stores; `content[key] = [rows]` overrides one of them."""
    os.makedirs(os.path.join(root, 'factory'), exist_ok=True)
    _write_param_registry(root)
    for rel in reg.STORES:
        rows = content.get(os.path.basename(rel).replace('.jsonl', ''), [])
        with io.open(os.path.join(root, rel.replace('/', os.sep)), 'w',
                     encoding='utf-8', newline='\n') as fh:
            fh.write(reg.canonical_line({'_comment': 'synthetic fixture'}) + '\n')
            for r in rows:
                fh.write(reg.canonical_line(r) + '\n')
    return root


def binding(rev='B14-H01-r1', param='SL_ATR', role='TUNABLE', surface='RESEARCH',
            build_tag=None, **extra):
    # ORDER-672: `parameter` is BARE and the tag is its own field. A fixture that still wrote
    # `SplitMode[BUILD_B]` into the name would be testing the encoding the schema now refuses.
    r = {'entity': 'ParameterBinding', 'hypothesis_revision': rev, 'parameter': param,
         'build_tag': build_tag, 'role': role, 'surface': surface,
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
        t = reg.resolve('B14-H01-r1', 'SL_ATR', root=root, stores=st)
        check('a TUNABLE binding resolves optimizable=True',
              t['optimizable'] is True and t['source'] == 'BOUND', json.dumps(t))
        s = reg.resolve('B14-H01-r1', 'MaxOpen', root=root, stores=st)
        check('a SAFETY binding resolves optimizable=False', s['optimizable'] is False)
        lk = reg.resolve('B14-H01-r1', 'LotBase', root=root, stores=st)
        check('a LOCKED binding carries its locked_value through',
              lk['optimizable'] is False and lk['locked_value'] == 0.01)
        # THE ONE THAT MATTERS: an unbound parameter must not be granted permission by silence.
        u = reg.resolve('B14-H01-r1', 'NeverBound', root=root, stores=st)
        check('an UNBOUND parameter resolves optimizable=None, never True',
              u['optimizable'] is None and u['role'] is None and u['source'] == 'UNBOUND',
              json.dumps(u))
        # The per-hypothesis point of the whole entity: same parameter, other revision.
        o = reg.resolve('B14-H02-r1', 'SL_ATR', root=root, stores=st)
        check('the SAME parameter is UNBOUND in a different revision (bindings are per-revision)',
              o['source'] == 'UNBOUND')
        check('resolve_all returns exactly the parameters bound in that revision',
              sorted(reg.resolve_all('B14-H01-r1', root=root, stores=st)) == ['LotBase', 'MaxOpen', 'SL_ATR'])

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

        print('\n--- ORDER-672: build_tag is a FIELD, and only one file knows the encoding ---')
        # G1 is asserted by ajv in run_schema_fixtures.py (parameterbinding-buildtag-*). Here:
        # G2 -- the R4 sweep can SEE a second parser -- and G3 -- AMBIGUOUS survives the split.
        chk.problems[:] = []
        chk.TAG_PARSE.search('')                       # named so L2 can find the constant
        rogue = "x = re.sub(r'\\[[^\\]]*\\]$', '', name)\n"
        check('G2 the tag-parse pattern MATCHES the suffix-strip idiom itself',
              bool(chk.TAG_PARSE.search(rogue)))
        check('G2 SPECIFICITY it does NOT match a markdown reference-definition regex -- the '
              'loose first version flagged check_coverage_transfer, which is the guard refusing '
              'valid work',
              not chk.TAG_PARSE.search("MD_REF_DEF = re.compile(r'^[ ]{0,3}\\[[^\\]]+\\]:.*$')"))
        check('G2 SPECIFICITY nor an ordinary bracket regex with no end anchor',
              not chk.TAG_PARSE.search("re.compile(r'\\[[^\\]]*\\]')"))
        check('G2 every tag-sweep exemption carries a reason (an exemption without one is a hole)',
              all(isinstance(v, str) and len(v) > 40 for v in chk.TAG_SWEEP_EXEMPT.values()),
              str({k: len(v) for k, v in chk.TAG_SWEEP_EXEMPT.items()}))
        # G3: the AMBIGUOUS path is the PARAM_REGISTRY one, and the split must not have quietly
        # turned it optimizable. A silent permission grant is the failure mode named in the order.
        amb = seed(tempfile.mkdtemp(prefix='s5amb_'),
                   parameter_bindings=[binding(param='SplitMode'),
                                       binding(param='SplitMode', build_tag='BUILD_A')])
        try:
            got = reg.resolve('B14-H01-r1', 'SplitMode', root=amb)
            check('G3 an UNTAGGED binding on a parameter whose CSV rows disagree stays '
                  'NOT optimizable after the field split',
                  got['optimizable'] is False and got['classification'] is None
                  and 'AMBIGUOUS' in (got['classification_source'] or ''), json.dumps(got))
            tagged = reg.resolve('B14-H01-r1', 'SplitMode', build_tag='BUILD_A', root=amb)
            check('G3 SPECIFICITY naming the build RESOLVES it -- the refusal is about the '
                  'question being under-specified, not about the parameter being poisoned',
                  tagged['classification'] == 'ACTIVE', json.dumps(tagged))
        finally:
            shutil.rmtree(amb, ignore_errors=True)
        # WHAT `build_tag: null` MEANS, and this case was written backwards first. The version
        # here a minute earlier asserted that a request naming a build must NOT match an untagged
        # row, reasoning that "no binding for this build" and "a binding for all builds" are
        # different facts. They are -- but null IS the second one (the schema says so), and
        # refusing it made every existing untagged binding invisible the moment optimize_guard
        # started passing --build-tag. Under ORDER-671 that turns every bound parameter into a
        # REFUSAL. Caught by run_registry_tests.ps1 cases B/C/C2 going red, not by re-reading.
        onlybare = seed(tempfile.mkdtemp(prefix='s5ob_'),
                        parameter_bindings=[binding(param='SplitMode')])
        try:
            check('G2 `build_tag: null` means EVERY build, so a request naming one still '
                  'resolves to it',
                  reg.resolve('B14-H01-r1', 'SplitMode', build_tag='BUILD_A',
                              root=onlybare)['source'] == 'BOUND')
        finally:
            shutil.rmtree(onlybare, ignore_errors=True)
        # ...and the fact that IS worth refusing to invent: bound for another build entirely.
        otherbuild = seed(tempfile.mkdtemp(prefix='s5ub_'),
                          parameter_bindings=[binding(param='SplitMode', build_tag='BUILD_B')])
        try:
            check('G2 SPECIFICITY a request for build A where only build B is bound is UNBOUND '
                  '-- the tag is not decoration',
                  reg.resolve('B14-H01-r1', 'SplitMode', build_tag='BUILD_A',
                              root=otherbuild)['source'] == 'UNBOUND')
            check('G2 SPECIFICITY and the exact build still resolves',
                  reg.resolve('B14-H01-r1', 'SplitMode', build_tag='BUILD_B',
                              root=otherbuild)['source'] == 'BOUND')
        finally:
            shutil.rmtree(otherbuild, ignore_errors=True)

        print("\n--- FABLE REVIEW (round 5) ---")
        # F1: the resolver keyed on the exact string while the consumer joined on the base name,
        # so a TAGGED binding was invisible -- and the resolver's own docstring instructs tagged
        # names for multi-build parameters. The two constraints were jointly unsatisfiable.
        tag = seed(tempfile.mkdtemp(prefix='s5tag_'),
                   parameter_bindings=[binding(param='SplitMode', build_tag='BUILD_B',
                                               role='LOCKED', surface='HIDDEN', locked_value=1)])
        try:
            direct = reg.resolve('B14-H01-r1', 'SplitMode', build_tag='BUILD_B', root=tag)
            joined = reg.resolve('B14-H01-r1', 'SplitMode', root=tag)
            check('AUDIT F1 a BARE request joins to a TAGGED binding (probed: it returned UNBOUND, '
                  'silently degrading a LOCKED binding to a note)',
                  joined['source'] == 'BOUND' and joined['role'] == 'LOCKED', json.dumps(joined))
            check('AUDIT F1 and the exact request still works, so the join added a route rather '
                  'than replacing one', direct['role'] == 'LOCKED')
            check('AUDIT F1 resolve_all keys on the BARE name, which is what the consumer looks up',
                  list(reg.resolve_all('B14-H01-r1', root=tag)) == ['SplitMode'],
                  str(list(reg.resolve_all('B14-H01-r1', root=tag))))
        finally:
            shutil.rmtree(tag, ignore_errors=True)
        # ...and the join must REFUSE ambiguity rather than pick one.
        two = seed(tempfile.mkdtemp(prefix='s5two_'),
                   parameter_bindings=[binding(param='SplitMode', build_tag='BUILD_A'),
                                       binding(param='SplitMode', build_tag='BUILD_B',
                                               role='LOCKED', surface='HIDDEN', locked_value=1)])
        try:
            refuses('AUDIT F1 NEG two tagged bindings sharing a bare name make a BARE request '
                    'AMBIGUOUS, not majority-resolved',
                    lambda: reg.resolve('B14-H01-r1', 'SplitMode', root=two),
                    'more than one answer')
            check('AUDIT F1 SPECIFICITY and each EXACT name still resolves to its own row',
                  reg.resolve('B14-H01-r1', 'SplitMode', build_tag='BUILD_A',
                              root=two)['role'] == 'TUNABLE'
                  and reg.resolve('B14-H01-r1', 'SplitMode', build_tag='BUILD_B',
                                  root=two)['role'] == 'LOCKED')
        finally:
            shutil.rmtree(two, ignore_errors=True)
        # F4: LOCKED must carry a VALUE, not just the key.
        nul = seed(tempfile.mkdtemp(prefix='s5nul_'),
                   parameter_bindings=[binding(param='Z', role='LOCKED', surface='HIDDEN',
                                               locked_value=None)])
        try:
            refuses('AUDIT F4 role=LOCKED with locked_value=NULL is REFUSED (probed: the check '
                    'tested presence while its own message is about the value)',
                    lambda: reg.resolve('B14-H01-r1', 'Z', root=nul), 'is not a lock')
        finally:
            shutil.rmtree(nul, ignore_errors=True)
        zero = seed(tempfile.mkdtemp(prefix='s5zero_'),
                    parameter_bindings=[binding(param='Z', role='LOCKED', surface='HIDDEN',
                                                locked_value=0)])
        try:
            check('AUDIT F4 SPECIFICITY locked_value=0 is still a real lock, not falsy-rejected',
                  reg.resolve('B14-H01-r1', 'Z', root=zero)['locked_value'] == 0)
        finally:
            shutil.rmtree(zero, ignore_errors=True)

        print("\n--- BLIND AUDIT ROUND 4 ---")
        # S7: the resolver must combine BOTH layers. Its docstring said it did; it did not.
        both = seed(tempfile.mkdtemp(prefix='s5comb_'),
                    parameter_bindings=[binding(param='SplitMode', build_tag='BUILD_B'),
                                        binding(param='SplitMode', build_tag='BUILD_A'),
                                        binding(param='SplitMode'),
                                        binding(param='DeadParam'),
                                        binding(param='SL_ATR')])
        try:
            dead = reg.resolve('B14-H01-r1', 'DeadParam', root=both)
            check('AUDIT S7 a TUNABLE binding on an INACTIVE parameter is NOT optimizable '
                  '(probed: it returned True, ignoring PARAM_REGISTRY entirely)',
                  dead['role'] == 'TUNABLE' and dead['classification'] == 'INACTIVE'
                  and dead['optimizable'] is False, json.dumps(dead))
            live = reg.resolve('B14-H01-r1', 'SL_ATR', root=both)
            check('AUDIT S7 SPECIFICITY a TUNABLE binding on an ACTIVE parameter still IS',
                  live['optimizable'] is True, json.dumps(live))
            # The tag collision the audit's example actually rests on.
            tagged_dead = reg.resolve('B14-H01-r1', 'SplitMode', build_tag='BUILD_B', root=both)
            tagged_live = reg.resolve('B14-H01-r1', 'SplitMode', build_tag='BUILD_A', root=both)
            check('AUDIT S7 a build-TAGGED name resolves to ITS OWN row, both ways',
                  tagged_dead['optimizable'] is False and tagged_live['optimizable'] is True,
                  '%s / %s' % (tagged_dead['classification'], tagged_live['classification']))
            bare = reg.resolve('B14-H01-r1', 'SplitMode', root=both)
            check('AUDIT S7 an UNTAGGED name whose tagged rows DISAGREE is AMBIGUOUS, not the '
                  'majority answer (probed: stripping the tag was last-wins across 8 real rows)',
                  bare['classification'] is None and bare['optimizable'] is False
                  and 'AMBIGUOUS' in (bare['classification_source'] or ''),
                  json.dumps(bare))
        finally:
            shutil.rmtree(both, ignore_errors=True)
        # An unparseable / absent registry must REFUSE, never resolve everything to UNKNOWN quietly.
        noreg = tempfile.mkdtemp(prefix='s5noreg_')
        try:
            os.makedirs(os.path.join(noreg, 'factory'))
            refuses('AUDIT S7 an ABSENT PARAM_REGISTRY is REFUSED, not defaulted to live',
                    lambda: reg._classifications(noreg), 'Refused rather than defaulted')
        finally:
            shutil.rmtree(noreg, ignore_errors=True)
        # resolve_all must carry the root through -- it did not, so answers came from two trees.
        rt = seed(tempfile.mkdtemp(prefix='s5rt_'),
                  parameter_bindings=[binding(param='DeadParam')])
        try:
            check('AUDIT S7 resolve_all carries `root` through to resolve (probed: it did not, so '
                  'bindings came from one tree and classifications from another)',
                  reg.resolve_all('B14-H01-r1', root=rt)['DeadParam']['classification']
                  == 'INACTIVE')
        finally:
            shutil.rmtree(rt, ignore_errors=True)

        print("\n--- BLIND AUDIT ROUND 3 ---")
        # R3 must scan METADATA records too -- "a verdict key at any depth" said nothing about
        # rows, and a note is still bytes in the store.
        note = seed(tempfile.mkdtemp(prefix='s5note_'))
        try:
            with io.open(os.path.join(note, 'factory', 'hypotheses.jsonl'), 'w',
                         encoding='utf-8', newline=chr(10)) as fh:
                fh.write(reg.canonical_line(
                    {'_comment': 'note', 'verdict': 'DEAD-STRUCTURAL'}) + chr(10))
            chk.problems[:] = []
            chk.check_r3(reg.load_all(root=note))
            check('AUDIT R3 a verdict inside a METADATA record is REFUSED '
                  '(probed: rows-only scan reported [])',
                  any(p.startswith('R3') for p in chk.problems), str(chk.problems))
        finally:
            shutil.rmtree(note, ignore_errors=True)
        clean = seed(tempfile.mkdtemp(prefix='s5cln_'))
        try:
            chk.problems[:] = []
            chk.check_r3(reg.load_all(root=clean))
            check('AUDIT R3 SPECIFICITY an ordinary metadata note is still accepted',
                  not chk.problems, str(chk.problems))
        finally:
            shutil.rmtree(clean, ignore_errors=True)

        # L0's completeness claim must cover the PowerShell checkers it never saw.
        import run_guard_shape_lint as lint
        check('AUDIT L0 discovery covers scripts/check_*.ps1, not only the python directory',
              any('scripts/check_*.ps1' in g for g in lint.CHECKER_GLOBS), str(lint.CHECKER_GLOBS))
        pr = []
        lint.lint_l0(pr, present=['scripts/check_brand_new.ps1'])
        check('AUDIT L0 an UNDECLARED PowerShell checker is REFUSED (probed: 11 existed, 0 seen)',
              bool(pr), str(pr))
        pr = []
        lint.lint_l0(pr, present=['scripts/check_state.ps1'])
        check('AUDIT L0 SPECIFICITY a DECLARED PowerShell checker is accepted', not pr, str(pr))
        check('AUDIT L0 and every declared-unparseable entry carries a REASON, not just a name',
              all(isinstance(v, str) and len(v) > 10 for v in lint.L1_NOT_PARSED.values()))

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

        print('\n--- ORDER-670: a checker judges the COMMIT (T1/T2/T3/T5) ---')
        import evidence as evd

        def _git(groot, *args):
            # NEVER inherit GIT_INDEX_FILE into a fixture repo. Discovered live: under this
            # repo's pre-commit hook that variable names the REAL commit's temp index; a
            # fixture `add -A` resolved it against the fixture repo and DELETED all 5,135
            # real entries from the commit being made. The fixture repos own their indexes.
            env = {k: v for k, v in os.environ.items() if k != 'GIT_INDEX_FILE'}
            return subprocess.run(['git', '-C', groot] + list(args),
                                  capture_output=True, env=env)

        # T1 -- the attack this whole order exists for, and its mirror. One temp repo,
        # one corruption, judged from both snapshots.
        t1 = seed(tempfile.mkdtemp(prefix='s5evd1_'))
        try:
            _git(t1, 'init', '-q')
            _git(t1, 'add', '-A')
            hyp = os.path.join(t1, 'factory', 'hypotheses.jsonl')
            clean = io.open(hyp, encoding='utf-8').read()
            corrupt = clean + '{"entity": "Hypothesis", "status": "DEAD-STRUCTURAL"}\n'
            src_i = evd.EvidenceSource('index', root=t1)
            src_w = evd.EvidenceSource('worktree', root=t1)

            with io.open(hyp, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(corrupt)
            chk.problems[:] = []
            chk.check_r3(reg.load_all(root=t1, source=src_i))
            check('T1 index mode judges the INDEX: a worktree-only corruption is invisible '
                  '(it is not in the commit)', not any(p.startswith('R3') for p in chk.problems),
                  str(chk.problems))
            chk.problems[:] = []
            chk.check_r3(reg.load_all(root=t1, source=src_w))
            check('T1 worktree mode still sees the disk (manual-run semantics preserved)',
                  any(p.startswith('R3') for p in chk.problems))

            # THE ATTACK (ORDER-615 S1's shape): stage the corruption, restore the worktree.
            _git(t1, 'add', 'factory/hypotheses.jsonl')
            with io.open(hyp, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(clean)
            chk.problems[:] = []
            chk.check_r3(reg.load_all(root=t1, source=src_i))
            check('T1 ATTACK staged corruption behind a clean worktree copy is RED in index '
                  'mode -- the bytes entering history are the ones judged',
                  any(p.startswith('R3') for p in chk.problems))
            chk.problems[:] = []
            chk.check_r3(reg.load_all(root=t1, source=src_w))
            check('T1 ATTACK and worktree mode is blind to it -- the exact pre-670 blindness, '
                  'now confined to manual runs that say so in their marker',
                  not any(p.startswith('R3') for p in chk.problems), str(chk.problems))

            # T1 ENGAGEMENT: in worktree mode the new reader returns the same text the old
            # io.open read did -- the migration must not change what a normal run judges.
            old_way = io.open(hyp, encoding='utf-8').read().replace('\r\n', '\n')
            check('T1 ENGAGEMENT worktree read_committed is byte-identical to the direct read',
                  src_w.read_committed('factory/hypotheses.jsonl') == old_way)

            # T5 -- category B untouched: observe() reads the DISK even where the index
            # holds different bytes, and refuses nothing that is stable.
            data, st = evd.observe(hyp)
            check('T5 observe() returns the DISK bytes while the index disagrees '
                  '(category B is the world, not the commit)',
                  data.decode('utf-8').replace('\r\n', '\n') == clean and st.st_size > 0)
        finally:
            shutil.rmtree(t1, ignore_errors=True)

        # T1/RESOLVER -- the migration of registry.py's OWN read (ORDER-670, design section 6).
        # Until this commit `resolve()` answered "may this run optimize this parameter" from
        # docs/PARAM_REGISTRY.csv on the WORKING TREE, while the tier that consumes the answer
        # runs as a pre-commit hook. A staged classification flip was therefore invisible to it.
        t1r = seed(tempfile.mkdtemp(prefix='s5evd1r_'))
        try:
            _git(t1r, 'init', '-q')
            _git(t1r, 'add', '-A')
            csv_path = os.path.join(t1r, 'docs', 'PARAM_REGISTRY.csv')
            clean_csv = io.open(csv_path, encoding='utf-8').read()
            dead = clean_csv.replace('"SL_ATR","","","","","","","","","","ACTIVE",""',
                                     '"SL_ATR","","","","","","","","","","INACTIVE",""')
            check('T1/RESOLVER the fixture flip is a real edit (guards the case against a '
                  'search string that matches nothing)', dead != clean_csv)
            sr_i = evd.EvidenceSource('index', root=t1r)
            sr_w = evd.EvidenceSource('worktree', root=t1r)

            # THE ATTACK: stage "this dial is dead", restore the live worktree copy.
            with io.open(csv_path, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(dead)
            _git(t1r, 'add', 'docs/PARAM_REGISTRY.csv')
            with io.open(csv_path, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(clean_csv)
            _write_param_registry(t1r)          # restore + clear the cache for this root
            with io.open(csv_path, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(clean_csv)
            check('T1/RESOLVER ATTACK index mode reads the STAGED classification (INACTIVE) '
                  'while the worktree says ACTIVE -- the resolver now judges the commit',
                  reg.classification_of('SL_ATR', root=t1r, source=sr_i)[0] == 'INACTIVE',
                  str(reg.classification_of('SL_ATR', root=t1r, source=sr_i)))
            check('T1/RESOLVER ATTACK worktree mode still answers ACTIVE -- the pre-670 '
                  'blindness, confined to manual runs that say so',
                  reg.classification_of('SL_ATR', root=t1r, source=sr_w)[0] == 'ACTIVE')
            # ... and the answer reaches the DECISION, not just the lookup
            stores = reg.load_all(root=t1r, source=sr_i)
            check('T1/RESOLVER ATTACK the staged classification reaches resolve(): a dead dial '
                  'is not optimizable',
                  not reg.resolve('B14-H01-r1', 'SL_ATR', root=t1r, stores=stores,
                                  source=sr_i)['optimizable'])

            # SPECIFICITY 1 -- the cache must not serve one vintage's answer to the other. Keyed
            # on the root alone (as it was), the FIRST call above would have decided for both.
            check('T1/RESOLVER SPECIFICITY the classification cache is keyed on (root, mode) -- '
                  'index and worktree answers coexist rather than overwrite',
                  reg.classification_of('SL_ATR', root=t1r, source=sr_i)[0] == 'INACTIVE'
                  and reg.classification_of('SL_ATR', root=t1r, source=sr_w)[0] == 'ACTIVE')
            # SPECIFICITY 1b (/scrutinize round 2) -- the cache key must follow the SOURCE's
            # root, not the `root` argument. A caller passing (root=None, source=rooted-at-t1)
            # would otherwise cache t1's table under REPO_ROOT's key, where the next
            # repo-rooted call inherits a fixture's answers.
            check('T1/RESOLVER SPECIFICITY a source-rooted lookup with root=None does not '
                  'poison the real repo\'s cache slot',
                  reg.classification_of('SL_ATR', source=sr_i)[0] == 'INACTIVE'
                  and (reg.REPO_ROOT, 'index') not in reg._CLASSIFICATION_CACHE)

            # SPECIFICITY 2 -- with nothing staged-but-different, the migration changes NOTHING
            _git(t1r, 'add', 'docs/PARAM_REGISTRY.csv')
            _write_param_registry(t1r)
            with io.open(csv_path, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write(clean_csv)
            check('T1/RESOLVER SPECIFICITY with nothing staged differently, index and worktree '
                  'and the un-migrated no-source path all agree',
                  (reg.classification_of('SL_ATR', root=t1r, source=sr_i)[0]
                   == reg.classification_of('SL_ATR', root=t1r, source=sr_w)[0]
                   == reg.classification_of('SL_ATR', root=t1r)[0] == 'ACTIVE'))
        finally:
            shutil.rmtree(t1r, ignore_errors=True)

        # T-P -- category P finally has a CALL (ORDER-670 migration 5/9). Design section 2 named
        # `read_blob`; part 1 shipped without it, so `# snapshot: blob` was a declaration with no
        # mechanism -- and T7 must keep allowing that word on a bare open() for exactly as long
        # as that stays true.
        tp = tempfile.mkdtemp(prefix='s5evdp_')
        try:
            _git(tp, 'init', '-q')
            yard = os.path.join(tp, 'yardstick.txt')
            with io.open(yard, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write('the pinned value\n')
            _git(tp, 'add', '-A')
            _git(tp, '-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-qm', 'x')
            sha = subprocess.run(['git', '-C', tp, 'rev-parse', 'HEAD:yardstick.txt'],
                                 capture_output=True, text=True,
                                 env={k: v for k, v in os.environ.items()
                                      if k != 'GIT_INDEX_FILE'}).stdout.strip()
            sp_i = evd.EvidenceSource('index', root=tp)
            sp_w = evd.EvidenceSource('worktree', root=tp)

            # THE ATTACK: move the path the pin came from. A pin that follows the path is not
            # a pin -- it is A2's crime, a live vintage substituted for a pinned one.
            with io.open(yard, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write('MOVED\n')
            _git(tp, 'add', '-A')
            check('T-P ATTACK read_blob returns the PINNED bytes after the path it came from '
                  'was rewritten AND staged',
                  sp_i.read_blob(sha, 'the yardstick') == b'the pinned value\n')
            check('T-P SPECIFICITY the mode is irrelevant to a pin -- index and worktree '
                  'sources return identical bytes for one sha',
                  sp_i.read_blob(sha, 'x') == sp_w.read_blob(sha, 'x'))
            # ToolFailure, NOT RegistryRefusal: "I cannot read the yardstick" and "I will not
            # answer for this input" are different facts with different exit codes, and the
            # generic `refuses` helper above would have silently accepted either.
            def _tool_failure(label, fn, needle):
                try:
                    fn()
                except evd.ToolFailure as exc:
                    check(label, needle in str(exc), 'refused, but not for that: %s'
                          % str(exc)[:140])
                except Exception as exc:                       # noqa: BLE001
                    check(label, False, 'raised %s, not ToolFailure' % type(exc).__name__)
                else:
                    check(label, False, 'it was ACCEPTED')

            _tool_failure('T-P an unknown object is a ToolFailure, never a read of that path '
                          'as it stands today',
                          lambda: sp_i.read_blob('0' * 40, 'the yardstick'), 'no substitute')
            _tool_failure('T-P a PATH passed where a sha belongs is refused, so callers cannot '
                          'drift back into path reads',
                          lambda: sp_i.read_blob('yardstick.txt', 'the yardstick'),
                          'not an object name')
            # ENGAGEMENT: the real generator's baseline is byte-identical through the new call.
            import gen_coverage as gcv
            old = _git(reg.REPO_ROOT, 'cat-file', 'blob', gcv.BASELINE_BLOB)
            check('T-P ENGAGEMENT gen_coverage baseline through read_blob is byte-identical to '
                  'the cat-file route it replaced (the migration changed no output)',
                  old.returncode == 0
                  and gcv.baseline_text() == old.stdout.decode('utf-8').replace('\r\n', '\n'))
        finally:
            shutil.rmtree(tp, ignore_errors=True)

        # T2 -- no silent fallback, all three refusal legs.
        t2 = seed(tempfile.mkdtemp(prefix='s5evd2_'))
        try:
            _git(t2, 'init', '-q')
            _git(t2, 'add', '-A')
            _git(t2, 'rm', '--cached', '-q', 'factory/hypotheses.jsonl')
            src_i2 = evd.EvidenceSource('index', root=t2)
            refuses('T2 an untracked store in hook mode is REFUSED even though it exists on '
                    'disk -- readable-from-worktree must buy nothing',
                    lambda: reg.load_all(root=t2, source=src_i2), 'not present')
            try:
                evd.EvidenceSource('indx')
                check('T2 a typo mode is refused, not defaulted', False)
            except evd.ToolFailure as exc:
                check('T2 a typo mode is refused, not defaulted', 'refused' in str(exc))
            broken = evd.EvidenceSource(
                'index', root=t2,
                _git=lambda *a: (0, b'', b'') if a[0] == 'ls-files' else (128, b'', b'boom'))
            try:
                broken.read_committed('factory/coverage.jsonl')
                check('T2 tracked-but-unreadable is a ToolFailure, never a worktree read', False)
            except evd.ToolFailure as exc:
                check('T2 tracked-but-unreadable is a ToolFailure, never a worktree read',
                      'not readable' in str(exc))
        finally:
            shutil.rmtree(t2, ignore_errors=True)

        # T3 -- ENUMERATION comes from the index: the staged rogue file whose worktree copy
        # was deleted (design 3.2, the attack that matters most).
        t3 = tempfile.mkdtemp(prefix='s5evd3_')
        try:
            fdir = os.path.join(t3, '_triage', 'factory_os')
            os.makedirs(fdir)
            rogue = os.path.join(fdir, 'rogue.py')
            with io.open(rogue, 'w', encoding='utf-8', newline='\n') as fh:
                fh.write("x = 'TUNABLE'\ny = 'LOCKED'\n")
            _git(t3, 'init', '-q')
            _git(t3, 'add', '-A')
            os.remove(rogue)  # staged, absent from the disk -- glob can never see it
            with io.open(os.path.join(fdir, 'scratch.py'), 'w',
                         encoding='utf-8', newline='\n') as fh:
                fh.write("a = 'TUNABLE'\nb = 'LOCKED'\n")  # on disk, NOT staged
            saved_cons = dict(chk.RESOLVER_CONSUMERS)
            try:
                chk.RESOLVER_CONSUMERS.clear()
                s3i = evd.EvidenceSource('index', root=t3)
                s3w = evd.EvidenceSource('worktree', root=t3)
                chk.problems[:] = []
                chk.check_r4(s3i)
                check('T3 ATTACK a STAGED rogue vocabulary with no worktree copy is RED in '
                      'index mode -- the commit is what gets swept',
                      any('rogue.py' in p for p in chk.problems), str(chk.problems))
                check('T3 SPECIFICITY the untracked scratch file neither flags nor fails the '
                      'run -- the commit never had it',
                      not any('scratch.py' in p for p in chk.problems), str(chk.problems))
                chk.problems[:] = []
                chk.check_r4(s3w)
                check('T3 worktree mode is the mirror: scratch seen, rogue invisible -- the '
                      'blindness this order confines to manual runs',
                      any('scratch.py' in p for p in chk.problems)
                      and not any('rogue.py' in p for p in chk.problems), str(chk.problems))
            finally:
                chk.RESOLVER_CONSUMERS.clear()
                chk.RESOLVER_CONSUMERS.update(saved_cons)
        finally:
            shutil.rmtree(t3, ignore_errors=True)

        # T-GIF -- GIT_INDEX_FILE containment, both directions. THE INCIDENT: under a real
        # pre-commit, fixture `git add -A` inherited the hook's GIT_INDEX_FILE, resolved it
        # against the FIXTURE repo, and deleted all 5,135 real entries from the commit's
        # temp index. These cases are the attack replayed and the honoured-side control.
        tg = tempfile.mkdtemp(prefix='s5gif_')
        decoy = os.path.join(tg, 'decoy_index')
        saved_gif = os.environ.get('GIT_INDEX_FILE')
        try:
            subprocess.run(['git', '-C', reg.REPO_ROOT, 'read-tree', 'HEAD'],
                           capture_output=True,
                           env=dict(os.environ, GIT_INDEX_FILE=decoy))
            subprocess.run(['git', '-C', reg.REPO_ROOT, 'update-index', '--force-remove',
                            'factory/coverage.jsonl'], capture_output=True,
                           env=dict(os.environ, GIT_INDEX_FILE=decoy))
            with io.open(decoy, 'rb') as fh:
                decoy_before = fh.read()
            os.environ['GIT_INDEX_FILE'] = decoy
            frepo = os.path.join(tg, 'fx')
            os.makedirs(frepo)
            with io.open(os.path.join(frepo, 'own.txt'), 'w', encoding='utf-8') as fh:
                fh.write('x\n')
            _git(frepo, 'init', '-q')
            _git(frepo, 'add', '-A')  # THE ATTACK LINE: pre-fix, this rewrote the decoy
            with io.open(decoy, 'rb') as fh:
                decoy_after = fh.read()
            check('T-GIF ATTACK fixture git ops under a hook-set GIT_INDEX_FILE leave the '
                  'real index BYTE-UNCHANGED (pre-fix: add -A emptied it to one file)',
                  decoy_before == decoy_after)
            check('T-GIF and the fixture repo used its OWN index -- its staged file is there',
                  evd.EvidenceSource('index', root=frepo).exists_committed('own.txt'))
            check('T-GIF SPECIFICITY for THIS repo the variable is still honoured -- the '
                  'decoy index (coverage removed) answers, not .git/index',
                  not evd.EvidenceSource('index', root=reg.REPO_ROOT)
                  .exists_committed('factory/coverage.jsonl'))
            # Windows paths are case-insensitive: the real repo spelled in a different case
            # is STILL the real repo, and must still honour the variable. Pre-normcase, this
            # spelling was scrubbed -- silently judging .git/index instead of the hook's
            # temp index for any caller that spelled the root differently.
            check('T-GIF SPECIFICITY a case-variant spelling of the real root is not scrubbed',
                  not evd.EvidenceSource('index', root=reg.REPO_ROOT.lower())
                  .exists_committed('factory/coverage.jsonl'))
        finally:
            if saved_gif is None:
                os.environ.pop('GIT_INDEX_FILE', None)
            else:
                os.environ['GIT_INDEX_FILE'] = saved_gif
            shutil.rmtree(tg, ignore_errors=True)

        # End to end through the real CLI, both modes pinned explicitly (the suite may itself
        # be running under a hook-set EA_LAB_EVIDENCE; these cases must not inherit it blind).
        py_exe = os.path.join(reg.REPO_ROOT, 'tools', 'python312', 'python.exe')
        for mode in ('worktree', 'index'):
            env = dict(os.environ)
            env['EA_LAB_EVIDENCE'] = mode
            p = subprocess.run([py_exe, os.path.join(HERE, 'check_registries.py')],
                               capture_output=True, text=True, cwd=reg.REPO_ROOT, env=env)
            ok = (p.returncode == 0
                  and ('##EVIDENCE-MODE## check_registries.py %s' % mode) in p.stdout)
            diag = p.stdout[-300:]
            if not ok:
                gi = os.environ.get('GIT_INDEX_FILE')
                ls = subprocess.run(['git', '-C', reg.REPO_ROOT, 'ls-files', '--cached'],
                                    capture_output=True, text=True)
                names = ls.stdout.split()
                diag += ' | DIAG GIT_INDEX_FILE=%r exists=%s size=%s ls_rc=%d n=%d head=%r err=%r' % (
                    gi, os.path.isfile(gi) if gi else None,
                    os.path.getsize(gi) if gi and os.path.isfile(gi) else None,
                    ls.returncode, len(names), names[:8], ls.stderr[-120:])
            check('CLI real repo, %s mode: exit 0 and the marker states the mode' % mode,
                  ok, diag)

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
