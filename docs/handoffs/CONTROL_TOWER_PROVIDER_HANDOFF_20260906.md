# Control Tower Provider Handoff — 2026-09-06

## Intake identity

- Milestone: `MS-WORKFLOW-03 / provider transition M1`
- Author lane: `ct-provider-transition-20260906`
- CT-verified clean base: `7b52ff0f7b71ad2a9f10065841378a12bbfa43d8`
- Author mode: explicit patch-only adapter after a read-only sandbox blocked the first write-capable attempt
- Status: `M1 DOCS + INERT TARGET METADATA ONLY`; `PROPOSED VALIDATOR NOT_ACCEPTED / M2 PENDING`
- Codex supplied patch-only author text; CT mechanically applied it. No downstream model call, persistent profile application or runtime activation was made by the author. Review/push evidence must be read from the exact-head receipt and verified Git; do not infer a full provider migration from this file.

## Source map for the next Control Tower

### ACCEPTED / PRESERVE

- Claude is owner-reported cancelled/unavailable; ChatGPT is the one active Control Tower and Codex is the default local author.
- Prior accepted Claude reviews remain valid historical evidence. `CLAUDE.md` remains the canonical production verdict gate and is not renamed or weakened.
- ChatGPT, Codex, and GPT-backed Hermes are one model family and cannot provide different-family review for one another.
- Hermes H1/H2/H3 mechanical evidence is reusable; provider qualification does not require rerunning accepted H2/H3.
- MS-SYSTEM-02 A/C/D are accepted. B remains excluded from Git and blocked `C_ENVIRONMENT_DEPENDENCY`; transient handoff: `D:\EA_LAB_CONTROL\handoffs\MS_SYSTEM02_B_HEARTBEAT_BLOCKED_20260906`.
- B's current-environment A/B control shows the same Boss12 result for old/new code only. It does not prove all-EA no regression and does not override `tpl_regression`.
- Preserve ORDER-353/VPS `PARKED_WAITING_MANUAL`, null first-trade/judge fields, global `DEGRADED_MONITORING`, x58, and `HYP-B16-GBP-H4-EXITCONC-01 = NOT_EXECUTED`.

### PENDING

- M2 qualification; the rejected provider-validator implementation requires a new bounded follow-up, not a second retry of the closed repair cycle.
- Hermes `openai-codex` / `gpt-5.6-sol` task-scoped qualification; repo target is not applied to installed profiles.
- Codex launcher/client compatibility, including the observed absence of `exec-local --ask-for-approval` from current help.
- Gemini read-only/tool-boundary/provenance/competence qualification before any acceptance-grade different-family review.
- Gemini billing/free-tier and live auth behavior. No new Gemini model request was made in M1.
- Runtime identity B remains deferred by owner direction.

### CONTRADICTED / SUPERSEDED FOR CURRENT ROUTING

- Any current instruction to route work to Claude or wait for temporary Claude quota.
- Any claim that the installed Hermes profiles already use GPT, or that repository defaults are a runtime `LIVE_PASS`.
- Any claim that ChatGPT Pro includes paid API billing, that Gemini has a fixed free quota, or that absent process environment variables prove no stored credentials.
- Any use of ChatGPT/Codex/GPT Hermes as a different-family reviewer of another member of that group.
- Any first-online device selection. Use BaBoss `bbb88aa0-1598-43f6-b56c-a7db22af086a` and verify hostname/repo origin; `fa2a5704-038f-4aba-b539-c1d5d7adde70` is not mapped as an EA_LAB target.

## Local/provider facts carried forward

- Codex CLI `0.144.2`, authenticated using ChatGPT.
- Gemini CLI `0.58.0`; `security.auth.selectedType=gemini-api-key`; no key is included.
- Gemini/Google/OpenAI API variables were absent in the Desktop Commander process; stored-key absence is not proven.
- Old global Codex `gpt-6-astra` failed a newer-client requirement earlier; `gpt-5.6-sol` ran. Do not update global configuration silently.
- Installed Hermes four-profile configs remain `anthropic/claude-sonnet-4.6` / `anthropic` and untouched.
- First author attempt: `C_ENVIRONMENT_DEPENDENCY` for write-launcher qualification, no repository change, not product failure. Current patch-only delivery grants no expanded permissions.

## Test receipt

Author status remains `NOT_RUN_BY_AUTHOR`. CT observed: original 11 focused cases passed; four adversarial cases failed; after one bounded repair 25 focused cases and the original four adversarial cases passed, but the column-zero YAML comment-boundary recheck still FAILED. The proposed code is therefore NOT ACCEPTED and was excluded from the commit. Read-only checks against four emitted installed-profile shapes passed with profile bytes unchanged; those checks do not cure the demonstrated false accept. The canonicalized scope is documentation plus inert metadata, not a tested provider migration.

CT packaged-scope acceptance (2026-09-06): 17/17 documentation/inert-metadata checks PASS; active manifest defaults/pins/MCP/toolsets/history unchanged; shipped validator byte-identical to base; no proposed provider test shipped. Canonical `converge_state_surfaces.ps1 -CheckOnly` returned PASS with digest/state exits 0/0, and `git diff --check` returned 0. Receipt: `D:\EA_LAB_CONTROL\provider_docs_scope_receipt_20260906.json`. These PASS results apply only to the reduced documentation/metadata package, not the rejected provider implementation. Final exact-head review/push receipt is recorded after commit freeze.

Verification commands from repository root:

1. Compare `tools/hermes_ea_lab_pilot/scripts/validate_profiles.ps1` against base `7b52ff0f...`: byte-identical; confirm no new provider test script or active default switch is shipped.
2. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_state.ps1 -Strict`
3. `git diff --check`

Confirm the diff contains only contract-allowed paths and that no local/global Hermes, Codex, or Gemini profile/auth/config changed. If one bounded repair is needed, repair once and rerun impacted acceptance. Freeze one clean exact commit before one independent review; moved HEAD invalidates that review.

## Next execution sequence

First reconcile fresh pushed Git with user additions and other-chat handoffs using the source map above. Reuse the accepted M1 documentation/metadata scope after verifying its exact-head receipt, then execute M2 as three bounded contracts: Codex client/launcher fixture, Gemini exact-head reviewer qualification with negative tests, and Hermes GPT same-boundary no-MT5 replay via explicit task-scoped overrides. Do not apply persistent profiles, activate schedulers, rerun accepted H2/H3, or broaden into runtime/system/research work without its direct consumer and authority.

## Rejected proposal preservation

External restart aid: `D:\EA_LAB_CONTROL\handoffs\MS_WORKFLOW03_PROVIDER_VALIDATOR_BLOCKED_20260906`. It includes proposed validator/tests and the failing comment-boundary fixture. This is not accepted code. Prior application receipts are in `D:\EA_LAB_CONTROL\provider_patch_apply_receipt_20260906.json` and `provider_repair01_apply_receipt_20260906.json`. Do not apply these patches automatically. The current manifest records `implementation_status=BLOCKED_A_PROPOSED_VALIDATOR_DEFECT`; old defaults and historical provider_evidence remain unchanged.
