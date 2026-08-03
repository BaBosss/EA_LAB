# -*- coding: utf-8 -*-
"""check_registries.py -- ORDER-630 (slice S5). The guard over the Factory registries.

THE DESIGN'S S5 ACCEPTANCE, ONE CRITERION EACH:
  R1  round-trip deterministic -- every stored line equals its canonical re-serialisation.
  R2  `NOT_APPLICABLE` is refused without a reason.
  R3  NO VERDICT FIELD in any of these files.
  R4  the generator and optimize_guard provably read ONE resolver.
  R5  every row carries the ONE entity its store holds, AND that entity's required fields.
      (NOT full schema validation -- see the note on it below.)
  R6  a store declared BLOCKED must actually be absent, and its blocker must still hold.

WHAT EACH ONE ACTUALLY PROVES, because three of them are easy to oversell:

  R3 is the one this repo has already been burned by. `check_s2a_migration`'s A3 checked key
  NAMES and never VALUES, so `"status": "DEAD-STRUCTURAL"` carried a verdict into a store whose
  entire acceptance forbids one (docs/GUARD_SHAPES.md, shape 2). So R3 checks BOTH ends: a closed
  set of forbidden key names AND a closed set of forbidden VALUES, the latter being the canonical
  verdict vocabulary out of CLAUDE.md. A field called `state` holding `DEAD-OPTIMIZED` is a
  verdict, whatever it is named.

  R4 cannot prove two programs compute the same thing -- that is the same impossibility ORDER-614
  rev 2 had to state out loud, and pretending otherwise here would be the same defect. What it
  proves is narrower and is stated in the failure text: (a) the role/surface vocabulary and the
  optimizable derivation exist in exactly ONE file, and (b) every declared consumer reaches that
  file. A consumer that calls the resolver and then ignores the answer is NOT caught by this, and
  saying so is why the check is worth having.

  R5 was WORSE THAN ITS OWN DESCRIPTION until a blind audit read the two side by side. It said
  "every row validates against the ONE entity its store is declared to hold" and it compared the
  DISCRIMINATOR STRING and nothing else, so `{"entity": "InstrumentProfile"}` -- every required
  field missing -- passed with R3 and R5 both reporting []. Shape 2, inside the check written to
  enforce shape 2. It now also checks the entity's REQUIRED FIELDS, read out of schemas.json so
  there is no second copy of the list. It is still not full validation: ajv is the validator and it
  runs in run_schema_fixtures.py, which this tier has no node budget for. The description above
  says required-field floor because that is what it is.

  R2 is scoped: it is the CoverageCell rule (a NOT_APPLICABLE cell must carry a reason of real
  length). The schema says so too, in an `allOf`; this repeats it because the schema gate is an
  ajv subprocess that the fast tier does not pay for, so on the fast path R2 is the only thing
  enforcing it.

USAGE  tools\\python312\\python.exe _triage/factory_os/check_registries.py
EXIT   0 = every criterion holds - 1 = a violation - 2 = the checker could not read its inputs
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import registry as reg  # noqa: E402
import evidence as ev  # noqa: E402

ROOT = reg.REPO_ROOT


def _default_src():
    """Manual-run semantics when a criterion is invoked directly (the test suite does this).

    main() always passes the for_run() source explicitly; this default exists so that calling
    a criterion by hand judges the worktree, which is what a hand run means. It is NOT a hook
    fallback -- in hook mode the tier sets the env and for_run() returns index.
    """
    return ev.EvidenceSource('worktree', root=ROOT)

# R3, half one: key NAMES that may never appear in a registry row, at any depth.
FORBIDDEN_VERDICT_KEYS = ('verdict', 'reconciliation_clear', 'all_clear', 'pass', 'passed',
                          'outcome', 'conclusion', 'judgement', 'judgment', 'ruling')

# R3 IS A BLACKLIST, AND SAYING SO IS PART OF IT. GUARD_SHAPES shape 2 asks: "is this a
# blacklist? if so, what is the allowlist?" PROBED 2026-07-31, four things walk past the value
# list and only one was closable:
#   a verdict as a dict KEY (`{"DEMO": 1}`)     -> CLOSED below, keys are checked against both sets
#   a NUMBER-coded verdict (`{"state": 1}`)     -> NOT closable by any value list
#   a verdict split across two fields           -> NOT closable
#   a verdict word nobody listed (`APPROVED`)   -> the definition of a blacklist's limit
#
# THE ALLOWLIST EXISTS AND IT IS NOT THIS CHECK. Every registry entity in schemas.json is
# `unevaluatedProperties: false`, so a row cannot acquire an undeclared field AT ALL -- that is the
# closed end, and R5 is what keeps each store bound to one such entity. R3 is the second line, for
# a verdict smuggled into a field that IS declared. Read on its own it would oversell itself, which
# is why the two halves are named together here.
#
# R3, half two: VALUES that are verdicts wherever they appear, under whatever key. This is the
# canonical verdict vocabulary from CLAUDE.md's VERDICT GATE plus the retired terms it names, so a
# store cannot smuggle one in under a neutral key like `state` or `label`.
FORBIDDEN_VERDICT_VALUES = ('DEAD-STRUCTURAL', 'DEAD-OPTIMIZED', 'PARKED-VERIFY', 'BUILD-ON',
                            'CANDIDATE', 'DEMO', 'LIVE', 'VALIDATED', 'ROBUST', 'MARGINAL',
                            'CONDITIONAL')

# Values that LOOK like verdicts but are a declared part of an entity's own closed vocabulary.
# A closed declaration in code, not a substring exemption: each entry names the exact
# (store, key, value) triple it excuses and why. `unowned_evidence` was defeated by an exemption
# broad enough to cover everything (memory: citation-guard-satisfied-by-a-universal-file).
VERDICT_VALUE_EXEMPTIONS = {
    ('factory/coverage.jsonl', 'status', 'LIVE'):
        'CoverageCell imported rows use `status: LIVE` to mean "this symbol x TF is traded '
        'live", which is a FACT about deployment, not a verdict about an edge. Transcribed by '
        "ORDER-610's transfer from MASTER_BACKLOG section 2 and pinned to its source blob.",
}

# ORDER-1251. Word-boundary, not substring: `LIVE` must not fire inside `DELIVERED`, and
# `CANDIDATE` must not fire inside `CANDIDATES-ONLY`. The class excludes `-` as well as word
# characters because every compound verdict already contains one -- without that, `BUILD-ON`
# would match inside `BUILD-ONLY`. Case-insensitive: the rule is about content, and a lowercase
# verdict is still a verdict (the ORDER-1220 matcher was case-sensitive and missed a real heading).
_VERDICT_WORD_RX = tuple(
    (w, re.compile(r'(?<![A-Za-z0-9_-])' + re.escape(w) + r'(?![A-Za-z0-9_-])', re.I))
    for w in FORBIDDEN_VERDICT_VALUES)


def _verdict_word_in(value):
    """-> the first verdict word appearing as a WORD inside `value`, or None."""
    for word, rx in _VERDICT_WORD_RX:
        if rx.search(value):
            return word
    return None


# R4: the ONE file allowed to define the role vocabulary or derive optimizability.
RESOLVER = '_triage/factory_os/registry.py'
# Consumers that MUST reach the resolver, and the token that proves each one does. Declared, so
# that adding a consumer and forgetting to wire it is a violation rather than a silence.
RESOLVER_CONSUMERS = {
    'scripts/optimize_guard.ps1': 'factory_os/registry.py',
}
# Files exempt from the "no second copy of the vocabulary" sweep, each with a reason.
RESOLVER_SWEEP_EXEMPT = {
    RESOLVER: 'is the resolver',
    '_triage/factory_os/schemas.json': 'declares the enum the resolver validates against; a '
                                       'contract and its implementation are not two copies',
    '_triage/factory_os/check_registries.py': 'this file, which must name what it forbids',
    '_triage/factory_os/run_registry_tests.py': 'the suite, which must name what it asserts',
    '_triage/factory_os/CONTRACTS.md': 'a GENERATED projection of schemas.json',
    '_triage/factory_os/run_param_surface_tests.py':
        'ORDER-1020: the CAGE for the state-table checker. Its attacks corrupt `role` fields to '
        'prove P2 can fire -- naming the values it must be able to break is what an attack IS. It '
        'derives no optimizability from any of them; that stays with the resolver, which '
        'check_param_surface reaches through registry.ROLES/SURFACES. Same reason '
        'run_registry_tests.py is exempt two entries down.',
    '_triage/factory_os/hypothesis_b14.py':
        'ORDER-1020: it is the DECISION TABLE, not a resolver. It records which role a human chose '
        'for each parameter of B14-H01/H02 and never derives optimizability from one -- that stays '
        'with the resolver, which gen_registry_rows.py calls. And the naming is not on trust: the '
        'module validates every role and surface it names against registry.ROLES/SURFACES at '
        'import, so it cannot introduce a value the resolver does not know. Sweeping it would '
        'leave no legal place to WRITE a binding down.',
    '_triage/factory_os/run_contract_binding_tests.py':
        'MEASURED: it names the role enum as SCHEMA MUTATION material -- it deletes values from '
        'ParameterBinding.role to prove the design<->schema binding goes red. It never decides '
        'whether a parameter is optimizable, which is what a second resolver would do.',
}

# ORDER-672 G2: files exempt from the TAG-PARSE sweep specifically. Separate from the vocabulary
# exemptions above on purpose -- a file may legitimately do one and not the other, and one list
# covering both would excuse more than it examined.
TAG_SWEEP_EXEMPT = {
    RESOLVER: 'owns the encoding in both directions (bare_registry_name / registry_name)',
    '_triage/factory_os/check_registries.py': 'this file, which must name the shape it forbids',
    '_triage/factory_os/run_registry_tests.py': 'the suite, which must name what it asserts',
    'scripts/optimize_guard.ps1':
        "MEASURED, not waved through: its Split-NameTag parses docs/PARAM_REGISTRY.csv NAMES -- "
        "the CSV boundary, where the encoding genuinely exists because this repo does not own "
        "that file's format. It is NOT parsing a ParameterBinding, which is what ORDER-672 "
        "removed the need for. RESIDUAL RISK, stated because an exemption without one is a hole: "
        "this is a SECOND implementation of the same decode, in a language that cannot call the "
        "Python one, so the two could drift. What bounds the damage is that the DECISION "
        "(optimizable) comes from the resolver -- R4(a) requires this file reference it -- and "
        "Split-NameTag only reaches the CSV row. Closing it properly means a shared decoder, "
        "which is a PowerShell/Python bridge and its own order.",
}
# The tokens whose duplication would mean a second resolver. Two roles that only ever appear
# together in a decision, not the whole enum.
ROLE_PAIR = re.compile(r'TUNABLE')
ROLE_PAIR2 = re.compile(r'LOCKED')

# ORDER-672 G2. A SECOND PARSER OF THE BUILD-TAG STRING IS A SECOND RESOLVER, and the role-pair
# sweep above cannot see one -- a file can strip `[LAB_ENTRY_16]` off a name without ever writing
# the word TUNABLE. This is not hypothetical: `preset.py` grew its own `re.sub(r'\[[^\]]*\]$', ...)`
# and carried it for a day, in the same batch that split the field out precisely to stop that.
#
# The pattern matches the SHAPE of the surgery (a bracket-suffix strip or an equivalent split),
# not a specific spelling, because the point is that only registry.py may know the encoding.
#
# TIGHTENED ON ITS FIRST RUN, and the loose version is worth recording. `\[[^\]]` followed by
# anything then `$` also matches `^[ ]{0,3}\[[^\]]+\]:.*$` -- check_coverage_transfer's MARKDOWN
# REFERENCE-DEFINITION regex, which has nothing to do with build tags. A guard that refuses valid
# work is the failure the Decision log recorded on 2026-07-30, so the pattern names the exact
# idiom (a bracket suffix stripped at END OF STRING) instead of anything bracket-shaped.
TAG_PARSE = re.compile(r"""
    \\ \[ \[ \^ \\ \] \] [*+] \\? \] \$     # re.sub(r'\[[^\]]*\]$', ...) -- the suffix strip
  | Split-NameTag                           # the PowerShell helper that does the same job
""", re.X)

# THE SWEEP'S LIMITS, PROBED AND STATED HERE RATHER THAN IMPLIED. 2026-07-31, round 3:
#   * `'TUN' + 'ABLE'` walks past it. Any regex sweep loses to string concatenation, and no
#     amount of pattern work closes that -- a parser would be needed, and a parser for four
#     languages to catch a hypothetical is worse than an honest limit.
#   * SCOPE is three globs: _triage/factory_os/*.py, scripts/*.ps1, scripts/lib/*.ps1.
#     scripts/_test/*.ps1, *.psm1 and MQL sources are NOT swept. A second resolver written in
#     ea_template/core/*.mqh would not be seen.
# So R4(b)'s claim is exactly: NO FILE IN THOSE THREE GLOBS PAIRS THE ROLE TOKENS IN CODE WITHOUT
# being the resolver or a declared exemption. It is not "no second resolver can exist". R4(a) --
# every declared consumer reaches the resolver -- is the half that carries real weight, and it is
# the half that reads stripped source so a comment cannot satisfy it.

# COMMENTS ARE NOT CODE, and this had to be learned here the same way run_guard_shape_lint learned
# it: the first version of the sweep flagged scripts/optimize_guard.ps1 -- the DECLARED CONSUMER --
# because the comment explaining WHY it consults the resolver says "LOCKED in B14-H01 and TUNABLE
# in B14-H02". Exempting the consumer would have removed the sweep's most important target to
# silence a false positive in prose. Stripping comments keeps the target and removes the noise.
# It is a stripper and not a parser: a file that hides a second resolver inside a string literal
# is still caught (run_contract_binding_tests.py is exactly that case, and is declared).
_PS_BLOCK_COMMENT = re.compile(r'<#.*?#>', re.S)
_PY_DOCSTRING = re.compile(r'(""".*?"""|' + "'''.*?'''" + r')', re.S)


def strip_comments(src, rel):
    if rel.endswith('.ps1'):
        src = _PS_BLOCK_COMMENT.sub(' ', src)
    else:
        src = _PY_DOCSTRING.sub(' ', src)
    return '\n'.join(l for l in src.splitlines() if not l.lstrip().startswith('#'))

problems = []


def _walk(node, path, fn, key=None):
    """Visit every (nearest-enclosing-key, value, path) in a row, INCLUDING inside arrays.

    FOUND BY ITS OWN FIXTURE, 2026-07-31: the first version called `fn` only for dict entries and
    merely RECURSED through lists, so `{"tags": ["DEMO"]}` was invisible -- a verdict value one
    bracket away from being caught. The list element inherits its parent key, which is what makes
    the exemption lookup still work for an exempted (store, key, value) triple inside an array.
    """
    fn(key, node, path)
    if isinstance(node, dict):
        for k, v in node.items():
            _walk(v, '%s.%s' % (path, k), fn, key=k)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            _walk(v, '%s[%d]' % (path, i), fn, key=key)


def check_r1(stores):
    # `stores` rather than reg.STORES: a BLOCKED store that does not exist has no lines to check,
    # and R6 is what proves it is genuinely absent rather than skipped. Iterating the declared set
    # here would make R1 crash on the very condition R6 exists to report.
    for rel in sorted(stores):
        bad = reg.round_trip(rel)
        if bad:
            problems.append(
                'R1 %s line(s) %s are not in canonical form, so a read-write cycle would change '
                'bytes that no edit changed. Run `registry.py canonicalize`.'
                % (rel, ', '.join(str(b) for b in bad)))


def check_r2(stores):
    if 'factory/coverage.jsonl' not in stores:
        return 0
    _meta, rows = stores['factory/coverage.jsonl']
    fired = 0
    for n, rec in rows:
        for cell in (rec.get('cells') or []):
            if not isinstance(cell, dict):
                continue
            if cell.get('status') != 'NOT_APPLICABLE' and cell.get('state') != 'NOT_APPLICABLE':
                continue
            fired += 1
            why = cell.get('not_applicable_reason')
            if not isinstance(why, str) or len(why.strip()) < 10:
                problems.append(
                    'R2 factory/coverage.jsonl line %d marks %r NOT_APPLICABLE with reason %r. A '
                    'cell excluded from the universe without a reason is a cell nobody can '
                    're-examine -- it is how a universe shrinks silently.'
                    % (n, cell.get('cell'), why))
    return fired


def check_r3(stores):
    for rel in sorted(stores):
        meta, rows = stores[rel]
        # METADATA IS SCANNED TOO. BLIND AUDIT 2026-07-31, reproduced: this iterated `rows` only,
        # so `{"_comment": "note", "verdict": "DEAD-STRUCTURAL"}` produced ZERO problems -- against
        # a criterion whose own text is "a verdict KEY at any depth". A note is still bytes in the
        # store, a reader still reads them, and "it was in a comment" is not a defence. The line
        # number is unavailable for meta records (read_store does not carry one), so they are
        # reported by CONTENT, which is enough to find them in a file this size.
        for n, rec in [(None, m) for m in meta] + list(rows):
            where = ('line %d' % n) if n is not None else ('metadata record %s'
                                                            % json.dumps(rec, sort_keys=True)[:70])
            # ORDER-1251. The VALUE test is a word search for rows this system AUTHORS, and stays
            # an equality test everywhere else. That split is not a compromise, it is what the
            # measurement forced:
            #
            #   * equality alone lets `"parked as a BUILD-ON until the optimize probe runs"` --
            #     a verdict, in a free-text field, in a registry store -- pass clean;
            #   * a word search over EVERYTHING fires 12 times on the live stores today and every
            #     one is innocent: eleven are the ORDER-610 imported rows describing a
            #     MASTER_BACKLOG column literally named "LIVE cell", and one is a module comment
            #     that uses the word Candidate while explaining what an InstrumentProfile is for.
            #     Shipping that would make the stores unwritable, which is how a guard earns the
            #     exemption list that then swallows it (memory
            #     `citation-guard-satisfied-by-a-universal-file`).
            #
            # An authored row is one carrying the `entity` discriminator. The imported rows are
            # TRANSCRIBED from a blob this repo pins and does not author, and metadata is prose
            # ABOUT the store -- neither is a place this system can put a verdict without also
            # writing an authored row saying the same thing.
            authored = isinstance(rec, dict) and rec.get('entity') is not None

            def seen(k, v, path, rel=rel, n=where, authored=authored):
                if k is not None and k.strip().upper() in FORBIDDEN_VERDICT_VALUES:
                    problems.append(
                        'R3 %s %s uses the verdict word %r as a KEY at %s. Probed and found '
                        'walking past the value check, which only inspected values.'
                        % (rel, n, k, path))
                if k is not None and k.lower() in FORBIDDEN_VERDICT_KEYS:
                    problems.append(
                        'R3 %s %s carries a verdict-shaped KEY at %s. These stores hold '
                        'facts and references; a verdict belongs in the scorecard.'
                        % (rel, n, path))
                if not isinstance(v, str):
                    return
                exact = v.strip().upper()
                word = _verdict_word_in(v) if authored else None
                if exact not in FORBIDDEN_VERDICT_VALUES and word is None:
                    return
                # The exemption is keyed on the EXACT value, and it stays that way: an exemption
                # that matched a value CONTAINING `LIVE` would excuse any sentence mentioning it.
                if (rel, k, exact) in VERDICT_VALUE_EXEMPTIONS:
                    return
                if exact in FORBIDDEN_VERDICT_VALUES:
                    problems.append(
                        'R3 %s %s carries the verdict VALUE %r at %s. Checking key names '
                        'and not values is the exact defect audit finding A3 shipped: '
                        '"status": "DEAD-STRUCTURAL" passed a name check and carried a verdict '
                        'into a store whose acceptance forbids one.' % (rel, n, v, path))
                else:
                    problems.append(
                        'R3 %s %s carries the verdict word %r INSIDE a free-text value at %s: %r. '
                        'An equality test never fired on this shape, so a verdict written as '
                        'prose passed every store (ORDER-1251). These stores hold facts and '
                        'references; a verdict belongs in the scorecard.'
                        % (rel, n, word, path, v[:120]))
            _walk(rec, 'row', seen)


def check_r4(src=None):
    # ORDER-670: every read and EVERY ENUMERATION here judges the source's snapshot -- the
    # index in hook mode. The old form globbed the DISK, so `git add rogue.py` + delete the
    # worktree copy left the sweep blind to a second vocabulary the commit contained (A7's
    # exact shape through the channel nothing had named; design 3.2).
    src = src or _default_src()
    # (a) exactly one file derives optimizability.
    for rel, why in sorted(RESOLVER_CONSUMERS.items()):
        if not src.exists_committed(rel):
            problems.append('R4 declared consumer %s does not exist (%s mode)' % (rel, src.mode))
            continue
        consumer_src = strip_comments(src.read_committed(rel), rel)
        # PROBED 2026-07-31 (round 2): this read the RAW source, so a consumer that merely MENTIONED
        # the resolver in a comment satisfied R4 while deciding role/surface some other way. That is
        # the same comments-are-not-code defect the sweep below had, in the half that is supposed to
        # be the strong one. MEASURED after the fix: optimize_guard still carries the token twice
        # with comments stripped, so the fix does not merely move the goalposts.
        if why not in consumer_src:
            problems.append(
                'R4 %s is declared a consumer of the ParameterBinding resolver but does not '
                'reference %r, so it is deciding role/surface some other way -- or not at all. '
                'Two answers to "may this run optimize this parameter" is the drift %s exists '
                'to prevent.' % (rel, why, RESOLVER))
    # (b) no second copy of the vocabulary.  (c) no second parser of the tag encoding.
    hits = []
    tag_hits = []
    for pat in ('_triage/factory_os/*.py', 'scripts/*.ps1', 'scripts/lib/*.ps1'):
        for rel in src.list_committed(pat):
            if rel in RESOLVER_SWEEP_EXEMPT:
                continue
            code = strip_comments(src.read_committed(rel, errors='replace'), rel)
            if ROLE_PAIR.search(code) and ROLE_PAIR2.search(code):
                hits.append(rel)
            # (c) ORDER-672 G2: nor a second parser of the build-tag encoding.
            if rel not in TAG_SWEEP_EXEMPT and TAG_PARSE.search(code):
                tag_hits.append(rel)
    for rel in sorted(hits):
        problems.append(
            'R4 %s pairs the role tokens TUNABLE and LOCKED without being the resolver or a '
            'declared exemption. Either route it through %s, or declare it in '
            'RESOLVER_SWEEP_EXEMPT with a reason.' % (rel, RESOLVER))
    for rel in sorted(tag_hits):
        problems.append(
            'R4 %s parses the build-tag encoding out of a parameter name. Only %s may know that '
            'encoding -- it owns both directions (bare_registry_name / registry_name), and a '
            'second parser is a second answer to "which parameter does this mean". That is F1: a '
            'tagged binding invisible to its only consumer. Call the resolver, or declare an '
            'exemption with a reason.' % (rel, RESOLVER))


def _required_fields(entity, src):
    """The entity's `required` list, READ FROM THE SCHEMA rather than re-typed here.

    A second copy of a required-field list is the drift this whole module is written against, so
    the list is not written down -- it is looked up. If the schema cannot be read, that is a TOOL
    failure and R5 says so instead of quietly checking nothing. ORDER-670: the schema is judged
    evidence -- the required-field floor must be the one the COMMIT declares, so it is read
    through the source (the cache is keyed by mode; two sources in one process must not share
    a schema).
    """
    key = (src.mode, src.root)
    if key not in _SCHEMA_DEFS:
        _SCHEMA_DEFS[key] = json.loads(
            src.read_committed('_triage/factory_os/schemas.json')).get('$defs') or {}
    return list((_SCHEMA_DEFS[key].get(entity) or {}).get('required') or [])


_SCHEMA_DEFS = {}


def check_r5(stores, src=None):
    src = src or _default_src()
    for rel, entity in sorted((k, v) for k, v in reg.STORES.items() if k in stores):
        _meta, rows = stores[rel]
        for n, rec in rows:
            got = rec.get('entity')
            if got is None:
                # coverage.jsonl's ORDER-610 import rows predate the entity discriminator and are
                # pinned to a source blob. They are NOT waved through: the exemption is this one
                # store, named here, and it ends when S5's CoverageCell rows replace them.
                if rel == 'factory/coverage.jsonl':
                    continue
                problems.append('R5 %s line %d has no `entity` discriminator, so nothing can '
                                'route it to a contract' % (rel, n))
                continue
            if got != entity:
                problems.append(
                    'R5 %s line %d declares entity=%r but this store holds %r. A store whose rows '
                    'can be any entity is a store nothing validates as a whole.'
                    % (rel, n, got, entity))
                continue
            # BLIND AUDIT 2026-07-31, reproduced: R5 was described as "every row VALIDATES against
            # the one entity its store is declared to hold" and it checked the DISCRIMINATOR ONLY.
            # `{"entity": "InstrumentProfile"}` -- every required field missing -- was accepted with
            # R3 and R5 both reporting []. That is shape 2 in the check written to enforce shape 2:
            # testing a name where a value is what matters.
            #
            # This is NOT full schema validation and must not be described as such. ajv is the
            # validator and it runs in run_schema_fixtures.py; this tier has no node budget. What
            # this adds is the REQUIRED-FIELD floor, read out of schemas.json so there is no second
            # copy of the list. A row that passes here can still be invalid in ways only ajv sees.
            missing = [f for f in _required_fields(entity, src) if f not in rec]
            if missing:
                problems.append(
                    'R5 %s line %d declares entity=%r but is missing required field(s) %s. The '
                    'discriminator alone was the whole check until 2026-07-31, so a row carrying '
                    'nothing but its own name passed. (Required-field floor only -- full schema '
                    'validation is ajv, in run_schema_fixtures.py.)'
                    % (rel, n, entity, ', '.join(missing)))


def check_r6(src=None):
    """A blocked store may not quietly appear, and a block may not quietly expire.

    Both halves, because a one-sided version is useless in a predictable way. If a blocked store
    APPEARS, load_all skips it and nothing validates it -- so it must be refused. If the CONDITION
    that blocks it stops holding, the block is an exclusion nobody re-examined, which is the same
    defect snapshot_build's TASKBOARDS_NOT_READ check exists for.

    ORDER-670: existence is judged through the source. "Absent from the COMMIT" is the fact this
    criterion is about in hook mode -- staging a blocked store while deleting the worktree copy
    must be refused, and an untracked scratch file must not be.
    """
    src = src or _default_src()
    d1_rel = '_triage/factory_os/s2a_migration.jsonl'
    d1_states = set()
    if src.exists_committed(d1_rel):
        for line in src.read_committed(d1_rel).split('\n'):
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if isinstance(rec, dict) and rec.get('proposed_owner') or                     (isinstance(rec, dict) and rec.get('proposed')):
                d1_states.add((rec.get('entity_name') or rec.get('entity'),
                               rec.get('current_owner') or rec.get('owner')))
    # THE THIRD DIRECTION, and it was missing. PROBED 2026-07-31 (round 2): emptying
    # reg.STORES_BLOCKED entirely went silently GREEN -- a recorded owner-owned block could be
    # deleted with nothing noticing, which is worse than never having recorded it, because the
    # store would then be created and the S2a gate would go red with no explanation on file.
    # A block is only a block if REMOVING it is also refused while its premise holds.
    if ('TestUniverse', 'NO_CURRENT_OWNER') in d1_states or             ('LogicalSymbol', 'NOT_YET_BUILT') in d1_states:
        if 'factory/universe.jsonl' not in reg.STORES_BLOCKED:
            problems.append(
                'R6 D1 still declares TestUniverse NO_CURRENT_OWNER / LogicalSymbol NOT_YET_BUILT '
                'with factory/universe.jsonl as their proposed owner, but that store is NOT '
                'declared in registry.STORES_BLOCKED. Creating it refutes both rows and D1 is '
                'inside the owner attestation bundle, so the block must be recorded, not dropped.')

    for rel, why in sorted(reg.STORES_BLOCKED.items()):
        if src.exists_committed(rel):
            problems.append(
                'R6 %s is declared BLOCKED but EXISTS. load_all() skips a blocked store, so a '
                'blocked store that is present is a store nothing validates. Either lift the '
                'block in registry.STORES_BLOCKED with the reason it no longer applies, or '
                'remove the file. Block reason on record: %s' % (rel, why))
        # The blocker for the universe store is D1 still declaring those two states. If D1 no
        # longer does, the block has expired and must be re-examined rather than inherited.
        if rel == 'factory/universe.jsonl' and d1_states:
            still = [st for ent, st in d1_states
                     if ent in ('TestUniverse', 'LogicalSymbol')
                     and st in ('NO_CURRENT_OWNER', 'NOT_YET_BUILT')]
            if not still:
                problems.append(
                    'R6 %s is declared BLOCKED because D1 declares TestUniverse '
                    'NO_CURRENT_OWNER / LogicalSymbol NOT_YET_BUILT, and D1 no longer declares '
                    'either. The block has EXPIRED: re-examine it rather than inheriting it.'
                    % rel)


def main():
    try:
        src = ev.EvidenceSource.for_run()
    except ev.ToolFailure as exc:
        print('[TOOL FAILURE] %s' % exc)
        return 2
    # The one tier-verifiable line (ORDER-670): which bytes this run judged, stated by the
    # code that chose them -- not by a wrapper that believes it knows.
    print(src.marker('check_registries.py'))
    try:
        stores = reg.load_all(source=src)
    except reg.RegistryRefusal as exc:
        # TOOL failure, exit 2. Not a violation: "I could not read the registries" and "the
        # registries are wrong" have different fixes, and collapsing them is this repo's
        # most-repeated defect.
        print('[TOOL FAILURE] %s' % exc)
        return 2

    check_r1(stores)
    na_fired = check_r2(stores)
    check_r3(stores)
    check_r4(src)
    check_r5(stores, src)
    check_r6(src)

    total = sum(len(rows) for _m, rows in stores.values())
    print('=== ORDER-630 registry check ===')
    for rel in sorted(reg.STORES):
        if rel not in stores:
            # Printed on its own line, loudly, on EVERY run. A block that only exists in a
            # constant is a block the next reader will not know about.
            print('  %-40s BLOCKED, not created -- %s' % (rel, reg.STORES_BLOCKED.get(rel, '?')))
            continue
        meta, rows = stores[rel]
        print('  %-40s %d row(s)' % (rel, len(rows)))
    print('  %d row(s) across %d store(s)' % (total, len(reg.STORES)))
    # THE GUARD RULE, applied to this guard. R2 can only be evidence if it fired; a run where it
    # fired 0 times means UNTESTED here, and the run_registry_tests.py fixtures are where it is
    # made to fire. Saying "0" out loud is the point -- CLAUDE.md's guard row exists because a
    # guard that never fired has been written up as passed before.
    print('  R2 NOT_APPLICABLE cells examined this run: %d%s'
          % (na_fired, '  <- 0 means R2 is UNTESTED by this run, not that it passed'
             if na_fired == 0 else ''))
    if problems:
        print('\n%d PROBLEM(S):' % len(problems))
        for p in problems:
            print('  - %s' % p)
        return 1
    print('\n=== R1 round-trip - R2 not-applicable reason - R3 no verdict (keys AND values) '
          '- R4 one resolver - R5 one entity per store: all hold ===')
    return 0


if __name__ == '__main__':
    sys.exit(main())
