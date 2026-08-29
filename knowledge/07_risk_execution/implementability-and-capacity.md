---
card_type: EXECUTION_NOTE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---
# Implementability and capacity are separate from theoretical edge
`RC-SSRN384500-001` shows that documented abnormal-return strategies can change materially when price impact, short-sale constraints, concentration limits and portfolio size are introduced. `RC-SSRN1585517-001` separately warns that turnover, transaction costs and real instrument availability affect relative-strength implementation.

## Research questions before an EA hypothesis is treated as tradable
- What spread/commission/slippage/funding assumptions are required?
- How much turnover does the mechanism create?
- Does the edge rely on fills near a benchmark, open or close?
- Does the source require instruments, shorting or liquidity unavailable to the target account?
- Does scaling position size change achievable price or participation?

Academic or frictionless profitability is `SOURCE_CLAIM`; retail MT5 implementability remains an EA_LAB hypothesis until tested. This note does not set execution or risk defaults.