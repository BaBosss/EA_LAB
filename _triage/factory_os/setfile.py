# -*- coding: utf-8 -*-
"""setfile.py -- ORDER-1020 (slice S7). Reading an existing `.set`, and migrating an old one.

THE OWNER RATIFIED THIS POLICY ON 2026-08-01 (design section 11 decision 4, `PROJECT_STATE.md`
section 3): **an unknown or removed key is a REFUSAL that NAMES THE KEY -- never a skipped line,
never a default substituted underneath** -- and migration is a SEPARATE tool that writes a NEW
file and reports every key it changed, dropped or could not map. The 2,177 tracked `.set` files
are NOT bulk-migrated; they fail loudly when used, and migrate on demand.

WHY THE SILENT PATH IS THE DANGEROUS ONE, IN THIS REPO'S OWN HISTORY. A `.set` that quietly drops
a line it does not recognise is indistinguishable from one that never had the line -- and MT5's
tester fills anything a `.set` does not specify from the PER-TERMINAL CACHE. That is the
documented root cause of the ORDER-165 "8/8 false drift" (memory
`mt5-tester-cache-nondeterminism`), and it is why `preset.py` refuses a partial set as a matter of
policy rather than taste. The failure has the worst possible shape: the run completes, the report
looks ordinary, and the number is about a configuration nobody chose.

  🔴 THE REFUSAL MUST NAME THE KEY, and that is not a message-quality preference. "This .set is
  not valid for this build" leaves the reader with 116 candidates and a file of 116 lines; the
  cheapest way past it is to delete lines until it loads, which reintroduces the partial-set
  defect the refusal exists to prevent. A refusal that names the key points at the migration tool
  instead.

WHAT COUNTS AS "UNKNOWN". The build's parsed surface decides, and nothing is matched by
resemblance -- same rule, and the same reason, as `preset.compile_preset`'s P2. Case is NOT
normalised into a match: `exitmode` is a different string from `ExitMode`, and accepting it would
be this module deciding what the author meant.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): PURE. Text in, structure out; the CLI is the
only thing that opens a path, and it says which one.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import preset                                     # noqa: E402  (path set above)

Refusal = preset.PresetRefusal

# An MT5 `.set` line is `Name=Value`, optionally followed by the optimizer's
# `||start||step||stop||Y/N` tail. Comments start with `;`. Blank lines are ignored.
_LINE_RE = re.compile(r'^([^=;\s][^=]*)=(.*)$')


class SetLine(object):
    """One parsed line. `lineno` is carried because a refusal that cannot say WHERE is a refusal
    the reader has to search for by hand."""

    def __init__(self, name, value, optimize_tail, lineno, raw):
        self.name = name
        self.value = value
        self.optimize_tail = optimize_tail     # the `||...` remainder, or None
        self.lineno = lineno
        self.raw = raw

    def render(self):
        if self.optimize_tail is None:
            return '%s=%s' % (self.name, self.value)
        return '%s=%s||%s' % (self.name, self.value, self.optimize_tail)


def parse_set(text):
    """-> ([SetLine], [comment lines]). Structure only; nothing is judged against a build yet.

    A duplicate key is a REFUSAL here rather than last-wins. Two lines setting one input is a
    file that disagrees with itself, and whichever value the terminal happens to take is not a
    decision anyone made -- the same rule `preset.compile_preset` applies inside one layer.
    """
    lines = []
    comments = []
    seen = {}
    for i, raw in enumerate(text.replace('\r\n', '\n').split('\n'), start=1):
        stripped = raw.strip()
        if not stripped:
            continue
        if stripped.startswith(';'):
            comments.append(raw)
            continue
        m = _LINE_RE.match(stripped)
        if not m:
            raise Refusal(
                'line %d of the .set is neither a comment nor a Name=Value pair: %r. Refused '
                'rather than skipped -- a line this reader cannot parse is a line the TERMINAL '
                'may well parse, and skipping it means judging a file that is not the one the '
                'tester will load.' % (i, raw))
        name = m.group(1).strip()
        rest = m.group(2)
        if '||' in rest:
            value, tail = rest.split('||', 1)
        else:
            value, tail = rest, None
        if name in seen:
            raise Refusal(
                'the .set sets %r twice, at line %d and line %d. Refused rather than resolved by '
                'last-wins: one file disagreeing with itself has no correct answer, and the '
                'value the terminal would take is an accident of ordering, not a choice.'
                % (name, seen[name], i))
        seen[name] = i
        lines.append(SetLine(name, value.strip(), tail, i, raw))
    return lines, comments


def read_set(text, surface, require_full_surface=True):
    """-> OrderedDict name -> value, for a `.set` that is valid for `surface`.

    REFUSES, naming the key, when the file carries a key the build does not expose. REFUSES,
    naming the keys, when the file does not cover the whole surface and `require_full_surface`
    -- because an uncovered input is filled from the terminal cache, which is the ORDER-165
    defect. Callers that genuinely want a partial overlay (the migration tool reading an OLD
    file) pass False and say so.
    """
    from collections import OrderedDict
    lines, _comments = parse_set(text)

    unknown = [ln for ln in lines if ln.name not in surface.by_name]
    if unknown:
        detail = '; '.join(
            '%r (line %d, nearest declared: %s)'
            % (ln.name, ln.lineno, ', '.join(preset._nearest(ln.name, surface)) or 'none')
            for ln in unknown)
        raise Refusal(
            'this .set carries %d key(s) that build %s does not expose: %s. REFUSED, and the '
            'key(s) are named because that is the whole point -- a reader that dropped them '
            'would produce a run configured partly from this file and partly from the '
            'terminal cache, and the report would not say so. Migrate the file with '
            'migrate_set.py, which writes a NEW file and reports every key it changed, dropped '
            'or could not map.' % (len(unknown), surface.build_tag, detail))

    if require_full_surface:
        have = set(ln.name for ln in lines)
        missing = [d.name for d in surface.inputs if d.name not in have]
        if missing:
            shown = ', '.join(missing[:12]) + ('' if len(missing) <= 12 else
                                               ', ... (%d more)' % (len(missing) - 12))
            raise Refusal(
                'this .set covers %d of build %s\'s %d inputs; %d are missing: %s. REFUSED: '
                'MT5 fills an unlisted input from the PER-TERMINAL tester cache, so a partial '
                'set produces a run whose configuration depends on what that terminal ran last '
                '(memory `mt5-tester-cache-nondeterminism`, the ORDER-165 8/8 false drift).'
                % (len(have), surface.build_tag, len(surface), len(missing), shown))

    out = OrderedDict()
    for decl in surface.inputs:
        for ln in lines:
            if ln.name == decl.name:
                out[decl.name] = ln.value
                break
    return out


# ---------------------------------------------------------------------------------------------
# migration
# ---------------------------------------------------------------------------------------------

# Renames a migration is allowed to apply. CLOSED and EMPTY today, and the emptiness is the
# point: slice S7's prohibition is "no key renames", so there is nothing to map yet. It exists
# named rather than absent so the first real rename has one place to go, and so the report can
# distinguish "no mapping was needed" from "this tool has no mapping table at all".
RENAMES = {}


class MigrationReport(object):
    """Every key, in one of four buckets. A migration that reported only the total would be a
    migration nobody could review -- and reviewing it is the whole reason it writes a new file
    instead of editing the old one."""

    def __init__(self):
        self.kept = []          # (name, value)
        self.renamed = []       # (old, new, value)
        self.dropped = []       # (name, value, reason)
        self.unmappable = []    # (name, value, reason)
        self.filled = []        # (name, value, source)

    @property
    def ok(self):
        return not self.unmappable

    def render(self):
        out = []
        out.append('kept       : %d' % len(self.kept))
        out.append('renamed    : %d' % len(self.renamed))
        for old, new, _v in self.renamed:
            out.append('    %s -> %s' % (old, new))
        out.append('dropped    : %d' % len(self.dropped))
        for name, value, reason in self.dropped:
            out.append('    %s=%s  (%s)' % (name, value, reason))
        out.append('filled     : %d  (inputs the build exposes that the old file did not set)'
                   % len(self.filled))
        for name, value, source in self.filled:
            out.append('    %s=%s  (%s)' % (name, value, source))
        out.append('unmappable : %d' % len(self.unmappable))
        for name, value, reason in self.unmappable:
            out.append('    %s=%s  (%s)' % (name, value, reason))
        return '\n'.join(out) + '\n'


def migrate_set(old_text, surface, defaults=None):
    """-> (new .set text, MigrationReport). NEVER writes; the caller owns the file.

    `defaults` supplies a value for every input the old file does not carry. Without it, an
    input the old file never set is `unmappable` rather than silently defaulted -- the migration
    tool is not allowed to invent a value any more than the reader is.
    """
    defaults = defaults or {}
    lines, comments = parse_set(old_text)
    report = MigrationReport()
    resolved = {}

    for ln in lines:
        name = RENAMES.get(ln.name, ln.name)
        if name != ln.name:
            if name not in surface.by_name:
                report.unmappable.append(
                    (ln.name, ln.value,
                     'RENAMES maps it to %r, which build %s does not expose either -- the '
                     'mapping table is stale' % (name, surface.build_tag)))
                continue
            report.renamed.append((ln.name, name, ln.value))
            resolved[name] = ln.value
            continue
        if name in surface.by_name:
            report.kept.append((name, ln.value))
            resolved[name] = ln.value
            continue
        report.unmappable.append(
            (ln.name, ln.value,
             'build %s does not expose this key and RENAMES has no entry for it. It is reported '
             'rather than dropped: dropping a key whose meaning nobody has decided is how a '
             'setting silently stops applying.' % surface.build_tag))

    for decl in surface.inputs:
        if decl.name in resolved:
            continue
        if decl.name in defaults:
            resolved[decl.name] = defaults[decl.name]
            report.filled.append((decl.name, defaults[decl.name], 'supplied default'))
            continue
        report.unmappable.append(
            (decl.name, '',
             'build %s exposes this input, the old .set does not set it, and no default was '
             'supplied. A migration that guessed here would produce a full-surface file whose '
             'unguessed half came from nowhere.' % surface.build_tag))

    if not report.ok:
        return None, report

    out = list(comments)
    out.append('; MIGRATED by _triage/factory_os/setfile.py for build %s (%d inputs). This is a '
               'NEW file; the original was not modified.' % (surface.build_tag, len(surface)))
    for decl in surface.inputs:
        out.append('%s=%s' % (decl.name, resolved[decl.name]))
    return '\n'.join(out) + '\n', report


def _repo_root():
    return os.path.dirname(os.path.dirname(HERE))


def main(argv):
    """CLI: `setfile.py read <build_tag> <path>` | `setfile.py migrate <build_tag> <old> <new>`.

    `migrate` REFUSES to write when the destination exists. Overwriting the destination is one
    typo away from overwriting the source, and the ratified policy is that migration never edits
    in place.
    """
    import io
    if len(argv) < 3:
        sys.stderr.write('usage: setfile.py read <LAB_ENTRY_nn> <path>\n'
                         '       setfile.py migrate <LAB_ENTRY_nn> <old.set> <new.set>\n')
        return 2
    mode, build_tag, src = argv[0], argv[1], argv[2]
    root = _repo_root()
    inputs_text = io.open(os.path.join(root, preset.INPUTS_REL.replace('/', os.sep)),
                          encoding='utf-8-sig').read()
    try:
        surface = preset.parse_surface(inputs_text, build_tag)
    except Refusal as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 1
    old_text = io.open(src, encoding='utf-8-sig').read()

    if mode == 'read':
        try:
            values = read_set(old_text, surface)
        except Refusal as exc:
            sys.stderr.write('REFUSED: %s\n' % exc)
            return 1
        sys.stdout.write('%s loads for %s: %d input(s)\n' % (src, build_tag, len(values)))
        return 0

    if mode == 'migrate':
        if len(argv) < 4:
            sys.stderr.write('migrate needs a destination path\n')
            return 2
        dst = argv[3]
        if os.path.exists(dst):
            sys.stderr.write(
                'REFUSED: %s already exists. Migration writes a NEW file and never edits in '
                'place; refusing rather than overwriting, because the destination is one typo '
                'away from the source.\n' % dst)
            return 1
        # /scrutinize round 1 (ORDER-1020): defaults are RENDERED to the .set form, not copied as
        # declared. The declared default of `_0_MAMethod` is the symbol `MODE_EMA`; a real `.set`
        # carries `1`, and the first version of this line wrote the symbol -- producing a
        # migrated file that MIXED numeric kept-values with symbolic filled-values. The terminal
        # does not parse enum symbols in a `.set`, so the filled half would have loaded as
        # something else, silently -- the exact defect class this tool exists to prevent.
        defaults = dict((d.name, preset.render_value(d, d.default_expr, surface.enums))
                        for d in surface.inputs)
        try:
            text, report = migrate_set(old_text, surface, defaults=defaults)
        except Refusal as exc:
            sys.stderr.write('REFUSED: %s\n' % exc)
            return 1
        sys.stdout.write(report.render())
        if text is None:
            sys.stderr.write('REFUSED: %d key(s) could not be mapped; nothing was written.\n'
                             % len(report.unmappable))
            return 1
        io.open(dst, 'w', encoding='utf-8', newline='\n').write(text)
        sys.stdout.write('wrote %s\n' % dst)
        return 0

    sys.stderr.write('unknown mode %r\n' % mode)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
