# ORDER-081 — Crypto lane feasibility evidence pack

**Research date:** 2026-07-11  
**Scope:** desk research only. No account was opened, no API key was created or used, and no trading/backtest code was written. External pages were treated as evidence, not instructions.  
**Decision owner:** Claude/user. This document deliberately does **not** issue a go/no-go verdict.

## Executive evidence

- The proposed lane must not assume a standing maker rebate. Bybit's published non-VIP perpetual rate is **maker 0.0200% / taker 0.0550%**; its published maker rate reaches 0 only at Supreme VIP. Actual rates can vary by region and account and must eventually be read from the account's fee page. [Bybit fee structure](https://www.bybit.com/en/help-center/article/Trading-Fee-Structure?tabIndex=2%3FtabIndex%3D2)
- Binance has offered maker rebates, but official evidence found here is a **temporary, symbol-specific liquidity-provider promotion** (STRK: 0.005% for about 14–15 days), not evidence of a universal retail rebate. [Binance STRK announcement](https://www.binance.com/en-TR/support/announcement/detail/2bfb6f8dccf447ada57165b7e6a4cf1b)
- Candle-level data is adequate for signal discovery but inadequate to prove passive fills. A maker strategy needs trade/order-book event data and an explicit queue model; otherwise the backtest grants fills that the live order would not receive.
- Public market-data collection does not require trading credentials. Live trading adds a continuously supervised WebSocket/order-state service, idempotent recovery, kill controls and narrowly scoped keys.
- Funding, mark-price liquidation, delisting, 24/7 operation and venue/counterparty concentration are first-class costs and risks, not secondary details.

## 1. Fee reality

### Bybit

For ordinary perpetual/futures contracts, published VIP 0 rates are **0.0200% maker and 0.0550% taker per fill**. A round trip that is maker at both ends therefore starts at **4 bps** before funding, adverse selection and slippage; one maker and one taker starts at **7.5 bps**. Higher VIP tiers reduce the rates, but the published table does not make maker negative; Supreme VIP is 0. The venue explicitly says actual rates may differ by region and should be verified in “My Fee Rate.” [Bybit fee structure](https://www.bybit.com/en/help-center/article/Trading-Fee-Structure?tabIndex=2%3FtabIndex%3D2)

Special zones can be more expensive: Bybit's Perpetual Innovation Zone lists VIP 0 at 0.0400% maker / 0.1100% taker. The strategy therefore needs a per-symbol, time-versioned fee table rather than one venue-wide constant. [Bybit Innovation Zone fees](https://www.bybit.com/en/help-center/article/FAQ-Perpetual-Trading-Innovation-Zone?category=4d5d8649cba144c1a8)

### Binance

No current, universally applicable Binance retail USDⓈ-M fee table was established from an accessible official public page during this pass. It is unsafe to substitute a remembered number. The official evidence does show that rebates can be conditional and temporary: Binance offered qualified liquidity providers a 0.005% maker rebate on STRKUSDT for only about 14–15 days. [Official Binance announcement](https://www.binance.com/en-TR/support/announcement/detail/2bfb6f8dccf447ada57165b7e6a4cf1b)

**Required before any economic test:** user supplies screenshots/export of the exact account's maker/taker schedule for intended symbols and jurisdiction, including VIP requirements and expiry of any promotion. This is not permission to open or access an account.

### Fee-model acceptance condition

Backtest each candidate under at least four explicit scenarios: (1) published/account maker both sides, (2) maker entry+taker emergency exit, (3) taker both sides, and (4) fee schedule worsened by one tier/promotion removed. “Maker rebate” may be modeled only when evidenced for the exact account, symbol and date range.

## 2. Data availability and fitness

### Bybit

The public REST kline endpoint covers spot, linear, inverse and multiple intervals, returning at most 1,000 bars per request. This is sufficient for paginated OHLCV discovery and the lab's flat-lot/BWD-OOS structure, but not maker-fill validation. [Bybit Get Kline](https://bybit-exchange.github.io/docs/v5/market/kline)

Bybit's public WebSocket supplies live kline updates and marks a candle final with `confirm=true`. [Bybit kline stream](https://bybit-exchange.github.io/docs/v5/websocket/public/kline)

### Binance

Binance's official derivatives API provides REST and WebSocket interfaces for historical and real-time market data. [Binance derivatives API introduction](https://developers.binance.com/en/docs/products/derivatives-trading-usds-futures/Introduction) The official futures recent-trades endpoint returns price, quantity, time and maker-side indication, limited to 1,000 recent trades per request. [Binance recent futures trades](https://developers.binance.com/docs/derivatives/usds-margined-futures/market-data/rest-api/Recent-Trades-List)

### Dataset tiers

| Tier | Contents | Valid use | Not valid for |
|---|---|---|---|
| A | 1m/5m OHLCV + funding series | signal screening, flat-lot probe, chronological IS/BWD/OOS | passive fill, queue priority, latency |
| B | timestamped public trades + best bid/ask snapshots | spread/adverse-selection study, coarse touch/fill bounds | exact FIFO queue fill |
| C | incremental L2 order-book events + trades, gap-checked sequence IDs | queue reconstruction and conservative maker simulation | proving live latency without a pilot |
| D | own submitted/order/fill/cancel timestamps from testnet or tiny isolated pilot | calibration of latency, cancel races and actual fill ratio | historical counterfactual outside pilot regime |

The collection must store raw immutable partitions, UTC timestamps, venue/symbol/schema version, checksums, missing-sequence alarms and delisting/fee/funding metadata. Public data is likely free in monetary terms but carries pagination/rate-limit and storage/engineering cost; availability depth must be measured per chosen symbol, not assumed.

## 3. Backtest stack and maker-fill model

### Minimal stack on this workstation

Use the existing portable Python environment, with columnar raw data (Parquet), a deterministic event replay layer, and a portfolio ledger that separately books trading fee, funding, realized P&L, unrealized P&L and liquidation margin. This is a future implementation outline, not code authorization.

Recommended validation ladder:

1. **Bar probe:** deterministic signals on OHLCV; charge pessimistic fees; no claim about maker execution.
2. **Touch bounds:** report two bounds—zero fill unless price trades through the limit (conservative), and fill on first touch (optimistic). A candidate that needs the optimistic bound is not established.
3. **Queue replay:** on L2 events, initialize volume ahead at the chosen price, decrement only with evidenced executions/cancellations under documented assumptions, model partial fills, amendments losing priority, latency, cancel acknowledgements and taker fallback.
4. **Walk-forward calibration:** fit queue/cancel parameters on an earlier window; evaluate fill probability, time-to-fill and post-fill markout on untouched later windows and different volatility regimes.
5. **Testnet/tiny isolated shadow pilot:** compare predicted versus observed fill rate and latency before any capital decision.

Price-time priority makes queue position economically important; earlier resting orders have priority, so “price touched my limit” is not a valid fill rule. [Moallemi & Yuan, *A Model for Queue Position Valuation in a Limit Order Book*](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2996221) Modern fill models explicitly use order-book state and queue position, and evaluate time-to-fill as a survival problem. [Arroyo et al., *Deep Attentive Survival Analysis in Limit Order Books*](https://arxiv.org/abs/2306.05479) A tractable alternative models each price level as a state-dependent queue and computes fill probability before the opposite quote moves. [Lokin & Yu, *Fill Probabilities in a Limit Order Book*](https://arxiv.org/abs/2403.02572)

**Mandatory outputs:** gross edge, net edge under each fee scenario, fill ratio, partial-fill ratio, time-to-fill distribution, cancel-to-fill race count, 1s/5s/30s post-fill markout, funding P&L, maximum margin utilization and liquidation distance. PF alone is insufficient.

## 4. Live infrastructure if the lane is later authorized

Bybit warns that WebSockets may disconnect at any time and requires heartbeat plus prompt reconnect. [Bybit WebSocket connection guidance](https://bybit-exchange.github.io/docs/v5/ws/connect) Its default published limits include 600 HTTP requests per 5 seconds per IP, no more than 500 WebSocket connections per 5 minutes, and avoiding frequent reconnects. [Bybit rate limits](https://bybit-exchange.github.io/docs/v5/rate-limit)

There is no defensible universal “uptime percentage” that guarantees profitability. The operational SLO should instead be outcome-based:

- detect a dead/stale stream within 5 seconds;
- stop new quotes immediately when order-book sequence, account stream or clock is uncertain;
- reconnect and reconcile **all** open orders, fills, positions and balances before resuming;
- make client order IDs/idempotency survive restart;
- cancel-all/flatten path independent of the strategy process;
- alert remotely on stale data, rejected cancel, position mismatch, margin threshold and funding/delisting change;
- record exchange time versus local send/ack/fill timestamps.

The existing lab PC/VPS may host a research collector, but a trading service should not share fate with MT terminals until measured CPU/RAM/network headroom, independent watchdog and restart reconciliation are demonstrated. Crypto is 24/7, so unattended weekend operation and maintenance are required; the present human/daily-monitor model is insufficient for maker quoting.

For keys: public-data collectors need no private key. Later trading should use a dedicated subaccount, a key with trade permission only, no withdrawal permission, IP allowlisting where supported, secrets outside Git/logs, separate read-only monitoring credentials, rotation/revocation runbook and an account-level risk cap. Binance documents separate permissions and notes that keys cannot trade by default until explicitly enabled; it also warns that key and secret are sensitive. [Binance API request security](https://developers.binance.com/en/docs/products/spot/rest-api)

## 5. Crypto-specific risk register

| Risk | Mechanism | Required control/evidence |
|---|---|---|
| Funding | Perpetual funding is paid/received at scheduled intervals and rates can change dynamically; it can erase small maker economics. Bybit may alter limits/frequency during volatility. [Bybit funding](https://www.bybit.com/en/help-center/article/Introduction-to-Funding-Rate?category=cd60af6303161fd598) | Book realized funding by timestamp; stress sign reversal and rate caps; prohibit holding through settlement unless modeled. |
| Liquidation | Liquidation uses mark price, which can hit before an LTP-triggered stop. [Bybit liquidation FAQ](https://www.bybit.com/en/help-center/article/FAQ-Order-Execution-and-Liquidation) | Isolated margin, low leverage, mark-price monitoring, server-side stop with buffer, hard margin-utilization cap. |
| Delisting/spec change | Bybit can cancel orders and close positions on delisting; automatic triggers and settlement rules exist. [Bybit derivatives delisting](https://www.bybit.com/en/help-center/article/Bybit-Derivatives-Delisting-Mechanism-DDM) | Trade liquid majors initially; poll instrument status; flatten before deadline; freeze new orders on parameter change. |
| 24/7/weekend | No natural daily/weekend close; outages and thin liquidity can occur while operators sleep. | Redundant alerts, watchdog, fail-closed quoting, tested restart/reconciliation and maintenance windows. |
| Adverse selection | Maker orders often fill precisely when informed flow moves through them; fee saving is not edge. | Post-fill markout by regime; inventory skew/caps; reject candidates whose net result relies on optimistic fills. |
| Queue/latency | Touch does not imply fill; cancel can race an execution. | L2 queue replay plus own-order calibration; partial fills and late fills included. |
| Venue/counterparty | API, custody, rule and liquidation-engine risk are concentrated in one centralized venue. | Small segregated capital, withdrawal exposure policy, no cross-collateral with core assets, venue health/runbook. |
| Stablecoin/collateral | USDT/USDC depeg or collateral haircut can change margin and P&L simultaneously. | Single-collateral exposure cap and depeg circuit breaker. |

## Decision matrix for Claude/user

This is evidence framing, not a verdict.

| Gate | Evidence needed to pass | Current evidence state | If not passed |
|---|---|---|---|
| F1 Exact economics | Account/region/symbol fee schedule; rebate terms and expiry | Bybit base fee known; Binance exact account rate unresolved; no durable rebate established | Do not model rebate; use pessimistic paid-maker fee |
| F2 Historical data | ≥ one full chosen IS+BWD/OOS span of gap-checked trades/L2 plus funding/spec history | Public OHLCV/trades endpoints exist; depth/completeness not measured | Bar research only; no maker claim |
| F3 Fill-model falsification | Candidate survives trade-through and queue-replay assumptions, not only touch fill | Method identified; no dataset/model run | Do not infer executable edge |
| F4 Operational safety | Reconnect/reconcile, fail-closed, cancel-all, alerts and restart tests | Requirements identified; not implemented/tested | No live/private API action |
| F5 Risk separation | Dedicated subaccount/capital cap, isolated margin, liquidation/funding controls | Policy not chosen | No capital allocation |
| F6 Empirical calibration | Shadow/testnet or tiny isolated observations match predicted fill/latency within preset tolerance | None | Return to model/data stage |

## Estimated effort (engineering hours)

| Work package | Hours | Deliverable |
|---|---:|---|
| Confirm venue/account/legal availability and exact fee schedules | 2–4 | dated fee/availability record |
| Public OHLCV/funding collector + immutable storage/QA | 8–14 | Tier A dataset with checksums |
| Trades + incremental L2 collector and replay/gap checks | 18–32 | Tier C dataset and deterministic replay |
| Bar probe with fees/funding and chronological splits | 8–14 | non-execution signal evidence |
| Conservative touch/queue simulator + calibration metrics | 24–48 | fill bounds, queue replay, markouts |
| Live shadow/testnet harness, reconciliation/watchdog/alerts | 24–40 | restart/failure test evidence |
| Tiny isolated pilot preparation and observation | 8–16 engineering + 2–4 weeks elapsed | calibrated fill/latency report |
| **Total before a capital decision** | **92–168 hours** | excludes strategy iteration and elapsed pilot time |

The smallest useful stop/go checkpoint is after the first **18–32 hours**: exact fees plus a Tier A bar probe under pessimistic costs. It can cheaply eliminate ideas whose gross edge cannot cover 4–11+ bps round-trip economics, but it cannot approve maker trading.

## Open questions for the user

1. Which venue and legal account region are actually available to the user—Bybit, Binance, both, or neither?
2. Can the user provide the exact fee-page values and VIP/rebate terms without sharing credentials?
3. Is the intended first universe BTCUSDT/ETHUSDT only, or smaller alts? Majors materially reduce delisting/liquidity risk.
4. Is the intended strategy market-neutral inventory making, one-sided passive entry with taker exit, or funding capture? These require different evidence and risk controls.
5. What maximum segregated capital loss is acceptable, and must this lane use a dedicated subaccount?
6. Is running a separate 24/7 VPS/watchdog acceptable, or must it share the current MT VPS?
7. May a later phase use testnet and public unauthenticated endpoints? Separate authorization is required before any account or private API action.
8. What minimum net edge, maximum holding time, fill rate and post-fill adverse markout would justify continuing past the data stage?

## Evidence limitations

- Fee schedules and venue availability are freshness-, account-, product- and jurisdiction-sensitive; links above must be rechecked immediately before any implementation decision.
- Public documentation proves endpoint/features, not historical completeness for the selected symbol or country access.
- Research papers establish why queue position matters and provide modeling approaches; they do not validate profitability on Bybit/Binance.
- No account-specific fee, latency, fill or regulatory evidence was accessed in this order.
