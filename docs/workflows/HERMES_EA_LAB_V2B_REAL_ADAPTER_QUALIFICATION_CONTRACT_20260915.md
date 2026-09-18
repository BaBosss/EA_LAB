# Hermes EA_LAB V2-B Real Adapter Qualification Contract — 2026-09-15

Status: `CONTRACT_FROZEN / NO_MT5 / NO_RUNTIME_ACTIVATION / NO_STRATEGY_AUTHORITY`

Canonical parent: `af1784e880e5b9e66bd23d714bda854271fc64a5`.
Direct predecessor: accepted Hermes V2-A fixture foundation in `docs/workflows/HERMES_EA_LAB_V2_20260911.md`.
Readiness evidence: `D:\EA_LAB_CONTROL\evidence\hermes-v2b-readiness-20260915\READINESS.md`.

## Objective
Qualify one generic, deterministic adapter seam that can translate a frozen V2 batch cell into the already-owned EA_LAB tester execution contract **without starting MT5 during this qualification**.
This contract does not authorize a real tester campaign, profile activation, scheduler, persistent Hermes memory, provider/global config change, runtime attachment, optimization, HOLDOUT, Candidate, risk/default, deployment or trading.

## Existing facts that must be preserved
- V2-A CLI remains `FIXTURE_ONLY / FIXTURE_NO_MT5`; do not turn its current CLI mode into production by renaming a constant.
- `batch_executor.py` already owns manifest order, STARTED/terminal checkpointing, controller-retained resume SHA, replay refusal, ambiguous-STARTED refusal, final revalidation and one-state-directory serialization.
- `safe_tester_executor_mcp.py` is a real execution primitive but is Boss19-specific: exact expert, set, Model1, deposit/leverage, allowed windows and TFs are hard-bound.
- The safe executor already validates build receipt, report identity, leverage and schema-v2 truncation sidecars.
- New full-window research evidence must also bind deterministic calendar-year split output through canonical `scripts/report_year_split.py`.
- Every execution/performance number must retain exact MT5 installation/lane identity; cross-install comparison remains forbidden.
## Proposed adapter boundary
The future adapter may accept only a controller-built, hash-frozen cell object containing exact cell ID, repository HEAD, manifest/contract hashes, expert/build identity, set/config hash, logical symbol/tester symbol binding, timeframe, window role/from/to, tester model, deposit, leverage, report name and one named tester lane.

It may call only the existing bounded tester execution primitive through an injected callable/subprocess seam. The qualification implementation must not expose arbitrary executable, command-line, path, parameter override, optimization, Force, HOLDOUT or free-form shell fields.

Its terminal output must normalize to the V2 batch result shape:
`cell_id / status / reason / artifacts`, where terminal status is only `COMPLETE` or `MECHANICAL_FAIL`. Strategy verdicts and performance interpretation are forbidden.

For a COMPLETE fixture result, artifacts must bind at minimum:
1. parsed MT5 report bytes/hash and exact report identity;
2. build receipt / artifact identity;
3. leverage-check sidecar;
4. schema-v2 truncation sidecar with `CHECK_PASS`, exit 0 and `truncated=false` before full-window eligibility;
5. deterministic `report_year_split.py` output/hash;
6. exact named tester lane/install identity.

A missing, stale, mismatched, unparsable or cross-bound artifact produces `MECHANICAL_FAIL`; it must never be silently downgraded to COMPLETE or converted into strategy failure.
## Qualification method — strictly NO-MT5
Implementation qualification must use injected subprocess/report/sidecar fixtures only. No terminal executable may start and no accepted H1/H2/H3 cell may be replayed.

Required deterministic tests include:
- exact positive cell → one normalized COMPLETE result with all required artifact hashes;
- wrong HEAD/manifest/contract/set/build receipt/expert/symbol/TF/window/model/deposit/leverage/report identity → refusal before runner dispatch where applicable;
- HOLDOUT or optimization request → refusal;
- stale/missing report, wrong report hash/identity, wrong leverage, truncated or ambiguous truncation sidecar, missing/changed year split → MECHANICAL_FAIL;
- runner non-zero/timeout/exception → MECHANICAL_FAIL without replay;
- duplicate/case-colliding cell/report IDs → refusal;
- checkpoint STARTED without terminal state → existing V2 ambiguous-started blocker; no automatic retry;
- resume with retained checkpoint SHA skips only verified terminal cells; explicit replay remains denied;
- changed adapter/executor bytes, contract or frozen inputs invalidate resume/final accounting;
- lane mismatch or absent lane identity prevents evidence admission;
- one batch remains serial and one state directory retains an exclusive lock.

All fixtures must be synthetic or copied inert evidence. They must not claim PF/net/DD/trade outcomes as strategy evidence.

## Acceptance and review
Normal tooling tests and V2-A regression must remain green. The adapter qualification suite must prove zero MT5 processes were launched. `git diff --check`, applicable hooks and exact frozen-head review are required.

Implementation is already complete at exact local tested head `db1054d3e962bdfd6d37d27cef917a0df796b697`; do not rerun or redispatch it. Preserve V2-A 83/83 and V2-B 30/30 PASS, strict state/diff/hooks evidence, the blocked subprocess/shell-launch seams and unchanged pre/post terminal/MetaEditor process set. Preserve the initial same-family scrutiny finding, bounded repair 1/1 for incomplete year-split reconciliation, and targeted same-family re-scrutiny with no remaining actionable defect as historical technical evidence. The repair budget is not reset.

Because this adapter can later launch execution/tester work, canonical adapter integration requires one fresh, separate, read-only acceptance-grade GPT Scrutiny job/lane/contract against exact head `db1054d3e962bdfd6d37d27cef917a0df796b697` and isolated frozen evidence under `EA_MILESTONE_SCRUTINY_CHECKLIST.md`. The author job cannot self-approve. Provider/model family is not an independence criterion and provider qualification cannot block this review. Gemini/Qwen are optional/support only; do not dispatch them as mandatory reviewers or PASS-shop.
## Authority ceiling and next transition
This contract grants implementation authority only for the isolated **NO-MT5 qualification adapter and its tests**. It does not grant real tester execution.

After the fresh acceptance-grade exact-head scrutiny returns `SCRUTINY_PASS`, a separate Control Tower acceptance may classify the adapter `QUALIFIED_NO_MT5`. Only then may another separately frozen tester contract bind a real campaign, exact lane, source/build/set/config identities and MAIN+BWD cells.

That later tester contract must still obey all current Model1/Model4, same-install, BWD non-search, HOLDOUT, concurrency, report/year-split and strategy-authority rules. V2-B qualification cannot itself select an EA, Home, parameters, optimization ranges or verdict.

Current direct consumer: the fresh acceptance-grade read-only GPT Scrutiny of exact head `db1054d3e962bdfd6d37d27cef917a0df796b697`. Do not rerun implementation. If scrutiny fails or blocks, preserve the exact local tested head and evidence before integration; unrelated Control Tower work continues.
