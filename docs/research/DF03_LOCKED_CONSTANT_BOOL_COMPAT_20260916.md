# DF03 locked-constant boolean compatibility — 2026-09-16

Base: `2a42b8aee98dbd2437de1b684ae96893ee2916c4`.
Role: Codex Primary tooling author. No commit or push.

The canonical scanner now recognises exact lowercase MQL literals `true` and
`false` as numeric 1 and 0 in its existing arithmetic folder. Scalar literals
canonicalise as longs (`1` / `0`); nested arithmetic, prior constant references,
and existing double promotion continue through the same canonicalisation path.
The emitter still reads the macro through `CFG_CanonLong((long)NAME)`.
No source substitution or fingerprint exclusion was introduced.

Only these files changed:

- `_triage/factory_os/gen_locked_constants.py`
- `_triage/factory_os/run_locked_constants_metadata_tests.py`
- `docs/research/DF03_LOCKED_CONSTANT_BOOL_COMPAT_20260916.md`

The existing metadata test owner grew from 7 to 31 checks. Coverage includes both
literals, nested arithmetic and references, unary arithmetic, double promotion,
quoted strings, emitted canonicalizer, fingerprint mapping, equivalent numeric
redefinition, and 15 refusal cases. The latter cover unknown/prefix/uppercase
identifiers, Python boolean spellings, forward references, string arithmetic,
calls, unsupported logical syntax, conflicting definitions, division by zero,
and `#if` / `#elif`. The original scanner loaded from HEAD also reproduced the
boolean refusal on an in-memory B21 fixture.

Validation used `. scripts/use_python.ps1` followed by
`$pythonExe = Assert-PortablePython -Provision`. Python commands used `-B`;
explicit compilation output went to a temporary directory outside the repository.

| Validation | Result |
| --- | --- |
| `run_locked_constants_metadata_tests.py` | 31/31 PASS |
| `run_input_surface_tests.py --mutate` | 20/20 attack/specificity checks; 10/10 mutations detected |
| `check_input_surface_gen.py --worktree` | ACCEPTED, all 9 existing wrappers |
| `run_preset_tests.py --mutate` | 20/20 attack/specificity checks; 10/10 mutations detected; populated synthetic E2E PASS |
| `run_wrapper_gen_tests.py` | 13/13 attacks, real-tree specificity and gate-assignment property PASS |
| `test_factory_vnext_semantic_metadata.py` | 11/11 PASS |
| `py_compile.compile(..., doraise=True)` for both changed Python files | 2/2 PASS |
| `git diff --check` | PASS |

Preset and wrapper suites are existing Factory fast-cage components; semantic
metadata is the directly affected Factory vNext fixture suite. The generic
`run_fast_cages.ps1 -ExportSelection` has no active mapping for the three changed
paths and proposed running every suite. Relevant suites above were run directly;
no full-tier PASS is claimed.

Both canonical generators were evaluated in memory and compared as UTF-8 bytes
against their existing generated files. Both comparisons passed exactly:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `ea_template/core/LockedConstants_gen.mqh` | 19787 | `d9f0fa0cb413b8da8ff37321c5a4ed269a83d1cc0b25a624323f01889af7ce7b` |
| `ea_template/core/InputSurface_gen.mqh` | 95364 | `1be03fc77b831bff2783846ceee0ae7ae8d254b6efde6c38d2ceabb4e7f9df6a` |

The original and repaired scanners produced identical canonical constant mappings
for all 9 current owners (`LAB_ENTRY_11` through `LAB_ENTRY_19`). Existing generated
fingerprint bytes therefore did not change. No generated header was rewritten;
the condition requiring regeneration was not met.

This is scanner compatibility evidence, not a generated DF03/B21 fingerprint or
MT5 acceptance claim: this exact base has no B21 canonical wrapper owner. DF03
source/adapter, Inputs, LabCore, Execution, PARAM registry, taskboards/state and
runtime/tester surfaces were not modified. No MT5, MetaEditor, terminal or
Strategy Tester was invoked.
