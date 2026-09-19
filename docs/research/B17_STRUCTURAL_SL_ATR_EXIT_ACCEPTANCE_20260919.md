# B17 structural SL / ATR exit source acceptance — 2026-09-19

Status: **SOURCE_ACCEPTED / REVIEWED / CANONICAL / REPO_ONLY / NO_PERFORMANCE_SCREEN**. Accepted and reviewed source: `2a1c8587a294380752ba3f48b478ab486504dec3`; B17 implementation source: `eff567e2675458090037d566ab78f9180225eb4e`; canonical composition parent: `2810be33fde22aac63c32ade37bc4fdf225146e2`.

## Accepted source behavior

The accepted six-path B17 change preserves source-native Wave-1 structural invalidation SL. `EXIT_ATR_TP` no longer takes ownership from B17 structural TP and reaches the existing generic ATR TP calculation. `EXIT_FIXED_TP` and `EXIT_STRUCTURAL_TARGET` preserve legacy structural-target behavior; TRAIL and RUN_TREND preserve their no-hard-structural-TP behavior. `_2_SuppressLegTP` remains the first precedence return, and the existing `STACK_SINGLE`, Recovery OFF and Hedge OFF structural-mode guards remain unchanged.

`Entry_Wave5.mqh`, `Inputs.mqh`, `Boss_17_Wave5.mq5`, inputs/defaults, and every tracked strategy surface outside the frozen six-path allowlist are byte-identical to the canonical control. Effective-config reporting truthfully separates structural SL active, structural TP override inactive and generic ATR Exit active. The parameter registry/linkage changes only the stale B17 TP-override description.

Focused positive and adversarial source checks, parameter registry/linkage/surface gates, and normal commit hooks passed. Reanchored Boss17 and the B17 fixture compiled at 0 errors / 0 warnings. Source repair usage is **0/1**.

## Engineering fixture and unaffected adjacent regression

The engineering fixture returned `PASS` and binds source, EX5, fresh journal and report hashes. Its XAUUSD/H1 Model1 invocation and `AllowLegacyIdentity` are engineering-carrier evidence only; the fixture is not a strategy-performance test and selects no Home, timeframe or settings.

The original adjacent-regression result and attempt2 `BLOCKED` / exit99 records remain preserved. Exact-head scrutiny traced attempt2's false concurrent-mutation classification to the external harness searching attempt2 build directories while the scoped compiler used the parent-root build tree. The final reviewer independently verified the unchanged comparator, exact source gate, freshness, Build6090, same-install, report-contract, build-receipt and restoration controls; reparsed all 14 reports; and reconciled unaffected B11-B16/B18 as **7/7 exact** on the single `D:\Meta 5b` lineage. B17 was intentionally excluded from metric parity. This is adjacent regression-only evidence, not a B17 performance result and not a rewrite of the preserved blocked harness receipts.

## Exact-head review and canonical source

Separate read-only GPT Scrutiny reviewed clean exact head `2a1c8587a294380752ba3f48b478ab486504dec3` and returned `SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION` with no findings. All six B17 blobs match implementation source `eff567e2675458090037d566ab78f9180225eb4e`; all six neighboring Hermes blobs match canonical parent `2810be33fde22aac63c32ade37bc4fdf225146e2`. Normal fast-forward source push was verified at the reviewed head.

Machine receipt: `portfolio/B17_STRUCTURAL_SL_ATR_EXIT_ACCEPTANCE_20260919.json`. Exact evidence bindings:

| Evidence | Location | SHA-256 |
|---|---|---|
| exact-head scrutiny | `D:\EA_LAB_CONTROL\evidence\ct-b17-scrutiny-20260919\REVIEW_RESULT.json` | `e74b6080423a7bfe455ae2c7606f5f2750e3806317bd107260b4d084b89e5f0c` |
| normal FF push verification | `D:\EA_LAB_CONTROL\evidence\ct-b17-scrutiny-20260919\PUSH_VERIFIED.json` | `94c49d343777d86b7adf37145f59e037dad8008623b8803816935cae4d5e2daf` |
| author checks | `D:\EA_LAB_CONTROL\evidence\ct-b17-structural-sl-decouple-20260919\AUTHOR_CHECKS.json` | `2c8e99dfaa31fffec57fd81cfadf93ac53b07757ed1d157567c72f2ed581626a` |
| implementation freeze | `D:\EA_LAB_CONTROL\evidence\ct-b17-structural-sl-decouple-20260919\FREEZE.json` | `ffcc702270c7f4fa19f77b3d3656083f349999f423c76bc19edf7a6ce882b91e` |
| canonical reanchor | `D:\EA_LAB_CONTROL\evidence\ct-b17-structural-sl-decouple-20260919\REANCHOR_RESULT.json` | `016dd5ba344fb23c631403e7a0a65134c24ca762acd111650af70509a0f24186` |
| normal commit hooks | `D:\EA_LAB_CONTROL\evidence\ct-b17-structural-sl-decouple-20260919\COMMIT_HOOKS.log` | `9a01a11ed9d4990e918d4faa09ec584a5171a275703147b5f05e8e6faf515dfd` |
| engineering fixture | `D:\EA_LAB_CONTROL\evidence\ct-b17-engineering-validation-20260919\FIXTURE_RESULT.json` | `596585d11b46457fee28fe5011a4b7dc27b7eb254b46d722d7004af41973278e` |
| preserved attempt2 result | `D:\EA_LAB_CONTROL\evidence\ct-b17-adjacent-regression-20260919\attempt2\RESULT.json` | `1d699f8ae4c6587e1070c6a4a8d53959853250ba6fc54c4afc006e93edfec808` |
| preserved attempt2 execution | `D:\EA_LAB_CONTROL\evidence\ct-b17-adjacent-regression-20260919\attempt2\EXECUTION.json` | `8e7cc8b833ff826e491f895aefccc0b3f08b7852db8827d26cd5ad152db32636` |
| harness correction record | `D:\EA_LAB_CONTROL\evidence\ct-b17-adjacent-regression-20260919\attempt2\HARNESS_CORRECTION.json` | `3e584cdb80b55b02de7f4475a013fdee85f7c8c2bfda0ed9c954427259094f73` |

## Authority ceiling

This closes source acceptance only. It grants no Home/TF/settings freeze, H01 inheritance, strategy-performance evidence or verdict, performance screen, optimization, HOLDOUT use, Model4, Candidate/Grade/KINT, risk/default change, runtime activation, deployment, DEMO/LIVE, trading, structural-target ratification, or whole-pipeline PASS. The direct consumer is a prospective owner B17 parameter/Home ratification; any later fixed MAIN+BWD screen requires a separate contract.
