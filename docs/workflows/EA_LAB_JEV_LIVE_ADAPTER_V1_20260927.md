# EA_LAB Jev Live Adapter V1 — 2026-09-27

Status: **SOURCE CANDIDATE / LIVE PROVIDER ACCEPTANCE BLOCKED ON CREDENTIAL**.

Owner authority: the owner's 2026-09-27 request to make Jev and lnwjud actually
usable authorizes this bounded adapter and one live provider qualification. It does
not grant trading, MT5, risk/default, deployment, LIVE, governance, or owner-attestation
authority.

## Purpose

Add one explicit TypeSafe Jev call to the already-canonical Control Routing V1.
The adapter may provide a typed advisory choice for a closed option set. It is not
a second Control Tower, decision owner, scheduler, service, Registry writer, or
source of truth.

Deterministic evidence and `decision.py` remain authoritative. A Jev result may not
override compiler/tests, owner hard stops, dependency state, repair budgets, required
review, canonical evidence, or the Lane Registry.

## Upstream API binding

The wire contract is pinned to the official `typesafe-ai/typesafe-sdk-python`
repository release v0.7.2 commit:

`f078f1e208a0d885154dc758344ae4fce77ac168`
At that exact upstream ref the generated OpenAPI models define:

- endpoint: `POST https://api.typesafe.ai/v1/systemone`;
- auth: `Authorization: Bearer <TYPESAFE_API_KEY>`;
- request: `state`, `model`, and a non-empty `questions` object;
- choice question: `type=choice`, `instructions`, and named `criteria`;
- response: exactly `model`, `answers`, and `usage`;
- choice answer: `type`, `choice`, `confidence`, `probabilities`;
- usage: integer `input_tokens`, `output_tokens`.

EA_LAB uses the vendor alias `jev-latest` by default and records both requested and
returned model identities. `TYPESAFE_JEV_MODEL` may replace the alias with an explicit
vendor model name. Provider/model availability must be proven by the live qualification;
source tests never fabricate provider availability.

## Input mapping

V1 intentionally reuses `ea_lab_jev_shadow_input/1`. This keeps the existing closed
EA_LAB option vocabulary and its bounds:

- `task_id`;
- bounded `question`;
- two or more unique options from the existing control decision allowlist;
- at most 30 bounded `evidence_summary` strings.

The provider receives only:

- `state.task_id`;
- `state.evidence_summary`;
- one question named `decision`;
- that question's instructions and exact requested options.

No repository file, secret, raw Registry record, process state, MT5 object, account
record, or unrestricted prompt is automatically added.
## Credential and transport boundary

The API key is read only from process environment variable `TYPESAFE_API_KEY`.
It is never emitted in the result, exception text, evidence payload, or source.
Missing auth refuses before network access.

The endpoint is fixed to the TypeSafe production HTTPS endpoint. Runtime calls have
a 0.5..30 second bounded timeout and a 256 KiB response ceiling. HTTP, timeout,
connection, malformed JSON, duplicate JSON member, schema, and probability failures
all fail closed.

There is no automatic retry in V1. A caller must make a new explicit invocation.
There is no persistent background Jev service or scheduler.

## Response validation

A usable answer must satisfy all of these:

1. top-level object is exactly `model / answers / usage`;
2. exactly one answer exists, named `decision`;
3. answer type is `choice`;
4. selected choice is in the requested option set;
5. confidence is finite in `[0,1]`;
6. probability keys exactly equal the requested option set;
7. every probability is finite in `[0,1]`;
8. probabilities sum to 1 within absolute tolerance 0.02;
9. selected choice is one of the maximum-probability choices;
10. usage contains exactly two non-negative integer token counters.

Unknown/additive provider fields are rejected under this exact-schema V1 contract
rather than silently accepted.
## Output and authority

Successful output is `ea_lab_jev_live_result/1` and records:

- requested and returned model;
- request id when supplied by TypeSafe;
- selected option, confidence and complete probabilities;
- usage counters;
- exact upstream SDK commit;
- `transport_status=LIVE_CALL_PASS`;
- `authority_ceiling=ADVISORY_ONLY_NO_CONTROL_AUTHORITY`;
- `runtime_activation=false`;
- `canonical=false`.

A live provider PASS proves only that this bounded adapter can obtain and validate
a TypeSafe response. It does not prove calibration, economic correctness, trading
edge, review competence, or permission to act on the selected option.

## Acceptance

Source acceptance requires:

- focused positive and fail-closed tests;
- missing-auth-before-network proof;
- exact request shape and no-secret-output proof;
- malformed/duplicate/extra/probability/usage negative cases;
- py_compile;
- implementation-manifest regeneration and verification;
- existing Control Routing regression suite;
- `git diff --check`;
- clean exact frozen HEAD;
- one separate read-only exact-head GPT Scrutiny.

Live provider acceptance additionally requires a real owner credential available as
`TYPESAFE_API_KEY`, one bounded call, returned-model identity, valid typed response,
and a receipt that contains no credential.
## Current environment blocker

At admission on 2026-09-27, BaBoss has no `TYPESAFE_API_KEY` in Process, User, or
Machine environment. Therefore source implementation and review may complete, but
`LIVE_PROVIDER_ACCEPTANCE_PASS` cannot be claimed until that credential exists.

No credential may be committed to Git or written into an EA_LAB evidence artifact.
