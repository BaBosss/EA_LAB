#!/usr/bin/env python3
import argparse, json, re, sys

NUM_TOKEN = r"[+-]?(?:\d+|\d{1,3}(?: \d{3})+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?"

def strip_html(t):
    t = re.sub(r"<[^>]+>", "", t)
    return (
        t.replace("&nbsp;", " ")
        .replace("\xa0", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .strip()
    )

def pn(s):
    if s is None:
        return None
    s = str(s).replace("\xa0", " ").strip()
    if not s or not re.fullmatch(NUM_TOKEN, s):
        return None
    normalized = s.replace(",", "").replace(" ", "")
    try:
        return float(normalized)
    except ValueError:
        return None

def leading_number(s):
    if not s:
        return None
    m = re.match(rf"\s*({NUM_TOKEN})(?=\s*(?:\(|%|$))", str(s).replace("\xa0", " "))
    return pn(m.group(1)) if m else None

def parse_report(path):
    with open(path, "rb") as f:
        raw = f.read()
    try:
        html = raw.decode("utf-16-le")
    except UnicodeDecodeError:
        html = raw.decode("utf-8", errors="replace")
    html = html.lstrip("\ufeff")

    c = strip_html(html)
    build_match = re.search(r"\bBuild\s+(\d+)\b", html, re.I)
    html_table_mode = re.search(r"<td\b", html, re.I) is not None

    def _looks_like_label(line):
        return re.match(r"^[A-Za-z][^:\n]{0,119}:\s*", line or "") is not None

    LOOKUP_NOT_FOUND = 0
    LOOKUP_FOUND_EMPTY = 1
    LOOKUP_FOUND_VALUE = 2

    def _lookup(label):
        if html_table_mode:
            # In HTML-table mode never fall through to document-wide plain text.
            label_cell = re.search(
                r"<td\b[^>]*>\s*" + re.escape(label) + r"\s*</td>",
                html,
                re.DOTALL | re.I,
            )
            if not label_cell:
                return LOOKUP_NOT_FOUND, ""
            tail = html[label_cell.end():]
            value_cell = re.match(
                r"\s*<td\b[^>]*>(.*?)</td>",
                tail,
                re.DOTALL | re.I,
            )
            if not value_cell:
                return LOOKUP_FOUND_EMPTY, ""
            value = strip_html(value_cell.group(1))
            if not value:
                return LOOKUP_FOUND_EMPTY, ""
            return LOOKUP_FOUND_VALUE, value

        # Legacy/plain-text mode is line-scoped. Preserve a matched-empty
        # distinction so aliases cannot override an explicitly empty primary.
        lines = c.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        label_low = label.lower()
        for idx, raw_line in enumerate(lines):
            line = raw_line.strip()
            if not line.lower().startswith(label_low):
                continue
            rest = line[len(label):].strip()
            if rest:
                if _looks_like_label(rest):
                    return LOOKUP_FOUND_EMPTY, ""
                return LOOKUP_FOUND_VALUE, rest
            for nxt in lines[idx + 1:]:
                candidate = nxt.strip()
                if not candidate:
                    continue
                if _looks_like_label(candidate):
                    return LOOKUP_FOUND_EMPTY, ""
                return LOOKUP_FOUND_VALUE, candidate
            return LOOKUP_FOUND_EMPTY, ""
        return LOOKUP_NOT_FOUND, ""

    def fl(label):
        status, value = _lookup(label)
        return value if status == LOOKUP_FOUND_VALUE else ""

    def fl_any(*labels):
        for label in labels:
            status, value = _lookup(label)
            if status == LOOKUP_NOT_FOUND:
                continue
            return value if status == LOOKUP_FOUND_VALUE else ""
        return ""

    def number_pct(value):
        if not value:
            return None
        m = re.fullmatch(
            rf"\s*({NUM_TOKEN})\s*\(\s*({NUM_TOKEN})\s*%\s*\)\s*",
            str(value).replace("\xa0", " "),
        )
        if not m:
            return None
        return pn(m.group(1)), pn(m.group(2))

    def count_pct(value):
        pair = number_pct(value)
        if pair is None or pair[0] is None:
            return None
        return int(pair[0]), pair[1]

    r = {}
    r["ea_name"] = fl("Expert:")
    r["symbol"] = fl("Symbol:")
    r["company"] = fl("Company:")
    r["report_build"] = int(build_match.group(1)) if build_match else 0
    r["currency"] = fl("Currency:")

    pr = fl("Period:")
    if pr:
        pts = pr.split("(")
        if len(pts) >= 2:
            dp = pts[-1].rstrip(")").strip()
            ds = dp.split("-")
            r["period"] = pts[0].strip()
            if len(ds) == 2:
                r["from_date"] = ds[0].strip()
                r["to_date"] = ds[1].strip()
        else:
            r["period"] = pr

    r["initial_deposit"] = pn(fl("Initial Deposit:")) or 0
    r["leverage"] = fl("Leverage:")
    r["quality"] = fl("Quality:")
    r["history_quality"] = fl("History Quality:")
    r["bars"] = pn(fl("Bars:")) or 0
    r["ticks"] = pn(fl("Ticks:")) or 0
    symbols = pn(fl("Symbols:"))
    r["symbols_count"] = int(symbols) if symbols is not None else 0

    r["net_profit"] = pn(fl("Total Net Profit:")) or 0
    r["gross_profit"] = pn(fl("Gross Profit:")) or 0
    r["gross_loss"] = pn(fl("Gross Loss:")) or 0
    r["balance_drawdown_abs"] = pn(fl("Balance Drawdown Absolute:")) or 0
    r["equity_drawdown_abs"] = pn(fl("Equity Drawdown Absolute:")) or 0

    bdma = fl("Balance Drawdown Maximal:")
    eqdma = fl("Equity Drawdown Maximal:")
    if bdma:
        pair = number_pct(bdma)
        if pair is not None:
            r["balance_drawdown_maximal_abs"] = pair[0] or 0
            r["balance_drawdown_maximal_pct"] = pair[1] or 0
    if eqdma:
        pair = number_pct(eqdma)
        if pair is not None:
            r["equity_drawdown_maximal_abs"] = pair[0] or 0
            r["equity_drawdown_maximal_pct"] = pair[1] or 0

    bdr = fl("Balance Drawdown Relative:")
    edr = fl("Equity Drawdown Relative:")
    if bdr:
        m = re.match(rf"\s*({NUM_TOKEN})\s*%", bdr.replace("\xa0", " "))
        if m:
            r["balance_drawdown_relative_pct"] = pn(m.group(1)) or 0
    if edr:
        m = re.match(rf"\s*({NUM_TOKEN})\s*%", edr.replace("\xa0", " "))
        if m:
            r["equity_drawdown_relative_pct"] = pn(m.group(1)) or 0

    r["profit_factor"] = pn(fl("Profit Factor:")) or 0
    r["recovery_factor"] = pn(fl("Recovery Factor:")) or 0
    r["expected_payoff"] = pn(fl("Expected Payoff:")) or 0
    r["sharpe_ratio"] = pn(fl("Sharpe Ratio:")) or 0
    r["z_score"] = fl("Z-Score:")
    r["ahpr"] = leading_number(fl("AHPR:")) or 0
    r["ghpr"] = leading_number(fl("GHPR:")) or 0
    r["lr_correlation"] = pn(fl("LR Correlation:")) or 0
    r["ontester_result"] = pn(fl("OnTester result:")) or 0
    r["margin_level"] = fl("Margin Level:")
    r["total_trades"] = pn(fl("Total Trades:")) or 0
    r["total_deals"] = pn(fl("Total Deals:")) or 0

    sr = fl("Short Trades (won %):")
    lr2 = fl("Long Trades (won %):")
    if sr:
        pair = count_pct(sr)
        if pair is not None:
            r["short_trades"] = pair[0]
            r["short_won_pct"] = pair[1] or 0
    if lr2:
        pair = count_pct(lr2)
        if pair is not None:
            r["long_trades"] = pair[0]
            r["long_won_pct"] = pair[1] or 0

    ptr = fl("Profit Trades (% of total):")
    lt2 = fl("Loss Trades (% of total):")
    if ptr:
        pair = count_pct(ptr)
        if pair is not None:
            r["profit_trades"] = pair[0]
            r["profit_trades_pct"] = pair[1] or 0
    if lt2:
        pair = count_pct(lt2)
        if pair is not None:
            r["loss_trades"] = pair[0]
            r["loss_trades_pct"] = pair[1] or 0

    r["largest_profit_trade"] = pn(fl("Largest profit trade:")) or 0
    r["largest_loss_trade"] = pn(fl("Largest loss trade:")) or 0
    r["avg_profit_trade"] = pn(fl_any("Average profit trade:", "Avg profit trade:")) or 0
    r["avg_loss_trade"] = pn(fl_any("Average loss trade:", "Avg loss trade:")) or 0
    r["avg_consecutive_wins"] = pn(fl_any("Average consecutive wins:", "Avg consecutive wins:")) or 0
    r["avg_consecutive_losses"] = pn(fl_any("Average consecutive losses:", "Avg consecutive losses:")) or 0
    r["max_consecutive_wins"] = leading_number(fl_any("Maximum consecutive wins ($):", "Max consecutive wins:")) or 0
    r["max_consecutive_losses"] = leading_number(fl_any("Maximum consecutive losses ($):", "Max consecutive losses:")) or 0
    return r

def main():
    pa = argparse.ArgumentParser()
    pa.add_argument("report")
    pa.add_argument("--json", action="store_true")
    a = pa.parse_args()
    try:
        res = parse_report(a.report)
    except FileNotFoundError:
        print(json.dumps({"error": f"File not found: {a.report}", "status": "NO_REPORT"}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e), "status": "PARSE_ERROR"}))
        sys.exit(1)
    if a.json:
        print(json.dumps(res, indent=2, ensure_ascii=False))
    else:
        for k, v in res.items():
            print(f"  {k}: {v}")

if __name__ == "__main__":
    main()
