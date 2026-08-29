---
card_type: VALIDATION_NOTE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---
# Parameter optimization requires search-history evidence
Optimized parameters can outperform defaults in a historical sample (`RC-SSRN3697734-001`), and iterative optimization is a legitimate strategy-development step (`RC-SSRN4878676-001`). Neither fact makes an optimized winner trustworthy by itself.

`RC-SSRN2474755-001` supplies the counterweight: the more alternatives tried, the easier it is to select a lucky high-Sharpe result. Search multiplicity therefore changes the evidentiary hurdle.

## EA_LAB research rule
- define mechanism and parameter semantics before search;
- record every tested parameter family/range, symbol and timeframe relevant to selection;
- separate development data from OOS/forward evidence;
- inspect parameter stability rather than only the optimum point;
- include realistic cost assumptions before promotion;
- treat a selected winner as `TESTABLE_HYPOTHESIS` until existing Factory acceptance proves otherwise.

This note does not change Factory policy or authorize optimization. It is a research discipline for designing future bounded experiments.