---
name: ea-strategy-synthesizer
description: Combine source-backed mechanisms, components, regimes, risk, and execution knowledge into an EA_LAB testable strategy hypothesis.
---

# EA Strategy Synthesizer

Authority: `RESEARCH_ONLY`.

The output is a `TESTABLE_HYPOTHESIS`, never an accepted strategy.

Required synthesis fields:

- hypothesis name and mechanism family;
- market behavior being exploited;
- entry/signal, filters, exit, sizing, and cost assumptions;
- expected operating and failure regimes;
- supporting `source_id` values and evidence depth;
- contradicting evidence / negative knowledge;
- target asset/timeframe transfer gaps;
- minimum controlled experiment needed to falsify the hypothesis.

Prefer the smallest coherent mechanism over indicator stacking. Do not invent supporting evidence or imply that source profitability transfers to XAU/FX/BTC.

Do not write EA source code, launch Factory/MT5, create a strategy registry entry, change risk/defaults, deploy, trade, or implement QI-2+. A later controlled experiment contract is a separate consumer.