# fxDreema YouTube — per-transcript extraction card schema

One card per transcript. A cheap model (qwen/haiku) reads each Thai transcript and emits
ONE JSON object with these fields. Claude reads only the aggregated catalog, never the raw
transcripts (token-per-file ≈ 0). Cards are appended to `cards.jsonl`.

## Card fields (JSON)
```json
{
  "tag": "EX178",
  "video_id": "ntcCOquUPCs",
  "title": "Gold Robot EA [EMA and Price Pattern]",
  "symbol": "XAUUSD",                  // or "unspecified"
  "timeframe": "unspecified",          // if the narrator states one
  "indicators": ["EMA9","EMA26","EMA200","engulfing"],
  "entry_long": "EMA9>EMA200 and EMA9 crosses above EMA26 + bullish engulfing (body ID1>ID2)",
  "entry_short": "mirror: EMA9<EMA200, EMA9 crosses below EMA26 + bearish engulfing",
  "exit": "trailing stop 500/step100, no SL, no TP",
  "lot_law": "martingale",             // fixed | martingale | linear-add | log | grid-add | unknown
  "escalation_cap": "2.0 lots",        // the cap value, or "none", or "n/a" (fixed lot)
  "has_sl": false,
  "risk_flags": ["no_sl","martingale"],// no_sl | uncapped_martingale | uncapped_grid | none
  "family": "ema+candlestick",         // primary mechanism family
  "buildon_idea": "already capped at 2 lots; flat-lot test first; try linear/log lot law",
  "novelty_note": "simple EMA-align + engulfing; common — low novelty",
  "confidence": "high"                 // high|med|low = how clearly the transcript stated it
}
```

## Rules for the extractor
- Thai narration; extract mechanism faithfully, DO NOT judge deploy-worthiness (that's Claude's job).
- **Build-on framing (user doctrine):** grid & martingale are NOT rejects. Always fill `buildon_idea`
  with the concrete extension: add position-cap, or swap lot-law to linear-add / log. Capture them.
- If a value isn't stated, use "unspecified"/"unknown"/"n/a" — never invent numbers.
- `risk_flags` = uncapped_martingale ONLY if narrator shows martingale with NO volume cap.
- Keep each field one line. Output strictly valid JSON, one object per transcript.

## Cross-ref (Claude, Phase 3 — NOT the extractor's job)
After cards.jsonl is built, Claude tags each vs lab state (EDGE_CATALOG + memory signal-landscape):
VALIDATED / TESTED-DEAD / PARTIAL / NEVER-TOUCHED. NEVER-TOUCHED ∩ build-on-viable = shortlist.

## Ground-truth spot-check anchor (built by hand 2026-07-12)
EX178 hand-extraction (verify the extractor's EX178 card matches this):
EMA 9/26/200 align + engulfing (body filter) · buy/sell 1 order · martingale ×2 **capped 2 lots** ·
no SL/TP · trailing 500/step100 · time filter 14:00–22:00 server. family=ema+candlestick.
