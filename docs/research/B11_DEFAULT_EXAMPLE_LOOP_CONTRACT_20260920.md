# B11 Default Example Loop Contract — 2026-09-20

Status: OWNER_AUTHORIZED / EXAMPLE_ONLY / PROSPECTIVE / NO_PROMOTION_AUTHORITY

## Purpose

Prove one complete EA Template research plumbing loop from a frozen B11 default configuration through fixed MAIN and BWD execution, parsing, reporting, independent review, and durable closeout.

The owner explicitly authorized this example on 2026-09-20 and explicitly instructed the loop to continue to completion even if PF is poor or BWD fails. Performance is therefore an observed output, not a gate that stops the example.

## Frozen identity

- Family: B11 GridTrend.
- Canonical preregistration base: `7421a211dfab3d415c5c666c09d801e31d976dfd`.
- Source: `ea_template/Boss_11_GridTrend.mq5`.
- Source SHA256: `59c51ad12ecc0450c19bffa373f836a95c0c3fe6808a2029fcc946f28c29f672`.
- Full default set: `ea_template/sets/regression/Boss_11_GridTrend_defaults.set`.
- Set SHA256: `5a0cdd3186e924234d4491bdf854966553214ebaaf03ca6793beaedd42ea8efa`.
- Entry defaults of interest: FastMA=20, SlowMA=50, MAMethod=EMA(1), MA_TF=PERIOD_CURRENT(0), ATRPeriod=14.
- All other effective inputs are exactly the full declared default set; no selective cache inheritance is allowed.

A fresh Build6090 B11 binary and build receipt must be produced from the exact canonical source tree before execution. The resulting EX5/receipt identities are evidence, not strategy changes.

## Example carrier

- Logical/tester symbol: XAUUSD.
- Timeframe: H1.
- Deposit: USD 10,000.
- Leverage: 1:100.
- Tester model: Model1 / 1 Minute OHLC.
- Optimization: 0.

XAUUSD/H1 is an OWNER-AUTHORIZED EXAMPLE CARRIER selected only to complete one plumbing loop. It is NOT a B11 Home ratification, recommendation, optimized home, family default, or candidate selection.

## Windows and execution order

1. MAIN: 2023.01.01 through 2025.12.31.
2. BWD: 2020.01.01 through 2022.12.31.

BWD runs after MAIN regardless of MAIN PF, net, DD, trade count, or any research bar. A poor MAIN result does not stop this example. A poor BWD result does not trigger retuning.

If a mechanical safety cage truncates a window, the truncation is recorded as evidence and the loop continues to the next lawful stage; the cage is not weakened and the run is not repeated merely to obtain a better result.

## Example TestUniverse exception

The example universe is exactly one cell: `XAUUSD/H1`.

This is an explicit owner-authorized EXAMPLE_TEST_UNIVERSE for this one non-promotional loop. It does not create or substitute for canonical `factory/universe.jsonl`, and it grants no later execution authority to B11 or any other family.

## Outcome-independent closeout

The loop is complete when:
- the fresh B11 Build6090 identity is recorded;
- MAIN and BWD have each been attempted once under the frozen contract;
- reports and truncation/leverage evidence are preserved;
- metrics are parsed without changing the contract;
- a result document states exactly what happened, including failures;
- a separate exact-head GPT Scrutiny reviews the finished package;
- canonical state records the example as closed.

No PF threshold, BWD threshold, participation floor, or verdict bar controls whether this example continues. Those bars may be reported descriptively, but they do not promote or kill the family in this scope.

## Hard ceiling

Forbidden in this loop: optimization, parameter search, BWD retuning, Model4, Monte Carlo, HOLDOUT 2026H1, Candidate/Grade/KINT assignment, Home ratification, risk/default change, DEMO/LIVE, runtime attachment, deployment, trading, or owner attestation.

The only intended product is a truthful end-to-end example of the EA Template research conveyor.
