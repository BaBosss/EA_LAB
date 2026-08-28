# -*- coding: utf-8 -*-
"""capability.py -- ORDER-1020 (slice S7). Which capability modules a hypothesis actually uses.

WHAT DESIGN 5.3 ASKS FOR. "The allowlist header defines one capability token per module the
hypothesis actually uses (`LAB_CAP_STACK`, `LAB_CAP_RECOVERY`, `LAB_CAP_HEDGE`, `LAB_CAP_REGIME`,
`LAB_CAP_MACROGATE`, ...). Inputs outside the wrapper's capability set become `const` at their
canonical default." That is what takes Boss_14's Operator surface from **116 visible inputs** down
towards the design's target of **<= 40** -- not by hiding dials, but by making the ones a given
hypothesis cannot reach stop being dials at all.

THE TOKEN SET IS DERIVED, NOT LISTED. `enabled_tokens()` reads the SAME mechanism selectors that
`architecture.py` reads, through the same config, so "which modules does this hypothesis use" and
"what architecture is this hypothesis" cannot answer differently. A hand-written module list per
hypothesis would be a second opinion about the same fact, and it would go stale in the direction
that costs the most: a token left in after the mode that needed it was turned off keeps a whole
input group visible and sweepable, and nothing would say so.

  🔴 A CAPABILITY IS "THE MODULE CAN RUN", NOT "THE MODULE DID RUN". `LAB_CAP_RECOVERY` is off when
  `RecoveryMode == REC_NONE` because the engine is then unreachable for EVERY tick of every run.
  It is NOT off merely because a particular backtest never happened to trigger recovery -- that is
  a property of the window, not of the build, and a token that flickered with the data would make
  two runs of one hypothesis compile to different binaries.

WHAT `module_version` MEANS HERE, STATED BECAUSE IT IS EASY TO OVER-READ. The core modules in
`ea_template/core/` are NOT independently versioned; they ship as one chassis, and the version
that exists is the one the build wrapper declares (`#property version "2.00"` in
`ea_template/Boss_14_GridLog.mq5`). So `module_version` is read from THAT, for every module in the
set, and it is a CHASSIS version. Recording it that way is the honest option: it makes the absence
of per-module versioning visible instead of manufacturing eight version numbers that no source
would agree with. When modules do get versioned independently, this function is the one place that
changes.

  Two alternatives were considered and rejected, recorded so they are not re-proposed:
  a `#define LAB_MODULE_VER_*` per header would be picked up by `gen_locked_constants.py` -- which
  enumerates every valued `#define` that reaches the build -- and would therefore move EVERY
  build's `effective_config_hash`, a money-path change made for a bookkeeping field. A content
  digest of each module file would be a true version, but it changes on every core edit, so a
  registered `module_set` would go stale on commits that do not touch the hypothesis at all.

WHY `stability` IS `EXPERIMENTAL` AND NOT A JUDGEMENT CALL. Design 3.2: a module becomes
`CERTIFIABLE` when it is "promoted to Stable Core + parity + regression CLEAN". The parity harness
is slice S8 and has never run. Until it has, there is no module in this tree that has met the
stated condition, so `CERTIFIABLE` is not available to be written truthfully -- and design 3.2's
consequence (REFUSE experimental evidence as promotion evidence) is exactly the protection that
should be in force while the harness does not exist yet.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): BUILDER. Every byte comes from the caller: the
config from the caller, and the wrapper text through a `read(relpath) -> text` callable, so a
checker can drive it from an `EvidenceSource`. Only the CLI opens a path, and it says which.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import architecture                               # noqa: E402  (path set above)
import preset                                     # noqa: E402  (path set above)

Refusal = preset.PresetRefusal

WRAPPER_DIR = 'ea_template'

# The two stabilities `schemas.json` allows. Named here so the reason a value is chosen can cite
# the vocabulary rather than a literal that could drift from the schema unnoticed.
STABILITY_EXPERIMENTAL = 'EXPERIMENTAL'
STABILITY_CERTIFIABLE = 'CERTIFIABLE'

# build tag -> the wrapper `.mq5` that declares the chassis version. Derived from the same
# `#ifdef LAB_ENTRY_nn` model `architecture.ENTRY_MODULE` uses, and CLOSED for the same reason.
WRAPPER_FILE = {
    'LAB_ENTRY_11': 'Boss_11_GridTrend.mq5',
    'LAB_ENTRY_12': 'Boss_12_Breakout.mq5',
    'LAB_ENTRY_13': 'Boss_13_MeanRev.mq5',
    'LAB_ENTRY_14': 'Boss_14_GridLog.mq5',
    'LAB_ENTRY_15': 'Boss_15_ST03.mq5',
    'LAB_ENTRY_16': 'Boss_16_KangarooGrid.mq5',
    'LAB_ENTRY_17': 'Boss_17_Wave5.mq5',
    'LAB_ENTRY_18': 'Boss_18_JumStoch.mq5',
    'LAB_ENTRY_19': 'Probe_19_AdaptiveTrendGrid.mq5',
}

# The capability vocabulary. Each entry: token -> (module relpath, selector input, test).
# `test` is `('NE', value)` -- enabled unless the selector holds that value -- or `('EQ', value)`
# -- enabled ONLY at that value. Both forms exist because both shapes are real: `Recovery` is off
# at exactly one value of `RecoveryMode` and on at the other three, while `PriceAction` is
# reachable at exactly ONE value of `StackConfirm` and unreachable at the other four. Collapsing
# them into a single "!= off" would have made PriceAction look enabled under CONF_SIG_VALID,
# CONF_RETRIGGER and CONF_PRICE_ACT, none of which reach that module.
#
# CLOSED, and an unlisted concern is not silently "always on": adding a module to the chassis
# without adding it here makes `check_param_surface.py`'s coverage criterion fail, because the
# inputs that module owns then belong to no token.
_ALWAYS_ON = object()   # the module every build compiles and reaches; no selector turns it off

CAPABILITY = {
    'LAB_CAP_CORE':      ('ea_template/core/LabCore.mqh',         _ALWAYS_ON, None),
    'LAB_CAP_EXEC':      ('ea_template/core/Execution.mqh',       _ALWAYS_ON, None),
    'LAB_CAP_INDICATORS': ('ea_template/core/Indicators.mqh',     _ALWAYS_ON, None),
    'LAB_CAP_EXIT':      ('ea_template/core/ExitManager.mqh',     _ALWAYS_ON, None),
    'LAB_CAP_MM':        ('ea_template/core/MoneyManagement.mqh', _ALWAYS_ON, None),
    'LAB_CAP_RISK':      ('ea_template/core/RiskControl.mqh',     _ALWAYS_ON, None),
    'LAB_CAP_STACK':     ('ea_template/core/Stack.mqh',           'StackMode',      ('NE', 'STACK_SINGLE')),
    'LAB_CAP_LOTPROG':   ('ea_template/core/MoneyManagement.mqh', 'LotProg',        ('NE', 'PROG_NONE')),
    'LAB_CAP_RECOVERY':  ('ea_template/core/Recovery.mqh',        'RecoveryMode',   ('NE', 'REC_NONE')),
    'LAB_CAP_HEDGE':     ('ea_template/core/Hedge.mqh',           'HedgeMode',      ('NE', 'HEDGE_OFF')),
    'LAB_CAP_REGIME':    ('ea_template/core/Regime.mqh',          '_50_RegimeMode', ('NE', '0')),
    'LAB_CAP_MACROGATE': ('ea_template/core/MacroGate_Core.mqh',  '_MG_SelfGate',   ('NE', 'false')),
    # PriceAction is reached only through the strongest stack confirmation. It is a capability
    # rather than a dial because the module is genuinely unreachable at any other StackConfirm --
    # `Stack_DecideAdd` returns before it -- so every input it owns is inert, not merely unused.
    'LAB_CAP_PRICEACTION': ('ea_template/core/PriceAction.mqh', 'StackConfirm',   ('EQ', 'CONF_PA_ENGULF')),
}

# Entry modules get their own token, because the entry IS a capability -- one per build, and the
# generated allowlist has to name it for the wrapper to be a wrapper rather than a build flag.
ENTRY_TOKEN_PREFIX = 'LAB_CAP_ENTRY_'

# Builds whose ownership overrides make an OTHERWISE-ENABLED module unreachable. Same table shape
# and the same reason as `architecture._BUILD_OWNER_OVERRIDE`: `Boss_16`/Kangaroo short-circuits
# before `Stack` and `ExitManager` in `LabCore.mqh`, so a `StackMode` other than SINGLE there does
# NOT mean the stacking module runs -- `Inputs.mqh:156` calls its own value "informational only".
_BUILD_TOKEN_SUPPRESS = {
    'LAB_ENTRY_16': ('LAB_CAP_STACK',),
}

# Build-local direct calls can make a generic selector understate reachability. Boss19 requires
# StackMode=SINGLE but still calls Stack_MarginBudgetOK() from Stack.mqh for every pending leg,
# so the module is reachable even while the ordinary StackMode selector says the strategy stack
# is off. This forces module reachability only; activation still decides which individual inputs
# are effective for Boss19.
_BUILD_TOKEN_FORCE = {
    'LAB_ENTRY_19': ('LAB_CAP_STACK',),
}

_VERSION_RE = re.compile(r'^\s*#property\s+version\s+"([^"]*)"\s*$', re.M)


def entry_token(build_tag):
    """-> the capability token naming this build's entry module."""
    module = architecture.ENTRY_MODULE.get(build_tag)
    if module is None:
        raise Refusal(
            'build tag %r has no entry module, so it has no entry capability token. Refused '
            'rather than given a generic one: a wrapper whose entry token does not name a real '
            'module compiles to a build with no signal.' % build_tag)
    # `Entry_GridLog` -> `LAB_CAP_ENTRY_GRIDLOG`. The schema pins `^LAB_CAP_[A-Z0-9_]+$`.
    return ENTRY_TOKEN_PREFIX + module.replace('Entry_', '', 1).upper()


def _canon(value, decl=None, enums=None):
    """-> the canonical (.set-form) spelling of a selector value.

    /scrutinize round 1 (ORDER-1020): the first version compared trimmed strings and its
    docstring argued that was the safe choice. It was the opposite: a real `.set` spells
    `RecoveryMode=80` and `HedgeMode=0`, and a raw-string compare against `REC_NONE`/`HEDGE_OFF`
    enabled LAB_CAP_RECOVERY and LAB_CAP_HEDGE at exactly their OFF values -- a wrapper compiling
    modules the hypothesis does not use. When the declaration and the enum table are available
    (every production path passes a surface), both sides go through `preset.render_value`, which
    REFUSES an unknown symbol rather than coercing anything -- so `off` still cannot become `0`
    by accident, which is the thing the old comment was right to fear."""
    text = str(value).strip()
    if decl is not None and enums is not None:
        return preset.render_value(decl, text, enums)
    return text


def enabled_tokens(build_tag, config, surface=None):
    """-> sorted tuple of the capability tokens this (build, config) enables."""
    if build_tag not in WRAPPER_FILE:
        raise Refusal(
            'build tag %r is not in WRAPPER_FILE, so this module cannot say which capabilities '
            'it has. Known: %s' % (build_tag, ', '.join(sorted(WRAPPER_FILE))))
    if surface is not None and surface.build_tag != build_tag:
        raise Refusal('the supplied surface is build %s but the capability set asked for is %s'
                      % (surface.build_tag, build_tag))

    suppressed = _BUILD_TOKEN_SUPPRESS.get(build_tag, ())
    tokens = {entry_token(build_tag)}
    tokens.update(_BUILD_TOKEN_FORCE.get(build_tag, ()))
    for token, (_module, selector, test) in CAPABILITY.items():
        if token in suppressed:
            continue
        if selector is _ALWAYS_ON:
            tokens.add(token)
            continue
        if surface is not None and selector not in surface.by_name:
            raise Refusal(
                'capability %s is selected by %r, which build %s does not expose. Refused rather '
                'than treated as off: "the selector is missing" and "the selector says off" have '
                'different fixes, and only one of them is a working build.'
                % (token, selector, build_tag))
        if selector not in config:
            raise Refusal(
                'capability %s is selected by %r, which has no value in the supplied config. '
                'Refused rather than defaulted to off: a capability silently switched off turns '
                'every input it owns into a const, which is a change of strategy made by an '
                'omission.' % (token, selector))
        op, ref = test
        decl = surface.by_name.get(selector) if surface is not None else None
        enums = getattr(surface, 'enums', None) if surface is not None else None
        held = _canon(config[selector], decl, enums)
        want = _canon(ref, decl, enums)
        if (op == 'NE' and held != want) or (op == 'EQ' and held == want):
            tokens.add(token)
    return tuple(sorted(tokens))


def chassis_version(read, build_tag):
    """-> the version string the build's wrapper declares. `read(relpath) -> text`."""
    rel = WRAPPER_FILE.get(build_tag)
    if rel is None:
        raise Refusal('no wrapper file is known for build %r' % build_tag)
    rel = '%s/%s' % (WRAPPER_DIR, rel)
    text = read(rel)
    found = _VERSION_RE.findall(text)
    if not found:
        raise Refusal(
            '%s declares no `#property version`, so there is no version to record for the modules '
            'this build compiles. Refused rather than defaulted to "1": a version nobody declared '
            'cannot distinguish two builds, which is the only job the field has.' % rel)
    if len(set(found)) > 1:
        raise Refusal(
            '%s declares %d DIFFERENT `#property version` values (%s). Refused rather than taking '
            'the first: last-wins across lines that disagree is the defect, not the parse.'
            % (rel, len(found), ', '.join(sorted(set(found)))))
    return found[0]


def module_set(build_tag, config, read, surface=None, stability=STABILITY_EXPERIMENTAL):
    """-> the `module_set` array a Hypothesis row carries, sorted by token.

    `stability` defaults to EXPERIMENTAL and the caller has to pass CERTIFIABLE deliberately --
    design 3.2 makes that a promotion decision with a stated condition (parity + regression
    CLEAN), and a default of CERTIFIABLE would grant it by omission.
    """
    if stability not in (STABILITY_EXPERIMENTAL, STABILITY_CERTIFIABLE):
        raise Refusal('stability %r is not one of %s'
                      % (stability, [STABILITY_EXPERIMENTAL, STABILITY_CERTIFIABLE]))
    version = chassis_version(read, build_tag)
    return [{'token': token, 'module_version': version, 'stability': stability}
            for token in enabled_tokens(build_tag, config, surface=surface)]


def _repo_root():
    return os.path.dirname(os.path.dirname(HERE))


def main(argv):
    import io
    if not argv:
        sys.stderr.write('usage: capability.py <LAB_ENTRY_nn> [Name=Value ...]\n')
        return 2
    build_tag = argv[0]
    overrides = {}
    for a in argv[1:]:
        if '=' not in a:
            sys.stderr.write('not a Name=Value pair: %r\n' % a)
            return 2
        k, v = a.split('=', 1)
        overrides[k] = v
    root = _repo_root()

    def read(rel):
        return io.open(os.path.join(root, rel.replace('/', os.sep)), encoding='utf-8-sig').read()

    try:
        surface = preset.parse_surface(read(preset.INPUTS_REL), build_tag)
        config = dict((d.name, d.default_expr) for d in surface.inputs)
        config.update(overrides)
        rows = module_set(build_tag, config, read, surface=surface)
    except Refusal as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 1
    sys.stdout.write('build         : %s\n' % build_tag)
    sys.stdout.write('config source : declared defaults from %s%s\n'
                     % (preset.INPUTS_REL,
                        (', overridden: ' + ', '.join(sorted(overrides))) if overrides else ''))
    for row in rows:
        sys.stdout.write('  %-26s version=%s stability=%s\n'
                         % (row['token'], row['module_version'], row['stability']))
    sys.stdout.write('%d capability token(s)\n' % len(rows))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
