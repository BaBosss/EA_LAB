# Codex review queue — opened 2026-07-25

Codex/ChatGPT quota was exhausted on 2026-07-25. User directive that day: *"ผมว่านายทำต่อ
ให้จบเลย แล้วค่อยให้ codex รีวิวทีเดียว"* — finish the work, batch the audits, send them in
one pass when quota returns.

Nothing below is blocking a live account today. Each item names what a reviewer must
actually check, not just "please review".

---

## 1. `scripts/portfolio_risk_admission.py` — single-leg-basket correlation resolution
**Commit:** `6f49e0b7` · **State:** built, `--resolve-single-leg-baskets`, **DEFAULT OFF**

A basket leg is keyed `basket::<id>` so a basket-level DD95 is not counted once per leg.
But `get_corr()` is keyed by MAGIC, so a `basket::` key can never match a measured
correlation and always falls back to the conservative 1.0. Where a basket has only ONE
known-DD95 leg, that rename buys no dedup at all and discards every correlation the leg
has. Account 463666728: **73.04% reported vs 38.36%** from the same formula over the same
already-measured correlations — the two IchiADX baskets (22.19% and 10.77%, each with
exactly one known leg) were being treated as fully additive with all 12 other EAs.

**The actual question for the reviewer — do NOT just diff the code:**
is it legitimate to pair a **basket-level DD95** with a **single leg's** correlation
series? The DD95 came from a 2-leg basket MC; the correlation comes from that one leg's
trade series. Both directions are defensible:
- resolving is strictly better than assuming 1.0 against a 14-EA portfolio
- but the 1.0 default is a *deliberate*, cage-protected choice (cage 19), and the
  magnitude/correlation mismatch is real

Also review the multi-leg case, which was deliberately left UNCHANGED: picking a
representative leg's correlation for a genuine 2-known-leg basket is a judgment call that
was explicitly not taken.

**Guards already in place:** cages 30/30 untouched still pass; cage 31 asserts the switch
is off by default and only ever touches the single-leg case; cage 32 asserts a basket's
identity is decided once per account inventory (re-deriving it per slice made the
ACTIVE-only view disagree with the all-rows view and raise KeyError on its own key).

**Do not flip the default** on Codex's word alone — user ratification required, same as
ORDER-200 Phase D.

## 2. ORDER-187 — fail-closed first-lot sizing + Wave5 naked-order guard
**State:** `DONE(2026-07-24) — รอ Codex blind-audit`. Money path, so the audit is
mandatory before it can be called closed. Brief must be neutral QA (no anchoring on the
Claude-side reasoning) and the reviewer must read the result files, not exit codes.

## 3. ORDER-200 Phase A/C — MRIS crisis models
**State:** advisory-only, live. Phase D (folding crisis scores into the real-money
MacroGate path) is explicitly gated on this audit + user ratify. Commits `6e806b85` →
`d744e57a`.

---

## Related, NOT for Codex — needs the user, or a normal session

- **991001 backtest-corr mapping is deliberately absent.** The only report carrying magic
  991001 runs the **v3** config (`Bars55/Tp8.0/Ema150`) while two independent live records
  (DEPLOYMENTS rows on both 159503454 and 159475669) point to **v2** (`Bars40/Tp5.0/Ema200`),
  and no usable v2 report exists on H1. Mapping it would launder CR-002's open
  config-lineage question into a correlation number. **Unblocks when the user confirms
  which `.set` is actually on the VPS** — the same CR-002 item already waiting.
- **992001 TsMom DD95 stays UNKNOWN on purpose** — no Monte Carlo was ever run on it
  (PARKED-VERIFY demo-isolate, not a completed funnel). Do not backfill a number.
- **Stale `2026.06.01` windows survive in order-specific scripts** (`gsmc_validate.ps1`,
  `mt5_batch_shortlist.ps1`, `optimize_loop.ps1`, `qwen_batch_runner.ps1`,
  `order104*.ps1`). Left alone deliberately: they are historical one-shot runners, and
  rewriting them would misrepresent what past runs actually did. The reusable path
  (`.claude/agents/ea-screener.md`, `ea-validator.md`) IS fixed — commit `c612dbe0`.
  Worth a sweep only if any of them gets reused for new evidence.
