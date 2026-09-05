# RuntimeIdentity Coverage / Onboarding Contract — 2026-09-05

Status: `CONTRACT_READY / NOT_IMPLEMENTED / CURRENT_X58_UNCHANGED`
Canonical base: `244c15d5c01dfdf31b3ce11daf578897b0376376`
Authority: monitoring classification design only. No inventory reclassification, attestation, runtime mutation, or deployment authority.

## Current evidence

Canonical monitoring currently defines the RuntimeIdentity expected universe from forward-observed, non-REMOVED deployment rows. That set is 58 ACTIVE rows. Current evidence is 1 mapped, 57 unmapped, 0 validated PASS, 0 fully bound. This contract does not rewrite those facts.

Two distinct scope dimensions are currently hidden inside that single denominator:

- mechanism capability: RuntimeIdentity is implemented for the MQL5 LabCore lineage; no MT4 RuntimeIdentity producer exists in the repository;
- certification responsibility: some deployment rows explicitly state that the lab does not certify the user-owned EA, while one `user mix` row also has high-confidence attestation evidence, proving that free-text account/notes inference is not reliable enough for machine policy.

Therefore prose notes, trade history, account-level governance, dashboard presence, filenames, or old activity must never be used to silently shrink the denominator.

## Frozen classification model

Every forward-observed non-REMOVED `(account, magic)` retains membership in `scope_total_forward_observed`.

Add two explicit per-row classifications:

- `identity_mechanism_capability`: `NATIVE_RUNTIME_IDENTITY | NO_NATIVE_RUNTIME_IDENTITY_MT4 | UNKNOWN`;
- `identity_certification_scope`: `LAB_CERTIFIED | USER_OWNED_UNCERTIFIED | UNKNOWN`.

Both are keyed by exact `account|magic`. `UNKNOWN` is fail-closed and must never be interpreted as excluded or certified by default.
## Reporting contract

Publish these dimensions side by side rather than replacing x58 with a cosmetically smaller number:

- `scope_total_forward_observed` — the existing lifecycle universe; remains 58 until canonical inventory changes for independent reasons;
- `scope_native_identity_capable` — rows with a proven native RuntimeIdentity producer path;
- `scope_mechanism_unavailable` — rows whose current platform/build has no native RuntimeIdentity mechanism;
- `scope_lab_certified` — rows explicitly inside lab certification scope;
- `scope_user_owned_uncertified` — rows explicitly outside lab certification scope;
- `scope_unknown` — unresolved capability/certification rows, always fail-closed;
- within the lab-certified/native-capable subset: mapped, validated PASS, fully bound, unmapped.

The current global `DEGRADED_MONITORING` state and the existing x58 failure remain unchanged by this contract. A mechanism-unavailable row is not mislabeled as ordinary mapping debt, but it remains a visible assurance gap until either an equivalent identity mechanism exists or an explicit owner-ratified monitoring policy changes its requirement. Likewise, an explicitly user-owned/uncertified row may be excluded from a future **lab-certification pass-rate** only after its structured scope fact is canonical; it remains visible as observed-but-uncertified and does not disappear from the deployment universe.

## Structured source of truth

Do not parse narrative `DEPLOYMENTS.csv.notes` at runtime. Introduce a dedicated machine-readable per-deployment scope owner (recommended: `portfolio/CERTIFICATION_SCOPE.csv`) keyed by `account|magic`, with at least:

`account,magic,identity_mechanism_capability,identity_certification_scope,evidence_ref,status`

Initial population may mechanically transcribe only already-explicit facts. Any ambiguous row remains `UNKNOWN`; no agent may create owner attestation or resolve an ownership ambiguity from prose alone.
## Migration / onboarding order

1. Add and schema-validate the structured per-deployment scope owner without changing current global verdicts.
2. Deterministically classify capability from explicit platform/build evidence; MT4 may be `NO_NATIVE_RUNTIME_IDENTITY_MT4` only when the row's platform is proven MT4.
3. Transcribe explicit certification facts; ambiguous `user mix`/attestation contradictions remain `UNKNOWN` pending owner clarification.
4. Extend monitoring output with the sub-denominators and arithmetic reconciliation while preserving `scope_total_forward_observed` and current x58 reporting during migration.
5. Add negative fixtures before changing any verdict routing.
6. Only after the structured scope owner and tests are reviewed may lab-certified/native-capable onboarding proceed one `(account, magic)` at a time using the existing build/config/attach evidence bar. No mapping may be invented from historical trades or old attestation.

## Minimum negative tests

- MT4 ACTIVE row is classified mechanism-unavailable, remains visible, and cannot be reported as a missing native mapping without the reason dimension.
- explicit user-owned/uncertified row remains visible and cannot become lab-certified merely because an identity file or mapping exists;
- no explicit scope fact -> `UNKNOWN`, never silently excluded;
- same account with different per-magic scope proves no account-level shortcut is allowed;
- `scope_total_forward_observed` equals the complete union of explicit capability/certification outcomes plus unknowns; no row vanishes;
- trade-history presence/absence cannot alter certification or current-attachment classification;
- structured-scope ambiguity keeps global monitoring non-green;
- existing ORDER-353 and deployment-unverified fail-closed cases remain unchanged.

## Current-count caution

Read-only analysis found 9 ACTIVE MT4 rows and 12 rows with the literal `lab does not certify`; a thirteenth `user mix` row has high-confidence attestation evidence and is therefore ambiguous. These are diagnostic observations only. They are not an authorized replacement denominator and must not be written into scorecard/verdict logic until the structured scope owner reproduces them deterministically and ambiguity is resolved.

## Authority ceiling

No `DEPLOYMENTS.csv`, `ATTESTATION_MAP.csv`, RuntimeIdentity map, certification fact, or monitoring verdict is changed by this contract. Current x58, ORDER-353 `BLOCKED / E`, null first-trade/judge clocks, and `DEGRADED_MONITORING` remain authoritative. Implementation is a separate bounded monitoring/schema lane with normal tests and independent review.
