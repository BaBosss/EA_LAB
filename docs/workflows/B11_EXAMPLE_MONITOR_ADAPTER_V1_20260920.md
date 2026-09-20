# B11 Example Monitor Adapter V1 — 2026-09-20

Status: OWNER_AUTHORIZED / PROSPECTIVE / REPO_ONLY_PRESENTATION / NO_RUNTIME_ACTIVATION

## Purpose

Complete the already-reviewed B11 example conveyor through the existing Mobile Report Hub / Monitor.

The B11 corrected-parser rerun is already canonical and reviewed:
- package head: `9fb9779d26b607b5a5271fbf543e23130ae88792`;
- state convergence: `9a1e4eab556318fd82aa4935a4573c9d8016665a`;
- package review: `SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION`;
- package review SHA256: `b523ed6023b1213dea5b46a879e47103fa07b31ff121b66d47c98c14f9fafe67`;
- accepted report parser parent: `629d9bfaf9fa5e25c5721539ba149420c36233ca`.

No MT5/tester rerun is part of this contract.

## Current gap

The canonical Monitor index discovers generic native report packages only through
`factory/runs/**/report_package_manifest.json`. The accepted B11 example package instead
uses `factory/runs/b11_default_example_rerun_20260920/package_manifest.json` plus
`evidence_summary.json`, so the canonical B11 run is absent from Monitor research records.

The fixture index is test data only and contains no B11 record.

## Objective

Add a fail-closed read-only presentation adapter that consumes the existing canonical B11 package
without modifying its evidence bytes or creating a second source of truth.

The adapter must:
1. read all inputs through exact Git object bytes at the requested canonical SHA;
2. validate the B11 package manifest schema, declared file count, safe unique paths, byte sizes and SHA256 for all 29 artifacts;
3. bind `evidence_summary.json` to its manifest entry and validate exact B11 example authority facts;
4. expose one Monitor research record with explicit `EXAMPLE_ONLY / NO_FAMILY_VERDICT / NO_HOME_AUTHORITY` semantics;
5. expose MAIN/BWD PF, EqDD, trades and cycles/year/exposure findings from existing package evidence only;
6. expose the existing human report through the Monitor's sanitized artifact-copy path;
7. expose MAIN/BWD source-bound native PNGs using content-addressed Monitor asset paths and package/report/asset hashes;
8. fail closed on manifest tamper, path traversal, missing/duplicate artifact, identity mismatch, authority drift or graph-hash mismatch;
9. keep B11 weak/negative performance truthful and never infer promotion;
10. require no changes to EA source, settings, strategy semantics, report package, MT5 runtime or deployment.

## Allowed repo paths

- `docs/workflows/B11_EXAMPLE_MONITOR_ADAPTER_V1_20260920.md`
- `tools/mobile_report_hub/build_index.py`
- `tools/mobile_report_hub/tests/test_b11_example_monitor.py`
- `tools/mobile_report_hub/README.md`

No `mobile_report_hub/app.js` change is expected unless deterministic tests prove the existing generic detail renderer cannot display the record safely. Any such need requires a separate scope decision rather than silent expansion.

## B11 authority that must remain visible

- Family: B11.
- Variant: `DEFAULT_EXAMPLE_RERUN_CORRECTED_PARSER`.
- Carrier: XAUUSD/H1 **example only**, not Home.
- Model: Model1 / 1 Minute OHLC.
- Optimization=0.
- HOLDOUT=UNSPENT.
- Candidate=false.
- quality grade=UNRATIFIED.
- Home ratified=false.
- Runtime/trading authority=false.
- MAIN PF=1.03, net=+696.95, trades=2822, EqDD=18.63%.
- BWD PF=0.89, net=-1878.63, trades=2657, EqDD=21.67%.
- Weak MAIN and negative BWD are retained, not retuned or reclassified.

## Acceptance

Required before source integration:
- focused adapter tests including adversarial package corruption;
- existing `tools/mobile_report_hub/tests/test_build_index.py`;
- existing `tools/mobile_report_hub/tests/test_native_graphs.py`;
- existing Monitor data/UI deterministic suites as applicable;
- a fresh local static preview built from the exact candidate head proving the B11 record, report link and both native graph assets;
- no source/reference path leakage into the public DTO;
- `git diff --check`, strict state/digest where impacted;
- one separate exact-head read-only GPT Scrutiny.

The source can be integrated only on `SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION`.

## Authority ceiling

`READ_ONLY_PRESENTATION_ONLY`.

No hosting activation, Scheduled Task change, production Monitor publishing, MT5 action, strategy/risk/default change,
Home selection, optimization, Model4, HOLDOUT, Candidate/Grade/KINT, DEMO/LIVE or trading authority.
