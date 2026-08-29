# Boss11-16 H01 Tester Contract

Status: PREPARED / FAIL-CLOSED ON DATE PINS
Canonical reviewed build: `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125`
Authority: `NON_AUTHORITATIVE_SIDECAR`; no optimizer, HOLDOUT, deployment, DEMO/LIVE, risk/default, or candidate-promotion authority.

## Fixed identities already resolved

The accepted template regression manifest `ea_template/regression_baseline_build6090.manifest.json` binds Boss11-18 to the common tester identity `XAUUSD / H1 / Model 1`, deposit `10000 USD`, leverage `1:100`. Lane H reuses that accepted identity rather than inventing a new symbol or timeframe.

Runtime allocation for this H01 fixed-baseline pass:
- Meta5b / lane2: `B16-H01-r1` then `B12-H01-r1`.
- Meta5c / lane3: `B11-H01-r1` then `B13-H01-r1` then `B15-H01-r1`.
- Meta5c must never run Model 4. One job at a time per lane. Lane1 remains outside this contract.

## Canonical build receipts
| Revision | EX5 SHA256 | Proposed set SHA256 | Build receipt |
|---|---|---|---|
| B11-H01-r1 | `2708f46cb31f6c957be360b31e0f2be5678d78280c5bd0f691313d26802c00af` | `5a0cdd3186e924234d4491bdf854966553214ebaaf03ca6793beaedd42ea8efa` | `br-0035caa23680498a8f812c18c9df0abc` |
| B12-H01-r1 | `c4fef86203803165675063074e04fd1560a970c64a12eaa53125c1569a6de3a9` | `62ffa4e95a08a483617046694309a8082c1d07bece39a778704f67cb389626c1` | `br-c65dbb2519f84815adb3cfe950e80bc5` |
| B13-H01-r1 | `23daca942b38ccb2927d4674471b69392fc445ee306d09d959350675e5408a06` | `65f3d4287effd5cf821bac6fff5f123eb17430608f32e9bfa5853216d053d9a6` | `br-a2740eb18db349a58c3aa177b45389e6` |
| B15-H01-r1 | `f3dd7c5f2e2c1eb5a9f30a95a120e8977aa071e86f5ea4d9929e84f74940803a` | `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c` | `br-58971201f0774c47bf5e6f423c47e1bc` |
| B16-H01-r1 | `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db` | `54d584ce3709b2cac478b872edc50c6f39fe254bd50812424443cdefb691e870` | `br-4fa94d22907b446ebc721d524bdfa5d1` |

All five builds were compiled from pushed canonical bytes on Meta5b at 0 errors / 0 warnings. The managed `EALabTpl` mirror on Meta5c was then hash-checked byte-for-byte against Meta5b for all five EX5 artifacts.

## Date-pin blocker

Do not run MAIN or BWD yet. Current canonical policy says MAIN is a rolling 36-month window and must not spend HOLDOUT, but the H01 preregistration does not pin exact MAIN/BWD dates. Historical orders frequently use `2023.01.01-2025.12.31` and `2020.01.01-2022.12.31`; those are evidence examples, not sufficient authority to silently bind this new H01.
A tester dispatcher may proceed only after an exact canonical date contract exists for BOTH windows. Once bound, use the same install for MAIN+BWD for each result, preserve the fixed H01 set, use Model 1, and record logical/actual symbol, timeframe, exact window, install/lane, build receipt, EX5/set/report SHA256, history quality, PF, trades, net, equity DD, truncation/full-window eligibility, and mechanical status.

HOLDOUT remains UNSPENT. No search, optimization, sensitivity, Model 4, or promotion is authorized by this contract.

## Reference evidence

- `ea_template/regression_baseline_build6090.manifest.json` — accepted common tester identity and regression surface.
- `factory/vnext/pilots/boss11_h01_first_green` through `boss16_h01_first_green` (excluding B14) — frozen H01 proposed sets and artifact indexes.
- Lane H exact-head review: Claude Sonnet 5 PASS at `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125`, required repair NONE.
- External execution receipts: `D:\EA_LAB_CONTROL\handoffs\LANE_H_BUILD_RECEIPTS_5B_cf32ba8d.jsonl` and `LANE_H_TESTER_PREP_cf32ba8d.json`.
