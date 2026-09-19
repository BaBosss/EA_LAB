# Hermes EA_LAB V2-B QUALIFIED_NO_MT5 acceptance — 2026-09-19

Status: **QUALIFIED_NO_MT5 / SOURCE_CANONICAL / NO_RUNTIME_CAMPAIGN_AUTHORITY**. Accepted and reviewed source: `2810be33fde22aac63c32ade37bc4fdf225146e2`; prospectively requalified technical source: `db1054d3e962bdfd6d37d27cef917a0df796b697`.

## Current accepted source-only qualification

The six accepted V2-B blobs at `2810be33fde22aac63c32ade37bc4fdf225146e2` are byte-identical to the prospectively reviewed technical source. Fresh prospective final gates passed with equal pre/post process sets, zero new MT5-family process identities and `mt5_started=false`. The preserved deterministic suites remain V2-B **30/30** and V2-A **83/83**. Normal commit hooks passed.

Separate read-only exact-head GPT Scrutiny returned `SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION` for the clean canonical child. Normal fast-forward source push was verified. This qualifies only the deterministic adapter source without starting MT5 during qualification.

## Historical blocker and repair budget remain binding history

The earlier acceptance-grade review of `db1054d3e962bdfd6d37d27cef917a0df796b697` remains `SCRUTINY_BLOCKED / HIGH / BLOCK_INTEGRATION`. Its frozen historical evidence did not contain the contract-required historical pre/post process-set binding for `terminal64.exe` and `MetaEditor64.exe`. That absence was an evidence-binding blocker, not a source defect or strategy failure.

The later prospective requalification generated new forward-looking process binding. It does not fabricate or rewrite the missing historical observation, turn the earlier review into a PASS, or reset the historical repair budget. Historical repair remains exactly **1/1_SPENT_NO_RESET**. The historical final disposition, blocker, technically green deterministic evidence and source-repair history remain preserved.

## Exact evidence bindings

Machine receipt: `portfolio/HERMES_V2B_QUALIFIED_NO_MT5_20260919.json`.

| Evidence | Location | SHA-256 |
|---|---|---|
| final canonical exact-head scrutiny | `D:\EA_LAB_CONTROL\evidence\ct-hermes-v2b-final-review-20260919\REVIEW_RESULT.json` | `088b749ff54f816c4d79b436dec7d9b6d5b04f2199acf3265f32df01726b139e` |
| normal FF push verification | `D:\EA_LAB_CONTROL\evidence\ct-hermes-v2b-final-child-20260919\PUSH_VERIFIED.json` | `b1fa54f81ef6597d976e72cba43efcd0117987e5106da30d62ec4ebf0de428af` |
| exact source freeze | `D:\EA_LAB_CONTROL\evidence\ct-hermes-v2b-final-child-20260919\FREEZE.json` | `a56d78d6379ff529a4417069db295c9e74fa1abd6502e9a69b58e68b1c732f85` |
| prospective final gates | `D:\EA_LAB_CONTROL\evidence\ct-hermes-v2b-final-child-20260919\FINAL_GATES.json` | `6d2d67034efc410c2a8f69574aa20714dc793c4d44ae0a586f66677757da7f1f` |
| historical blocked scrutiny | `D:\EA_LAB_CONTROL\evidence\ct-hermes-v2b-scrutiny-20260919\REVIEW_RESULT.json` | `f1e84a95cf28412c6c0a341dcdc40d7e1cd98a3e9943684230fff035fbcf94da` |
| historical blocked final disposition | `D:\EA_LAB_CONTROL\evidence\ct-hermes-v2b-scrutiny-20260919\FINAL_DISPOSITION_20260919.json` | `e3a14498aaa33e0d27b5a19352650ffebafe5be683a200076f75bae47a198ad1` |

## Authority ceiling

`QUALIFIED_NO_MT5` is a source-only classification. It creates no real tester campaign, MT5 execution authority, runtime/profile/provider/scheduler activation, EA/Home/timeframe/settings or parameter selection, strategy-performance evidence or interpretation, optimization, HOLDOUT, Candidate/Grade/KINT, risk/default change, deployment, DEMO/LIVE, trading, or whole-pipeline PASS. Any runtime campaign requires a separate prospective authorization and its own evidence gates.
