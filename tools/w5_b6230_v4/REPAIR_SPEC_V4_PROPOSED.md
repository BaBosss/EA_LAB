# W5 Build6230 — Prospective Evidence Gate V4 Repair Specification (T0 engineering deliverable)

**Status:** `REPAIR_SPEC_PREPARED_NOT_SOURCE_INTEGRATED / NOT_INDEPENDENTLY_ACCEPTED / NO_NATIVE_T3`
**Target lane:** `w5-b17-h0b-native-b6230-20261011` — historical `BLOCKED`, original tester `POSTCONDITION_FAIL` **immutable**.
**Scope:** test/evidence gate, broker/agent data provenance only; no change to B17 EA mechanics, monetary risk, source/EX5/SET, original Registry, original receipts, installed terminal or symbol files.
**Binding source:** current canonical Git at `origin/master=b98b5966aac7a8e0068a122bf744888c6d91cfa8`; frozen original W5 observer commit `4f0254340d0f7610223eb8ee507bb0ed141bd323` / TREE `c521daad1119a69fec18060ec5c46d7aa0365e8d`. Those are separate lineages. Verify fresh before any native admission.

## 1. The actual defect and repair target

The old runner (`D:\EA_LAB_CONTROL\mt5_isolated\w5-b17-h0b-b6230-20261011\run_b6230_cell_v2_refreeze.ps1`, SHA256 `8667e8eca33b893c1f59adbbad8341e233a1327a3bf57fc87ca1f935717299c9`) compares SHA256 of all 106 copied broker/history files before/after each cell. It correctly **stopped** after `MAIN_OFF` returned `data_unchanged=false`. However, it has **no pre-registered semantic/causal evidence gate** for terminal-maintained data, agent-consumed history and broker-effective costs. Do not modify the old runner or old decision. A future runner must keep the old all-106 audit as evidence and add stronger separately reviewed, fail-closed provenance checks rather than treat the 3 hashes as benign.

Old `MAIN_OFF` raw 17 trades / 34 deals / PF 0.21 / net -USD 2202.97 / EqDD 25.58% / Hard Kill 2023-03-10 10:01:40 remains **not accepted**, with 93.8% idle tail. Historical `MAIN_ON`, `BWD_OFF`, `BWD_ON` were never run.

## 2. Exact proposed files, not authorized edits

Implement only under a **new, qualified original author/source-only contract** with exact allowlist, original budget ledger and independent reviewer. Suggested **new test-only** files in isolated explicitly admitted W5 evidence tooling path (final names for CT to approve):

1. `w5_b6230_prospective_gate_v4.py` — pure stdlib comparison of immutable manifest, effective series, economics, stage identity and report receipts; only `UNKNOWN`, `BLOCKED`, `PRECHECK_COMPLETE_NOT_NATIVE_ACCEPTED` without T3/native acceptance.
2. `tests/test_w5_b6230_gate_v4.py` — run control + fail-closed negatives and positive paths with signed/real evidence clearly distinct from mock data.
3. `schema/W5_B6230_STAGE_EVIDENCE_V4.json` — versioned schema: source/tree/EX5/SET/build, live terminal+agent executable hash, broker, symbol, account, owner/lease, `PID+CreationTime`, exact as-of UTC, immutable file inventory/path/size/hash, effective economics and history provenance.
4. `contract/W5_B6230_V4_PREREG.json` — new pre-outcome, signed/approved owner/reviewer stage contract. Old V1/V2/V3 records remain unchanged.

**Not authorized here:** creating these files in Git, editing old `run_b6230_cell_v2_refreeze.ps1`, replacing original frozen manifest, changing `selected-146237.dat`, updating installed runtime, binding a T3 lease or starting MT5.

## 3. Field-complete effective broker/cost contract

PRE and POST must be extracted by a **separately T3-authorized** native target-terminal/agent method with verified issuer, PID+birth, executable SHA, UTC time, account/server/symbol, same build and effective data source. A string label `ECONOMICS_PASS` or journal's `3720 bytes of symbol info received` is insufficient.

Require all **16 `economics` keys** from historical V3: `contract_size`, `tick_size`, `tick_value`, `margin_initial`, `margin_maintenance`, `margin_rate`, `commission_value`, `commission_type`, `swap_long`, `swap_short`, `swap_mode`, `spread_mode`, `spread_fixed_or_default`, `lot_min`, `lot_step`, `lot_max`. Require **5 account keys**: `currency`, `leverage`, `trade_mode`, `stopout_level`, `stopout_mode`. Require explicit additional broker-provided cost/execution-mode details when material (tick_value_profit/loss, digits/point, fill/order modes, margin calculation, commission tiers, effective spread/tick timeline): `UNKNOWN` if not exposed rather than create illustrative numeric values. Numeric equality in 16+5 fields alone is **not sufficient** when unrecorded execution-cost conditions remain relevant.

For `selected-146237.dat`, save a full, byte-identical preimage at the new S1 checkpoint, SHA256, length and signed producer/economics evidence. After S2 compare whole bytes, byte ranges and effective values. **No blanket whitelist.** If preimage unavailable, producer unverified or economic field unknown => `BLOCKED`. Historical missing V2 preimage **cannot** be repaired retroactively by taking a new snapshot.

## 4. Four ordered stages: causal attribution

- **S0 BEFORE_PREPROBE:** no target-terminal operation in this future lineage yet; capture all 106 file hashes + full copies of 3 drift-prone files, agent baseline (`EMPTY` OR `PINNED_NONEMPTY`, exactly one mode predeclared), exact source-tree, broker/server/account/symbol, process inventory, owner lease. No automatic deletion of cache.
- **S1 AFTER_PREPROBE_BEFORE_TESTER:** once T3 approves native economics extraction, hash/compare S0→S1, record full 16+5 account/economic values, authenticated producer and expected agent identity. Unexpected mutation => stop before Tester; no rebaseline.
- **S2 AFTER_TESTER_BEFORE_POSTPROBE:** fresh outcome artifacts/report/graphs/deals/agent logs, `PID+CreationTime+ExecutableSHA`, 106-file audit, agent `.hcs` file creation/change map, effective history (M1 + H1/H4/D1 as actually consumed and 2022 warmup for MAIN), actual broker-effective values at agent, prices/cost timeline. Attribute S1→S2 only if each boundary is measured/ordered and verified. Any unclassified data change => fail closed.
- **S3 AFTER_POSTPROBE:** separately approved post-probe; compare S2→S3 to avoid falsely attributing probe side effects to Tester. Must match as-of ordering, owner/lease/terminal and source identity.

`S0 < S1 < S2 < S3` must be proven from signed UTC timestamps and process PIDs/creation; same-path checks without stage identity are not sufficient. If probe itself creates metadata drift, isolate its effects **prospectively**; never retroactively excuse S1→S2 drift.

## 5. Agent history and warmup policy

Define exactly one positive agent cache precondition: `EMPTY` or `PINNED_NONEMPTY`; old V3 §§8.2/12 contradictions must be resolved. Record full manifest before/after: path, size, SHA256, intended read/write/allowed-create paths, agent executable/hash/PID+birth, source and stage time. An `EMPTY` baseline may legitimately generate agent `.hcs`, but only if **allowed creation** and source→agent derivation rules were preregistered and verified. Any unexpected additional, missing or modified file => `BLOCKED`, including same bytes from wrong source/agent. MAIN explicitly consumes 2022-01-03 .. 2025-12-31 agent history according to journal; BWD 2020–2022 may need 2019 warmup, must prove before BWD.

Frozen B17 code: `_17_BasketATR_TF=16385` = **PERIOD_H1**, `_17_RiskATRContext=0`; direct risk/basket ATR handles on H1. `_50_RegimeMode=0` disables configured H4 regime handles. B19-specific D1 ATR is not an active B17 entry path. This **narrows direct code paths** but does **not** prove that `Daily.hc` is unconsumed by terminal/agent/preload. Require signed native consumed-series trace and deterministic derived-bar/indicator values for actual test; `Daily.hc` drift remains fail-closed without it.

## 6. Negative and positive cases and exact verdicts

**Negatives (must BLOCK):** altered 2023/2021 annual M1, 2019 BWD warmup unknown, changed effective agent `.hcs` even if terminal `.hcc` same, missing full V2/new selected.dat preimage, missing economics field / changed any 16+5 field, changed agent-effective tick/cost mode, missing signer/producer authentication, wrong or missing stage S1/S2, S2 timestamp earlier than S1, mixed terminal/agent process identity, generic string harmless-cache attestation without SHA/byte proof, no report graph/journal, wrong source/tree/EX5/SET/build/model/window, source H1 enum misread as D1, wrong previous cell, holdout touched, historical failure relabeled PASS, unknown cache mutation, after-outcome re-freeze.

**Positive structural cases (NOT Native PASS):** exact frozen identity, one chosen agent baseline, ordered S0/S1/S2/S3, independently evidenced all 16+5 economics and effective agent inputs, no unexplained mutable post-run changes, real report/deal/equity/halt trace, actual reviewed prospective contract and Owner T3. For true source-equivalent benign drift to be considered, require signed field-level proof and independent explicit acceptance; no extension-based waiver.

**Stop rule:** missing/equivocal provenance -> `BLOCKED`; fail evidence never becomes green. If all offline structural checks pass, output `PRECHECK_COMPLETE_NOT_NATIVE_ACCEPTED` and submit to qualified independent reviewer. An accepted native cell requires additional real T3-run evidence and reviewer/CT gates outside this sample comparator.

## 7. Required serial native cells and decision sequence

| Cell | Frozen B6230 baseline | Gate |
|---|---|---|
| `MAIN_OFF` | XAUUSD/H1; 1-minute OHLC; 2023.01.01..2025.12.31; OFF EX5 `aa06cf...`; SET `c145f3...` | New prospective run only after reviewed V4 + one exact Owner T3 + unique isolated tester lease; report and S0-S3 integrity first |
| `MAIN_ON` | Same MAIN; ON EX5 `14a792...`; identical SET/broker/data | Only after **new** `MAIN_OFF` accepted; trade/deal/price/cost/equity/Hard Kill parity |
| `BWD_OFF` | 2020.01.01..2022.12.31; OFF; same lineage | Only after MAIN pair, BWD 2019 warmup+data proven and T3 scope covers BWD |
| `BWD_ON` | Same BWD; ON | Only after BWD_OFF; same exact parity tests |

No Model4 Candidate claim (requires separate same-lineage real-ticks MAIN+BWD where admitted), no 2026H1 HOLDOUT, Factory/Submit, live trading or risk changes. Hard Kill settings remain exactly frozen; negative economics are not retuned.

## 8. Current implementation/readiness boundary

`gate.py`, `historical_receipt_fixture.json`, `SYNTHETIC_DO_NOT_USE_FOR_NATIVE.json`, and `test_gate.py` in this delivery are **independent T0 sandbox reference only**, tested using only Python stdlib. They have NOT been added to the repo, accepted as source, independently reviewed or proven against new native execution. Their synthetic control deliberately never claims Native PASS. Existing old 25/25 synthetic and 6 uncovered negative findings were reused as design inputs rather than mutated. Original W5 Registry `BLOCKED` and all original bytes remain unchanged.

**Exact Next Gate:** Main CT verifies original actor/allowlist/remaining budget/reviewer, admits a **versioned test-only evidence-gate implementation** under lawful T1 if available; if not, requires a new scoped source-only contract before integration. Independent different-family exact-version review and genuine positive/negative/real-receipt validation precede a separate **Owner T3** decision authorizing the native economics pre/post probe + new serial tester cells with rollback, exclusive tester lease, original failed evidence preserved.
