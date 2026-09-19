# ZL-EA-067 B22 source acceptance — 2026-09-19

Status: **SOURCE_ACCEPTED / REVIEWED / CANONICAL / REPO_ONLY / NO_PERFORMANCE_SCREEN**. Accepted and reviewed source: `57aed8a5235f871fcdaf198433dd66f2c4ebaa11`; immediate source parent: `5c85eba937968f80e558f11d583be85a2969c41e`.

## Accepted identity-only scope

The accepted identity is `B22 / LAB_ENTRY_22 / Boss_22_WickDisplacement`, with `_22_WickBodyRatio / P12200` and `_22_DisplacementBodyFraction / P12201`. It is an identity-only regeneration from the historical ZL technical lineage. Historical B20 ZL heads remain preserved and non-integratable under B20 because canonical DF02 GoldTimeBomb owns that identity.

The exact author allowlist contained 11 paths:

- `_triage/factory_os/wrapper_owners.csv`
- `docs/PARAM_LINKAGE.md`
- `docs/PARAM_REGISTRY.csv`
- `docs/research/ZL_EA_067_WICK_DISPLACEMENT_V0.md`
- `ea_template/Boss_22_WickDisplacement.mq5`
- `ea_template/core/InputSurface_gen.mqh`
- `ea_template/core/Inputs.mqh`
- `ea_template/core/LabCore.mqh`
- `ea_template/core/LockedConstants_gen.mqh`
- `ea_template/core/entries/Entry_WickDisplacement.mqh`
- `ea_template/tests/WickDisplacement_Test.mq5`

Normalized identity comparison preserved the exact Wick defaults and semantics: closed-bar shift2/shift1 mechanics, BUY/SELL mirror rules, defaults `2.0 / 0.65`, invalid-input/refusal behavior, `STACK_SINGLE / CONF_DISTANCE`, entry-only ownership, and independent-child/no-proprietary-fidelity provenance. B20 GoldTimeBomb and B21 GridFibo source ownership remained unchanged. Source repair usage was **0/1**; the available bounded source repair was not consumed.

## Deterministic, compile, regression and engineering-fixture evidence

Boss22 and `WickDisplacement_Test` compiled with **0 errors / 0 warnings**. Generated input/locked-constant surfaces, registry/linkage, wrapper registration, scaffold, collision/PID, B20-preservation, B21-cage and adversarial gates passed. Normal commit hooks passed.

Fixed adjacent B11-B18 comparison on one `D:\Meta 5b` portable Build 6090 lineage passed **8/8 exact** for net, PF, trade count and equity DD. Both arms used the frozen XAUUSD/H1, Model1, 2024-01-01 through 2024-07-01, USD 10,000, leverage 1:100 configuration. This is **regression-only evidence**; none of those numbers is a B22 strategy-performance result.

The pure nine-case Wick engineering fixture passed all nine named assertions and its green summary, with no failures. Its Model1 XAUUSD/H1 run and `AllowLegacyIdentity` switch were only an engineering carrier for the fixture. They do not select a Home, timeframe, settings, or performance claim.

## Review, canonical identity and evidence bindings

Separate read-only exact-head GPT Scrutiny returned exactly `SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION`, with no findings. Review identity was scope `B22_IDENTITY_ONLY_EXACT_HEAD_SCRUTINY`, author lane `ct-zl-ea-067-b22-identity-20260919`, reviewer lane `ct-zl-ea-067-b22-scrutiny-ro-20260919`, and reviewed head `57aed8a5235f871fcdaf198433dd66f2c4ebaa11`. The author and reviewer were separate contracts/worktrees, and the reviewer performed no source mutation. Normal fast-forward source push was then verified with canonical SHA `57aed8a5235f871fcdaf198433dd66f2c4ebaa11`.

Machine receipt: `portfolio/ZL_EA_067_SOURCE_ACCEPTANCE_20260919.json`. Exact external evidence locations and file SHA-256 bindings:

| Evidence | Location | SHA-256 |
|---|---|---|
| exact-head scrutiny | `D:\EA_LAB_CONTROL\evidence\ct-zl-ea-067-b22-scrutiny-20260919\REVIEW_RESULT.json` | `30650621e3756c2e4f2cbcfbd13fc101e76831390b9ba6abebfb2e51021d0cf5` |
| normal FF push verification | `D:\EA_LAB_CONTROL\evidence\ct-zl-ea-067-b22-scrutiny-20260919\PUSH_VERIFIED.json` | `8d40706d9b707f772df44e49f814964ea9c124ee3b310b3b8dceef234447d5f5` |
| identity author result | `D:\EA_LAB_CONTROL\evidence\ct-zl-ea-067-b22-identity-20260919\AUTHOR_RESULT.json` | `d4918c41b1ec671372f64d531c183002a8a70372915fc33f58368b40bd4c7591` |
| exact source freeze | `D:\EA_LAB_CONTROL\evidence\ct-zl-ea-067-b22-identity-20260919\FREEZE.json` | `0e7cddf6c17f4afa98fc81415446eb37c2c4726ebc1c2357406d0032d6bb3f5c` |
| normal commit hooks | `D:\EA_LAB_CONTROL\evidence\ct-zl-ea-067-b22-identity-20260919\COMMIT_HOOKS.log` | `67731ef22acecba1fbf558265e06376d526cbd79596c79068cdbe0f699b8fc5e` |
| adjacent regression-only result | `D:\EA_LAB_CONTROL\evidence\ct-b22-runtime-parity-20260919\RESULT.json` | `2f1c849a3bb3ad488e19148aabe55032f86bd68928c3c288cfd234824f00a3f6` |
| nine-case engineering fixture | `D:\EA_LAB_CONTROL\evidence\ct-b22-runtime-parity-20260919\WICK_FIXTURE_RESULT.json` | `9768c4db8ed413b0a4ba60d4022c5da2acea881c564f0ec63156d8686be758dd` |

## Authority ceiling

This closes source acceptance only. It creates no Strategy Catalog `E022`, no Home/TF/settings freeze, no B22 performance screen or conclusion, no optimization or BWD retuning, no HOLDOUT use, no Candidate/Grade/KINT, no risk/default change, and no runtime attachment, deployment, DEMO/LIVE, trading, or whole-pipeline authority. Any performance research or runtime transition requires its own later prospective contract and gates.
