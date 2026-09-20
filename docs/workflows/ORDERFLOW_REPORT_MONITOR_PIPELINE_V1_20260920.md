# Order Flow Proxy report / Monitor projection pipeline V1

Status: `SOURCE_PREPARATION / COMMIT_REQUIRED / NO_MONITOR_HOOKUP`

Can do: Codex Primary author. Direct consumer: the existing EA_LAB Monitor integrator after the shared serializer and UI ownership are free.

## Boundary

`tools/orderflow_proxy/research_presentation/` is a deterministic read-only projection module. It does not create an application, parse the Lane Registry, alter shared Monitor files, run MT5, interpret tester output, or grant experimental state. Its only outputs are a strict contract-specific JSON status projection and static HTML rendered from that JSON.

The module reads an exact local Git checkout/ref and the canonical `portfolio/ORDERFLOW_MT5_PROXY_TEMPLATE_SEAM_V1_20260920.json`. It binds the accepted manifest, proxy source, provider seam, cards, reference implementation, fixture, and bundle builder by committed SHA-256 and Git blob identity. The checkout `HEAD` must equal the supplied full commit. Each locked working-tree input must equal the committed blob. No fetch or network operation exists.

The current source acceptance remains historical `EXACT_WINDOW_ONLY` for `XAUUSD`, `EURUSD`, `GBPUSD`, `EURGBP`, `USDJPY`, and `EURJPY`. It is not standing six-symbol historical readiness. `BTCUSD` and `ETHUSD` remain `PARKED` with `RATE_SNAPSHOT_CHANGED` and no fallback.

## R0 preparation semantics

The projection names the six frozen variants and their explicit one-change parents, D1/M15/M5 roles, requested MAIN 2023-2025 and BWD 2020-2022 windows, 36+36 planned cells, and zero executed cells. P0 remains a quote-tick activity-profile control rather than a pure OHLC strategy. Prose containing `RUN` or `Model4` never establishes execution.

Source, data, execution, observation, and Monitor states remain separate:

- accepted source history is a source fact only;
- historical raw data, a reviewed historical manifest/bundle, native event/geometry parity, and a geometry-aware execution contract remain `WAITING_GATE`;
- MAIN/BWD performance remains `NOT_RUN`;
- every performance metric is `null` with an explicit reason;
- native equity remains `UNAVAILABLE`;
- Monitor `wired`, `deployed`, and `live_refresh_asserted` remain `false`.

The report contains no zero-PF substitute, synthetic fixture metric, Candidate/grade recommendation, blank graph, progress percentage, or freshness assertion based on wall time, file mtime, or generated output. A future performance/result schema is deliberately out of scope until raw result, execution contract, and review identities exist.

## Safety and integration contract

All report text is HTML-escaped. The HTML has no script or external resource and emits no links. The projection's link policy permits only future repository-relative content-addressed artifacts; its current link set is empty. Absolute Windows paths, UNC paths, `file:`, `javascript:`, and `data:` links are not an output surface. Source paths are fixed repository-relative display identities only.

Optional supplied observations use a narrow exact-field schema and cannot carry performance or affirmative execution/authority/Monitor booleans. They must bind the exact source ref and manifest SHA-256 and pass an explicit validity interval check. Even then they remain caller-supplied metadata and freshness is `NOT_ASSERTED`.

The existing Monitor remains the sole application. A later integrator may map this JSON into the existing presentation layer, but must not turn source acceptance into data/performance acceptance, infer execution from prose, create live refresh, or add a second Registry/status parser. Hookup, deployment, runtime observation, and refresh remain separate reviewed work.

## Validation

The self-contained standard-library suite covers the positive canonical render, exact golden reproducibility, planned/negated Model4 prose, missing/dirty/hash-mismatched source, path traversal, outside-root symlink where the account permits creation, stale/unbound observation, unknown/malformed fields, output filename traversal, HTML escaping, no source promotion, BTC/ETH no fallback, invented performance refusal, and metadata-only observation behavior.

Visual acceptance is optional and must be reported separately. An installed process-local Playwright may render mobile 390x844 and desktop screenshots without installing or downloading anything. Browser absence is `NO_VISUAL_ACCEPTANCE`, not UI PASS and not a module failure.
