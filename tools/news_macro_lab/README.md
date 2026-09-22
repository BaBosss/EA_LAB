# News / Macro Lab V1

Offline library and preparation contracts for the **existing** EA_LAB NewsGuard, MacroGate, MRIS and Monitor. No new service, dashboard, registry, provider or trading adapter. Independent review pending; local source is not canonical until normal acceptance/integration.

From the repository root with its existing portable Python:

```powershell
python -m unittest discover -s tools/news_macro_lab/tests -p "test_*.py" -v
python -m tools.news_macro_lab.cli readiness --input-root tools/news_macro_lab --input tools/news_macro_lab/global_source_catalog.json
python -m tools.news_macro_lab.cli preflight --input-root tools/news_macro_lab --input tools/news_macro_lab/experiment_proposal.json
```

Preflight is intentionally nonzero while the real experimental contract is incomplete. It cannot launch MT5 even when all hash fields are filled. CLI prints JSON only and has no runtime-output option.

`select`, `news-contact`, `macro-context` and `price-features` consume a canonical `ea_lab_offline_replay_package/1` plus explicit `--raw-source` and `--decision`. Input files must be within an explicit root. `--synthetic-mechanics` labels fixtures; neither setting qualifies a real dataset. There is deliberately no default timeframe, freshness, contact length, currency list, importance level, threshold, lot or EA selection.

For news contacts supply `--currencies USD --importance-levels High --pre-minutes <frozen input> --post-minutes <frozen input>`. For macro context supply the exact series/classifier hash and source-age limit. No API reads actual release values from the schedule stream. A current weekly calendar does not automatically meet the historical archive contract.

`causal.py` binds a precomputed regime state to the latest availability time of every required input and refuses same-state causal clocks that reveal the state before those inputs. It does **not** run or certify the classifier or the raw-to-normalized derivation. `placebo.py` builds every preregistered whole-week-shift placebo schedule and never selects the favorable seed. `results.py` accepts only same-identity full-engine result arms and emits descriptive deltas with no verdict/promotion. `monitor_handoff.py` emits only a non-live handoff payload with runtime effectiveness and global regime fixed to UNKNOWN.

The imported canonical selector is byte-verified before the verified bytes execute. `dependency_pins.json` changes need review; do not repin to make a test pass. Freeze the complete source package, including configs, dependency pins, CLI and test files. Neither a checksum nor this Python library grants runtime authority.

See `docs/research/NEWS_MACRO_LAB_V1_20260921.md` for the full integration, source qualification, no-bias test contract and limitations, and `WORKPLAN.json` for dependencies. The existing Monitor owner consumes a later reviewed data increment; this package does not alter `D:\OneDrive\Monitor`.
