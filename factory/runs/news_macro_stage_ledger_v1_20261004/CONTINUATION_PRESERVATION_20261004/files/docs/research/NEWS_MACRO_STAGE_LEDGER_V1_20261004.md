# News/Macro offline stage ledger V1 — 2026-10-04

Owner: EA_LAB-NEWS-MACRO-20260921. Lane: ct-news-macro-stage-ledger-v1-20261004.
Exact base: 471a94d6d65fc86882ac7a4bbb882e280edbe98d.
Direct consumers: the existing NewsMacro owner and a future handoff validator.
Monitor wiring and Template integration are outside this contract.

## Contract and admission

The existing BaBoss owner-side RDC actuator created a clean isolated worktree and
the canonical bootstrap returned READY with normal .githooks. Registry Check returned
READY with no conflicts; Claim returned CLAIMED/RUNNING under the existing owner,
without superseding any lane. Mobile and lnwjud V2 were disjoint active writers.
The old News/Macro DONE lane is immutable. Exhausted MGTT predecessors remain BLOCKED;
MGTTV3 b06320999f98aeefb33329971eee03405524e5af is reused as historical runner
engineering qualification only, with no native rerun or performance inference.

The pre-source contract is factory/runs/news_macro_stage_ledger_v1_20261004/CONTRACT.json
(SHA256 6a9590804bc2a02b072c48d455d318823edff4d16a5dcf66bf9d908014a42b13).
The 12-case pre-outcome plan is CASES_FROZEN.json
(SHA256 d628b95f7c46e7e7e71707c1124f896d91ce3b9d16ebb3cb5df4511a761fbde0).
Neither frozen document is rewritten after outcomes.

One author, 60 minutes, one candidate; one independent exact-head review, 30 minutes,
only after green gates and DOT confirmation of a free review slot. At most one
post-candidate repair, 30 minutes, and one targeted recheck if used. Native/MT5,
current-market fetch, production mutations and worker push budgets are zero.
Initial author harness corrections before source freeze are recorded in the checkpoint.
Prior lane budgets are never reset. Denied actor/admission requires exact-error STOP.

## Input and interpretation

news_macro_stage_ledger.py reads only --input, an explicit frozen UTF-8 JSON manifest.
It performs no network access, producer execution, Git lookup, environment/runtime
discovery, consumer lookup or fallback. CLI stdout is sorted, compact ASCII JSON,
UTF-8 encoded, with one LF. Exit 0 means a structurally valid ledger, 1 a refused
manifest, and 2 unreadable/malformed JSON; none means a real run is GREEN.

Schema: ea_lab_news_macro_stage_manifest/1, authority OFFLINE_ONLY, label FIXTURE_ONLY
or ACTUAL_UNQUALIFIED. Top-level fields are exactly schema_version, authority, label,
run_id, source, as_of_utc, clocks, stages, evidence, last_good, known_failures.
source contains source_id and artifact_sha256. Recorded UTC times use
YYYY-MM-DDTHH:MM:SSZ and cannot be later than the explicit as_of_utc.

The eight ordered stages are FETCHED, VALIDATED, CLASSIFIED, PUBLISHED_LOCAL,
TRANSFER_REQUESTED, TRANSFERRED, CONSUMER_OBSERVED and EFFECTIVE.
TRANSFERRED denotes receipt-backed transfer, not an exit-code inference.
Every stage declaration binds stage, run_id, source_id, artifact_sha256, at_utc,
status, reason and evidence_id. Status is PASS, FAIL or UNKNOWN. Inline evidence
has evidence_id, sha256 and payload. Its hash covers the same canonical serialization
as stdout. A payload repeats the exact stage binding and must use the stage-specific
kind and basis EXPLICIT_STAGE_ATTESTATION. These are declarations, not authenticated
remote witnesses; structural PASS does not certify the truth of the declaration.

Transfer requests bind receiver_id and destination; receipts additionally bind
request_evidence_id and received_sha256. Observations bind consumer_id and
observed_sha256. Effect receipts bind consumer_id, observation_evidence_id and
effective_sha256. Binding mismatches, hash mismatches, duplicate/orphan receipts,
malformed types, unknown fields, future recorded times and reversed stage chronology
refuse the manifest. Missing stages/receipts remain UNKNOWN. A declared failure
remains FAIL even when other stages are absent; its declared reason is retained.
A positive stage needs explicit matching evidence and all predecessor stages PASS.
Last-good metadata is separately reported and never substitutes for the current run.

clocks retains observation_time_utc, release_time_utc, available_at_utc and
fetch_time_utc as separate nullable fields. Economic observation, release, information
availability and transport fetch are not interchangeable. No age threshold or new
clock conversion is defined. A FETCHED attestation must match the explicit fetch clock.

File existence, mtime, rclone exit 0 and absent failure tokens cannot establish PASS.
The ledger always emits actual_run_green=UNKNOWN and runtime_effectiveness_certified=false.
A FIXTURE_ONLY EFFECTIVE/PASS is a synthetic declaration chain, never a VPS or EA verdict.
ACTUAL_UNQUALIFIED is also an evidence description, never runtime qualification.

## Read-only bindings and actual evidence

READONLY_BINDINGS.json pins hashes at the exact base for:

- scripts/daily_monitor.ps1
- scripts/mris/mris_run.ps1
- scripts/publish_guard_feeds_to_vps.ps1
- ea_projects/(Boss)_NewsGuard/vps_rclone/pull_guard_feeds.ps1

The abbreviated publisher locator in the dispatch resolves to the canonical scripts/
path. None of these producers is edited, imported or executed.

DailyMonitor records nonzero child exits and separately appends coverage failures;
its final nonempty failure list yields exit 1. MRIS aggregates caught stage exceptions,
and a partial brief path does not prove every stage. The publisher validates feeds
independently and preserves last-good destinations on failure; local staging is not
remote receipt or consumer-effect evidence. The VPS pull distinguishes rclone copy
from validation/local atomic publication; neither proves consumer observation/effect.

The immutable October 1 acceptance is copied as ACTUAL_ACCEPTANCE_20261001.json and
rehashes to b1568f6fba0bd0067df208c966728fa28a1f36da345104d1b444453e42d50c29.
It records last_result=1, DEGRADED_MONITORING and exactly:

- runtime-identity-unverified
- runtime-identity-coverage-gap
- deployment-unverified-69424711|
- deployment-verification-underived-x58

This locates the final nonzero evidence-gap result. It does not establish a new
News/Macro producer-stage failure or a current remote/runtime result.
ACTUAL_INPUT.json binds the acceptance snapshot as its source artifact, not a feed.
It deliberately supplies no feed-stage receipts and no economic/fetch clocks.
ACTUAL_LEDGER.json preserves all eight stages UNKNOWN and all four failure tokens.
Its structural PASS does not override the accepted degraded-monitoring evidence.

## Validation and handoff

Twelve frozen FIXTURE_ONLY cases cover positive chain, empty stages, missing
classification, wrong artifact hash, wrong run, malformed/future recorded times,
separate last-good, transfer without receipt, observation without effect, explicit
known failures, clock distinction and deterministic bytes/schema rejection.
The final test runner produces one input/outcome pair per case and RESULTS.json.
Adversarial subcases test weak evidence bases, receipt/consumer identity mismatch,
schema/types, duplicate JSON keys and numeric/nonfinite inputs.

Run from the isolated worktree using its existing portable Python:

    . scripts\use_python.ps1
    $python = Assert-PortablePython -Root $PWD
    & $python -B tools\knowledge_validation\test_news_macro_stage_ledger.py --write-evidence
    & $python -B tools\knowledge_validation\news_macro_stage_ledger.py --input <frozen-manifest.json>

The 12 cases pass; the existing focused knowledge-validation cage passes 11 tests.
Source parse, annotation/schema checks, exact allowlist, diff-check and hashes are
recorded before the normal-hook commit attempt. HASHES.json pins evidence/source bytes.
AUTHOR_CHECKPOINT.json supplies exact commit/gate/Registry readback and the one NEXT.

Independent review is NOT_RUN until DOT confirms the free review slot and admits
the separate exact-head read-only review. Author results grant no integration/push,
Template/MT5/native/performance, deployment, trading or risk-policy authority.
