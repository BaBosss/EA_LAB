# -*- coding: utf-8 -*-
"""ORDER-610 E4 -- the negative fixtures for the S2 Coverage transfer acceptance.

Every criterion in check_coverage_transfer.py has at least one case here that must come back RED,
and every RED is asserted BY REASON, not merely by exit code: a check that fails for the wrong
reason is a check that will pass for the wrong reason later.

Both the pre-transfer and post-transfer states of MASTER_BACKLOG.md are SYNTHESIZED in memory. This
suite therefore behaves identically before and after the transfer commit. That is deliberate: three
separate controls in this repo have gone red or silently skipped because they depended on the state
of the repository instead of the logic under test (see the S2AD1D2 lane notes and memory
`drift-guard-regenerating-against-head`).

The case that matters most is INERTNESS, at the bottom: it demonstrates that the naive
implementation of A2 -- deriving the baseline from the store instead of from the pinned blob --
would have accepted a store with a cell deleted. That is what makes the pin load-bearing rather
than decorative.
"""

import copy
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import gen_coverage as gen            # noqa: E402
import check_coverage_transfer as chk  # noqa: E402

OUT = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', newline='\n')
FAILURES = []


def say(line=''):
    OUT.write(line + '\n')
    OUT.flush()


# --------------------------------------------------------------------------- synthetic inputs

def real_store():
    """The committed/working store, as (section, records). Never mutated in place."""
    text = io.open(os.path.join(ROOT, gen.COVERAGE_PATH), encoding='utf-8').read()
    return chk.load_store_text(text)


def store_text(section, records):
    lines = [json.dumps({'_comment': 'synthetic fixture'}, ensure_ascii=False),
             json.dumps({'_section': section}, ensure_ascii=False, sort_keys=True)]
    lines += [json.dumps(r, ensure_ascii=False, sort_keys=True) for r in records]
    return '\n'.join(lines) + '\n'


def backlog_pre():
    """MASTER_BACKLOG.md exactly as it was before the transfer: hand table, no notice."""
    return gen.baseline_text()


def backlog_post(section=None, records=None, top_banner=True, section_banner=True):
    """MASTER_BACKLOG.md as it looks AFTER the transfer, built from the pinned baseline."""
    if section is None:
        section, records = real_store()
    lines = gen.baseline_text().split('\n')
    span = gen.section2_span(lines)
    start, end = span
    body = chk.render_from(section, records)
    if not section_banner:
        body = [l for l in body if chk.PHRASE not in chk.normalize(l)]
    lines[start:end] = body
    if top_banner:
        anchor = next(i for i, l in enumerate(lines) if 'canonical entry =' in l)
        lines.insert(anchor + 1, gen.TOP_BANNER)
    return '\n'.join(lines)


def run(backlog_text, section, records):
    return chk.check(backlog_text=backlog_text,
                     coverage_text=store_text(section, records),
                     skip_a8=True)[0]


def case(name, backlog_text, section, records, expect_red, needle=None):
    try:
        problems = run(backlog_text, section, records)
    except chk.ToolFailure as exc:
        problems = ['TOOLFAILURE %s' % exc]
    red = bool(problems)
    ok = (red == expect_red)
    if ok and expect_red and needle:
        ok = any(re.search(needle, p) for p in problems)
    tag = '[OK ]' if ok else '[FAIL]'
    say('  %s %-58s expect=%s got=%s' % (tag, name, 'RED' if expect_red else 'GREEN',
                                         'RED' if red else 'GREEN'))
    if not ok:
        FAILURES.append(name)
        for p in problems[:4]:
            say('        ! %s' % p.replace('\n', ' ')[:220])
    return problems


def mutate(records, fn):
    r = copy.deepcopy(records)
    fn(r)
    return r


# --------------------------------------------------------------------------- the suite

def main():
    section, records = real_store()

    say('=== CONTROLS: both legal states of the file must be accepted ===')
    case('CONTROL pre-transfer: hand table, no notice', backlog_pre(), section, records, False)
    case('CONTROL post-transfer: generated body + both notices',
         backlog_post(section, records), section, records, False)

    say()
    say('=== A1 condition 1, BOTH directions ===')
    case('generated body, top banner missing',
         backlog_post(section, records, top_banner=False), section, records, True,
         r'A1 .*top banner')
    # The first version of this case tried to remove the notice from the section body while keeping
    # the body generated. That state is UNREACHABLE -- the renderer emits the notice -- so the
    # checker branch it targeted could never fire. The reachable version mutates the GENERATOR.
    saved_banner = list(gen.SECTION_BANNER)
    try:
        gen.SECTION_BANNER[:] = ['> (no notice)']
        case('the generator stops emitting the notice',
             backlog_post(section, records), section, records, True,
             r'A1 the generator no longer emits')
    finally:
        gen.SECTION_BANNER[:] = saved_banner
    # The pre-armed banner: the notice lands one commit BEFORE the generation. A "banner present"
    # check would be green here while the file tells every reader a falsehood.
    pre_armed = backlog_pre().split('\n')
    _anchor = next(i for i, l in enumerate(pre_armed) if 'canonical entry =' in l)
    pre_armed.insert(_anchor + 1, gen.TOP_BANNER)
    case('banner pre-armed one commit early, body still hand-written',
         '\n'.join(pre_armed), section, records, True, r'A1 the file SAYS')

    say()
    say('=== A5 the hand-edit guard that makes the notice true rather than decorative ===')
    edited = backlog_post(section, records).split('\n')
    _row = next(i for i, l in enumerate(edited) if l.startswith('| Gold Reaper'))
    edited[_row] = edited[_row].replace('default params', 'locked')
    case('a hand edit to one generated row after the transfer',
         '\n'.join(edited), section, records, True, r'A1 the file SAYS.*!=')

    say()
    say('=== A2 condition 2, measured against the PINNED blob ===')
    post = backlog_post(section, records)

    def drop_live(rs):
        for r in rs:
            if r['ea'] == 'ST_EA03 MACD':
                r['live_cells'] = [c for c in r['live_cells'] if c != 'USDCAD H1']
                r['cells'] = [c for c in r['cells'] if c.get('cell') != 'USDCAD H1']
    case('a LIVE cell dropped from the store', post, section, mutate(records, drop_live), True,
         r'A2 row .* lost (LIVE )?cell')

    def drop_import(rs):
        for r in rs:
            if r['ea'] == 'EA_BREAKOUT_XAU':
                r['cells'] = [c for c in r['cells'] if c.get('cell') != 'XAUUSD H4']
    case('an UNVERIFIED_IMPORT cell dropped', post, section, mutate(records, drop_import), True,
         r"A2 row .*lost cell 'XAUUSD H4'")

    case('a whole EA row dropped', post, section,
         mutate(records, lambda rs: rs.pop(3)), True, r'A2 the hand table row .* is absent')

    # Audit 8 MAJOR 4's attack, re-run at the new boundary: keep the traceable token, replace the
    # label with something meaningless. The token stays findable in the source; the label is junk.
    def relabel(rs):
        for r in rs:
            if r['ea'] == 'NuiIndy RSI+ADX':
                for c in r['cells']:
                    if c.get('cell') == 'GBPUSD':
                        c['cell'] = 'MEANINGLESS-CELL-1'
    # The needle changed with the fix and that is an improvement, not a regression: positional
    # comparison names the exact FIELD that was altered instead of reporting the cell as missing.
    case('a cell relabelled while its source_token stays valid', post, section,
         mutate(records, relabel), True, r"A2 row .*field 'cell' was altered")

    def clip_column(rs):
        rs[4]['source_columns'][4] = ''
    case('a source column (Optimized?) emptied', post, section,
         mutate(records, clip_column), True, r'A2 row .* column 4 lost or altered')

    sec_no_note = dict(section)
    sec_no_note['note'] = None
    case('the reading note under the table dropped',
         backlog_post(sec_no_note, records), sec_no_note, records, True,
         r'A2 the reading note')

    say()
    say('=== CODEX AUDIT, Standards 3 -- a notice a human cannot SEE is not a notice ===')
    say('  Wrapping the banner in an HTML comment made the rendered notice vanish while the')
    say('  checker returned 0 problems. Same mechanism as memory')
    say('  guard-disarmed-by-prose-reported-as-note. Reproduced by hand before it was fixed.')
    # Round 2 named six more ways to keep the phrase in the source and off the page, and tested the
    # Markdown reference definition itself. Two of the seven were STILL open after the first repair
    # here -- `hidden` and `display:none` -- because the pattern stripped the opening tag and left
    # the text inside it. All seven are cases now, so the next one found is added to a list rather
    # than argued about.
    _post = backlog_post(section, records).split('\n')
    _b = next(i for i, l in enumerate(_post) if l == gen.TOP_BANNER)
    for _label, _repl in (
            ('an HTML comment',            '<!-- ' + gen.TOP_BANNER[2:] + ' -->'),
            ('a Markdown reference def',   '[ref]: /x "%s"' % chk.PHRASE),
            ('a <template> element',       '<template>%s</template>' % chk.PHRASE),
            ('a hidden attribute',         '<div hidden>%s</div>' % chk.PHRASE),
            ('an inline display:none',     '<div style="display:none">%s</div>' % chk.PHRASE),
            ('image alt text',             '<img alt="%s">' % chk.PHRASE),
            ('a title attribute',          '<div title="%s"></div>' % chk.PHRASE)):
        _t = list(_post)
        _t[_b] = _repl
        case('the notice hidden in %s' % _label, '\n'.join(_t), section, records, True,
             r'A1 section 2 IS generated output but the notice is missing from the top banner')
    # ...and the control that keeps the fix from over-reaching: a comment elsewhere in the header
    # must not remove a notice that IS visible.
    withc = backlog_post(section, records).split('\n')
    withc.insert(_b, '<!-- an ordinary editorial comment -->')
    case('CONTROL an unrelated HTML comment beside a visible notice',
         '\n'.join(withc), section, records, False)

    say()
    say('=== CODEX AUDIT ROUND 2 -- every one of these passed BEFORE the fix ===')
    post = backlog_post(section, records)

    # Standards 2 (P0): a duplicate placed BEFORE the real cell was invisible, because cells were
    # collapsed into a dict keyed by identity and the LAST one won -- so the real cell satisfied
    # A2 on the corrupted duplicate's behalf.
    def dup_before(rs):
        for r in rs:
            if r['cells']:
                bad = copy.deepcopy(r['cells'][0])
                bad['source_coordinates'] = {'file': 'WRONG.md', 'column_index': 5,
                                             'section': 'x', 'source_row': 'y'}
                r['cells'].insert(0, bad)
                return
    case('a corrupted DUPLICATE inserted before the real cell', post, section,
         mutate(records, dup_before), True, r'A2 row .*carries \d+ cell')

    # Spec 1 (P0): A3 checked key NAMES, never VALUES -- so a verdict word rode in as `status`.
    case('a VERDICT carried as a cell status', post, section,
         mutate(records, lambda rs: rs[0]['cells'].append(
             {'cell': 'EXTRA', 'status': 'DEAD-STRUCTURAL'})), True,
         r'A3 row .*status=.DEAD-STRUCTURAL')

    # Spec 6: `.get()` made an absent key and a present-null key compare equal.
    case('a null value where the reviewed evidence has no key at all', post, section,
         mutate(records, lambda rs: rs[0]['cells'][0].update({'why_unverified': None})), True,
         r'A2 row .*field set differs')

    # Spec 5: A4 was deleted; a nondeterministic renderer then passed everything. The fixture
    # perturbs the RENDERER, which is the only thing that can make this fire.
    _calls = {'n': 0}
    _real_render = gen.render_from
    try:
        def flaky(sec, recs):
            _calls['n'] += 1
            out = _real_render(sec, recs)
            return out if _calls['n'] % 2 else out + ['<extra line on every other call>']
        gen.render_from = flaky
        probs = run(post, section, records)
        ok = any(re.search(r'A4 the generator is NOT deterministic', p) for p in probs)
        say('  %s %-58s expect=RED got=%s'
            % ('[OK ]' if ok else '[FAIL]', 'a renderer that returns something different each call',
               'RED' if probs else 'GREEN'))
        if not ok:
            FAILURES.append('nondeterministic renderer')
    finally:
        gen.render_from = _real_render

    say()
    say('=== CODEX AUDIT, P1 -- the store is a CLOSED shape, not a bag ===')
    say('  All three of these passed before the fix: a wrong source_coordinates.file, a root')
    say('  "outcome": "DEAD", and one declared_status swapped for another allowed value.')
    post = backlog_post(section, records)

    def wrong_coord(rs):
        for r in rs:
            for c in r.get('cells') or []:
                if c.get('source_coordinates'):
                    c['source_coordinates']['file'] = 'WRONG'
                    return
    case('a cell coordinate pointing at the wrong file', post, section,
         mutate(records, wrong_coord), True, r"A2 row .*field 'source_coordinates' was altered")

    case('a root field the old name-blacklist never anticipated', post, section,
         mutate(records, lambda rs: rs[0].update({'outcome': 'DEAD'})), True,
         r"A3 row .*undeclared field\(s\) \['outcome'\]")

    def swap_status(rs):
        for r in rs:
            for c in r.get('cells') or []:
                if c.get('declared_status') == 'REJECT':
                    c['declared_status'] = 'DEAD'      # a DIFFERENT but ALLOWED vocabulary value
                    return
    case('one declared_status swapped for another allowed value', post, section,
         mutate(records, swap_status), True, r"A2 row .*field 'declared_status' was altered")

    case('an undeclared key inside source_coordinates', post, section,
         mutate(records, lambda rs: rs[1]['cells'][1].setdefault('note', 'x')), True,
         r'A3 row .* undeclared field')

    say()
    say('=== ORDER-610 A4 was deleted; its promised perturbation fixture lands on A1 ===')
    case('a source column perturbed in the STORE, so section 2 no longer matches it', post, section,
         mutate(records, lambda rs: rs[2]['source_columns'].__setitem__(1, 'PERTURBED')), True,
         r'A1 the file SAYS')

    say()
    say('=== A3 no verdict may live in a coverage store ===')
    case('a verdict field added to a row', post, section,
         mutate(records, lambda rs: rs[0].update({'verdict': 'CANDIDATE'})), True,
         r'A3 row .* carries the field')

    def status_on_live(rs):
        for c in rs[0]['cells']:
            if c.get('status') == 'LIVE':
                c['declared_status'] = 'DEAD'
    case('an outcome word attached to a LIVE cell', post, section,
         mutate(records, status_on_live), True, r'A3 row .* is LIVE and also carries')

    def strip_token(rs):
        for r in rs:
            if r['ea'] == 'NuiIndy RSI+ADX':
                for c in r['cells']:
                    if c.get('declared_status'):
                        c.pop('source_token', None)
    case('an outcome word with its provenance removed', post, section,
         mutate(records, strip_token), True, r'A3 row .* with no source_token')

    def new_word(rs):
        for r in rs:
            if r['ea'] == 'NuiIndy RSI+ADX':
                for c in r['cells']:
                    if c.get('declared_status'):
                        c['declared_status'] = 'PROBABLY_FINE'
                        break
    case('a brand-new outcome word minted', post, section,
         mutate(records, new_word), True, r'A3 row .* not in the closed vocabulary')

    say()
    say('=== CODEX AUDIT, Standards 1 -- read_input, which had NO fixture at all ===')
    say('  It falls back to the working tree for a path absent from the index, so a verdict could')
    say('  rest on one input that is being committed and one that is not.')
    real_git = chk._git

    def fake_git(*args):
        # `git show :<path>` succeeds only for the paths this scenario says are in the index
        if args[:1] == ('show',) and args[1].startswith(':'):
            path = args[1][1:]
            if path in fake_git.indexed:
                return 0, b'INDEXED BYTES\n', b''
            return 1, b'', b'fatal: path does not exist in the index'
        if args[:2] == ('ls-files', '--error-unmatch'):
            return (0, b'', b'') if args[2] in fake_git.tracked else (1, b'', b'')
        return real_git(*args)

    for name, indexed, tracked, expect in (
            ('both in the index -> one coherent snapshot', {chk.BACKLOG_PATH, chk.COVERAGE_PATH},
             {chk.BACKLOG_PATH, chk.COVERAGE_PATH}, 'index/index'),
            ('the store missing from the index -> mixed, must REFUSE', {chk.BACKLOG_PATH},
             {chk.BACKLOG_PATH}, 'ToolFailure'),
            ('the backlog missing from the index -> mixed, must REFUSE', {chk.COVERAGE_PATH},
             {chk.COVERAGE_PATH}, 'ToolFailure'),
            # Codex round 2, Spec 4: refusing only the MIXED pair left BOTH-from-worktree
            # accepted -- the original defect, doubled, not a weaker version of it.
            ('NEITHER in the index -> worktree/worktree, must REFUSE', set(), set(),
             'ToolFailure')):
        fake_git.indexed, fake_git.tracked = indexed, tracked
        chk._git = fake_git
        try:
            b, bs = chk.read_input(chk.BACKLOG_PATH)
            c, cs = chk.read_input(chk.COVERAGE_PATH)
            got = '%s/%s' % (bs, cs)
            if got != 'index/index':
                # reproduce what check() does: a MIXED pair, and now also a both-worktree pair,
                # are tool failures -- neither says anything about what the commit contains.
                got = 'ToolFailure'
        except chk.ToolFailure:
            got = 'ToolFailure'
        finally:
            chk._git = real_git
        ok = got == expect
        if not ok:
            FAILURES.append(name)
        say('  %s %-58s expect=%-12s got=%s' % ('[OK ]' if ok else '[FAIL]', name, expect, got))

    say()
    say('=== TOOL FAILURE is not a rejection ===')
    for name, text in (('coverage.jsonl is not valid JSON', '{ this is not json\n'),
                       ('coverage.jsonl has no _section record',
                        json.dumps({'ea': 'x'}) + '\n')):
        try:
            chk.check(backlog_text=post, coverage_text=text, skip_a8=True)
            say('  [FAIL] %-58s expected a ToolFailure, got a verdict' % name)
            FAILURES.append(name)
        except chk.ToolFailure as exc:
            say('  [OK ] %-58s ToolFailure: %s' % (name, str(exc)[:60]))

    say()
    say('=== A8: the downgrade is GONE (ORDER-613 D3), so there is nothing left to fixture ===')
    say('  Six cases used to live here proving the exemption refused to widen. They are deleted')
    say('  with the exemption itself: the contract can now express "the pinned bytes changed INTO')
    say('  the state this record approved", so nothing needs downgrading. A8 is a plain hard check')
    say('  again -- check_s2a_attestation.py must exit 0 -- which is what ORDER-610 pre-registered')
    say('  before I amended it. Its negative fixture is the attestation suite, not this one.')

    say('=== WHY THE PINNED BLOB IS LOAD-BEARING (the inertness probe) ===')
    say('  The naive A2 derives the baseline from the store it is judging. Below is that exact')
    say('  implementation, run against the store with a LIVE cell deleted.')
    dropped = mutate(records, drop_live)
    real_build = gen.build_records
    try:
        def self_referential():
            # what a working-tree baseline would produce: the mutated store, describing itself
            return (section['heading'], section['header_columns'], section['note'],
                    [{'ea': r['ea'], 'source_columns': r['source_columns'],
                      'live_cells': r.get('live_cells') or [], 'cells': r.get('cells') or []}
                     for r in dropped])
        gen.build_records = self_referential
        naive = run(post, section, dropped)
    finally:
        gen.build_records = real_build
    a2_naive = [p for p in naive if p.startswith('A2')]
    if a2_naive:
        say('  [FAIL] the self-referential baseline still caught it -- the probe is wrong')
        FAILURES.append('inertness probe')
    else:
        say('  [OK ] self-referential baseline: 0 A2 problems -- it accepts the deletion')
    real = run(post, section, dropped)
    if [p for p in real if p.startswith('A2')]:
        say('  [OK ] pinned-blob baseline:      catches the same deletion')
    else:
        say('  [FAIL] pinned-blob baseline missed it too')
        FAILURES.append('inertness probe (real)')

    say()
    if FAILURES:
        say('=== %s CASE(S) FAILED: %s ===' % (len(FAILURES), ', '.join(FAILURES)))
        return 1
    say('=== EVERY CRITERION REFUSED ITS OWN ATTACK, AND BOTH LEGAL STATES WERE ACCEPTED ===')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
