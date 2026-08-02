# -*- coding: utf-8 -*-
"""architecture.py -- ORDER-1000 (slice S7). The `architecture_digest` a Hypothesis carries.

WHY THIS EXISTS AT ALL. `schemas.json` requires every `Hypothesis` row to carry a 16-hex
`architecture_digest` and says of it: *"hash of (entry, exit_owner, stack_owner, lot_owner,
recovery, hedge, regime). Change here MECHANICALLY forces a new revision."* Until this file
existed there was NO producer of that value anywhere in the tree -- so the only way to register a
hypothesis was to TYPE a digest, and a typed digest is a hand-maintained cache of a fact that
lives in the code. It would be right on the day it was typed and silently wrong on the day the
architecture moved, which is precisely the revision boundary it exists to force. `BACKLOG-D29`'s
shape, one layer down.

WHAT AN ARCHITECTURE IS HERE, AND WHAT IT IS NOT. The seven fields are the MECHANISM SELECTORS:
which entry module, which exit owner, which stacking law, which lot law, which recovery engine,
which hedge, which regime gate. They are the answers to "what is this strategy" -- not "how is it
tuned". A numeric dial (`_33_SL_ATRmult`, `_8_TriggerATR`) moves inside one architecture; the
enum that decides WHICH module reads that dial does not. Getting this line wrong in either
direction has a cost: too wide and every re-optimize forces a new revision, so nobody registers
one; too narrow and two genuinely different strategies share a digest and their evidence pools.

THE OWNERSHIP OVERRIDES ARE THE PART THAT IS NOT MECHANICAL. `Boss_16`/Kangaroo owns its own exit
and its own stacking pipeline -- `LabCore` short-circuits before `ExitManager` and before
`Stack` -- so reading `ExitMode`/`StackMode` for that build would report a mechanism that never
runs. `Inputs.mqh:156` says so in its own comment ("informational only"). That is why
`_BUILD_OWNER_OVERRIDE` is a CLOSED table and an unlisted build is not defaulted into the generic
answer: a build added later without a decision here would silently be described by inputs that
may be inert on it.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): PURE. It takes every byte from its caller --
`Inputs.mqh` text and a config mapping -- and opens no path of its own.
"""
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import preset                                    # noqa: E402  (path set above)

Refusal = preset.PresetRefusal


# The seven fields, in the order the preimage lists them. ONE definition: the digest's meaning is
# this tuple, so a second copy of it somewhere else would be a second opinion about what an
# architecture IS, and the two would disagree at the revision boundary.
ARCHITECTURE_FIELDS = (
    'entry', 'exit_owner', 'stack_owner', 'lot_owner', 'recovery', 'hedge', 'regime',
)

# The digest length. 16 hex characters, because `schemas.json` pins `^[0-9a-f]{16}$` -- stated
# here as a named constant so a schema change and this file cannot drift apart silently.
DIGEST_HEX = 16

# build tag -> the entry module that build compiles. Derived from the `#ifdef LAB_ENTRY_nn`
# include block in `ea_template/core/LabCore.mqh`; CLOSED, because a build whose entry module is
# unknown has no architecture at all and must be refused rather than described as "generic".
ENTRY_MODULE = {
    'LAB_ENTRY_11': 'Entry_GridTrendMA',
    'LAB_ENTRY_12': 'Entry_Breakout',
    'LAB_ENTRY_13': 'Entry_MeanReversion',
    'LAB_ENTRY_14': 'Entry_GridLog',
    'LAB_ENTRY_15': 'Entry_ST03',
    'LAB_ENTRY_16': 'Entry_KangarooRSI',
    'LAB_ENTRY_17': 'Entry_Wave5',
    'LAB_ENTRY_18': 'Entry_JumStoch',
}

# The selector inputs each field is computed from, in the order they enter that field's value.
# An input named here that the build does not expose is a REFUSAL, not a skipped term -- the
# whole point is that the digest describes THIS build, and a silently dropped term makes two
# builds that differ share one digest.
FIELD_SELECTORS = {
    'entry':       (),                                # from ENTRY_MODULE, not from an input
    'exit_owner':  ('ExitMode', 'SLMode'),
    'stack_owner': ('StackMode', 'StackConfirm'),
    'lot_owner':   ('FirstLotMode', 'LotProg'),
    'recovery':    ('RecoveryMode',),
    'hedge':       ('HedgeMode',),
    'regime':      ('_50_RegimeMode',),
}

# Builds whose module ownership is NOT what the generic selectors say. The value is the owner
# name that replaces the whole field.
#
# `Boss_16` (Kangaroo): `LabCore.mqh` short-circuits before both `ExitManager` and `Stack`, so
# `ExitMode`/`StackMode`/`StackConfirm` are declared, settable, and never read on that build.
# `Inputs.mqh:156` labels its own `StackMode` "informational only". Reading them here would put a
# mechanism into the architecture that does not run.
_BUILD_OWNER_OVERRIDE = {
    'LAB_ENTRY_16': {
        'exit_owner':  'Kangaroo',
        'stack_owner': 'Kangaroo',
    },
}


def _selector_value(config, surface, name):
    """-> the canonical string for one selector input. Refuses two different absences separately,
    because they have different fixes: not on the surface = this table is wrong for this build;
    on the surface but not in the config = the caller handed over a partial config."""
    if surface is not None and name not in surface.by_name:
        raise Refusal(
            'architecture selector %r is not exposed by build %s, so the seven-field table is '
            'wrong for this build. Refused rather than dropped: a dropped term makes two builds '
            'that genuinely differ hash to one digest, and the digest exists to force a new '
            'revision exactly there.' % (name, surface.build_tag))
    if name not in config:
        raise Refusal(
            'architecture selector %r has no value in the supplied config. Refused rather than '
            'defaulted -- a default here would describe an architecture nobody configured, and '
            'the resulting digest would be a claim about a strategy that was never run.' % name)
    value = config[name]
    if value is None:
        raise Refusal('architecture selector %r is present but null in the supplied config' % name)
    return str(value).strip()


def architecture_of(build_tag, config, surface=None):
    """-> OrderedDict-shaped dict of the seven fields for (build_tag, config).

    `config` maps input name -> value (rendered or raw; it is stringified). `surface` is the
    parsed `Surface` for this build when the caller has one -- passing it turns "this selector is
    not on this build" from an undetectable silence into a refusal.
    """
    if build_tag not in ENTRY_MODULE:
        raise Refusal(
            'build tag %r has no entry module in ENTRY_MODULE, so its architecture is unknown. '
            'Refused rather than described generically: the CLOSED table is what stops a build '
            'added later from being silently characterised by inputs that may be inert on it. '
            'Known: %s' % (build_tag, ', '.join(sorted(ENTRY_MODULE))))
    if surface is not None and surface.build_tag != build_tag:
        raise Refusal(
            'the supplied surface is build %s but the architecture asked for is %s. Refused: a '
            'mismatched pair would check the selectors against the wrong build and report the '
            'absence of nothing.' % (surface.build_tag, build_tag))

    override = _BUILD_OWNER_OVERRIDE.get(build_tag, {})
    arch = {}
    for field in ARCHITECTURE_FIELDS:
        if field in override:
            arch[field] = override[field]
            continue
        if field == 'entry':
            arch[field] = ENTRY_MODULE[build_tag]
            continue
        parts = [_selector_value(config, surface, name) for name in FIELD_SELECTORS[field]]
        arch[field] = '/'.join(parts)
    return arch


def preimage(arch):
    """-> the exact bytes the digest is taken over. Separate from `digest()` so a test can read
    what was hashed rather than only whether two digests differ -- a digest comparison alone
    cannot say WHICH field moved, and 'the digest changed' is not a diagnosis."""
    missing = [f for f in ARCHITECTURE_FIELDS if f not in arch]
    if missing:
        raise Refusal(
            'architecture is missing field(s) %s. Refused rather than hashed over what is '
            'present: a short preimage produces a perfectly well-formed 16-hex digest, so the '
            'omission would be invisible in the only place anyone looks.' % ', '.join(missing))
    extra = [f for f in sorted(arch) if f not in ARCHITECTURE_FIELDS]
    if extra:
        raise Refusal(
            'architecture carries field(s) %s that are not in ARCHITECTURE_FIELDS. Refused: an '
            'unlisted field either belongs in the tuple (and then every existing digest is '
            'stale) or does not belong in an architecture at all. Both need a decision, and '
            'hashing it silently makes neither.' % ', '.join(extra))
    lines = ['%s=%s' % (f, arch[f]) for f in ARCHITECTURE_FIELDS]
    return '\n'.join(lines) + '\n'


def digest(arch):
    """-> the 16-hex `architecture_digest`."""
    return hashlib.sha256(preimage(arch).encode('utf-8')).hexdigest()[:DIGEST_HEX]


def digest_for(build_tag, config, surface=None):
    """-> (architecture dict, digest). The call a Hypothesis writer makes."""
    arch = architecture_of(build_tag, config, surface=surface)
    return arch, digest(arch)


def _repo_root():
    return os.path.dirname(os.path.dirname(HERE))


def main(argv):
    """CLI: `architecture.py <LAB_ENTRY_nn> [Name=Value ...]`. Values not supplied on the command
    line come from the build's own declared defaults, and the output SAYS which is which -- a
    digest printed without saying what it was taken over is the thing this module exists to stop
    people writing down."""
    import io
    if not argv:
        sys.stderr.write('usage: architecture.py <LAB_ENTRY_nn> [Name=Value ...]\n')
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
    text = io.open(os.path.join(root, preset.INPUTS_REL.replace('/', os.sep)),
                   encoding='utf-8-sig').read()
    try:
        surface = preset.parse_surface(text, build_tag)
    except Refusal as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 1
    config = {}
    for decl in surface.inputs:
        config[decl.name] = decl.default_expr
    config.update(overrides)

    try:
        arch, dig = digest_for(build_tag, config, surface=surface)
    except Refusal as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 1
    sys.stdout.write('build            : %s\n' % build_tag)
    sys.stdout.write('config source    : declared defaults from %s%s\n'
                     % (preset.INPUTS_REL,
                        (', overridden: ' + ', '.join(sorted(overrides))) if overrides else ''))
    sys.stdout.write('preimage:\n')
    for line in preimage(arch).rstrip('\n').split('\n'):
        sys.stdout.write('  %s\n' % line)
    sys.stdout.write('architecture_digest: %s\n' % dig)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
