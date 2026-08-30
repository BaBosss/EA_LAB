# BT0 - H02 Pulse Model-4 Execution-Fidelity Confirmation

Status: `PREREGISTERED / EXECUTION_BLOCKED`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `b26af204faf7907fe7e78a2b5f90a5dfa8c6bc02`
Owner scope: `BT-20260830`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Question

Do the six accepted H02 Model-1 screening pulses remain materially present when the exact same EA/configuration is executed on the repository-approved Model-4 / real-tick path?

This is an execution-fidelity confirmation only. It is not optimization, strategy redesign, rescaling, normalization, Candidate selection, deployment, DEMO/LIVE, or risk/default authority.

## Frozen tester contract

- MAIN: `2023.01.01..2025.12.31`
- BWD: `2020.01.01..2022.12.31`
- Deposit: `10000 USD`
- Leverage: `1:100`
- Model: `4`
- Optimization: `0`
- Forward: `NO`
- HOLDOUT 2026H1: `UNSPENT`
- Parameter changes: `NONE`
- Symbol/TF-specific rescaling: `NONE`

## Frozen identities

H02 reuses H01 revision identities. B13/B15 use the exact accepted H01 proposed set bytes; B16 uses the accepted 173/173 tester materialization.

| Revision | Expert | EX5 SHA256 | Frozen config identity |
|---|---|---|---|
| `B13-H01-r1` | `EALabTpl\Boss_13_MeanRev` | `23daca942b38ccb2927d4674471b69392fc445ee306d09d959350675e5408a06` | proposed set SHA256 `65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6` |
| `B15-H01-r1` | `EALabTpl\Boss_15_ST03` | `f3dd7c5f2e2c1eb5a9f30a95a120e8977aa071e86f5ea4d9929e84f74940803a` | proposed set SHA256 `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c` |
| `B16-H01-r1` | `EALabTpl\Boss_16_KangarooGrid` | `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db` | full tester set SHA256 `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`; accepted H02 effective TesterInputs SHA256 `19013c650622e379551efff2cfa4ba6f860b37fff78c766b99621bd80f7e3272` |

Identity sources: `docs/factory/BOSS11_16_H01_TESTER_CONTRACT.md`, `docs/factory/BOSS11_16_H01_FIXED_BASELINE_RESULTS.md`, `docs/factory/BOSS11_16_H02_LITERAL_PORTABILITY_CONTRACT.md`, and `docs/factory/B16_H03_CONFIRMATION_RESULTS.md`.

## Intended 12-cell manifest

| Cell | EA | Symbol | TF | Window | Requested lane | Model |
|---:|---|---|---|---|---|---:|
| 1 | B16 | XAUUSD | H4 | MAIN | BT-A / Meta5b | 4 |
| 2 | B16 | XAUUSD | H4 | BWD | BT-A / Meta5b | 4 |
| 3 | B16 | USDJPY | H1 | MAIN | BT-A / Meta5b | 4 |
| 4 | B16 | USDJPY | H1 | BWD | BT-A / Meta5b | 4 |
| 5 | B16 | XAUUSD | M15 | MAIN | BT-A / Meta5b | 4 |
| 6 | B16 | XAUUSD | M15 | BWD | BT-A / Meta5b | 4 |
| 7 | B15 | GBPUSD | H4 | MAIN | BT-B / Meta5c | 4 |
| 8 | B15 | GBPUSD | H4 | BWD | BT-B / Meta5c | 4 |
| 9 | B13 | XAUUSD | M15 | MAIN | BT-B / Meta5c | 4 |
| 10 | B13 | XAUUSD | M15 | BWD | BT-B / Meta5c | 4 |
| 11 | B13 | GBPUSD | H4 | MAIN | BT-B / Meta5c | 4 |
| 12 | B13 | GBPUSD | H4 | BWD | BT-B / Meta5c | 4 |

MAIN and BWD of one experiment pair must remain on one install. Within a runtime lane cells are sequential. No cell may substitute a different EA/configuration if its frozen identity cannot be proven.

## Mechanical acceptance per executed cell

Require all of the following independently from strategy performance:

- exact intended EA/config identity;
- expected logical/tester symbol;
- expected TF and exact dates;
- Model `4`;
- Optimization `0` and Forward `NO`;
- leverage `1:100` where the report supports verification;
- fresh report provenance and report SHA256;
- explicit stale-report rejection;
- explicit truncation check;
- explicit full-window eligibility;
- no HOLDOUT date;
- no unauthorized parameter difference.

Poor PF or negative net is strategy evidence, not mechanical failure and is not a reason to rerun.
## Canonical runtime preflight result

Execution is fail-closed before MT5 launch.

Current canonical `AGENTS.md` binds:

- lane1 to `D:\Meta 5` and requires Model 4 to run serial on lane1 only;
- lane2 to `D:\Meta 5b` for portable Model-1 work;
- lane3 to `D:\Meta 5c`, explicitly with no tick cache and a prohibition on Model 4;
- Model 4 must not run concurrently with any tester work.

The owner-approved BT-20260830 scope separately says `DO NOT USE D:\Meta 5` and forbids attaching to or reusing that runtime.

Therefore there is no runtime that simultaneously satisfies current canonical Model-4 policy and this lane's owner-approved runtime boundary. Meta5b/Meta5c cannot be used to bypass canonical policy, and lane1 cannot be used to bypass the owner scope.

`BT0_EXECUTION_STATUS = BLOCKED`
`BLOCKER_CLASS = E OWNER/EXTERNAL`
`RUNS_EXECUTED = 0/12`

Unblock requires a prospective owner/canonical resolution of the runtime-policy conflict. This contract does not itself change `AGENTS.md`, runtime ownership, or the approved `D:\Meta 5` prohibition.

## Authority ceiling

Research-only preregistration and evidence recording. No HOLDOUT, optimization, Candidate/DEMO/LIVE authority, deployment, runtime attach/detach, production risk/default change, KINT resolution, grade mapping, force push, or history rewrite.
