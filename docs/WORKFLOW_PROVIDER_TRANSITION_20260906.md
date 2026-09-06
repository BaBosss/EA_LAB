# Workflow Provider Transition — 2026-09-06

## Status and scope

MS-WORKFLOW-03 M1 delivers routing documentation and inert Hermes target metadata only. It does not switch active repository defaults, apply profiles, authenticate a provider, invoke Gemini, or activate Hermes/MT5/VPS/schedulers. The proposed provider-check code was NOT ACCEPTED: after one bounded repair and 25 passing focused cases, a targeted recheck proved that a column-zero YAML comment could hide a duplicate model.provider. Preserve this A_PRODUCT_DEFECT in the proposed validator; it is not a failure of the accepted baseline or any strategy. Code and fixtures are saved outside Git, while the shipped validator remains byte-identical to base. M2 qualification and a new bounded validator follow-up remain pending.

This document owns provider-transition routing and its qualification checklist. `AGENTS.md` owns roles and authority; `PROJECT_STATE.md` owns current status; `AGENT_TASKBOARD.md` points to the bounded contract; `START_HERE.md` routes startup. `CLAUDE.md` remains the canonical production verdict gate despite its filename and current service cancellation. Historical Claude reviews remain valid evidence.

## Evidence classification

### OWNER_REPORTED

- Claude subscription/service is cancelled and unavailable; this is not temporary quota waiting.
- ChatGPT Pro is active. Exact tier limits are unspecified.
- Gemini is usable, but is not yet qualified as an acceptance-grade different-family core reviewer.

Owner reports are project inputs, not billing-provider verification.

### LOCALLY_VERIFIED

The transition intake records these local observations from Control Tower without exposing credentials:

- Codex CLI `0.144.2`; login status: `Logged in using ChatGPT`. The current Codex execution uses ChatGPT authentication.
- Gemini CLI `0.58.0` is installed. `security.auth.selectedType=gemini-api-key`; the key is not recorded.
- Gemini/Google/OpenAI API environment variables were absent in the Desktop Commander process. This does not prove that stored keys are absent.
- No new Gemini model request was made because billing/free-tier status was not verified.
- An older global Codex selection, `gpt-6-astra`, previously failed a newer-client requirement; `gpt-5.6-sol` ran. Do not silently change a global model.
- Installed Hermes `ea-researcher`, `ea-coder`, `ea-tester`, and `ea-reviewer` configs still specify `anthropic/claude-sonnet-4.6` and provider `anthropic`. They are untouched by M1.
- The first Codex author attempt exited without repository changes because its sandbox was enforced read-only. Classify write-launcher qualification as `C_ENVIRONMENT_DEPENDENCY`, not product failure. The current delivery is an explicit patch-only adapter, not expanded permission.

### TARGET / PENDING

- Hermes inert target metadata: `provider_transition.target_provider=openai-codex`, `provider_transition.target_model=gpt-5.6-sol`. Active default_provider/default_model remain Anthropic/Sonnet; a metadata target is not a runnable migration.
- Target state: `REPO_CONFIG_ONLY_NOT_APPLIED / QUALIFICATION_PENDING`; there is no new runtime `LIVE_PASS`.
- Actual model names must be resolved from the authenticated local surface and a bounded smoke, not inferred from marketing names.
- Gemini live authentication, quota/billing behavior, tool boundary, provenance, and review competence remain unverified pending M2.

## Current routing

1. One active ChatGPT Control Tower manages one project truth, task contracts, interpretation, and integration decisions inside existing authority.
2. Codex Primary is the default local implementation/test/integration author. A bounded Codex session is a worker, not another Control Tower or its own reviewer.
3. Use deterministic local tooling first. Do not keep an LLM waiting for every tester cell. Reuse accepted Hermes H1/H2/H3 mechanical evidence and deterministic executors when the direct consumer does not require a new observation.
4. GPT-backed Hermes remains a mechanical EA R&D evidence factory. Provider changes grant no strategy, risk, HOLDOUT, deployment, trading, promotion, or review authority.
5. ChatGPT, Codex, and GPT-backed Hermes are the same model family. They never satisfy a different-family core review requirement for one another.
6. Gemini is the only identified different-family route and may be used for such review only after the relevant M2 qualification. If unavailable or unqualified, the required review is `BLOCKED`; do not weaken the reviewer requirement or review repeatedly until PASS.
7. Claude-specific launchers are unavailable legacy routes. Preserve them and historical evidence; do not rename them or pretend they invoke Gemini/Codex.

## Subscription, OAuth, and paid API boundary

ChatGPT subscription OAuth and separately billed API-key usage are distinct. ChatGPT Pro does not imply paid OpenAI API authority, and Gemini usability does not establish a fixed free quota. There is no automatic paid fallback. Resolve the active authentication surface and obtain any required billing authority before a billable smoke.

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

### Gemini different-family reviewer

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

## Exact-head and device rules

Keep one writer. Freeze a clean exact commit before one independent review; if HEAD moves, rerun impacted checks before review/integration.

For device execution, select BaBoss deviceId `bbb88aa0-1598-43f6-b56c-a7db22af086a`, then verify hostname and repository origin. `MOC-NB-4432NKM` deviceId `fa2a5704-038f-4aba-b539-c1d5d7adde70` is not an EA_LAB execution target without explicit mapping. Never select the first online device implicitly.

## Preserved state and hard stops

MS-SYSTEM-02 remains partial: A/C/D accepted; B deferred and blocked `C_ENVIRONMENT_DEPENDENCY`. The A/B control proves only the same current Boss12 result for old/new code in the current environment; it is not all-EA no-regression proof and does not replace `tpl_regression`. Do not repin or waive the baseline.

Preserve ORDER-353/VPS `PARKED_WAITING_MANUAL`, `first_trade_epoch=null`, `judge_date=null`, global `DEGRADED_MONITORING`, and x58. Preserve `HYP-B16-GBP-H4-EXITCONC-01` as preregistered `NOT_EXECUTED`. No optimization, HOLDOUT, Candidate, deployment, trading, runtime activation, risk/default, Grade, or KINT authority is created.

## Next Control Tower contract

1. Re-anchor to fresh pushed Git and merge user additions/other-chat handoffs using an accepted/pending/contradicted source map.
2. Verify M1 documentation/metadata reachability and review evidence; reuse the accepted scope without resurrecting its rejected validator. Local commit/freeze precedes independent review; normal FF push follows successful review and reconciliation.
3. Execute M2 qualification in three separate bounded consumers: Codex launcher/client compatibility; Gemini exact-head read-only review qualification with negative tests; Hermes same-boundary GPT no-MT5 replay through task overrides.
4. Do not apply persistent profiles or activate schedulers without explicit runtime approval.
5. Keep runtime identity B deferred and separate later system/audit/research work by direct consumer; do not rewrite the whole repository.
6. Use the replacement Project Instructions/Operating Context package produced after the reviewed M1 push as snapshots; merge owner additions before producing the next full-replacement version. Project UI application is not automatic.
