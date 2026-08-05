#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
botmogul_parse.py - ORDER-091B phase 1: deterministic parse of BOT MOGUL Bundles
MT4/MT5 Strategy Tester Report .html files into a flat claims CSV + ranked shortlist.

PARSE + RANK + SHORTLIST ONLY. No backtests. No verdicts. Every extracted number is a
vendor CLAIM, not a validated result (memory wobr-botranking: BotMogul rank = adverse-
selected overfit corpus).

Input rows come from _triage\\_archive\\campaigns_closed\\ORDER091A_REPORTS.csv, filtered to:
    type == 'html' AND scan_folder == 'BOT MOGUL Bundles'

Report HTML anatomy (identical across the MT4(ex4) and MT5(ex5) subtrees, spot-checked):
  Settings block: single label/value <tr> rows -
    Expert: / Symbol: / Period: <TF> (<from> - <to>) / Inputs: <first input>
    then N more <tr> rows with an EMPTY label cell and one more "<b>Name=Value</b>" input,
    until the "Company:" row closes the Inputs run.
  Results block: 3-column label/value <tr> rows -
    History Quality (or Modelling Quality): NN%
    Total Net Profit: / Balance Drawdown Maximal: NNN (PP.PP%) / Equity Drawdown Maximal: ...
    Profit Factor: ...
    Total Trades: ...
  Numbers use space thousands separators, e.g. "41 121.26" -> strip inner spaces before float().

Usage:
  tools\\python312\\python.exe scripts\\botmogul_parse.py
      [--csv _triage\\_archive\\campaigns_closed\\ORDER091A_REPORTS.csv]
      [--out _triage\\_archive\\corpora_cold\\botmogul\\BOTMOGUL_CLAIMS.csv]
      [--xray _triage\\FXDREEMA_XRAY.csv]
      [--shortlist _triage\\_archive\\corpora_cold\\botmogul\\BOTMOGUL_SHORTLIST.md]
      [--limit N]   (debug: only process first N filtered rows)
"""
import argparse
import csv
import os
import re
import sys
from datetime import date

# --------------------------------------------------------------------------- regexes

RE_EXPERT = re.compile(r'Expert:</td>\s*<td[^>]*>(?:<b>)?([^<]*)(?:</b>)?</td>', re.I)
RE_SYMBOL = re.compile(r'Symbol:</td>\s*<td[^>]*>(?:<b>)?([^<]*)(?:</b>)?</td>', re.I)
RE_PERIOD = re.compile(r'Period:</td>\s*<td[^>]*>(?:<b>)?([^<]*)(?:</b>)?</td>', re.I)
RE_PERIOD_DATES = re.compile(r'\((\d{4})\.(\d{2})\.(\d{2})\s*-\s*(\d{4})\.(\d{2})\.(\d{2})\)')

# Inputs run: from the "Inputs:" label row through to the "Company:" label row (exclusive)
RE_INPUTS_BLOCK = re.compile(r'Inputs:</td>(.*?)Company:</td>', re.S | re.I)
RE_BOLD = re.compile(r'<b>([^<]*)</b>')

RE_QUALITY = re.compile(r'(History Quality|Modelling Quality):</td>\s*<td[^>]*>(?:<b>)?([^<]*)(?:</b>)?</td>', re.I)
RE_NET_PROFIT = re.compile(r'Total Net Profit:</td>\s*<td[^>]*>(?:<b>)?([^<]*)(?:</b>)?</td>', re.I)
RE_PROFIT_FACTOR = re.compile(r'Profit Factor:</td>\s*<td[^>]*>(?:<b>)?([^<]*)(?:</b>)?</td>', re.I)
RE_BAL_DD = re.compile(r'Balance Drawdown Maximal:</td>\s*<td[^>]*>(?:<b>)?([^<]*)(?:</b>)?</td>', re.I)
RE_EQ_DD = re.compile(r'Equity Drawdown Maximal:</td>\s*<td[^>]*>(?:<b>)?([^<]*)(?:</b>)?</td>', re.I)
RE_TOTAL_TRADES = re.compile(r'Total Trades:</td>\s*<td[^>]*>(?:<b>)?([^<]*)(?:</b>)?</td>', re.I)

# danger-flag input name patterns (heuristic, on the input NAME half of "Name=Value")
RE_NAME_MARTINGALE = re.compile(r'(multipl|mart|lot.*mult)', re.I)
RE_NAME_MONEYLOT = re.compile(r'(lots_per_money|risk|percent)', re.I)
RE_NAME_SL = re.compile(r'(^|_)(sl|stoploss|stop_loss)($|_)', re.I)

BUCKET_LE1 = "<=1yr"
BUCKET_1_2 = "1-2yr"
BUCKET_GE2 = ">=2yr"


def read_text(path):
    """Read the report tolerating encoding oddities.

    Confirmed (2026-07-11 spot-check): MT4/MT5 tester HTML reports in this bundle are
    written as UTF-16 (LE BOM FF FE) despite the generic <meta> tag saying nothing about
    charset. A naive utf-8/cp1252 decode "succeeds" without raising but yields NUL-interleaved
    garbage that silently fails every regex. BOM-sniff first, then fall back for any plain
    ASCII/UTF-8 reports that may also exist in the bundle.
    """
    with open(path, "rb") as fh:
        raw = fh.read()
    if raw[:2] == b"\xff\xfe":
        return raw.decode("utf-16-le", errors="replace")
    if raw[:2] == b"\xfe\xff":
        return raw.decode("utf-16-be", errors="replace")
    for enc in ("utf-8", "cp1252", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def strip_num(raw):
    """'41 121.26' -> '41121.26' ; '13 288.50 (21.53%)' -> ('13288.50','21.53')"""
    raw = (raw or "").strip()
    m = re.match(r'^(-?[\d\s]+(?:\.\d+)?)\s*(?:\(([\-\d.]+)\s*%\))?', raw)
    if not m:
        return "", ""
    absval = m.group(1).replace(" ", "").replace("\xa0", "").strip()
    pct = m.group(2) or ""
    return absval, pct


def to_float(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return None


def parse_inputs(inputs_block_html):
    """Extract ordered list of 'Name=Value' tokens from the raw Inputs-run HTML slice."""
    tokens = []
    for m in RE_BOLD.finditer(inputs_block_html):
        val = m.group(1).strip()
        if val:
            tokens.append(val)
    return tokens


def derive_flags(input_tokens):
    flags = []
    saw_sl_name = False
    for tok in input_tokens:
        if "=" not in tok:
            continue
        name, _, value = tok.partition("=")
        name = name.strip()
        value = value.strip()
        if RE_NAME_SL.search(name):
            saw_sl_name = True
        if RE_NAME_MARTINGALE.search(name):
            fv = to_float(value)
            if fv is not None and fv > 1:
                flags.append("MARTINGALE")
        if RE_NAME_MONEYLOT.search(name):
            flags.append("MONEY_LOT")
    if not saw_sl_name:
        flags.append("NO_SL_INPUT(heuristic)")
    # de-dup preserve order
    seen = set()
    out = []
    for f in flags:
        if f not in seen:
            seen.add(f)
            out.append(f)
    return ";".join(out)


def window_bucket(years):
    if years is None:
        return ""
    if years <= 1.05:
        return BUCKET_LE1
    if years < 1.95:
        return BUCKET_1_2
    return BUCKET_GE2


def parse_report(path, ea_id):
    """Returns a dict of extracted fields, plus parse_status/parse_fail_reason."""
    row = {
        "ea_id": ea_id,
        "path": path,
        "expert_name": "",
        "symbol": "",
        "period_tf": "",
        "window_from": "",
        "window_to": "",
        "window_years": "",
        "window_bucket": "",
        "net_profit": "",
        "profit_factor": "",
        "balance_dd_abs": "",
        "balance_dd_pct": "",
        "equity_dd_abs": "",
        "equity_dd_pct": "",
        "total_trades": "",
        "quality_label": "",
        "quality_value": "",
        "inputs_raw": "",
        "danger_flags": "",
        "parse_status": "ok",
        "parse_fail_reason": "",
    }
    missing = []

    try:
        html = read_text(path)
    except Exception as e:
        row["parse_status"] = "fail"
        row["parse_fail_reason"] = "read_error:%r" % (e,)
        return row

    m = RE_EXPERT.search(html)
    if m:
        row["expert_name"] = m.group(1).strip()

    m = RE_SYMBOL.search(html)
    if m:
        row["symbol"] = m.group(1).strip()
    else:
        missing.append("symbol")

    m = RE_PERIOD.search(html)
    if m:
        period_raw = m.group(1).strip()
        row["period_tf"] = period_raw.split("(")[0].strip()
        dm = RE_PERIOD_DATES.search(period_raw)
        if dm:
            y1, mo1, d1, y2, mo2, d2 = dm.groups()
            row["window_from"] = "%s.%s.%s" % (y1, mo1, d1)
            row["window_to"] = "%s.%s.%s" % (y2, mo2, d2)
            try:
                d_from = date(int(y1), int(mo1), int(d1))
                d_to = date(int(y2), int(mo2), int(d2))
                years = (d_to - d_from).days / 365.25
                row["window_years"] = round(years, 3)
                row["window_bucket"] = window_bucket(years)
            except ValueError:
                missing.append("window_dates_invalid")
        else:
            missing.append("window_dates")
    else:
        missing.append("period")

    im = RE_INPUTS_BLOCK.search(html)
    input_tokens = []
    if im:
        input_tokens = parse_inputs(im.group(1))
        row["inputs_raw"] = " ".join(input_tokens)
    else:
        missing.append("inputs")
    row["danger_flags"] = derive_flags(input_tokens)

    m = RE_QUALITY.search(html)
    if m:
        row["quality_label"] = m.group(1).strip()
        row["quality_value"] = m.group(2).strip()

    m = RE_NET_PROFIT.search(html)
    if m:
        absval, _ = strip_num(m.group(1))
        row["net_profit"] = absval
    else:
        missing.append("net_profit")

    m = RE_PROFIT_FACTOR.search(html)
    if m:
        pf_raw = m.group(1).strip()
        # Profit Factor can be a plain number or occasionally blank/inf-like text
        pf_clean = pf_raw.replace(" ", "")
        row["profit_factor"] = pf_clean
    else:
        missing.append("profit_factor")

    m = RE_BAL_DD.search(html)
    if m:
        absval, pct = strip_num(m.group(1))
        row["balance_dd_abs"] = absval
        row["balance_dd_pct"] = pct

    m = RE_EQ_DD.search(html)
    if m:
        absval, pct = strip_num(m.group(1))
        row["equity_dd_abs"] = absval
        row["equity_dd_pct"] = pct

    m = RE_TOTAL_TRADES.search(html)
    if m:
        absval, _ = strip_num(m.group(1))
        row["total_trades"] = absval
    else:
        missing.append("total_trades")

    essential = {"symbol", "period", "net_profit", "profit_factor", "total_trades"}
    if essential & set(missing):
        row["parse_status"] = "fail"
        row["parse_fail_reason"] = ";".join(missing)
    elif missing:
        row["parse_status"] = "partial"
        row["parse_fail_reason"] = ";".join(missing)

    return row


# --------------------------------------------------------------------------- xray join

def load_xray(xray_path):
    """name -> row dict, for a best-effort left-join on ea_id (mostly expected to miss)."""
    idx = {}
    if not xray_path or not os.path.isfile(xray_path):
        return idx
    with open(xray_path, encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            name = (r.get("name") or "").strip()
            if name:
                idx[name.lower()] = r
    return idx


# --------------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=r"_triage\_archive\campaigns_closed\ORDER091A_REPORTS.csv")
    ap.add_argument("--out", default=r"_triage\_archive\corpora_cold\botmogul\BOTMOGUL_CLAIMS.csv")
    ap.add_argument("--xray", default=r"_triage\FXDREEMA_XRAY.csv")
    ap.add_argument("--shortlist", default=r"_triage\_archive\corpora_cold\botmogul\BOTMOGUL_SHORTLIST.md")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    with open(args.csv, encoding="utf-8-sig", newline="") as f:
        all_rows = list(csv.DictReader(f))
    filtered = [r for r in all_rows
                if r.get("type") == "html" and r.get("scan_folder") == "BOT MOGUL Bundles"]
    if args.limit:
        filtered = filtered[:args.limit]

    print("Input CSV total rows: %d" % len(all_rows))
    print("Filtered (html, BOT MOGUL Bundles): %d" % len(filtered))

    xray_idx = load_xray(args.xray)
    print("X-ray index loaded: %d names" % len(xray_idx))

    out_rows = []
    n_ok = n_partial = n_fail = 0
    n_joined = 0
    for i, r in enumerate(filtered):
        path = r["path"]
        ea_id = r["parent_ea_folder"]
        parsed = parse_report(path, ea_id)

        xr = xray_idx.get(ea_id.lower()) or xray_idx.get((parsed.get("expert_name") or "").lower())
        if xr:
            n_joined += 1
            parsed["xray_concept"] = xr.get("concept", "")
            parsed["xray_flags"] = xr.get("flags", "")
            parsed["xray_has_sl"] = xr.get("has_sl", "")
            parsed["xray_lot_escalation"] = xr.get("lot_escalation", "")
        else:
            parsed["xray_concept"] = ""
            parsed["xray_flags"] = ""
            parsed["xray_has_sl"] = ""
            parsed["xray_lot_escalation"] = ""

        if parsed["parse_status"] == "ok":
            n_ok += 1
        elif parsed["parse_status"] == "partial":
            n_partial += 1
        else:
            n_fail += 1

        out_rows.append(parsed)
        if (i + 1) % 100 == 0:
            print("  ...processed %d/%d" % (i + 1, len(filtered)))

    print("Parsed: ok=%d partial=%d fail=%d (total %d)" % (n_ok, n_partial, n_fail, len(out_rows)))
    print("X-ray join hits: %d/%d" % (n_joined, len(out_rows)))

    fieldnames = [
        "ea_id", "path", "expert_name", "symbol", "period_tf",
        "window_from", "window_to", "window_years", "window_bucket",
        "net_profit", "profit_factor",
        "balance_dd_abs", "balance_dd_pct", "equity_dd_abs", "equity_dd_pct",
        "total_trades", "quality_label", "quality_value",
        "inputs_raw", "danger_flags",
        "xray_concept", "xray_flags", "xray_has_sl", "xray_lot_escalation",
        "parse_status", "parse_fail_reason",
    ]
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in out_rows:
            w.writerow(r)
    print("Wrote %s" % args.out)

    write_shortlist(args.shortlist, out_rows, len(filtered), n_ok, n_partial, n_fail, n_joined)
    print("Wrote %s" % args.shortlist)


def write_shortlist(path, rows, total_filtered, n_ok, n_partial, n_fail, n_joined):
    buckets = {BUCKET_LE1: 0, BUCKET_1_2: 0, BUCKET_GE2: 0, "unknown": 0}
    for r in rows:
        b = r.get("window_bucket") or "unknown"
        buckets[b] = buckets.get(b, 0) + 1
    total = len(rows)

    def pct(n):
        return "%.1f%%" % (100.0 * n / total) if total else "n/a"

    # rankable rows: parse ok/partial, have profit_factor as float, window_bucket == >=2yr
    def pf_val(r):
        return to_float(r.get("profit_factor"))

    ge2 = [r for r in rows if r.get("window_bucket") == BUCKET_GE2 and pf_val(r) is not None
           and r.get("parse_status") in ("ok", "partial")]
    ge2_sorted = sorted(ge2, key=lambda r: pf_val(r), reverse=True)

    single_year = [r for r in rows if r.get("window_bucket") in (BUCKET_LE1, BUCKET_1_2)
                   and pf_val(r) is not None and r.get("parse_status") in ("ok", "partial")]
    single_year_sorted = sorted(single_year, key=lambda r: pf_val(r), reverse=True)

    def red_flag(r):
        flags = []
        if "MARTINGALE" in (r.get("danger_flags") or ""):
            flags.append("MARTINGALE")
        if "NO_SL_INPUT" in (r.get("danger_flags") or ""):
            flags.append("NO_SL")
        dd_b = to_float(r.get("balance_dd_pct")) or 0
        dd_e = to_float(r.get("equity_dd_pct")) or 0
        if max(dd_b, dd_e) > 40:
            flags.append("DD>40%")
        return ";".join(flags) if flags else "none"

    lines = []
    lines.append("# BOTMOGUL_SHORTLIST — ORDER-091B phase 1 (parse+rank, no backtests, no verdicts)")
    lines.append("")
    lines.append("Source: `_triage\\_archive\\corpora_cold\\botmogul\\BOTMOGUL_CLAIMS.csv`, %d BOT MOGUL Bundles html reports "
                  "(type=html, scan_folder='BOT MOGUL Bundles')." % total_filtered)
    lines.append("Parse status: ok=%d, partial=%d, fail=%d (of %d)." % (n_ok, n_partial, n_fail, total))
    lines.append("X-ray join hits (ea_id/expert_name vs FXDREEMA_XRAY.csv name): %d/%d "
                  "(expected low — most BOT MOGUL entries are .ex4/.ex5-only, no matching source)."
                  % (n_joined, total))
    lines.append("")
    lines.append("**All numbers below are vendor CLAIMS from the vendor's own MT4/MT5 Strategy Tester "
                  "report. Not verified. Do not treat as pass/fail — memory `wobr-botranking`: this "
                  "corpus lineage ranks adverse-selected/overfit results. Phase 2 (BWD spot-kill on our "
                  "own data) is required before any verdict.**")
    lines.append("")
    lines.append("## Window distribution (cherry-pick measure)")
    lines.append("")
    lines.append("| bucket | count | %% of %d |" % total)
    lines.append("|---|---|---|")
    lines.append("| <=1yr (single-year) | %d | %s |" % (buckets[BUCKET_LE1], pct(buckets[BUCKET_LE1])))
    lines.append("| 1-2yr | %d | %s |" % (buckets[BUCKET_1_2], pct(buckets[BUCKET_1_2])))
    lines.append("| >=2yr | %d | %s |" % (buckets[BUCKET_GE2], pct(buckets[BUCKET_GE2])))
    if buckets["unknown"]:
        lines.append("| unknown (unparsed window) | %d | %s |" % (buckets["unknown"], pct(buckets["unknown"])))
    single_pct = pct(buckets[BUCKET_LE1] + buckets[BUCKET_1_2])
    lines.append("")
    lines.append("**Headline: %s of the %d-report bundle is tested on <2 years of data "
                  "(single-year or 1-2yr window) — the majority is single-year/short-window "
                  "cherry-pick territory, per the ORDER-091A spot-check hypothesis.**"
                  % (single_pct, total))
    lines.append("")
    lines.append("## Top-30 by claimed Profit Factor — RESTRICTED to window_years >= 2")
    lines.append("")
    lines.append("(Single-year / 1-2yr reports are excluded from this ranking on principle — "
                  "listed separately below. `structural_red_flag` is visible, NOT a filter: "
                  "flagged rows stay in the table so the judge sees them.)")
    lines.append("")
    lines.append("| # | ea_id | symbol | TF | PF | bal_dd% | eq_dd% | trades | window | years | red_flag | note |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for i, r in enumerate(ge2_sorted[:30], 1):
        note_bits = []
        if r.get("parse_status") == "partial":
            note_bits.append("partial-parse:%s" % r.get("parse_fail_reason"))
        if r.get("quality_value") and r.get("quality_value") != "100%":
            note_bits.append("quality=%s" % r.get("quality_value"))
        note = "; ".join(note_bits) if note_bits else "-"
        lines.append("| %d | %s | %s | %s | %s | %s | %s | %s | %s-%s | %s | %s | %s |" % (
            i, r.get("ea_id"), r.get("symbol"), r.get("period_tf"), r.get("profit_factor"),
            r.get("balance_dd_pct") or "-", r.get("equity_dd_pct") or "-", r.get("total_trades"),
            r.get("window_from"), r.get("window_to"), r.get("window_years"), red_flag(r), note,
        ))
    if not ge2_sorted:
        lines.append("| - | (none) | - | - | - | - | - | - | - | - | - | no reports with window_years>=2 parsed successfully |")

    lines.append("")
    lines.append("## Single-year / short-window reports (top-15 by claimed PF — NOT in the main ranking)")
    lines.append("")
    lines.append("| # | ea_id | symbol | TF | PF | bal_dd% | eq_dd% | trades | window | years | red_flag |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for i, r in enumerate(single_year_sorted[:15], 1):
        lines.append("| %d | %s | %s | %s | %s | %s | %s | %s | %s-%s | %s | %s |" % (
            i, r.get("ea_id"), r.get("symbol"), r.get("period_tf"), r.get("profit_factor"),
            r.get("balance_dd_pct") or "-", r.get("equity_dd_pct") or "-", r.get("total_trades"),
            r.get("window_from"), r.get("window_to"), r.get("window_years"), red_flag(r),
        ))

    lines.append("")
    lines.append("## Parse failures")
    lines.append("")
    fails = [r for r in rows if r.get("parse_status") == "fail"]
    lines.append("%d rows failed to parse essential fields (symbol/period/net_profit/profit_factor/"
                  "total_trades). ea_id + reason:" % len(fails))
    lines.append("")
    if fails:
        lines.append("| ea_id | path | reason |")
        lines.append("|---|---|---|")
        for r in fails[:200]:
            lines.append("| %s | %s | %s |" % (r.get("ea_id"), r.get("path"), r.get("parse_fail_reason")))
        if len(fails) > 200:
            lines.append("| ... | (%d more, see BOTMOGUL_CLAIMS.csv parse_status=fail) | ... |"
                          % (len(fails) - 200))
    else:
        lines.append("(none)")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    sys.exit(main())
