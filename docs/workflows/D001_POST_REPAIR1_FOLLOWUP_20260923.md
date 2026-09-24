# D001 Post-Repair1 Follow-up — Prospective Contract

Classification: INPUT_QUALIFICATION_TOOLING / NEW_SUCCESSOR_CONTRACT / NO_MT5.

Predecessor evidence: rejected head `55207d86bbbdb206e0b00cace5eaccca476bec5d`; Repair1 and targeted recheck are consumed. Preserve D001-1 invalid-container PASS and D001-3 Build-identity PASS. This contract does not extend or reset Repair1.

## Objective

Close only the two still-open findings:
1. D001-2 raw malformed start-tag acceptance caused by tolerant HTMLParser normalization.
2. D001-4 lossy float alias agreement above binary-float exactness.

## D001-2 raw tag validation

Validate the raw start-tag token before normalized parser-event acceptance, preferably at the existing `_ReportHTML` tokenizer / `parse_starttag` seam. Do not use a document-wide regex or a blacklist of known bad strings.

The validator must consume the whole raw token deterministically. `/` is not whitespace. Self-close is exactly `/>` with no whitespace between `/` and `>`. Reject missing attribute values, repeated `=`, unfinished quotes, illegal nested `<`, duplicate ambiguous attribute names, and malformed structural start tags such as `<table / >`, `<tr / >`, and `<td / >`.Preserve valid mixed-case tags, comments/style raw text opacity, the existing script prohibition, valid MT5 HTML forms, and legitimate void tags. Structural self-closing table/tr/td remains rejected.

## D001-4 exact numeric alias agreement

At the private alias-agreement seam, validate each textual alias with the existing closed NUM_TOKEN grammar, normalize accepted grouping, construct `decimal.Decimal` directly from normalized text, and compare Decimal values before any downstream float conversion. Do not reconstruct the comparison value from float and do not expand the public accepted numeric language.

Required controls:
- `9007199254740992` vs `9007199254740993` => CONFLICT
- `1` vs `1.0` => SAME
- `1.00` vs `1.000` => SAME
- `-0` vs `0` => SAME
- equivalent grouped values => SAME
- distinct high-precision decimals => CONFLICT
- malformed alias => reject entire input
- exponent / NaN / Infinity remain rejected unless the existing contract already permits them

Public downstream float output may remain unchanged; only private conflict detection is corrected.

## Allowed paths

- `docs/workflows/D001_POST_REPAIR1_FOLLOWUP_20260923.md`
- `scripts/parse_mt5_report.py`
- `scripts/_test/test_mt5_input_qualification.py`
- `scripts/_test/run_parse_mt5_report_tests.ps1`- `scripts/_test/fixtures/factory_vnext/test_factory_vnext_pilot.py`
- `scripts/_test/run_factory_vnext_operationalization_tests.ps1`
- `tools/research_preflight/test_preflight.py`
- `tools/hermes_ea_lab_pilot/tests/test_safe_tester_executor.py`

No old evidence mutation; no PROJECT_STATE/P03/AGENTS mutation from author; no Factory production logic; no MQL/core/risk/runtime paths; no MT5 or HOLDOUT.

## Acceptance

Preserve D001-1 and D001-3 behavior, existing public successful-result keys, and Factory/Research/Hermes error mappings.

Required regression:
- all 8 Build6090 templates
- pinned B11 MAIN/BWD
- Factory 212
- Research 41
- Hermes 20
- operationalization suite
- pycompile
- PowerShell parse where applicable
- `git diff --check`
- normal hooks

One bounded in-scope repair maximum. Freeze one exact clean head, then one independent exact-head GPT Scrutiny. Author cannot self-approve. Workers do not push.

## Direct execution checkpoint — 2026-09-23

Status: `BLOCKED_HERMES_RUNTIME_APPLICATION_CONTROL`. This is an uncommitted
author checkpoint, not acceptance, freeze, or scrutiny. Current canonical was
fresh-fetched and matched remote master at
`372c73e5f33f39fa445c748f40cbfed5565c6831`. Existing lane/worktree/branch were
retained; starting HEAD is `8aae48d9c6afea826aaa2534be051da140f5fd6c`.
The dirty primary checkout was preserved.

The owner's explicit prerequisite import and corrected P2 pin were verified
before source mutation. No active ownership conflict was found. P1/P2 were
reproduced as projections that remove the rejected end-tag/buffer workaround,
float alias helper/wiring, and old D001-2/D001-4 tests. P3-P7 are exact authorized
whole blobs. The rejected predecessor was not merged or cherry-picked.

| Prerequisite | Verified Git blob SHA-1 |
|---|---|
| P1 | `49fe157bce0da706dc7a320635e7a2e62c503460` |
| P2 | `4202695d370bdcd535ee53c48ee65bec508a49b3` |
| P3 | `d40ef7e22964d7f9db6b6f16de1dc56af0e3f78a` |
| P4 | `38ea3b3119f9b40e654a28a4b843aad7d5cc7a98` |
| P5 | `568b8479ed9d9adbb3bb0ca3b29f4d9f44750b7c` |
| P6 | `afdbac32304327f9d67e63518a69f69fa52a388a` |
| P7 | `70282b1cd088bab5d949cef331288845ed50a915` |

P1 SHA256: `1e9284bb9b08137b4c9c43c80b796e33e506b6bf6c5a7d88ab3433cf02baa433`
(16,694 bytes / 419 lines). P2 SHA256:
`2ffeaf4d875a4f6a9dcad6a81c710cbf4fbd7ff30e334a73f0dec323080352c2`
(9,536 bytes / 181 lines). Imported bytes were rehashed before adding tests.

Prerequisite-only qualification passed 10 test groups, including the retained
D001-1/D001-3 behavior and all eight Build6090 output comparisons. New tests
then produced 95 expected failing subcases with the prerequisite parser unchanged.
The successor validates raw markup with a token-by-token scanner inside
`_ReportHTML` before `feed`; it does not use a document-wide regex, blacklist,
`parse_endtag` override, or pre-close buffered-token workaround. Comments and
style raw text remain opaque. Alias comparison constructs Decimal values from
NUM_TOKEN-validated, grouping-normalized text before downstream float validation.

Successor repair usage: **1/1 consumed**. After the first 17-group green run, an
additional adversarial probe demonstrated that `<table width>` was accepted
without an attribute value. Repair1 added this missing-value negative coverage
(three red subcases across table/tr/td) and restricted valueless attributes to
recognized HTML boolean attributes, preserving legitimate void/boolean controls.
The full 17-group qualification suite then passed. Historical predecessor
Repair1/recheck remain consumed independently. No further source repair is
authorized by this contract.

Completed post-repair gates: qualification 17 groups, eight Build6090 templates,
original hash-pinned B11 MAIN/BWD (43 numeric checks including synthetic fixture),
Factory 212, Research 41, operationalization, Python compilation, PowerShell
syntax parsing, and `git diff --check`.

Hermes's installed runtime fails during dependency import, before any of the
20 safe-tester tests executes: `ImportError: DLL load failed while importing
unicodedata: An Application Control policy has blocked this file.` The same
environment failure occurs at the V2 wrapper's first suite. No dependency,
policy, Hermes production source, or test expectation was altered to bypass it.
This is an environment blocker, not a reported Hermes test PASS or product
finding. The all-deterministic-gates-PASS requirement therefore prevents staging,
hooks, and the requested one normal commit. Work remains uncommitted in the
existing lane for Main CT intake; review is NOT_STARTED and push NOT_PERFORMED.

Reproduction evidence (external, existing lane folder):
`D:\EA_LAB_CONTROL\evidence\d001-post-repair1-followup-v1-20260923`.
`admission_corrected.json` records all seven identities and pre-import hashes;
`import_verified.json`, `prerequisite_controls.log`, `red_first.log`,
`repair1_red.log`, `repair1_green.log`, and `*_final.log` preserve observations.
`EXECUTION_RESULT_20260923.json` binds the final source and evidence hashes.

## Owner-authorized additional style-data repair — 2026-09-23

The owner authorized one additional bounded repair on the existing D001 successor,
limited to style content entering extracted report data. Historical Repair1 remains
**1/1 consumed**; this additional owner repair is **1/1 consumed**. The reviewed
input was clean HEAD `8758a8c01652b2829b9136ff872f14c73a84d765`, tree
`c0e6273413a33d5cbe336df46eecc0993de04e23`, with all three authorized
file bytes matching HEAD. A fresh fetch matched `origin/master` and remote
`refs/heads/master` at `c24eec92edd5f30d715478cb2cf6eac38cf0f4ee`.
The reviewed source was not rebased or merged.

Red-first evidence: three new style test groups against the reviewed parser
produced three failures (style-only Expert label, preamble Build, and required
value) plus two errors (style changing a legitimate label or value). The
raw-token opacity control passed. After source repair, the same groups passed.
The matrix also verifies that style cannot supply title Build identity, and
that legitimate head/style and inline style markup preserve visible report
data and valid reports.

The parser now discards `handle_data` events while `style` is on the element
stack. This structural boundary keeps style characters out of title identity,
table discovery, labels, values, and preamble Build identity. Script rejection,
raw-token grammar, Decimal alias comparison, and public metrics were not
changed.

Post-repair gates: complete input qualification 20/20 groups and synthetic
parser checks 24/24; all eight Build6090 templates matched the baseline;
original hash-pinned B11 MAIN/BWD checks passed; Factory 212/212; Research
41/41; operationalization PASS; Hermes 20/20 with the previously qualified
Python 3.11 route and process-local existing site-packages. No MT5, HOLDOUT,
strategy, runtime, or environment mutation was performed. Independent
targeted recheck has not started; push was not performed.
