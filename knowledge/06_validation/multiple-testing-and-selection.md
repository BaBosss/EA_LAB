# Multiple Testing and Strategy Selection

Authority: `RESEARCH_ONLY`. This note summarizes research implications; it does not modify Factory acceptance policy or implement QI-2 Evidence Intelligence.

## Core research point

When many strategies, parameter combinations or variants are tried, the best observed result is selected from a search distribution. Conventional single-test significance, Sharpe Ratio or attractive equity shape can therefore overstate evidence for the selected winner.

Primary Batch 1 source: `RC-SSRN2474755-001` / `SRC-GDRIVE-SSRN2474755`.

## What must remain visible in future hypotheses

- how many materially distinct alternatives were tried;
- whether the reported winner was selected after looking at the same data;
- which performance statistic was optimized;
- whether variants are strongly correlated or effectively independent;
- IS/OOS/WFA/PBO evidence available after selection;
- whether the return distribution makes Sharpe an incomplete summary.

## EA_LAB research use

Treat experiment/search history as part of provenance. A future validation design may compare raw performance with selection-aware evidence, but this note itself grants no verdict, optimization authority or acceptance-threshold change.