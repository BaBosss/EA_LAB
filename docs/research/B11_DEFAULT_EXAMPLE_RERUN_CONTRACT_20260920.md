# B11 Default Example Rerun Contract — 2026-09-20

Status: OWNER_AUTHORIZED / PROSPECTIVE / SAME_CONFIG_RERUN / PARSER_REPAIR4_ACCEPTED / NO_PROMOTION_AUTHORITY

## Purpose
Repeat the prior B11 example loop exactly after canonical MT5 report parser Repair4 acceptance, proving corrected end-to-end reporting through MAIN+BWD, deal/year/exposure diagnostics, native visuals, final report, independent GPT Scrutiny, and state closeout.

## Frozen identities
- canonical contract base: `629d9bfaf9fa5e25c5721539ba149420c36233ca`;
- accepted parser SHA256: `b2af79b9f694d1253137a559782db6f48a483a23a33caea7b68829f581e3b16b`;
- parser Repair4 review: `SCRUTINY_PASS / HIGH / ALLOW_INTEGRATION`, review SHA256 `8d25fc66054808c762fabd12bc919f6056cfd9e3305ccec81eecdaa7c5ef0826`;
- B11 source: `ea_template/Boss_11_GridTrend.mq5`, SHA256 `59c51ad12ecc0450c19bffa373f836a95c0c3fe6808a2029fcc946f28c29f672`;
- full default set: `ea_template/sets/regression/Boss_11_GridTrend_defaults.set`, SHA256 `5a0cdd3186e924234d4491bdf854966553214ebaaf03ca6793beaedd42ea8efa`.

No B11 parameter, risk/default, stack, direction, exit, lot, symbol/TF, window or tester setting may change from the first example.

## Fixed example contract
- carrier: XAUUSD/H1, EXAMPLE_ONLY, not Home authority;
- Model1 / 1 Minute OHLC;
- USD 10,000; leverage 1:100; Optimization=0;
- MAIN: 2023.01.01..2025.12.31;
- BWD: 2020.01.01..2022.12.31;
- BWD runs regardless of MAIN PF/net/DD;
- no retune after MAIN or BWD;
- HOLDOUT 2026H1 remains UNSPENT.

## Execution
Compile a fresh Build6090 B11 from the exact canonical source, create a fresh build receipt, back up the existing Meta5b B11 EX5, mirror the fresh EX5 only for the two serial tester runs, then restore the previous EX5 byte-for-byte in a finally path. Preserve raw reports, truncation/leverage evidence, parser JSON, native MT5 graph assets and run logs.

## Reporting
Derive year split and deal-path/exposure from the same immutable raw report ledgers; do not rerun MT5 for reporting. The final package must bind raw report hashes, parser output, build identity, INIs, graphs, year split, exposure, package manifest and a human-readable Evidence / Interpretation / Decision report.

## Outcome independence
Poor MAIN or BWD performance does not stop this rerun and creates no permission to retune. This rerun may close successfully as plumbing evidence even when strategy performance is weak.

## Authority ceiling
No optimization, BWD retune, Model4, Monte Carlo, HOLDOUT, Home ratification, Candidate/Grade/KINT, risk/default change, runtime/deployment, DEMO/LIVE or trading authority. Final package requires exact-head read-only GPT Scrutiny before canonical integration.
