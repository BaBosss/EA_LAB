# Local Control Collector V1 / bounded R2
Owner authorization: 2026-09-21 current continuation message approving completion after Repair1 FAIL, with the attached LOCAL-FIRST / NORMAL-ECONOMY directive.
Attachment: Pasted markdown(20260921-033751).md, SHA256 85e7c0457cd15ccd52c7f9fd60528e6a9a7711d6c8331a94f622be6cfb8fb41a.
Authority ceiling: TOOLING_ONLY / READ_ONLY_OBSERVATION / NO_RUNTIME_MUTATION.
Same source lane: ct-local-control-collector-v1-20260921.
Repair1 remains spent and rejected at 43c9c705b4b52f7a0f9938f7354457f4d8eb49ff, SCRUTINY_FAIL / HIGH / BLOCK_INTEGRATION, LCCV1-001 and LCCV1-002.
This is a new owner-approved bounded correction, not a reset or relabeling of Repair1.
Scope: close only database-title fallback and all-malformed Registry status, with regression witnesses; preserve compact route selection and full durable observation.
LCCV1-001: no SELECT of title/prompt/preview content; unmapped or ambiguous rows use bounded THREAD:<id> labels. Exact explicit mappings keep their declared identity.
LCCV1-002: zero usable Registry rows with malformed records is UNAVAILABLE; mixed usable/malformed stays PARTIAL; valid Registry stays AVAILABLE. Counts remain explicit.
Gates: red regression witnesses, complete collector focused tests, AST/pycompile, diff check, actual BaBoss Registry + read-only usage observation, clean committed HEAD and one independent targeted exact-head GPT Scrutiny.
Review output must preserve findings/confidence and exact source/evidence hashes. No source correction after a failed R2 targeted review without further owner authority.
Direct consumer: accepted collector and its existing live-schema adapter are prerequisites for a separately frozen NORMAL/ECONOMY hookup; a collector by itself does not activate a mode.
Reporter V3 source and historical failures are not modified or re-reviewed. No model billing/quota/allowance/savings claims.
No strategy/MT5/risk/default/trading/deployment/hosting/scheduler/owner attestation authority. Normal repository integration remains separately gated.

## Pre-review scope clarification from real observational pilot
Owner completion directive also covers the snapshot/delta prerequisite. Before the R2 review or commit, the pilot reproduced LCCV1-003_LEDGER_ROUNDTRIP: old writer emitted pretty JSON but reader required JSONL, losing the prior baseline. This bounded correction adds compact JSONL, read-only legacy pretty-stream compatibility and fail-closed corruption tests; it does not reset Repair1 or add another post-review repair. Original failing pilot and red witnesses are preserved. No mode activation occurs before acceptance.
