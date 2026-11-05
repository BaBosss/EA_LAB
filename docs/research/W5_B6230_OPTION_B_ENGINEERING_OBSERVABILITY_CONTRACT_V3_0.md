# EA_LAB ONE MAIN CT — W5 Build6230 Option B: Engineering Observability Contract V3.0

**Document Version:** `V3.0_CLOSED_ABI_PROPOSAL`\
**Date:** 2026-11-04 (Asia/Bangkok)\
**Status:** `T0_DESIGN_SPECIFICATION_COMPLETE / OWNER_OPTION_B_APPROVED / NOT_NATIVE / NOT_LIVE`\
**Lineage & Disposition:** Directly supersedes R1 (`66bcd873fd65b00c04a15ea6b07ae99923ac6ecff8101a79e755632d93c1b420`) and R2.2 (`5a72815d688cf815e44ba2748e6c7d1e04db140f06554b4231f24d189f3a9e32`). Resolves all Main CT technical scrutiny findings D1-01 through D1-05 and A01 through A12 from `MAIN_CT_W5_OPTION_B_D1_R2_2_PREFLIGHT_SCRUTINY_DISPOSITION_20261102_R1.md`. Incorporates Author-Side QA Findings Q01 through Q11 from `W5_OPTION_B_AGY_OFFLINE_SUITE_T0_PRE_D4_QA_FINDINGS_20261104_R1.md`.\
**Scope Boundary:** Pure engineering-only telemetry, serialization profile, event schema, and offline verification framework. Strictly preserves Track L (Legacy Original W5) immutable facts; no Native MT5 Strategy Tester execution, no broker credential/tariff substitution, no real-money risk change.

---

## 1. Executive Separation: Track L (Legacy) vs Track E (Engineering-Only)

1. **Track L (Legacy W5 Build6230):**
   * Pinned to original frozen binary `aa06cf4969139f13eee4c0c1c57cdc3d9f16d36b2de0e992d7f03d93b26c45ac`, source HEAD `4f0254340d0f7610223eb8ee507bb0ed141bd323`, and SET173 `c145f3f472c540aba9c9fd82fdd22034eba73e44f5de4d90199b1234e88ab6fd`.
   * Historical native outcome: `POSTCONDITION_FAIL 3/106` (`history/XAUUSD/2026.hcc`, `history/XAUUSD/cache/Daily.hc`, `symbols/selected-146237.dat`).
   * Independent Method Review R4 verdict: `BLOCKED_METHOD` (M02/M03/M04 CRITICAL, M05 MAJOR).
   * **Invariant:** This historical failure is immutable. No telemetry or instrumentation can reclassify this outcome as benign or awarded a retro-active PASS.

2. **Track E (Engineering-Only Observability Lineage):**
   * A distinct, forward-looking engineering instrumented lineage.
   * Acknowledges that any source modification or sensor insertion creates a **distinct EX5 SHA256**, distinct build receipt, and distinct compiler output.
   * Proves the mechanical observable fidelity of the *telemetry collection mechanism itself* under controlled, offline-verifiable contracts.
   * Never claims to represent the uninstrumented internal state of the legacy frozen OFF EX5.

---

## 2. Immutable Provenance Manifest (Q10: Exact Full 64-hex SHA References)

| Artifact / Evidence | SHA256 Checksum (Full 64-Hex) | Authoritative Status |
|---|---|---|
| Original Frozen OFF EX5 | `aa06cf4969139f13eee4c0c1c57cdc3d9f16d36b2de0e992d7f03d93b26c45ac` | Immutable legacy binary; never modified |
| Original `Entry_Wave5.mqh` | `fcfc1aaded75f4719a87877a78e1c0de73c80d8904ee13d5a75b5ed05ae96b44` | Historical source reference |
| Original SET173 | `c145f3f472c540aba9c9fd82fdd22034eba73e44f5de4d90199b1234e88ab6fd` | Historical set parameters |
| Independent Method R4 Receipt | `b6b2095e0b6a5bb14f49d97c13943661924e16b295901c7dd360b0fcfaa4cae2` | `BLOCKED_METHOD` |
| Option B R1 Method Design | `66bcd873fd65b00c04a15ea6b07ae99923ac6ecff8101a79e755632d93c1b420` | Owner scope accepted; superseded by V3.0 |
| D1 Scrutiny Disposition R1 | `823a81060d84718777712b9250b6fc75acb03c02bf729a22ca1c6109af04de85` | Mandates V3.0 closed ABI & Draft-07 schema |
| D2 Proposal Evaluation R1 | `52b4d83e17927ed98249b21e7be91b498629c08af6f4b515531dc640b4cd40ba` | Directs pure offline Scope A implementation |

---

## 3. Technical Closures: Scrutiny Findings D1-01 to D1-05, A01 to A12, & QA Q01 to Q11

### 3.1 D1-01 / A01: Hierarchical Causal ID Namespace & Grammar
* **Problem:** Simple `run/kind/counter` identifiers suffered from cross-stream collision when multiple threads, async indicators, or multiple symbol streams emitted events concurrently.
* **V3.0 Closure:** Enforces a strictly typed, globally unique hierarchical lexical grammar:
  $$\text{event\_id} = \langle \text{run\_id} \rangle \text{:} \langle \text{stream\_id} \rangle \text{:} \langle \text{emitter\_gen} \rangle \text{:} \langle \text{event\_kind} \rangle \text{:} \langle \text{local\_counter} \rangle$$
  * `run_id`: `^[A-Za-z0-9_-]{1,32}$` (run-specific session UUID or deterministic test run id).
  * `stream_id`: `^[A-Za-z0-9_-]{1,16}$` (e.g. `STREAM_MAIN`, `IND_ATR_M1`).
  * `emitter_gen`: Non-negative integer (incremented upon indicator re-init, handle recreation, or reconnect).
  * `event_kind`: Closed uppercase enum (`HND_CREATE`, `HND_RELEASE`, `READ_REQ`, `READ_RET`, `READ_FAIL`, `VAL_USED`, `DECISION`, `GAP_DET`, `RUN_CLOSE`).
  * `local_counter`: Strict monotonically increasing 64-bit integer, formatted as decimal integer `1, 2, 3...`.
* **Collision Protection (F58):** Any duplicate `event_id`, or out-of-order counter within the same stream generation, immediately rejects with `ERR_EVENT_ID_COLLISION` or `ERR_SEQUENCE_ORDER_VIOLATION`. Multi-input DAG joins require explicit parent references (`parent_event_id`, `parent_event_ids`).

### 3.2 D1-02 / A02 / Q03 / Q04: Domain-Separated Signing with Common Replay Namespace & Atomic Commit
* **Problem:** In-memory set permitted state leakage across failures, and nonce was staged before digest mismatch verification.
* **V3.0 Closure:**
  * **Signing Domain Separation:** Header prepends strict domain prefix before digest:
    * `W5_STAGE_SIGNING_DOMAIN_V3:`
    * `W5_ACTION_SIGNING_DOMAIN_V3:`
    * `W5_EVENT_SIGNING_DOMAIN_V3:` — RESERVED: V3 event-chain digests are plain JCS-SHA256, not signed events.
  * **Common Replay Namespace:** A single global atomic replay ledger tracks tuples of:
    $$\text{ReplayKey} = (\text{protocol\_version}, \text{environment}, \text{issuer\_id}, \text{key\_fingerprint}, \text{nonce})$$
  * **Atomic Staging & Rollback (Q04):** Stage envelopes are validated in two phases. Signature, issuer, digest, and process checks are preflighted. State and nonces are only committed if all checks pass.
  * **Fail-Closed Replay Ledger Persistence (RQA-05):** Corrupted JSON, unreadable ledger files, or invalid record shapes fail-closed with `ERR_REPLAY_LEDGER_CORRUPTED` to prevent replay nonces from passing.
  * **Strict Signed-Stage Mode (RQA-03):** When `require_signatures=True`, missing or whitespace signatures and unknown issuers are rejected with `ERR_INVALID_SIGNATURE` or `ERR_UNKNOWN_ISSUER`.
  * **Replay Rule (F59):** Synthetic STAGE and ACTION use distinct signing domain prefixes and each signature is verified independently; one common replay ledger then rejects reuse of the same issuer/key/nonce across the domains. This is not broker or OS custody evidence.

### 3.3 D1-03 / A03 / Q07: Strict Separation of Time Metadata vs Strategy Decision Use & Multi-Input DAG
* **Problem:** Calling `iTime` to annotate a sample was incorrectly treated as proof of strategy time use.
* **V3.0 Closure:**
  * `TIME_BIND_ONLY`: The read of `iTime` or bar timestamp is strictly recorded as **Metadata Association** (`edge_type: BAR_ASSOCIATION`). It certifies when the sample was recorded or what bar it relates to, but confers **zero** decision weight.
  * `TIME_CONSUME`: A distinct, explicit event type (`TIME_CONSUMPTION_DECISION`) required only when logic explicitly branches on time.
  * **Multi-Input DAG (Q07):** Supports complex decisions with multiple upstream parent inputs via `parent_event_ids: List[str]`, auditing value consistency and detecting orphan decisions.
  * **Rule (F60, F61):** An event stream claiming strategy execution based on time without a corresponding `TIME_CONSUMPTION_DECISION` event fails with `ERR_METADATA_TIME_NOT_DECISION`.

### 3.4 D1-04 / A04 / Q11: Truthful Multi-Tier Coverage Claims & Capability Bounding
* **Problem:** EA internal counter equality was equated to having witnessed all OS and MT5 API calls.
* **V3.0 Closure:** Enforces 3 distinct, non-fungible assurance levels:
  1. `TRACE_INTERNAL_CLOSED`: Proves that internal EA instrumented sites emitted balanced, causal event chains ($N_{req} = N_{ret} + N_{fail}$).
  2. `STATIC_SCOPE_INSTRUMENTED`: Proves that 100% of the statically declared call-sites in the MQL source AST are instrumented.
  3. `ACTUAL_API_CALLS_WITNESSED`: Requires an independent, external operating-system witness. In the absence of an external witness receipt, this field **must** be explicitly reported as `UNKNOWN` (F64).
* **Rule (F63, F64):** Any claim of "All API Calls Witnessed" without external witness evidence fails with `ERR_UNVERIFIED_COVERAGE_CLAIM`.

### 3.5 D1-05 / A05 / Q05 / RQA-02: Synthetic 106 Census Custody & Prohibition of Unverified Authoritative Claims
* **Problem:** 106-path manifest was synthetic, but claimed authoritative original custody.
* **V3.0 Closure:**
  * Census assurance level is strictly designated `SYNTHETIC_106_CENSUS_ONLY`.
  * The synthetic census list is defined as `SYNTHETIC_106_PATHS`.
  * Any claim of authoritative original custody on synthetic paths without an owner-admitted manifest is strictly forbidden and rejected with `ERR_UNVERIFIED_AUTHORITATIVE_CUSTODY_CLAIM` (RQA-02).
  * Mandatory enforcement of historical 3/106 drift paths (`history/XAUUSD/2026.hcc`, `history/XAUUSD/cache/Daily.hc`, `symbols/selected-146237.dat`).
  * Synthetic fixtures must declare `trust_domain: "SYNTHETIC_FIXTURE_TEST_ONLY"`.
  * Real native validation (future) must declare `trust_domain: "NATIVE_AUTHENTIC_PROD_ONLY"`.
  * **Rule (F06, F14, F68, RQA-02):** Missing paths, path substitutions, retroactive drift waivers, authoritative custody misrepresentations, or domain spoofing immediately fail with `ERR_PATH_CENSUS_MISMATCH`, `ERR_LEGACY_WAIVER_PROHIBITED`, `ERR_UNVERIFIED_AUTHORITATIVE_CUSTODY_CLAIM`, or `ERR_NATIVE_IDENTITY_SPOOF`.

### 3.6 A06–A12 / Q01–Q02 / RQA-04: Serialization, Lifecycles, and RFC 8785 Compliance
* **A06 / Q01 / RQA-04 (Strict RFC 8785 JCS & ECMA-262 7.1.12.1):** Preserves Unicode strings without NFC normalization; formats numbers per ECMA-262 Section 7.1.12.1 shortest round-trip representation (preserving full 17-digit IEEE 754 binary64 precision without truncation), serializes `-0.0` and `-0` as `"0"`, forbids non-finites (`NaN`, `Infinity`); sorts object keys by UTF-16 code units (surrogate pair ordering).
* **A07 (Handle Lifecycle):** MQL handles are tracked with `HANDLE_CREATE` and `HANDLE_RELEASE`. If a handle is recycled by the OS or reused after release without a new create event, it fails with `ERR_RECYCLED_HANDLE_COLLISION` (F62).
* **A08 / Q06 (CopyBuffer & MQL5 Telemetry):** `requested_count` is bounded to exact request size. `W5_TimeToISO8601UTC` outputs standard `YYYY-MM-DDTHH:MM:SSZ`. If `CopyBuffer` returns failure, `GetLastError()` must be preserved in `error_code` (F67).
* **A09 / Q03 (Revocation Ledger):** Signing keys are validated against an atomic revocation ledger. Expired or revoked keys fail with `ERR_KEY_REVOKED` (F69).
* **A10 (Broker Costs):** `commission` and `swap` default to `UNKNOWN` in offline mode. Never coerced to zero ($0.00$) unless explicitly authenticated by S2 broker deals.

---

## 4. Closed Event Schema V3.0 Specification

### 4.1 Event Envelope Structure
Every event emitted in Track E adheres to the following canonical schema:

```json
{
  "schema_version": "W5_ENG_OBS_V3_0",
  "lineage_id": "ENGINEERING_ONLY_TRACK_E",
  "trust_domain": "SYNTHETIC_FIXTURE_TEST_ONLY",
  "event_id": "RUN01:STREAM_MAIN:0:READ_RET:1",
  "parent_event_id": "RUN01:STREAM_MAIN:0:READ_REQ:1",
  "parent_event_ids": null,
  "run_id": "RUN01",
  "stream_id": "STREAM_MAIN",
  "emitter_generation": 0,
  "event_type": "READ_RETURN",
  "local_counter": 1,
  "recorded_utc": "2026-11-04T00:00:00Z",
  "strategy_bar_time": "2026-11-04T02:00:00Z",
  "call_site": {
    "file": "Entry_Wave5.mqh",
    "function": "B17_ReadATR",
    "line": 1033
  },
  "sensor_payload": {
    "symbol": "XAUUSD",
    "timeframe": 16385,
    "indicator_kind": "ATR",
    "period": 14,
    "handle_id": "HND_001",
    "handle_generation": 1,
    "buffer_id": 0,
    "start_pos": 1,
    "requested_count": 1,
    "returned_count": 1,
    "raw_value": "12.45000000",
    "error_code": 0
  },
  "causality_link": {
    "consumed_in_decision": false,
    "decision_id": null,
    "edge_type": "BAR_ASSOCIATION"
  },
  "assurance_class": {
    "trace_internal_closed": true,
    "static_scope_instrumented": true,
    "actual_api_calls_witnessed": "UNKNOWN"
  },
  "prev_event_digest": "0000000000000000000000000000000000000000000000000000000000000000"
}
```

---

## 5. Falsifiable Test Matrix: F01 through F69 (Q08: 100% Individually Specified)

All 69 test fixtures are individually specified in `tools/w5_engineering_observability/fixture_spec_v3.json` and executed dynamically in `tests/test_w5_obs_schema_canonical_v3.py`:

| Case Range | Description / Checks | Expected Result / Error Codes | Status |
|---|---|---|---|
| **F01** | Perfectly formatted synthetic event chain baseline | `FIXTURE_VALID_ONLY` (64-hex digest) | `PASS` |
| **F02–F05** | Cryptographic envelope, forged HMAC signature, replay nonce collision, PID mismatch, stage order | `ERR_INVALID_SIGNATURE`, `ERR_REPLAY_NONCE_COLLISION`, `ERR_PROCESS_IDENTITY_MISMATCH`, `ERR_STAGE_CHAIN_ORDER` | `PASS` |
| **F06–F08** | Legacy 106-path census inventory, symbol scope mismatch, temporal coverage gap | `ERR_PATH_CENSUS_MISMATCH`, `ERR_SYMBOL_SCOPE_MISMATCH`, `ERR_COVERAGE_GAP_DETECTED` | `PASS` |
| **F09–F11** | Unpaired read return, coerced zero commission, incomplete raw bundle assets | `ERR_UNPAIRED_READ_RETURN`, `ERR_COMMISSION_ZERO_COERCION`, `ERR_RAW_BUNDLE_INCOMPLETE` | `PASS` |
| **F12–F14** | Legacy binary SHA mismatch, broken digest chain, legacy 3/106 waiver prohibition | `ERR_LEGACY_IDENTITY_MISMATCH`, `ERR_EVENT_CHAIN_BROKEN`, `ERR_LEGACY_WAIVER_PROHIBITED` | `PASS` |
| **F15–F57** | Exhaustive Draft-07 schema structural checks (missing required keys, bad enums, bad patterns, out-of-range bounds, unauthorized additionalProperties) | `ERR_SCHEMA_MISSING_REQUIRED_KEY`, `ERR_INVALID_*`, `ERR_SCHEMA_INVALID_PATTERN`, `ERR_SCHEMA_VALUE_OUT_OF_RANGE`, `ERR_SCHEMA_ADDITIONAL_PROPERTY` | `PASS` (43 distinct cases) |
| **F58–F59** | Event ID collision across threads, cross-domain nonce collision | `ERR_EVENT_ID_COLLISION`, `ERR_REPLAY_NONCE_COLLISION` | `PASS` |
| **F60–F61** | Metadata bar time claiming decision, missing genuine time decision edge | `ERR_METADATA_TIME_NOT_DECISION`, `ERR_MISSING_TIME_DECISION_EDGE` | `PASS` |
| **F62–F64** | Recycled handle collision, AST callsite omission, unverified external API witness claim | `ERR_RECYCLED_HANDLE_COLLISION`, `ERR_STATIC_CALLSITE_OMITTED`, `ERR_UNVERIFIED_COVERAGE_CLAIM` | `PASS` |
| **F65–F66** | Non-integer float local counter, UTF-16 non-BMP surrogate key sorting | `ERR_SCHEMA_TYPE_MISMATCH`, `ERR_JCS_KEY_SORT_ORDER` | `PASS` |
| **F67–F69** | CopyBuffer unpreserved LastError, native trust domain spoofing, revoked signing key | `ERR_UNPRESERVED_LAST_ERROR`, `ERR_NATIVE_IDENTITY_SPOOF`, `ERR_KEY_REVOKED` | `PASS` |

> **RQA-01 Resolution Note:** All 69 fixture cases (including F08, F12, F61, F63, F66) feature explicit, dedicated execution branches with fault injection and assertions in `tests/test_w5_obs_schema_canonical_v3.py`. Any unhandled or missing fixture is trapped by a terminal `else: self.fail(...)` block. Individual PASS receipts are dumped to `tests/w5_f01_f69_matrix_receipt.json`.

---

## 6. System Capability Matrix (Q11: Explicit SUPPORTED / UNSUPPORTED / NOT_RUN)

| Capability / Feature Area | Implementation Status | Test Coverage | Operational Scope Boundary & Security Guard |
|---|---|---|---|
| **RFC 8785 JSON Canonicalization (JCS)** | `SUPPORTED` | `TestRFC8785JCSConformance` (`test_ecmascript_float_serialization_binary64`, `test_ecmascript_number_serialization`, `test_utf16_surrogate_key_ordering`) | Fail-closed RFC 8785 compliance: raw Unicode preserved, ECMAScript float format with double-precision IEEE-754 round-trip, UTF-16 surrogate code unit key sorting. |
| **File-Backed Closed ABI Schema (Draft-07 keyword subset)** | SUPPORTED (offline) | test_runtime_schema_change_is_enforced_fail_closed, F15-F57 | Validates against schema_v3.json for the defined keyword subset; unsupported schema keywords fail closed. Additional ABI-specific checks remain enforced. This is not a generic all-keyword Draft-07 engine. |
| **Atomic Replay & Nonce Ledger** | `SUPPORTED` | `TestPersistentReplayLedger` (`test_persistence_and_reload`, `test_replay_ledger_fail_closed_on_corruption`, `test_stage_and_rollback`) & F03, F59 | Persistent file backing with `fsync`, two-phase staging + commit/rollback, fail-closed on corrupt JSON, cross-domain collision defense. |
| **HMAC-SHA256 Stage Signature & Revocation** | `SUPPORTED` (Synthetic) | `test_q03_q04_atomic_signed_stage`, `test_scope_c_rqa_03_signed_mode_enforcement`, `test_scope_c_rqa_03_native_unsigned_rejected` & F02, F69 | Domain-separated signing (`STAGE_DOMAIN`), trust anchor registry, fail-closed revocation check, strict signed-stage mode mandatory for native trust domain. |
| **Synthetic 106-Path Structural Census** | `SUPPORTED` (Synthetic Only) | `test_q05_exact_106_census`, `test_scope_c_106_census_clean`, `test_scope_c_rqa_02_synthetic_census_only_rejects_authoritative_claim` & F06, F14 | Exact 106-path structural synthetic census (`SYNTHETIC_106_CENSUS_ONLY`), mandatory retention of 3/106 drift paths, waiver prohibition, authoritative original custody claims strictly prohibited without owner manifest. |
| **Multi-Parent Causal DAG & Divergence Audit** | `SUPPORTED` (Verifier) | `test_scope_b_multi_input_dag`, `test_scope_b_orphan_decision_fails`, `test_scope_b_open_read_request_flagged` & F09 | Multi-parent DAG resolution (`parent_event_ids`), value consistency check, orphan decision rejection, unclosed read request detection. |
| **Time Metadata vs Strategy Decision Separation** | `SUPPORTED` | `test_scope_b_causal_chain_clean`, `test_scope_b_orphan_decision_consumed_false_flagged` & F60, F61 | `BAR_ASSOCIATION` metadata cannot serve as decision parent without explicit time consumption edge (`TIME_CONSUMPTION_DECISION`). |
| **Full F01–F69 Boundary Fixture Suite** | `SUPPORTED` | `test_full_69_matrix_execution` | 69/69 individual cases dynamically executed and passed with exact code match; dynamically verified against `tests/w5_f01_f69_matrix_receipt.json`. |
| **MQL5 Sensor Header Formatting & ISO 8601 UTC** | IMPLEMENTED_SOURCE / NOT_COMPILED | Source-only mock; no execution | Escapes JSON control/UTF-16, supports multi-parent IDs, renders binary64 with 17 significant digits; requires UTC timestamp. Script emits one synthetic event without chain claim. Native ABI and compiler parity not verified. |
| **MQL5 MetaEditor Compilation to EX5** | `NOT_RUN` | N/A (Compilation gate) | Parked pending Native admission; no compiler invocation in offline Scope A. |
| **OS / Hypervisor External API Witness Receipt** | `UNSUPPORTED` / `NOT_RUN` | Negative test F64 | Parameterized fail-closed check (`external_witness_present=False`); OS witness probe not implemented. |
| **Native MT5 Strategy Tester Execution (S0–S3)** | `UNSUPPORTED` / `NOT_RUN` | Forbidden under Scope A | Gated at Gate D5 / Scope E; zero native runs executed. |
| **Live Broker Tariffs / Real-Money Execution** | `UNSUPPORTED` / `NOT_RUN` | Zero live access | Prohibited; pure engineering observability design. |

---

## 7. Implementation Scope A (Offline Tooling) Allowlist

When admitted for Source implementation under Gate D2, Scope A is strictly confined to the following add-only, offline files:
1. `tools/w5_engineering_observability/schema_v3.json`
2. `tools/w5_engineering_observability/canonical_v3.py`
3. `tools/w5_engineering_observability/stage_verifier_v3.py`
4. `tools/w5_engineering_observability/verifier_v3.py`
5. `tools/w5_engineering_observability/W5_TelemetrySensor.mqh`
6. `tools/w5_engineering_observability/fixture_spec_v3.json`
7. `ea_template/tests/W5_ObservabilitySensor_Test.mq5`
8. `tests/test_w5_obs_schema_canonical_v3.py`
9. `tests/test_w5_obs_causal_stage_verifier_v3.py`
10. `docs/research/W5_B6230_OPTION_B_ENGINEERING_OBSERVABILITY_CONTRACT_V3_0.md`

**Prohibited in Scope A:** Any modification to `ea_template/core/*`, primary checkout dirty files, `.ex5`, `.set`, broker accounts, MT5 terminal runtime, or live risk parameters.


## 8. D4 failure and bounded offline repairs (2026-11-05)

The first independent D4 reviewer returned **FAIL** for exact HEAD
0a782d48629ceeb94e1e1d9d086b32932f860560, TREE
ac79e1f94a331af419b02174fda91e2cdfd8885a.
Review evidence:
D:\EA_LAB_CONTROL\evidence\w5_option_b_exacthead_0a782d48_20261105\CODEX_D4_VERDICT.md.

The author repairs address issuer-key binding, multi-instance nonce persistence
locking and fresh-disk reconciliation, stage rollback on persistence failure,
commission and swap finite checks, request/return scope and order,
time metadata versus causal dependencies, schema types, and event ID binding.

A synthetic boolean s2_broker_authenticated=true is **not independently broker
authenticated**. Historical commission and swap remain UNKNOWN absent separate
trusted broker evidence. No real-world tariffs or prices were established.

The MQL5 .mqh header and .mq5 probe are **source examples only, NOT COMPILED**.
The script emits only one synthetic JSON event; no chained digest can be
calculated without independent RFC 8785 JCS over actual event bytes. Its
trace_internal_closed and static_scope_instrumented flags remain false.
These examples are NOT evidence of sensor/compiler ABI parity, a Native
S0-S3 execution, CopyBuffer runtime witness, or closure of Original W5 3/106.

Every subsequent frozen author HEAD requires a different-family exact-head
D4 PASS before hub-owned ordinary fast-forward integration. None of this
authorizes T3, MetaEditor, MT5 or live trading.

## 9. Exact-head independent review follow-up and trusted verification time (2026-11-05)

The first independently reviewed HEAD 010e3ea1b888dcc668cc64a65661d83bfa04f576
received CONDITIONAL_PASS_FIX_THEN_SHIP, **not** an accepted D4 PASS. The
identified file-backed schema and duplicate F59 coverage gaps were addressed
by the existing author: the V3 Draft-07 keyword subset is now loaded and
enforced directly from schema_v3.json, unsupported keywords fail closed,
and F59 separately verifies synthetic ACTION and STAGE HMAC signatures
and checks a shared replay nonce namespace. EVENT_DOMAIN remains reserved.

A subsequent R12 read-only QA reproduced an expired signing key accepted by
the ACTION verifier when the action's untrusted recorded_utc backdated the
key-validity check. The same vulnerability also existed for STAGE
recorded_utc/strategy_bar_time. Both signers and verifiers now check the
key-validity interval against verifier-side UTC runtime time only; payload
timestamps never establish a trusted signing or verification time. The legacy
current_time_iso caller override is rejected without an admitted, independently
authenticated archival-custody mechanism. Invalid key validity bounds fail closed.
Regression tests cover expired and active ACTION/STAGE keys and backdated
timestamp/override behavior. The runtime OS clock is an offline engineering
input, **not** proof of independently attested OS/hypervisor time.

Native/MetaEditor/MT5/T3 were NOT RUN. Historical Original W5 parity remains
BLOCKED_METHOD with postcondition FAIL 3/106; broker commission and swap
remain UNKNOWN. These changes require a new frozen source HEAD, normal
hooks and an independent D4 PASS before normal fast-forward integration.
