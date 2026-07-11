#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fxdreema_concepts.py — ORDER-079: concept catalog of the fxDreema course-library corpus.

Reframe vs ORDER-074 xray: the 1,050-EA corpus is the user's COURSE LIBRARY (idea seeds
and exercises), so this pass extracts *what ideas the course taught* — a concept taxonomy —
NOT risk judgment. No danger-flag language belongs in the catalog output.

Reuses the ORDER-074 parser (scripts/fxdreema_xray.py) for file reading + block-label
extraction, and the ORDER-074 CSV (_triage/FXDREEMA_XRAY.csv) as the authoritative
deduped file list (1 row = 1 unique EA, `path` = canonical copy).

Per-file concept evidence, richest first:
  1. fxDreema "// Block N (label)" comments — human-written, meaning-dense
  2. filename + parent folder name
  3. descriptive string constants: Comment()/Print()/Alert() literals, #property
     description, string input defaults
  4. indicator set (from the xray CSV column) as a fallback signal

Outputs:
  _triage/FXDREEMA_IDEA_CATALOG.md   — concept sections (count, representatives,
                                       mechanism sketch, lab status)
  _triage/FXDREEMA_XRAY.csv          — rewritten with a new `concept` column appended
                                       (all ORDER-074 columns preserved)

Usage:
  tools\python312\python.exe scripts\fxdreema_concepts.py [--dump-evidence FILE.json]
"""
import argparse
import csv
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fxdreema_xray import read_text, RE_BLOCK_MARKER, html_unescape  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XRAY_CSV = os.path.join(REPO, "_triage", "FXDREEMA_XRAY.csv")
CATALOG_MD = os.path.join(REPO, "_triage", "FXDREEMA_IDEA_CATALOG.md")

# --------------------------------------------------------------------- string evidence

RE_PROP_DESC = re.compile(r'#property\s+description\s+"([^"]*)"')
RE_CALL_STR = re.compile(r'\b(?:Comment|Print|Alert|SendNotification)\s*\(\s*"([^"]{3,200})"')
RE_STR_INPUT = re.compile(
    r'^\s*(?:input|extern|sinput)\s+string\s+\w+\s*=\s*"([^"]{3,120})"', re.MULTILINE)
RE_ICUSTOM = re.compile(r'iCustom\s*\([^;]*?"([^"]+)"')

# fxDreema auto-labels that carry no concept meaning
GENERIC_LABELS = re.compile(
    r"^(buy now|sell now|buy|sell|close|delete pending|modify.*|trailing.*|"
    r"if.*orders?( in (profit|loss))?.*|no trade|once per (bar|tick).*|"
    r"technical analysis( \d+)?|check every tick.*|condition|formula|"
    r"multi condition|spread filter|once flag.*|wait \d+.*|for each order.*|"
    r"order count.*|money management|lot size?|set variable.*|get variable.*|"
    r"print|comment|alert|arrow.*|else|and|or|not)$", re.I)


def extract_evidence(path):
    """Return dict of evidence text pulled from one source file."""
    text = read_text(path)
    labels = []
    for m in RE_BLOCK_MARKER.finditer(text):
        lab = html_unescape(m.group(2)).strip()
        if lab and lab not in labels:
            labels.append(lab)
    strings = []
    # fxDreema template boilerplate strings present in nearly every export - never concept evidence
    boiler = ("Unable to set chart", "Average ticks per second", "Error code", "not enough money",
              "invalid stops", "market closed")
    for rx in (RE_PROP_DESC, RE_CALL_STR, RE_STR_INPUT):
        for m in rx.finditer(text):
            s = m.group(1).strip()
            if s and s not in strings and not s.startswith(("\\n", "=", "-", "*")) \
               and not any(b.lower() in s.lower() for b in boiler):
                strings.append(s)
    customs = []
    for m in RE_ICUSTOM.finditer(text):
        s = m.group(1).strip()
        if s and s not in customs:
            customs.append(s)
    return {"labels": labels, "strings": strings[:40], "custom_indicators": customs[:10]}


# --------------------------------------------------------------------- taxonomy

# (family_key, display_name, regex over evidence, priority)
# Higher priority wins the PRIMARY slot; a second distinct match becomes SECONDARY.
# Specific named concepts outrank generic mechanism words on purpose: an EA whose
# labels say "order block" + "breakout" is an SMC exercise that uses a breakout entry.
RULES = [
    ("elliott", "Elliott / wave-count / swing-structure",
     r"elliott?[\s_-]?wave|\bwave[\s_-]?[1-5ab c]\b|\bwave\s*count|impulse\s*wave|"
     r"motive|corrective|\bwolfe\b|elliot", 100),
    ("smc", "SMC / order-block / liquidity / BOS-CHOCH / FVG",
     r"order[\s_-]?block|liquidity|\bsweep\b|\bBOS\b|CHO?CH\b|\bFVG\b|fair\s*value\s*gap|"
     r"imbalance|mitigat|premium.{0,12}discount|smart\s*money|\bSMC\b|inducement|"
     r"break\s*of\s*structure|change\s*of\s*character|market\s*structure", 95),
    ("harmonic_fib", "Fibonacci / harmonic / pattern-geometry",
     r"fibonacci|\bfibo?\b|harmonic|gartley|butterfly\s*pattern|retracement|extension\s*level|"
     r"golden\s*(ratio|zone)", 90),
    ("strength_meter", "Currency-strength meter",
     r"strength\s*(meter|matrix)|currency\s*strength|strongest|weakest|\bCSM\b", 88),
    ("correlation_pair", "Correlation / pair & basket-of-symbols trading",
     r"correlat|pair\s*trad|arbitrage|hedge\s*pair|carry\s*trade|multi[\s_-]?(symbol|pair|currency)|"
     r"basket\s*of|two\s*pairs?|28\s*pairs?", 85),
    ("news", "News / calendar event trading",
     r"\bnews\b|\bNFP\b|non[\s_-]?farm|calendar|high\s*impact|economic\s*event|fomc|straddle", 83),
    ("session_time", "Session / time-window trading",
     r"session|london|new\s*york|tokyo|asian?\b|sydney|market\s*open|opening\s*hour|"
     r"time\s*(filter|window|range)|end\s*of\s*(day|week)|friday\s*close|day\s*of\s*week|"
     r"\bGMT\b|midnight|daily\s*open", 70),
    ("zone_sr", "Support/Resistance / supply-demand zone",
     r"support|resistan|supply|demand\s*zone|key\s*level|round\s*number|pivot|"
     r"\bS/?R\b|zone\s*(entry|touch)|psychological", 65),
    ("candle_pattern", "Candlestick / bar-pattern recognition",
     r"engulf|pin\s*bar|pinbar|doji|hammer|shooting\s*star|inside\s*bar|outside\s*bar|"
     r"morning\s*star|evening\s*star|three\s*(white|black|soldiers|crows)|marubozu|"
     r"heiken|heikin|candle\s*pattern|bullish\s*candle|bearish\s*candle", 62),
    ("divergence", "Divergence (price vs oscillator)",
     r"divergen", 61),
    ("breakout", "Breakout (channel / range / fractal / high-low)",
     r"break[\s_-]?out|breakout|donchian|\bbreak\b.{0,20}(high|low|range|level|channel|box)|"
     r"(high|low|range|channel|box).{0,20}\bbreak|fractal.{0,15}break|new\s*(high|low)|"
     r"highest\s*high|lowest\s*low|range\s*box", 55),
    ("reversion", "Mean-reversion / oscillator fade (RSI-CCI-Stoch-BB-WPR)",
     r"oversold|overbought|mean\s*rever|revers(al|ion)|\bfade\b|bollinger.{0,20}(touch|lower|upper)|"
     r"rsi.{0,15}(below|above|under|over|<|>)|counter[\s_-]?trend|pull\s*back|pullback|"
     r"snap\s*back|band\s*bounce", 50),
    ("trend_follow", "Trend-following (MA/SuperTrend/SAR/Ichimoku/ADX)",
     r"trend[\s_-]?follow|supertrend|super\s*trend|ma\s*cross|moving\s*average\s*cross|"
     r"golden\s*cross|death\s*cross|ichimoku|kumo|parabolic|\bsar\b|adx.{0,15}(trend|strong)|"
     r"ema\s*cross|crossover|cross\s*(up|down|over|under)|uptrend|downtrend|trend\s*direction|"
     r"alligator|slope", 45),
    ("scalping", "Scalping / short-horizon tick-pip logic",
     r"scalp|\bm1\b|tick\s*(trade|scalp)|quick\s*pips|few\s*pips", 40),
    ("grid_basket", "Grid / averaging / recovery / basket-close exercises",
     r"\bgrid\b|martingale|averag(e|ing)\s*(down|up|price)?|recovery|basket\s*(close|profit|tp)|"
     r"\bDCA\b|cost\s*averag|pip\s*step|add\s*(position|order|lot)|rescue|hedge|zone\s*recovery|"
     r"double\s*lot|multipl(y|ier).{0,10}lot|next\s*lot", 35),
    ("mm_exercise", "Money-management / equity-target exercises",
     r"money\s*management|risk\s*percent|equity\s*(target|stop|protect)|balance\s*target|"
     r"profit\s*target\s*(money|currency|\$)|drawdown\s*(stop|close)|compound|"
     r"daily\s*(profit|loss)\s*(target|limit)|prop\s*firm|ftmo|challenge", 30),
    ("dashboard_tool", "Dashboard / panel / utility (not a strategy)",
     r"dashboard|panel|button|trade\s*manager|utility|\btool\b|manual\s*trad|assistant|"
     r"informat|display|screenshot|notif(y|ication)|telegram|closer\b|close\s*all\b", 25),
]

RULES_BY_KEY = {k: (name, re.compile(rx, re.I), prio) for k, name, rx, prio in RULES}
FAMILY_ORDER = [k for k, _, _, _ in RULES] + ["indicator_generic", "unclassified"]
FAMILY_NAMES = {k: n for k, n, _, _ in RULES}
FAMILY_NAMES["indicator_generic"] = "Indicator-signal exercise (generic, from indicator set only)"
FAMILY_NAMES["unclassified"] = "Unclassified (no concept evidence found)"

# indicator-set fallback when no keyword evidence exists
IND_FALLBACK = [
    ("reversion", {"iRSI", "iCCI", "iStochastic", "iWPR", "iBands", "iDeMarker", "iMFI"}),
    ("trend_follow", {"iMA", "iSAR", "iIchimoku", "iADX", "iAlligator", "iAMA", "iDEMA",
                      "iTEMA", "iFrAMA", "iVIDyA"}),
]


def classify(name, folder, evidence, indicators):
    """Return (primary, secondary_or_None, evidence_quotes)."""
    fields = [
        ("name", name),
        ("folder", folder),
        ("label", " || ".join(evidence["labels"])),
        ("string", " || ".join(evidence["strings"])),
        ("custom", " || ".join(evidence["custom_indicators"])),
    ]
    hits = {}   # key -> (priority, quote)
    for key, (disp, rx, prio) in RULES_BY_KEY.items():
        best = None
        for src, txt in fields:
            if not txt:
                continue
            m = rx.search(txt)
            if m:
                # quote: the label/string containing the match, else the fragment
                if src in ("label", "string", "custom"):
                    seg_start = txt.rfind("||", 0, m.start())
                    seg_end = txt.find("||", m.end())
                    seg = txt[seg_start + 2 if seg_start >= 0 else 0:
                              seg_end if seg_end >= 0 else len(txt)].strip()
                    best = '%s:"%s"' % (src, seg[:80])
                else:
                    best = '%s:"%s"' % (src, m.group(0)[:60])
                break   # fields are ordered by evidence richness... but name first
        if best:
            hits[key] = (prio, best)
    if not hits:
        ind_set = set(indicators.split(";")) if indicators else set()
        for key, needed in IND_FALLBACK:
            if ind_set & needed:
                return key, None, ['indicators:"%s"' % ";".join(sorted(ind_set & needed))]
        if ind_set:
            return "indicator_generic", None, ['indicators:"%s"' % indicators[:60]]
        return "unclassified", None, []
    ranked = sorted(hits.items(), key=lambda kv: -kv[1][0])
    primary = ranked[0][0]
    secondary = ranked[1][0] if len(ranked) > 1 else None
    quotes = [hits[primary][1]] + ([hits[secondary][1]] if secondary else [])
    return primary, secondary, quotes


# --------------------------------------------------------------------- deep-list greps

DEEP_ELLIOTT = re.compile(
    r"elliott?|\bwave\b|impulse|motive|zigzag|zig[\s_-]zag|\bwolfe\b", re.I)
DEEP_SMC = re.compile(
    r"order[\s_-]?block|liquidity|\bsweep\b|\bBOS\b|CHO?CH\b|\bFVG\b|fair\s*value\s*gap|"
    r"imbalance|mitigat|premium.{0,12}discount|\bSMC\b|smart\s*money", re.I)


def deep_match(rx, name, folder, evidence):
    """Return list of matching evidence fragments for the deep lists."""
    frags = []
    for txt in [name, folder] + evidence["labels"] + evidence["strings"] + \
               evidence["custom_indicators"]:
        if txt and rx.search(txt) and txt not in frags:
            frags.append(txt)
    return frags


# --------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump-evidence", default=None,
                    help="also write per-file evidence JSON (for taxonomy review)")
    ap.add_argument("--no-write", action="store_true",
                    help="extraction/stats only; do not rewrite CSV or catalog")
    args = ap.parse_args()

    with open(XRAY_CSV, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    print("xray rows: %d" % len(rows), file=sys.stderr)

    records, missing = [], []
    for i, r in enumerate(rows):
        path = r["path"]
        if not os.path.exists(path):
            missing.append(path)
            r["_evidence"] = {"labels": [], "strings": [], "custom_indicators": []}
        else:
            try:
                r["_evidence"] = extract_evidence(path)
            except OSError:
                missing.append(path)
                r["_evidence"] = {"labels": [], "strings": [], "custom_indicators": []}
        r["_folder"] = os.path.basename(os.path.dirname(path))
        records.append(r)
        if (i + 1) % 200 == 0:
            print("  parsed %d/%d" % (i + 1, len(rows)), file=sys.stderr)
    if missing:
        print("MISSING files: %d" % len(missing), file=sys.stderr)
        for p in missing[:10]:
            print("  " + p, file=sys.stderr)

    for r in records:
        prim, sec, quotes = classify(r["name"], r["_folder"], r["_evidence"], r["indicators"])
        r["_primary"], r["_secondary"], r["_quotes"] = prim, sec, quotes
        r["_elliott"] = deep_match(DEEP_ELLIOTT, r["name"], r["_folder"], r["_evidence"])
        r["_smc"] = deep_match(DEEP_SMC, r["name"], r["_folder"], r["_evidence"])

    # stats
    from collections import Counter
    cp = Counter(r["_primary"] for r in records)
    cs = Counter(r["_secondary"] for r in records if r["_secondary"])
    print("\nPRIMARY counts:", file=sys.stderr)
    for k in FAMILY_ORDER:
        if cp.get(k):
            print("  %-18s %4d" % (k, cp[k]), file=sys.stderr)
    print("SECONDARY counts:", file=sys.stderr)
    for k, v in cs.most_common():
        print("  %-18s %4d" % (k, v), file=sys.stderr)
    print("elliott deep-list: %d · smc deep-list: %d"
          % (sum(1 for r in records if r["_elliott"]),
             sum(1 for r in records if r["_smc"])), file=sys.stderr)

    if args.dump_evidence:
        dump = [{
            "name": r["name"], "folder": r["_folder"], "primary": r["_primary"],
            "secondary": r["_secondary"], "quotes": r["_quotes"],
            "labels": r["_evidence"]["labels"], "strings": r["_evidence"]["strings"],
            "custom": r["_evidence"]["custom_indicators"],
            "indicators": r["indicators"],
            "elliott": r["_elliott"], "smc": r["_smc"], "path": r["path"],
        } for r in records]
        with open(args.dump_evidence, "w", encoding="utf-8") as fh:
            json.dump(dump, fh, ensure_ascii=False, indent=1)
        print("evidence dump -> %s" % args.dump_evidence, file=sys.stderr)

    if args.no_write:
        return

    # ---------------- CSV rewrite (old columns + concept) ----------------------
    # guard (ORDER-091A): the CSV already carries a concept column after ORDER-077 —
    # appending unconditionally recreated the duplicate-concept-column bug (fixed 2026-07-10)
    fieldnames = [k for k in rows[0].keys() if not k.startswith("_")]
    if "concept" not in fieldnames:
        fieldnames.append("concept")
    with open(XRAY_CSV, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in records:
            r["concept"] = r["_primary"] + ("+" + r["_secondary"] if r["_secondary"] else "")
            w.writerow(r)
    print("rewrote %s (+concept column)" % XRAY_CSV, file=sys.stderr)

    # catalog markdown is written by build_catalog.py logic embedded in the caller —
    # here we only emit the per-family machine summary the catalog builder consumes.
    summary = {}
    for k in FAMILY_ORDER:
        members = [r for r in records if r["_primary"] == k]
        also = [r for r in records if r["_secondary"] == k]
        if not members and not also:
            continue
        # representatives: most label-rich members whose quotes came from labels
        reps = sorted(members, key=lambda r: -len(r["_evidence"]["labels"]))[:6]
        summary[k] = {
            "display": FAMILY_NAMES[k],
            "primary_count": len(members),
            "secondary_count": len(also),
            "representatives": [{
                "name": r["name"], "path": r["path"], "quotes": r["_quotes"],
                "labels": r["_evidence"]["labels"][:25],
                "indicators": r["indicators"],
            } for r in reps],
        }
    deep = {
        "elliott": [{"name": r["name"], "path": r["path"], "frags": r["_elliott"],
                     "labels": r["_evidence"]["labels"], "indicators": r["indicators"]}
                    for r in records if r["_elliott"]],
        "smc": [{"name": r["name"], "path": r["path"], "frags": r["_smc"],
                 "labels": r["_evidence"]["labels"], "indicators": r["indicators"]}
                for r in records if r["_smc"]],
    }
    out = os.path.join(REPO, "_triage", "_concept_summary.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump({"families": summary, "deep": deep,
                   "total": len(records), "missing": len(missing)},
                  fh, ensure_ascii=False, indent=1)
    print("summary -> %s" % out, file=sys.stderr)


if __name__ == "__main__":
    main()
