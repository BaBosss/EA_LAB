# EA_LAB W5 B6230 — proposed offline evidence gate V4

**State:** `SOURCE_PATCH_PREPARED / T1_NOT_ADMITTED / NOT_REVIEWED / NO_NATIVE_T3`.
This is an independent test/evidence implementation **proposal**, never a
substitute for a native tester run, verified source author lease, independent
method review, or Owner T3. All code uses Python standard library; no
MT5/MQL5/broker/network mutation is performed by these commands.

## Exact W5 frozen lineage

- W5 original observer `HEAD=4f0254340d0f7610223eb8ee507bb0ed141bd323`
- Original source TREE `c521daad1119a69fec18060ec5c46d7aa0365e8d`
- Original 173-key SET SHA `c145f3f472c540aba9c9fd82fdd22034eba73e44f5de4d90199b1234e88ab6fd`
- OFF EX5 `aa06cf4969139f13eee4c0c1c57cdc3d9f16d36b2de0e992d7f03d93b26c45ac`
- ON EX5 `14a792616c0117d18e2f45d4b7969c1b041f13662647f18cd5f9cf5c75de7f88`
- ThinkMarkets-Live / XAUUSD H1 / Build6230 / Model1 / deposit USD10000 / leverage 1:100
- MAIN `2023.01.01–2025.12.31`; BWD `2020.01.01–2022.12.31`
- Historical MAIN_OFF verdict is **`POSTCONDITION_FAIL`** (103/106 unchanged),
  independent of whether its report's 17 trades / PF0.21 / DD25.58% exists.
- Never change this lineage or rerun historical 2026H1 HOLDOUT.

## Why this V4 gate exists

The original runner stopped on three changed `hcc`/`hc`/`selected.dat` hashes.
A synthetically “complete” original V4 prototype could misleadingly accept
all-zero economics and all-zero SHA, malformed timestamp strings and a
self-asserted `SIGNED_PROVEN_NO_EFFECT` exception. This corrected offline
proposal rejects those classes and keeps historical SHA pinned to the
original receipt. It also classifies **where** drift occurs across S0–S3 and
models deterministic `EMPTY`/`PINNED_NONEMPTY` agent cache transitions.

The comparator **does not authenticate producers from a boolean field or
SHA text**. It checks structure and original pinned receipt consistency;
independent attestation of native agent, consumed bars, effective spreads,
commissions, account conditions, and actual Owner T3 remains external.

## Offline commands (no Native execution)

From the canonical repository root, **only after source admission**:

```powershell
& 'D:\EA_LAB\tools\python312\python.exe' -m unittest discover -s tests -p 'test_w5_b6230_*.py' -v
& 'D:\EA_LAB\tools\python312\python.exe' tools\w5_b6230_v4\gate.py historical tests\w5_b6230_historical_receipt_fixture.json
& 'D:\EA_LAB\tools\python312\python.exe' tools\w5_b6230_v4\gate.py prospective tests\w5_b6230_SYNTHETIC_DO_NOT_USE_FOR_NATIVE.json
```

The `historical` command always returns exit **2**, while displaying
`POSTCONDITION_FAIL` (even if the supplied summary matches the original
receipts). The `prospective` command returns **2** for `BLOCKED`, or **3** for
`OFFLINE_STRUCTURAL_READY_NOT_NATIVE_ACCEPTED`. **Exit 0 never means Native
PASS**. Only the `audit` mode returns 0 for a read-only, byte-identical file
hash audit, not the approval of a future research cell.

Read-only file audit using a manifest of objects `{path,bytes,sha256}`:

```powershell
& 'D:\EA_LAB\tools\python312\python.exe' tools\w5_b6230_v4\gate.py audit <manifest.json> --root <isolated-approved-data-root>
```

`audit_manifest` hashes actual files using streaming reads, rejects
path traversal/duplicate path/symlinks/missing/mismatched files. It does
not provide atomic filesystem snapshots or race-free process attribution.
Use an accepted exclusive lease, external capture provenance and full
106-file stage inventory for real data. `compare_stage_data` defaults to 106
entries at each S0–S3 checkpoint and reports deltas by `PREPROBE`, `TESTER`,
`POSTPROBE`. `compare_agent_cache` compares one preregistered baseline mode
and rejects unexpected `.hcs` additions/mutations; it cannot prove derived
bars or signed source→agent history by itself.

The JSON Schema under `schema/` is a **proposed Stage V4 envelope**. Shape
validation cannot prove signed data identity or source/build/cost fidelity.

## In-scope and prohibited

Suggested added files: this `tools/w5_b6230_v4/` folder and distinct
`tests/test_w5_b6230_*.py` plus synthetic/receipt-derived fixtures. No
modifications to `ea_template/`, original `run_b6230_cell_v2_refreeze.ps1`,
Registry, broker/symbol files, original WIP, source EX5/SET, trading risk or
installed runtime. No new MT5 Tester, MQL5 economics probe or HOLDOUT. An
actual native probe is T3, including PRE probe before Tester.

**Gate before any BaBoss source commit:** original task/actor, exact clean
source worktree, allowlist, budget, source-only T1 lease and a full approval
of the affected paths must be verified. The owner instruction “finish”
does not itself transfer a blocked original W5 Native writer lease to an
Independent RCA worker. Once admitted: run normal repository hooks/suites,
prepare one scoped local commit, secure independent exact-head review;
Main CT alone handles canonical integration/push according to policy.

## Files and proof boundaries

`gate.py` — pinned historical receipt + prospective offline structural logic,
`audit_manifest` byte comparator, strict JSON loader, fail-closed CLI.

`provenance.py` — S0/S1/S2/S3 broker file delta classification and agent
baseline transition checks (structural, not authenticated consumption).

`schema/W5_B6230_STAGE_V4.schema.json` — proposed format, no T3 authority.

`tests/` — old 42 historical/prospective negative/control cases retained,
expanded with adversarial, stage, agent, CLI, SHA and schema checks. Every
mock receipt is tagged synthetic; no example claim is a ThinkMarkets
account or real tester signature.
