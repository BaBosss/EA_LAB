# EA_LAB lnwjud + Review-Cost Operational Context — 2026-09-22

Status: `OWNER_APPROVED_CONTEXT_SYNC / READ_ONLY_TRANSPORT_BOUNDARY / NO NEW RUNTIME OR TRADING AUTHORITY`

## Current source of truth

Fresh reconciliation at intake verified BaBoss and `origin/master == ls-remote refs/heads/master == 0e3e2d90645a248137bb94cbd65f7c54bd6360aa`. Future sessions must fresh-fetch again; this SHA is an observation, not a permanent pin.

The one active Main Control Tower remains the coordinator. Existing lnwjud, Monitor, Registry and state ownership must be consumed rather than duplicated.

## lnwjud transport boundary

Existing lane `ct-lnwjud-direct-setup-20260918` is `DONE`. The accepted pilot is an immutable **READ-ONLY** snapshot, not current-master authority:
- base SHA `bf22e49df8fd73dcaf6da29ca4d38ad87382df10`;
- workspace_id `f49ff79200c9a4727f7b71c3db6d91b9`;
- manifest SHA256 `a447998c15ec1ae75f4e501cbc1c6c503563917c1d942371e7a2d0bd336bae79`;
- route: OpenAI Responses API -> Secure MCP Tunnel -> BaBoss -> loopback HTTP MCP gateway;
- MCP endpoint `http://127.0.0.1:18766/mcp`, `http-streamable`;
- exact exposed tools: `ea_lab_status`, `workspace_info`, `read_file`.

The final Responses E2E is PASS: exact three-tool surface, status identity, START_HERE read and forbidden ACCOUNTS policy denial all passed. Latest observed Responses E2E used GPT-5.6 Luna with 841 input / 217 output tokens and an estimated model-token cost of USD 0.0004286. These are workload/cost observations, not ChatGPT subscription quota or billing-credit semantics.
## RDC remains the actuator

lnwjud does **not** replace RDC for current Git truth or mutation. RDC remains required for:
- fresh current-master/local-worktree inspection where the immutable snapshot is stale;
- file writes/patches and Git mutation/push;
- Lane Registry transitions and Control Tower state writes;
- process/job launch and recovery;
- MT5/backtest/optimization/runtime operations;
- GUI/computer-use and emergency recovery.

The immutable lnwjud route has no write, process/shell, job, Git, Registry, MT5, trading, runtime, risk/default or GUI authority.

## Review routing that no longer requires Codex by default

Canonical independence is procedural, not provider-family based. A current ChatGPT session may perform acceptance-grade review without a Codex reviewer thread **only when it did not author the submitted artifact** and the review is a separate exact-head read-only lane/contract over frozen evidence after deterministic gates.

Concrete accepted example: B11-00 result scrutiny. Reviewer lane `ct-b11-00-result-scrutiny-ro-20260921` independently reviewed exact diagnostic head `389789a7d0f16a2b98f2ed92b95c4608c69c1d81` and returned `SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION`. Accepted classification is only `MECHANICALLY_INELIGIBLE_HARD_KILL_TRUNCATION`; no PF/net/trade-count strategy verdict follows. Review receipt SHA256: `e5af6c0cfeb7eea3e681d7153650291cbf5dd962203eaf4e44d1be9e2c424992`.

After an orthogonal current-canonical re-anchor, B11 local result head `f7bf85c5e645fe7bf2cfbdde074519e7242a1b4d` preserves every acceptance-critical source/log/diagnostic blob. Review-reuse binding SHA256: `e76a022cd4f36cc30a81e717a35a95bdb5934debd37a3884dc43d343c8502df6`. No second general review or MT5 rerun is required for that unchanged evidence.
This does **not** permit self-review. Current Main CT authored or materially repaired:
- Review-Cost governance head `a0672f9a779394ca2c6b342d66425c1b5517bcee`;
- BMH-004 local head `1e120c8d98259d59f7a0bf663b50ab9d2afd3809`.
Those still require a separate independent reviewer before integration. BMH-004 deterministic gates are green but NORMAL/ECONOMY remains inactive.

## DPAPI one-click convenience path

The DPAPI convenience path has strong functional evidence but is **not acceptance-grade infrastructure yet**. Functional trial passed CurrentUser DPAPI roundtrip, owner+SYSTEM ACL, vault decrypt, no-prompt restart, single tunnel/gateway, runtime-secret cleanup, idempotent START and no-prompt Responses E2E.

Fresh current-byte scrutiny is `SCRUTINY_BLOCKED / HIGH / evidence_binding=MISMATCH`, review SHA256 `7de6119dbdd379a31fa84b9f09f6496d2b966e3af5a6bcca1779b7e98a3b55fc`, for two bounded issues:
- `DPAPI-BIND-001`: prep hashes no longer bind current helper source/scripts and the current C# source postdates the functional executable, so source->binary provenance is not exact.
- `DPAPI-BIND-002`: the Responses shortcut/Python client can decrypt the DPAPI OpenAI key without first proving the exact reviewed client hash.

Therefore the original manual immutable lnwjud read-only route remains accepted, while DPAPI one-click remains `FUNCTIONAL_TRIAL_ONLY_REVIEW_BLOCKED`. A separately bounded binding repair is required before treating it as a reviewer trust anchor.

## Review-cost telemetry

Use existing Collector/Usage Reporter/Monitor surfaces when their own accepted contracts support the fields; do not create another dashboard/control plane. Per review, prefer recording:
- lane/job;
- model and reasoning effort;
- review type: PRECHECK / ACCEPTANCE / TARGETED_RECHECK;
- exact reviewed HEAD/evidence identity;
- prior-review reuse decision;
- HIGH rationale, when HIGH is used;
- API input/output tokens and bounded cost estimate when an API path reports them;
- whether RDC calls were avoided for read-only inspection;
- whether a Codex reviewer thread/model dispatch was avoided.

Local lifetime/thread token counters remain workload observations only, never billing/quota/credit units.

## Authority ceiling

This context changes routing and observation only. It grants no new write/process/job/Registry/MT5/runtime/trading/risk/default/deployment/HOLDOUT/Candidate/LIVE authority and does not activate Budget NORMAL/ECONOMY.
