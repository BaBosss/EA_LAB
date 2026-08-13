# -*- coding: utf-8 -*-
"""gen_default_preset.py -- ORDER-710's evidence tool: a full-surface `.set` of DECLARED defaults.

WHAT IT IS FOR. To compare the EA's `[CFG] input surface:` fingerprint against `preset.py`'s, a
run needs a configuration BOTH sides can be sure about. The declared defaults are that
configuration: they are written in `Inputs.mqh`, so the compiler can render them and the binary
holds them -- provided the `.set` actually reached the chart, which is the thing being tested.

WHY IT IS NOT A "CALLER" OF THE COMPILER. `ORDER-700` deliberately shipped with nothing that
generates a preset INTO the repo (a new store under `factory/` is an S2a ownership question).
This writes to a path the caller names, generates nothing into the repo by default, and exists to
produce evidence for one verification run -- `scripts/verify_config_fingerprint.ps1` is its only
caller.

CATEGORY: BUILDER. It reads through an `EvidenceSource` in **worktree** mode, on purpose and
stated in its output: the binary under test was compiled from the working tree, so the surface
this compares against has to be the working tree's too. Judging the index here would compare a
binary against bytes it was not built from.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import evidence     # noqa: E402
import gen_locked_constants as gen_consts   # noqa: E402
import preset       # noqa: E402


def defaults_layer(surface, unit_classes, account_unit='usd'):
    """Every input of this build, at the value ITS OWN DECLARATION gives.

    The rows are the declaration expressions verbatim (`EXIT_ATR_TP`, `PERIOD_H4`, `0.35`,
    `true`); `compile_preset` resolves each through `render_value`, which refuses any symbol
    that is neither a declared enum member nor one of the closed table of MQL5 platform
    constants. A default this tool cannot resolve is therefore a REFUSAL, never a guess.

    A money-denominated default carries its UNIT, because the compiler refuses a bare number
    for one (P8) -- and it refused this tool on its first run, which is the rule working. The
    unit declared is the account unit being compiled for, and that is a statement rather than a
    conversion: `_16_BasketTpUsdPer01 = 25.0` in the source means 25 units of whatever account
    the author had in mind, and the compiler CARRIES units, it never converts them.
    """
    rows = []
    for d in surface.inputs:
        if preset.is_money_unit(unit_classes.get(d.name)):
            rows.append((d.name, {'value': d.default_expr, 'unit': account_unit}))
        else:
            rows.append((d.name, d.default_expr))
    return [preset.Layer('defaults', rows)]


def build(build_tag, overrides=None, root=ROOT):
    src = evidence.EvidenceSource('worktree', root=root)
    surface = preset.load_surface(src, build_tag)
    unit_classes = preset.load_unit_classes(src)
    layers = defaults_layer(surface, unit_classes)
    if overrides:
        layers.append(preset.Layer('hypothesis', list(overrides)))
    # ORDER-730: the locked constants join the preimage here, which is what moves the scope from
    # `surface_only` to `surface+constants`. They come from the SAME EvidenceSource as the surface
    # -- a constant read from the disk while the surface came from the index would fingerprint a
    # configuration no single snapshot has.
    consts = gen_consts.constants_for(
        src.read_committed, build_tag,
        gen_consts._resolve_wrappers(src.read_committed, src.read_committed(preset.INPUTS_REL),
                                     _wrapper_rels(root))[1][build_tag])
    return preset.compile_preset(surface, layers, 'usd',
                                 unit_classes=unit_classes,
                                 locked_constants=consts,
                                 enums=preset.load_enums(src)), surface


def read_overlay(path, surface, unit_classes):
    """Read an existing .set as an explicit value layer without losing money units."""
    rows = []
    with open(path, 'r', encoding='utf-8-sig') as handle:  # snapshot: worktree -- explicit overlay path
        for raw in handle:
            text = raw.strip()
            if not text or text.startswith(';') or '=' not in text:
                continue
            key, value = text.split('=', 1)
            if key not in surface.by_name:
                raise preset.PresetRefusal('%s is not on %s' % (key, surface.build_tag))
            if preset.is_money_unit(unit_classes.get(key)):
                value = {'value': value, 'unit': 'usd'}
            rows.append((key, value))
    return rows


def _wrapper_rels(root):
    return gen_consts.wrapper_rels_on_disk(root)


def main(argv):
    build_tag = None
    out = None
    root = ROOT
    overrides = []
    overlay = None
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == '--build':
            build_tag = argv[i + 1]
            i += 2
        elif a == '--out':
            out = argv[i + 1]
            i += 2
        elif a == '--root':
            root = os.path.abspath(argv[i + 1])
            i += 2
        elif a == '--override':
            key, _sep, val = argv[i + 1].partition('=')
            if not _sep:
                sys.stderr.write('--override needs NAME=VALUE, got %r\n' % argv[i + 1])
                return 2
            overrides.append((key, val))
            i += 2
        elif a == '--overlay-set':
            overlay = argv[i + 1]
            i += 2
        else:
            sys.stderr.write('unknown argument %r\n' % a)
            return 2
    if not build_tag or not out:
        sys.stderr.write('usage: gen_default_preset.py --build LAB_ENTRY_nn --out FILE '
                         '[--override NAME=VALUE ...]\n')
        return 2
    try:
        if overlay:
            src = evidence.EvidenceSource('worktree', root=root)
            surface = preset.load_surface(src, build_tag)
            unit_classes = preset.load_unit_classes(src)
            overrides = read_overlay(overlay, surface, unit_classes)
        pre, surface = build(build_tag, overrides, root=root)
    except (preset.PresetRefusal, evidence.ToolFailure) as exc:
        sys.stderr.write('%s: %s\n' % (type(exc).__name__, exc))
        return 1
    text = preset.render_set(pre, header_note=(
        'ORDER-710 fingerprint verification. Declared defaults of %s, full surface (%d keys).\n'
        'Generated by _triage/factory_os/gen_default_preset.py from the WORKING TREE.'
        % (build_tag, len(surface))))
    import io
    io.open(out, 'w', encoding='utf-8', newline='\n').write(text)
    # One machine-readable line per fact -- the PowerShell caller parses these.
    print('build=%s' % build_tag)
    print('keys=%d' % len(surface))
    print('scope=%s' % pre.fingerprint_scope)
    print('expected_hash=%s' % pre.effective_config_hash)
    print('set_file=%s' % out)
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
