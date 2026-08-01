# -*- coding: utf-8 -*-
"""gen_input_surface.py -- ORDER-710 (slice S6, the `[CFG]` half).

WHAT IT EMITS. `ea_template/core/InputSurface_gen.mqh`: for every build tag declared in
`ea_template/core/Inputs.mqh`, the code that walks that build's OWN input surface at run time
and writes the fingerprint preimage `preset.py` hashes. The EA can then print, at `OnInit`, a
hash of THE VALUES THE BINARY IS HOLDING -- which is a different claim from the hash of the
`.set` file somebody meant to load, and the difference is the whole point (memories
`attach-verify-gate-and-binary` and `proving-a-set-was-loaded-on-a-chart`: a bundle whose own
`.set` set `AllowLive=false` killed three legs silently for three days, and a hand-built diff
table lied in two directions).

WHY THIS IS GENERATED AND NOT WRITTEN BY HAND (ORDER-710 C1). MQL5 has no reflection, so the
enumeration has to exist as source. A hand-kept enumeration is a COPY of the input surface, and
a copy of a fact is the thing `BACKLOG-D29`/`L0` exist to refuse: it is right on the day it is
typed and silently wrong on the day an input is added. So it is generated, and
`check_input_surface_gen.py` refuses any commit where the generated file and `Inputs.mqh`
disagree AT THE SAME SNAPSHOT.

ONE PARSER, NOT TWO. The surface comes from `preset.parse_surface` -- the same call, on the
same file, that the compiler uses. A second parser here would be a second opinion about what a
build exposes, and the two would drift exactly where it costs the most: in the fingerprint that
exists to prove they agree.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): BUILDER. It takes its source text from the
caller (`emit()`); only the CLI opens a path, and it says which one it opened.
"""
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import preset                                    # noqa: E402  (path set above)

OUT_REL = 'ea_template/core/InputSurface_gen.mqh'
GENERATOR_REL = '_triage/factory_os/gen_input_surface.py'

# The MQL5 canonicaliser each declared type is routed through. The KEYS ARE THE CONTRACT: a type
# that is not here is REFUSED rather than emitted through a default, because a default here
# would silently hash a value in a form `preset.canonical_for_hash` does not produce, and the
# two sides would disagree only for the inputs nobody checked by hand.
_CANON_CALL = {
    'bool':   'CFG_CanonBool(%s)',
    'double': 'CFG_CanonDouble(%s)',
    'int':    'CFG_CanonLong((long)%s)',
    'long':   'CFG_CanonLong((long)%s)',
    'string': 'CFG_CanonString(%s)',
}


def canon_call(decl):
    """-> the MQL5 expression that renders this input into the preimage."""
    if decl.mql_type in _CANON_CALL:
        return _CANON_CALL[decl.mql_type] % decl.name
    if decl.mql_type.startswith('ENUM_'):
        # An MQL5 enum is an integer at run time and `preset.canonical_for_hash` renders it with
        # `str(int(...))`. The cast is explicit so the compiler's 0-warnings policy (deploy.ps1)
        # is not spent on an implicit conversion.
        return 'CFG_CanonLong((long)%s)' % decl.name
    raise preset.PresetRefusal(
        'input %s has type %s, which this generator has no canonical MQL5 form for. Refused '
        'rather than emitted through a default: a default would hash the value in a form '
        'preset.canonical_for_hash does not produce, and the EA and the compiler would then '
        'disagree for exactly the inputs nobody checked by hand.' % (decl.name, decl.mql_type))


def emit(inputs_text):
    """Inputs.mqh text -> the full text of InputSurface_gen.mqh. Deterministic: no clock, no
    host path, no dict order. Newlines are '\\n'; git's autocrlf owns the working-tree form."""
    tags = sorted(preset.known_build_tags(inputs_text))
    if not tags:
        raise preset.PresetRefusal(
            'no LAB_ENTRY_* build tag is declared in the input source, so there is no build to '
            'enumerate. Refusing to emit a file that would compile to an empty surface.')
    out = []
    w = out.append
    w('//+------------------------------------------------------------------+')
    w('//| InputSurface_gen.mqh - GENERATED FILE, DO NOT EDIT BY HAND.       |')
    w('//| generator : %s' % GENERATOR_REL)
    w('//| source    : %s' % preset.INPUTS_REL)
    w('//| regenerate: tools\\python312\\python.exe %s --write' % GENERATOR_REL)
    w('//|                                                                   |')
    w('//| ORDER-710. One block per build tag; the wrapper defines exactly    |')
    w('//| one, so exactly one compiles. The strings below are the preimage   |')
    w('//| preset.py hashes -- see _fingerprint() there. Editing either side  |')
    w('//| alone does not break the build, it breaks the COMPARISON, which is |')
    w('//| why check_input_surface_gen.py regenerates this file on every      |')
    w('//| commit that touches either one.                                    |')
    w('//+------------------------------------------------------------------+')
    w('#ifndef BOSS_INPUT_SURFACE_GEN_MQH')
    w('#define BOSS_INPUT_SURFACE_GEN_MQH')
    w('')
    w('#include "ConfigFingerprint.mqh"')
    w('')
    for tag in tags:
        surface = preset.parse_surface(inputs_text, tag)
        w('#ifdef %s' % tag)
        w('#define CFG_SURFACE_ENUMERATED')
        w('string CFG_BuildTag()    { return("%s"); }' % tag)
        w('int    CFG_SurfaceKeys() { return(%d); }' % len(surface))
        w('string CFG_SurfacePreimage()')
        w('  {')
        w('   string s = "scope=" + CFG_FP_SCOPE + "\\nbuild=%s";' % tag)
        for decl in surface.inputs:
            w('   s += "\\n%s=" + %s;' % (decl.name, canon_call(decl)))
        w('   return(s);')
        w('  }')
        w('#endif')
        w('')
    w('#ifndef CFG_SURFACE_ENUMERATED')
    w('// No LAB_ENTRY_* tag was defined by the time this file was included. Inputs.mqh falls')
    w('// back to LAB_ENTRY_11 when the wrapper defines none, so reaching here means this file')
    w('// was included BEFORE Inputs.mqh. Emit a fingerprint that cannot be mistaken for a real')
    w('// one rather than an empty string that would hash to a perfectly valid-looking digest.')
    w('string CFG_BuildTag()    { return("NO_BUILD_TAG"); }')
    w('int    CFG_SurfaceKeys() { return(-1); }')
    w('string CFG_SurfacePreimage() { return("UNENUMERATED"); }')
    w('#endif')
    w('')
    w('// The entry point LabCore prints. It lives HERE, after every block, because it calls')
    w('// CFG_SurfacePreimage() and the include that defines the canonicalisers is above.')
    w('string CFG_Fingerprint() { return(CFG_Sha256Hex(CFG_SurfacePreimage())); }')
    w('')
    w('#endif // BOSS_INPUT_SURFACE_GEN_MQH')
    return '\n'.join(out) + '\n'


def _repo_root():
    return os.path.dirname(os.path.dirname(HERE))


def main(argv):
    root = _repo_root()
    src = os.path.join(root, preset.INPUTS_REL.replace('/', os.sep))
    dst = os.path.join(root, OUT_REL.replace('/', os.sep))
    text = emit(io.open(src, encoding='utf-8-sig').read())  # snapshot: worktree
    if '--write' in argv:
        io.open(dst, 'w', encoding='utf-8', newline='\n').write(text)
        print('wrote %s (%d lines) from the WORKING TREE copy of %s'
              % (OUT_REL, text.count('\n'), preset.INPUTS_REL))
        return 0
    sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
