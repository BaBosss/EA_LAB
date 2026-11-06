#!/usr/bin/env python3
"""new_entry.py - one-command, additive, build-gated entry scaffold for the Boss V2 template.

WHY: adding an entry used to be a hand recipe (A10 C2, commit baabe23e): a wrapper, an entry module,
blocks in Inputs.mqh and LabCore.mqh, five generated files, a magic reservation, a regression preset, and
a proof that no existing build changed. The recipe lived in one-off scripts outside the repo.

WHAT IT DOES NOT DO: it edits no shared logic. It inserts only `#ifdef LAB_ENTRY_<NN>`-gated blocks at the
five hook sites an entry-only port needs. An entry that needs a new execution primitive, a changed shared
default or any other core edit is REFUSED by the anchors/validation here and stays manual core work.

USAGE
    python scripts/new_entry.py apply --manifest M.json [--root WT] [--no-compile] [--keep-on-fail]
    python scripts/new_entry.py prove [--root WT]      # HEAD vs working tree neutrality proof
    python scripts/new_entry.py selftest               # the proof must be able to FAIL (specificity)

Exit 0 only when every step and every check passed. On any failure `apply` restores every file it touched
(unless --keep-on-fail) and deletes the files it created.
"""
import argparse
import csv
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile

MARK = 'new_entry.py'
DEFAULT_METAEDITOR = r'D:\Meta 5\metaeditor64.exe'

# The fallback guard that makes a build tag known (preset.known_build_tags reads it).
FALLBACK_DEFINE = '#define LAB_ENTRY_11          // fallback build\n'

# Hook sites: (kind, anchor that must exist exactly once at the base commit). A new block goes after the
# last block this tool inserted for that kind, or after the anchor when it is the first.
INPUTS_STACK_ANCHOR = ('#ifdef LAB_ENTRY_25\n'
                       'const ENUM_STACK_MODE StackMode = STACK_SINGLE; // HIDDEN_INACTIVE: dedicated physical cycle owner\n'
                       'const ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;\n#endif\n')
INPUTS_TAIL = '#endif // BOSS_LAB_INPUTS_MQH\n'
LABCORE_ANCHORS = {
    'include': '#ifdef LAB_ENTRY_25\n   #include "entries/Entry_PersistentAdaptiveGrid.mqh"\n#endif\n',
    'init': '#ifdef LAB_ENTRY_22\n   Entry_WickDisplacement_Init();\n#endif\n',
    'deinit': '#ifdef LAB_ENTRY_19\n   Entry_AdaptiveTrendGrid_Deinit();\n#endif\n',
    'tick': '   if(AdaptiveTrendGrid_OnTick()) return;\n#endif\n',
}

# Every manifest value is matched with fullmatch(): `$` also matches before a trailing newline, and a newline in a
# value that lands in core text is how a hook call could smuggle in its own preprocessor lines.
IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
NAME = re.compile(r'[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)*')
CALL = re.compile(r'[A-Za-z_]\w*\([ A-Za-z0-9_,.+\-*"]*\);')
ENTRY_FILE = re.compile(r'Entry_[A-Za-z0-9_]+\.mqh')
EXTRA_FILE = re.compile(r'[A-Za-z0-9_]+\.mqh')
ENUM_CONST = re.compile(r'[A-Z][A-Z0-9_]*')
INPUT_DECL = re.compile(r'^input\s+([A-Za-z_]\w*)\s+(_\d+_\w+)\s*=\s*([^;]+);\s*(?://\s*(.*))?$')
INPUT_GROUP = re.compile(r'^input\s+group\s+"[^"\n]*"\s*;?\s*(?://.*)?$')
PID_TAG = re.compile(r'^\[P\d{5}\]\s*')


class Refuse(Exception):
    """A precondition or a cage failed. Nothing is left half applied."""


# ------------------------------------------------------------------ small io helpers
def rd(path):
    with io.open(path, encoding='utf-8-sig', newline='') as f:
        return f.read().replace('\r\n', '\n')


def wr(path, text):
    d = os.path.dirname(path)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)


def sha256_file(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def need_ascii(label, text):
    bad = sorted(set(c for c in text if ord(c) >= 128))
    if bad:
        raise Refuse('%s contains non-ASCII characters %r; this tool adds none to the repo' % (label, ''.join(bad[:8])))
    # A bare CR / form feed / vertical tab / NUL ends a line for some readers (MetaEditor, git) but not for the
    # '\n' splitting the neutrality proof does, so a control character is how text could break out of a comment.
    ctl = sorted(set(c for c in text if (ord(c) < 32 and c not in '\n\t') or ord(c) == 127))
    if ctl:
        raise Refuse('%s contains control characters %r; only \\n and \\t are allowed' % (label, ''.join(ctl)))


def git(root, *args, **kw):
    r = subprocess.run(('git', '-C', root) + args, capture_output=True)
    if r.returncode != 0 and not kw.get('ok_fail'):
        raise Refuse('git %s failed: %s' % (' '.join(args), r.stderr.decode('utf-8', 'replace').strip()))
    return r.stdout.decode('utf-8', 'replace')


# ------------------------------------------------------------------ manifest
def load_manifest(path):
    base = os.path.dirname(os.path.abspath(path))
    with io.open(path, encoding='utf-8-sig') as f:
        m = json.load(f)

    def need(key, kind):
        if key not in m or not isinstance(m[key], kind):
            raise Refuse('manifest: %r missing or not %s' % (key, kind.__name__))
        return m[key]
    out = {}
    out['build'] = need('build', int)
    if out['build'] < 11 or out['build'] > 99:
        raise Refuse('manifest: build %d outside 11..99' % out['build'])
    out['name'] = need('name', str)
    if not NAME.fullmatch(out['name']):
        raise Refuse('manifest: name %r must look like Donchian_Pullback / DonchianPullback' % out['name'])
    out['title'] = need('title', str).strip()
    if not out['title'] or '"' in out['title'] or '\n' in out['title']:
        raise Refuse('manifest: title must be one line without double quotes')
    out['entry_source'] = os.path.join(base, need('entry_source', str))
    out['inputs_source'] = os.path.join(base, need('inputs_source', str))
    out['entry_file'] = m.get('entry_file') or 'Entry_%s.mqh' % out['name']
    if not ENTRY_FILE.fullmatch(out['entry_file']):
        raise Refuse('manifest: entry_file %r must be Entry_<Name>.mqh' % out['entry_file'])
    for key in ('init_call', 'deinit_call'):
        v = (m.get(key) or '').strip()
        if v and not v.endswith(';'):
            v += ';'
        if v and not CALL.fullmatch(v):
            raise Refuse('manifest: %s %r must be ONE single-line function call (letters, digits, _ , . + - * and quotes only)'
                         % (key, v))
        out[key] = v
    ot = m.get('own_ontick')
    if ot is not None and (not isinstance(ot, str) or not IDENT.fullmatch(ot)):
        raise Refuse('manifest: own_ontick must be null or a function name')
    out['own_ontick'] = ot
    st = need('stack', dict)
    for key in ('mode', 'confirm'):
        if not isinstance(st.get(key), str) or not ENUM_CONST.fullmatch(st[key]):
            raise Refuse('manifest: stack.%s must be an ENUM constant such as STACK_SINGLE' % key)
    out['stack'] = {'mode': st['mode'], 'confirm': st['confirm'], 'note': str(st.get('note', 'n/a')).replace('\n', ' ')}
    out['magic'] = need('magic', int)
    if not 100000 <= out['magic'] <= 99999999:
        raise Refuse('manifest: magic %d is not a plausible magic number' % out['magic'])
    ov = m.get('preset_overlay', {})
    if not isinstance(ov, dict) or not all(isinstance(k, str) and isinstance(v, (str, int, float, bool)) for k, v in ov.items()):
        raise Refuse('manifest: preset_overlay must be {name: value}')
    out['preset_overlay'] = dict((k, str(v).lower() if isinstance(v, bool) else str(v)) for k, v in ov.items())
    out['extra_files'] = [os.path.join(base, p) for p in m.get('extra_files', [])]
    for p in out['extra_files']:
        if not EXTRA_FILE.fullmatch(os.path.basename(p)):
            raise Refuse('manifest: extra file name %r must be <letters/digits/_>.mqh' % os.path.basename(p))
    out['provenance'] = str(m.get('provenance', '')).replace('\n', ' ').strip()
    need_ascii('manifest provenance/title/stack note', out['provenance'] + out['title'] + out['stack']['note'])
    need_ascii('manifest preset_overlay', ''.join(k + v for k, v in out['preset_overlay'].items()))
    if any('\n' in k + v for k, v in out['preset_overlay'].items()):
        raise Refuse('manifest: preset_overlay names and values must be single-line')
    for p in [out['entry_source'], out['inputs_source']] + out['extra_files']:
        if not os.path.isfile(p):
            raise Refuse('manifest: source file not found: %s' % p)
    return out


def parse_entry_inputs(text, build):
    """-> list of ('group', line) / ('input', type, name, default, label). Refuses anything else."""
    items, seen = [], set()
    prefix = '_%d_' % build
    for n, raw in enumerate(text.split('\n'), 1):
        line = raw.strip()
        if not line or line.startswith('//'):
            continue
        if INPUT_GROUP.match(line):
            items.append(('group', line.rstrip(';').split('//')[0].strip()))
            continue
        m = INPUT_DECL.match(line)
        if not m:
            raise Refuse('inputs_source line %d is not a plain `input <type> %s<Name> = <default>; // label`: %r' % (n, prefix, line))
        typ, name, default, label = m.group(1), m.group(2), m.group(3).strip(), (m.group(4) or '').strip()
        if not name.startswith(prefix):
            raise Refuse('inputs_source line %d: %s must start with %s (the build-local prefix)' % (n, name, prefix))
        if name in seen:
            raise Refuse('inputs_source line %d: duplicate input %s' % (n, name))
        seen.add(name)
        label = PID_TAG.sub('', label) or name
        items.append(('input', typ, name, default, label))
    if not any(i[0] == 'input' for i in items):
        raise Refuse('inputs_source declares no inputs')
    return items


def render_entry_inputs(items, build, name, srcsha):
    n_inputs = sum(1 for i in items if i[0] == 'input')
    if n_inputs > 100:
        raise Refuse('%d entry inputs; the parameter-id range [P%d..P%d] holds 100' % (n_inputs, 10000 + build * 100, 10099 + build * 100))
    pid0 = 10000 + build * 100
    out = ['// %s: build %d %s (inputs source sha256 %s)\n#ifdef LAB_ENTRY_%d\n' % (MARK, build, name, srcsha, build)]
    k = 0
    for it in items:
        if it[0] == 'group':
            out.append(it[1] + '\n')
            continue
        _, typ, nm, default, label = it
        out.append('#ifndef LAB_CONST_%s\ninput %s %s = %s; // [P%d] %s\n#endif\n'
                   '#ifdef LAB_CONST_%s\nconst %s %s = LAB_CONSTVAL_%s;\n#endif\n'
                   % (nm, typ, nm, default, pid0 + k, label, nm, typ, nm, nm))
        k += 1
    out.append('#endif\n')
    return ''.join(out)


def render_stack(stack, build):
    return ('#ifdef LAB_ENTRY_%d\n'
            '#ifndef LAB_CONST_StackMode\ninput ENUM_STACK_MODE    StackMode    = %s;       // 90 (Entry %d: %s)\n#endif\n'
            '#ifdef LAB_CONST_StackMode\nconst ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;\n#endif\n'
            '#ifndef LAB_CONST_StackConfirm\ninput ENUM_STACK_CONFIRM StackConfirm = %s;      // n/a\n#endif\n'
            '#ifdef LAB_CONST_StackConfirm\nconst ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;\n#endif\n'
            '#endif\n') % (build, stack['mode'], build, stack['note'], stack['confirm'])


# ------------------------------------------------------------------ text insertion
def end_marker(kind, build):
    return '// %s: end %s build %d\n' % (MARK, kind, build)


def insert_hook(text, kind, build, body, base_anchor):
    """Insert `body` after the last block this tool added for `kind`, else after `base_anchor`."""
    if end_marker(kind, build) in text:
        raise Refuse('%s block for build %d already present' % (kind, build))
    marks = list(re.finditer(r'(?m)^// %s: end %s build \d+\n' % (re.escape(MARK), re.escape(kind)), text))
    if marks:
        pos = marks[-1].end()
    else:
        if text.count(base_anchor) != 1:
            raise Refuse('hook anchor for %r not found exactly once (found %d): %r'
                         % (kind, text.count(base_anchor), base_anchor[:70]))
        pos = text.index(base_anchor) + len(base_anchor)
    return text[:pos] + body + end_marker(kind, build) + text[pos:]


def edit_inputs(text, mf, items, srcsha):
    b = mf['build']
    if re.search(r'(?m)^#ifndef LAB_ENTRY_%d$' % b, text) or ('LAB_ENTRY_%d\n' % b) in text:
        raise Refuse('build %d is already declared in Inputs.mqh' % b)
    if text.count(FALLBACK_DEFINE) != 1:
        raise Refuse('fallback define not found exactly once in Inputs.mqh')
    text = text.replace(FALLBACK_DEFINE, '#ifndef LAB_ENTRY_%d\n%s#endif\n' % (b, FALLBACK_DEFINE), 1)
    text = insert_hook(text, 'stack', b, render_stack(mf['stack'], b), INPUTS_STACK_ANCHOR)
    if not text.endswith('\n' + INPUTS_TAIL) and not text.endswith(INPUTS_TAIL):
        raise Refuse('Inputs.mqh does not end with the include-guard tail')
    block = render_entry_inputs(items, b, mf['name'], srcsha)
    return text[:-len(INPUTS_TAIL)] + block + '\n' + INPUTS_TAIL


def edit_labcore(text, mf):
    b = mf['build']
    text = insert_hook(text, 'include', b, '#ifdef LAB_ENTRY_%d\n   #include "entries/%s"\n#endif\n' % (b, mf['entry_file']),
                       LABCORE_ANCHORS['include'])
    if mf['init_call']:
        text = insert_hook(text, 'init', b, '#ifdef LAB_ENTRY_%d\n   %s\n#endif\n' % (b, mf['init_call']), LABCORE_ANCHORS['init'])
    if mf['deinit_call']:
        text = insert_hook(text, 'deinit', b, '#ifdef LAB_ENTRY_%d\n   %s\n#endif\n' % (b, mf['deinit_call']), LABCORE_ANCHORS['deinit'])
    if mf['own_ontick']:
        text = insert_hook(text, 'tick', b,
                           '#ifdef LAB_ENTRY_%d\n   // %s: entry-owned pipeline (runs its own DD/halt cage first, then always returns).\n'
                           '   if(%s()) return;\n#endif\n' % (b, MARK, mf['own_ontick']), LABCORE_ANCHORS['tick'])
    return text


def render_wrapper(mf, entry_sha, inputs_sha):
    b, name = mf['build'], mf['name']
    prov = ('// %s: entry source sha256 %s; inputs source sha256 %s.\n' % (MARK, entry_sha, inputs_sha))
    if mf['provenance']:
        prov += '// %s\n' % mf['provenance']
    return ('//+------------------------------------------------------------------+\n'
            '//| Boss_%d_%s.mq5 - generated by scripts/new_entry.py\n'
            '//|   Boss Lab V2 chassis - Entry %d: %s.\n'
            '//+------------------------------------------------------------------+\n'
            '#property copyright "EA_LAB / Boss"\n#property version   "2.00"\n'
            '#property description "Boss Lab V2 - %d %s"\n#property strict\n%s\n'
            '#define LAB_ENTRY_%d\n#define LAB_ENTRY_TAG "%d_%s"\n#include "core/LabCore.mqh"\n'
            % (b, name, b, mf['title'], b, mf['title'], prov, b, b, name))


def registry_rows(items, mf, inputs_text):
    lines = inputs_text.split('\n')
    rows = []
    for it in items:
        if it[0] != 'input':
            continue
        _, typ, nm, default, label = it
        ln = next(i for i, l in enumerate(lines, 1) if re.match(r'^input\s+\S+\s+%s\s*=' % re.escape(nm), l.strip()))
        pid = re.search(r'\[P(\d{5})\]', lines[ln - 1]).group(1)
        rows.append([nm, 'entries/%s' % mf['entry_file'], 'UNKNOWN', 'entry', 'build %d only' % mf['build'], 'none direct',
                     '%s - Inputs.mqh:%d' % (default, ln), 'UNKNOWN', 'UNKNOWN', label, 'ACTIVE',
                     '%s build %d; declared type %s' % (MARK, mf['build'], typ), pid, 'UNKNOWN', 'UNKNOWN', label, ''])
    return rows


def csv_rows_text(rows):
    buf = io.StringIO()
    w = csv.writer(buf, quoting=csv.QUOTE_ALL, lineterminator='\n')
    for r in rows:
        w.writerow(r)
    return buf.getvalue()


def add_wrapper_owner(text, build, wrapper_rel):
    lines = text.rstrip('\n').split('\n')
    head, body = lines[0], lines[1:]
    if any(l.startswith('LAB_ENTRY_%d,' % build) for l in body):
        raise Refuse('wrapper_owners.csv already has LAB_ENTRY_%d' % build)
    body.append('LAB_ENTRY_%d,%s' % (build, wrapper_rel))
    body.sort(key=lambda r: int(re.match(r'LAB_ENTRY_(\d+)', r).group(1)))
    return '\n'.join([head] + body) + '\n'


# ------------------------------------------------------------------ neutrality proof
def active(text, tag, annotate=False):
    """Lines of `text` that can be active when `tag` (or nothing) is the only defined build token.

    SOUND AGAINST MACROS DEFINED IN OTHER FILES. Known conditions are decided: LAB_ENTRY_<NN> names (defined only
    when it is `tag`) and names `#define`d unconditionally earlier in this file. A condition on any OTHER name (an
    include guard, a LAB_CONST_* token from a generated wrapper's allowlist header) is UNKNOWN: both branches are
    kept and each line carries the stack of unknown conditions guarding it (annotate=True returns
    (conditions, line) pairs). A condition is (kind, name, version): the version of a name goes up at every
    #define / #undef of it, so the same words asked before and after a change are different conditions, and the
    `#else` of a guard keeps the version it was asked at. Comparing annotated sequences therefore means
    "identical for every possible value of the unknown macros". #if / #elif are refused (the template does not
    use them) rather than guessed.

    Blank lines and whole-line comments carry no tokens and are dropped. Trailing comments stay: in MQL5 the
    trailing comment of an `input` line is its Inputs-tab label."""
    defined = set([tag]) if tag else set()
    maybe = set()      # defined/undefined under an unknown condition: not KNOWN either way
    ver = {}           # name -> number of #define/#undef seen so far
    out, stack, conds, cur = [], [], [], True

    def known(name):
        if name in defined:
            return True
        return name not in maybe and re.fullmatch(r'LAB_ENTRY_\d+', name) is not None

    def changed(name):
        ver[name] = ver.get(name, 0) + 1

    for l in text.split(chr(10)):
        s = l.strip()
        m = re.match(r'#(ifdef|ifndef)\s+(\S+)', s)
        if m:
            name, neg = m.group(2), m.group(1) == 'ifndef'
            if known(name):
                cond = (name in defined) != neg
                stack.append((cur, 'known', cond, None))
                cur = cur and cond
            else:
                key = (m.group(1), name, ver.get(name, 0))
                stack.append((cur, 'unknown', None, key))
                conds.append(key)
            continue
        if re.match(r'#(if|elif)\b', s):
            raise Refuse('unmodelled preprocessor directive %r (only ifdef/ifndef/else/endif/define/undef are supported)' % s)
        if s.startswith('#else'):
            parent, kind, cond, key = stack.pop()
            if kind == 'known':
                stack.append((parent, kind, not cond, None))
                cur = parent and (not cond)
            else:
                conds.pop()
                flipped = ('ifndef' if key[0] == 'ifdef' else 'ifdef', key[1], key[2])
                stack.append((parent, kind, None, flipped))
                conds.append(flipped)
            continue
        if s.startswith('#endif'):
            parent, kind, cond, key = stack.pop()
            if kind == 'unknown':
                conds.pop()
            cur = parent
            continue
        if not cur:
            continue
        u = re.match(r'#undef\s+(\S+)', s)
        if u:
            name = u.group(1)
            defined.discard(name)          # no longer KNOWN defined; later conditions on it are unknown
            if conds:
                maybe.add(name)
            changed(name)
        d = re.match(r'#define\s+(\S+)', s)
        if d:
            name = d.group(1)
            if conds:
                maybe.add(name)            # a define under an unknown condition decides nothing for later lines
            else:
                defined.add(name)
                maybe.discard(name)
            changed(name)
        if s == '' or s.startswith('//'):
            continue
        out.append((tuple(conds), l) if annotate else l)
    if stack:
        raise Refuse('unbalanced preprocessor nesting')
    return out


def existing_tags(base_inputs_text):
    return sorted(set(re.findall(r'(?m)^#ifndef (LAB_ENTRY_\d+)$', base_inputs_text)))


def is_code(rel):
    return rel.endswith('.mqh') or rel.endswith('.mq5')


# `active()` models only #ifdef/#ifndef/#else/#endif/#define inside ONE file. A condition on a macro defined in
# another file (an include guard, a LAB_CONST_* token from a generated wrapper's allowlist header) is not modelled,
# so a line added under such a condition could be live for an existing build while the proof says "identical".
# The audit closes that channel structurally: a preprocessor line ADDED to an existing file may only be
#   * #ifdef/#ifndef on a NEW LAB_ENTRY_<NN> tag (the new build's own switch),
#   * #endif / nothing else that opens or flips a condition (#else, #elif, #if, #undef, #pragma are refused),
#   * inside a region opened by such a new tag: LAB_CONST_*/LAB_CONSTVAL_* guards and defines, and the
#     `#include "entries/Entry_<Name>.mqh"` of the new entry,
#   * in the generated *_gen.mqh files only: `#define CFG_<NAME>` (the enumeration markers).
GEN_DEFINE = re.compile(r'#define CFG_[A-Z_]+(?: .*)?')
IN_REGION_DIRECTIVES = [
    re.compile(r'#(?:ifdef|ifndef) LAB_CONST_\w+'),
    re.compile(r'#define (?:LAB_CONSTVAL_\w+|LAB_CONST_\w+)(?: .*)?'),
    re.compile(r'#include "entries/Entry_[A-Za-z0-9_]+\.mqh"'),
]


def added_line_numbers(diff_text):
    """Line numbers (new file) of every added line in a `git diff -U0` of ONE file."""
    out = set()
    for m in re.finditer(r'(?m)^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', diff_text):
        start, count = int(m.group(1)), int(m.group(2)) if m.group(2) is not None else 1
        out.update(range(start, start + count))
    return out


def directive_violations(new_text, added, new_tags, rel=''):
    bad = []
    stack, in_new = [], False
    for n, raw in enumerate(new_text.split(chr(10)), 1):
        s = raw.strip()
        if not s.startswith('#'):
            continue
        is_added = n in added
        m = re.match(r'#(ifdef|ifndef)\s+(\S+)\s*$', s)
        if m:
            tag_is_new = m.group(2) in new_tags
            if is_added and not (tag_is_new or (in_new and IN_REGION_DIRECTIVES[0].fullmatch(s))):
                bad.append('line %d: %s' % (n, s))
            stack.append(in_new)
            # Only the POSITIVE test of a new tag is a region that existing builds skip. `#ifndef LAB_ENTRY_<new>`
            # (the fallback chain's guard) is true for every existing build, so its body is NOT a new-build region.
            in_new = in_new or (tag_is_new and m.group(1) == 'ifdef')
            continue
        if s.startswith('#endif'):
            if stack:
                in_new = stack.pop()
            continue
        if re.match(r'#(?:else|elif)', s) and stack:
            in_new = stack[-1]      # the other branch of any guard is never a new-build-only region
        if not is_added:
            continue
        if re.match(r'#(?:else|elif|if|undef|pragma)', s):
            bad.append('line %d: %s' % (n, s))
        elif in_new and any(p.fullmatch(s) for p in IN_REGION_DIRECTIVES[1:]):
            continue
        elif rel.endswith('_gen.mqh') and GEN_DEFINE.fullmatch(s):
            continue
        else:
            bad.append('line %d: %s' % (n, s))
    return bad


def audit_added_directives(root, rel, new_text, new_tags):
    diff = git(root, 'diff', '-U0', 'HEAD', '--', rel)
    return directive_violations(new_text, added_line_numbers(diff), new_tags, rel)


def prove(root):
    """HEAD vs working tree. Returns a list of lines; raises Refuse on any difference."""
    base_inputs = git(root, 'show', 'HEAD:ea_template/core/Inputs.mqh').replace('\r\n', '\n')
    tags = existing_tags(base_inputs)
    if not tags:
        raise Refuse('no existing build tags found at HEAD')
    tagset = tags + [None]
    new_tags = set(existing_tags(rd(os.path.join(root, 'ea_template', 'core', 'Inputs.mqh')))) - set(tags)
    changed = [p for p in git(root, 'diff', '--name-only', 'HEAD', '--', 'ea_template').split('\n') if p]
    new_files = [p for p in git(root, 'ls-files', '--others', '--exclude-standard', '--', 'ea_template').split('\n') if p]
    report, fail = [], []
    for rel in sorted(changed):
        if not is_code(rel):
            report.append('%-52s non-code change (not part of any build token stream)' % rel)
            continue
        old = git(root, 'show', 'HEAD:' + rel).replace('\r\n', '\n')
        new = rd(os.path.join(root, rel))
        for d in audit_added_directives(root, rel, new, new_tags):
            fail.append('%s: added preprocessor line outside the allowed shapes: %s' % (rel, d))
        if '\r' in new:
            fail.append('%s: contains a bare CR (line ends the proof does not split on)' % rel)
        same = 0
        for tag in tagset:
            a, b = active(old, tag, annotate=True), active(new, tag, annotate=True)
            if a == b:
                same += 1
                continue
            i = next((k for k, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
            fail.append('%s [%s]: active source differs at active line %d (base %d lines, now %d)'
                        % (rel, tag or 'no tag', i + 1, len(a), len(b)))
        report.append('%-52s identical active source for %d/%d existing builds' % (rel, same, len(tagset)))
    new_code = [p for p in new_files if is_code(p)]
    new_names = [os.path.basename(p) for p in new_code]
    for p in new_code:
        if '\r' in rd(os.path.join(root, p)):
            fail.append('%s: contains a bare CR' % p)
    reachable = []
    for dp, _, fs in os.walk(os.path.join(root, 'ea_template')):
        for f in fs:
            if not is_code(f):
                continue
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, root).replace('\\', '/')
            if rel in new_code:
                continue
            text = rd(p)
            for tag in tagset:
                for l in active(text, tag):
                    for nf in new_names:
                        if re.match(r'\s*#include\s+"[^"]*%s"' % re.escape(nf), l):
                            reachable.append('%s includes %s for existing build %s' % (rel, nf, tag or 'no tag'))
    report.append('new code files: %d; reachable from an existing build: %s' % (len(new_code), 'NONE' if not reachable else 'YES'))
    fail += reachable
    if fail:
        raise Refuse('NEUTRALITY PROOF FAILED:\n  ' + '\n  '.join(report + fail))
    report.append('PROOF HOLDS: every existing build (%s, no-tag fallback) sees byte-identical active source.'
                  % ', '.join(t.replace('LAB_ENTRY_', '') for t in tags))
    return report


def selftest(root):
    """The proof must be able to fail: an unguarded line must change an existing build, the same line
    under a new-build guard must not."""
    base = git(root, 'show', 'HEAD:ea_template/core/Execution.mqh').replace('\r\n', '\n').split('\n')
    i = next(k for k, l in enumerate(base) if l.startswith('bool Exec_CloseAll()'))
    b = '\n'.join(base)
    unguarded = '\n'.join(base[:i] + ['int g_injected = 1;'] + base[i:])
    guarded = '\n'.join(base[:i] + ['#ifdef LAB_ENTRY_98', 'int g_injected = 1;', '#endif'] + base[i:])
    checks = [
        ('unguarded line changes build 14', active(unguarded, 'LAB_ENTRY_14') != active(b, 'LAB_ENTRY_14')),
        ('unguarded line changes the no-tag build', active(unguarded, None) != active(b, None)),
        ('new-tag-guarded line leaves build 14 unchanged', active(guarded, 'LAB_ENTRY_14') == active(b, 'LAB_ENTRY_14')),
        ('new-tag-guarded line IS active for its own build', 'int g_injected = 1;' in active(guarded, 'LAB_ENTRY_98')),
    ]
    return checks


# ------------------------------------------------------------------ transactional apply
class Snapshot(object):
    def __init__(self):
        self.saved = {}

    def keep(self, path):
        if path in self.saved:
            return
        if os.path.exists(path):
            with open(path, 'rb') as f:
                self.saved[path] = (f.read(), os.stat(path).st_mode)
        else:
            self.saved[path] = None

    def restore(self):
        """Restore EVERY file even if one fails (a read-only attribute must not strand the rest)."""
        errors = []
        for path, saved in self.saved.items():
            try:
                if os.path.exists(path):
                    os.chmod(path, 0o666)
                if saved is None:
                    if os.path.exists(path):
                        os.remove(path)
                else:
                    data, mode = saved
                    with open(path, 'wb') as f:
                        f.write(data)
                    os.chmod(path, mode)
            except OSError as e:
                errors.append('%s: %s' % (path, e))
        if errors:
            raise Refuse('ROLLBACK INCOMPLETE, fix by hand (git restore / delete):\n  ' + '\n  '.join(errors))


# The cages must judge the files on disk. check_input_surface_gen and friends default to the INDEX (which still holds
# HEAD during an apply) unless told otherwise; EA_LAB_EVIDENCE=worktree is the documented switch.
WORKTREE_ENV = dict(os.environ, EA_LAB_EVIDENCE='worktree')


def run(argv, cwd, label):
    r = subprocess.run(argv, cwd=cwd, capture_output=True, env=WORKTREE_ENV)
    out = (r.stdout.decode('utf-8', 'replace') + r.stderr.decode('utf-8', 'replace')).strip()
    if r.returncode != 0:
        raise Refuse('%s failed (exit %d):\n%s' % (label, r.returncode, '\n'.join(out.split('\n')[-25:])))
    return out


def ps(root, script, *args):
    return ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', os.path.join(root, 'scripts', script)] + list(args)


def compile_wrapper(root, wrapper_rel, metaeditor):
    if not os.path.isfile(metaeditor):
        raise Refuse('MetaEditor not found: %s' % metaeditor)
    tmp = tempfile.mkdtemp(prefix='new_entry_compile_')
    import shutil
    shutil.copytree(os.path.join(root, 'ea_template'), os.path.join(tmp, 'ea_template'),
                    ignore=shutil.ignore_patterns('regression_reports', '*.ex5', '*.log'))
    src = os.path.join(tmp, wrapper_rel.replace('/', os.sep))
    logp = os.path.join(tmp, 'compile.txt')
    subprocess.run([metaeditor, '/compile:' + src, '/log:' + logp], timeout=600)   # exit code is non-zero on success too
    if not os.path.exists(logp):
        raise Refuse('compile produced no log at %s' % logp)
    txt = io.open(logp, encoding='utf-16', errors='replace').read()
    m = re.search(r'Result:\s*(\d+)\s+errors?,\s*(\d+)\s+warnings?', txt)
    ex5 = os.path.splitext(src)[0] + '.ex5'
    if not m or m.group(1) != '0' or m.group(2) != '0' or not os.path.exists(ex5):
        lines = [l for l in txt.split('\n') if re.search(r'error|warning', l)]
        raise Refuse('compile not 0/0: %s\n%s' % (m.group(0) if m else 'no Result line', '\n'.join(lines[:15])))
    return 'compile %s in isolated copy %s' % (m.group(0), tmp)


def check_destinations(dests, root):
    keys = [os.path.normcase(os.path.abspath(p)) for p in dests]
    if len(set(keys)) != len(keys):
        raise Refuse('two files in this manifest resolve to the same destination (entry_file / extra_files / wrapper): %s'
                     % ', '.join(os.path.relpath(p, root) for p in dests))
    for p in dests:
        if os.path.exists(p):
            raise Refuse('refusing to overwrite existing %s' % os.path.relpath(p, root))


def apply(manifest_path, root, do_compile, keep_on_fail, metaeditor):
    root = os.path.abspath(root)
    mf = load_manifest(manifest_path)
    b, name = mf['build'], mf['name']
    if git(root, 'status', '--porcelain', '--untracked-files=all').strip():
        raise Refuse('worktree is not clean; the neutrality proof compares HEAD with the working tree, so commit or '
                     'restore first:\n' + git(root, 'status', '--short')[:600])
    if not os.path.isfile(os.path.join(root, 'tools', 'python312', 'python.exe')):
        raise Refuse('portable Python missing in this worktree (the registry check shells out to it). Run: '
                     '. .\\scripts\\use_python.ps1; Assert-PortablePython -Provision')
    head = git(root, 'rev-parse', 'HEAD').strip()
    entry_text, inputs_text = rd(mf['entry_source']), rd(mf['inputs_source'])
    need_ascii('entry_source', entry_text)
    need_ascii('inputs_source', inputs_text)
    if not re.search(r'\bEntrySignal\s+Entry_Evaluate\s*\(', entry_text):
        raise Refuse('entry_source does not define `EntrySignal Entry_Evaluate()`; the generic path needs it even when the '
                     'entry owns its OnTick')
    for call in (mf['init_call'], mf['deinit_call']):
        if call and not re.search(r'\b%s\s*\(' % re.escape(call.split('(')[0]), entry_text):
            raise Refuse('hook call %s is not defined in entry_source' % call)
    if mf['own_ontick'] and not re.search(r'\b%s\s*\(' % re.escape(mf['own_ontick']), entry_text):
        raise Refuse('own_ontick %s is not defined in entry_source' % mf['own_ontick'])
    items = parse_entry_inputs(inputs_text, b)
    entry_sha, inputs_sha = sha256_file(mf['entry_source']), sha256_file(mf['inputs_source'])

    core = os.path.join(root, 'ea_template', 'core')
    p_inputs, p_labcore = os.path.join(core, 'Inputs.mqh'), os.path.join(core, 'LabCore.mqh')
    wrapper_rel = 'ea_template/Boss_%d_%s.mq5' % (b, name)
    p_wrapper = os.path.join(root, wrapper_rel.replace('/', os.sep))
    p_entry = os.path.join(core, 'entries', mf['entry_file'])
    p_preset = os.path.join(root, 'ea_template', 'sets', 'regression', 'Boss_%d_%s_defaults.set' % (b, name))
    p_owners = os.path.join(root, '_triage', 'factory_os', 'wrapper_owners.csv')
    p_registry = os.path.join(root, 'docs', 'PARAM_REGISTRY.csv')
    extra_dst = [os.path.join(core, 'entries', os.path.basename(p)) for p in mf['extra_files']]
    check_destinations([p_wrapper, p_entry, p_preset] + extra_dst, root)

    # everything that can be refused is computed BEFORE the first write
    new_inputs = edit_inputs(rd(p_inputs), mf, items, inputs_sha)
    new_labcore = edit_labcore(rd(p_labcore), mf)
    new_owners = add_wrapper_owner(rd(p_owners), b, wrapper_rel)
    for label, old_t, new_t in (('Inputs.mqh', rd(p_inputs), new_inputs), ('LabCore.mqh', rd(p_labcore), new_labcore)):
        if sum(ord(c) >= 128 for c in new_t) != sum(ord(c) >= 128 for c in old_t):   # existing Thai header stays; add none
            raise Refuse('the %s edit would add non-ASCII characters; this tool adds none to the repo' % label)
    rows = registry_rows(items, mf, new_inputs)
    reg_text = io.open(p_registry, encoding='utf-8', newline='').read()
    if not reg_text.endswith('\n'):
        raise Refuse('PARAM_REGISTRY.csv does not end with a newline')
    if any(('"%s"' % r[0]) in reg_text for r in rows):
        raise Refuse('an input of this entry already has a registry row')

    snap = Snapshot()
    gen_paths = [os.path.join(core, 'InputSurface_gen.mqh'), os.path.join(core, 'LockedConstants_gen.mqh'),
                 os.path.join(root, 'docs', 'PARAM_LINKAGE.md'), os.path.join(root, 'factory', 'magic_allocations.jsonl')]
    for p in [p_inputs, p_labcore, p_owners, p_registry, p_wrapper, p_entry, p_preset] + extra_dst + gen_paths:
        snap.keep(p)
    py, receipt = sys.executable, []
    try:
        wr(p_wrapper, render_wrapper(mf, entry_sha, inputs_sha))
        wr(p_entry, '// %s: build %d, copied from %s (sha256 %s)\n%s' % (MARK, b, os.path.basename(mf['entry_source']), entry_sha, entry_text))
        for src, dst in zip(mf['extra_files'], extra_dst):
            wr(dst, '// %s: build %d, copied from %s (sha256 %s)\n%s' % (MARK, b, os.path.basename(src), sha256_file(src), rd(src)))
        wr(p_inputs, new_inputs)
        wr(p_labcore, new_labcore)
        wr(p_owners, new_owners)

        sys.path.insert(0, os.path.join(root, '_triage', 'factory_os'))
        import magic as M                                           # the worktree's own copy
        store = M.store_path(root)
        inv = M.read_inventory(M.inventory_path(root))
        row = M.allocate(M.read_store(store), inv, head, magic=mf['magic'])
        M.append_allocation(store, row, inv, root=root)
        receipt.append(('magic reserved', str(mf['magic'])))

        fo = os.path.join(root, '_triage', 'factory_os')
        run([py, '-I', os.path.join(fo, 'gen_input_surface.py'), '--write'], root, 'gen_input_surface')
        run([py, '-I', os.path.join(fo, 'gen_locked_constants.py'), '--write'], root, 'gen_locked_constants')
        with io.open(p_registry, 'a', encoding='utf-8', newline='\n') as f:
            f.write(csv_rows_text(rows))
        run(ps(root, 'param_registry_fix_lines.ps1', '-Apply'), root, 'param_registry_fix_lines')   # dry run without -Apply
        run(ps(root, 'gen_param_linkage.ps1'), root, 'gen_param_linkage')
        receipt.append(('registry rows', str(len(rows))))

        ov = tempfile.NamedTemporaryFile('w', suffix='.set', delete=False)
        try:
            overlay = dict(mf['preset_overlay'])
            overlay['_0_Magic'] = str(mf['magic'])
            ov.write(''.join('%s=%s\n' % kv for kv in overlay.items()))
            ov.close()
            run([py, '-I', os.path.join(fo, 'gen_default_preset.py'), '--root', root, '--build', 'LAB_ENTRY_%d' % b,
                 '--out', p_preset, '--overlay-set', ov.name], root, 'gen_default_preset')
        finally:
            os.unlink(ov.name)
        receipt.append(('regression preset', os.path.relpath(p_preset, root).replace('\\', '/')))

        # -------- cages
        receipt += [('proof', l) for l in prove(root)]
        run([py, '-I', os.path.join(fo, 'check_input_surface_gen.py'), '--worktree'], root, 'check_input_surface_gen')
        receipt.append(('check_input_surface_gen', 'ACCEPTED'))
        run(ps(root, 'param_registry_check.ps1'), root, 'param_registry_check')
        receipt.append(('param_registry_check', 'CLEAN'))
        # --only: the whole-family run is red at HEAD for Boss_14/16 (their *_defaults.set predate the
        # surface); this tool answers for the build it adds, not for the family's historical debt.
        run([py, '-I', os.path.join(root, 'scripts', 'check_template_presets.py'), '--root', root,
             '--only', 'Boss_%d_%s' % (b, name)], root, 'check_template_presets')
        receipt.append(('check_template_presets', 'OK (new build only)'))
        run([py, '-I', os.path.join(fo, 'magic.py'), 'verify', '--root=' + root], root, 'magic verify')
        receipt.append(('magic verify', 'VERIFIED'))
        run([py, '-I', os.path.join(fo, 'run_preset_tests.py')], root, 'run_preset_tests')
        receipt.append(('run_preset_tests', 'PASS'))
        if do_compile:
            receipt.append(('compile', compile_wrapper(root, wrapper_rel, metaeditor)))
        else:
            receipt.append(('compile', 'SKIPPED (--no-compile); a build is not done until MetaEditor says 0/0'))
    except BaseException as exc:
        if not keep_on_fail:
            try:
                snap.restore()
                sys.stderr.write('apply failed: restored every touched file and removed the created ones\n')
            except Refuse as rb:
                raise Refuse('%s\n(original failure: %s)' % (rb, exc))
        raise
    return receipt


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)
    a = sub.add_parser('apply')
    a.add_argument('--manifest', required=True)
    a.add_argument('--root', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    a.add_argument('--no-compile', dest='compile', action='store_false', help='skip the isolated MetaEditor compile (on by default)')
    a.add_argument('--keep-on-fail', action='store_true')
    a.add_argument('--metaeditor', default=DEFAULT_METAEDITOR)
    p = sub.add_parser('prove')
    p.add_argument('--root', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    s = sub.add_parser('selftest')
    s.add_argument('--root', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    args = ap.parse_args(argv)
    try:
        if args.cmd == 'apply':
            for k, v in apply(args.manifest, args.root, args.compile, args.keep_on_fail, args.metaeditor):
                print('%-26s %s' % (k, v))
            print('RESULT: applied. Review `git diff`, commit, then send for review. Not committed by this tool.')
        elif args.cmd == 'prove':
            print('\n'.join(prove(os.path.abspath(args.root))))
        else:
            res = selftest(os.path.abspath(args.root))
            for name, ok in res:
                print('[%s] %s' % ('PASS' if ok else 'FAIL', name))
            return 0 if all(ok for _, ok in res) else 1
    except Refuse as e:
        sys.stderr.write('REFUSED: %s\n' % e)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
