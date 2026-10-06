# Workflow Provider Transition — 2026-09-06

## Status and scope

MS-WORKFLOW-03 M1 remains routing documentation plus inert Hermes target metadata only; active repository defaults/profiles are not switched. The historical proposed validator is still rejected evidence. A separate bounded M2 follow-up now implements a narrow fail-closed Hermes-emitted YAML provider check: 31 focused fixtures close the column-zero-comment duplicate-provider false accept, provider CLI preflight remains green, the per-path fast cage selects only this suite (0.3s measured of the 110s ceiling), and installed-profile validation passes on all four unchanged Anthropic profiles. This is tooling qualification only, governed by exact-head independent review before integration; it does not complete Gemini/Hermes GPT M2 qualification or activate any provider/runtime.

This document owns provider-transition routing and its qualification checklist. `AGENTS.md` owns roles and authority; `PROJECT_STATE.md` owns current status; `AGENT_TASKBOARD.md` points to the bounded contract; `START_HERE.md` routes startup. `CLAUDE.md` remains the canonical production-verdict rule document despite its filename; the historical direct-Claude cancellation does not disable current Antigravity Claude routing. Historical Claude reviews remain valid evidence.

## Current owner policy — 2026-10-06

ChatGPT Plus current chat is the one Main Control Tower. Gemini 3.1 Pro High is the default implementation author, with Claude Sonnet 5.5 High for secondary/repair. Qwen and GPT-OSS 120B are for support/batch/advisory. Codex is a scarce specialist reserve.

For core/high-risk acceptance, the canonical final path is Acceptance-Grade Independent Exact-Head Scrutiny. The current default final reviewer is Claude Opus 5.5 High via Antigravity. An acceptance-grade GPT reviewer remains an alternate when available, but GPT quota absence must not block when an authorized independent acceptance route exists. The author job cannot self-approve. The reviewer may not mutate source and must fail closed on ambiguous or conflicting provenance. One bounded repair remains available only where the underlying contract grants it, followed by one targeted exact-head recheck; no duplicate reviewers or PASS-shopping.

All historical qualification attempts, timeouts, cancellations, grades, and completed reviews below remain preserved historical facts. They may support later analysis but do not gate the current canonical review path.

### Owner review-cost reduction addendum - 2026-10-06

The Acceptance-Grade Independent Exact-Head Scrutiny governance applies, with an efficiency overlay for **new** dispatches. Deterministic/local evidence is completed first; packages already failing deterministically are not sent for acceptance review. Normal acceptance uses one exact-head Scrutiny. For the current default route, Claude Opus 5.5 High is required; alternate acceptance-grade routes must use their approved acceptance reasoning level and remain procedurally independent. If one authorized bounded repair is used, the only follow-up review is one targeted exact-head recheck focused on the original findings, changed hunks/files, affected requirements and impacted deterministic evidence.

An already accepted independent review receipt is reused when exact reviewed commit/tree or frozen bytes, acceptance-relevant evidence hashes, review contract and impacted deterministic results are unchanged. Chat rotation, state rereads, lane-label changes, wrapper ambiguity and unchanged evidence copying/repackaging do not themselves trigger a new review. Any acceptance-relevant change requires exact-delta analysis first.

This addendum grants no reopening of rejected/exhausted work, no repair-budget reset, no self-approval, no reduced acceptance criteria, and no trading/runtime/risk/default authority.

## Evidence classification

### OWNER_REPORTED

- Current 2026-10-06 operating tier: ChatGPT Plus; Codex quota is treated as scarce, so Codex is not a default critical-path dependency. Do not encode transient quota percentages/reset dates.
- Current 2026-10-06 Google AI Pro / Antigravity access is owner-authorized for bounded EA_LAB workers and Claude Opus 5.5 High acceptance review under the current policy.
- The previously cancelled direct Claude subscription/service remains historical context; current Antigravity Claude access is a separate route.
- Historical 2026-09-06 owner facts are preserved by this note: ChatGPT Pro was active at that time, the direct Claude service was cancelled, and Gemini had not yet qualified under the then-current policy.

Owner reports are project inputs, not billing-provider verification.

### LOCALLY_VERIFIED

The transition intake records these local observations from Control Tower without exposing credentials:

- Current 2026-10-06 Antigravity CLI agy 1.3.0 is locally observed with consumer OAuth/keyring and model labels including gemini-3.1-pro-high, gemini-3.8-flash-high, claude-sonnet-5-5-high, claude-opus-5-5-high, and gpt-oss-120b-medium. Availability is dynamic and must be resolved fresh.
- The legacy standalone Gemini CLI API-key route remains separate from the preferred Antigravity consumer-OAuth route; do not silently substitute one for the other.

**Historical 2026-09-06 locally verified intake (preserved, not current routing):**

- Codex CLI `0.144.2`; login status: `Logged in using ChatGPT`. The current Codex execution uses ChatGPT authentication.
- Gemini CLI `0.58.0` is installed. `security.auth.selectedType=gemini-api-key`; the key is not recorded.
- Gemini/Google/OpenAI API environment variables were absent in the Desktop Commander process. This does not prove that stored keys are absent.
- No new Gemini model request was made because billing/free-tier status was not verified.
- An older global Codex selection, `gpt-6-astra`, previously failed a newer-client requirement; `gpt-5.6-sol` ran. Do not silently change a global model.
- Installed Hermes `ea-researcher`, `ea-coder`, `ea-tester`, and `ea-reviewer` configs still specify `anthropic/claude-sonnet-4.6` and provider `anthropic`. They are untouched by M1.
- The first Codex author attempt exited without repository changes because its sandbox was enforced read-only. Classify write-launcher qualification as `C_ENVIRONMENT_DEPENDENCY`, not product failure. The current delivery is an explicit patch-only adapter, not expanded permission.

### HISTORICAL TARGET / PENDING (standalone/provider-M2 record; does not gate current Antigravity routing)

- Hermes inert target metadata: `provider_transition.target_provider=openai-codex`, `provider_transition.target_model=gpt-5.6-sol`. Active default_provider/default_model remain Anthropic/Sonnet; a metadata target is not a runnable migration.
- Target state: `REPO_CONFIG_ONLY_NOT_APPLIED / QUALIFICATION_PENDING`; there is no new runtime `LIVE_PASS`.
- Actual model names must be resolved from the authenticated local surface and a bounded smoke, not inferred from marketing names.
- Gemini live authentication, quota/billing behavior, tool boundary, provenance, and review competence remain unverified pending M2.

## Current routing

1. One active ChatGPT Control Tower manages one project truth, task contracts, interpretation, and integration decisions inside existing authority. Architecture: Boss -> ChatGPT Main CT -> RDC/lnwjud -> BaBoss -> bounded AI/deterministic workers -> Main CT intake/integration.
2. Gemini 3.1 Pro High is the default local implementation/test author. A bounded session is a worker, not another Control Tower, integration owner, or its own reviewer; Main CT alone integrates/pushes shared master.
3. Use deterministic local tooling first. Do not keep an LLM waiting for every tester cell. Reuse accepted mechanical evidence and deterministic executors when the direct consumer does not require a new observation.
4. GPT-backed Hermes remains a mechanical EA R&D evidence factory. Provider changes grant no strategy, risk, HOLDOUT, deployment, trading, promotion, or review authority.
5. Core/high-risk final review uses the Acceptance-Grade Independent Exact-Head Scrutiny path (default Claude Opus 5.5 High). Independence is established by separate author/reviewer jobs and lanes, read-only evidence isolation, exact-head identity, deterministic/adversarial gates, and fail-closed authority handling—not provider family.
6. Explicit route/model per dispatch; no silent fallback. No surprise separately billed API fallback. Google AI Pro consumer OAuth != Gemini API key billing; ChatGPT subscription != OpenAI API billing.
7. Legacy Claude-specific launchers that target the previously cancelled direct Claude service remain historical/unavailable routes. Antigravity Claude models are a current, separate Google AI Pro route. Preserve historical launcher evidence and do not relabel it as Antigravity execution. Codex remains available only as an explicitly selected specialist route, not a default critical-path dependency.

## Subscription, OAuth, and paid API boundary

ChatGPT subscription OAuth and separately billed API-key usage are distinct. ChatGPT Plus does not imply paid OpenAI API authority. Google AI Pro Antigravity consumer OAuth/keyring is distinct from Gemini API-key billing. There is no automatic paid fallback. Resolve the active authentication surface and obtain any required billing authority before a billable smoke.

References (public API/tool documentation, not project authority):

- [OpenAI Codex authentication](https://developers.openai.com/codex/auth)
- [OpenAI Codex models](https://developers.openai.com/codex/models)
- [Hermes provider integrations](https://hermes-agent.nousresearch.com/docs/integrations/providers)
- [Google Code Assist Individuals deprecation](https://developers.google.com/gemini-code-assist/docs/deprecations/code-assist-individuals)

The current Hermes docs describe `openai-codex` OAuth, but pinned local Hermes `0.20.5` must still be checked; public current docs do not prove pinned-version compatibility.

## M2 qualification checklist

All qualification uses a clean exact pushed HEAD, task-scoped overrides, captured provenance, no secrets, and one bounded repair followed by one recheck.

### Codex launcher/client

- Resolve the authenticated model list from the installed Codex client.
- Verify launcher arguments against current help before use. `exec-local --ask-for-approval` was absent from observed help; do not treat the generic launcher as qualified until reconciled.
- Run a bounded no-mutation fixture and record exact client version, auth class, requested/resolved model, exit, and output identity.
- Do not silently update global Codex configuration.

### Historical/optional Gemini reviewer qualification

- Verify billing/free-tier authority before making a new model request.
- Use a read-only exact-head review fixture with seeded positive and negative findings.
- Prove refusal of writes, shell/tool expansion, moved HEAD, ambiguous provenance, and out-of-scope instructions.
- Record CLI version, auth class without secrets, requested/resolved model, exact HEAD, prompt hash, output hash, and exit.
- Demonstrate relevant review competence; installation/login alone is insufficient.
- Qualification author must not grade its own seeded fixture as the sole final reviewer.

### Hermes GPT route

- Preserve Hermes `0.20.5`, tag `v2026.8.19`, commit `fcbd1076a93841fa88855acce810e342a5b78101`, SOUL bytes, MCP manifests, toolsets, and allowed scopes.
- Use existing `run_profile_task.ps1` task-scoped `InferenceModel`/`InferenceProvider` overrides; do not apply persistent profiles.
- Replay the same accepted no-MT5 boundary and verify tool refusal, workspace/head binding, provenance, and deterministic evidence handling.
- Do not rerun accepted H2/H3 backtests merely to qualify the provider.
- A provider/auth failure is an environment/provider qualification blocker, not strategy failure.

The checklist above records the former qualification objective and remains useful only for optional support-route qualification. It no longer controls core/high-risk acceptance or creates a mandatory different-family dependency.

## Exact-head and device rules

Keep one writer. Freeze a clean exact commit before one separate read-only Acceptance-Grade Independent Exact-Head Scrutiny job; default reviewer is Claude Opus 5.5 High when independent. If HEAD moves, rerun impacted checks and bind review to the new exact head. The author job cannot self-approve.

For device execution, select BaBoss deviceId `bbb88aa0-1598-43f6-b56c-a7db22af086a`, then verify hostname and repository origin. `MOC-NB-4432NKM` deviceId `fa2a5704-038f-4aba-b539-c1d5d7adde70` is not an EA_LAB execution target without explicit mapping. Never select the first online device implicitly.

## Preserved state and hard stops

MS-SYSTEM-02 remains partial: A/C/D accepted; B deferred and blocked `C_ENVIRONMENT_DEPENDENCY`. The A/B control proves only the same current Boss12 result for old/new code in the current environment; it is not all-EA no-regression proof and does not replace `tpl_regression`. Do not repin or waive the baseline.

Preserve ORDER-353/VPS `PARKED_WAITING_MANUAL`, `first_trade_epoch=null`, `judge_date=null`, global `DEGRADED_MONITORING`, and x58. Preserve `HYP-B16-GBP-H4-EXITCONC-01` as preregistered `NOT_EXECUTED`. No optimization, HOLDOUT, Candidate, deployment, trading, runtime activation, risk/default, Grade, or KINT authority is created.

## Next Control Tower contract

1. Re-anchor to fresh pushed Git and merge user additions/other-chat handoffs using an accepted/pending/contradicted source map.
2. Verify M1 documentation/metadata reachability and review evidence; reuse the accepted scope without resurrecting its rejected validator. Local commit/freeze precedes independent review; normal FF push follows successful review and reconciliation.
3. Treat remaining M2 qualification as optional provider/tooling capability work with direct consumers: Codex launcher/client compatibility; optional Gemini read-only support-route qualification with negative tests; Hermes same-boundary GPT no-MT5 replay through task overrides. None gates the canonical core/high-risk scrutiny path.
4. Do not apply persistent profiles or activate schedulers without explicit runtime approval.
5. Keep runtime identity B deferred and separate later system/audit/research work by direct consumer; do not rewrite the whole repository.
6. Use the replacement Project Instructions/Operating Context package produced after the reviewed M1 push as snapshots; merge owner additions before producing the next full-replacement version. Project UI application is not automatic.
