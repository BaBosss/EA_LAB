# B21 / DF03 source acceptance — 2026-09-18

Status: SOURCE_ACCEPTED / REVIEWED / CANONICAL / REPO_ONLY. Accepted source: `19bafeec7d75339e166bafc23913a168dac3bc38`; immediate control parent: `ba887429c7553d8da5c6cef262ae12ec3ac67d94`.

## Accepted scope
The existing source-native B21 implementation and its single timer-path repair are accepted at the exact reviewed source head. The offline timer-to-native-tick seam now passes the runtime-identity/current-DD/halt guard while preserving native timer/trade/cleanup behavior. The parent/compatibility/TemplateEngine lineage and source-native strategy ownership are preserved. No parent, strategy defaults, Home/TF or trading semantics were selected or retuned by this closeout.

Initial scrutiny at `7c8b3f9f552795405265fce3fea7ac356fb73b3a`, the spent source repair1/1, compile-only harness fixes and all historical failed receipts remain evidence. Targeted GPT Scrutiny returned `SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION` on `19bafeec7d75339e166bafc23913a168dac3bc38`. No provider-family or Gemini/Qwen gate applies under current canonical governance. This is not a repeat of the initial review or a repair-budget reset.

## Warning contract and regression
The compile refusal was a harness-policy mismatch: B21's frozen contract requires zero errors and truthful inherited warnings, while broad deploy requires zero/zero. Exact source-bound comparison proved all24 diagnostics (location/code/message) match historical wrapper diagnostics, with the same parent warning kinds and unchanged warning source lines. No warning was suppressed and no source was changed to silence it.

The external compiler accepts only that exact B21 diagnostic set and rejects any change; all other dynamically discovered targets remain zero/zero. Twelve deterministic positive/negative gate tests passed. The current compile arm included all10 targets and the control all9 targets. The generic canonical deploy/TPL source is unchanged; this scoped compiler is not general deployment approval.

Fixed Build6090 adjacent parity passed8/8 exact comparisons across Boss11–18, with16 fresh reports on one `D:\Meta 5b` portable installation. Both arms used XAUUSD/H1, Model1, 2024.01.01–2024.07.01, USD10000, leverage1:100 and frozen baseline sets. Net/PF/trade-count/equity-DD equality is a regression assertion only, not strategy performance evidence. B21 was compiled, not performance-tested. Compiler and terminal hashes are recorded separately in the machine receipt.

The initial archive-root harness refusal happened before compilation or tester execution; the single predicate correction preserved traversal/type guards. Its failed attempt remains visible. No duplicate B21 implementation/review lane or worktree was created for this resume. Previous failed-job build receipts were preserved before restoring only the exact generated append; source HEAD stayed unchanged/clean. Eight test EX5 files were restored to pre-run bytes; no primary install, Scheduled Task, service or runtime attachment was activated.

## Evidence and limits
Machine receipt: `portfolio/B21_SOURCE_ACCEPTANCE_20260918.json`. It pins the targeted review, compile-warning policy, runtime-parity result, full evidence manifest and verified normal-FF source push by SHA256. Source acceptance and state convergence are separate commits; future canonical HEAD must be freshly verified rather than inferred from this document.

The old `DF03_B21_TEMPLATE_INTEGRATION_20260916.md` and old compile/failure logs remain historical, not rewritten into a past PASS. No optimization, HOLDOUT, Candidate/Grade/KINT, Home/TF/settings freeze, runtime/deployment/trading permission or whole-pipeline acceptance follows. Broad production deployment still has its separate compile/runtime gates. The next B21 consumer is a separately frozen downstream preparation/experiment contract, not an automatic MT5 campaign.
