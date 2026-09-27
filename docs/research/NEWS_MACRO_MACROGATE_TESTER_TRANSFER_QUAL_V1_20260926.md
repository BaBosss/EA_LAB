# MacroGate tester-transfer Phase1 qualification

Control canonical: `152b2849d6bb8759b65aa91273248cd068343ddf`
Disposition: **READY_FOR_PROSPECTIVE_IMPLEMENTATION** (planning acceptance only).
Lane: `ct-news-macro-mg-tester-transfer-qual-v1-20260926`

Repair1 of the unaccepted `8552a2dd078316323c2a6e83632ff9fd8b0ae4c7` plan. No MQL/source implementation, compile, MT5 or performance run has been performed in this phase. Implementation remains separately owner-authorized.

## Recovery and historical boundary

The same lane was recovered from stale RUNNING metadata. Initial candidate source work was clean and unreviewed; one exact-head independent review found MGTT-P1-001 through 005. This bounded planning Repair1 preserves that review and the earlier commits. The old MacroGate execution/runtime lanes are not reopened. Old accepted blocker head is `73a46848937e637bb4e025b8e8985a7d714462dc`: BASE MAIN and BWD qualified only the parent host gate; valid guarded outcomes remain 0. Historical BWD denominator stays `null / UNAVAILABLE_NOT_CERTIFIED` after two failed entry attempts; neither 218 nor 220 is substituted. No Recovery3, invalid guarded-report reuse or HOLDOUT contact is allowed.

## Q1 - technically supported mechanism, not a runtime guarantee

Select constant-name `#property tester_file` dependency declarations plus a NEW tester-only raw-byte verifier. The eleven accepted feed names can be declared in one prospective Boss15 wrapper. Official MetaQuotes documentation states that the dependency must exist at compilation for recognition, but content is transferred later; its example rewrites content in OnTesterInit after compilation. **CSV bytes are not embedded or authenticated merely by EX5 identity.** The corrected mechanism is supported for prospective implementation, not yet qualified on this machine. FILE_COMMON is not selected because it is shared mutable storage and would change the frozen false setting. Manual Agent pre-staging is not qualified by the old receipts; automatic sandbox cleanup was not proven and is not asserted here.

## Q2 - source change required: YES

Prospective source paths are exactly:

- `ea_template/Boss_15_ST03.mq5`
- `ea_template/core/LabCore.mqh`
- `ea_template/core/MacroGate_Core.mqh`
- `ea_template/core/Execution.mqh`

Boss15 opts into `LAB_MG_TESTER_EVIDENCE_QUAL`. LabCore adds tester-only fail-closed initialization and passive lifecycle/transaction hooks; MacroGate_Core supplies the source-bound expected digest map and new same-buffer verifier/parser; Execution supplies passive event accounting and the verified virtual CTrade observation seam. Vendor Trade.mqh, Inputs.mqh and ConfigFingerprint.mqh are not modified. The current raw-file hash adapter is **NOT IMPLEMENTED / NOT QUALIFIED**.

## Q3 - config change required: YES; no default/risk change

Only the prospective per-cell `_MG_RegimeFile` value changes to its declared basename, so each cell set SHA and effective fingerprint must be refrozen. `_MG_InCommon=false` and all other strategy, guard-policy and risk/default values remain frozen. Qualification telemetry is controlled by a **compile flag and MQL_TESTER**, not by `_MG_SelfGate`; it therefore measures gate-OFF BASE and gate-ON arms. Non-qualification builds and non-tester behavior remain unchanged.

## Q4 - exact byte identity before interpretation

PRELAUNCH_HOST_HASH is required immediately before transfer, in addition to precompile dependency checks. IN_EA_RUNTIME_IDENTITY currently has no qualified raw-byte SHA adapter. The future adapter must use FILE_READ|FILE_BIN, read the exact size into uchar[] once, require full FileReadArray completion, and use the documented CryptEncode(CRYPT_HASH_SHA256, raw, empty_key, digest) with a 32-byte result. Compare to a source-bound expected hash before strategy initialization. Parse **the same immutable byte buffer** only after success: no reopen, no normalized-string hash, no sidecar-supplied expected digest. The exact expected filename/hash/size/row/endpoints tuples are in `FEED_RUNTIME_EXPECTATIONS.json`, derived from unchanged accepted files. Their metadata corroborates load; it is not a substitute for raw-byte equality.

## Q5 - successful runtime load proof

Required prospective marker fields: `build_receipt`, `effective_config_fingerprint`, `requested_filename`, `source_class=TESTER_SANDBOX_NONCOMMON`, `expected_sha256`, `observed_sha256`, `file_size_bytes`, `bytes_read`, `valid_row_count`, `skipped_row_count`, `first_accepted_timestamp`, `last_accepted_timestamp`, `load_status=PASS`. These fields do not exist as a qualified surface today. The observed SHA must equal the compiled golden digest, and the runtime filename/config must match the frozen cell. The captured terminal, selected tester process, build receipt and complete log must independently match the run manifest. Host receipts alone or filename/row/endpoints alone are insufficient.

## Q6 - missing, stale and wrong files fail closed

For the opted-in tester self-gate only, unknown filename, Common mode, missing/open/size/read/hash/parser failure must return INIT_FAILED before any strategy order path. A same-length interior timestamp mutation retains size, row count and endpoints but changes the digest; the host-only in-memory counterexample is bound in REPAIR1.json. A stale/different-content file also fails the golden hash/size checks. Existing freshness and valid-feed state/UNKNOWN/offset behavior must pass parity unchanged. No wall-clock guess replaces content identity. BASE gate OFF consumes no regime file but still records attempts. Deliberate negative probes have isolated, frozen fault manifests; they cannot authorize performance or bypass positive gates.

## Q7 - count the intended units, including failures

The **new prospective** ledger separates:

- `strategy_intent_total`: Calls entering Lab_OpenOrder before its existing quote/SL/heat early returns; not every signal or OnTick predicate. Tag upstream refusals separately. Other execution-call paths need not have a Lab_OpenOrder parent.
- `execution_entry_total`: Every call to Exec_Open or Exec_PlacePending, before existing short-circuit news/macro/spread/volume gates. This NEW prospective unit is NOT the historical request-line denominator.
- `submit_total`: Every invocation of an existing CTrade opening method after upstream checks, including local-library failures before native send.
- `native_request_total`: Every actual forwarded CTrade::OrderSend invocation while an opening-call context is active; do not count closes, modifications or cancellations.
- `accepted_request_total`: Native requests whose bool/retcode combination qualifies as accepted; not a trade/fill count.
- `rejected_request_total`: Known failed native request results, retaining raw transport bool/retcode/error. This is not a claim of broker rejection or absence of a later fill.
- `entry_fill_total`: Distinct observed DEAL_ADD entry/entry-inout deal IDs associated with opening order IDs; partial fills may create multiple events. Never a request denominator.
- `unresolved_request_total`: Native results whose classification cannot be certified. They remain separate and invalidate ratio certification.

`execution_entry_total` is not every raw strategy signal and is not the historical request-line denominator. Record Lab_OpenOrder upstream refusals separately. Telemetry is enabled by `defined(LAB_MG_TESTER_EVIDENCE_QUAL) && MQL_TESTER`, independent of `_MG_SelfGate`. It preserves the original short-circuit news-before-Macro checks, early returns, lot math, existing counters and trading return values. The installed CTrade protected virtual OrderSend seam is hash-bound in the contract; a future opt-in observer forwards once without editing vendor code or adding retries.

CTrade true alone does not prove execution. Preserve the boolean, retcode, IDs and result_volume. Full, partial, accepted-but-pending and pending placement are distinct; known failed transport/request results and unresolved contradictions remain separate. Pending placement is not a fill. Passive transaction events deduplicate/link actual entry deals; incomplete fill coverage remains unavailable. No closes/modifications/cancellations enter the new-entry request denominator.

Monotonic IDs and a gap-free event sequence must reconcile one start and terminal event per unit, and complete RUN_BEGIN/RUN_END plus external process completion. Missing/duplicate/gapped/malformed/mixed-session events, missing footer or unresolved results make certification unavailable, not zero. The machine contract contains the exact taxonomy and invariants.

Future `blocked_execution_entry_share_v1 = MACRO pre-submit blocks / execution_entry_total` within the SAME certified arm/window; zero or uncertified denominator yields null. All future BASE/REAL/five-PLACEBO comparisons require a newly frozen same-lineage instrumented source/EX5 and matching windows. No old-BASE/new-guard mixed-lineage result is allowed. This future protocol does not authorize a BASE rerun or guarded run now.

## Q8 - prospective refreeze and affected paths

Refreeze all four source blobs and their transitive include closure, the vendor Trade.mqh observation seam hash, diagnostic source/tooling, compiled expected-file map, exact terminal/compiler/tester binaries, EX5/build receipts, each cell set/config fingerprint and the new ledger contract before outcomes. Preserve all accepted feed bytes/hashes, parent B15 GBPUSD/H4 semantics, old evidence and HOLDOUT. Future tooling paths are:

- `scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1`
- `scripts/_test/macrogate_tester_transfer_probe.mq5`
- `scripts/_test/test_macrogate_tester_transfer_contract.py`

Future per-probe configurations, byte fixtures and receipts belong only under `factory/runs/news_macro_macrogate_tester_transfer_impl_v1_20260927/`. These are prospective path grants only, requiring implementation approval. This Phase1 changes only its document and allowed factory package.

## Bounded non-performance qualification contract

The positive probe uses existing `REAL_FULL_2020_2025_macrogate_native.csv`, SHA256 `6aba7e1e7bd01e82469db580ae666c9903803c4fb8d206f4cc44f8aab8afbb2a`; no tiny unbound market fixture is invented. Production Boss15 declares eleven dependencies, while each separate diagnostic probe variant declares exactly one. Missing-file variant uses the explicit probe-only alias in the machine contract; wrong/stale variants carry the exact deterministic negative-copy hashes. The positive/missing/wrong/stale cases must run only after implementation authorization on reserved D:\Meta 5, GBPUSD/H4, Model1, 2020.01.02..2020.01.03, with a no-order-path probe importing the actual loader/verifier. There is no PF/net/DD interpretation.

Compile/launch dependency staging is only into contract-owned terminal MQL5/Files sources. No manual Agent injection, Common writes or unowned file replacement. Existing conflicting residue causes refusal. Native tester transfer plus in-EA byte verification must supply evidence. Required future gates:

1. powershell -File scripts/tpl_regression.ps1 -> CLEAN (mandatory shared-core gate)
2. Clean compile of Boss15 and diagnostic probe with zero errors and zero warnings, exact compiler/tester/build receipts
3. Focused loader/hash/same-buffer/parser/UNKNOWN parity against all eleven accepted feeds
4. Missing/wrong/stale and equal-metadata byte mutation must fail before strategy execution
5. Hash known-vector and raw LF/CRLF/BOM/byte-count adapter tests; do not substitute normalized string hash
6. Native file-transfer qualification on reserved D:\Meta 5; no manual Agent injection
7. Passive telemetry mock and adversarial request/fill/sequence tests; all counters independent of _MG_SelfGate
8. Shared-core/non-tester/live/default behavior regression; observe existing request/return/error behavior unchanged
9. New instrumented same-lineage controls, per-cell sets/fingerprints and complete measurement protocol must be preregistered in a separate execution contract before any performance run
10. One independent exact-head implementation GPT Scrutiny after deterministic acceptance; one bounded repair only where authorized

## Evidence and limitations

SOURCE_BINDING.json pins current source and historical blocker files; FEED_RUNTIME_EXPECTATIONS.json pins all eleven golden CSV identities. MQL5_REFERENCE_BINDING.json now binds nine actual official captures by URL, capture time, SHA256 and external path, including tester directives, FileOpen, raw-array/hash APIs and CTrade/OrderSend transaction semantics. These are primary technical references, not tests of the current build.

Read-only inspection found terminal 6182 while installed tester/editor report 6230. Exact current hashes are recorded in the prospective contract; the future qualification must refreeze and test them rather than assume the historical build still applies. No runtime qualification claim is made. Raw accepted files, historical failures and the original review are preserved.

## Repair disposition and authority

**READY_FOR_PROSPECTIVE_IMPLEMENTATION** means the corrected plan is ready to be considered for separately authorized implementation, subject to its targeted exact-head planning recheck. It is not implementation acceptance or performance authority. Planning Repair1 is consumed; only one targeted recheck follows. If material findings remain open, stop. Old execution budgets are not reset.

MT5/performance: NOT RUN. Source/EX5/config changes in Phase1: NONE. REAL_GUARD/PLACEBO/BASE rerun/Model4/optimizer/deployment/LIVE: NOT AUTHORIZED. HOLDOUT: LOCKED_UNSPENT. ZAB and other completed lanes are untouched.

**NEXT:** obtain independent targeted recheck and eligible canonical integration of this Phase1; then return the frozen contract for owner authorization of implementation only.
