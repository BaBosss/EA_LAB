# ORDER-091C-D1g — dataset provenance descriptor (for event-log `data` artifact hash)

> **Why this file exists (event-log dogfood rough-edge #1):** the Contract-D schema requires all five
> `artifact_hashes` (ea/source/set/data/tester) as raw sha256 from `BAR_PREREGISTERED` onward. For an
> MT5 every-tick backtest the *dataset* is broker-generated tick/M1 history living inside the terminal's
> data folder — **not a committed git artifact and not stably hashable** (it regenerates per broker/feed).
> Resolution: `data` = sha256 of THIS committed descriptor, which is the reproducible fingerprint of the
> dataset actually used (symbol · TF · window · server · model). This keeps `data` meaningful + committed
> without pretending a multi-GB broker tick cache is a versioned artifact. → fold this convention into
> `docs/memory_control/EVENT_LOG_ADOPTION.md` for future MT5 experiments.

## Dataset fingerprint

| field | value |
|---|---|
| platform | MetaTrader 5 (terminal `D:\Meta 5\terminal64.exe`, data dir `9CA16B8382AE4CF692710FB36B9DA355`) |
| symbols | EURGBP (primary), NZDUSD (secondary) |
| timeframes | EURGBP H1 · NZDUSD H4 |
| A/B model | **Model 4 (every tick, real ticks)** — mandatory: pending-limit fills are tick-path-sensitive |
| cage model | **Model 1** (matches the 07-11 D1f reference run for byte-identical baseline comparison) |
| windows | recent = 2023.01.01–2026.07.01 · BWD = 2020.01.01–2022.12.31 (each a CONTINUOUS span — grid EA) |
| deposit / leverage | 10000 USD / 1:100 |
| account margin mode | RETAIL_HEDGING (JUMSTOCH OnInit FATAL otherwise — 4 opposing baskets) |
| history source | broker-recorded ticks/M1 in the terminal data folder (NOT a git artifact — hashed via this descriptor) |

## Reference baseline being reproduced (regression cage target)

07-11 D1f run `JUMT5OOS_EURGBP_H1_OOS` — Model 1, empty TesterInputs (compiled defaults),
window 2025.03.01–2026.07.01 → OOS PF 1.34 / 869 trades. Cage = new `(EXP)_JUMSTOCH_Pending` with
`EntryMode=0, TP_Widen_Pips=0` on the identical config must match this within tick-noise; a mismatch =
refactor drift → stop and fix before trusting any A/B number.
