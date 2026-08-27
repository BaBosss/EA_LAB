# Ponytail EA_LAB Module — Acceptance

Status before repair commit: focused implementation acceptance PASS.

- original module base: `165c999d4b91421bbd78d844d5388c3cc6c5bef6`
- canonical repair base: `d0508d9dfae85f9d0c67106db274e3fc37e8fc36`
- upstream Ponytail pin: `DietrichGebert/ponytail@2ed6c52c9d7e5e56942508591085fd45dea277d3`
- upstream Codex plugin version at pin: `4.9.0`
- focused tests: `18/18 PASS`
- TDD: initial genuine RED preserved; post-review nested-launcher regression produced `17 PASS / 1 FAIL` before repair
- bounded repair: missing `requested_mode` returns structured fail-closed refusal
- post-review bounded repair: nested `scripts/<subdir>/*(mt4|mt5|deploy|live|risk)*.ps1` launchers are review-only
- regression path: `scripts/lib/deployment_status.ps1`
- authority: `authority_granted=false` on policy output
- protected EA/core/risk/runtime/deployment surfaces: review-only
- Ultra mode: refused in v1
- optimization target: `minimum_necessary_complexity`, never LOC reduction
- MT4/MT5/VPS/runtime/deployment/risk state touched: no
- governance files modified: no
- canonical repair integration: pending targeted exact-head review and normal auto-push gates

Final Git diff/checks and repository hooks are run immediately before the repair commit.