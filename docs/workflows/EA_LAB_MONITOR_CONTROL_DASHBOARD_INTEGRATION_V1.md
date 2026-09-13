# EA_LAB Monitor / Control Dashboard Integration V1

Status: `REPO_ONLY / READ_ONLY_PRESENTATION / REVIEW_REQUIRED`

Purpose: keep the existing EA_LAB Monitor as the single owner-facing application while incorporating only the useful read-only evidence views from the Control Dashboard audit.

## Source and authority boundaries

- Canonical Git owns project/research statements.
- Lane Registry remains noncanonical operational observation.
- Runtime evidence remains separately qualified and may be `UNKNOWN` or `DEGRADED`.
- Factory pilot completeness is presentation of canonical file evidence only.
- No projection in this change creates strategy, Grade, Candidate, risk, runtime, deployment, DEMO/LIVE or trading authority.
- The historical Control Dashboard renderer remains reference evidence; it is not a second product or source of truth.

## Work integration

The existing Monitor Work view remains the owner. Existing taskboard and Lane Registry audit projections are reused; the Control Dashboard lane parser is deliberately not copied.

Work emphasizes qualified unfinished observations, keeps DONE rows available as history, and labels total Registry rows as cumulative history rather than concurrent-agent count. Agent Graph and Detailed lanes remain the existing Monitor implementations.

## EA Lab integration

A deterministic `factory_pilot_projection/1` reads the exact pinned Git tree under `factory/vnext/pilots`. Required evidence is checked without guessing from adjacent files.
At the implementation pin used during acceptance, the projection contains nine pilot directories: one valid pilot and eight explicit missing-artifact issues. `INCOMPLETE_EVIDENCE` is intentionally not translated into trading loss, strategy failure, runtime failure or abnormal-market status.

Safe report copies use relative content-addressed links. Windows paths, `file://` URLs and UNC references are not exposed.

## Alerts integration

Alerts surface only work/evidence conditions: qualified blocked-lane observations, stale/unqualified observations, and Factory evidence gaps. Copy states explicitly that these conditions do not imply P&L loss, EA malfunction, abnormal market behavior or runtime failure.

## Observation metadata

Presentation includes source kind, pinned canonical SHA, observation timestamp/timestamp basis and limitations. Current/historical status is never upgraded from an unqualified or stale source.

## Deliberate exclusions

- no new Lane Registry parser or status calculator;
- no replacement source registry;
- no agent execution buttons;
- no trading controls;
- no Scheduled Task change;
- no OneDrive delivery change;
- no hosting/public deployment;
- no runtime attachment or activation;
- no C01/core patch.

The existing Control Dashboard and its staged activation package remain preserved until this Monitor integration is accepted. No Dashboard Scheduled Task activation is part of this milestone.

## Acceptance

Required acceptance is impacted Python/data regression, static UI checks, Agent Graph deterministic tests, JS syntax/diff checks, and real headless browser checks at 390x844 plus desktop. Browser dependencies use the already-installed workspace Playwright/AJV module directories through process-local `NODE_PATH`; no global package installation is required.

A normal commit, exact-head independent review, fresh origin reconciliation and normal fast-forward-compatible integration are required before canonical push. Runtime activation remains a separate owner hard stop.